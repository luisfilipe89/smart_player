import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onUserDeleted } from "firebase-functions/v2/auth";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onValueCreated, onValueDeleted, onValueWritten } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import * as puppeteer from "puppeteer";
import { createHash } from "crypto";

admin.initializeApp();
setGlobalOptions({ region: "europe-west1" });

const FALLBACK_FIELD_REPORT_EMAIL =
  process.env.FIELD_REPORTS_EMAIL ||
  process.env.MUNICIPALITY_REPORT_EMAIL ||
  "luisfccfigueiredo@gmail.com";

function formatDateForEmail(date: Date): string {
  return date.toLocaleString("nl-NL", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function renderFieldReportHtml(report: any, createdAt: Date) {
  const contactBlock =
    report.allowContact && report.contactEmail
      ? `<p><strong>Contact:</strong> ${report.contactName || report.contactEmail
        } (${report.contactEmail})</p>`
      : "";

  const locationBlock = [
    report.fieldName ? `<p><strong>Field:</strong> ${report.fieldName}</p>` : "",
    report.fieldAddress ? `<p><strong>Address:</strong> ${report.fieldAddress}</p>` : "",
    report.fieldId ? `<p><strong>Field ID:</strong> ${report.fieldId}</p>` : "",
  ]
    .filter(Boolean)
    .join("");

  return `
    <div style="font-family: Arial, sans-serif; line-height:1.6;">
      <h2 style="margin-bottom: 8px;">New field issue report</h2>
      ${locationBlock}
      <p><strong>Category:</strong> ${report.category || "-"}</p>
      <p><strong>Submitted:</strong> ${formatDateForEmail(createdAt)}</p>
      <p><strong>Description:</strong></p>
      <p style="white-space:pre-wrap;background:#f7f7f7;padding:12px;border-radius:6px;border:1px solid #eee;">
        ${report.description || "-"}
      </p>
      ${contactBlock}
      <hr style="margin:24px 0;border:none;border-top:1px solid #e0e0e0;" />
      <p style="font-size:12px;color:#888;">
        Reported via SMARTPLAYER. Document ID: ${report._id}
      </p>
    </div>
  `;
}

function renderFieldReportText(report: any, createdAt: Date) {
  const lines: string[] = [
    "New field issue report",
    `Field: ${report.fieldName || "-"}`,
    `Address: ${report.fieldAddress || "-"}`,
    `Field ID: ${report.fieldId || "-"}`,
    `Category: ${report.category || "-"}`,
    `Submitted: ${formatDateForEmail(createdAt)}`,
    "",
    "Description:",
    report.description || "-",
  ];

  if (report.allowContact && report.contactEmail) {
    lines.push(
      "",
      `Contact: ${report.contactName || report.contactEmail} (${report.contactEmail})`
    );
  }

  lines.push(
    "",
    `Reported via SMARTPLAYER. Document ID: ${report._id}`
  );

  return lines.join("\n");
}

// Helper function to process a field report (used by both trigger and manual call)
async function processFieldReport(report: any, reportId: string) {
  const createdAt =
    report.createdAt?.toDate?.() ??
    (report.createdAt?._seconds
      ? new Date(report.createdAt._seconds * 1000)
      : new Date());

  const payload = {
    _id: reportId,
    ...report,
  };

  const targetEmail =
    (report.targetEmail && String(report.targetEmail).trim()) ||
    FALLBACK_FIELD_REPORT_EMAIL;

  const htmlBody = renderFieldReportHtml(payload, createdAt);
  const textBody = renderFieldReportText(payload, createdAt);

  const mailRef = admin.firestore().collection("mail").doc(reportId);
  const mailData: Record<string, any> = {
    to: [targetEmail],
    message: {
      subject: `Field report: ${report.fieldName || report.fieldId || "New issue"}`,
      html: htmlBody,
      text: textBody,
    },
    reportId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "pending",
    meta: {
      fieldId: report.fieldId || null,
      category: report.category || null,
    },
  };

  if (report.allowContact && report.contactEmail) {
    mailData.replyTo = report.contactEmail;
  }

  await mailRef.set(mailData);
  console.log(`Queued field report email for ${reportId} to ${targetEmail}`);
  
  // Update the fieldReports document to mark it as queued
  await admin.firestore()
    .collection("fieldReports")
    .doc(reportId)
    .update({
      status: "queued",
      emailQueuedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

export const onFieldReportCreated = onDocumentCreated(
  "fieldReports/{reportId}",
  async (event) => {
    const report = event.data?.data();
    const reportId = event.params.reportId as string;
    if (!report) {
      console.log("Field report created without data, skipping.");
      return;
    }

    try {
      await processFieldReport(report, reportId);
    } catch (error) {
      console.error("Failed to queue field report email:", error);
      // Mark as failed in the fieldReports document
      try {
        await admin.firestore()
          .collection("fieldReports")
          .doc(reportId)
          .update({
            status: "failed",
            emailError: String(error),
          });
      } catch (updateError) {
        console.error("Failed to update fieldReports status:", updateError);
      }
      throw error;
    }
  }
);

// Manual HTTP endpoint to process stuck pending reports
export const processPendingFieldReport = onRequest(
  {
    region: "europe-west1",
    cors: true,
  },
  async (req, res) => {
    const reportId = req.query.reportId as string;
    if (!reportId) {
      res.status(400).json({ error: "reportId query parameter required" });
      return;
    }

    try {
      const reportDoc = await admin.firestore()
        .collection("fieldReports")
        .doc(reportId)
        .get();

      if (!reportDoc.exists) {
        res.status(404).json({ error: "Report not found" });
        return;
      }

      const report = reportDoc.data();
      if (!report) {
        res.status(404).json({ error: "Report data not found" });
        return;
      }

      await processFieldReport(report, reportId);
      res.json({ success: true, message: `Report ${reportId} queued for email` });
    } catch (error: any) {
      console.error("Error processing pending report:", error);
      res.status(500).json({ error: error?.message || "Unknown error" });
    }
  }
);

// Consume client-queued notifications at /mail/notifications and fan-out
// to per-user notifications that are then pushed via sendNotification above.
export const onMailNotificationCreate = onValueCreated(
  "/mail/notifications/{notificationId}",
  async (event) => {
    const payload = event.data.val() || {};
    const notificationId = event.params.notificationId as string;
    try {
      const type = (payload.type || "").toString();
      const toUid = (payload.toUid || "").toString();
      const fromUid = (payload.fromUid || "").toString();
      const gameId = (payload.gameId || "").toString();
      const scheduled = (payload.scheduled || "").toString();

      const db = admin.database();
      // Idempotency: skip if already processed
      const processedRef = db.ref(`/mail/processed/${notificationId}`);
      const processedSnap = await processedRef.once("value");
      if (processedSnap.exists()) {
        await db.ref(`/mail/notifications/${notificationId}`).remove();
        return;
      }
      const now = Date.now();

      if (type === "friend_request" && toUid) {
        // Resolve fromName best-effort
        let fromName = "Someone";
        if (fromUid) {
          try {
            const user = await admin.auth().getUser(fromUid);
            if (user.displayName) fromName = user.displayName;
          } catch (_) { }
        }

        await db.ref(`/users/${toUid}/notifications/${notificationId}`).set({
          type: "friend_request",
          data: { fromUid, fromName },
          timestamp: now,
          read: false,
        });
      } else if (type === "friend_accept" && toUid) {
        // Resolve fromName best-effort
        let fromName = "Someone";
        if (fromUid) {
          try {
            const user = await admin.auth().getUser(fromUid);
            if (user.displayName) fromName = user.displayName;
          } catch (_) { }
        }

        await db.ref(`/users/${toUid}/notifications/${notificationId}`).set({
          type: "friend_request_accepted",
          data: { fromUid, fromName },
          timestamp: now,
          read: false,
        });
      } else if (type === "game_invite" && toUid && gameId) {
        await db.ref(`/users/${toUid}/notifications/${notificationId}`).set({
          type: "game_invite",
          data: { gameId },
          timestamp: now,
          read: false,
        });
      } else if (type === "game_reminder" && gameId) {
        // Fan-out reminder to all players of the game
        const gameSnap = await db.ref(`/games/${gameId}`).once("value");
        if (gameSnap.exists()) {
          const game = gameSnap.val() || {};
          const players: string[] = Array.isArray(game.players)
            ? game.players
            : Object.values(game.players || {}).map((v: any) => String(v));
          const updates: { [path: string]: any } = {};
          for (const uid of players) {
            const path = `/users/${uid}/notifications/${notificationId}`;
            updates[path] = {
              type: "game_reminder",
              data: { gameId, scheduled },
              timestamp: now,
              read: false,
            };
          }
          if (Object.keys(updates).length) {
            await db.ref().update(updates);
          }
        }
      } else {
        // Unknown notification type - log for debugging
        console.log(`[DEBUG] onMailNotificationCreate: Unknown notification type "${type}" for notificationId ${notificationId}, payload:`, JSON.stringify(payload));
      }

      // Mark as processed and remove the queued mail notification
      await processedRef.set({ ts: now, type });
      await db.ref(`/mail/notifications/${notificationId}`).remove();
    } catch (e) {
      console.error("Error processing mail notification:", e);
    }
  }
);

// Cleanup when a game is deleted: remove joined indexes, invites, and related notifications
export const onGameDelete = onValueDeleted("/games/{gameId}", async (event) => {
  const gameId = event.params.gameId as string;
  const db = admin.database();
  try {
    const usersSnap = await db.ref("/users").once("value");
    const users = usersSnap.val() || {};
    const updates: { [path: string]: null } = {};
    for (const uid of Object.keys(users)) {
      updates[`/users/${uid}/joinedGames/${gameId}`] = null;
      updates[`/users/${uid}/gameInvites/${gameId}`] = null;
      const notifs = (users[uid]?.notifications) || {};
      for (const nid of Object.keys(notifs)) {
        if (notifs[nid]?.data?.gameId === gameId) {
          updates[`/users/${uid}/notifications/${nid}`] = null;
        }
      }
    }
    if (Object.keys(updates).length) {
      await db.ref().update(updates);
    }
  } catch (e) {
    console.error("Error cleaning up after game delete:", e);
  }
});

function toDisplayNameLower(name?: string | null): string | null {
  if (!name) return null;
  const trimmed = name.trim();
  if (!trimmed) return null;
  return trimmed.toLowerCase();
}

function deriveNameLowerFromEmail(email?: string | null): string | null {
  if (!email) return null;
  const prefix = email.split("@")[0] ?? "";
  const cleaned = prefix.replace(/[^A-Za-z]/g, "");
  const base = (cleaned || prefix).trim();
  if (!base) return null;
  return base.toLowerCase();
}

export const cleanupAuthUserDelete = onUserDeleted(async (event) => {
  const uid = event.data?.uid;
  if (!uid) return;

  const db = admin.database();
  const updates: Record<string, any> = {
    [`/users/${uid}`]: null,
    [`/publicProfiles/${uid}`]: null,
  };

  const rawEmail = event.data?.email;
  const email =
    typeof rawEmail === "string" && rawEmail.trim().length
      ? rawEmail.trim().toLowerCase()
      : undefined;
  if (email) {
    const emailHash = createHash("sha256").update(email).digest("hex");
    updates[`/usersByEmailHash/${emailHash}`] = null;
  }

  const displayNameLower = toDisplayNameLower(event.data?.displayName);
  if (displayNameLower) {
    updates[`/usersByDisplayNameLower/${displayNameLower}/${uid}`] = null;
  }

  const derivedNameLower = deriveNameLowerFromEmail(email);
  if (derivedNameLower) {
    updates[`/usersByDisplayNameLower/${derivedNameLower}/${uid}`] = null;
  }

  try {
    const tokensSnap = await db.ref("/friendTokens").once("value");
    const tokens = tokensSnap.val() as Record<string, any> | null;
    if (tokens) {
      for (const [tokenId, tokenData] of Object.entries(tokens)) {
        const owner = tokenData?.uid ?? tokenData?.ownerUid;
        if (owner === uid) {
          updates[`/friendTokens/${tokenId}`] = null;
        }
      }
    }
  } catch (error) {
    console.error("Error loading friend tokens during auth delete cleanup:", error);
  }

  try {
    if (Object.keys(updates).length > 0) {
      await db.ref().update(updates);
    }
  } catch (error) {
    console.error("Error cleaning database during auth delete cleanup:", error);
  }

  try {
    await admin
      .storage()
      .bucket()
      .file(`users/${uid}/profile.jpg`)
      .delete({ ignoreNotFound: true });
  } catch (error: any) {
    if (error?.code !== 404) {
      console.error("Error deleting profile image during auth delete cleanup:", error);
    }
  }
});

// Cleanup when a user is deleted: remove invites and player entries
export const onUserDelete = onValueDeleted("/users/{uid}", async (event) => {
  const uid = event.params.uid as string;
  const db = admin.database();
  try {
    const gamesSnap = await db.ref("/games").once("value");
    const games = gamesSnap.val() || {};
    const updates: { [path: string]: any } = {};
    for (const gid of Object.keys(games)) {
      updates[`/games/${gid}/invites/${uid}`] = null;
      // players may be array or object; handle both
      const game = games[gid] || {};
      const players = game.players;
      if (Array.isArray(players)) {
        const filtered = players.filter((p: string) => p !== uid);
        updates[`/games/${gid}/players`] = filtered;
        updates[`/games/${gid}/currentPlayers`] = filtered.length;
      } else if (players && typeof players === 'object') {
        // If modeled as map, just remove key if present
        updates[`/games/${gid}/players/${uid}`] = null;
      }
    }
    if (Object.keys(updates).length) await db.ref().update(updates);
  } catch (e) {
    console.error("Error cleaning up after user delete:", e);
  }
});

// Enforce last-write-wins metadata and monotonic version on game updates
export const onGameUpdate = onValueWritten("/games/{gameId}", async (event) => {
  const before = event.data.before.val();
  const after = event.data.after.val() || {};
  if (!after) return;

  // Only update metadata if this is an actual update (game existed before)
  // New game creations should not have updatedAt set by this function
  const isCreation = !event.data.before.exists();
  if (isCreation) {
    // For new games, only set version if not already set
    // IMPORTANT: Don't update updatedAt during creation - it should equal createdAt
    // Also check if updatedAt is already correctly set to createdAt (or not set)
    const updates: { [key: string]: any } = {};
    if (!after.version) {
      updates.version = 1;
    }
    // Ensure updatedAt is not set or equals createdAt for new games
    // This prevents the "Modified" badge from appearing on newly created games
    const createdAtMs = after.createdAt;
    const updatedAtMs = after.updatedAt;
    if (updatedAtMs && createdAtMs && updatedAtMs !== createdAtMs) {
      // Fix: set updatedAt to match createdAt for new games
      updates.updatedAt = createdAtMs;
    }

    if (Object.keys(updates).length > 0) {
      await event.data.after.ref.update(updates);
    }
    return;
  }

  // This is an update - check if it's an organizer edit or just player participation changes
  const beforeData = before || {};

  // Skip if this is just a metadata update from this function (version/updatedAt only)
  // This prevents infinite loops when we update version during creation
  // Check if only version and/or updatedAt changed, and nothing else
  let onlyMetadataChanged = true;
  for (const key in after) {
    if (key !== 'version' && key !== 'updatedAt') {
      if (beforeData[key] !== after[key]) {
        onlyMetadataChanged = false;
        break;
      }
    }
  }
  // Also check if any keys were removed
  for (const key in beforeData) {
    if (key !== 'version' && key !== 'updatedAt' && !(key in after)) {
      onlyMetadataChanged = false;
      break;
    }
  }

  if (onlyMetadataChanged) {
    // Only version/updatedAt changed, likely from this function's own update
    // Don't process further to avoid loops
    return;
  }

  // Primary indicator: if lastOrganizerEditAt was updated, it's definitely an organizer edit
  const beforeLastEdit = beforeData.lastOrganizerEditAt;
  const afterLastEdit = after.lastOrganizerEditAt;
  const isOrganizerEdit = afterLastEdit && afterLastEdit !== beforeLastEdit;

  // If lastOrganizerEditAt wasn't set, check if only participant fields changed
  // Participant fields are: players, currentPlayers, and nested invites/{uid}/status
  // These changes (player joins/leaves) should NOT trigger updatedAt
  let onlyParticipantFieldsChanged = false;
  if (!isOrganizerEdit) {
    // Check what fields actually changed (excluding metadata)
    const changedFields = new Set<string>();
    for (const key in after) {
      if (key === 'version' || key === 'updatedAt' || key === 'updatedBy' || key === 'lastOrganizerEditAt') {
        continue; // Skip metadata fields
      }
      if (beforeData[key] !== after[key]) {
        changedFields.add(key);
      }
    }

    // Check if ONLY participant fields changed:
    // - players, currentPlayers (when players join/leave)
    // - invites/{uid}/status (when players accept/decline invites)
    const participantFields = ['players', 'currentPlayers'];
    const participantOnlyFields = new Set(['players', 'currentPlayers', 'invites']);

    // First, check if only players/currentPlayers changed
    if (changedFields.size > 0 &&
      changedFields.size <= participantFields.length &&
      Array.from(changedFields).every(field => participantFields.includes(field))) {
      onlyParticipantFieldsChanged = true;
    }
    // Otherwise, check if players/currentPlayers AND invites changed (player accept scenario)
    else if (changedFields.size > 0 &&
      changedFields.size <= participantOnlyFields.size &&
      Array.from(changedFields).every(field => participantOnlyFields.has(field))) {
      // Verify invites only had status changes (not new invites added)
      if (changedFields.has('invites')) {
        const beforeInvites = beforeData.invites || {};
        const afterInvites = after.invites || {};
        const beforeInviteUids = Object.keys(beforeInvites);
        const afterInviteUids = Object.keys(afterInvites);

        // Check if only invite statuses changed or new invites were added
        // Both cases are participant-related actions, not game modifications
        const newInvitesAdded = afterInviteUids.length > beforeInviteUids.length &&
          beforeInviteUids.every(uid => afterInviteUids.includes(uid));
        const sameInvitesStatusChanged =
          beforeInviteUids.length === afterInviteUids.length &&
          beforeInviteUids.every(uid => afterInviteUids.includes(uid));

        if (newInvitesAdded || sameInvitesStatusChanged) {
          // Check existing invites: only status should change (for status updates)
          // Or new invites are just being added (organizer sending invites)
          let onlyParticipantInviteChanges = true;
          for (const uid of beforeInviteUids) {
            const beforeInvite = beforeInvites[uid] || {};
            const afterInvite = afterInvites[uid] || {};
            // Check if anything other than status changed
            for (const key in afterInvite) {
              if (key !== 'status' && beforeInvite[key] !== afterInvite[key]) {
                onlyParticipantInviteChanges = false;
                break;
              }
            }
            if (!onlyParticipantInviteChanges) break;
          }
          // New invites are also participant-related (organizer inviting people, not modifying game)
          if (onlyParticipantInviteChanges || newInvitesAdded) {
            onlyParticipantFieldsChanged = true;
          }
        }
      } else {
        // Only players/currentPlayers changed, no invites
        onlyParticipantFieldsChanged = true;
      }
    }
  }

  // Only set updatedAt if this is an organizer edit, not just a player join/leave/accept
  const shouldSetUpdatedAt = isOrganizerEdit || !onlyParticipantFieldsChanged;

  // Skip version/updatedAt updates entirely if only participant fields changed
  // This prevents unnecessary writes and potential notification triggers
  if (onlyParticipantFieldsChanged && !isOrganizerEdit) {
    console.log(`Skipping version/updatedAt update for game ${event.params.gameId} - only participant fields changed (invites/players)`);
    return;
  }

  try {
    const currentVersion = Number(beforeData.version ?? 0);
    const incomingVersion = Number(after.version ?? currentVersion);
    const nextVersion = isNaN(incomingVersion) || incomingVersion <= currentVersion
      ? currentVersion + 1
      : incomingVersion;

    const updates: { [key: string]: any } = { version: nextVersion };

    // Only set updatedAt for organizer edits, not for player participation changes
    if (shouldSetUpdatedAt) {
      updates.updatedAt = Date.now();
    }

    await event.data.after.ref.update(updates);
  } catch (e) {
    console.error("Error enforcing game version/update metadata:", e);
  }
});

// Process notification requests and write to user's notifications
export const processNotificationRequest = onValueCreated(
  "/notification_requests/{requestId}",
  async (event) => {
    const request = event.data.val();
    const requestId = event.params.requestId as string;

    if (!request) return;

    try {
      const { recipientUid, type, data, timestamp, read } = request;

      // Write the notification to the user's notifications path
      await admin.database()
        .ref(`/users/${recipientUid}/notifications/${requestId}`)
        .set({
          type,
          data,
          timestamp,
          read,
        });

      console.log(`Notification request processed for user ${recipientUid}, type: ${type}, requestId: ${requestId}`);

      // Log specifically for game_modified to trace source
      if (type === "game_modified") {
        console.log(`[DEBUG] game_modified notification created via processNotificationRequest - recipientUid: ${recipientUid}, requestId: ${requestId}, data:`, JSON.stringify(data));
      }

      // Clean up the request
      await admin.database()
        .ref(`/notification_requests/${requestId}`)
        .remove();

    } catch (error) {
      console.error("Error processing notification request:", error);
    }
  }
);

// RTDB → push notifications
export const sendNotification = onValueCreated(
  "/users/{userId}/notifications/{notificationId}",
  async (event) => {
    const notification = event.data.val();
    const userId = event.params.userId as string;
    const notificationId = event.params.notificationId as string;

    if (!notification || notification.read) return;

    // Log all notifications for debugging to find where game_modified comes from
    if (notification.type === "game_modified") {
      console.log(`[DEBUG] game_modified notification detected - userId: ${userId}, notificationId: ${notificationId}, data:`, JSON.stringify(notification.data));
    }

    try {
      const userTokensSnapshot = await admin
        .database()
        .ref(`/users/${userId}/fcmTokens`)
        .once("value");

      const tokensObj = userTokensSnapshot.val();
      if (!tokensObj) {
        console.log(`No FCM tokens found for user ${userId}`);
        return;
      }

      const tokenList = Object.keys(tokensObj);
      if (tokenList.length === 0) {
        console.log(`No valid FCM tokens for user ${userId}`);
        return;
      }

      let title = "SMARTPLAYER";
      let body = "You have a new notification";
      const data: { [key: string]: string } = {
        type: notification.type || "default",
        notificationId,
      };

      switch (notification.type) {
        case "friend_request":
          title = "New Friend Request";
          body = `${notification.data?.fromName || "Someone"} sent you a friend request`;
          data.route = "/friends";
          break;

        case "friend_request_accepted":
          title = "Friend Request Accepted";
          body = `${notification.data?.fromName || "Someone"} accepted your friend request`;
          data.route = "/friends";
          break;

        case "game_invite":
          title = "Game Invitation";
          {
            const fromName = notification.data?.fromName || "Someone";
            const rawSport = (notification.data?.sport || "game").toString();
            const sportWord = rawSport.toLowerCase() === "soccer" ? "football" : rawSport;
            body = `${fromName} invited you to play a ${sportWord} match!`;
          }
          data.route = "/my-games";
          data.gameId = notification.data?.gameId || "";
          break;

        case "game_cancelled":
          title = "Game Cancelled";
          body = `The ${notification.data?.sport || "game"} at ${notification.data?.location || "your location"
            } has been cancelled`;
          data.route = "/my-games";
          data.gameId = notification.data?.gameId || "";
          break;

        case "game_player_joined":
          title = "Player Joined Your Game";
          body = `${notification.data?.fromName || "Someone"} joined your ${notification.data?.sport || "game"}`;
          data.route = "/my-games";
          data.gameId = notification.data?.gameId || "";
          break;

        case "invite_accepted":
          title = "Invite Accepted";
          body = `${notification.data?.fromName || "Someone"} accepted your ${notification.data?.sport || "game"} invite`;
          data.route = "/my-games";
          data.gameId = notification.data?.gameId || "";
          break;

        case "invite_declined":
          title = "Invite Declined";
          body = `${notification.data?.fromName || "Someone"} declined your ${notification.data?.sport || "game"} invite`;
          data.route = "/my-games";
          data.gameId = notification.data?.gameId || "";
          break;

        case "game_edited":
          title = "Game Updated";
          const changes = notification.data?.changes || "details";
          body = `${notification.data?.fromName || "Organizer"} changed the game ${changes}`;
          data.route = "/my-games";
          data.gameId = notification.data?.gameId || "";
          break;

        default:
          title = notification.data?.title || "SMARTPLAYER";
          body = notification.data?.message || "You have a new notification";
          data.route = notification.data?.route || "/home";

          // Log unknown notification types to trace where they come from
          if (notification.type !== "default") {
            console.log(`[DEBUG] sendNotification: Unknown notification type "${notification.type}" for userId ${userId}, notificationId ${notificationId}, data:`, JSON.stringify(notification.data));
          }
      }

      const message: admin.messaging.MulticastMessage = {
        notification: { title, body },
        data,
        tokens: tokenList,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        `Successfully sent notification to ${response.successCount} tokens for user ${userId}`
      );

      if (response.failureCount > 0) {
        console.log(`Failed to send to ${response.failureCount} tokens`);
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const code = resp.error.code;
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(tokenList[idx]);
            }
          }
        });
        if (invalidTokens.length > 0) {
          const updates: { [key: string]: null } = {};
          invalidTokens.forEach((t) => {
            updates[`/users/${userId}/fcmTokens/${t}`] = null;
          });
          await admin.database().ref().update(updates);
          console.log(`Removed ${invalidTokens.length} invalid tokens`);
        }
      }
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  }
);

// Invite trigger → push directly to invitee
export const onGameInviteCreate = onValueCreated(
  "/games/{gameId}/invites/{inviteeUid}",
  async (event) => {
    const inviteeUid = event.params.inviteeUid as string;
    const gameId = event.params.gameId as string;
    const invite = event.data.val() || {};

    try {
      const tokensSnap = await admin
        .database()
        .ref(`/users/${inviteeUid}/fcmTokens`)
        .once("value");
      const tokensObj = tokensSnap.val() || {};
      const tokens = Object.keys(tokensObj);
      if (!tokens.length) {
        console.log(`No tokens for invitee ${inviteeUid}`);
        return;
      }

      // Get game data to retrieve sport and organizerId
      const gameSnap = await admin
        .database()
        .ref(`/games/${gameId}`)
        .once("value");
      const game = gameSnap.val() || {};
      const organizerId = (game.organizerId || invite.organizerId || "").toString();
      const rawSport = (game.sport || invite.sport || "game").toString();

      // Resolve organizer display name with graceful fallbacks
      let organizerName: string = "Someone";
      if (organizerId) {
        try {
          const user = await admin.auth().getUser(organizerId);
          if (user.displayName) organizerName = user.displayName;
        } catch (_) {
          // Fallback to invite data if available
          organizerName = invite.organizerName || invite.fromName || "Someone";
        }
      } else {
        organizerName = invite.organizerName || invite.fromName || "Someone";
      }

      // Map soccer to "football"; otherwise use sport value
      const sportWord = rawSport.toLowerCase() === "soccer" ? "football" : rawSport;

      const message: admin.messaging.MulticastMessage = {
        notification: {
          title: "Game Invitation",
          body: `${organizerName} invited you to a ${sportWord} game!`,
        },
        data: {
          type: "discover",
          gameId,
        },
        tokens,
      };

      const res = await admin.messaging().sendEachForMulticast(message);
      console.log(
        `Invite push: sent ${res.successCount} of ${tokens.length} to invitee ${inviteeUid} for game ${gameId}`
      );

      if (res.failureCount > 0) {
        const invalid: string[] = [];
        res.responses.forEach((r, i) => {
          if (!r.success && r.error) {
            const code = r.error.code;
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              invalid.push(tokens[i]);
            }
          }
        });
        if (invalid.length) {
          const updates: { [key: string]: null } = {};
          invalid.forEach((t) => {
            updates[`/users/${inviteeUid}/fcmTokens/${t}`] = null;
          });
          await admin.database().ref().update(updates);
          console.log(
            `Removed ${invalid.length} invalid tokens for ${inviteeUid}`
          );
        }
      }
    } catch (err) {
      console.error("Error sending invite push:", err);
    }
  }
);

// Nightly cleanup
export const cleanupOldNotifications = onSchedule(
  { schedule: "0 2 * * *", timeZone: "Europe/Amsterdam" },
  async () => {
    const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
    try {
      const usersSnapshot = await admin.database().ref("/users").once("value");
      const users = usersSnapshot.val();
      if (!users) return;

      const updates: { [key: string]: null } = {};

      for (const [userId, userData] of Object.entries(users)) {
        if (
          userData &&
          typeof userData === "object" &&
          "notifications" in (userData as any)
        ) {
          const notifications = (userData as any).notifications;
          if (notifications) {
            for (const [notificationId, notification] of Object.entries(
              notifications
            )) {
              const notif = notification as any;
              if (notif.timestamp && notif.timestamp < thirtyDaysAgo) {
                updates[`/users/${userId}/notifications/${notificationId}`] =
                  null;
              }
            }
          }
        }
      }

      if (Object.keys(updates).length > 0) {
        await admin.database().ref().update(updates);
        console.log(
          `Cleaned up ${Object.keys(updates).length} old notifications`
        );
      }
    } catch (error) {
      console.error("Error cleaning up old notifications:", error);
    }
  }
);

// Invite status change → notify organizer (accepted/declined)
export const onInviteStatusChange = onValueWritten(
  "/games/{gameId}/invites/{inviteeUid}/status",
  async (event) => {
    const gameId = event.params.gameId as string;
    const inviteeUid = event.params.inviteeUid as string;
    const before = (event.data.before.val() || "").toString();
    const after = (event.data.after.val() || "").toString();

    if (!after || after === before) return; // no-op
    if (after !== "accepted" && after !== "declined") return; // only these

    try {
      // Load game to find organizer and sport
      const gameSnap = await admin.database().ref(`/games/${gameId}`).once("value");
      if (!gameSnap.exists()) return;
      const game = gameSnap.val() || {};
      const organizerId: string = (game.organizerId || "").toString();
      if (!organizerId || organizerId === inviteeUid) return;
      const rawSport = (game.sport || "game").toString();
      const sportWord = rawSport.toLowerCase() === "soccer" ? "football" : rawSport;

      // Resolve invitee display name
      let fromName = "Someone";
      try {
        const user = await admin.auth().getUser(inviteeUid);
        if (user.displayName) fromName = user.displayName;
      } catch (_) { }

      // Organizer tokens
      const tokensSnap = await admin
        .database()
        .ref(`/users/${organizerId}/fcmTokens`)
        .once("value");
      const tokensObj = tokensSnap.val() || {};
      const tokens: string[] = Object.keys(tokensObj);
      if (!tokens.length) return;

      const isAccepted = after === "accepted";
      const title = isAccepted ? "Invite Accepted" : "Invite Declined";
      const body = isAccepted
        ? `${fromName} accepted your ${sportWord} invite`
        : `${fromName} declined your ${sportWord} invite`;

      const msg: admin.messaging.MulticastMessage = {
        notification: { title, body },
        data: {
          type: isAccepted ? "invite_accepted" : "invite_declined",
          route: "/my-games",
          gameId,
        },
        tokens,
      };

      const res = await admin.messaging().sendEachForMulticast(msg);
      console.log(
        `Invite status ${after}: sent ${res.successCount}/${tokens.length} to organizer ${organizerId} for game ${gameId}`
      );

      if (res.failureCount > 0) {
        const invalid: string[] = [];
        res.responses.forEach((r, i) => {
          if (!r.success && r.error) {
            const code = r.error.code;
            if (
              code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered"
            ) {
              invalid.push(tokens[i]);
            }
          }
        });
        if (invalid.length) {
          const updates: { [key: string]: null } = {};
          invalid.forEach((t) => {
            updates[`/users/${organizerId}/fcmTokens/${t}`] = null;
          });
          await admin.database().ref().update(updates);
        }
      }
    } catch (e) {
      console.error("Error processing invite status change:", e);
    }
  }
);

// Extract info from raw text block
function extractInfoDict(rawText: string): {
  location: string;
  target_group: string;
  cost: string;
  date_time: string;
} {
  const lines = rawText.split("\n").map(line => line.trim()).filter(line => line);
  const info = {
    location: "-",
    target_group: "-",
    cost: "-",
    date_time: "-"
  };
  let currentKey: string | null = null;

  for (const line of lines) {
    const lower = line.toLowerCase();
    if (lower.startsWith("locatie") || lower.startsWith("location")) {
      currentKey = "location";
    } else if (lower.startsWith("doelgroep") || lower.startsWith("target group") || lower.startsWith("targetgroup")) {
      currentKey = "target_group";
    } else if (lower.startsWith("kosten") || lower.startsWith("cost")) {
      currentKey = "cost";
    } else if (lower.startsWith("datum") || lower.startsWith("date")) {
      currentKey = "date_time";
    } else if (currentKey) {
      if (info[currentKey as keyof typeof info] === "-") {
        info[currentKey as keyof typeof info] = line;
      } else {
        info[currentKey as keyof typeof info] += " | " + line;
      }
    }
  }

  // Clean up trailing junk from date_time
  if (info.date_time !== "-") {
    info.date_time = info.date_time.split("|")[0].trim();
  }

  return info;
}

// Determine if event is recurring
function isRecurringDateTime(input: string): boolean {
  const lower = input.toLowerCase();
  return !(lower.includes("1x") || lower.includes("eenmalig") || lower.includes("op inschrijving"));
}

// Scrape sport events from s-port.nl for a given locale ('en' | 'nl')
async function scrapeSportEvents(locale: 'en' | 'nl' = 'en'): Promise<any[]> {
  let browser;
  try {
    browser = await puppeteer.launch({
      headless: true,
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--single-process",
        "--disable-software-rasterizer"
      ],
      executablePath: puppeteer.executablePath()
    });

    const page = await browser.newPage();

    // Set language cookie for requested locale
    await page.setCookie({
      name: 'locale',
      value: locale,
      path: '/',
      domain: 'www.aanbod.s-port.nl'
    });

    // Load activities page
    await page.goto(
      "https://www.aanbod.s-port.nl/activiteiten?gemeente%5B0%5D=40&projecten%5B0%5D=5395&sort=name&order=asc",
      { waitUntil: "networkidle2" }
    );

    // Scroll to load all content
    for (let i = 0; i < 10; i++) {
      await page.evaluate(() => {
        window.scrollTo(0, document.body.scrollHeight);
      });
      await page.waitForTimeout(2000);
    }

    // Wait for activity cards
    await page.waitForSelector(".activity", { timeout: 15000 });

    // Extract all events
    const events = await page.evaluate(() => {
      const cards = Array.from(document.querySelectorAll(".activity"));
      const results: any[] = [];

      for (const card of cards) {
        try {
          const titleElem = card.querySelector("h2 a");
          const title = titleElem?.textContent?.trim() || "-";
          const url = titleElem?.getAttribute("href") || "-";

          const imageElem = card.querySelector("img");
          const imageUrl = imageElem?.getAttribute("src") || "";

          const organizerElem = card.querySelector("span.location");
          const organizer = organizerElem?.textContent?.trim() || "-";

          const infoElem = card.querySelector(".info");
          const rawInfo = infoElem?.textContent?.trim() || "";

          results.push({
            title,
            url,
            organizer,
            rawInfo,
            imageUrl
          });
        } catch (err) {
          console.error("Error extracting card:", err);
        }
      }

      return results;
    });

    // Process events
    const processedEvents = events.map((event: any) => {
      const info = extractInfoDict(event.rawInfo || "");
      const cost = info.cost.trim().replace(/^·\s*/, "").trim();
      const isRecurring = isRecurringDateTime(info.date_time);

      return {
        title: event.title,
        url: event.url,
        organizer: event.organizer,
        location: info.location,
        target_group: info.target_group,
        cost: cost,
        date_time: info.date_time,
        imageUrl: event.imageUrl,
        isRecurring
      };
    });

    console.log(`Scraped ${processedEvents.length} events for locale ${locale}`);
    return processedEvents;

  } catch (error) {
    console.error("Error scraping events:", error);
    throw error;
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

// Scheduled function to fetch sport events daily
export const fetchSportEvents = onSchedule(
  {
    schedule: "0 2 * * *", // Every day at 2 AM
    timeZone: "Europe/Amsterdam",
    memory: "1GiB",
    timeoutSeconds: 540, // 9 minutes
  },
  async (event) => {
    console.log("Starting daily event scrape...");

    try {
      const [eventsEn, eventsNl] = await Promise.all([
        scrapeSportEvents('en'),
        scrapeSportEvents('nl'),
      ]);

      // Save to Firebase Realtime Database
      const db = admin.database();
      await db.ref("events/latest").set({
        events_en: eventsEn,
        events_nl: eventsNl,
        // Backward compatibility for older app versions
        events: eventsEn,
        lastUpdated: Date.now(),
      });

      console.log(`Stored EN:${eventsEn.length} NL:${eventsNl.length} events`);
      return;
    } catch (error) {
      console.error("Error in fetchSportEvents:", error);
      throw error;
    }
  }
);

// Manual HTTP trigger to fetch and store events on-demand
export const manualFetchEvents = onRequest(
  {
    region: "europe-west1",
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (req, res) => {
    try {
      const lang = (req.query.lang as string | undefined)?.toLowerCase();
      if (lang === 'en' || lang === 'nl') {
        const events = await scrapeSportEvents(lang);
        const db = admin.database();
        await db.ref("events/latest").update({
          [lang === 'en' ? 'events_en' : 'events_nl']: events,
          // Keep default events pointer to EN
          ...(lang === 'en' ? { events } : {}),
          lastUpdated: Date.now(),
        });
        res.json({ success: true, count: events.length, locale: lang });
        return;
      }

      const [eventsEn, eventsNl] = await Promise.all([
        scrapeSportEvents('en'),
        scrapeSportEvents('nl'),
      ]);
      const db = admin.database();
      await db.ref("events/latest").set({
        events_en: eventsEn,
        events_nl: eventsNl,
        events: eventsEn,
        lastUpdated: Date.now(),
      });
      res.json({ success: true, count_en: eventsEn.length, count_nl: eventsNl.length });
    } catch (error: any) {
      console.error("Error in manualFetchEvents:", error);
      res.status(500).json({ error: error?.message || "Unknown error" });
    }
  }
);
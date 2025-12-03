import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
// import { onUserDeleted } from "firebase-functions/v2/auth"; // Temporarily disabled - v2/auth not available in current firebase-functions version
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onValueCreated, onValueDeleted, onValueWritten } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
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
      } else if ((type === "game_edited" || type === "game_cancelled") && gameId) {
        // Fan-out game edited/cancelled notifications to all players and invited users (excluding organizer)
        console.log(`[${type}] Processing notification for game ${gameId}`);
        const gameSnap = await db.ref(`/games/${gameId}`).once("value");
        if (!gameSnap.exists()) {
          console.error(`[${type}] Game ${gameId} does not exist`);
          return;
        }

        const game = gameSnap.val() || {};
        const organizerId = (game.organizerId || "").toString();
        console.log(`[${type}] Game ${gameId} found, organizer: ${organizerId}`);

        // Get all players who have joined the game
        let players: string[] = [];
        if (Array.isArray(game.players)) {
          players = game.players.map((v: any) => String(v));
        } else if (game.players && typeof game.players === "object") {
          players = Object.values(game.players).map((v: any) => String(v));
        }
        console.log(`[${type}] Found ${players.length} players: ${players.join(", ")}`);

        // Get all users who have been invited (pending or accepted)
        const invitesSnap = await db.ref(`/games/${gameId}/invites`).once("value");
        const invitedUsers = new Set<string>();
        if (invitesSnap.exists()) {
          const invites = invitesSnap.val() || {};
          for (const uid in invites) {
            const invite = invites[uid];
            // Handle both Map and String formats
            let status = "pending";
            if (typeof invite === "object" && invite !== null) {
              status = invite.status || "pending";
            } else if (typeof invite === "string") {
              status = invite;
            }
            // Include pending and accepted invites (not declined)
            if (status === "pending" || status === "accepted") {
              invitedUsers.add(uid);
            }
          }
        }
        console.log(`[${type}] Found ${invitedUsers.size} invited users: ${Array.from(invitedUsers).join(", ")}`);

        // Combine players and invited users, filter out organizer
        const allUsersToNotify = new Set<string>([...players, ...invitedUsers]);
        allUsersToNotify.delete(organizerId);

        console.log(`[${type}] Total users to notify: ${allUsersToNotify.size} (after excluding organizer)`);

        if (allUsersToNotify.size === 0) {
          console.log(`[${type}] No users to notify for game ${gameId} (organizer: ${organizerId}, players: ${players.length}, invites: ${invitedUsers.size})`);
          return;
        }

        // Get game details for notification
        const sport = (game.sport || "game").toString();
        const location = (game.location || "your location").toString();
        const organizerName = (game.organizerName || "Organizer").toString();

        const updates: { [path: string]: any } = {};
        for (const uid of allUsersToNotify) {
          const path = `/users/${uid}/notifications/${notificationId}`;
          if (type === "game_edited") {
            updates[path] = {
              type: "game_edited",
              data: { gameId, sport, location, fromName: organizerName, changes: "details" },
              timestamp: now,
              read: false,
            };
          } else if (type === "game_cancelled") {
            updates[path] = {
              type: "game_cancelled",
              data: { gameId, sport, location },
              timestamp: now,
              read: false,
            };
          }
        }

        if (Object.keys(updates).length > 0) {
          await db.ref().update(updates);
          console.log(`[${type}] Successfully sent ${Object.keys(updates).length} notifications for game ${gameId}`);
        } else {
          console.error(`[${type}] Failed to create notification updates for game ${gameId}`);
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

// Temporarily disabled - onUserDeleted import not available
/*
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
*/

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

// Cleanup old cancelled and past games
// Runs nightly at 3 AM (1 hour after notification cleanup)
export const cleanupOldGames = onSchedule(
  { schedule: "0 3 * * *", timeZone: "Europe/Amsterdam" },
  async () => {
    const db = admin.database();
    const now = Date.now();
    const ninetyDaysAgo = now - 90 * 24 * 60 * 60 * 1000; // 90 days in milliseconds
    const oneYearAgo = now - 365 * 24 * 60 * 60 * 1000; // 1 year in milliseconds

    try {
      const gamesSnapshot = await db.ref("/games").once("value");
      const games = gamesSnapshot.val();
      if (!games) {
        console.log("No games found for cleanup");
        return;
      }

      const gamesToDelete: string[] = [];
      const updates: { [path: string]: null } = {};

      // First pass: identify games to delete
      for (const [gameId, gameData] of Object.entries(games)) {
        const game = gameData as any;
        if (!game) continue;

        let shouldDelete = false;
        let reason = "";

        // Check if game is cancelled and cancelled more than 90 days ago
        if (game.isActive === false && game.canceledAt) {
          const canceledAt = typeof game.canceledAt === "number"
            ? game.canceledAt
            : parseInt(game.canceledAt);
          if (canceledAt && canceledAt < ninetyDaysAgo) {
            shouldDelete = true;
            reason = `cancelled ${Math.floor((now - canceledAt) / (24 * 60 * 60 * 1000))} days ago`;
          }
        }

        // Check if game date is more than 1 year in the past (regardless of active status)
        // This catches old historical games that should be archived
        if (!shouldDelete && game.dateTime) {
          let gameDate: number;
          if (typeof game.dateTime === "number") {
            // If stored as timestamp
            gameDate = game.dateTime;
          } else if (typeof game.dateTime === "string") {
            // If stored as ISO string, parse it
            const parsed = new Date(game.dateTime).getTime();
            if (isNaN(parsed)) continue;
            gameDate = parsed;
          } else {
            continue;
          }

          if (gameDate < oneYearAgo) {
            shouldDelete = true;
            reason = `game date was ${Math.floor((now - gameDate) / (24 * 60 * 60 * 1000))} days ago`;
          }
        }

        if (shouldDelete) {
          gamesToDelete.push(gameId);
          console.log(`Marking game ${gameId} for deletion: ${reason}`);
        }
      }

      if (gamesToDelete.length === 0) {
        console.log("No old games found to clean up");
        return;
      }

      // Second pass: collect all related data to clean up
      const usersSnapshot = await db.ref("/users").once("value");
      const users = usersSnapshot.val() || {};

      // Get all games data for slot cleanup
      for (const gameId of gamesToDelete) {
        const game = games[gameId] as any;
        if (!game) continue;

        // Delete the game itself (this will trigger onGameDelete for some cleanup)
        updates[`/games/${gameId}`] = null;

        // Clean up organizer's createdGames index
        if (game.organizerId) {
          updates[`/users/${game.organizerId}/createdGames/${gameId}`] = null;
        }

        // Clean up slot reservation if game has slot info
        if (game.slotDate && game.slotField && game.slotTime) {
          updates[`/slots/${game.slotDate}/${game.slotField}/${game.slotTime}`] = null;
        }

        // Clean up pending invite index for all users
        for (const uid of Object.keys(users)) {
          updates[`/pendingInviteIndex/${uid}/${gameId}`] = null;
        }
      }

      // Note: onGameDelete will automatically clean up:
      // - /users/{uid}/joinedGames/{gameId}
      // - /users/{uid}/gameInvites/{gameId}
      // - Related notifications
      // But we clean up createdGames and pendingInviteIndex here since onGameDelete
      // might not catch all cases

      // Execute all deletions atomically
      if (Object.keys(updates).length > 0) {
        await db.ref().update(updates);
        console.log(
          `Successfully cleaned up ${gamesToDelete.length} old games and related data`
        );
      }
    } catch (error) {
      console.error("Error cleaning up old games:", error);
      throw error; // Re-throw to trigger Cloud Functions retry
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

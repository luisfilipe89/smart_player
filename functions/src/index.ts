import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
// Note: onUserDeleted from v2/auth may not be available in current firebase-functions version
// Using onValueDeleted("/users/{uid}") instead, which triggers when user data is deleted
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
      const matchId = (payload.matchId || "").toString();

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
      } else if (type === "match_invite" && toUid && matchId) {
        await db.ref(`/users/${toUid}/notifications/${notificationId}`).set({
          type: "match_invite",
          data: { matchId },
          timestamp: now,
          read: false,
        });
      } else if ((type === "match_edited" || type === "match_cancelled") && matchId) {
        // Fan-out match edited/cancelled notifications to all players and invited users (excluding organizer)
        console.log(`[${type}] Processing notification for match ${matchId}`);
        const matchSnap = await db.ref(`/matches/${matchId}`).once("value");
        if (!matchSnap.exists()) {
          console.error(`[${type}] Match ${matchId} does not exist`);
          return;
        }

        const match = matchSnap.val() || {};
        const organizerId = (match.organizerId || "").toString();
        console.log(`[${type}] Match ${matchId} found, organizer: ${organizerId}`);

        // Get all players who have joined the match
        let players: string[] = [];
        if (Array.isArray(match.players)) {
          players = match.players.map((v: any) => String(v));
        } else if (match.players && typeof match.players === "object") {
          players = Object.values(match.players).map((v: any) => String(v));
        }
        console.log(`[${type}] Found ${players.length} players: ${players.join(", ")}`);

        // Get all users who have been invited (pending or accepted)
        const invitesSnap = await db.ref(`/matches/${matchId}/invites`).once("value");
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
          console.log(`[${type}] No users to notify for match ${matchId} (organizer: ${organizerId}, players: ${players.length}, invites: ${invitedUsers.size})`);
          return;
        }

        // Get match details for notification
        const sport = (match.sport || "match").toString();
        const location = (match.location || "your location").toString();
        const organizerName = (match.organizerName || "Organizer").toString();

        const updates: { [path: string]: any } = {};
        for (const uid of allUsersToNotify) {
          const path = `/users/${uid}/notifications/${notificationId}`;
          if (type === "match_edited") {
            updates[path] = {
              type: "match_edited",
              data: { matchId, sport, location, fromName: organizerName, changes: "details" },
              timestamp: now,
              read: false,
            };
          } else if (type === "match_cancelled") {
            updates[path] = {
              type: "match_cancelled",
              data: { matchId, sport, location },
              timestamp: now,
              read: false,
            };
          }
        }

        if (Object.keys(updates).length > 0) {
          await db.ref().update(updates);
          console.log(`[${type}] Successfully sent ${Object.keys(updates).length} notifications for match ${matchId}`);
        } else {
          console.error(`[${type}] Failed to create notification updates for match ${matchId}`);
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

// Cleanup when a match is deleted: remove joined indexes, invites, and related notifications
export const onMatchDelete = onValueDeleted("/matches/{matchId}", async (event) => {
  const matchId = event.params.matchId as string;
  const db = admin.database();
  try {
    const usersSnap = await db.ref("/users").once("value");
    const users = usersSnap.val() || {};
    const updates: { [path: string]: null } = {};
    for (const uid of Object.keys(users)) {
      updates[`/users/${uid}/joinedMatches/${matchId}`] = null;
      updates[`/users/${uid}/matchInvites/${matchId}`] = null;
      const notifs = (users[uid]?.notifications) || {};
      for (const nid of Object.keys(notifs)) {
        if (notifs[nid]?.data?.matchId === matchId) {
          updates[`/users/${uid}/notifications/${nid}`] = null;
        }
      }
    }
    if (Object.keys(updates).length) {
      await db.ref().update(updates);
    }
  } catch (e) {
    console.error("Error cleaning up after match delete:", e);
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

// Note: We use onValueDeleted("/users/{uid}") instead of onUserDeleted from v2/auth
// because the v2/auth trigger may not be available in the current firebase-functions version.
// The app deletes /users/{uid} after auth deletion, which triggers this function.

// Cleanup when a user is deleted: remove all user-related data
// This triggers when /users/{uid} is deleted (which happens after auth deletion in the app)
// Note: Since Auth account is deleted first, we may not be able to fetch email/displayName
// for index cleanup, but that's acceptable - orphaned indexes won't cause functional issues
export const onUserDelete = onValueDeleted("/users/{uid}", async (event) => {
  const uid = event.params.uid as string;
  const db = admin.database();

  console.log(`Starting comprehensive cleanup for deleted user: ${uid}`);

  const updates: { [path: string]: any } = {};

  // 1. Clean up public profile
  updates[`/publicProfiles/${uid}`] = null;

  // 2. Try to get user data from Firebase Auth to clean up indexes
  // Note: Auth account may already be deleted, so we try-catch this
  let email: string | undefined;
  let displayName: string | undefined;
  try {
    const authUser = await admin.auth().getUser(uid);
    email = authUser.email;
    displayName = authUser.displayName || undefined;
  } catch (error: any) {
    // Auth account may already be deleted - that's okay, we'll skip index cleanup
    console.log(`Could not fetch Auth user data for ${uid} (may already be deleted): ${error?.code || error}`);
  }

  // 3. Clean up email hash index (if we have email)
  if (email && typeof email === "string") {
    const emailLower = email.trim().toLowerCase();
    if (emailLower) {
      const emailHash = createHash("sha256").update(emailLower).digest("hex");
      updates[`/usersByEmailHash/${emailHash}`] = null;
      console.log(`Removing email hash index for: ${emailHash.substring(0, 8)}...`);
    }
  }

  // 4. Clean up display name indexes (if we have displayName)
  const displayNameLower = toDisplayNameLower(displayName);
  if (displayNameLower) {
    updates[`/usersByDisplayNameLower/${displayNameLower}/${uid}`] = null;
    console.log(`Removing display name index: ${displayNameLower}`);
  }

  if (email && typeof email === "string") {
    const derivedNameLower = deriveNameLowerFromEmail(email);
    if (derivedNameLower && derivedNameLower !== displayNameLower) {
      updates[`/usersByDisplayNameLower/${derivedNameLower}/${uid}`] = null;
      console.log(`Removing derived name index: ${derivedNameLower}`);
    }
  }

  // 5. Clean up friend tokens owned by this user
  try {
    const tokensSnap = await db.ref("/friendTokens").once("value");
    const tokens = tokensSnap.val() as Record<string, any> | null;
    if (tokens) {
      let tokenCount = 0;
      for (const [tokenId, tokenData] of Object.entries(tokens)) {
        const owner = tokenData?.uid ?? tokenData?.ownerUid;
        if (owner === uid) {
          updates[`/friendTokens/${tokenId}`] = null;
          tokenCount++;
        }
      }
      if (tokenCount > 0) {
        console.log(`Removing ${tokenCount} friend token(s)`);
      }
    }
  } catch (error) {
    console.error("Error loading friend tokens during user delete cleanup:", error);
  }

  // 6. Clean up match-related data (invites and player entries)
  try {
    const matchesSnap = await db.ref("/matches").once("value");
    const matches = matchesSnap.val() || {};
    for (const mid of Object.keys(matches)) {
      updates[`/matches/${mid}/invites/${uid}`] = null;
      // players may be array or object; handle both
      const match = matches[mid] || {};
      const players = match.players;
      if (Array.isArray(players)) {
        const filtered = players.filter((p: string) => p !== uid);
        updates[`/matches/${mid}/players`] = filtered;
        updates[`/matches/${mid}/currentPlayers`] = filtered.length;
      } else if (players && typeof players === 'object') {
        // If modeled as map, just remove key if present
        updates[`/matches/${mid}/players/${uid}`] = null;
      }
    }
  } catch (e) {
    console.error("Error loading matches during user delete cleanup:", e);
  }

  // 7. Clean up pending invite index
  updates[`/pendingInviteIndex/${uid}`] = null;

  // 8. Apply all database deletions atomically
  try {
    if (Object.keys(updates).length > 0) {
      await db.ref().update(updates);
      console.log(`Successfully removed ${Object.keys(updates).length} database entries`);
    }
  } catch (error) {
    console.error("Error cleaning database during user delete cleanup:", error);
    throw error; // Re-throw to trigger retry
  }

  console.log(`Completed comprehensive cleanup for deleted user: ${uid}`);
});

// Enforce last-write-wins metadata and monotonic version on match updates
export const onMatchUpdate = onValueWritten("/matches/{matchId}", async (event) => {
  const before = event.data.before.val();
  const after = event.data.after.val() || {};
  if (!after) return;

  // Only update metadata if this is an actual update (match existed before)
  // New match creations should not have updatedAt set by this function
  const isCreation = !event.data.before.exists();
  if (isCreation) {
    // For new matches, only set version if not already set
    // IMPORTANT: Don't update updatedAt during creation - it should equal createdAt
    // Also check if updatedAt is already correctly set to createdAt (or not set)
    const updates: { [key: string]: any } = {};
    if (!after.version) {
      updates.version = 1;
    }
    // Ensure updatedAt is not set or equals createdAt for new matches
    // This prevents the "Modified" badge from appearing on newly created matches
    const createdAtMs = after.createdAt;
    const updatedAtMs = after.updatedAt;
    if (updatedAtMs && createdAtMs && updatedAtMs !== createdAtMs) {
      // Fix: set updatedAt to match createdAt for new matches
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
        // Both cases are participant-related actions, not match modifications
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
          // New invites are also participant-related (organizer inviting people, not modifying match)
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
    console.log(`Skipping version/updatedAt update for match ${event.params.matchId} - only participant fields changed (invites/players)`);
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
    console.error("Error enforcing match version/update metadata:", e);
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

      // Log specifically for match_modified to trace source
      if (type === "match_modified") {
        console.log(`[DEBUG] match_modified notification created via processNotificationRequest - recipientUid: ${recipientUid}, requestId: ${requestId}, data:`, JSON.stringify(data));
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

    // Log all notifications for debugging to find where match_modified comes from
    if (notification.type === "match_modified") {
      console.log(`[DEBUG] match_modified notification detected - userId: ${userId}, notificationId: ${notificationId}, data:`, JSON.stringify(notification.data));
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

        case "match_invite":
          title = "Match Invitation";
          {
            const fromName = notification.data?.fromName || "Someone";
            const rawSport = (notification.data?.sport || "match").toString();
            const sportWord = rawSport.toLowerCase() === "soccer" ? "football" : rawSport;
            body = `${fromName} invited you to play a ${sportWord} match!`;
          }
          data.route = "/my-matches";
          data.matchId = notification.data?.matchId || "";
          break;

        case "match_cancelled":
          title = "Match Cancelled";
          body = `The ${notification.data?.sport || "match"} at ${notification.data?.location || "your location"
            } has been cancelled`;
          data.route = "/my-matches";
          data.matchId = notification.data?.matchId || "";
          break;

        case "invite_accepted":
          title = "Invite Accepted";
          body = `${notification.data?.fromName || "Someone"} accepted your ${notification.data?.sport || "match"} invite`;
          data.route = "/my-matches";
          data.matchId = notification.data?.matchId || "";
          break;

        case "invite_declined":
          title = "Invite Declined";
          body = `${notification.data?.fromName || "Someone"} declined your ${notification.data?.sport || "match"} invite`;
          data.route = "/my-matches";
          data.matchId = notification.data?.matchId || "";
          break;

        case "match_edited":
          title = "Match Updated";
          const changes = notification.data?.changes || "details";
          body = `${notification.data?.fromName || "Organizer"} changed the match ${changes}`;
          data.route = "/my-matches";
          data.matchId = notification.data?.matchId || "";
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
export const onMatchInviteCreate = onValueCreated(
  "/matches/{matchId}/invites/{inviteeUid}",
  async (event) => {
    const inviteeUid = event.params.inviteeUid as string;
    const matchId = event.params.matchId as string;
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

      // Get match data to retrieve sport and organizerId
      const matchSnap = await admin
        .database()
        .ref(`/matches/${matchId}`)
        .once("value");
      const match = matchSnap.val() || {};
      const organizerId = (match.organizerId || invite.organizerId || "").toString();
      const rawSport = (match.sport || invite.sport || "match").toString();

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
          title: "Match Invitation",
          body: `${organizerName} invited you to a ${sportWord} match!`,
        },
        data: {
          type: "discover",
          matchId,
        },
        tokens,
      };

      const res = await admin.messaging().sendEachForMulticast(message);
      console.log(
        `Invite push: sent ${res.successCount} of ${tokens.length} to invitee ${inviteeUid} for match ${matchId}`
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

// Cleanup old cancelled and past matches
// Runs nightly at 3 AM (1 hour after notification cleanup)
export const cleanupOldMatches = onSchedule(
  { schedule: "0 3 * * *", timeZone: "Europe/Amsterdam" },
  async () => {
    const db = admin.database();
    const now = Date.now();
    const ninetyDaysAgo = now - 90 * 24 * 60 * 60 * 1000; // 90 days in milliseconds
    const oneYearAgo = now - 365 * 24 * 60 * 60 * 1000; // 1 year in milliseconds

    try {
      const matchesSnapshot = await db.ref("/matches").once("value");
      const matches = matchesSnapshot.val();
      if (!matches) {
        console.log("No matches found for cleanup");
        return;
      }

      const matchesToDelete: string[] = [];
      const updates: { [path: string]: null } = {};

      // First pass: identify matches to delete
      for (const [matchId, matchData] of Object.entries(matches)) {
        const match = matchData as any;
        if (!match) continue;

        let shouldDelete = false;
        let reason = "";

        // Check if match is cancelled and cancelled more than 90 days ago
        if (match.isActive === false && match.canceledAt) {
          const canceledAt = typeof match.canceledAt === "number"
            ? match.canceledAt
            : parseInt(match.canceledAt);
          if (canceledAt && canceledAt < ninetyDaysAgo) {
            shouldDelete = true;
            reason = `cancelled ${Math.floor((now - canceledAt) / (24 * 60 * 60 * 1000))} days ago`;
          }
        }

        // Check if match date is more than 1 year in the past (regardless of active status)
        // This catches old historical matches that should be archived
        if (!shouldDelete && match.dateTime) {
          let matchDate: number;
          if (typeof match.dateTime === "number") {
            // If stored as timestamp
            matchDate = match.dateTime;
          } else if (typeof match.dateTime === "string") {
            // If stored as ISO string, parse it
            const parsed = new Date(match.dateTime).getTime();
            if (isNaN(parsed)) continue;
            matchDate = parsed;
          } else {
            continue;
          }

          if (matchDate < oneYearAgo) {
            shouldDelete = true;
            reason = `match date was ${Math.floor((now - matchDate) / (24 * 60 * 60 * 1000))} days ago`;
          }
        }

        if (shouldDelete) {
          matchesToDelete.push(matchId);
          console.log(`Marking match ${matchId} for deletion: ${reason}`);
        }
      }

      if (matchesToDelete.length === 0) {
        console.log("No old matches found to clean up");
        return;
      }

      // Second pass: collect all related data to clean up
      const usersSnapshot = await db.ref("/users").once("value");
      const users = usersSnapshot.val() || {};

      // Get all matches data for slot cleanup
      for (const matchId of matchesToDelete) {
        const match = matches[matchId] as any;
        if (!match) continue;

        // Delete the match itself (this will trigger onMatchDelete for some cleanup)
        updates[`/matches/${matchId}`] = null;

        // Clean up organizer's createdMatches index
        if (match.organizerId) {
          updates[`/users/${match.organizerId}/createdMatches/${matchId}`] = null;
        }

        // Clean up slot reservation if match has slot info
        if (match.slotDate && match.slotField && match.slotTime) {
          updates[`/slots/${match.slotDate}/${match.slotField}/${match.slotTime}`] = null;
        }

        // Clean up pending invite index for all users
        for (const uid of Object.keys(users)) {
          updates[`/pendingInviteIndex/${uid}/${matchId}`] = null;
        }
      }

      // Note: onMatchDelete will automatically clean up:
      // - /users/{uid}/joinedMatches/{matchId}
      // - /users/{uid}/matchInvites/{matchId}
      // - Related notifications
      // But we clean up createdMatches and pendingInviteIndex here since onMatchDelete
      // might not catch all cases

      // Execute all deletions atomically
      if (Object.keys(updates).length > 0) {
        await db.ref().update(updates);
        console.log(
          `Successfully cleaned up ${matchesToDelete.length} old matches and related data`
        );
      }
    } catch (error) {
      console.error("Error cleaning up old matches:", error);
      throw error; // Re-throw to trigger Cloud Functions retry
    }
  }
);

// Invite status change → notify organizer (accepted/declined)
export const onInviteStatusChange = onValueWritten(
  "/matches/{matchId}/invites/{inviteeUid}/status",
  async (event) => {
    const matchId = event.params.matchId as string;
    const inviteeUid = event.params.inviteeUid as string;
    const before = (event.data.before.val() || "").toString();
    const after = (event.data.after.val() || "").toString();

    if (!after || after === before) return; // no-op
    if (after !== "accepted" && after !== "declined") return; // only these

    try {
      // Load match to find organizer and sport
      const matchSnap = await admin.database().ref(`/matches/${matchId}`).once("value");
      if (!matchSnap.exists()) return;
      const match = matchSnap.val() || {};
      const organizerId: string = (match.organizerId || "").toString();
      if (!organizerId || organizerId === inviteeUid) return;
      const rawSport = (match.sport || "match").toString();
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
          route: "/my-matches",
          matchId,
        },
        tokens,
      };

      const res = await admin.messaging().sendEachForMulticast(msg);
      console.log(
        `Invite status ${after}: sent ${res.successCount}/${tokens.length} to organizer ${organizerId} for match ${matchId}`
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

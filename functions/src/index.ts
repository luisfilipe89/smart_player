import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onValueCreated } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";

admin.initializeApp();
setGlobalOptions({ region: "europe-west1" });

// RTDB → push notifications
export const sendNotification = onValueCreated(
  "/users/{userId}/notifications/{notificationId}",
  async (event) => {
    const notification = event.data.val();
    const userId = event.params.userId as string;
    const notificationId = event.params.notificationId as string;

    if (!notification || notification.read) return;

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

        default:
          title = notification.data?.title || "SMARTPLAYER";
          body = notification.data?.message || "You have a new notification";
          data.route = notification.data?.route || "/home";
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

      // Resolve organizer display name with graceful fallbacks
      const organizerId = (invite.organizerId as string | undefined) || undefined;
      let organizerName: string =
        invite.organizerName || invite.fromName || "Someone";
      if (organizerName === "Someone" && organizerId) {
        try {
          const user = await admin.auth().getUser(organizerId);
          if (user.displayName) organizerName = user.displayName;
        } catch (_) { }
      }

      // Map soccer to "football game"; otherwise use sport value
      const rawSport = (invite.sport || "game").toString();
      const sportWord = rawSport.toLowerCase() === "soccer" ? "football" : rawSport;

      const message: admin.messaging.MulticastMessage = {
        notification: {
          title: "Game Invitation",
          body: `${organizerName} invited you to play a ${sportWord} match!`,
        },
        data: {
          type: "game_invite",
          route: "/my-games",
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
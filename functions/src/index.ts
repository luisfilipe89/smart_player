import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onValueCreated } from "firebase-functions/v2/database";
import { onValueWritten } from "firebase-functions/v2/database";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onRequest } from "firebase-functions/v2/https";
import * as puppeteer from "puppeteer";

admin.initializeApp();
setGlobalOptions({ region: "europe-west1" });

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

      console.log(`Notification request processed for user ${recipientUid}, type: ${type}`);

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

      // Map soccer to "football"; otherwise use sport value
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

// Scrape sport events from s-port.nl
async function scrapeSportEvents(): Promise<any[]> {
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

    // Set language
    await page.setCookie({
      name: 'locale',
      value: 'en',
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

    console.log(`Scraped ${processedEvents.length} events`);
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

// Scheduled function to fetch sport events weekly
export const fetchSportEvents = onSchedule(
  {
    schedule: "0 2 * * 1", // Every Monday at 2 AM
    timeZone: "Europe/Amsterdam",
    memory: "1GiB",
    timeoutSeconds: 540, // 9 minutes
  },
  async (event) => {
    console.log("Starting weekly event scrape...");

    try {
      const events = await scrapeSportEvents();

      // Save to Firebase Realtime Database
      const db = admin.database();
      await db.ref("events/latest").set({
        events,
        lastUpdated: Date.now(),
      });

      console.log(`Successfully stored ${events.length} events`);
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
      const events = await scrapeSportEvents();
      const db = admin.database();
      await db.ref("events/latest").set({
        events,
        lastUpdated: Date.now(),
      });
      res.json({ success: true, count: events.length });
    } catch (error: any) {
      console.error("Error in manualFetchEvents:", error);
      res.status(500).json({ error: error?.message || "Unknown error" });
    }
  }
);
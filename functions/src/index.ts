import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

// Send FCM notification when notification data is written to database
export const sendNotification = functions.database
    .ref('/users/{userId}/notifications/{notificationId}')
    .onCreate(async (snapshot, context) => {
        const notification = snapshot.val();
        const userId = context.params.userId;
        const notificationId = context.params.notificationId;

        if (!notification || notification.read) {
            return null;
        }

        try {
            // Get user's FCM tokens
            const userTokensSnapshot = await admin.database()
                .ref(`/users/${userId}/fcmTokens`)
                .once('value');

            const tokens = userTokensSnapshot.val();
            if (!tokens) {
                console.log(`No FCM tokens found for user ${userId}`);
                return null;
            }

            const tokenList = Object.keys(tokens);
            if (tokenList.length === 0) {
                console.log(`No valid FCM tokens for user ${userId}`);
                return null;
            }

            // Prepare notification payload based on type
            let title = 'SMARTPLAYER';
            let body = 'You have a new notification';
            const data: { [key: string]: string } = {
                type: notification.type || 'default',
                notificationId: notificationId,
            };

            switch (notification.type) {
                case 'friend_request':
                    title = 'New Friend Request';
                    body = `${notification.data?.fromName || 'Someone'} sent you a friend request`;
                    data.route = '/friends';
                    break;

                case 'friend_request_accepted':
                    title = 'Friend Request Accepted';
                    body = `${notification.data?.fromName || 'Someone'} accepted your friend request`;
                    data.route = '/friends';
                    break;

                case 'game_invite':
                    title = 'Game Invitation';
                    body = `${notification.data?.fromName || 'Someone'} invited you to a ${notification.data?.sport || 'game'}`;
                    data.route = '/my-games';
                    data.gameId = notification.data?.gameId || '';
                    break;

                case 'game_cancelled':
                    title = 'Game Cancelled';
                    body = `The ${notification.data?.sport || 'game'} at ${notification.data?.location || 'your location'} has been cancelled`;
                    data.route = '/my-games';
                    data.gameId = notification.data?.gameId || '';
                    break;

                case 'player_joined':
                    title = 'Player Joined Your Game';
                    body = `${notification.data?.playerName || 'Someone'} joined your ${notification.data?.sport || 'game'}`;
                    data.route = '/my-games';
                    data.gameId = notification.data?.gameId || '';
                    break;

                default:
                    title = notification.data?.title || 'SMARTPLAYER';
                    body = notification.data?.message || 'You have a new notification';
                    data.route = notification.data?.route || '/home';
            }

            // Send FCM message
            const message: admin.messaging.MulticastMessage = {
                notification: {
                    title: title,
                    body: body,
                },
                data: data,
                tokens: tokenList,
            };

            const response = await admin.messaging().sendMulticast(message);

            console.log(`Successfully sent notification to ${response.successCount} tokens for user ${userId}`);

            if (response.failureCount > 0) {
                console.log(`Failed to send to ${response.failureCount} tokens`);

                // Clean up invalid tokens
                const invalidTokens: string[] = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success && resp.error) {
                        const errorCode = resp.error.code;
                        if (errorCode === 'messaging/invalid-registration-token' ||
                            errorCode === 'messaging/registration-token-not-registered') {
                            invalidTokens.push(tokenList[idx]);
                        }
                    }
                });

                // Remove invalid tokens from database
                if (invalidTokens.length > 0) {
                    const updates: { [key: string]: null } = {};
                    invalidTokens.forEach(token => {
                        updates[`/users/${userId}/fcmTokens/${token}`] = null;
                    });
                    await admin.database().ref().update(updates);
                    console.log(`Removed ${invalidTokens.length} invalid tokens`);
                }
            }

            return null;
        } catch (error) {
            console.error('Error sending notification:', error);
            return null;
        }
    });

// Clean up old notifications (older than 30 days)
export const cleanupOldNotifications = functions.pubsub
    .schedule('0 2 * * *') // Run daily at 2 AM
    .timeZone('Europe/Amsterdam')
    .onRun(async (context) => {
        const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);

        try {
            const usersSnapshot = await admin.database()
                .ref('/users')
                .once('value');

            const users = usersSnapshot.val();
            if (!users) return null;

            const updates: { [key: string]: null } = {};

            for (const [userId, userData] of Object.entries(users)) {
                if (userData && typeof userData === 'object' && 'notifications' in userData) {
                    const notifications = (userData as any).notifications;
                    if (notifications) {
                        for (const [notificationId, notification] of Object.entries(notifications)) {
                            const notif = notification as any;
                            if (notif.timestamp && notif.timestamp < thirtyDaysAgo) {
                                updates[`/users/${userId}/notifications/${notificationId}`] = null;
                            }
                        }
                    }
                }
            }

            if (Object.keys(updates).length > 0) {
                await admin.database().ref().update(updates);
                console.log(`Cleaned up ${Object.keys(updates).length} old notifications`);
            }

            return null;
        } catch (error) {
            console.error('Error cleaning up old notifications:', error);
            return null;
        }
    });

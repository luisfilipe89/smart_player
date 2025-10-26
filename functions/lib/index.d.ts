export declare const processNotificationRequest: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2/database").DataSnapshot, {
    requestId: string;
}>>;
export declare const sendNotification: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2/database").DataSnapshot, {
    userId: string;
    notificationId: string;
}>>;
export declare const onGameInviteCreate: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2/database").DataSnapshot, {
    gameId: string;
    inviteeUid: string;
}>>;
export declare const cleanupOldNotifications: import("firebase-functions/v2/scheduler").ScheduleFunction;
export declare const onInviteStatusChange: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2").Change<import("firebase-functions/v2/database").DataSnapshot>, {
    gameId: string;
    inviteeUid: string;
}>>;
export declare const fetchSportEvents: import("firebase-functions/v2/scheduler").ScheduleFunction;
export declare const manualFetchEvents: import("firebase-functions/v2/https").HttpsFunction;

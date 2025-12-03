export declare const onFieldReportCreated: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/firestore").FirestoreEvent<import("firebase-functions/v2/firestore").QueryDocumentSnapshot, {
    reportId: string;
}>>;
export declare const processPendingFieldReport: import("firebase-functions/v2/https").HttpsFunction;
export declare const onMailNotificationCreate: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2/database").DataSnapshot, {
    notificationId: string;
}>>;
export declare const onGameDelete: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2/database").DataSnapshot, {
    gameId: string;
}>>;
export declare const onUserDelete: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2/database").DataSnapshot, {
    uid: string;
}>>;
export declare const onGameUpdate: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2").Change<import("firebase-functions/v2/database").DataSnapshot>, {
    gameId: string;
}>>;
export declare const processNotificationRequest: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2/database").DataSnapshot, {
    requestId: string;
}>>;
export declare const sendNotification: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/database").DatabaseEvent<import("firebase-functions/v2/database").DataSnapshot, {
    notificationId: string;
    userId: string;
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

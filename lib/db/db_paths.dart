class DbPaths {
  DbPaths._();

  // Root collections
  static const String users = 'users';
  static const String games = 'games';
  static const String mail = 'mail';
  static const String emailInvites = 'emailInvites';
  static const String friendTokens = 'friendTokens';
  static const String reports = 'reports';

  // Users subpaths
  static String user(String uid) => '$users/$uid';
  static String userProfile(String uid) => '$users/$uid/profile';
  static String userProfileDisplayName(String uid) =>
      '$users/$uid/profile/displayName';
  static String userProfilePhotoUrl(String uid) =>
      '$users/$uid/profile/photoURL';
  static String userMetadata(String uid) => '$users/$uid/metadata';
  static String userFriends(String uid) => '$users/$uid/friends';
  static String userBlocks(String uid) => '$users/$uid/blocks';
  static String userFriendRequestsReceived(String uid) =>
      '$users/$uid/friendRequests/received';
  static String userFriendRequestsSent(String uid) =>
      '$users/$uid/friendRequests/sent';
  static String userJoinedGames(String uid) => '$users/$uid/joinedGames';
  static String userCreatedGames(String uid) => '$users/$uid/createdGames';
  static String userGameInvites(String uid) => '$users/$uid/gameInvites';
  static String userSettingsRoot(String uid) => '$users/$uid/settings';
  static String userSettingsProfileRoot(String uid) =>
      '$users/$uid/settings/profile';
  static String userSettingsNotifications(String uid, String key) =>
      '$users/$uid/settings/notifications/$key';
  static String userFcmToken(String uid, String token) =>
      '$users/$uid/fcmTokens/$token';

  // Settings profile convenience
  static String userVisibility(String uid) =>
      '$users/$uid/settings/profile/visibility';
  static String userShowOnline(String uid) =>
      '$users/$uid/settings/profile/showOnline';
  static String userAllowFriendRequests(String uid) =>
      '$users/$uid/settings/profile/allowFriendRequests';
  static String userShareEmail(String uid) =>
      '$users/$uid/settings/profile/shareEmail';

  // Games subpaths
  static String game(String gameId) => '$games/$gameId';
  static String gamePlayers(String gameId) => '$games/$gameId/players';
  static String gameInvites(String gameId) => '$games/$gameId/invites';

  // Friend tokens
  static String friendToken(String token) => '$friendTokens/$token';

  // Users by email hash (indexing)
  static const String usersByEmailHash = 'usersByEmailHash';
  static String userByEmailHash(String hash) => '$usersByEmailHash/$hash';
}

class DbPaths {
  DbPaths._();

  // Root collections
  static const String users = 'users';
  static const String games = 'games';
  static const String mail = 'mail';
  static const String emailInvites = 'emailInvites';
  static const String pendingInviteIndex = 'pendingInviteIndex';
  static const String friendTokens = 'friendTokens';
  static const String fieldReports = 'fieldReports';

  // Users subpaths
  static String user(String uid) => uid; // For use with _usersRef.child()
  static String userProfile(String uid) => '$users/$uid/profile';
  static String userProfileDisplayName(String uid) =>
      '$users/$uid/profile/displayName';
  static String userProfilePhotoUrl(String uid) =>
      '$users/$uid/profile/photoURL';
  static String userFriends(String uid) => '$users/$uid/friends';
  static String userFriendRequestsReceived(String uid) =>
      '$users/$uid/friendRequests/received';
  static String userFriendRequestsSent(String uid) =>
      '$users/$uid/friendRequests/sent';
  static String userJoinedGames(String uid) => '$uid/joinedGames';
  static String userCreatedGames(String uid) => '$uid/createdGames';
  static String userGameInvites(String uid) => '$uid/gameInvites';
  static String userSettingsProfileRoot(String uid) =>
      '$users/$uid/settings/profile';

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

  // Users by email hash (indexing)
  static const String usersByEmailHash = 'usersByEmailHash';
}

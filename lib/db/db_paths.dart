class DbPaths {
  DbPaths._();

  // Root collections
  static const String users = 'users';
  static const String matches = 'matches';
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
  static String userFriends(String uid) => '$users/$uid/friends';
  static String userFriendRequestsReceived(String uid) =>
      '$users/$uid/friendRequests/received';
  static String userFriendRequestsSent(String uid) =>
      '$users/$uid/friendRequests/sent';
  static String userJoinedMatches(String uid) => '$uid/joinedMatches';
  static String userCreatedMatches(String uid) => '$uid/createdMatches';
  static String userMatchInvites(String uid) => '$uid/matchInvites';
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

  // Matches subpaths
  static String match(String matchId) => '$matches/$matchId';
  static String matchPlayers(String matchId) => '$matches/$matchId/players';
  static String matchInvites(String matchId) => '$matches/$matchId/invites';

  // Users by email hash (indexing)
  static const String usersByEmailHash = 'usersByEmailHash';
}

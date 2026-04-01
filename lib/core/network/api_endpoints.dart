class ApiEndpoints {
  static const String sendEmailCode = '/auth/send-code';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String xidianAuthSession = '/auth/xidian/session';
  static const String xidianAuthStart = '/auth/xidian/start';
  static const String verifyEmail = '/auth/verify';
  static const String resendCode = '/auth/resend-code';
  static const String passwordResetSendCode = '/auth/password/send-code';
  static const String passwordReset = '/auth/password/reset';
  static const String logout = '/auth/logout';

  static const String me = '/users/me';
  static const String userSearch = '/users/search';
  static const String privacy = '/users/privacy';
  static const String notificationPreferences =
      '/users/notification-preferences';
  static const String notificationPreferencesLegacy =
      '/users/me/notification-preferences';
  static const String avatarUpload = '/users/avatar';
  static const String meCancellationRequest = '/users/me/cancellation-request';
  static const String meLevelUpgradeRequest = '/users/me/level-upgrade-request';

  // 关注系统
  static const String myFollowing = '/users/me/following';
  static const String myFollowers = '/users/me/followers';
  static const String myFriends = '/users/me/friends';
  static String followUser(String userId) => '/users/$userId/follow';
  static String unfollowUser(String userId) => '/users/$userId/unfollow';
  static String userProfile(String userId) => '/users/$userId';
  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';

  static const String channels = '/channels';
  static const String posts = '/posts';
  static const String myPosts = '/posts/mine';
  static const String favoritePosts = '/posts/favorites';
  static const String uploadImages = '/uploads/images';
  static const String myUploads = '/uploads/mine';

  static const String myComments = '/comments/mine';
  static const String myReports = '/reports/mine';
  static const String reports = '/reports';

  static const String dmRequests = '/messages/requests';
  static const String conversations = '/messages/conversations';
  static const String directConversation = '/messages/conversations/direct';

  static const String adminOverview = '/admin/overview';
  static const String adminLogin = '/admin/auth/login';
  static const String adminLogout = '/admin/auth/logout';
  static const String adminMe = '/admin/auth/me';
  static const String adminPassword = '/admin/auth/password';
  static const String adminReviews = '/admin/reviews';
  static const String adminReports = '/admin/reports';
  static const String adminImageReviews = '/admin/images/reviews';
  static const String adminUsers = '/admin/users';
  static const String adminPostPinRequests = '/admin/post-pin-requests';
  static const String adminUserLevelRequests = '/admin/user-level-requests';
  static const String adminAccounts = '/admin/admin-accounts';
  static const String adminAccountCancellationRequests =
      '/admin/account-cancellation-requests';
  static const String adminAppeals = '/admin/appeals';
  static const String adminExport = '/admin/export';
  static const String adminChannelsTags = '/admin/channels-tags';
  static const String adminChannels = '/admin/channels';
  static const String adminTags = '/admin/tags';
  static const String adminConfig = '/admin/config';
  static const String adminAnnouncements = '/admin/announcements';
  static const String adminAndroidRelease = '/admin/releases/android';
  static const String androidReleaseLatest = '/releases/android/latest';

  static String postById(String postId) => '/posts/$postId';
  static String xidianAuthSessionById(String attemptId) =>
      '/auth/xidian/session/$attemptId';
  static String postComments(String postId) => '/posts/$postId/comments';
  static String postLike(String postId) => '/posts/$postId/like';
  static String postFavorite(String postId) => '/posts/$postId/favorite';
  static String postUnfavorite(String postId) => '/posts/$postId/favorite';
  static String postPinRequest(String postId) => '/posts/$postId/pin-request';
  static String postView(String postId) => '/posts/$postId/view';
  static String commentLike(String commentId) => '/comments/$commentId/like';

  static String dmRequestAction(String requestId, String action) =>
      '/messages/requests/$requestId/$action';
  static String dmConversationMessages(String conversationId) =>
      '/messages/conversations/$conversationId/messages';
  static String dmConversation(String conversationId) =>
      '/messages/conversations/$conversationId';
  static String dmConversationBlock(String conversationId, bool block) =>
      '/messages/conversations/$conversationId/${block ? 'block' : 'unblock'}';
  static String dmMessageRecall(String messageId) =>
      '/messages/messages/$messageId/recall';
  static String notificationRead(String notificationId) =>
      '/notifications/$notificationId/read';

  static String commentById(String commentId) => '/comments/$commentId';
  static String reportById(String reportId) => '/reports/$reportId';

  static String adminReviewAction(
    String targetType,
    String targetId,
    String action,
  ) => '/admin/reviews/$targetType/$targetId/$action';
  static const String adminReviewBatch = '/admin/reviews/batch';

  static String adminReportHandle(String reportId) =>
      '/admin/reports/$reportId/handle';

  static String adminImageReview(String uploadId) =>
      '/admin/images/$uploadId/review';

  static String adminUserAction(String userId) => '/admin/users/$userId/action';
  static String adminPostPinRequestHandle(String requestId) =>
      '/admin/post-pin-requests/$requestId/handle';
  static String adminUserLevelRequestHandle(String requestId) =>
      '/admin/user-level-requests/$requestId/handle';

  static String adminAccountAction(String adminId) =>
      '/admin/admin-accounts/$adminId/action';

  static String adminAccountCancellationHandle(String requestId) =>
      '/admin/account-cancellation-requests/$requestId/handle';

  static String adminAppealHandle(String appealId) =>
      '/admin/appeals/$appealId/handle';

  static String adminChannelByName(String name) => '/admin/channels/$name';

  static String adminTagByName(String name) => '/admin/tags/$name';
}

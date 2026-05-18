import '../core/auth/admin_auth_store.dart';
import '../core/network/api_client.dart';
import 'admin_repository.dart';
import 'admin_auth_repository.dart';
import 'app_release_repository.dart';
import 'auth_repository.dart';
import 'message_repository.dart';
import 'notification_repository.dart';
import 'post_repository.dart';
import 'user_repository.dart';

class AppRepositories {
  AppRepositories._();

  static final ApiClient apiClient = ApiClient();
  static final ApiClient adminApiClient = ApiClient(
    tokenResolver: () => AdminAuthStore.instance.token,
  );

  static final AuthRepository auth = AuthRepository(apiClient);
  static final PostRepository posts = PostRepository(apiClient);
  static final MessageRepository messages = MessageRepository(apiClient);
  static final NotificationRepository notifications = NotificationRepository(
    apiClient,
  );
  static final UserRepository users = UserRepository(apiClient);
  static final AppReleaseRepository releases = AppReleaseRepository(apiClient);
  static final AdminRepository admin = AdminRepository(apiClient);
  static final AdminRepository adminPortal = AdminRepository(adminApiClient);
  static final AdminAuthRepository adminAuth = AdminAuthRepository(
    adminApiClient,
  );
}

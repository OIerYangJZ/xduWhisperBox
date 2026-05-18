library;

/// 移动端 App 专用入口文件
/// 复用现有 web 端的所有数据层、Repository、API Client、Auth Store

export 'core/config/mobile_config.dart';
export 'core/theme/mobile_theme.dart';
export 'core/navigation/app_router.dart';
export 'core/state/mobile_providers.dart';
export 'features/shell/mobile_shell.dart';
export 'features/auth/login_page.dart';
export 'features/auth/verify_page.dart';
export 'features/auth/reset_password_page.dart';
export 'features/home/home_page.dart';
export 'features/search/search_page.dart';
export 'features/post/post_detail_page.dart';
export 'features/post/create_post_page.dart';
export 'features/messages/messages_page.dart';
export 'features/messages/chat_page.dart';
export 'features/favorites/favorites_page.dart';
export 'features/profile/profile_page.dart';
export 'features/profile/edit_profile_page.dart';
export 'features/profile/my_posts_page.dart';
export 'features/profile/my_comments_page.dart';
export 'features/profile/my_reports_page.dart';
export 'features/profile/settings_page.dart';
export 'features/profile/settings_main_page.dart';
export 'features/profile/notification_settings_page.dart';
export 'features/notifications/notification_center_page.dart';
export 'features/admin/admin_login_page.dart';
export 'features/admin/admin_console_page.dart';
export 'features/home/post_card.dart';
export 'features/widgets/comment_tile.dart';
export 'features/widgets/input_bar.dart';
export 'features/widgets/emoji_bar.dart';
export 'features/widgets/avatar_widget.dart';
export 'features/widgets/loading_states.dart';
export 'features/widgets/shimmer_loading.dart';
export 'features/widgets/empty_state_widget.dart';
export 'features/post/image_gallery.dart';
export 'features/post/comment_input_bar.dart';

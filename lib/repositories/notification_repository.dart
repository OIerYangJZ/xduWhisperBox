import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../models/notification_item.dart';

class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<NotificationItem>> fetchNotifications() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.notifications);
    final Map<String, dynamic> data = extractMap(response);
    final List<dynamic> list = extractList(data['items'] ?? data);
    return list
        .map((dynamic item) => NotificationItem.fromJson(asMap(item)))
        .where((NotificationItem item) => item.id.isNotEmpty)
        .toList();
  }

  Future<NotificationItem> markRead(String notificationId) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.notificationRead(notificationId),
      body: const <String, dynamic>{},
    );
    final Map<String, dynamic> data = extractMap(response);
    return NotificationItem.fromJson(data);
  }

  Future<void> markAllRead() {
    return _apiClient.post(
      ApiEndpoints.notificationsReadAll,
      body: const <String, dynamic>{},
    );
  }
}

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_utils.dart';
import '../models/app_release_item.dart';

class AppReleaseRepository {
  AppReleaseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AppReleaseItem?> fetchLatestAndroidRelease() async {
    try {
      final dynamic response = await _apiClient.get(
        ApiEndpoints.androidReleaseLatest,
        auth: false,
      );
      final Map<String, dynamic> data = extractMap(response);
      if (data.isEmpty) {
        return null;
      }
      return AppReleaseItem.fromJson(data);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}

import 'package:url_launcher/url_launcher.dart';

Future<bool> triggerBrowserDownload(String url) async {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

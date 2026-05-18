import 'package:web/web.dart' as web;

Future<bool> triggerBrowserDownload(String url) async {
  final String trimmed = url.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
    ..href = trimmed
    ..target = '_self'
    ..rel = 'noopener'
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

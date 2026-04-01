import 'dart:convert';
import 'package:web/web.dart' as web;

bool downloadTextFile({
  required String fileName,
  required String content,
  required String contentType,
}) {
  final bytes = utf8.encode(content);
  final b64 = base64Encode(bytes);
  final dataUrl = 'data:$contentType;base64,$b64';
  final anchor = web.HTMLAnchorElement()
    ..href = dataUrl
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  return true;
}

// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

const String _postRestoreSessionKey = 'xdu_treehole_restore_post_id';

String? takeQueryParameterFromUrl(String key) {
  final Uri uri = Uri.parse(html.window.location.href);
  final String value = (uri.queryParameters[key] ?? '').trim();
  if (value.isEmpty) {
    return null;
  }
  final Map<String, String> qp = Map<String, String>.from(uri.queryParameters)
    ..remove(key);
  final Uri next = uri.replace(queryParameters: qp.isEmpty ? null : qp);
  html.window.history.replaceState(null, '', next.toString());
  return value;
}

String? currentPostIdFromUrl() {
  final Uri uri = Uri.parse(html.window.location.href);
  final String value = (uri.queryParameters['postId'] ?? '').trim();
  if (value.isEmpty) {
    return null;
  }
  final String restorablePostId =
      (html.window.sessionStorage[_postRestoreSessionKey] ?? '').trim();
  if (restorablePostId != value) {
    final Map<String, String> qp = Map<String, String>.from(uri.queryParameters)
      ..remove('postId');
    final Uri next = uri.replace(queryParameters: qp.isEmpty ? null : qp);
    html.window.history.replaceState(null, '', next.toString());
    html.window.sessionStorage.remove(_postRestoreSessionKey);
    return null;
  }
  html.window.sessionStorage.remove(_postRestoreSessionKey);
  return value;
}

void setPostIdOnUrl(String? postId) {
  final Uri uri = Uri.parse(html.window.location.href);
  final Map<String, String> qp = Map<String, String>.from(uri.queryParameters);
  final String value = (postId ?? '').trim();
  if (value.isEmpty) {
    qp.remove('postId');
    html.window.sessionStorage.remove(_postRestoreSessionKey);
  } else {
    qp['postId'] = value;
    html.window.sessionStorage[_postRestoreSessionKey] = value;
  }
  final Uri next = uri.replace(queryParameters: qp.isEmpty ? null : qp);
  html.window.history.replaceState(null, '', next.toString());
}

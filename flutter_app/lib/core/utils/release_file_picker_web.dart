import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'picked_release_file.dart';

Future<PickedReleaseFile?> pickReleaseFile() async {
  final web.HTMLInputElement input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.apk,application/vnd.android.package-archive';

  final Completer<PickedReleaseFile?> completer =
      Completer<PickedReleaseFile?>();

  void completeSafely(PickedReleaseFile? value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  input.onchange = ((web.Event event) {
    final web.FileList? files = input.files;
    if (files == null || files.length == 0) {
      completeSafely(null);
      return;
    }
    final web.File? file = files.item(0);
    if (file == null) {
      completeSafely(null);
      return;
    }
    _readFile(file, completeSafely);
  }).toJS;

  input.click();
  Future<void>.delayed(const Duration(seconds: 30), () => completeSafely(null));
  return completer.future;
}

Future<void> _readFile(
  web.File file,
  void Function(PickedReleaseFile?) completeSafely,
) async {
  final String? dataUrl = await _readAsDataUrl(file);
  if (dataUrl == null || !dataUrl.contains(',')) {
    completeSafely(null);
    return;
  }

  final int separator = dataUrl.indexOf(',');
  final String header = dataUrl.substring(0, separator);
  final String base64Data = dataUrl.substring(separator + 1);
  final String contentType = _extractContentType(header, fallback: file.type);

  try {
    completeSafely(
      PickedReleaseFile(
        fileName: file.name,
        contentType: contentType,
        bytes: Uint8List.fromList(base64Decode(base64Data)),
      ),
    );
  } catch (_) {
    completeSafely(null);
  }
}

Future<String?> _readAsDataUrl(web.File file) async {
  final Completer<String?> completer = Completer<String?>();
  final web.FileReader reader = web.FileReader();
  reader.readAsDataURL(file);

  reader.onloadend = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.complete(reader.result as String?);
    }
  }).toJS;

  reader.onerror = ((web.Event event) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }).toJS;

  return completer.future;
}

String _extractContentType(String dataUrlHeader, {required String fallback}) {
  final String normalizedFallback = fallback.trim().toLowerCase();
  final RegExpMatch? match = RegExp(
    r'^data:([^;]+);base64$',
  ).firstMatch(dataUrlHeader);
  if (match != null) {
    final String raw = match.group(1)?.trim().toLowerCase() ?? '';
    if (raw.isNotEmpty) {
      return raw;
    }
  }
  if (normalizedFallback.isNotEmpty) {
    return normalizedFallback;
  }
  return 'application/vnd.android.package-archive';
}

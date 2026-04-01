import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'picked_image_data.dart';

Future<List<PickedImageData>> pickImageFiles({bool multiple = true}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..multiple = multiple;

  final completer = Completer<List<PickedImageData>>();

  void completeSafely(List<PickedImageData> value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  input.onchange = ((web.Event event) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completeSafely(const <PickedImageData>[]);
      return;
    }

    final List<web.File> selectedFiles = _fileListToDartList(files);
    _processFiles(selectedFiles, completer, completeSafely);
  }).toJS;

  input.click();

  Future<void>.delayed(const Duration(seconds: 15), () {
    completeSafely(const <PickedImageData>[]);
  });
  return completer.future;
}

List<web.File> _fileListToDartList(web.FileList files) {
  final result = <web.File>[];
  for (int i = 0; i < files.length; i++) {
    result.add(files.item(i)!);
  }
  return result;
}

Future<void> _processFiles(
  List<web.File> files,
  Completer<List<PickedImageData>> completer,
  void Function(List<PickedImageData>) completeSafely,
) async {
  final results = <PickedImageData>[];
  for (final file in files) {
    final dataUrl = await _readAsDataUrl(file);
    if (dataUrl == null || !dataUrl.contains(',')) {
      continue;
    }
    final separator = dataUrl.indexOf(',');
    final header = dataUrl.substring(0, separator);
    final base64Data = dataUrl.substring(separator + 1);
    final contentType = _extractContentType(header, fallback: file.type);

    if (!_isAllowedImageType(contentType)) {
      continue;
    }

    final sizeBytes = _calcBase64DecodedSize(base64Data);

    const maxPreviewSize = 10 * 1024 * 1024;
    if (sizeBytes > maxPreviewSize) {
      continue;
    }

    results.add(
      PickedImageData(
        fileName: file.name,
        contentType: contentType,
        dataBase64: base64Data,
        sizeBytes: sizeBytes,
        previewDataUrl: dataUrl,
      ),
    );
  }
  completeSafely(results);
}

Future<String?> _readAsDataUrl(web.File file) async {
  final completer = Completer<String?>();
  final reader = web.FileReader();
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
  final normalizedFallback = fallback.trim().toLowerCase();
  final match = RegExp(r'^data:([^;]+);base64$').firstMatch(dataUrlHeader);
  if (match != null) {
    final raw = match.group(1)?.trim().toLowerCase() ?? '';
    if (raw.isNotEmpty) {
      return raw;
    }
  }
  if (normalizedFallback.isNotEmpty) {
    return normalizedFallback;
  }
  return 'application/octet-stream';
}

bool _isAllowedImageType(String contentType) {
  const allowed = <String>{'image/jpeg', 'image/png', 'image/webp', 'image/gif'};
  return allowed.contains(contentType.toLowerCase());
}

int _calcBase64DecodedSize(String base64Data) {
  int padding = 0;
  if (base64Data.endsWith('==')) {
    padding = 2;
  } else if (base64Data.endsWith('=')) {
    padding = 1;
  }
  return (base64Data.length * 3 ~/ 4) - padding;
}

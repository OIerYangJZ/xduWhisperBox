// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

import 'picked_image_data.dart';

typedef MarkdownClipboardImageDetach = void Function();

MarkdownClipboardImageDetach registerMarkdownClipboardImageListener({
  required FocusNode focusNode,
  required Future<void> Function(List<PickedImageData> images) onImagesPasted,
}) {
  final StreamSubscription<html.Event> subscription =
      html.document.onPaste.listen((html.Event event) async {
    if (!focusNode.hasFocus) {
      return;
    }
    final html.ClipboardEvent? clipboardEvent =
        event is html.ClipboardEvent ? event : null;
    final html.DataTransferItemList? items = clipboardEvent?.clipboardData?.items;
    if (items == null || items.length == 0) {
      return;
    }

    final List<html.File> files = <html.File>[];
    final int itemCount = items.length ?? 0;
    for (int i = 0; i < itemCount; i += 1) {
      final html.DataTransferItem? item = items[i];
      if (item == null) {
        continue;
      }
      final String type = (item.type ?? '').toLowerCase();
      if (item.kind == 'file' && type.startsWith('image/')) {
        final html.File? file = item.getAsFile();
        if (file != null) {
          files.add(file);
        }
      }
    }

    if (files.isEmpty) {
      return;
    }

    event.preventDefault();
    final List<PickedImageData> images = await _processFiles(files);
    if (images.isEmpty) {
      return;
    }
    await onImagesPasted(images);
  });

  return () {
    subscription.cancel();
  };
}

Future<List<PickedImageData>> _processFiles(List<html.File> files) async {
  final List<PickedImageData> results = <PickedImageData>[];
  for (final html.File file in files) {
    final String? dataUrl = await _readAsDataUrl(file);
    if (dataUrl == null || !dataUrl.contains(',')) {
      continue;
    }
    final int separator = dataUrl.indexOf(',');
    final String header = dataUrl.substring(0, separator);
    final String base64Data = dataUrl.substring(separator + 1);
    final String contentType = _extractContentType(header, fallback: file.type);

    if (!_isAllowedImageType(contentType)) {
      continue;
    }

    final int sizeBytes = _calcBase64DecodedSize(base64Data);
    if (sizeBytes > 10 * 1024 * 1024) {
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
  return results;
}

Future<String?> _readAsDataUrl(html.File file) async {
  final Completer<String?> completer = Completer<String?>();
  final html.FileReader reader = html.FileReader();
  reader.readAsDataUrl(file);

  reader.onLoadEnd.first.then((_) {
    if (!completer.isCompleted) {
      completer.complete(reader.result as String?);
    }
  });
  reader.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });

  return completer.future;
}

String _extractContentType(String dataUrlHeader, {required String fallback}) {
  final String normalizedFallback = fallback.trim().toLowerCase();
  final RegExpMatch? match =
      RegExp(r'^data:([^;]+);base64$').firstMatch(dataUrlHeader);
  if (match != null) {
    final String raw = match.group(1)?.trim().toLowerCase() ?? '';
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
  const Set<String> allowed = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  };
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

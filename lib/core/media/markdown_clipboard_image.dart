import 'package:flutter/widgets.dart';

import 'picked_image_data.dart';
import 'markdown_clipboard_image_stub.dart'
    if (dart.library.html) 'markdown_clipboard_image_web.dart' as impl;

typedef MarkdownClipboardImageDetach = void Function();

MarkdownClipboardImageDetach registerMarkdownClipboardImageListener({
  required FocusNode focusNode,
  required Future<void> Function(List<PickedImageData> images) onImagesPasted,
}) {
  return impl.registerMarkdownClipboardImageListener(
    focusNode: focusNode,
    onImagesPasted: onImagesPasted,
  );
}

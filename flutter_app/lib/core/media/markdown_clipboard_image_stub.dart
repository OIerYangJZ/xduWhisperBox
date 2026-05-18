import 'package:flutter/widgets.dart';

import 'picked_image_data.dart';

typedef MarkdownClipboardImageDetach = void Function();

MarkdownClipboardImageDetach registerMarkdownClipboardImageListener({
  required FocusNode focusNode,
  required Future<void> Function(List<PickedImageData> images) onImagesPasted,
}) {
  return () {};
}

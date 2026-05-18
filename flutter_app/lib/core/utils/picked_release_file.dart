import 'dart:typed_data';

class PickedReleaseFile {
  PickedReleaseFile({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final Uint8List bytes;

  int get sizeBytes => bytes.length;
}

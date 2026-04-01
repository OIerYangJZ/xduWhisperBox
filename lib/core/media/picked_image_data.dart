class PickedImageData {
  PickedImageData({
    required this.fileName,
    required this.contentType,
    required this.dataBase64,
    required this.sizeBytes,
    required this.previewDataUrl,
  });

  final String fileName;
  final String contentType;
  final String dataBase64;
  final int sizeBytes;
  final String previewDataUrl;
}

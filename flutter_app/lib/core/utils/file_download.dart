import 'file_download_stub.dart' if (dart.library.html) 'file_download_web.dart'
    as impl;

bool downloadTextFile({
  required String fileName,
  required String content,
  required String contentType,
}) {
  return impl.downloadTextFile(
    fileName: fileName,
    content: content,
    contentType: contentType,
  );
}

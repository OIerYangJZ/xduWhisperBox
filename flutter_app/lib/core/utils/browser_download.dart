import 'browser_download_stub.dart'
    if (dart.library.io) 'browser_download_io.dart'
    if (dart.library.html) 'browser_download_web.dart'
    as impl;

Future<bool> triggerBrowserDownload(String url) {
  return impl.triggerBrowserDownload(url);
}

import 'picked_release_file.dart';
import 'release_file_picker_stub.dart'
    if (dart.library.html) 'release_file_picker_web.dart'
    as impl;

export 'picked_release_file.dart';

Future<PickedReleaseFile?> pickReleaseFile() {
  return impl.pickReleaseFile();
}

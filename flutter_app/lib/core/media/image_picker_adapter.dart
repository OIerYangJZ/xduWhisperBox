import 'picked_image_data.dart';
import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart' as image_picker_impl;

Future<List<PickedImageData>> pickImageFiles({bool multiple = true}) {
  return image_picker_impl.pickImageFiles(multiple: multiple);
}

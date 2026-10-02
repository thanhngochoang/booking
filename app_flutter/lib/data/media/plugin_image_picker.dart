import 'package:image_picker/image_picker.dart';

import 'package:photobooking/data/media/image_picker_port.dart';

/// The system gallery picker (Android photo picker, iOS PHPicker). No camera,
/// so no camera permission.
class PluginImagePicker implements ImagePickerPort {
  PluginImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  static const _longSide = 2048.0;
  static const _quality = 85;

  @override
  Future<List<PickedImage>> pickImages({required int max}) async {
    if (max <= 0) {
      return const [];
    }
    final List<XFile> files;
    if (max == 1) {
      final one = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _longSide,
        maxHeight: _longSide,
        imageQuality: _quality,
      );
      files = [?one];
    } else {
      files = await _picker.pickMultiImage(
        maxWidth: _longSide,
        maxHeight: _longSide,
        imageQuality: _quality,
        limit: max,
      );
    }
    return [
      for (final f in files)
        PickedImage(path: f.path, name: f.name, sizeBytes: await f.length()),
    ];
  }
}

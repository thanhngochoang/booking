import 'package:flutter/foundation.dart';

/// A photo chosen from the gallery: a file on disk, never its bytes.
@immutable
class PickedImage {
  const PickedImage({required this.path, required this.name, this.sizeBytes});
  final String path;
  final String name;
  final int? sizeBytes;
}

abstract class ImagePickerPort {
  /// Opens the system gallery picker for up to [max] photos. They are already
  /// scaled to at most 2048 px on the long side and re-encoded as JPEG at
  /// quality 85. Empty when the user cancels.
  Future<List<PickedImage>> pickImages({required int max});
}

class FakeImagePicker implements ImagePickerPort {
  FakeImagePicker([List<List<PickedImage>> answers = const []])
    : _answers = List.of(answers);

  final List<List<PickedImage>> _answers;
  int calls = 0;
  final List<int> requestedMax = [];

  @override
  Future<List<PickedImage>> pickImages({required int max}) async {
    calls++;
    requestedMax.add(max);
    if (_answers.isEmpty) {
      return const [];
    }
    return _answers.removeAt(0).take(max).toList();
  }
}

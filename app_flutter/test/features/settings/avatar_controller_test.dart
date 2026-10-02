// test/features/settings/avatar_controller_test.dart
import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/avatar_controller.dart';
import 'package:photobooking/features/settings/button_style_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = PickedImage(path: '/tmp/a.jpg', name: 'a.jpg');
const _b = PickedImage(path: '/tmp/b.jpg', name: 'b.jpg');
final _avatarPath = RegExp(r'^avatars/fake-1/[0-9A-HJKMNP-TV-Z]{26}\.jpg$');

Future<(ProviderContainer, FakeUserRepository, FakeMediaUploader)> _setup(
  List<List<PickedImage>> answers, {
  Map<String, Object> prefs = const {},
  FakeMediaUploader? uploader,
  ImagePickerPort? picker,
  bool listen = true,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Lan');
  await users.ensureProfile(u);
  final up = uploader ?? FakeMediaUploader();
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      imagePickerProvider.overrideWithValue(picker ?? FakeImagePicker(answers)),
      mediaUploaderProvider.overrideWithValue(up),
    ],
  );
  addTearDown(c.dispose);
  if (listen) {
    final sub = c.listen(avatarControllerProvider, (_, _) {});
    addTearDown(sub.close);
  }
  return (c, users, up);
}

/// Holds every upload open until [gate] completes.
class _GatedUploader extends FakeMediaUploader {
  final gate = Completer<void>();

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
  }) async* {
    await gate.future;
    yield* super.upload(image, storagePath: storagePath);
  }
}

class _BrokenPicker implements ImagePickerPort {
  @override
  Future<List<PickedImage>> pickImages({required int max}) =>
      Future.error(StateError('already_active'));
}

void main() {
  test('uploads to avatars/{uid}/{ulid}.jpg, points the profile at it, removes the old one', () async {
    final (c, users, uploader) = await _setup([
      [_a],
      [_b],
    ]);
    await c.read(avatarControllerProvider.notifier).change();
    final first = uploader.uploaded.single;
    expect(first, matches(_avatarPath));
    expect(
      (await users.watch('fake-1').first)!.avatarUrl,
      'https://storage.test/$first',
    );
    expect(c.read(avatarControllerProvider).value, isTrue);

    await c.read(avatarControllerProvider.notifier).change();
    expect(uploader.deleted, [first]);
    expect(uploader.uploaded.single, isNot(first));
  });

  test('a cancelled pick changes nothing', () async {
    final (c, users, uploader) = await _setup([[]]);
    await c.read(avatarControllerProvider.notifier).change();
    expect(uploader.uploadCalls, 0);
    expect(c.read(avatarControllerProvider).value, isFalse);
    expect((await users.watch('fake-1').first)!.avatarUrl, isNull);
  });

  test('a failed upload keeps the old photo', () async {
    final (c, users, uploader) = await _setup([
      [_a],
    ]);
    uploader.failNames.add('a.jpg');
    await c.read(avatarControllerProvider.notifier).change();
    expect(c.read(avatarControllerProvider).hasError, isTrue);
    expect(users.avatarPaths, isEmpty);
  });

  test('a failed profile write deletes the new upload again', () async {
    final (c, users, uploader) = await _setup([
      [_a],
    ]);
    users.failSetAvatar = true;
    await c.read(avatarControllerProvider.notifier).change();
    expect(c.read(avatarControllerProvider).hasError, isTrue);
    expect(uploader.uploaded, isEmpty);
    expect(uploader.deleted.single, matches(_avatarPath));
  });

  test('the avatar button style follows a new photo at once', () async {
    final (c, users, _) = await _setup(
      [
        [_a],
      ],
      prefs: {'buttonStyle': 'avatar'},
    );
    final cta = c.listen(ctaAvatarProvider, (_, _) {});
    addTearDown(cta.close);
    await c.read(currentProfileProvider.future);
    expect(cta.read(), isNull, reason: 'no photo yet: the gradient is used');
    await c.read(avatarControllerProvider.notifier).change();
    await Future<void>.delayed(Duration.zero);
    final url = (await users.watch('fake-1').first)!.avatarUrl!;
    expect(cta.read(), NetworkImage(url));
  });

  test('leaving the screen mid-upload still saves the new photo', () async {
    final gated = _GatedUploader();
    final (c, users, _) = await _setup(
      [
        [_a],
      ],
      uploader: gated,
      listen: false,
    );
    final sub = c.listen(avatarControllerProvider, (_, _) {});
    final done = c.read(avatarControllerProvider.notifier).change();
    await Future<void>.delayed(Duration.zero);
    sub.close(); // S42 popped: no listener is left
    await Future<void>.delayed(Duration.zero);
    gated.gate.complete();
    await done;
    expect(users.avatarPaths['fake-1'], matches(_avatarPath));
    expect(gated.uploaded.single, users.avatarPaths['fake-1']);
    expect(gated.deleted, isEmpty);
  });

  test('a picker error surfaces as an error', () async {
    final (c, users, uploader) = await _setup(
      const [],
      picker: _BrokenPicker(),
    );
    await c.read(avatarControllerProvider.notifier).change();
    expect(c.read(avatarControllerProvider).hasError, isTrue);
    expect(uploader.uploadCalls, 0);
    expect(users.avatarPaths, isEmpty);
  });

  test('a second tap while the first change is running is ignored', () async {
    final gated = _GatedUploader();
    final picker = FakeImagePicker([
      [_a],
      [_b],
    ]);
    final (c, _, _) = await _setup(const [], uploader: gated, picker: picker);
    final first = c.read(avatarControllerProvider.notifier).change();
    await c.read(avatarControllerProvider.notifier).change();
    gated.gate.complete();
    await first;
    expect(picker.calls, 1);
  });
}

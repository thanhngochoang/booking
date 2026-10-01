# Step 3c: Create Post (S21), Image Upload and the Post Write Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A photographer picks up to 10 photos from the gallery, writes a caption, chooses the package (required), optionally a place and a style, and publishes once for the feed and the portfolio. Photos upload one at a time with per-photo progress and retry, nothing is left orphaned in Storage, the text of the form survives leaving the screen, and the new post is the first thing on Home afterwards.

**Architecture:** Ports in `lib/data/media/` (`ImagePickerPort`, `MediaUploader`) and `lib/data/content/` (`PostPublisher`) with fakes and one adapter each; only `firebase_media_uploader.dart` imports `firebase_storage`, only `firestore_post_publisher.dart` imports `cloud_firestore`, only `plugin_image_picker.dart` imports `image_picker`. A `PostComposerController` (Riverpod `Notifier`) owns the form state and orchestrates upload then create; `CreatePostScreen` only renders it. Photos are scaled to 2048 px and re-encoded by the picker, uploaded with `putFile` (streamed from disk, never held in memory), and the post document is written in one batch with the portfolio entry. Hashtags are extracted from the caption and stored; linking them to an event timeline is the server's job (spec 3.7) and is not done here.

**Tech Stack:** Flutter, Riverpod 3, `image_picker`, `firebase_storage`, `cloud_firestore` (adapter only), `fake_cloud_firestore` (dev), Firestore and Storage rules with `@firebase/rules-unit-testing`, `flutter_test`.

**Spec:** `docs/superpowers/specs/screens/photographer.md` (S21, S22), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3.7 (hashtags), §5, §6, §7; `docs/superpowers/specs/data-model/domain-model.md` (`Post`, `PostImage`, `PostHashtag`; ULID ids); `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` §5 (post document, Storage resize ≤ 2048 px); mock `docs/design/ui-mock.html` (`data-code="S21"`).

**Prerequisite:** plans 3a1 to 3b4 are done (`ServiceRepository`, `PostRepository`, `FakePostRepository`, `PostImage`, `PostSummary`, `HomeFeedController`, `OptionRow`, `showAppSheet`, `screenApp`, `DiscoveryWorld`); the screen-codes plan is done (`ScreenCodes.createPost`, `test/support/idle.dart`, `docs/testing/battery-and-performance.md`). Plan 2d (S24 package setup) registers `/setup/2`, where "Thêm gói" leads; the events plan adds the "Sự kiện" tab of this screen (S25), which is therefore absent here.

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features import `package:photobooking/core/core.dart`.
- **Isolation:** `firebase_storage` only in `lib/data/media/firebase_media_uploader.dart`; `cloud_firestore` only in `lib/data/content/firestore_post_publisher.dart` (and the existing content adapters); `image_picker` only in `lib/data/media/plugin_image_picker.dart`.
- Data conventions (`data-model/README.md`): post ids are ULIDs generated on the device; instants are UTC; the client never writes counters (`likeCount`, `saveCount` start at 0 and only Functions change them); hashtags are lower case without `#`.
- **Rules:** a photographer may create `posts/{id}` only as themself, `kind: work`, with 1 to 10 images, a service that is theirs and exists, zero counters and the server timestamp; nobody edits or deletes posts from the client yet. Storage: `posts/{uid}/…` writable by that user only, images up to 8 MB, readable by signed-in users.
- **Battery and data:** uploads run one at a time, from disk, with progress reported in steps of at least 5 percent; photos are re-encoded to at most 2048 px JPEG (quality 85) by the picker; the screen holds file paths, never image bytes; no timers, no background uploads, no listeners.
- **Platform (Android and iOS):** gallery only. `ios/Runner/Info.plist` gets `NSPhotoLibraryUsageDescription` in Vietnamese; no camera, microphone or location keys. `android/app/src/main/AndroidManifest.xml` gets no storage, camera or media permission (the system photo picker needs none). A test reads both files. iOS cannot be built on this machine yet (separate "iOS enablement" plan).
- No hard-coded UI text: Vietnamese strings with full diacritics in `lib/l10n/app_vi.arb`, then `flutter gen-l10n`. One primary action: "Đăng". Layouts tested at width 320 and text scale 1.3; interactive controls 48dp; at most 4 `BackdropFilter`s per screen and none nested (this screen has none outside sheets).
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/ulid.dart`, `lib/core/hashtags.dart` (create) | `newUlid`, `ulidTime`; `extractHashtags` |
| `lib/data/media/image_picker_port.dart` (create) | `PickedImage`, `ImagePickerPort`, `FakeImagePicker` |
| `lib/data/media/plugin_image_picker.dart` (create) | `PluginImagePicker` (the only `image_picker` import) |
| `lib/data/media/media_uploader.dart` (create) | `UploadedMedia`, `UploadEvent`, `MediaUploader`, `FakeMediaUploader` |
| `lib/data/media/firebase_media_uploader.dart` (create) | `FirebaseMediaUploader` (the only `firebase_storage` import) |
| `lib/data/content/post_publisher.dart` (create) | `PostDraft`, `PostPublisher`, `FakePostPublisher` |
| `lib/data/content/firestore_post_publisher.dart` (create) | `FirestorePostPublisher` |
| `lib/features/create_post/create_post_providers.dart` (create) | providers for the ports, `myServicesProvider` |
| `lib/features/create_post/post_composer.dart` (create) | `PostComposerController`, `postComposerProvider`, `ComposerState`, `ComposerImage`, `PostPublishResult` |
| `lib/features/create_post/create_post_screen.dart` (create) | S21 |
| `lib/features/home/home_controller.dart` (modify) | `pinToTop` |
| `lib/features/shell/placeholder_tabs.dart`, `test/features/responsive_test.dart` (modify) | photographer branch of `ActionTab` |
| `storage.rules`, `firebase/firebase.json`, `firebase/rules-test/*` (create/modify) | Storage rules and tests; Firestore post-create rules and tests |
| `ios/Runner/Info.plist` (modify) | photo library reason |
| `pubspec.yaml`, `lib/l10n/app_vi.arb` (modify) | `image_picker`, `firebase_storage`; strings |
| tests | listed per task; `test/battery/create_post_battery_test.dart` |

(`storage.rules` lives next to `firestore.rules`, in `app_flutter/firebase/`.)

---

### Task 1: Ids, hashtags, the image picker port and the platform configuration

**Files:**
- Create: `lib/core/ulid.dart`, `lib/core/hashtags.dart`, `lib/data/media/image_picker_port.dart`, `lib/data/media/plugin_image_picker.dart`, `test/core/ulid_test.dart`, `test/core/hashtags_test.dart`, `test/data/media/image_picker_port_test.dart`, `test/platform/media_platform_config_test.dart`
- Modify: `lib/core/core.dart`, `ios/Runner/Info.plist`, `pubspec.yaml` (via `flutter pub add`)

**Interfaces:**
- Produces:
  - `String newUlid({DateTime? now, math.Random? random})` — 26 Crockford-base32 characters, the first 10 encode the UTC millisecond time, so ids sort by creation time; `DateTime? ulidTime(String id)` decodes it (null for anything that is not a 26-character ULID).
  - `List<String> extractHashtags(String caption)` — lower-case tags without `#`, unique, in order of appearance, 2 to 40 letters/digits/underscores (Vietnamese letters allowed), not inside a URL or a word, at most 30.
  - `class PickedImage { const PickedImage({required String path, required String name, int? sizeBytes}); }`
  - `abstract class ImagePickerPort { Future<List<PickedImage>> pickImages({required int max}); }` — opens the system gallery picker; photos are already scaled to at most 2048 px and re-encoded as JPEG quality 85; empty when cancelled.
  - `FakeImagePicker([List<List<PickedImage>> answers])` with `calls`, `requestedMax`; `PluginImagePicker({ImagePicker? picker})`.

- [ ] **Step 1: Add the packages and write the failing tests**

```bash
flutter pub add image_picker firebase_storage
flutter pub deps --style=compact | grep -E "^- (image_picker|firebase_storage) "
```

Expected: two lines, `image_picker 1.1` or newer (the `limit` parameter of `pickMultiImage` needs 1.1) and a `firebase_storage` major that resolves against the pinned `firebase_core ^4`. If pub reports a conflict, stop and report it instead of downgrading Firebase.

```dart
// test/core/ulid_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/ulid.dart';

void main() {
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  test('26 characters from the Crockford alphabet', () {
    final id = newUlid();
    expect(id, hasLength(26));
    expect(id.split('').every(alphabet.contains), isTrue);
  });

  test('the first ten characters are the time, so ids sort by creation', () {
    final a = newUlid(now: DateTime.utc(2026, 10, 1, 5), random: Random(1));
    final b = newUlid(now: DateTime.utc(2026, 10, 1, 5, 0, 0, 1), random: Random(1));
    final c = newUlid(now: DateTime.utc(2027), random: Random(1));
    expect([c, a, b]..sort(), [a, b, c]);
    expect(a.substring(0, 10).compareTo(b.substring(0, 10)), lessThan(0));
  });

  test('the time can be read back', () {
    final t = DateTime.utc(2026, 10, 1, 5, 30, 15, 123);
    expect(ulidTime(newUlid(now: t)), t);
  });

  test('same millisecond, different randomness: different ids', () {
    final t = DateTime.utc(2026, 10, 1);
    expect(newUlid(now: t, random: Random(1)), isNot(newUlid(now: t, random: Random(2))));
    expect(newUlid(now: t, random: Random(7)), newUlid(now: t, random: Random(7)));
  });

  test('ulidTime rejects things that are not ULIDs', () {
    expect(ulidTime('abc'), isNull);
    expect(ulidTime('x' * 26), isNull);
    expect(ulidTime('I' * 26), isNull, reason: 'I is not in the alphabet');
  });
}
```

```dart
// test/core/hashtags_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/hashtags.dart';

void main() {
  test('lower-cases, strips the hash and keeps the order', () {
    expect(extractHashtags('Chiều muộn #ChanDung và #photowalk'), ['chandung', 'photowalk']);
  });

  test('duplicates are dropped ignoring case', () {
    expect(extractHashtags('#Cuoi #cuoi #CUOI #gia_dinh'), ['cuoi', 'gia_dinh']);
  });

  test('Vietnamese letters and digits are part of a tag', () {
    expect(extractHashtags('#nhiếpảnh #PhotoWalkPhoCo1020'), ['nhiếpảnh', 'photowalkphoco1020']);
  });

  test('a lone hash, a one-letter tag and punctuation do not make tags', () {
    expect(extractHashtags('# #a #! hello'), isEmpty);
    expect(extractHashtags('Đẹp quá #chandung, #cuoi.'), ['chandung', 'cuoi']);
  });

  test('a tag is not taken from inside a word or a link', () {
    expect(extractHashtags('mail a#b link https://x.vn/page#section'), isEmpty);
    expect(extractHashtags('(#hoa) "#nang"'), ['hoa', 'nang']);
  });

  test('a tag over 40 characters is ignored and at most 30 are kept', () {
    expect(extractHashtags('#${'a' * 41}'), isEmpty);
    final many = List.generate(40, (i) => '#tag$i').join(' ');
    expect(extractHashtags(many), hasLength(30));
    expect(extractHashtags(many).first, 'tag0');
  });

  test('empty text has no tags', () {
    expect(extractHashtags(''), isEmpty);
  });
}
```

```dart
// test/data/media/image_picker_port_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

void main() {
  const a = PickedImage(path: '/tmp/a.jpg', name: 'a.jpg', sizeBytes: 1200);
  const b = PickedImage(path: '/tmp/b.jpg', name: 'b.jpg');

  test('the fake answers in order and records how many were asked for', () async {
    final picker = FakeImagePicker([
      [a, b],
      [],
    ]);
    expect(await picker.pickImages(max: 10), [a, b]);
    expect(await picker.pickImages(max: 8), isEmpty, reason: 'cancelled');
    expect(await picker.pickImages(max: 3), isEmpty, reason: 'nothing queued');
    expect(picker.calls, 3);
    expect(picker.requestedMax, [10, 8, 3]);
  });

  test('the fake never returns more than were asked for', () async {
    final picker = FakeImagePicker([
      [a, b, a],
    ]);
    expect(await picker.pickImages(max: 2), hasLength(2));
  });
}
```

```dart
// test/platform/media_platform_config_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('iOS explains the photo library in Vietnamese and asks for nothing else', () {
    expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
    final reason = RegExp(
      r'<key>NSPhotoLibraryUsageDescription</key>\s*<string>([^<]+)</string>',
    ).firstMatch(plist)!.group(1)!;
    expect(reason, contains('thư viện ảnh'));
    for (final banned in [
      'NSCameraUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSPhotoLibraryAddUsageDescription',
      'NSLocationAlwaysAndWhenInUseUsageDescription',
    ]) {
      expect(plist, isNot(contains(banned)), reason: banned);
    }
  });

  test('Android needs no storage, media or camera permission for the system picker', () {
    for (final banned in [
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'READ_MEDIA_IMAGES',
      'READ_MEDIA_VISUAL_USER_SELECTED',
      'android.permission.CAMERA',
      'MANAGE_EXTERNAL_STORAGE',
    ]) {
      expect(manifest, isNot(contains(banned)), reason: banned);
    }
  });

  test('image_picker is imported in one file only', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains("package:image_picker/"))
        .map((f) => f.path)
        .toList();
    expect(offenders, ['lib/data/media/plugin_image_picker.dart']);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/ulid_test.dart test/core/hashtags_test.dart test/data/media/image_picker_port_test.dart test/platform/media_platform_config_test.dart`
Expected: FAIL (libraries missing; the plist has no photo library key; the last platform test fails until the plugin adapter file exists).

- [ ] **Step 3: Implement**

Add inside the top-level `<dict>` of `ios/Runner/Info.plist`, before its closing `</dict>`:

```xml
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Ứng dụng cần truy cập thư viện ảnh để bạn chọn ảnh đăng lên hồ sơ và bài đăng.</string>
```

```dart
// lib/core/ulid.dart
import 'dart:math' as math;

const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// A ULID: 10 characters of UTC millisecond time, then 16 random ones.
/// Ids made later sort later, and they can be created on the device without
/// asking the server (data-model/README.md, section 2.1).
String newUlid({DateTime? now, math.Random? random}) {
  var time = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  final rng = random ?? math.Random.secure();
  final out = List<String>.filled(26, '0');
  for (var i = 9; i >= 0; i--) {
    out[i] = _alphabet[time % 32];
    time ~/= 32;
  }
  for (var i = 10; i < 26; i++) {
    out[i] = _alphabet[rng.nextInt(32)];
  }
  return out.join();
}

/// The creation time inside a ULID, or null when [id] is not one.
DateTime? ulidTime(String id) {
  if (id.length != 26) {
    return null;
  }
  var ms = 0;
  for (var i = 0; i < 10; i++) {
    final v = _alphabet.indexOf(id[i]);
    if (v < 0) {
      return null;
    }
    ms = ms * 32 + v;
  }
  for (var i = 10; i < 26; i++) {
    if (_alphabet.indexOf(id[i]) < 0) {
      return null;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
```

```dart
// lib/core/hashtags.dart

// A tag starts at a `#` that is not glued to a word, a path or an entity.
final _tag = RegExp(r'(?<![\p{L}\p{N}_/&#])#([\p{L}\p{N}_]+)', unicode: true);

/// Hashtags in [caption]: lower case, no `#`, unique, in order, 2 to 40
/// characters, at most 30. They are stored with the post; linking them to an
/// event timeline is done by the server (spec 3.7).
List<String> extractHashtags(String caption) {
  final seen = <String>{};
  final out = <String>[];
  for (final m in _tag.allMatches(caption)) {
    final tag = m.group(1)!.toLowerCase();
    if (tag.length < 2 || tag.length > 40 || !seen.add(tag)) {
      continue;
    }
    out.add(tag);
    if (out.length == 30) {
      break;
    }
  }
  return out;
}
```

Export `ulid.dart` and `hashtags.dart` from `core.dart`.

```dart
// lib/data/media/image_picker_port.dart
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
```

```dart
// lib/data/media/plugin_image_picker.dart
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
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/core/ulid_test.dart test/core/hashtags_test.dart test/data/media test/platform && flutter analyze`
Expected: PASS (ulid 5, hashtags 7, picker 2, platform 3); analyze clean. If the "link" hashtag case fails, the lookbehind must contain `/` and the character class `\p{L}\p{N}_&#`; `unicode: true` is required for `\p{L}`.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist lib/core lib/data/media test/core test/data/media test/platform
git commit -m "feat(media): ULIDs, hashtags, gallery picker port and platform permissions

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `MediaUploader`, the Storage adapter and Storage rules

**Files:**
- Create: `lib/data/media/media_uploader.dart`, `lib/data/media/firebase_media_uploader.dart`, `firebase/storage.rules`, `test/data/media/media_uploader_test.dart`
- Modify: `firebase/firebase.json`, `firebase/rules-test/package.json`, `firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Produces:
  - `class UploadedMedia { const UploadedMedia({required String url, required String storagePath}); }`
  - `class UploadEvent { const UploadEvent.progress(double fraction); const UploadEvent.done(UploadedMedia media); final double fraction; final UploadedMedia? media; bool get isDone; }`
  - `abstract class MediaUploader { Stream<UploadEvent> upload(PickedImage image, {required String storagePath}); Future<void> delete(String storagePath); }` — the stream emits progress events and ends with exactly one done event; a failure is a stream error; `delete` is idempotent (a missing object is not an error).
  - `FakeMediaUploader` with `Set<String> failNames` (image names whose upload fails after a first progress event), `List<String> uploaded` (paths currently stored), `List<String> deleted`, `int uploadCalls`, `int maxConcurrent` (the most uploads that were open at the same time), `Object? deleteFailure`.
  - `FirebaseMediaUploader({FirebaseStorage? storage})`: `putFile` with content type `image/jpeg`, progress reported at most every 5 percent, URL from `getDownloadURL`.
- Rules: `posts/{uid}/{postId}/{file}` readable by signed-in users, created and overwritten only by `uid` for `image/*` under 8 MB, deleted only by `uid`; everything else denied.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/media/media_uploader_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

const _img = PickedImage(path: '/tmp/a.jpg', name: 'a.jpg');

void main() {
  test('a successful upload reports progress and ends with one done event', () async {
    final up = FakeMediaUploader();
    final events = await up.upload(_img, storagePath: 'posts/u1/p1/a.jpg').toList();
    expect(events.where((e) => !e.isDone).every((e) => e.fraction >= 0 && e.fraction <= 1), isTrue);
    expect(events.where((e) => e.isDone), hasLength(1));
    expect(events.last.isDone, isTrue);
    expect(events.last.media!.storagePath, 'posts/u1/p1/a.jpg');
    expect(events.last.media!.url, startsWith('https://'));
    expect(up.uploaded, ['posts/u1/p1/a.jpg']);
    expect(up.uploadCalls, 1);
  });

  test('a failing image gives a stream error after some progress and stores nothing', () async {
    final up = FakeMediaUploader()..failNames.add('a.jpg');
    final seen = <UploadEvent>[];
    await expectLater(
      up.upload(_img, storagePath: 'posts/u1/p1/a.jpg').map((e) {
        seen.add(e);
        return e;
      }).drain<void>(),
      throwsStateError,
    );
    expect(seen, isNotEmpty);
    expect(seen.any((e) => e.isDone), isFalse);
    expect(up.uploaded, isEmpty);
  });

  test('delete removes the object, is idempotent, and is recorded', () async {
    final up = FakeMediaUploader();
    await up.upload(_img, storagePath: 'posts/u1/p1/a.jpg').drain<void>();
    await up.delete('posts/u1/p1/a.jpg');
    await up.delete('posts/u1/p1/a.jpg');
    expect(up.uploaded, isEmpty);
    expect(up.deleted, ['posts/u1/p1/a.jpg', 'posts/u1/p1/a.jpg']);
  });

  test('the fake records the most uploads open at once', () async {
    final up = FakeMediaUploader();
    await up.upload(_img, storagePath: 'a').drain<void>();
    await up.upload(_img, storagePath: 'b').drain<void>();
    expect(up.maxConcurrent, 1);
    await Future.wait([
      up.upload(_img, storagePath: 'c').drain<void>(),
      up.upload(_img, storagePath: 'd').drain<void>(),
    ]);
    expect(up.maxConcurrent, 2);
  });

  test('the Storage adapter streams from disk and throttles progress', () {
    final src = File('lib/data/media/firebase_media_uploader.dart').readAsStringSync();
    expect(src, contains('putFile'));
    expect(src, isNot(contains('putData')));
    expect(src, isNot(contains('readAsBytes')));
    expect(src, contains('0.05'), reason: 'progress in steps of at least 5 percent');
    expect(src, contains("contentType: 'image/jpeg'"));
    expect(src, contains('object-not-found'));
    for (final banned in ['Timer', 'Stream.periodic']) {
      expect(src, isNot(contains(banned)));
    }
  });

  test('firebase_storage is imported in one file only', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('package:firebase_storage/'))
        .map((f) => f.path)
        .toList();
    expect(offenders, ['lib/data/media/firebase_media_uploader.dart']);
  });
}
```

Append to `firebase/rules-test/rules.test.mjs` (and extend the top import with `import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';`). The test environment must also load Storage rules: in the `initializeTestEnvironment` call add
`storage: { rules: readFileSync('../storage.rules', 'utf8'), host: '127.0.0.1', port: 9199 },` beside the `firestore` entry.

```js
// ---- Storage: post photos ----
const photo = (n = 4) => new Uint8Array(n);
const jpeg = { contentType: 'image/jpeg' };

test('a user uploads, reads and deletes photos under their own post path', async () => {
  const st = env.authenticatedContext('ph1').storage();
  const r = ref(st, 'posts/ph1/post1/a.jpg');
  await assertSucceeds(uploadBytes(r, photo(), jpeg));
  await assertSucceeds(getBytes(r));
  await assertSucceeds(deleteObject(r));
});

test('nobody uploads into or deletes from someone else\'s post path', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    uploadBytes(ref(c.storage(), 'posts/ph1/post1/b.jpg'), photo(), jpeg));
  const other = env.authenticatedContext('ph2').storage();
  await assertFails(uploadBytes(ref(other, 'posts/ph1/post1/c.jpg'), photo(), jpeg));
  await assertFails(deleteObject(ref(other, 'posts/ph1/post1/b.jpg')));
  await assertSucceeds(getBytes(ref(other, 'posts/ph1/post1/b.jpg'))); // reading is for every signed-in user
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), 'posts/ph1/post1/b.jpg')));
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(), 'posts/ph1/post1/d.jpg'), photo(), jpeg));
});

test('only images up to 8 MB are accepted', async () => {
  const st = env.authenticatedContext('ph1').storage();
  await assertFails(uploadBytes(ref(st, 'posts/ph1/post1/e.pdf'), photo(), { contentType: 'application/pdf' }));
  await assertFails(uploadBytes(ref(st, 'posts/ph1/post1/f.jpg'), photo(8 * 1024 * 1024 + 1), jpeg));
  await assertSucceeds(uploadBytes(ref(st, 'posts/ph1/post1/g.jpg'), photo(1024 * 1024), jpeg));
});

test('every other Storage path is closed', async () => {
  const st = env.authenticatedContext('ph1').storage();
  await assertFails(uploadBytes(ref(st, 'avatars/ph1/a.jpg'), photo(), jpeg));
  await assertFails(uploadBytes(ref(st, 'posts/ph1/a.jpg'), photo(), jpeg)); // missing the post folder
  await assertFails(getBytes(ref(st, 'misc/x.jpg')));
});
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/media/media_uploader_test.dart`; from `firebase/rules-test`: `npm ci && npm test`
Expected: FAIL (libraries missing; the Storage rules file does not exist). If the emulator cannot run in this sandbox, say so and rely on the CI job "Firestore rules tests (emulator)" (extended below to start the Storage emulator).

- [ ] **Step 3: Implement**

```dart
// lib/data/media/media_uploader.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/media/image_picker_port.dart';

@immutable
class UploadedMedia {
  const UploadedMedia({required this.url, required this.storagePath});

  /// Download URL, stored on the post as `imageUrls[i]`.
  final String url;

  /// Where the object lives; kept so it can be deleted again.
  final String storagePath;
}

@immutable
class UploadEvent {
  const UploadEvent.progress(this.fraction) : media = null;
  const UploadEvent.done(UploadedMedia this.media) : fraction = 1;

  final double fraction;
  final UploadedMedia? media;
  bool get isDone => media != null;
}

abstract class MediaUploader {
  /// Uploads [image] to [storagePath]. Emits progress events and then one done
  /// event; a failure is a stream error.
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath});

  /// Removes an uploaded object. A missing object is not an error.
  Future<void> delete(String storagePath);
}

class FakeMediaUploader implements MediaUploader {
  /// Names of images whose upload fails after a first progress event.
  final Set<String> failNames = {};

  /// Storage paths that currently hold an object.
  final List<String> uploaded = [];
  final List<String> deleted = [];
  int uploadCalls = 0;

  /// The most uploads that were open at the same time.
  int maxConcurrent = 0;
  Object? deleteFailure;
  int _open = 0;

  @override
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath}) async* {
    uploadCalls++;
    _open++;
    if (_open > maxConcurrent) {
      maxConcurrent = _open;
    }
    try {
      yield const UploadEvent.progress(0.2);
      await Future<void>.delayed(Duration.zero);
      if (failNames.contains(image.name)) {
        throw StateError('upload failed: ${image.name}');
      }
      yield const UploadEvent.progress(0.6);
      await Future<void>.delayed(Duration.zero);
      uploaded.add(storagePath);
      yield UploadEvent.done(
        UploadedMedia(url: 'https://storage.test/$storagePath', storagePath: storagePath),
      );
    } finally {
      _open--;
    }
  }

  @override
  Future<void> delete(String storagePath) async {
    if (deleteFailure != null) {
      throw deleteFailure!;
    }
    deleted.add(storagePath);
    uploaded.remove(storagePath);
  }
}
```

```dart
// lib/data/media/firebase_media_uploader.dart
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class FirebaseMediaUploader implements MediaUploader {
  FirebaseMediaUploader({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;
  final FirebaseStorage _storage;

  @override
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath}) async* {
    final ref = _storage.ref(storagePath);
    // Streamed from disk: a 10-photo post never holds the photos in memory.
    final task = ref.putFile(
      File(image.path),
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );
    var last = 0.0;
    await for (final s in task.snapshotEvents) {
      if (s.totalBytes <= 0) {
        continue;
      }
      final fraction = s.bytesTransferred / s.totalBytes;
      // At most one update per 5 percent, so the screen is not rebuilt for
      // every chunk.
      if (fraction - last >= 0.05 && fraction < 1) {
        last = fraction;
        yield UploadEvent.progress(fraction);
      }
    }
    await task; // throws when the upload failed
    yield UploadEvent.done(
      UploadedMedia(url: await ref.getDownloadURL(), storagePath: storagePath),
    );
  }

  @override
  Future<void> delete(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}
```

`firebase/storage.rules`:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Post photos: posts/{uid}/{postId}/{file}. Anyone signed in may look at
    // them; only the owner may add, replace or delete, and only images up to 8 MB.
    match /posts/{uid}/{postId}/{file} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null
        && request.auth.uid == uid
        && request.resource.size < 8 * 1024 * 1024 + 1
        && request.resource.contentType.matches('image/.*');
      allow delete: if request.auth != null && request.auth.uid == uid;
    }
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

`firebase/firebase.json`: add the Storage rules file and emulator beside the existing entries:

```json
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "storage": { "rules": "storage.rules" },
  "emulators": {
    "firestore": { "host": "127.0.0.1", "port": 8080 },
    "auth": { "host": "127.0.0.1", "port": 9099 },
    "storage": { "host": "127.0.0.1", "port": 9199 },
    "ui": { "enabled": false }
  }
}
```

(Keep any other emulator or rules entries other plans added.) In `firebase/rules-test/package.json` change the test script's `--only firestore` to `--only firestore,storage`. The CI job already runs `npm ci && npm test` from that folder, so it now covers both rule sets.

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/media && flutter analyze`; from `firebase/rules-test`: `npm test`
Expected: PASS (6 Dart tests, 4 new rules tests plus all existing ones). If the 8 MB boundary case fails, check the arithmetic: the rule accepts sizes up to and including 8 MiB (`size < 8 * 1024 * 1024 + 1`).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/media test/data/media firebase
git commit -m "feat(media): MediaUploader port, Storage adapter and Storage rules

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `PostDraft`, `PostPublisher`, the Firestore write path

**Files:**
- Create: `lib/data/content/post_publisher.dart`, `lib/data/content/firestore_post_publisher.dart`, `test/data/content/post_publisher_test.dart`

**Interfaces:**
- Consumes: `PostImage`, `PostSummary`, `PostKind`, `FakePostRepository`, `FirestorePostRepository`, `extractHashtags`.
- Produces:
  - `class PostDraft { const PostDraft({required String id, required String photographerId, required String serviceId, String? specialtyId, required List<PostImage> images, String caption = '', String? locationName, String? styleId, bool inPortfolio = true}); }` — `id` is a ULID made on the device, so a retry after a timeout overwrites the same document instead of duplicating it. `specialtyId` is the specialty of the chosen package, stored on the post so Home can filter by it.
  - `abstract class PostPublisher { Future<PostSummary> publish(PostDraft draft); }`
  - `FakePostPublisher({required FakePostRepository posts, DateTime Function()? clock})` with `published` (the drafts), `Object? failWith`; the post it creates is added to `posts` so a Home feed built on the same fake shows it.
  - `FirestorePostPublisher({FirebaseFirestore? db})`: one batch writes `posts/{id}` (kind `work`, author = photographer, zero counters, `hashtags` extracted from the caption, `createdAt` server time) and, when `inPortfolio`, adds the id to `photographers/{uid}.portfolio`; the commit has a 20 second deadline so an offline phone reports a failure instead of spinning forever (the queued write is idempotent).
- The returned `PostSummary.createdAt` is the device time (the server stamp replaces it in the stored document).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/content/post_publisher_test.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/firestore_post_publisher.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/post_summary.dart';

import '../../support/content_fixtures.dart';

PostDraft draft({
  String id = '01J9ZZZZZZZZZZZZZZZZZZZZZZ',
  String caption = 'Chiều muộn ở bến Bạch Đằng #ChanDung #phoco',
  String? location = 'Bến Bạch Đằng',
  String? style = 'natural_light',
  String? specialty = 'portrait',
  bool portfolio = true,
  int images = 2,
}) => PostDraft(
  id: id,
  photographerId: 'p1',
  serviceId: 's1',
  specialtyId: specialty,
  images: [
    for (var i = 0; i < images; i++)
      PostImage(url: 'https://storage.test/posts/p1/$id/$i.jpg'),
  ],
  caption: caption,
  locationName: location,
  styleId: style,
  inPortfolio: portfolio,
);

typedef Env = ({PostPublisher publisher, PostRepository reader});

void postPublisherContract(String name, Future<Env> Function() create) {
  group('PostPublisher contract: $name', () {
    late Env env;
    setUp(() async => env = await create());

    test('the published post can be read back with everything that was entered', () async {
      final made = await env.publisher.publish(draft());
      expect(made.id, '01J9ZZZZZZZZZZZZZZZZZZZZZZ');
      final read = (await env.reader.byId(made.id))!;
      expect(read.kind, PostKind.work);
      expect(read.authorId, 'p1');
      expect(read.photographerId, 'p1');
      expect(read.serviceId, 's1');
      expect(read.specialtyId, 'portrait');
      expect(read.styleId, 'natural_light');
      expect(read.locationName, 'Bến Bạch Đằng');
      expect(read.caption, 'Chiều muộn ở bến Bạch Đằng #ChanDung #phoco');
      expect(read.hashtags, ['chandung', 'phoco']);
      expect(read.images.map((i) => i.url), [
        'https://storage.test/posts/p1/01J9ZZZZZZZZZZZZZZZZZZZZZZ/0.jpg',
        'https://storage.test/posts/p1/01J9ZZZZZZZZZZZZZZZZZZZZZZ/1.jpg',
      ]);
      expect(read.inPortfolio, isTrue);
      expect((read.likeCount, read.saveCount), (0, 0));
    });

    test('the new post is the first of the feed', () async {
      await env.publisher.publish(draft(id: '01J9AAAAAAAAAAAAAAAAAAAAAA'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await env.publisher.publish(draft(id: '01J9BBBBBBBBBBBBBBBBBBBBBB'));
      final feed = await env.reader.feed();
      expect(feed.posts.first.id, '01J9BBBBBBBBBBBBBBBBBBBBBB');
    });

    test('publishing the same draft twice leaves one post', () async {
      await env.publisher.publish(draft());
      await env.publisher.publish(draft(caption: 'Đã sửa lỗi chính tả'));
      final feed = await env.reader.feed();
      expect(feed.posts, hasLength(1));
      expect(feed.posts.single.caption, 'Đã sửa lỗi chính tả');
    });

    test('optional fields may be absent', () async {
      final made = await env.publisher.publish(
        draft(location: null, style: null, specialty: null, portfolio: false, images: 1),
      );
      final read = (await env.reader.byId(made.id))!;
      expect((read.locationName, read.styleId, read.specialtyId), (null, null, null));
      expect(read.inPortfolio, isFalse);
      expect(read.images, hasLength(1));
    });
  });
}

void main() {
  postPublisherContract('fake', () async {
    final posts = FakePostRepository();
    return (
      publisher: FakePostPublisher(posts: posts, clock: () => DateTime.now().toUtc()),
      reader: posts,
    );
  });

  postPublisherContract('firestore', () async {
    final db = FakeFirebaseFirestore();
    return (publisher: FirestorePostPublisher(db: db), reader: FirestorePostRepository(db: db));
  });

  group('FakePostPublisher', () {
    test('records drafts, fails on demand and stores nothing then', () async {
      final posts = FakePostRepository();
      final pub = FakePostPublisher(posts: posts, clock: () => fixtureNow);
      final made = await pub.publish(draft());
      expect(made.createdAt, fixtureNow);
      expect(pub.published.single.id, made.id);
      pub.failWith = StateError('offline');
      await expectLater(pub.publish(draft(id: '01J9CCCCCCCCCCCCCCCCCCCCCC')), throwsStateError);
      expect((await posts.feed()).posts, hasLength(1));
    });
  });

  group('FirestorePostPublisher documents', () {
    test('writes the shape the rules expect and no counters but zero', () async {
      final db = FakeFirebaseFirestore();
      await FirestorePostPublisher(db: db).publish(draft());
      final d = (await db.collection('posts').doc('01J9ZZZZZZZZZZZZZZZZZZZZZZ').get()).data()!;
      expect(d.keys.toSet(), {
        'kind', 'authorId', 'photographerId', 'serviceId', 'specialty', 'imageUrls',
        'imageMeta', 'caption', 'location', 'style', 'hashtags', 'inPortfolio',
        'likeCount', 'saveCount', 'createdAt',
      });
      expect(d['kind'], 'work');
      expect((d['likeCount'], d['saveCount']), (0, 0));
      expect(d['createdAt'], isA<Timestamp>());
      expect((d['imageMeta'] as List), hasLength(2));
      expect(d['location'], {'name': 'Bến Bạch Đằng'});
    });

    test('the portfolio gets the post id, even when the photographer document is new', () async {
      final db = FakeFirebaseFirestore();
      final pub = FirestorePostPublisher(db: db);
      await pub.publish(draft(id: '01J9AAAAAAAAAAAAAAAAAAAAAA'));
      await pub.publish(draft(id: '01J9BBBBBBBBBBBBBBBBBBBBBB'));
      final p = (await db.collection('photographers').doc('p1').get()).data()!;
      expect(p['portfolio'], ['01J9AAAAAAAAAAAAAAAAAAAAAA', '01J9BBBBBBBBBBBBBBBBBBBBBB']);
    });

    test('a post kept out of the portfolio does not touch the photographer document', () async {
      final db = FakeFirebaseFirestore();
      await FirestorePostPublisher(db: db).publish(draft(portfolio: false));
      expect((await db.collection('photographers').doc('p1').get()).exists, isFalse);
    });

    test('the commit has a deadline so an offline phone does not wait forever', () {
      final src = File('lib/data/content/firestore_post_publisher.dart').readAsStringSync();
      expect(src, contains('.timeout('));
      expect(src, contains('Duration(seconds: 20)'));
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/content/post_publisher_test.dart`
Expected: FAIL (the publisher libraries do not exist).

- [ ] **Step 3: Implement**

```dart
// lib/data/content/post_publisher.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';

/// Everything needed to create a post. The photos are already uploaded; their
/// download URLs are in [images].
@immutable
class PostDraft {
  const PostDraft({
    required this.id,
    required this.photographerId,
    required this.serviceId,
    this.specialtyId,
    required this.images,
    this.caption = '',
    this.locationName,
    this.styleId,
    this.inPortfolio = true,
  });

  /// A ULID created on the device; publishing the same id again overwrites.
  final String id;
  final String photographerId;
  final String serviceId;

  /// Specialty of the package, stored on the post for the Home category chips.
  final String? specialtyId;
  final List<PostImage> images;
  final String caption;
  final String? locationName;
  final String? styleId;
  final bool inPortfolio;
}

abstract class PostPublisher {
  /// Creates the post (and its portfolio entry) and returns it.
  Future<PostSummary> publish(PostDraft draft);
}

class FakePostPublisher implements PostPublisher {
  FakePostPublisher({required this.posts, DateTime Function()? clock})
    : _now = clock ?? (() => DateTime.now().toUtc());

  /// The feed the new post is added to.
  final FakePostRepository posts;
  final DateTime Function() _now;
  final List<PostDraft> published = [];
  Object? failWith;

  @override
  Future<PostSummary> publish(PostDraft draft) async {
    if (failWith != null) {
      throw failWith!;
    }
    final post = PostSummary(
      id: draft.id,
      kind: PostKind.work,
      authorId: draft.photographerId,
      photographerId: draft.photographerId,
      serviceId: draft.serviceId,
      images: draft.images,
      caption: draft.caption,
      locationName: draft.locationName,
      styleId: draft.styleId,
      specialtyId: draft.specialtyId,
      hashtags: extractHashtags(draft.caption),
      inPortfolio: draft.inPortfolio,
      createdAt: _now(),
    );
    posts.removeById(draft.id);
    posts.add(post);
    published.add(draft);
    return post;
  }
}
```

Add `removeById` to `FakePostRepository` in `lib/data/content/fake_content_repositories.dart`:

```dart
  /// Removes a post if present; used when a draft id is published again.
  void removeById(String id) => _posts.removeWhere((p) => p.id == id);
```

```dart
// lib/data/content/firestore_post_publisher.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/post_summary.dart';

class FirestorePostPublisher implements PostPublisher {
  FirestorePostPublisher({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  @override
  Future<PostSummary> publish(PostDraft d) async {
    final hashtags = extractHashtags(d.caption);
    final batch = _db.batch();
    batch.set(_db.collection('posts').doc(d.id), {
      'kind': PostKind.work.code,
      'authorId': d.photographerId,
      'photographerId': d.photographerId,
      'serviceId': d.serviceId,
      if (d.specialtyId != null) 'specialty': d.specialtyId,
      'imageUrls': [for (final i in d.images) i.url],
      'imageMeta': [
        for (final i in d.images)
          {'blurHash': i.blurHash, 'w': i.width, 'h': i.height},
      ],
      'caption': d.caption,
      if (d.locationName != null) 'location': {'name': d.locationName},
      if (d.styleId != null) 'style': d.styleId,
      'hashtags': hashtags,
      'inPortfolio': d.inPortfolio,
      'likeCount': 0,
      'saveCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (d.inPortfolio) {
      batch.set(_db.collection('photographers').doc(d.photographerId), {
        'portfolio': FieldValue.arrayUnion([d.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    // Offline, a Firestore commit never completes until the server answers.
    // The deadline turns that into an error the user can retry; the retry
    // reuses the same post id, so the queued write is not duplicated.
    await batch.commit().timeout(const Duration(seconds: 20));
    return PostSummary(
      id: d.id,
      kind: PostKind.work,
      authorId: d.photographerId,
      photographerId: d.photographerId,
      serviceId: d.serviceId,
      images: d.images,
      caption: d.caption,
      locationName: d.locationName,
      styleId: d.styleId,
      specialtyId: d.specialtyId,
      hashtags: hashtags,
      inPortfolio: d.inPortfolio,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/content && flutter analyze`
Expected: PASS (contract 4 per implementation, plus 1 + 4); analyze clean. If the "same draft twice" Firestore case keeps the old caption, `batch.set` without merge must replace the whole document: it does; check the test is not reading a cached query.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/content test/data/content
git commit -m "feat(content): PostPublisher port, fake and Firestore write path

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Firestore rules for creating a post

**Files:**
- Modify: `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Produces: `posts/{postId}` can be created by a signed-in photographer for themself only, with the shape `FirestorePostPublisher` writes; update and delete stay denied; the existing read rule stays.
- The portfolio batch write (`photographers/{uid}.portfolio`, `updatedAt`) is already allowed by the existing `photographerClientFields()` rule.

- [ ] **Step 1: Write the failing tests** (append to `firebase/rules-test/rules.test.mjs`; the import line needs `arrayUnion` from `firebase/firestore`)

```js
// ---- creating posts ----
const validPost = (uid, extra = {}) => ({
  kind: 'work', authorId: uid, photographerId: uid, serviceId: 's1', specialty: 'portrait',
  imageUrls: ['https://x/1.jpg'], imageMeta: [{ blurHash: null, w: null, h: null }],
  caption: 'Chiều muộn #chandung', hashtags: ['chandung'], location: { name: 'Bến Bạch Đằng' },
  style: 'film', inPortfolio: true, likeCount: 0, saveCount: 0, createdAt: serverTimestamp(), ...extra,
});

async function seedShooter(uid, { role = 'photographer', service = true, active = true } = {}) {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, `users/${uid}`), { displayName: uid, role });
    if (service) {
      await setDoc(doc(db, `photographers/${uid}/services/s1`), { name: 'Gói', price: 1500000, active });
    }
  });
}

test('a photographer creates a post for themself with their own package', async () => {
  await seedShooter('c1');
  const db = env.authenticatedContext('c1').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/post-ok'), validPost('c1')));
});

test('the post and its portfolio entry can be written in one batch', async () => {
  await seedShooter('c2');
  const db = env.authenticatedContext('c2').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts/post-batch'), validPost('c2'));
  batch.set(doc(db, 'photographers/c2'), { portfolio: arrayUnion('post-batch'), updatedAt: serverTimestamp() }, { merge: true });
  await assertSucceeds(batch.commit());
});

test('optional fields may be left out', async () => {
  await seedShooter('c3');
  const db = env.authenticatedContext('c3').firestore();
  const bare = validPost('c3');
  for (const k of ['specialty', 'imageMeta', 'location', 'style', 'hashtags', 'inPortfolio']) delete bare[k];
  await assertSucceeds(setDoc(doc(db, 'posts/post-bare'), bare));
});

test('nobody posts as someone else, and customers cannot post', async () => {
  await seedShooter('c4');
  await seedShooter('cust', { role: 'customer' });
  const db = env.authenticatedContext('c4').firestore();
  await assertFails(setDoc(doc(db, 'posts/x1'), validPost('c5')));
  await assertFails(setDoc(doc(db, 'posts/x2'), validPost('c4', { authorId: 'c5' })));
  const customer = env.authenticatedContext('cust').firestore();
  await assertFails(setDoc(doc(customer, 'posts/x3'), validPost('cust')));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'posts/x4'), validPost('c4')));
});

test('the package must exist, be yours and be active', async () => {
  await seedShooter('c6', { service: false });
  await seedShooter('c7', { active: false });
  await seedShooter('c8');
  await assertFails(setDoc(doc(env.authenticatedContext('c6').firestore(), 'posts/y1'), validPost('c6')));
  await assertFails(setDoc(doc(env.authenticatedContext('c7').firestore(), 'posts/y2'), validPost('c7')));
  // A package id is looked up under the poster's own packages only.
  await assertFails(setDoc(doc(env.authenticatedContext('c8').firestore(), 'posts/y3'), validPost('c8', { serviceId: 'other' })));
});

test('one to ten photos', async () => {
  await seedShooter('c9');
  const db = env.authenticatedContext('c9').firestore();
  await assertFails(setDoc(doc(db, 'posts/z1'), validPost('c9', { imageUrls: [], imageMeta: [] })));
  const eleven = Array.from({ length: 11 }, (_, i) => `https://x/${i}.jpg`);
  const tooMany = validPost('c9', { imageUrls: eleven });
  delete tooMany.imageMeta;
  await assertFails(setDoc(doc(db, 'posts/z2'), tooMany));
  const ten = eleven.slice(0, 10);
  await assertSucceeds(setDoc(doc(db, 'posts/z3'), validPost('c9', { imageUrls: ten, imageMeta: ten.map(() => ({ blurHash: null, w: null, h: null })) })));
  await assertFails(setDoc(doc(db, 'posts/z4'), validPost('c9', { imageMeta: [] }))); // meta must match the photo count
});

test('counters, kind, time and extra fields cannot be forged', async () => {
  await seedShooter('d1');
  const db = env.authenticatedContext('d1').firestore();
  await assertFails(setDoc(doc(db, 'posts/f1'), validPost('d1', { likeCount: 500 })));
  await assertFails(setDoc(doc(db, 'posts/f2'), validPost('d1', { saveCount: 1 })));
  await assertFails(setDoc(doc(db, 'posts/f3'), validPost('d1', { kind: 'real_shoot' })));
  await assertFails(setDoc(doc(db, 'posts/f4'), validPost('d1', { createdAt: new Date('2020-01-01') })));
  await assertFails(setDoc(doc(db, 'posts/f5'), validPost('d1', { bookingId: 'b1' })));
  await assertFails(setDoc(doc(db, 'posts/f6'), validPost('d1', { caption: 'x'.repeat(2001) })));
  await assertFails(setDoc(doc(db, 'posts/f7'), validPost('d1', { hashtags: Array.from({ length: 31 }, (_, i) => `t${i}`) })));
  await assertSucceeds(setDoc(doc(db, 'posts/f8'), validPost('d1', { caption: 'x'.repeat(2000) })));
});

test('posts cannot be edited or deleted from the client yet', async () => {
  await seedShooter('d2');
  const db = env.authenticatedContext('d2').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/own'), validPost('d2')));
  await assertFails(updateDoc(doc(db, 'posts/own'), { caption: 'đổi' }));
  await assertFails(updateDoc(doc(db, 'posts/own'), { likeCount: 10 }));
  await assertFails(deleteDoc(doc(db, 'posts/own')));
});
```

The earlier 3b1 test "nobody writes them from the client yet" keeps passing: its forged post is by a plain viewer without the photographer role and without a service.

- [ ] **Step 2: Run and see it fail**

Run (from `firebase/rules-test`): `npm test`
Expected: the "creates a post" tests FAIL (the rule is still `allow write: if false`).

- [ ] **Step 3: Implement**

In `firebase/firestore.rules`, add this function next to the other helpers:

```
    // posts/{id}: a photographer creates a "work" post for themself, with 1 to
    // 10 photos and one of their own active packages. Counters start at zero
    // and the time is the server's. Posts are not edited from the client.
    function validPostCreate() {
      let d = request.resource.data;
      let uid = request.auth.uid;
      return d.keys().hasOnly(['kind', 'authorId', 'photographerId', 'serviceId', 'specialty',
                               'imageUrls', 'imageMeta', 'caption', 'location', 'style',
                               'hashtags', 'inPortfolio', 'likeCount', 'saveCount', 'createdAt'])
        && d.keys().hasAll(['kind', 'authorId', 'photographerId', 'serviceId', 'imageUrls',
                            'caption', 'likeCount', 'saveCount', 'createdAt'])
        && d.kind == 'work'
        && d.authorId == uid
        && d.photographerId == uid
        && hasPhotographerRole(uid)
        && d.serviceId is string
        && get(/databases/$(database)/documents/photographers/$(uid)/services/$(d.serviceId))
             .data.get('active', true) == true
        && d.imageUrls is list && d.imageUrls.size() >= 1 && d.imageUrls.size() <= 10
        && (!('imageMeta' in d) || (d.imageMeta is list && d.imageMeta.size() == d.imageUrls.size()))
        && d.caption is string && d.caption.size() <= 2000
        && (!('hashtags' in d) || (d.hashtags is list && d.hashtags.size() <= 30))
        && (!('inPortfolio' in d) || d.inPortfolio is bool)
        && d.likeCount == 0 && d.saveCount == 0
        && d.createdAt == request.time;
    }
```

and change the `posts` block from plan 3b1 to:

```
    match /posts/{postId} {
      allow read: if signedIn();
      allow create: if signedIn() && validPostCreate();
      allow update, delete: if false;
    }
```

- [ ] **Step 4: Run and see it pass**

Run (from `firebase/rules-test`): `npm test`
Expected: all rules tests pass, old and new (7 new). A `get() on a missing package document makes the rule error, which denies; that is the intended result for the "package must exist" cases.

- [ ] **Step 5: Commit**

```bash
git add firebase
git commit -m "feat(rules): photographers create their own work posts, nothing else writes posts

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `PostComposerController`

**Files:**
- Create: `lib/features/create_post/create_post_providers.dart`, `lib/features/create_post/post_composer.dart`, `test/features/create_post/post_composer_test.dart`

**Interfaces:**
- Consumes: `ImagePickerPort`, `MediaUploader`, `PostPublisher`, `ServiceRepository`, `newUlid`, `sharedPreferencesProvider`, `authRepositoryProvider`, fakes `FakeImagePicker`, `FakeMediaUploader`, `FakePostPublisher`.
- Produces (`create_post_providers.dart`): `imagePickerProvider` (`PluginImagePicker`), `mediaUploaderProvider` (`FirebaseMediaUploader`), `postPublisherProvider` (`FirestorePostPublisher`), `myServicesProvider` (`FutureProvider.autoDispose<List<ServiceSummary>>`, the signed-in photographer's active packages).
- Produces (`post_composer.dart`):
  - `enum ComposerImageStatus { local, uploading, uploaded, failed }`; `class ComposerImage { key, picked, status, progress, media }`.
  - `class ComposerState { draftId, images, caption, serviceId, specialtyId, locationName, styleId, inPortfolio, publishing; bool get canPublish }` — `canPublish` needs at least one photo, a package, a caption of at most 2000 characters, and no publish in progress.
  - `enum PublishOutcome { published, imageFailed, publishFailed, notReady }`, `class PostPublishResult { PublishOutcome outcome; String? postId }`.
  - `class PostComposerController extends Notifier<ComposerState>` with `static const maxImages = 10`, `maxCaption = 2000`; `Future<void> pickImages()`, `void removeImage(String key)`, `void moveImage(String key, int delta)`, `void setCaption(String)`, `void setService(ServiceSummary?)`, `void setLocation(String?)`, `void setStyle(String?)`, `void setInPortfolio(bool)`, `Future<void> retryImage(String key)`, `Future<PostPublishResult> publish()`; `postComposerProvider` (kept while the app runs, so the form survives switching tabs).

Behaviour:

- Photos are uploaded only when "Đăng" is pressed, one at a time, to `posts/{uid}/{draftId}/{key}.jpg`. A photo that fails stays marked as failed; the photos before it stay uploaded and are not uploaded again on the next try.
- If creating the post fails after the uploads, the uploaded photos are kept for the next try; the post id (`draftId`) is the same, so a retry never duplicates.
- Removing a photo that is already uploaded deletes it from Storage, so a discarded photo is not left behind.
- The text of the form (caption, package, place, style, portfolio switch) is saved on the device per user after every change and restored the next time; photos are not (the picker's temporary files may be gone).
- After a successful publish the form is empty again with a new `draftId`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/create_post/post_composer_test.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/create_post/post_composer.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_fixtures.dart';

PickedImage img(int i) => PickedImage(path: '/tmp/$i.jpg', name: '$i.jpg', sizeBytes: 1000);

class _Env {
  _Env(this.c, this.picker, this.uploader, this.publisher, this.posts, this.prefs, this.uid);
  final ProviderContainer c;
  final FakeImagePicker picker;
  final FakeMediaUploader uploader;
  final FakePostPublisher publisher;
  final FakePostRepository posts;
  final SharedPreferences prefs;
  final String? uid;
  PostComposerController get ctl => c.read(postComposerProvider.notifier);
  ComposerState get state => c.read(postComposerProvider);
}

Future<_Env> _env({
  List<List<PickedImage>> picks = const [],
  bool signedIn = true,
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  String? uid;
  if (signedIn) {
    uid = (await auth.registerWithEmail('a@b.vn', 'password1', 'Minh')).uid;
  }
  final picker = FakeImagePicker(picks);
  final uploader = FakeMediaUploader();
  final posts = FakePostRepository();
  final publisher = FakePostPublisher(posts: posts, clock: () => fixtureNow);
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      imagePickerProvider.overrideWithValue(picker),
      mediaUploaderProvider.overrideWithValue(uploader),
      postPublisherProvider.overrideWithValue(publisher),
    ],
  );
  addTearDown(c.dispose);
  return _Env(c, picker, uploader, publisher, posts, prefs, uid);
}

Future<_Env> _ready({int photos = 2}) async {
  final e = await _env(picks: [[for (var i = 0; i < photos; i++) img(i)]]);
  await e.ctl.pickImages();
  e.ctl.setService(fixtureService('s1'));
  return e;
}

void main() {
  group('the form', () {
    test('starts empty and cannot be published', () async {
      final e = await _env();
      expect(e.state.images, isEmpty);
      expect(e.state.inPortfolio, isTrue);
      expect(e.state.canPublish, isFalse);
      expect(e.state.draftId, hasLength(26));
    });

    test('a photo and a package are enough', () async {
      final e = await _env(picks: [[img(1)]]);
      await e.ctl.pickImages();
      expect(e.state.canPublish, isFalse, reason: 'no package yet');
      e.ctl.setService(fixtureService('s1'));
      expect(e.state.canPublish, isTrue);
      e.ctl.setService(null);
      expect(e.state.canPublish, isFalse);
    });

    test('a caption over 2000 characters blocks publishing', () async {
      final e = await _ready(photos: 1);
      e.ctl.setCaption('x' * 2000);
      expect(e.state.canPublish, isTrue);
      e.ctl.setCaption('x' * 2001);
      expect(e.state.canPublish, isFalse);
    });

    test('picking asks for exactly the room that is left and never exceeds ten', () async {
      final e = await _env(picks: [
        [for (var i = 0; i < 6; i++) img(i)],
        [for (var i = 10; i < 20; i++) img(i)],
      ]);
      await e.ctl.pickImages();
      await e.ctl.pickImages();
      expect(e.picker.requestedMax, [10, 4]);
      expect(e.state.images, hasLength(10));
      await e.ctl.pickImages();
      expect(e.picker.calls, 2, reason: 'no room: the picker is not even opened');
    });

    test('a cancelled picker adds nothing', () async {
      final e = await _env(picks: [[]]);
      await e.ctl.pickImages();
      expect(e.state.images, isEmpty);
    });

    test('photos can be moved and removed', () async {
      final e = await _env(picks: [[img(0), img(1), img(2)]]);
      await e.ctl.pickImages();
      List<String> names() => e.state.images.map((i) => i.picked.name).toList();
      final k = e.state.images.map((i) => i.key).toList();
      e.ctl.moveImage(k[2], -1);
      expect(names(), ['0.jpg', '2.jpg', '1.jpg']);
      e.ctl.moveImage(k[0], -1);
      expect(names(), ['0.jpg', '2.jpg', '1.jpg'], reason: 'the first cannot go up');
      e.ctl.moveImage(k[1], 1);
      expect(names(), ['0.jpg', '2.jpg', '1.jpg'], reason: 'the last cannot go down');
      e.ctl.removeImage(k[2]);
      expect(names(), ['0.jpg', '1.jpg']);
    });

    test('place and style are trimmed and cleared when empty', () async {
      final e = await _env();
      e.ctl.setLocation('  Bến Bạch Đằng ');
      expect(e.state.locationName, 'Bến Bạch Đằng');
      e.ctl.setLocation('   ');
      expect(e.state.locationName, isNull);
      e.ctl.setStyle('film');
      e.ctl.setStyle(null);
      expect(e.state.styleId, isNull);
    });
  });

  group('publishing', () {
    test('uploads one by one to the post folder, then creates the post', () async {
      final e = await _ready();
      e.ctl.setCaption('  Chiều muộn #chandung  ');
      e.ctl.setLocation('Bến Bạch Đằng');
      e.ctl.setStyle('natural_light');
      final draftId = e.state.draftId;
      final result = await e.ctl.publish();

      expect(result.outcome, PublishOutcome.published);
      expect(result.postId, draftId);
      expect(e.uploader.maxConcurrent, 1);
      expect(e.uploader.uploaded, hasLength(2));
      for (final p in e.uploader.uploaded) {
        expect(p, startsWith('posts/${e.uid}/$draftId/'));
        expect(p, endsWith('.jpg'));
      }
      final d = e.publisher.published.single;
      expect(d.id, draftId);
      expect(d.photographerId, e.uid);
      expect(d.serviceId, 's1');
      expect(d.specialtyId, 'portrait');
      expect(d.caption, 'Chiều muộn #chandung');
      expect(d.locationName, 'Bến Bạch Đằng');
      expect(d.styleId, 'natural_light');
      expect(d.inPortfolio, isTrue);
      expect(d.images.map((i) => i.url), [for (final p in e.uploader.uploaded) 'https://storage.test/$p']);
      expect((await e.posts.byId(draftId))!.hashtags, ['chandung']);
    });

    test('afterwards the form is empty with a new post id, and the draft is gone', () async {
      final e = await _ready();
      e.ctl.setCaption('Xong');
      final before = e.state.draftId;
      await e.ctl.publish();
      expect(e.state.images, isEmpty);
      expect(e.state.caption, isEmpty);
      expect(e.state.serviceId, isNull);
      expect(e.state.draftId, isNot(before));
      expect(e.state.publishing, isFalse);
      expect(e.prefs.getKeys().where((k) => k.startsWith('postDraft')), isEmpty);
    });

    test('statuses go local, uploading, uploaded while it runs', () async {
      final e = await _ready(photos: 1);
      final seen = <ComposerImageStatus>[];
      e.c.listen(postComposerProvider, (_, s) {
        if (s.images.isNotEmpty) {
          seen.add(s.images.single.status);
        }
      });
      await e.ctl.publish();
      expect(
        seen,
        containsAllInOrder([
          ComposerImageStatus.local,
          ComposerImageStatus.uploading,
          ComposerImageStatus.uploaded,
        ]),
      );
    });

    test('a second press while publishing is ignored', () async {
      final e = await _ready();
      final first = e.ctl.publish();
      final second = await e.ctl.publish();
      expect(second.outcome, PublishOutcome.notReady);
      expect((await first).outcome, PublishOutcome.published);
      expect(e.publisher.published, hasLength(1));
    });

    test('not ready, or signed out, publishes nothing', () async {
      final e = await _env();
      expect((await e.ctl.publish()).outcome, PublishOutcome.notReady);
      final out = await _env(signedIn: false, picks: [[img(1)]]);
      await out.ctl.pickImages();
      out.ctl.setService(fixtureService('s1'));
      expect((await out.ctl.publish()).outcome, PublishOutcome.notReady);
      expect(out.uploader.uploadCalls, 0);
    });
  });

  group('failures', () {
    test('a failing photo stops the run, keeps the earlier ones, and can be retried alone', () async {
      final e = await _ready(photos: 3);
      e.uploader.failNames.add('1.jpg');
      final result = await e.ctl.publish();
      expect(result.outcome, PublishOutcome.imageFailed);
      expect(e.state.publishing, isFalse);
      expect(e.state.images.map((i) => i.status), [
        ComposerImageStatus.uploaded,
        ComposerImageStatus.failed,
        ComposerImageStatus.local,
      ]);
      expect(e.publisher.published, isEmpty);

      e.uploader.failNames.clear();
      final calls = e.uploader.uploadCalls;
      await e.ctl.retryImage(e.state.images[1].key);
      expect(e.state.images[1].status, ComposerImageStatus.uploaded);
      expect(e.uploader.uploadCalls, calls + 1, reason: 'only that photo');

      final done = await e.ctl.publish();
      expect(done.outcome, PublishOutcome.published);
      expect(e.uploader.uploadCalls, calls + 2, reason: 'only the third photo was left');
      expect(e.publisher.published.single.images, hasLength(3));
    });

    test('a failed retry leaves the photo failed', () async {
      final e = await _ready(photos: 1);
      e.uploader.failNames.add('0.jpg');
      await e.ctl.publish();
      await e.ctl.retryImage(e.state.images.single.key);
      expect(e.state.images.single.status, ComposerImageStatus.failed);
    });

    test('a failing create keeps the uploaded photos and the same id for the next try', () async {
      final e = await _ready();
      final id = e.state.draftId;
      e.publisher.failWith = StateError('offline');
      expect((await e.ctl.publish()).outcome, PublishOutcome.publishFailed);
      expect(e.state.publishing, isFalse);
      expect(e.state.images.every((i) => i.status == ComposerImageStatus.uploaded), isTrue);
      expect(e.state.draftId, id);
      final uploads = e.uploader.uploadCalls;

      e.publisher.failWith = null;
      final again = await e.ctl.publish();
      expect(again.outcome, PublishOutcome.published);
      expect(again.postId, id);
      expect(e.uploader.uploadCalls, uploads, reason: 'nothing is uploaded twice');
    });

    test('removing an uploaded photo deletes it from Storage', () async {
      final e = await _ready();
      e.publisher.failWith = StateError('offline');
      await e.ctl.publish();
      final victim = e.state.images.first;
      final path = victim.media!.storagePath;
      e.ctl.removeImage(victim.key);
      await Future<void>.delayed(Duration.zero);
      expect(e.uploader.deleted, [path]);
      expect(e.uploader.uploaded, hasLength(1));
    });

    test('a photo that was never uploaded is simply dropped', () async {
      final e = await _ready(photos: 1);
      e.ctl.removeImage(e.state.images.single.key);
      expect(e.uploader.deleted, isEmpty);
    });

    test('a failing delete does not break the form', () async {
      final e = await _ready();
      e.publisher.failWith = StateError('offline');
      await e.ctl.publish();
      e.uploader.deleteFailure = StateError('offline');
      e.ctl.removeImage(e.state.images.first.key);
      await Future<void>.delayed(Duration.zero);
      expect(e.state.images, hasLength(1));
    });
  });

  group('the draft on the device', () {
    test('text fields are saved under the user\'s key, photos are not', () async {
      final e = await _env();
      e.ctl.setCaption('Chiều muộn');
      e.ctl.setService(fixtureService('s1'));
      e.ctl.setLocation('Bến Bạch Đằng');
      e.ctl.setStyle('film');
      e.ctl.setInPortfolio(false);
      final stored = jsonDecode(e.prefs.getString('postDraft:${e.uid}')!) as Map<String, dynamic>;
      expect(stored['caption'], 'Chiều muộn');
      expect(stored['serviceId'], 's1');
      expect(stored['specialtyId'], 'portrait');
      expect(stored['inPortfolio'], false);
      expect(stored.containsKey('images'), isFalse);
      expect(e.prefs.getKeys().where((k) => k.startsWith('postDraft')), ['postDraft:${e.uid}']);
    });

    test('the same user gets the draft back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthRepository();
      final uid = (await auth.registerWithEmail('a@b.vn', 'password1', 'Minh')).uid;
      ProviderContainer make() => ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          imagePickerProvider.overrideWithValue(FakeImagePicker()),
          mediaUploaderProvider.overrideWithValue(FakeMediaUploader()),
          postPublisherProvider.overrideWithValue(FakePostPublisher(posts: FakePostRepository())),
        ],
      );
      final first = make();
      first.read(postComposerProvider.notifier)
        ..setCaption('Nháp của tôi')
        ..setService(fixtureService('s1'))
        ..setLocation('Hồ Gươm')
        ..setStyle('film')
        ..setInPortfolio(false);
      first.dispose();

      final second = make();
      addTearDown(second.dispose);
      final s = second.read(postComposerProvider);
      expect((s.caption, s.serviceId, s.specialtyId, s.locationName, s.styleId, s.inPortfolio),
          ('Nháp của tôi', 's1', 'portrait', 'Hồ Gươm', 'film', false));
      expect(s.images, isEmpty);
      expect(prefs.containsKey('postDraft:$uid'), isTrue);
    });

    test('emptying every field removes the stored draft', () async {
      final e = await _env();
      e.ctl.setCaption('x');
      expect(e.prefs.containsKey('postDraft:${e.uid}'), isTrue);
      e.ctl.setCaption('');
      expect(e.prefs.containsKey('postDraft:${e.uid}'), isFalse);
    });

    test('a corrupt stored draft is ignored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthRepository();
      final uid = (await auth.registerWithEmail('a@b.vn', 'password1', 'Minh')).uid;
      await prefs.setString('postDraft:$uid', '{oops');
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(postComposerProvider).caption, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/create_post/post_composer_test.dart`
Expected: FAIL (providers and controller do not exist).

- [ ] **Step 3: Implement**

```dart
// lib/features/create_post/create_post_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/firestore_post_publisher.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/media/firebase_media_uploader.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/media/plugin_image_picker.dart';

final imagePickerProvider = Provider<ImagePickerPort>((ref) => PluginImagePicker());

final mediaUploaderProvider = Provider<MediaUploader>(
  (ref) => FirebaseMediaUploader(),
);

final postPublisherProvider = Provider<PostPublisher>(
  (ref) => FirestorePostPublisher(),
);

/// The signed-in photographer's active packages, for the package field.
final myServicesProvider = FutureProvider.autoDispose<List<ServiceSummary>>((
  ref,
) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return const [];
  }
  return ref.watch(serviceRepositoryProvider).activeFor(uid);
});
```

```dart
// lib/features/create_post/post_composer.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

enum ComposerImageStatus { local, uploading, uploaded, failed }

@immutable
class ComposerImage {
  const ComposerImage({
    required this.key,
    required this.picked,
    this.status = ComposerImageStatus.local,
    this.progress = 0,
    this.media,
  });

  /// Stable id inside the form; also the file name in Storage.
  final String key;
  final PickedImage picked;
  final ComposerImageStatus status;
  final double progress;
  final UploadedMedia? media;

  ComposerImage copyWith({
    ComposerImageStatus? status,
    double? progress,
    UploadedMedia? media,
  }) => ComposerImage(
    key: key,
    picked: picked,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    media: media ?? this.media,
  );
}

@immutable
class ComposerState {
  const ComposerState({
    required this.draftId,
    this.images = const [],
    this.caption = '',
    this.serviceId,
    this.specialtyId,
    this.locationName,
    this.styleId,
    this.inPortfolio = true,
    this.publishing = false,
  });

  /// The id the post will have (a ULID), fixed for the life of the form so a
  /// retried publish overwrites instead of duplicating.
  final String draftId;
  final List<ComposerImage> images;
  final String caption;
  final String? serviceId;
  final String? specialtyId;
  final String? locationName;
  final String? styleId;
  final bool inPortfolio;
  final bool publishing;

  bool get canPublish =>
      images.isNotEmpty &&
      serviceId != null &&
      !publishing &&
      caption.length <= PostComposerController.maxCaption;

  ComposerState copyWith({
    List<ComposerImage>? images,
    String? caption,
    bool? inPortfolio,
    bool? publishing,
  }) => ComposerState(
    draftId: draftId,
    images: images ?? this.images,
    caption: caption ?? this.caption,
    serviceId: serviceId,
    specialtyId: specialtyId,
    locationName: locationName,
    styleId: styleId,
    inPortfolio: inPortfolio ?? this.inPortfolio,
    publishing: publishing ?? this.publishing,
  );

  ComposerState withService(String? id, String? specialty) => ComposerState(
    draftId: draftId,
    images: images,
    caption: caption,
    serviceId: id,
    specialtyId: specialty,
    locationName: locationName,
    styleId: styleId,
    inPortfolio: inPortfolio,
    publishing: publishing,
  );

  ComposerState withLocation(String? v) => ComposerState(
    draftId: draftId,
    images: images,
    caption: caption,
    serviceId: serviceId,
    specialtyId: specialtyId,
    locationName: v,
    styleId: styleId,
    inPortfolio: inPortfolio,
    publishing: publishing,
  );

  ComposerState withStyle(String? v) => ComposerState(
    draftId: draftId,
    images: images,
    caption: caption,
    serviceId: serviceId,
    specialtyId: specialtyId,
    locationName: locationName,
    styleId: v,
    inPortfolio: inPortfolio,
    publishing: publishing,
  );
}

enum PublishOutcome { published, imageFailed, publishFailed, notReady }

@immutable
class PostPublishResult {
  const PostPublishResult(this.outcome, [this.postId]);
  final PublishOutcome outcome;
  final String? postId;
}

class PostComposerController extends Notifier<ComposerState> {
  static const maxImages = 10;
  static const maxCaption = 2000;

  final _busy = <String>{};

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  String _draftKey(String uid) => 'postDraft:$uid';

  @override
  ComposerState build() {
    final uid = _uid;
    return (uid == null ? null : _restore(uid)) ??
        ComposerState(draftId: newUlid());
  }

  ComposerState? _restore(String uid) {
    final raw = _prefs.getString(_draftKey(uid));
    if (raw == null) {
      return null;
    }
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return ComposerState(
        draftId: newUlid(),
        caption: (m['caption'] as String?) ?? '',
        serviceId: m['serviceId'] as String?,
        specialtyId: m['specialtyId'] as String?,
        locationName: m['locationName'] as String?,
        styleId: m['styleId'] as String?,
        inPortfolio: m['inPortfolio'] as bool? ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Text fields only: the picker's temporary photo files may be gone by the
  /// next session, so photos are not part of the draft.
  void _persist() {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    final s = state;
    final empty = s.caption.isEmpty &&
        s.serviceId == null &&
        s.locationName == null &&
        s.styleId == null;
    if (empty) {
      unawaited(_prefs.remove(_draftKey(uid)));
      return;
    }
    unawaited(
      _prefs.setString(
        _draftKey(uid),
        jsonEncode({
          'caption': s.caption,
          'serviceId': s.serviceId,
          'specialtyId': s.specialtyId,
          'locationName': s.locationName,
          'styleId': s.styleId,
          'inPortfolio': s.inPortfolio,
        }),
      ),
    );
  }

  Future<void> pickImages() async {
    final room = maxImages - state.images.length;
    if (room <= 0 || state.publishing) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: room);
    if (!ref.mounted || picked.isEmpty) {
      return;
    }
    state = state.copyWith(
      images: [
        ...state.images,
        for (final p in picked.take(room)) ComposerImage(key: newUlid(), picked: p),
      ],
    );
  }

  void removeImage(String key) {
    if (state.publishing) {
      return;
    }
    final i = state.images.indexWhere((e) => e.key == key);
    if (i < 0) {
      return;
    }
    final media = state.images[i].media;
    state = state.copyWith(images: [...state.images]..removeAt(i));
    if (media != null) {
      unawaited(_deleteQuietly(media.storagePath));
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await ref.read(mediaUploaderProvider).delete(path);
    } catch (_) {
      // An object we could not delete stays behind; nothing else depends on it.
    }
  }

  void moveImage(String key, int delta) {
    if (state.publishing) {
      return;
    }
    final list = [...state.images];
    final from = list.indexWhere((e) => e.key == key);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) {
      return;
    }
    list.insert(to, list.removeAt(from));
    state = state.copyWith(images: list);
  }

  void setCaption(String v) {
    state = state.copyWith(caption: v);
    _persist();
  }

  void setService(ServiceSummary? s) {
    state = state.withService(s?.id, s?.specialtyId);
    _persist();
  }

  void setLocation(String? v) {
    final t = v?.trim();
    state = state.withLocation(t == null || t.isEmpty ? null : t);
    _persist();
  }

  void setStyle(String? id) {
    state = state.withStyle(id);
    _persist();
  }

  void setInPortfolio(bool v) {
    state = state.copyWith(inPortfolio: v);
    _persist();
  }

  ComposerImage? _image(String key) {
    for (final i in state.images) {
      if (i.key == key) {
        return i;
      }
    }
    return null;
  }

  void _update(String key, ComposerImage Function(ComposerImage) f) {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      images: [for (final i in state.images) i.key == key ? f(i) : i],
    );
  }

  Future<bool> _upload(String key, String uid) async {
    final img = _image(key);
    if (img == null) {
      return false;
    }
    _update(key, (i) => i.copyWith(status: ComposerImageStatus.uploading, progress: 0));
    final path = 'posts/$uid/${state.draftId}/$key.jpg';
    try {
      await for (final e in ref.read(mediaUploaderProvider).upload(img.picked, storagePath: path)) {
        final media = e.media;
        if (media != null) {
          _update(
            key,
            (i) => i.copyWith(status: ComposerImageStatus.uploaded, progress: 1, media: media),
          );
        } else {
          _update(key, (i) => i.copyWith(progress: e.fraction));
        }
      }
      return _image(key)?.status == ComposerImageStatus.uploaded;
    } catch (_) {
      _update(key, (i) => i.copyWith(status: ComposerImageStatus.failed));
      return false;
    }
  }

  /// Uploads one photo again (the "thử lại" on a failed tile).
  Future<void> retryImage(String key) async {
    final uid = _uid;
    final img = _image(key);
    if (uid == null || img == null || state.publishing || !_busy.add(key)) {
      return;
    }
    try {
      await _upload(key, uid);
    } finally {
      _busy.remove(key);
    }
  }

  Future<PostPublishResult> publish() async {
    final uid = _uid;
    if (uid == null || !state.canPublish) {
      return const PostPublishResult(PublishOutcome.notReady);
    }
    state = state.copyWith(publishing: true);
    for (final key in [for (final i in state.images) i.key]) {
      final img = _image(key);
      if (img == null || img.status == ComposerImageStatus.uploaded) {
        continue;
      }
      if (!await _upload(key, uid)) {
        if (ref.mounted) {
          state = state.copyWith(publishing: false);
        }
        return const PostPublishResult(PublishOutcome.imageFailed);
      }
    }
    if (!ref.mounted) {
      return const PostPublishResult(PublishOutcome.notReady);
    }
    final s = state;
    try {
      final post = await ref.read(postPublisherProvider).publish(
        PostDraft(
          id: s.draftId,
          photographerId: uid,
          serviceId: s.serviceId!,
          specialtyId: s.specialtyId,
          images: [for (final i in s.images) PostImage(url: i.media!.url)],
          caption: s.caption.trim(),
          locationName: s.locationName,
          styleId: s.styleId,
          inPortfolio: s.inPortfolio,
        ),
      );
      await _prefs.remove(_draftKey(uid));
      if (ref.mounted) {
        state = ComposerState(draftId: newUlid(), inPortfolio: s.inPortfolio);
      }
      return PostPublishResult(PublishOutcome.published, post.id);
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(publishing: false);
      }
      return const PostPublishResult(PublishOutcome.publishFailed);
    }
  }
}

/// Kept while the app runs, so the form survives switching tabs.
final postComposerProvider =
    NotifierProvider<PostComposerController, ComposerState>(
      PostComposerController.new,
    );
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/create_post/post_composer_test.dart && flutter analyze`
Expected: PASS (24 tests); analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/create_post test/features/create_post
git commit -m "feat(create-post): composer controller with sequential uploads, retry and local draft

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: S21 Create post screen

**Files:**
- Create: `lib/features/create_post/create_post_screen.dart`, `test/features/create_post/create_post_screen_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `postComposerProvider`, `myServicesProvider`, `showAppSheet`, `OptionRow`, `AppButton`, `EmptyState`/`ErrorState`, `AppSkeleton`, `kStyles`, `styleLabel`, `formatMoney`.
- Produces:
  - `CreatePostScreen({super.key, required VoidCallback onAddService, required ValueChanged<String> onPublished})` wrapped in `ScreenCode(ScreenCodes.createPost)`. `onPublished` receives the id of the new post; `onAddService` is called by "Thêm gói" when the photographer has no package yet.
  - Keys: `create-add` (the "+" tile), `create-tile-<i>`, `create-remove-<i>`, `create-up-<i>`, `create-down-<i>`, `create-retry-<i>`, `create-caption`, `create-service`, `create-add-service`, `create-location`, `create-style`, `create-portfolio`, `create-publish`.
  - l10n: `createAddPhotos`, `createPhotosCount(n, max)`, `createCaptionLabel`, `createCaptionHint`, `createServiceLabel`, `createServicePick`, `createServiceTitle`, `createServiceRequired`, `createPhotosRequired`, `createNoServices`, `createAddService`, `createLocationLabel`, `createStyleLabel`, `createStyleNone`, `createStyleTitle`, `createPortfolio`, `createPublish`, `createRemove`, `createMoveUp`, `createMoveDown`, `createRetryPhoto`, `createUploading(percent)`, `createUploadFailed`, `createPublishFailed`, `createPublished`.

Layout: AppBar "Đăng bài"; a two-column photo grid (a "+" tile after the photos while there are fewer than 10; each tile has remove, move up and move down buttons, a progress bar while uploading, a retry button when it failed, a tick once uploaded); caption; the package field with an accent border and the required marker, replaced by "Bạn chưa có gói dịch vụ nào" and "Thêm gói" when there are none; place; style; the portfolio switch; a bottom "Đăng" button, disabled until there is at least one photo and a package, with a spinner while it runs. Missing photos or package show a short error under their field once the photographer has started the form. Dragging photos to reorder is replaced by the up and down buttons (spec allows them as the alternative). The "Bài đăng / Sự kiện" tabs of the mock arrive with the events plan.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/create_post/create_post_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/create_post/post_composer.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

PickedImage img(int i) => PickedImage(path: '/tmp/none-$i.jpg', name: '$i.jpg');

/// A photographer with one package, ready to post.
class _Create {
  _Create({List<List<PickedImage>>? picks, bool withService = true, MediaUploader? uploader})
    : world = DiscoveryWorld(role: UserRole.photographer),
      picker = FakeImagePicker(picks ?? [[img(0), img(1), img(2)]]),
      uploader = uploader ?? FakeMediaUploader(),
      withService = withService;

  final DiscoveryWorld world;
  final FakeImagePicker picker;
  final MediaUploader uploader;
  final bool withService;
  late final FakePostPublisher publisher;
  late List<Override> overrides;
  final published = <String>[];
  var addServiceTaps = 0;

  Future<void> init() async {
    await world.init();
    if (withService) {
      world.services.add(fixtureService('s1', photographerId: world.uid));
    }
    publisher = FakePostPublisher(posts: world.posts, clock: () => fixtureNow);
    overrides = [
      ...world.overrides,
      imagePickerProvider.overrideWithValue(picker),
      mediaUploaderProvider.overrideWithValue(uploader),
      postPublisherProvider.overrideWithValue(publisher),
    ];
  }

  Widget screen() => CreatePostScreen(
    onAddService: () => addServiceTaps++,
    onPublished: published.add,
  );
}

Future<_Create> _open(WidgetTester tester, {_Create? create, double textScale = 1, Brightness brightness = Brightness.dark}) async {
  final c = create ?? _Create();
  await c.init();
  await tester.pumpWidget(
    screenApp(home: c.screen(), overrides: c.overrides, textScale: textScale, brightness: brightness),
  );
  await tester.pumpAndSettle();
  return c;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CreatePostScreen)));

ComposerState _state(WidgetTester tester) => _container(tester).read(postComposerProvider);

bool _enabled(WidgetTester tester, String key) => tester
        .widget<FilledButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)))
        .onPressed !=
    null;

Future<void> _addPhotos(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-add')));
  await tester.pumpAndSettle();
}

Future<void> _pickService(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-service')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Chân dung 2 giờ'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty form: the plus tile, the fields, the portfolio switch on, "Đăng" disabled', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Đăng bài'), findsOneWidget);
    expect(find.byKey(const Key('create-add')), findsOneWidget);
    expect(find.byKey(const Key('create-caption')), findsOneWidget);
    expect(find.text('Gói dịch vụ · bắt buộc'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('create-portfolio'))).value, isTrue);
    expect(_enabled(tester, 'create-publish'), isFalse);
    expect(find.text('Thêm ít nhất một ảnh'), findsNothing, reason: 'no errors before the form is started');
    expect(find.text('Chọn gói dịch vụ cho bài đăng'), findsNothing);
  });

  testWidgets('adding photos fills the grid and shows the count', (tester) async {
    await _open(tester);
    await _addPhotos(tester);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('create-tile-$i')), findsOneWidget);
    }
    expect(find.byKey(const Key('create-tile-3')), findsNothing);
    expect(find.text('3 / 10 ảnh'), findsOneWidget);
    expect(find.byKey(const Key('create-add')), findsOneWidget);
  });

  testWidgets('ten photos hide the plus tile', (tester) async {
    await _open(tester, create: _Create(picks: [[for (var i = 0; i < 10; i++) img(i)]]));
    await _addPhotos(tester);
    expect(find.byKey(const Key('create-add')), findsNothing);
  });

  testWidgets('once started, the missing photo or package is named under its field', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('create-caption')), 'Chiều muộn');
    await tester.pump();
    expect(find.text('Thêm ít nhất một ảnh'), findsOneWidget);
    expect(find.text('Chọn gói dịch vụ cho bài đăng'), findsOneWidget);
    await _addPhotos(tester);
    expect(find.text('Thêm ít nhất một ảnh'), findsNothing);
    await _pickService(tester);
    expect(find.text('Chọn gói dịch vụ cho bài đăng'), findsNothing);
    expect(_enabled(tester, 'create-publish'), isTrue);
  });

  testWidgets('the package sheet lists the packages with prices and the field shows the choice', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('create-service')));
    await tester.pumpAndSettle();
    expect(find.text('Chân dung 2 giờ · 1.500.000₫'), findsOneWidget);
    await tester.tap(find.text('Chân dung 2 giờ · 1.500.000₫'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('create-service')), matching: find.textContaining('Chân dung 2 giờ')), findsOneWidget);
    expect(_state(tester).serviceId, 's1');
  });

  testWidgets('without packages the field gives way to "Thêm gói", and posting stays off', (
    tester,
  ) async {
    final c = await _open(tester, create: _Create(withService: false));
    expect(find.byKey(const Key('create-service')), findsNothing);
    expect(find.text('Bạn chưa có gói dịch vụ nào. Thêm gói để đăng bài.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-add-service')));
    expect(c.addServiceTaps, 1);
    await _addPhotos(tester);
    expect(_enabled(tester, 'create-publish'), isFalse);
  });

  testWidgets('move up, move down and remove change the order', (tester) async {
    await _open(tester);
    await _addPhotos(tester);
    List<String> order() => _state(tester).images.map((i) => i.picked.name).toList();
    await tester.tap(find.byKey(const Key('create-up-1')));
    await tester.pump();
    expect(order(), ['1.jpg', '0.jpg', '2.jpg']);
    await tester.tap(find.byKey(const Key('create-down-1')));
    await tester.pump();
    expect(order(), ['1.jpg', '2.jpg', '0.jpg']);
    await tester.tap(find.byKey(const Key('create-remove-0')));
    await tester.pump();
    expect(order(), ['2.jpg', '0.jpg']);
    expect(find.byKey(const Key('create-up-0')), findsNothing, reason: 'the first cannot go up');
  });

  testWidgets('publishing uploads, creates the post and hands its id to the caller', (
    tester,
  ) async {
    final c = await _open(tester);
    await tester.enterText(find.byKey(const Key('create-caption')), 'Chiều muộn #chandung');
    await _addPhotos(tester);
    await _pickService(tester);
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(c.published, [c.publisher.published.single.id]);
    expect((c.uploader as FakeMediaUploader).uploaded, hasLength(3));
    expect(_state(tester).images, isEmpty, reason: 'the form is empty again');
    expect(tester.widget<TextField>(find.byKey(const Key('create-caption'))).controller!.text, isEmpty);
  });

  testWidgets('a photo that fails shows a retry; retrying and publishing completes', (
    tester,
  ) async {
    final c = await _open(tester);
    (c.uploader as FakeMediaUploader).failNames.add('1.jpg');
    await _addPhotos(tester);
    await _pickService(tester);
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được ảnh. Thử lại nhé.'), findsWidgets);
    expect(find.byKey(const Key('create-retry-1')), findsOneWidget);
    expect(c.published, isEmpty);

    (c.uploader as FakeMediaUploader).failNames.clear();
    await tester.tap(find.byKey(const Key('create-retry-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-retry-1')), findsNothing);
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(c.published, hasLength(1));
  });

  testWidgets('a failing create says so and can be tried again', (tester) async {
    final c = await _open(tester);
    await _addPhotos(tester);
    await _pickService(tester);
    c.publisher.failWith = StateError('offline');
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(find.text('Không đăng được bài. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    expect(c.published, isEmpty);
    c.publisher.failWith = null;
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(c.published, hasLength(1));
  });

  testWidgets('a photo shows its progress while it uploads, and the button spins', (tester) async {
    final slow = _SlowUploader();
    await _open(tester, create: _Create(picks: [[img(0)]], uploader: slow));
    await _addPhotos(tester);
    await _pickService(tester);
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Đang tải 40%'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.descendant(of: find.byKey(const Key('create-tile-0')), matching: find.byType(LinearProgressIndicator)),
    );
    expect(bar.value, closeTo(0.4, 0.001));
    expect(find.byKey(const Key('create-remove-0')), findsNothing, reason: 'no edits while publishing');
    slow.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('style: choose one, then clear it', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('create-style')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Film'));
    await tester.pumpAndSettle();
    expect(_state(tester).styleId, 'film');
    await tester.tap(find.byKey(const Key('create-style')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Không chọn'));
    await tester.pumpAndSettle();
    expect(_state(tester).styleId, isNull);
  });

  testWidgets('the portfolio switch and the place are stored in the form', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('create-portfolio')));
    await tester.enterText(find.byKey(const Key('create-location')), 'Bến Bạch Đằng');
    await tester.pump();
    expect(_state(tester).inPortfolio, isFalse);
    expect(_state(tester).locationName, 'Bến Bạch Đằng');
  });

  testWidgets('leaving the screen and coming back keeps what was typed', (tester) async {
    final c = _Create();
    await c.init();
    await tester.pumpWidget(screenApp(home: c.screen(), overrides: c.overrides));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create-caption')), 'Nháp');
    await tester.pump();
    await tester.pumpWidget(screenApp(home: const SizedBox(), overrides: c.overrides));
    await tester.pumpWidget(screenApp(home: c.screen(), overrides: c.overrides));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('create-caption'))).controller!.text, 'Nháp');
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320x640 at 1.3x on ${b.name} with photos, errors and a sheet', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(tester, textScale: 1.3, brightness: b);
      await _addPhotos(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('create-service')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter).evaluate().length, lessThanOrEqualTo(1));
    });
  }
}

/// An upload that stops at 40 percent until [finish] is called.
class _SlowUploader implements MediaUploader {
  final _gate = Completer<void>();
  void finish() => _gate.complete();

  @override
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath}) async* {
    yield const UploadEvent.progress(0.4);
    await _gate.future;
    yield UploadEvent.done(UploadedMedia(url: 'https://storage.test/$storagePath', storagePath: storagePath));
  }

  @override
  Future<void> delete(String storagePath) async {}
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/create_post/create_post_screen_test.dart`
Expected: FAIL (`CreatePostScreen` and the strings do not exist).

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry), then `flutter gen-l10n`:

```json
  "createAddPhotos": "Thêm ảnh",
  "createPhotosCount": "{n} / {max} ảnh",
  "@createPhotosCount": {
    "placeholders": {
      "n": {"type": "int"},
      "max": {"type": "int"}
    }
  },
  "createCaptionLabel": "Mô tả",
  "createCaptionHint": "Chiều muộn ở bến Bạch Đằng…",
  "createServiceLabel": "Gói dịch vụ · bắt buộc",
  "createServicePick": "Chọn gói",
  "createServiceTitle": "Chọn gói dịch vụ",
  "createServiceRequired": "Chọn gói dịch vụ cho bài đăng",
  "createPhotosRequired": "Thêm ít nhất một ảnh",
  "createNoServices": "Bạn chưa có gói dịch vụ nào. Thêm gói để đăng bài.",
  "createAddService": "Thêm gói",
  "createLocationLabel": "Địa điểm",
  "createStyleLabel": "Phong cách",
  "createStyleNone": "Không chọn",
  "createStyleTitle": "Phong cách",
  "createPortfolio": "Thêm vào portfolio",
  "createPublish": "Đăng",
  "createRemove": "Gỡ ảnh",
  "createMoveUp": "Đưa lên",
  "createMoveDown": "Đưa xuống",
  "createRetryPhoto": "Tải lại ảnh",
  "createUploading": "Đang tải {percent}%",
  "@createUploading": {
    "placeholders": {
      "percent": {"type": "int"}
    }
  },
  "createUploadFailed": "Không tải được ảnh. Thử lại nhé.",
  "createPublishFailed": "Không đăng được bài. Kiểm tra mạng rồi thử lại.",
  "createPublished": "Đã đăng bài"
```

```dart
// lib/features/create_post/create_post_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/create_post/post_composer.dart';

/// S21: publish once for the feed and the portfolio, always tied to a package.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({
    super.key,
    required this.onAddService,
    required this.onPublished,
  });

  final VoidCallback onAddService;
  final ValueChanged<String> onPublished;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  late final TextEditingController _caption;
  late final TextEditingController _location;

  @override
  void initState() {
    super.initState();
    final s = ref.read(postComposerProvider);
    _caption = TextEditingController(text: s.caption);
    _location = TextEditingController(text: s.locationName ?? '');
    // After a publish the form starts again: show the empty fields.
    ref.listenManual(postComposerProvider.select((s) => s.draftId), (_, _) {
      final now = ref.read(postComposerProvider);
      _caption.text = now.caption;
      _location.text = now.locationName ?? '';
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _publish() async {
    final l = context.l10n;
    final result = await ref.read(postComposerProvider.notifier).publish();
    if (!mounted) {
      return;
    }
    switch (result.outcome) {
      case PublishOutcome.published:
        _toast(l.createPublished);
        widget.onPublished(result.postId!);
      case PublishOutcome.imageFailed:
        _toast(l.createUploadFailed);
      case PublishOutcome.publishFailed:
        _toast(l.createPublishFailed);
      case PublishOutcome.notReady:
        break;
    }
  }

  Future<void> _pickService(List<ServiceSummary> services, String? current) async {
    final l = context.l10n;
    final picked = await showAppSheet<ServiceSummary>(
      context,
      builder: (sheet) => _SheetList(
        title: l.createServiceTitle,
        rows: [
          for (final s in services)
            OptionRow(
              label: '${s.name} · ${formatMoney(s.priceVnd)}',
              selected: s.id == current,
              onTap: () => Navigator.of(sheet).pop(s),
            ),
        ],
      ),
    );
    if (picked != null) {
      ref.read(postComposerProvider.notifier).setService(picked);
    }
  }

  Future<void> _pickStyle(String? current) async {
    final l = context.l10n;
    final picked = await showAppSheet<Picked>(
      context,
      builder: (sheet) => _SheetList(
        title: l.createStyleTitle,
        rows: [
          OptionRow(
            label: l.createStyleNone,
            selected: current == null,
            onTap: () => Navigator.of(sheet).pop(const Picked(null)),
          ),
          for (final o in kStyles)
            OptionRow(
              label: o.labelVi,
              selected: o.id == current,
              onTap: () => Navigator.of(sheet).pop(Picked(o.id)),
            ),
        ],
      ),
    );
    if (picked != null) {
      ref.read(postComposerProvider.notifier).setStyle(picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = ref.watch(postComposerProvider);
    final ctl = ref.read(postComposerProvider.notifier);
    final services = ref.watch(myServicesProvider);
    final started = s.images.isNotEmpty ||
        s.caption.isNotEmpty ||
        s.serviceId != null ||
        s.locationName != null;
    final stack = MediaQuery.textScalerOf(context).scale(16) > 18.4;
    ServiceSummary? chosen;
    for (final sv in services.value ?? const <ServiceSummary>[]) {
      if (sv.id == s.serviceId) {
        chosen = sv;
      }
    }

    return ScreenCode(
      ScreenCodes.createPost,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.tabCreate)),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpace.s2,
                crossAxisSpacing: AppSpace.s2,
              ),
              itemCount: s.images.length + (s.images.length < PostComposerController.maxImages ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == s.images.length) {
                  return _AddTile(
                    key: const Key('create-add'),
                    onTap: s.publishing ? null : ctl.pickImages,
                  );
                }
                return _ImageTile(
                  key: Key('create-tile-$i'),
                  index: i,
                  count: s.images.length,
                  image: s.images[i],
                  locked: s.publishing,
                  onRemove: () => ctl.removeImage(s.images[i].key),
                  onUp: () => ctl.moveImage(s.images[i].key, -1),
                  onDown: () => ctl.moveImage(s.images[i].key, 1),
                  onRetry: () => ctl.retryImage(s.images[i].key),
                );
              },
            ),
            const SizedBox(height: AppSpace.s1),
            if (s.images.isNotEmpty)
              Text(
                l.createPhotosCount(s.images.length, PostComposerController.maxImages),
                style: theme.textTheme.bodySmall,
              ),
            if (started && s.images.isEmpty)
              _FieldError(l.createPhotosRequired),
            const SizedBox(height: AppSpace.s4),
            TextField(
              key: const Key('create-caption'),
              controller: _caption,
              minLines: 3,
              maxLines: 6,
              maxLength: PostComposerController.maxCaption,
              onChanged: ctl.setCaption,
              decoration: InputDecoration(
                labelText: l.createCaptionLabel,
                hintText: l.createCaptionHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            _ServiceField(
              services: services,
              chosen: chosen,
              onTap: (list) => _pickService(list, s.serviceId),
              onAddService: widget.onAddService,
              showError: started && s.serviceId == null,
            ),
            const SizedBox(height: AppSpace.s3),
            TextField(
              key: const Key('create-location'),
              controller: _location,
              maxLength: 60,
              onChanged: ctl.setLocation,
              decoration: InputDecoration(labelText: l.createLocationLabel),
            ),
            _PickField(
              key: const Key('create-style'),
              label: l.createStyleLabel,
              value: s.styleId == null ? null : styleLabel(s.styleId!),
              onTap: () => _pickStyle(s.styleId),
            ),
            SwitchListTile(
              key: const Key('create-portfolio'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.createPortfolio),
              value: s.inPortfolio,
              onChanged: s.publishing ? null : ctl.setInPortfolio,
            ),
            const SizedBox(height: AppSpace.s2),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s4),
            child: AppButton.primary(
              l.createPublish,
              key: const Key('create-publish'),
              loading: s.publishing,
              onPressed: s.canPublish ? _publish : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// What the style sheet returns; `id == null` means "no style".
class Picked {
  const Picked(this.id);
  final String? id;
}

class _SheetList extends StatelessWidget {
  const _SheetList({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s5, 0, AppSpace.s5, AppSpace.s2),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppSpace.s3, 0, AppSpace.s3, AppSpace.s5),
            children: rows,
          ),
        ),
      ],
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s1),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: AppText.sm),
    ),
  );
}

/// A tap-to-choose row that looks like an input.
class _PickField extends StatelessWidget {
  const _PickField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          side: BorderSide(color: accent ? scheme.primary : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(controlRadius),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: theme.textTheme.bodySmall),
                        if (value != null) Text(value!),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceField extends StatelessWidget {
  const _ServiceField({
    required this.services,
    required this.chosen,
    required this.onTap,
    required this.onAddService,
    required this.showError,
  });

  final AsyncValue<List<ServiceSummary>> services;
  final ServiceSummary? chosen;
  final ValueChanged<List<ServiceSummary>> onTap;
  final VoidCallback onAddService;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final list = services.value;
    if (services.isLoading && list == null) {
      return const AppSkeleton.box(height: 56);
    }
    if (list != null && list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.createNoServices, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l.createAddService,
            key: const Key('create-add-service'),
            onPressed: onAddService,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PickField(
          key: const Key('create-service'),
          label: l.createServiceLabel,
          value: chosen == null ? l.createServicePick : '${chosen!.name} · ${formatMoney(chosen!.priceVnd)}',
          accent: true,
          onTap: () => onTap(list ?? const []),
        ),
        if (showError) _FieldError(l.createServiceRequired),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({super.key, required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.createAddPhotos,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(AppRadius.lg + 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg + 8),
          onTap: onTap,
          child: Center(child: Icon(Icons.add, color: scheme.onSurface.withValues(alpha: 0.6))),
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    super.key,
    required this.index,
    required this.count,
    required this.image,
    required this.locked,
    required this.onRemove,
    required this.onUp,
    required this.onDown,
    required this.onRetry,
  });

  final int index;
  final int count;
  final ComposerImage image;
  final bool locked;
  final VoidCallback onRemove;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final failed = image.status == ComposerImageStatus.failed;
    final uploading = image.status == ComposerImageStatus.uploading;
    final scrim = IconButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      foregroundColor: Colors.white,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg + 8),
      child: LayoutBuilder(
        builder: (context, box) {
          final cacheWidth = ((box.maxWidth * ratio) / 50).ceil() * 50;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(image.picked.path),
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) => ColoredBox(color: scheme.secondary),
              ),
              if (failed) ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
              if (!locked) ...[
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    key: Key('create-remove-$index'),
                    tooltip: l.createRemove,
                    style: scrim,
                    icon: const Icon(Icons.close),
                    onPressed: onRemove,
                  ),
                ),
                if (index > 0)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: IconButton(
                      key: Key('create-up-$index'),
                      tooltip: l.createMoveUp,
                      style: scrim,
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: onUp,
                    ),
                  ),
                if (index < count - 1)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: IconButton(
                      key: Key('create-down-$index'),
                      tooltip: l.createMoveDown,
                      style: scrim,
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: onDown,
                    ),
                  ),
              ],
              if (image.status == ComposerImageStatus.uploaded)
                const Positioned(
                  top: AppSpace.s2,
                  left: AppSpace.s2,
                  child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                ),
              if (uploading)
                Positioned(
                  left: AppSpace.s2,
                  right: AppSpace.s2,
                  bottom: AppSpace.s2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.createUploading((image.progress * 100).round()),
                        style: const TextStyle(color: Colors.white, fontSize: AppText.sm),
                      ),
                      const SizedBox(height: AppSpace.s1),
                      LinearProgressIndicator(value: image.progress),
                    ],
                  ),
                ),
              if (failed)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('create-retry-$index'),
                        tooltip: l.createRetryPhoto,
                        style: scrim,
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: onRetry,
                      ),
                      Text(
                        l.createUploadFailed,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: AppText.sm),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
```

The `stack` local in `build` is not used; delete that line if the analyzer reports it. `Picked` is local to this screen (the Find screen has its own generic `Picked<T>`; this one is non-generic to keep the screen self-contained).

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/create_post && flutter analyze`
Expected: PASS (screen 17); analyze clean. If the progress test finds no `Đang tải 40%`, the slow uploader's first event may not have been delivered yet: add one more `await tester.pump()` before the expectation (the composer updates state per event). If `find.text('Chân dung 2 giờ · 1.500.000₫')` finds two widgets (the open field also shows the chosen text) the test taps the sheet row before choosing, when the field still shows "Chọn gói"; keep that order.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/create_post lib/l10n test/features/create_post
git commit -m "feat(create-post): S21 Create post screen

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Wire S21 into the photographer's middle tab, and put the new post first on Home

**Files:**
- Modify: `lib/features/home/home_controller.dart`, `lib/features/home/home_screen.dart`, `lib/features/shell/placeholder_tabs.dart`, `test/features/home/home_controller_test.dart`, `test/app/discovery_routes_test.dart`, `test/features/responsive_test.dart`
- Create: `test/features/create_post/create_post_flow_test.dart`

**Interfaces:**
- Consumes: `CreatePostScreen`, `HomeFeedController`, `FakePostPublisher`.
- Produces:
  - `HomeFeedController.pinToTop(String postId)`: reloads the feed for "Dành cho bạn", then moves the given post to the front, fetching it (with its author) when the ranking did not include it. Without it the on-device ranking would put a new post behind photographers who are free sooner, and the spec says the new post is at the top ("Đăng xong về S01 với bài mới ở đầu").
  - `ActionTab` for photographers: `CreatePostScreen(onAddService: () => context.push('/setup/2'), onPublished: (id) { pin it; go('/home'); })`.
  - Home shows the chip that matches the loaded category (so returning from Create after a pin selects "Dành cho bạn" again).

- [ ] **Step 1: Write the failing tests**

Append to `test/features/home/home_controller_test.dart` inside `main()`:

```dart
  test('pinToTop puts a post the ranking would put last at the front', () async {
    final (c, w, _) = await _make();
    await c.read(homeFeedProvider.future);
    w.posts.add(fixturePost('late', photographerId: 'p4', age: const Duration(seconds: 1)));
    await c.read(homeFeedProvider.notifier).pinToTop('late');
    final s = c.read(homeFeedProvider).requireValue;
    expect(s.items.first.post.id, 'late');
    expect(s.items.where((e) => e.post.id == 'late'), hasLength(1));
    expect(s.items.length, greaterThan(1));
  });

  test('pinToTop returns to "Dành cho bạn" and fetches a post the ranking did not include', () async {
    final (c, w, _) = await _make();
    await c.read(homeFeedProvider.future);
    await c.read(homeFeedProvider.notifier).selectCategory('wedding');
    w.posts.add(fixturePost('mine', photographerId: 'p1', specialtyId: 'portrait', age: const Duration(seconds: 1)));
    await c.read(homeFeedProvider.notifier).pinToTop('mine');
    final s = c.read(homeFeedProvider).requireValue;
    expect(s.category, isNull);
    expect(s.items.first.post.id, 'mine');
  });

  test('pinToTop with a post that cannot be found just refreshes', () async {
    final (c, _, _) = await _make();
    await c.read(homeFeedProvider.future);
    await c.read(homeFeedProvider.notifier).pinToTop('ghost');
    expect(c.read(homeFeedProvider).requireValue.items.map((e) => e.post.id), ['a', 'b', 'c', 'e', 'd']);
  });
```

Replace the photographer test in `test/app/discovery_routes_test.dart`:

```dart
  testWidgets('a photographer\'s middle tab is the Create post screen', (tester) async {
    final w = DiscoveryWorld(role: UserRole.photographer);
    await w.init();
    await tester.pumpWidget(screenApp(home: const ActionTab(), overrides: w.overrides));
    await tester.pumpAndSettle();
    expect(find.byType(FindPhotographerScreen), findsNothing);
    expect(find.byType(CreatePostScreen), findsOneWidget);
  });
```

(add `import 'package:photobooking/features/create_post/create_post_screen.dart';` to that file.) In `test/features/responsive_test.dart` remove the `'action': () => const ActionTab(),` entry: Find and Create post have their own 320 dp, 1.3x tests.

```dart
// test/features/create_post/create_post_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/home/home_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

void main() {
  testWidgets('publish on the middle tab, land on Home with the new post first', (tester) async {
    final w = DiscoveryWorld(role: UserRole.photographer);
    await w.init();
    // The photographer needs a profile card and a package for Home to show the post.
    w.photographers.add(fixturePhotographer(w.uid, name: 'Tôi'));
    w.services.add(fixtureService('s1', photographerId: w.uid));
    final publisher = FakePostPublisher(posts: w.posts, clock: () => fixtureNow);
    final router = GoRouter(
      initialLocation: AppTab.action.path,
      routes: [
        GoRoute(path: AppTab.action.path, builder: (_, _) => const ActionTab()),
        GoRoute(path: AppTab.home.path, builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/setup/2', builder: (_, _) => const Text('setup packages')),
      ],
    );
    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: [
          ...w.overrides,
          imagePickerProvider.overrideWithValue(
            FakeImagePicker([
              [const PickedImage(path: '/tmp/none.jpg', name: 'n.jpg')],
            ]),
          ),
          mediaUploaderProvider.overrideWithValue(FakeMediaUploader()),
          postPublisherProvider.overrideWithValue(publisher),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Chân dung 2 giờ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();

    final id = publisher.published.single.id;
    expect(find.byKey(Key('post-$id')), findsOneWidget, reason: 'Home shows the new post as the large card');
    expect(find.text('Chào Lan Anh'), findsOneWidget);
  });

  testWidgets('"Thêm gói" opens the package setup', (tester) async {
    final w = DiscoveryWorld(role: UserRole.photographer);
    await w.init();
    final router = GoRouter(
      initialLocation: AppTab.action.path,
      routes: [
        GoRoute(path: AppTab.action.path, builder: (_, _) => const ActionTab()),
        GoRoute(path: '/setup/2', builder: (_, _) => const Text('setup packages')),
      ],
    );
    await tester.pumpWidget(screenRouterApp(router: router, overrides: w.overrides));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-add-service')));
    await tester.pumpAndSettle();
    expect(find.text('setup packages'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/home/home_controller_test.dart test/features/create_post/create_post_flow_test.dart test/app/discovery_routes_test.dart`
Expected: FAIL (`pinToTop` does not exist; `ActionTab` still shows the placeholder to photographers).

- [ ] **Step 3: Implement**

In `lib/features/home/home_controller.dart` add to `HomeFeedController` (imports needed: `content_providers.dart` is already imported; add `package:photobooking/data/recommendation/recommendation_models.dart` if not present):

```dart
  /// Shows [postId] first, on "Dành cho bạn". The on-device ranking puts
  /// photographers who are free soon first, so a post that was just published
  /// would otherwise sit below them; the spec wants it on top.
  Future<void> pinToTop(String postId) async {
    final fresh = await AsyncValue.guard(() => _loadFirst(null));
    if (!ref.mounted) {
      return;
    }
    final data = fresh.value;
    if (data == null) {
      return;
    }
    RecommendedPost? pinned;
    for (final item in data.items) {
      if (item.post.id == postId) {
        pinned = item;
      }
    }
    if (pinned == null) {
      final post = await ref.read(postRepositoryProvider).byId(postId);
      if (post != null) {
        final authors = await ref
            .read(photographerRepositoryProvider)
            .summaries([post.photographerId]);
        final author = authors[post.photographerId];
        if (author != null) {
          pinned = RecommendedPost(post: post, photographer: author, rank: 1);
        }
      }
    }
    if (!ref.mounted) {
      return;
    }
    if (pinned == null) {
      state = fresh;
      return;
    }
    final first = pinned;
    state = AsyncData(
      data.copyWith(
        items: [first, ...data.items.where((e) => e.post.id != postId)],
      ),
    );
    unawaited(ref.read(engagementProvider.notifier).seed([first.post]));
  }
```

In `lib/features/home/home_screen.dart`, make the chips follow the loaded category: in `build`, right after `final feed = ref.watch(homeFeedProvider);` add

```dart
    // Once a feed is loaded, its category is the truth (a pin from Create post
    // returns to "Dành cho bạn"); while it loads, the tapped chip.
    final selected = feed.hasValue && !feed.isLoading ? feed.requireValue.category : _selected;
    _selected = selected;
```

and use `selected` instead of `_selected` for the `selected:` argument of the chips (`selected == null`, `selected == id`).

In `lib/features/shell/placeholder_tabs.dart` add the imports `package:go_router/go_router.dart` (already present), `package:photobooking/app/tabs.dart`, `package:photobooking/features/create_post/create_post_screen.dart` and `package:photobooking/features/home/home_controller.dart`, and replace the photographer branch of `ActionTab.build` with:

```dart
    return CreatePostScreen(
      onAddService: () => context.push('/setup/2'),
      onPublished: (postId) {
        ref.read(homeFeedProvider.notifier).pinToTop(postId);
        context.go(AppTab.home.path);
      },
    );
```

(the remaining `Scaffold`/`EmptyState` placeholder code and its `l` local are deleted; the strings `emptyCreateTitle` and `emptyCreateBody` become unused and stay in the ARB).

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/features test/app && flutter analyze && flutter test`
Expected: PASS; analyze clean; the whole suite is green. In the flow test, the new post is the first large card because `pinToTop` runs while the router changes to Home; if the key `post-$id` is not found, wait one more frame (`await tester.pumpAndSettle()` after the publish tap) because `pinToTop` finishes after navigation.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(create-post): photographer's middle tab is Create post; new post lands first on Home

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/create_post_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `expectIdle`, `expectBlurBudget`, `_Create`-style setup (copied into this file), the composer, the screen.
- Produces: no production code.

What is checked: the form is idle at rest in every state (empty, with photos, with failed and uploaded tiles, with a sheet open); a running upload costs one spinner and determinate progress, no other animation; uploads are strictly one at a time and rebuild the screen a bounded number of times; the screen holds file paths and decodes previews at tile size, never bytes; no timers or streams; no location or camera access; the platform files ask for the photo library only (Task 1).

- [ ] **Step 1: Write the tests**

If `test/support/idle.dart` or `test/support/blur.dart` is missing, create it with exactly the code given in plan 3a1 Task 7.

```dart
// test/battery/create_post_battery_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/create_post/post_composer.dart';

import '../support/blur.dart';
import '../support/content_fixtures.dart';
import '../support/discovery_world.dart';
import '../support/idle.dart';
import '../support/screen_host.dart';

PickedImage img(int i) => PickedImage(path: '/tmp/none-$i.jpg', name: '$i.jpg');

Future<(DiscoveryWorld, FakeMediaUploader, FakePostPublisher)> _open(
  WidgetTester tester, {
  int photos = 3,
  MediaUploader? uploader,
}) async {
  final w = DiscoveryWorld(role: UserRole.photographer);
  await w.init();
  w.services.add(fixtureService('s1', photographerId: w.uid));
  final fake = FakeMediaUploader();
  final publisher = FakePostPublisher(posts: w.posts, clock: () => fixtureNow);
  await tester.pumpWidget(
    screenApp(
      home: CreatePostScreen(onAddService: () {}, onPublished: (_) {}),
      overrides: [
        ...w.overrides,
        imagePickerProvider.overrideWithValue(FakeImagePicker([[for (var i = 0; i < photos; i++) img(i)]])),
        mediaUploaderProvider.overrideWithValue(uploader ?? fake),
        postPublisherProvider.overrideWithValue(publisher),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return (w, fake, publisher);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CreatePostScreen)));

void main() {
  group('the form is idle at rest', () {
    testWidgets('empty', (tester) async {
      await _open(tester);
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('with photos, one failed and one uploaded', (tester) async {
      final (_, uploader, _) = await _open(tester);
      await tester.tap(find.byKey(const Key('create-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Chân dung 2 giờ'));
      await tester.pumpAndSettle();
      uploader.failNames.add('1.jpg');
      await tester.tap(find.byKey(const Key('create-publish')));
      await tester.pumpAndSettle();
      final statuses = _container(tester).read(postComposerProvider).images.map((i) => i.status).toList();
      expect(statuses, [ComposerImageStatus.uploaded, ComposerImageStatus.failed, ComposerImageStatus.local]);
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('with the package sheet open', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const Key('create-service')));
      await expectIdle(tester);
      expectBlurBudget(max: 1);
    });
  });

  testWidgets('while a photo uploads: determinate progress and one spinner, nothing else moves', (
    tester,
  ) async {
    final slow = _Slow();
    await _open(tester, photos: 1, uploader: slow);
    await tester.tap(find.byKey(const Key('create-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Chân dung 2 giờ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, isNotNull, reason: 'an indeterminate bar would animate forever');
    expect(tester.binding.transientCallbackCount, lessThanOrEqualTo(1), reason: 'only the button spinner');
    slow.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('ten photos upload strictly one at a time with a bounded number of rebuilds', (
    tester,
  ) async {
    final (_, uploader, _) = await _open(tester, photos: 10);
    await tester.tap(find.byKey(const Key('create-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Chân dung 2 giờ'));
    await tester.pumpAndSettle();
    var states = 0;
    _container(tester).listen(postComposerProvider, (_, _) => states++);
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(uploader.maxConcurrent, 1);
    expect(uploader.uploaded, hasLength(10));
    // per photo: start, two progress steps, done; plus publishing on/off and the reset.
    expect(states, lessThanOrEqualTo(10 * 4 + 6));
  });

  group('source audit', () {
    String read(String path) => File(path).readAsStringSync();

    test('previews are decoded at tile size and no image bytes are held', () {
      final screen = read('lib/features/create_post/create_post_screen.dart');
      expect(screen, contains('Image.file('));
      expect(screen, contains('cacheWidth: cacheWidth'));
      for (final f in [
        'lib/features/create_post/post_composer.dart',
        'lib/features/create_post/create_post_screen.dart',
        'lib/data/media/media_uploader.dart',
      ]) {
        final src = read(f);
        expect(src, isNot(contains('readAsBytes')), reason: f);
        expect(src, isNot(contains('Uint8List')), reason: f);
      }
    });

    test('no timer, ticker, stream provider or listener in the feature', () {
      for (final f in Directory('lib/features/create_post').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        for (final banned in ['Timer', 'AnimationController', 'StreamProvider', '.snapshots(', 'Stream.periodic']) {
          expect(src, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    });

    test('Create post never touches location or the camera', () {
      for (final f in Directory('lib/features/create_post').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('LocationRepository')), reason: f.path);
        expect(src, isNot(contains('ImageSource.camera')), reason: f.path);
      }
      expect(read('lib/data/media/plugin_image_picker.dart'), isNot(contains('ImageSource.camera')));
    });

    test('the picker scales and re-encodes before the app ever sees the file', () {
      final src = read('lib/data/media/plugin_image_picker.dart');
      expect(src, contains('2048'));
      expect(src, contains('imageQuality'));
    });

    test('the permission files are checked by the platform test', () {
      expect(File('test/platform/media_platform_config_test.dart').existsSync(), isTrue);
    });
  });
}

class _Slow implements MediaUploader {
  final _gate = Completer<void>();
  void finish() => _gate.complete();

  @override
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath}) async* {
    yield const UploadEvent.progress(0.4);
    await _gate.future;
    yield UploadEvent.done(UploadedMedia(url: 'https://storage.test/$storagePath', storagePath: storagePath));
  }

  @override
  Future<void> delete(String storagePath) async {}
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/create_post_battery_test.dart test/platform`
Expected: PASS (9 + 3 tests). A failure names the culprit: an idle failure means a spinner, skeleton or controller is alive while nothing happens (a failed tile must not show a spinner); a state-count failure means progress events rebuild the screen too often; a source failure means bytes, a timer or a camera path crept in. Fix the code, not the test.

- [ ] **Step 3: Fix anything the run found**

Re-run Step 2 until green.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it) on a mid-range Android phone in profile mode:

1. Pick 10 photos taken with the phone's camera (about 12 MP each) and publish on mobile data: watch memory (PSS) while the previews load and during the upload (< 250 MB, and no growth after the post is published), the mobile radio (active only during uploads, `batterystats`), and that no wake lock is held.
2. Leave the filled form open for 5 minutes (idle frames ≤ 5 per 30 s, CPU < 3 %).
3. Publish, then confirm the new post is first on Home and the photos load at tile size from Storage.
4. Kill the app between "photos uploaded" and "post created" once and note any leftover objects under `posts/{uid}/{draftId}/`: they are the known orphan case and are cleaned by a server job later, not by this plan.

- Android: `flutter run --profile`; `adb shell dumpsys gfxinfo`, `top`, `batterystats` and `meminfo` as in the guide.
- iOS: Xcode Instruments (Allocations, Time Profiler and Energy Log) on a real iPhone, or the Simulator's Debug Navigator CPU, Memory and Energy gauges; peak memory while picking 10 photos must stay bounded and Energy Impact must read "Low" at rest. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement".

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add test/support test/battery
git commit -m "test: idle, upload-order, memory and permission checks for Create post

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** S21 — photo grid up to 10 with a "+" tile, reorder with up/down buttons, remove; caption; package required (accent border, error under the field, "Thêm gói" when none); place and style; "Thêm vào portfolio"; "Đăng" disabled until a photo and a package exist; per-photo progress and a separate retry; text draft saved on the device; published once for feed and portfolio (post document plus `photographers/{uid}.portfolio`); the new post is first on Home (`pinToTop`); no orphan photos from removed or abandoned uploads (delete on removal; uploads only at publish time; same id on retry). Hashtags are extracted and stored (spec 3.7: "only store them"). Storage resize to 2048 px and quality 85 happen in the picker; rules for post creation and for Storage with tests.
- **Deviations (flagged):** (1) images are re-encoded as JPEG quality 85, not WebP (the picker cannot encode WebP; a WebP encoder is a later optimisation). (2) The draft saves text only, not photos (temporary picker files may be gone). (3) Reordering uses the up and down buttons; dragging is not built (the spec allows the buttons as the alternative). (4) The "Bài đăng / Sự kiện" tabs and S25 are not here (events plan). (5) Photos uploaded and then abandoned by killing the app stay in Storage until a server cleanup exists. (6) Post location stores the place name only, no geohash (privacy: no coordinates are involved in posting).
- **Cross-plan dependencies:** `/setup/2` (plan 2d) for "Thêm gói"; plan 3b4's `HomeFeedController` gains `pinToTop`; the posts rules block from plan 3b1 is replaced by the create rule; `firebase/firebase.json` and the rules test script now start the Storage emulator (the CI job in `.github/workflows/flutter.yml` runs `npm test` and needs no change).
- **Placeholders:** none. **Type consistency:** `PickedImage`, `ImagePickerPort.pickImages(max:)`, `UploadedMedia`/`UploadEvent`/`MediaUploader`, `PostDraft`/`PostPublisher`, `ComposerState`/`ComposerImage`/`PostPublishResult`/`PublishOutcome`, `postComposerProvider`, `CreatePostScreen(onAddService, onPublished)`, the keys `create-*`, `newUlid`, `extractHashtags` are named identically in tests and code.
- **Battery and performance (Task 8):** idle in every form state, one spinner and determinate progress while uploading, strictly sequential uploads with a bounded number of rebuilds, no bytes in memory (`putFile` from disk, previews decoded at tile size), no timers or streams, no location or camera, permission files asserted for Android and iOS (Task 1), manual Android and iOS profiling per `docs/testing/battery-and-performance.md`.
- **Risks:** `image_picker` and `firebase_storage` versions (Task 1 Step 1 checks they resolve); the Storage emulator in the rules test script; `Image.file` with a missing file in widget tests relies on `errorBuilder`; the exact count of transient callbacks while a button spinner runs (Task 8 uses `<= 1`).

// test/features/create_post/post_composer_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/create_post/post_composer.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_fixtures.dart';

PickedImage img(int i) =>
    PickedImage(path: '/tmp/$i.jpg', name: '$i.jpg', sizeBytes: 1000);

/// Uploads that stay in flight until [release] is called.
class _GatedUploader extends FakeMediaUploader {
  final Completer<void> gate = Completer<void>();
  void release() => gate.complete();

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
  }) async* {
    uploadCalls++;
    yield const UploadEvent.progress(0.3);
    await gate.future;
    uploaded.add(storagePath);
    yield UploadEvent.done(
      UploadedMedia(
        url: 'https://storage.test/$storagePath',
        storagePath: storagePath,
      ),
    );
  }
}

class _Env {
  _Env(
    this.c,
    this.picker,
    this.uploader,
    this.publisher,
    this.posts,
    this.prefs,
    this.uid,
  );
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
  final e = await _env(
    picks: [
      [for (var i = 0; i < photos; i++) img(i)],
    ],
  );
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
      final e = await _env(
        picks: [
          [img(1)],
        ],
      );
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

    test(
      'picking asks for exactly the room that is left and never exceeds ten',
      () async {
        final e = await _env(
          picks: [
            [for (var i = 0; i < 6; i++) img(i)],
            [for (var i = 10; i < 20; i++) img(i)],
          ],
        );
        await e.ctl.pickImages();
        await e.ctl.pickImages();
        expect(e.picker.requestedMax, [10, 4]);
        expect(e.state.images, hasLength(10));
        await e.ctl.pickImages();
        expect(
          e.picker.calls,
          2,
          reason: 'no room: the picker is not even opened',
        );
      },
    );

    test('a cancelled picker adds nothing', () async {
      final e = await _env(picks: [[]]);
      await e.ctl.pickImages();
      expect(e.state.images, isEmpty);
    });

    test('photos can be moved and removed', () async {
      final e = await _env(
        picks: [
          [img(0), img(1), img(2)],
        ],
      );
      await e.ctl.pickImages();
      List<String> names() => e.state.images.map((i) => i.picked.name).toList();
      final k = e.state.images.map((i) => i.key).toList();
      e.ctl.moveImage(k[2], -1);
      expect(names(), ['0.jpg', '2.jpg', '1.jpg']);
      e.ctl.moveImage(k[0], -1);
      expect(names(), [
        '0.jpg',
        '2.jpg',
        '1.jpg',
      ], reason: 'the first cannot go up');
      e.ctl.moveImage(k[1], 1);
      expect(names(), [
        '0.jpg',
        '2.jpg',
        '1.jpg',
      ], reason: 'the last cannot go down');
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
    test(
      'uploads one by one to the post folder, then creates the post',
      () async {
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
        expect(d.images.map((i) => i.url), [
          for (final p in e.uploader.uploaded) 'https://storage.test/$p',
        ]);
        expect((await e.posts.byId(draftId))!.hashtags, ['chandung']);
      },
    );

    test(
      'afterwards the form is empty with a new post id, and the draft is gone',
      () async {
        final e = await _ready();
        e.ctl.setCaption('Xong');
        final before = e.state.draftId;
        await e.ctl.publish();
        expect(e.state.images, isEmpty);
        expect(e.state.caption, isEmpty);
        expect(e.state.serviceId, isNull);
        expect(e.state.draftId, isNot(before));
        expect(e.state.publishing, isFalse);
        expect(
          e.prefs.getKeys().where((k) => k.startsWith('postDraft')),
          isEmpty,
        );
      },
    );

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
      final out = await _env(
        signedIn: false,
        picks: [
          [img(1)],
        ],
      );
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
      expect(
        e.uploader.uploadCalls,
        calls + 2,
        reason: 'only the third photo was left',
      );
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
      expect(
        e.state.images.every((i) => i.status == ComposerImageStatus.uploaded),
        isTrue,
      );
      expect(e.state.draftId, id);
      final uploads = e.uploader.uploadCalls;

      e.publisher.failWith = null;
      final again = await e.ctl.publish();
      expect(again.outcome, PublishOutcome.published);
      expect(again.postId, id);
      expect(
        e.uploader.uploadCalls,
        uploads,
        reason: 'nothing is uploaded twice',
      );
    });

    test('removing an uploaded photo deletes it from Storage', () async {
      final e = await _ready();
      e.uploader.failNames.add('1.jpg');
      expect((await e.ctl.publish()).outcome, PublishOutcome.imageFailed);
      final victim = e.state.images.first;
      expect(victim.status, ComposerImageStatus.uploaded);
      final path = victim.media!.storagePath;
      e.ctl.removeImage(victim.key);
      await Future<void>.delayed(Duration.zero);
      expect(e.uploader.deleted, [path]);
    });

    test('after a failed create, removing a photo keeps its Storage file '
        '(the queued write may still land)', () async {
      final e = await _ready();
      e.publisher.failWith = StateError('timeout');
      expect((await e.ctl.publish()).outcome, PublishOutcome.publishFailed);
      e.ctl.removeImage(e.state.images.first.key);
      await Future<void>.delayed(Duration.zero);
      expect(e.state.images, hasLength(1));
      expect(e.uploader.deleted, isEmpty);
    });

    test('a photo that was never uploaded is simply dropped', () async {
      final e = await _ready(photos: 1);
      e.ctl.removeImage(e.state.images.single.key);
      expect(e.uploader.deleted, isEmpty);
    });

    test('a failing delete does not break the form', () async {
      final e = await _ready();
      e.uploader.failNames.add('1.jpg');
      await e.ctl.publish();
      e.uploader.deleteFailure = StateError('offline');
      e.ctl.removeImage(e.state.images.first.key);
      await Future<void>.delayed(Duration.zero);
      expect(e.state.images, hasLength(1));
    });
  });

  group('the draft on the device', () {
    test(
      'text fields are saved under the user\'s key, photos are not',
      () async {
        final e = await _env();
        e.ctl.setCaption('Chiều muộn');
        e.ctl.setService(fixtureService('s1'));
        e.ctl.setLocation('Bến Bạch Đằng');
        e.ctl.setStyle('film');
        e.ctl.setInPortfolio(false);
        final stored = jsonDecode(
          e.prefs.getString('postDraft:${e.uid}')!,
        ) as Map<String, dynamic>;
        expect(stored['caption'], 'Chiều muộn');
        expect(stored['serviceId'], 's1');
        expect(stored['specialtyId'], 'portrait');
        expect(stored['inPortfolio'], false);
        expect(stored.containsKey('images'), isFalse);
        expect(e.prefs.getKeys().where((k) => k.startsWith('postDraft')), [
          'postDraft:${e.uid}',
        ]);
      },
    );

    test('the same user gets the draft back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthRepository();
      final uid = (await auth.registerWithEmail(
        'a@b.vn',
        'password1',
        'Minh',
      )).uid;
      ProviderContainer make() => ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          imagePickerProvider.overrideWithValue(FakeImagePicker()),
          mediaUploaderProvider.overrideWithValue(FakeMediaUploader()),
          postPublisherProvider.overrideWithValue(
            FakePostPublisher(posts: FakePostRepository()),
          ),
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
      expect(
        (
          s.caption,
          s.serviceId,
          s.specialtyId,
          s.locationName,
          s.styleId,
          s.inPortfolio,
        ),
        ('Nháp của tôi', 's1', 'portrait', 'Hồ Gươm', 'film', false),
      );
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
      final uid = (await auth.registerWithEmail(
        'a@b.vn',
        'password1',
        'Minh',
      )).uid;
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

  group('user switch, in-flight uploads, empty draft', () {
    test('another user never sees the previous user\'s form', () async {
      SharedPreferences.setMockInitialValues({
        'postDraft:fake-2': jsonEncode({'caption': 'của B', 'serviceId': 's9'}),
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthRepository();
      final a = (await auth.registerWithEmail('a@b.vn', 'password1', 'A')).uid;
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          imagePickerProvider.overrideWithValue(
            FakeImagePicker([
              [img(1)],
            ]),
          ),
          mediaUploaderProvider.overrideWithValue(FakeMediaUploader()),
          postPublisherProvider.overrideWithValue(
            FakePostPublisher(posts: FakePostRepository()),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(postComposerProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      final ctl = c.read(postComposerProvider.notifier);
      await ctl.pickImages();
      ctl.setCaption('của A');
      ctl.setService(fixtureService('s1'));
      final draftA = c.read(postComposerProvider).draftId;
      expect(prefs.containsKey('postDraft:$a'), isTrue);

      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      var s = c.read(postComposerProvider);
      expect(s.images, isEmpty);
      expect(s.caption, isEmpty);
      expect(s.draftId, isNot(draftA));

      final b = await auth.registerWithEmail('b@b.vn', 'password1', 'B');
      expect(b.uid, 'fake-2');
      await Future<void>.delayed(Duration.zero);
      s = c.read(postComposerProvider);
      expect(s.images, isEmpty);
      expect(s.caption, 'của B');
      expect(s.serviceId, 's9');
      c.read(postComposerProvider.notifier).setCaption('B sửa');
      final stored = jsonDecode(prefs.getString('postDraft:$a')!) as Map;
      expect(stored['caption'], 'của A', reason: 'A\'s draft is untouched');
    });

    test(
      'publish while a retry is uploading is not ready, one upload at a time',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final auth = FakeAuthRepository();
        await auth.registerWithEmail('a@b.vn', 'password1', 'A');
        final plain = FakeMediaUploader()..failNames.add('0.jpg');
        MediaUploader current = plain;
        final gated = _GatedUploader();
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authRepositoryProvider.overrideWithValue(auth),
            imagePickerProvider.overrideWithValue(
              FakeImagePicker([
                [img(0)],
              ]),
            ),
            mediaUploaderProvider.overrideWith((ref) => current),
            postPublisherProvider.overrideWithValue(
              FakePostPublisher(posts: FakePostRepository()),
            ),
          ],
        );
        addTearDown(c.dispose);
        final ctl = c.read(postComposerProvider.notifier);
        await ctl.pickImages();
        ctl.setService(fixtureService('s1'));
        expect((await ctl.publish()).outcome, PublishOutcome.imageFailed);

        current = gated;
        c.invalidate(mediaUploaderProvider);
        final key = c.read(postComposerProvider).images.single.key;
        final retry = ctl.retryImage(key);
        await Future<void>.delayed(Duration.zero);
        var s = c.read(postComposerProvider);
        expect(s.images.single.status, ComposerImageStatus.uploading);
        expect(s.canPublish, isFalse);
        expect((await ctl.publish()).outcome, PublishOutcome.notReady);
        expect(gated.uploadCalls, 1);
        gated.release();
        await retry;
        s = c.read(postComposerProvider);
        expect(s.images.single.status, ComposerImageStatus.uploaded);
        expect((await ctl.publish()).outcome, PublishOutcome.published);
        expect(gated.uploadCalls, 1);
      },
    );

    test('a photo cannot be removed while it uploads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = FakeAuthRepository();
      await auth.registerWithEmail('a@b.vn', 'password1', 'A');
      final gated = _GatedUploader();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          imagePickerProvider.overrideWithValue(
            FakeImagePicker([
              [img(0)],
            ]),
          ),
          mediaUploaderProvider.overrideWithValue(gated),
          postPublisherProvider.overrideWithValue(
            FakePostPublisher(posts: FakePostRepository()),
          ),
        ],
      );
      addTearDown(c.dispose);
      final ctl = c.read(postComposerProvider.notifier);
      await ctl.pickImages();
      ctl.setService(fixtureService('s1'));
      final run = ctl.publish();
      await Future<void>.delayed(Duration.zero);
      ctl.removeImage(c.read(postComposerProvider).images.single.key);
      expect(c.read(postComposerProvider).images, hasLength(1));
      gated.release();
      expect((await run).outcome, PublishOutcome.published);
      expect(gated.deleted, isEmpty);
    });

    test('setters are ignored while publishing', () async {
      final e = await _ready();
      final run = e.ctl.publish();
      e.ctl.setCaption('muộn');
      expect(e.state.caption, isEmpty);
      await run;
    });

    test('the portfolio switch alone makes a draft', () async {
      final e = await _env();
      e.ctl.setInPortfolio(false);
      expect(e.prefs.containsKey('postDraft:${e.uid}'), isTrue);
      e.ctl.setInPortfolio(true);
      expect(e.prefs.containsKey('postDraft:${e.uid}'), isFalse);
    });
  });
}

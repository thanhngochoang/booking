// test/features/create_post/create_post_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/create_post/post_composer.dart';

import '../../support/content_fixtures.dart';
import '../../support/create_post_world.dart';
import '../../support/screen_host.dart';

PickedImage img(int i) => PickedImage(path: '/tmp/none-$i.jpg', name: '$i.jpg');

/// A photographer with one package, ready to post.
class _Create {
  _Create({
    List<List<PickedImage>>? picks,
    this.withService = true,
    MediaUploader? uploader,
  }) : world = CreatePostWorld(),
       picker = FakeImagePicker(
         picks ??
             [
               [img(0), img(1), img(2)],
             ],
       ),
       uploader = uploader ?? FakeMediaUploader();

  final CreatePostWorld world;
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

Future<_Create> _open(
  WidgetTester tester, {
  _Create? create,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) async {
  final c = create ?? _Create();
  await c.init();
  await tester.pumpWidget(
    screenApp(
      home: c.screen(),
      overrides: c.overrides,
      textScale: textScale,
      brightness: brightness,
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CreatePostScreen)));

ComposerState _state(WidgetTester tester) =>
    _container(tester).read(postComposerProvider);

bool _enabled(WidgetTester tester, String key) =>
    tester
        .widget<FilledButton>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

/// Scrolls [f] into view first: the form is taller than the test window.
Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

Future<void> _addPhotos(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('create-add')));
  await tester.pumpAndSettle();
}

Future<void> _pickService(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('create-service')));
  await tester.pumpAndSettle();
  await _tap(tester, find.textContaining('Chân dung 2 giờ'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'an empty form: the plus tile, the fields, the portfolio switch on, "Đăng" disabled',
    (tester) async {
      await _open(tester);
      expect(find.text('Đăng bài'), findsOneWidget);
      expect(find.byKey(const Key('create-add')), findsOneWidget);
      expect(find.byKey(const Key('create-caption')), findsOneWidget);
      expect(find.text('Gói dịch vụ · bắt buộc'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('create-portfolio')))
            .value,
        isTrue,
      );
      expect(_enabled(tester, 'create-publish'), isFalse);
      expect(
        find.text('Thêm ít nhất một ảnh'),
        findsNothing,
        reason: 'no errors before the form is started',
      );
      expect(find.text('Chọn gói dịch vụ cho bài đăng'), findsNothing);
    },
  );

  testWidgets('adding photos fills the grid and shows the count', (
    tester,
  ) async {
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
    await _open(
      tester,
      create: _Create(
        picks: [
          [for (var i = 0; i < 10; i++) img(i)],
        ],
      ),
    );
    await _addPhotos(tester);
    expect(find.byKey(const Key('create-add')), findsNothing);
  });

  testWidgets(
    'once started, the missing photo or package is named under its field',
    (tester) async {
      await _open(tester);
      await tester.enterText(
        find.byKey(const Key('create-caption')),
        'Chiều muộn',
      );
      await tester.pump();
      expect(find.text('Thêm ít nhất một ảnh'), findsOneWidget);
      expect(find.text('Chọn gói dịch vụ cho bài đăng'), findsOneWidget);
      await _addPhotos(tester);
      expect(find.text('Thêm ít nhất một ảnh'), findsNothing);
      await _pickService(tester);
      expect(find.text('Chọn gói dịch vụ cho bài đăng'), findsNothing);
      expect(_enabled(tester, 'create-publish'), isTrue);
    },
  );

  testWidgets(
    'the package sheet lists the packages with prices and the field shows the choice',
    (tester) async {
      await _open(tester);
      await _tap(tester, find.byKey(const Key('create-service')));
      await tester.pumpAndSettle();
      expect(find.text('Chân dung 2 giờ · 1.500.000₫'), findsOneWidget);
      await _tap(tester, find.text('Chân dung 2 giờ · 1.500.000₫'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('create-service')),
          matching: find.textContaining('Chân dung 2 giờ'),
        ),
        findsOneWidget,
      );
      expect(_state(tester).serviceId, 's1');
    },
  );

  testWidgets(
    'without packages the field gives way to "Thêm gói", and posting stays off',
    (tester) async {
      final c = await _open(tester, create: _Create(withService: false));
      expect(find.byKey(const Key('create-service')), findsNothing);
      expect(
        find.text('Bạn chưa có gói dịch vụ nào. Thêm gói để đăng bài.'),
        findsOneWidget,
      );
      await _tap(tester, find.byKey(const Key('create-add-service')));
      expect(c.addServiceTaps, 1);
      await _addPhotos(tester);
      expect(_enabled(tester, 'create-publish'), isFalse);
    },
  );

  testWidgets('move up, move down and remove change the order', (tester) async {
    await _open(tester);
    await _addPhotos(tester);
    List<String> order() =>
        _state(tester).images.map((i) => i.picked.name).toList();
    await _tap(tester, find.byKey(const Key('create-up-1')));
    await tester.pump();
    expect(order(), ['1.jpg', '0.jpg', '2.jpg']);
    await _tap(tester, find.byKey(const Key('create-down-1')));
    await tester.pump();
    expect(order(), ['1.jpg', '2.jpg', '0.jpg']);
    await _tap(tester, find.byKey(const Key('create-remove-0')));
    await tester.pump();
    expect(order(), ['2.jpg', '0.jpg']);
    expect(
      find.byKey(const Key('create-up-0')),
      findsNothing,
      reason: 'the first cannot go up',
    );
  });

  testWidgets(
    'publishing uploads, creates the post and hands its id to the caller',
    (tester) async {
      final c = await _open(tester);
      await tester.enterText(
        find.byKey(const Key('create-caption')),
        'Chiều muộn #chandung',
      );
      await _addPhotos(tester);
      await _pickService(tester);
      await _tap(tester, find.byKey(const Key('create-publish')));
      await tester.pumpAndSettle();
      expect(c.published, [c.publisher.published.single.id]);
      expect((c.uploader as FakeMediaUploader).uploaded, hasLength(3));
      expect(_state(tester).images, isEmpty, reason: 'the form is empty again');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('create-caption')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'a photo that fails shows a retry; retrying and publishing completes',
    (tester) async {
      final c = await _open(tester);
      (c.uploader as FakeMediaUploader).failNames.add('1.jpg');
      await _addPhotos(tester);
      await _pickService(tester);
      await _tap(tester, find.byKey(const Key('create-publish')));
      await tester.pumpAndSettle();
      expect(find.text('Không tải được ảnh. Thử lại nhé.'), findsWidgets);
      expect(find.byKey(const Key('create-retry-1')), findsOneWidget);
      expect(c.published, isEmpty);

      (c.uploader as FakeMediaUploader).failNames.clear();
      await _tap(tester, find.byKey(const Key('create-retry-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('create-retry-1')), findsNothing);
      await _tap(tester, find.byKey(const Key('create-publish')));
      await tester.pumpAndSettle();
      expect(c.published, hasLength(1));
    },
  );

  testWidgets('a failing create says so and can be tried again', (
    tester,
  ) async {
    final c = await _open(tester);
    await _addPhotos(tester);
    await _pickService(tester);
    c.publisher.failWith = StateError('offline');
    await _tap(tester, find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(
      find.text('Không đăng được bài. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(c.published, isEmpty);
    c.publisher.failWith = null;
    await _tap(tester, find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(c.published, hasLength(1));
  });

  testWidgets(
    'a photo shows its progress while it uploads, and the button spins',
    (tester) async {
      final slow = _SlowUploader();
      await _open(
        tester,
        create: _Create(
          picks: [
            [img(0)],
          ],
          uploader: slow,
        ),
      );
      await _addPhotos(tester);
      await _pickService(tester);
      await _tap(tester, find.byKey(const Key('create-publish')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Đang tải 40%'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(const Key('create-tile-0')),
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(bar.value, closeTo(0.4, 0.001));
      expect(
        find.byKey(const Key('create-remove-0')),
        findsNothing,
        reason: 'no edits while publishing',
      );
      slow.finish();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('style: choose one, then clear it', (tester) async {
    await _open(tester);
    await _tap(tester, find.byKey(const Key('create-style')));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Film'));
    await tester.pumpAndSettle();
    expect(_state(tester).styleId, 'film');
    await _tap(tester, find.byKey(const Key('create-style')));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Không chọn'));
    await tester.pumpAndSettle();
    expect(_state(tester).styleId, isNull);
  });

  testWidgets('the portfolio switch and the place are stored in the form', (
    tester,
  ) async {
    await _open(tester);
    await _tap(tester, find.byKey(const Key('create-portfolio')));
    await tester.enterText(
      find.byKey(const Key('create-location')),
      'Bến Bạch Đằng',
    );
    await tester.pump();
    expect(_state(tester).inPortfolio, isFalse);
    expect(_state(tester).locationName, 'Bến Bạch Đằng');
  });

  testWidgets('leaving the screen and coming back keeps what was typed', (
    tester,
  ) async {
    final c = _Create();
    await c.init();
    await tester.pumpWidget(
      screenApp(home: c.screen(), overrides: c.overrides),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create-caption')), 'Nháp');
    await tester.pump();
    await tester.pumpWidget(
      screenApp(home: const SizedBox(), overrides: c.overrides),
    );
    await tester.pumpWidget(
      screenApp(home: c.screen(), overrides: c.overrides),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('create-caption')))
          .controller!
          .text,
      'Nháp',
    );
  });

  for (final b in Brightness.values) {
    testWidgets(
      'fits 320x640 at 1.3x on ${b.name} with photos, errors and a sheet',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await _open(tester, textScale: 1.3, brightness: b);
        await _addPhotos(tester);
        expect(tester.takeException(), isNull);
        await _tap(tester, find.byKey(const Key('create-service')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byType(BackdropFilter).evaluate().length,
          lessThanOrEqualTo(1),
        );
      },
    );
  }
}

/// An upload that stops at 40 percent until [finish] is called.
class _SlowUploader implements MediaUploader {
  final _gate = Completer<void>();
  void finish() => _gate.complete();

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
  }) async* {
    yield const UploadEvent.progress(0.4);
    await _gate.future;
    yield UploadEvent.done(
      UploadedMedia(
        url: 'https://storage.test/$storagePath',
        storagePath: storagePath,
      ),
    );
  }

  @override
  Future<void> delete(String storagePath) async {}
}

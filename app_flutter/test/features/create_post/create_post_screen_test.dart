// test/features/create_post/create_post_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/create_post/post_composer.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import '../../support/content_fixtures.dart';
import '../../support/create_post_world.dart';

import 'package:photobooking/data/album/album.dart';

import '../../support/screen_host.dart';

const _uid = 'fake-1';

PickedImage img(int i) => PickedImage(path: '/tmp/none-$i.jpg', name: '$i.jpg');

/// A photographer with one package, ready to post.
class _Create {
  _Create({
    List<List<PickedImage>>? picks,
    this.withService = true,
    MediaUploader? uploader,
    Map<String, Object> prefsValues = const {},
    this.initialCaption,
    this.withEvents = false,
  }) : world = CreatePostWorld(prefsValues: prefsValues),
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
  final String? initialCaption;
  final bool withEvents;
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
    initialCaption: initialCaption,
    onOpenEvents: withEvents ? () {} : null,
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
    'an empty form: the plus tile, the fields, the album field, "Đăng" disabled',
    (tester) async {
      await _open(tester);
      expect(find.text('Đăng bài'), findsOneWidget);
      expect(find.byKey(const Key('create-add')), findsOneWidget);
      expect(find.byKey(const Key('create-caption')), findsOneWidget);
      expect(find.text('Gói dịch vụ · bắt buộc'), findsOneWidget);
      expect(find.byKey(const Key('create-portfolio')), findsNothing);
      expect(find.byKey(const Key('create-album')), findsOneWidget);
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

  testWidgets('the place is stored in the form', (tester) async {
    await _open(tester);
    await tester.enterText(
      find.byKey(const Key('create-location')),
      'Bến Bạch Đằng',
    );
    await tester.pump();
    expect(_state(tester).locationName, 'Bến Bạch Đằng');
  });

  group('the album field', () {
    Future<_Create> openWith(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
      bool albums = true,
    }) async {
      final c = _Create(prefsValues: prefs);
      await c.init();
      if (albums) {
        c.world.addAlbum('al1', title: 'Tác phẩm đạt giải', postCount: 9);
        c.world.addAlbum('al2', position: 2);
      }
      await tester.pumpWidget(
        screenApp(home: c.screen(), overrides: c.overrides),
      );
      await tester.pumpAndSettle();
      return c;
    }

    String fieldText(WidgetTester tester) => tester
        .widget<Semantics>(
          find
              .descendant(
                of: find.byKey(const Key('create-album')),
                matching: find.byType(Semantics),
              )
              .first,
        )
        .properties
        .label!;

    testWidgets('the album field replaces the portfolio switch', (
      tester,
    ) async {
      await openWith(tester);
      expect(find.byKey(const Key('create-portfolio')), findsNothing);
      expect(find.text('Album · tuỳ chọn'), findsOneWidget);
      expect(fieldText(tester), 'Album · tuỳ chọn, Không xếp album');
    });

    testWidgets('new draft preselects the last used album', (tester) async {
      await openWith(tester, prefs: {'lastAlbum:$_uid': 'al2'});
      expect(fieldText(tester), contains('Hà Giang 2025'));
    });

    testWidgets('a deleted last album falls back to none', (tester) async {
      final c = await openWith(tester, prefs: {'lastAlbum:$_uid': 'gone'});
      expect(fieldText(tester), contains('Không xếp album'));
      await _addPhotos(tester);
      await _pickService(tester);
      await _tap(tester, find.byKey(const Key('create-publish')));
      await tester.pumpAndSettle();
      expect(c.publisher.published.single.albumId, isNull);
    });

    testWidgets('choosing an album fills the field and closes the sheet', (
      tester,
    ) async {
      await openWith(tester);
      await _tap(tester, find.byKey(const Key('create-album')));
      await tester.pumpAndSettle();
      expect(find.text('Xếp vào album'), findsOneWidget);
      expect(find.text('Chỉ hiện ở Dòng thời gian'), findsOneWidget);
      expect(find.text('9 bài'), findsOneWidget);
      await tester.tap(find.byKey(const Key('album-pick-al1')));
      await tester.pumpAndSettle();
      expect(find.text('Xếp vào album'), findsNothing);
      expect(_state(tester).albumId, 'al1');
      expect(fieldText(tester), contains('Tác phẩm đạt giải'));
    });

    testWidgets('the last used album is marked in the sheet', (tester) async {
      await openWith(tester, prefs: {'lastAlbum:$_uid': 'al1'});
      await _tap(tester, find.byKey(const Key('create-album')));
      await tester.pumpAndSettle();
      expect(find.text('9 bài · dùng gần nhất'), findsOneWidget);
    });

    testWidgets('publishing sends albumId and remembers it', (tester) async {
      final c = await openWith(tester);
      await _tap(tester, find.byKey(const Key('create-album')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('album-pick-al1')));
      await tester.pumpAndSettle();
      await _addPhotos(tester);
      await _pickService(tester);
      await _tap(tester, find.byKey(const Key('create-publish')));
      await tester.pumpAndSettle();
      expect(c.publisher.published.single.albumId, 'al1');
      expect(c.world.prefs.getString('lastAlbum:${c.world.uid}'), 'al1');
    });

    testWidgets('publishing with none sends no albumId', (tester) async {
      final c = await openWith(tester);
      await _addPhotos(tester);
      await _pickService(tester);
      await _tap(tester, find.byKey(const Key('create-publish')));
      await tester.pumpAndSettle();
      expect(c.publisher.published.single.albumId, isNull);
    });

    testWidgets('Album mới creates an album and selects it', (tester) async {
      final c = await openWith(tester, albums: false);
      await _tap(tester, find.byKey(const Key('create-album')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('album-pick-new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('album-edit-title')),
        'Phố cổ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('album-edit-save')));
      await tester.pumpAndSettle();
      expect(c.world.albums.calls, ['create:Phố cổ']);
      expect(find.text('Xếp vào album'), findsNothing);
      expect(_state(tester).albumId, 'new1');
      expect(fieldText(tester), contains('Phố cổ'));
    });

    testWidgets('a duplicate name shows the error and keeps the prompt', (
      tester,
    ) async {
      final c = await openWith(tester, albums: false);
      c.world.albums.failWith = const AlbumError('conflict');
      await _tap(tester, find.byKey(const Key('create-album')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('album-pick-new')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('album-edit-title')), 'A');
      await tester.pump();
      await tester.tap(find.byKey(const Key('album-edit-save')));
      await tester.pumpAndSettle();
      expect(find.text('Bạn đã có album tên này'), findsOneWidget);
      expect(_state(tester).albumId, isNull);
    });
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

  testWidgets('a saved draft whose package is gone cannot be published and '
      'asks for a package', (tester) async {
    final c = _Create();
    await c.init();
    // The draft names s-gone; the photographer only has s1 now.
    c.world.prefs.setString(
      'postDraft:${c.world.uid}',
      '{"caption":"Hello","serviceId":"s-gone","specialtyId":"portrait"}',
    );
    await tester.pumpWidget(
      screenApp(home: c.screen(), overrides: c.overrides),
    );
    await tester.pumpAndSettle();
    await _addPhotos(tester);
    expect(_state(tester).serviceId, isNull);
    expect(_enabled(tester, 'create-publish'), isFalse);
    expect(find.text('Chọn gói dịch vụ cho bài đăng'), findsOneWidget);
  });

  group('S10.01 opened from an event timeline', () {
    String field(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const Key('create-caption')))
        .controller!
        .text;

    testWidgets('the caption starts with #Tag and a space', (tester) async {
      await _open(tester, create: _Create(initialCaption: '#PhotoWalk1020 '));
      expect(field(tester), '#PhotoWalk1020 ');
      expect(_state(tester).caption, '#PhotoWalk1020 ');
    });

    testWidgets('it goes in front of what was already typed', (tester) async {
      final c = _Create(
        initialCaption: '#PhotoWalk1020 ',
        prefsValues: {'postDraft:$_uid': '{"caption":"Hello"}'},
      );
      await _open(tester, create: c);
      expect(field(tester), '#PhotoWalk1020 Hello');
    });

    testWidgets('a caption that has the tag (any case) is left alone', (
      tester,
    ) async {
      final c = _Create(
        initialCaption: '#PhotoWalk1020 ',
        prefsValues: {'postDraft:$_uid': '{"caption":"Đẹp #photowalk1020"}'},
      );
      await _open(tester, create: c);
      expect(field(tester), 'Đẹp #photowalk1020');
    });

    testWidgets('/action?caption= prefills a photographer\'s post', (
      tester,
    ) async {
      final w = CreatePostWorld();
      await w.init();
      w.services.add(fixtureService('s1', photographerId: w.uid));
      final router = GoRouter(
        initialLocation: AppTab.action.path,
        routes: [
          GoRoute(
            path: AppTab.action.path,
            builder: (_, s) =>
                ActionTab(caption: s.uri.queryParameters['caption']),
          ),
          GoRoute(path: '/events/new', builder: (_, _) => const Text('events')),
        ],
      );
      await tester.pumpWidget(
        screenRouterApp(router: router, overrides: w.overrides),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('create-caption')))
            .controller!
            .text,
        '',
      );
      router.go(
        '${AppTab.action.path}?caption=${Uri.encodeQueryComponent('#Tag1 ')}',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('create-caption')))
            .controller!
            .text,
        '#Tag1 ',
      );
    });
  });

  group('S10.01 mock parity', () {
    testWidgets('S10.01 uses the tab-root title and has no back button', (
      tester,
    ) async {
      await _open(tester);
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.centerTitle, isFalse);
      expect(
        bar.titleTextStyle,
        tabRootTitleStyle(tester.element(find.byType(AppBar))),
      );
      expect(bar.leading, isNull);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('the order of fields matches the mock', (tester) async {
      await _open(tester, create: _Create(withEvents: true));
      await _addPhotos(tester);
      double top(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
      final order = [
        top('create-post-tabs'),
        top('create-add'),
        top('create-caption'),
        top('create-service'),
        top('create-location'),
        top('create-album'),
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i], greaterThan(order[i - 1]), reason: 'field $i');
      }
      expect(top('create-style'), top('create-location'));
      expect(
        tester.getTopLeft(find.byKey(const Key('create-style'))).dx,
        greaterThan(
          tester.getTopLeft(find.byKey(const Key('create-location'))).dx,
        ),
      );
    });

    testWidgets('the photo count reads "1 / 10 ảnh" after one photo', (
      tester,
    ) async {
      await _open(
        tester,
        create: _Create(
          picks: [
            [img(0)],
          ],
        ),
      );
      await _addPhotos(tester);
      expect(find.text('1 / 10 ảnh'), findsOneWidget);
    });
  });

  group('S10.01 Bài đăng / Sự kiện', () {
    testWidgets('S10.01 Sự kiện tab opens /events/new', (tester) async {
      final w = CreatePostWorld();
      await w.init();
      final router = GoRouter(
        initialLocation: AppTab.action.path,
        routes: [
          GoRoute(
            path: AppTab.action.path,
            builder: (_, _) => const ActionTab(),
          ),
          GoRoute(
            path: '/events/new',
            builder: (_, s) => Text('stub ${s.uri}'),
          ),
        ],
      );
      await tester.pumpWidget(
        screenRouterApp(router: router, overrides: w.overrides),
      );
      await tester.pumpAndSettle();

      final tabs = find.byKey(const Key('create-post-tabs'));
      expect(tabs, findsOneWidget);
      expect(
        find.descendant(of: tabs, matching: find.text('Bài đăng')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: tabs, matching: find.text('Sự kiện')),
      );
      await tester.pumpAndSettle();
      expect(find.text('stub /events/new'), findsOneWidget);
    });

    testWidgets('without an events entry the tabs are not shown', (
      tester,
    ) async {
      await _open(tester);
      expect(find.byKey(const Key('create-post-tabs')), findsNothing);
    });
  });
}

/// An upload that stops at 40 percent until [finish] is called.
class _SlowUploader implements MediaUploader {
  final _gate = Completer<void>();
  void finish() => _gate.complete();

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
    required ImagePurpose purpose,
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

// test/features/events/event_share_composer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

import '../../support/event_world.dart';

const _sw = Size(390, 1000);

PickedImage _img(String n) => PickedImage(path: '/tmp/$n.jpg', name: '$n.jpg');

Finder _byKey(String k) => find.byKey(Key(k));

EventsWorld _world({List<List<PickedImage>>? picks}) => EventsWorld(
  events: [detailOf('ev1', priceVnd: 0, hashtag: 'PhotoWalkPhoCo1020')],
  registrations: [registrationOf('r1', 'ev1')],
  pickerAnswers:
      picks ??
      [
        [_img('a'), _img('b')],
      ],
);

String _caption(WidgetTester tester) =>
    tester.widget<TextField>(_byKey('share-caption')).controller!.text;

void main() {
  group('event share composer', () {
    testWidgets(
      'the caption starts with the hashtag and Đăng waits for a photo',
      (tester) async {
        final w = _world();
        await w.pump(tester, path: '/e/ev1/share', size: _sw);
        expect(find.text('Chia sẻ ảnh sự kiện'), findsOneWidget);
        expect(_caption(tester), '#PhotoWalkPhoCo1020 ');
        expect(
          tester.widget<AppButton>(_byKey('share-send')).onPressed,
          isNull,
        );
      },
    );

    testWidgets('picked photos are counted and can be removed', (tester) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/share', size: _sw);
      await tester.tap(_byKey('share-add'));
      await settle(tester);
      expect(find.text('2 / 10 ảnh'), findsOneWidget);
      expect(_byKey('share-photo-1'), findsOneWidget);
      expect(w.picker.requestedMax.single, 10);
      await tester.tap(
        find.descendant(
          of: _byKey('share-photo-0'),
          matching: find.byType(IconButton),
        ),
      );
      await settle(tester);
      expect(find.text('1 / 10 ảnh'), findsOneWidget);
    });

    testWidgets('uploads, shares and goes back to the timeline', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/share', size: _sw);
      await tester.tap(_byKey('share-add'));
      await settle(tester);
      await tester.enterText(
        _byKey('share-caption'),
        '#PhotoWalkPhoCo1020 Sáng nay đẹp quá',
      );
      await tester.tap(_byKey('share-send'));
      await settle(tester);
      final share = w.timeline.shares.single;
      expect(share.eventId, 'ev1');
      expect(share.images, hasLength(2));
      expect(share.caption, '#PhotoWalkPhoCo1020 Sáng nay đẹp quá');
      expect(find.text('Đã đăng lên timeline'), findsOneWidget);
      expect(w.location, '/e/ev1/timeline');
    });

    testWidgets('a refused share stays, says why and cleans up', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/share', size: _sw);
      await tester.tap(_byKey('share-add'));
      await settle(tester);
      w.timeline.failWith = const EventError('not_eligible');
      await tester.tap(_byKey('share-send'));
      await settle(tester);
      expect(find.text('Timeline đã đóng đăng mới.'), findsOneWidget);
      expect(w.timeline.cleanedUp, 2);
      expect(w.location, '/e/ev1/share');
      // the photos are still there to try again
      expect(find.text('2 / 10 ảnh'), findsOneWidget);
      w.timeline.failWith = const EventError('network');
      await tester.tap(_byKey('share-send'));
      await settle(tester);
      expect(
        find.text('Không đăng được ảnh. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'leaving with photos asks to discard; keep stays, discard leaves',
      (tester) async {
        final w = _world();
        await w.pump(tester, path: '/e/ev1', size: _sw);
        w.router.push('/e/ev1/share');
        await settle(tester);
        await tester.tap(_byKey('share-add'));
        await settle(tester);
        await tester.tap(_byKey('share-back'));
        await settle(tester);
        expect(find.text('Bỏ bài đang soạn?'), findsOneWidget);
        await tester.tap(find.text('Tiếp tục soạn'));
        await settle(tester);
        expect(_byKey('share-caption'), findsOneWidget);
        await tester.tap(_byKey('share-back'));
        await settle(tester);
        await tester.tap(find.text('Bỏ'));
        await settle(tester);
        expect(_byKey('share-caption'), findsNothing);
        expect(w.timeline.shares, isEmpty); // nothing was uploaded or shared
      },
    );

    testWidgets('leaving an untouched form needs no question', (tester) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1', size: _sw);
      w.router.push('/e/ev1/share');
      await settle(tester);
      await tester.tap(_byKey('share-back'));
      await settle(tester);
      expect(find.text('Bỏ bài đang soạn?'), findsNothing);
      expect(_byKey('share-caption'), findsNothing);
    });

    testWidgets('fits 320dp at 1.3 text scale', (tester) async {
      final w = _world();
      await w.pump(
        tester,
        path: '/e/ev1/share',
        size: const Size(320, 700),
        textScale: 1.3,
      );
      await tester.tap(_byKey('share-add'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}

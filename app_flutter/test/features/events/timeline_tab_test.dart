// test/features/events/timeline_tab_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/event_world.dart';

const _sw = Size(390, 1400);

Finder _byKey(String k) => find.byKey(Key(k));

EventsWorld _world({
  String uid = 'u1',
  UserRole role = UserRole.customer,
  bool ticket = false,
  List<TimelineItem>? items,
  DateTime? completedAt,
  int postCount = 4,
}) {
  final ev = detailOf(
    'ev1',
    priceVnd: 0,
    hashtag: 'PhotoWalkPhoCo1020',
    postCount: postCount,
    completedAt: completedAt,
  );
  return EventsWorld(
    uid: uid,
    role: role,
    events: [ev],
    registrations: [if (ticket) registrationOf('r1', 'ev1', userId: uid)],
    timelineItems: {
      'ev1':
          items ??
          [
            timelineItemOf('p1', 'Lan Anh', minutesAgo: 1),
            timelineItemOf('p2', 'Minh Khoa', minutesAgo: 2),
            timelineItemOf('p3', 'Quốc Bảo', host: true, minutesAgo: 3),
            timelineItemOf('p4', 'Thảo Vy', minutesAgo: 4),
            timelineItemOf('w1', 'Chờ ai đó', status: TimelineStatus.pending),
          ],
    },
  );
}

void main() {
  group('S11.05 timeline', () {
    testWidgets('masonry shows author names and the host suffix', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(find.text('#PhotoWalkPhoCo1020'), findsOneWidget);
      expect(find.text('4 bài'), findsOneWidget);
      expect(find.text('Lan Anh'), findsOneWidget);
      expect(find.text('Minh Khoa'), findsOneWidget);
      expect(find.text('Thảo Vy'), findsOneWidget);
      expect(find.text('Quốc Bảo · chủ sự kiện'), findsOneWidget);
      expect(find.text('Chờ ai đó'), findsNothing); // pending stays hidden
      expect(
        find.byWidgetPredicate(
          (x) => x is ScreenCode && x.code == ScreenCodes.eventTimeline,
        ),
        findsOneWidget,
      );
      expect(w.timeline.pages.single.status, TimelineStatus.visible);
    });

    testWidgets('visitors see no Chờ duyệt tab', (tester) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(_byKey('timeline-tab-pending'), findsNothing);
      expect(find.textContaining('Chờ duyệt'), findsNothing);
    });

    testWidgets(
      'managers see the tab with its count and review the pending posts',
      (tester) async {
        final w = _world(uid: 'p1', role: UserRole.photographer);
        await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
        expect(find.text('Chờ duyệt · 1'), findsOneWidget);
        await tester.tap(_byKey('timeline-tab-pending'));
        await settle(tester);
        expect(find.text('Chờ ai đó'), findsOneWidget);
        expect(find.text('Lan Anh'), findsNothing);
        expect(w.timeline.pages.last.status, TimelineStatus.pending);
      },
    );

    testWidgets('review=1 opens on Chờ duyệt', (tester) async {
      final w = _world(uid: 'p1', role: UserRole.photographer);
      await w.pump(tester, path: '/e/ev1/timeline?review=1', size: _sw);
      expect(find.text('Chờ ai đó'), findsOneWidget);
      expect(find.text('Lan Anh'), findsNothing);
    });

    testWidgets('managers approve from the long-press menu', (tester) async {
      final w = _world(uid: 'p1', role: UserRole.photographer);
      await w.pump(tester, path: '/e/ev1/timeline?review=1', size: _sw);
      await tester.longPress(_byKey('timeline-item-w1'));
      await settle(tester);
      expect(_byKey('timeline-hide'), findsNothing);
      await tester.tap(_byKey('timeline-approve'));
      await settle(tester);
      expect(w.timeline.moderated.single.action, TimelineAction.approve);
      expect(w.timeline.moderated.single.postId, 'w1');
      expect(find.text('Chờ ai đó'), findsNothing);
      expect(find.text('Chờ duyệt · 0'), findsOneWidget);
    });

    testWidgets('managers hide a visible post from the menu', (tester) async {
      final w = _world(uid: 'p1', role: UserRole.photographer);
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      await tester.longPress(_byKey('timeline-item-p2'));
      await settle(tester);
      expect(find.text('Ẩn khỏi timeline'), findsOneWidget);
      expect(_byKey('timeline-approve'), findsNothing);
      await tester.tap(_byKey('timeline-hide'));
      await settle(tester);
      expect(w.timeline.moderated.single.action, TimelineAction.hide);
      expect(find.text('Minh Khoa'), findsNothing);
    });

    testWidgets('everyone can long-press, Báo cáo opens report sheet for others posts', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      await tester.longPress(_byKey('timeline-item-p1'));
      await settle(tester);
      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Sắp có'), findsNothing);
      expect(find.text('Duyệt'), findsNothing);
      expect(find.text('Ẩn khỏi timeline'), findsNothing);
      await tester.tap(find.text('Báo cáo'));
      await settle(tester);
      expect(find.text('Báo cáo bài viết'), findsOneWidget);
    });

    testWidgets('a failed moderation says so and keeps the row', (
      tester,
    ) async {
      final w = _world(uid: 'p1', role: UserRole.photographer);
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      w.timeline.failWith = StateError('no');
      await tester.longPress(_byKey('timeline-item-p2'));
      await settle(tester);
      await tester.tap(_byKey('timeline-hide'));
      await settle(tester);
      expect(find.text('Không thực hiện được. Thử lại nhé.'), findsOneWidget);
      expect(find.text('Minh Khoa'), findsOneWidget);
    });

    testWidgets('tapping a photo opens its post', (tester) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      await tester.tap(_byKey('timeline-item-p3'));
      await settle(tester);
      expect(w.location, '/p/p3');
    });

    testWidgets('the empty timeline invites the first photo', (tester) async {
      final w = _world(items: const [], postCount: 0, ticket: true);
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(
        find.text('Chưa có ảnh nào. Hãy là người đầu tiên chia sẻ!'),
        findsOneWidget,
      );
      expect(_byKey('timeline-post'), findsOneWidget);
    });

    testWidgets('pages of 20; the next page loads near the end of the scroll', (
      tester,
    ) async {
      final items = [
        for (var i = 0; i < 25; i++)
          timelineItemOf('q$i', 'Tác giả $i', minutesAgo: i),
      ];
      final w = _world(items: items);
      await w.pump(tester, path: '/e/ev1/timeline', size: const Size(390, 844));
      expect(w.timeline.pages.map((p) => p.cursor), [null]);
      expect(_byKey('timeline-more'), findsNothing); // the mock has no button
      await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
      await settle(tester);
      expect(w.timeline.pages.map((p) => p.cursor), [null, 'q19']);
      await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
      await settle(tester);
      expect(_byKey('timeline-item-q24'), findsOneWidget);
      // The last page has no cursor: nothing more is asked.
      expect(w.timeline.pages, hasLength(2));
    });

    testWidgets('a first page that does not fill the screen loads the next', (
      tester,
    ) async {
      final items = [
        for (var i = 0; i < 25; i++)
          timelineItemOf('q$i', 'Tác giả $i', minutesAgo: i),
      ];
      final w = _world(items: items);
      await w.pump(
        tester,
        path: '/e/ev1/timeline',
        size: const Size(390, 9000),
      );
      await settle(tester);
      expect(w.timeline.pages.map((p) => p.cursor), [null, 'q19']);
      expect(_byKey('timeline-item-q24'), findsOneWidget);
    });

    testWidgets('pull to refresh loads the first page again', (tester) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      final before = w.timeline.pages.length;
      w.timeline.put('ev1', [timelineItemOf('n1', 'Người mới')]);
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 400),
        1000,
      );
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(w.timeline.pages.length, greaterThan(before));
      expect(find.text('Người mới'), findsOneWidget);
    });

    testWidgets('a load error offers Thử lại', (tester) async {
      final w = _world();
      w.timeline.failWith = StateError('offline');
      w.timeline.failOnce = true;
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await settle(tester);
      expect(find.text('Lan Anh'), findsOneWidget);
    });

    testWidgets('fits 320dp at 1.3 text scale', (tester) async {
      final w = _world(uid: 'p1', role: UserRole.photographer);
      await w.pump(
        tester,
        path: '/e/ev1/timeline',
        size: const Size(320, 900),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Quốc Bảo · chủ sự kiện'), findsOneWidget);
    });
  });

  group('S11.05 bottom bar', () {
    testWidgets('a visitor sees the join bar, not the post button', (
      tester,
    ) async {
      final w = _world();
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(_byKey('timeline-post'), findsNothing);
      expect(_byKey('event-join'), findsOneWidget);
    });

    testWidgets('a paid attendee sees Đăng ảnh với #Tag', (tester) async {
      final w = _world(ticket: true);
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(find.text('Đăng ảnh với #PhotoWalkPhoCo1020'), findsOneWidget);
      expect(_byKey('event-join'), findsNothing);
    });

    testWidgets('a manager without the photographer role gets the share form', (
      tester,
    ) async {
      final w = _world(uid: 'p1');
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(_byKey('timeline-post'), findsOneWidget);
      await tester.tap(_byKey('timeline-post'));
      await settle(tester);
      expect(_byKey('share-caption'), findsOneWidget);
    });

    testWidgets('an attendee opens the share composer', (tester) async {
      final w = _world(ticket: true);
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      await tester.tap(_byKey('timeline-post'));
      await settle(tester);
      expect(_byKey('share-caption'), findsOneWidget);
    });

    testWidgets('photographers open S10.01 with the hashtag', (tester) async {
      final w = _world(role: UserRole.photographer);
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      await tester.tap(_byKey('timeline-post'));
      await settle(tester);
      final uri = Uri.parse(w.location);
      expect(uri.path, '/action');
      expect(uri.queryParameters['caption'], '#PhotoWalkPhoCo1020 ');
    });

    testWidgets('after 30 days the button becomes the closed note', (
      tester,
    ) async {
      final w = _world(
        ticket: true,
        completedAt: eventNow.subtract(const Duration(days: 31)),
      );
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(_byKey('timeline-post'), findsNothing);
      expect(find.text('Timeline đã đóng đăng mới'), findsOneWidget);
    });

    testWidgets('on day 30 the button is still there', (tester) async {
      final w = _world(
        ticket: true,
        completedAt: eventNow.subtract(const Duration(days: 30)),
      );
      await w.pump(tester, path: '/e/ev1/timeline', size: _sw);
      expect(_byKey('timeline-post'), findsOneWidget);
    });
  });
}

// test/features/photographer_profile/photographer_profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/content_fixtures.dart';
import '../../support/profile_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<ProfileWorld> _world(
  WidgetTester tester, {
  UserRole role = UserRole.customer,
  bool hasPhone = true,
  double width = 390,
}) async {
  usePhoneFor(tester, width: width, height: width < 390 ? 640 : 1400);
  final w = ProfileWorld(role: role, hasPhone: hasPhone);
  await w.init();
  return w;
}

Finder get _page => find.byType(Scrollable).first;

/// Scrolls the tabs into the middle, clear of the app bar and footer bar (slivers below are not built).
Future<void> _toTabs(WidgetTester tester) async {
  final tabs = find.byKey(const Key('profile-tabs'));
  await tester.scrollUntilVisible(tabs, 200, scrollable: _page);
  for (var i = 0; i < 5; i++) {
    final top = tester.getTopLeft(tabs).dy;
    if (top > 100 && top < 400) {
      break;
    }
    await tester.drag(_page, Offset(0, (250 - top).clamp(-100, 100)));
    await tester.pumpAndSettle();
  }
}

bool _enabled(WidgetTester tester, String key) =>
    tester
        .widget<FilledButton>(
          find.descendant(of: _key(key), matching: find.byType(FilledButton)),
        )
        .onPressed !=
    null;

void main() {
  testWidgets(
    'a visitor sees who, how good and from how much; no phone anywhere',
    (tester) async {
      final w = await _world(tester);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      expect(find.byType(VerifiedMark), findsOneWidget);
      expect(find.textContaining('Minh Trí'), findsWidgets);
      expect(find.text('Chân dung · Cưới · Quận 3'), findsOneWidget);
      for (final t in ['4,9', '58 đánh giá', '112', '~1 giờ', '6 năm']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text(profileBio), findsOneWidget);
      expect(find.text('Chân dung · Chuyên sâu'), findsOneWidget);
      expect(find.text('Cưới · Thành thạo'), findsOneWidget);
      expect(find.text('Thiết bị: Sony A7 IV'), findsOneWidget);
      expect(find.text('Đặt lịch · từ 1,5M'), findsOneWidget);
      expect(find.textContaining(RegExp(r'\+84|0\d{9}')), findsNothing);
      expect(_key('profile-edit'), findsNothing);
      expect(
        find.byType(CompletenessMeter),
        findsNothing,
        reason: 'only the owner sees it',
      );
    },
  );

  testWidgets('"Đặt lịch" books, or asks for a phone number first', (
    tester,
  ) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('profile-book'));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/p1/book'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    final noPhone = await _world(tester, hasPhone: false);
    await tester.pumpWidget(noPhone.app('/u/p1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('profile-book'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('stub /profile/phone?returnTo='),
      findsOneWidget,
    );
  });

  testWidgets('the chat button opens the inquiry and nothing else', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Nhắn tin hỏi trước'), findsOneWidget);
    for (final channel in ['Gọi', 'Zalo', 'WhatsApp']) {
      expect(find.text(channel), findsNothing);
    }
    await tester.tap(find.byType(ContactDial));
    await tester.pumpAndSettle();
    expect(find.text('stub /u/p1/ask'), findsOneWidget);
    h.dispose();
  });

  testWidgets(
    'tabs: packages book with the package, calendar is read-only, reviews are empty',
    (tester) async {
      final h = tester.ensureSemantics();
      final w = await _world(tester);
      w.availability.seed(
        'p1',
        AvailabilityDay(
          day: DateTime.utc(2026, 10, 10),
          state: DayState.booked,
        ),
      );
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gói'));
      await tester.pumpAndSettle();
      expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
      expect(find.text('3.200.000₫'), findsOneWidget);
      expect(
        find.text('Gói cũ'),
        findsNothing,
        reason: 'hidden packages are not offered',
      );
      await tester.ensureVisible(_key('service-s2'));
      await tester.tap(_key('service-s2'));
      await tester.pumpAndSettle();
      expect(find.text('stub /u/p1/book?serviceId=s2'), findsOneWidget);

      await tester.pumpWidget(w.app('/u/p1?tab=calendar'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 10, 2026'), findsOneWidget);
      expect(find.bySemanticsLabel('10 tháng 10, đã đặt'), findsOneWidget);
      expect(w.availability.watchers, 1);

      await tester.tap(find.text('Đánh giá'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có đánh giá'), findsOneWidget);
      expect(
        w.availability.watchers,
        0,
        reason: 'leaving the calendar tab closes its listener',
      );
      h.dispose();
    },
  );

  testWidgets('?tab=services opens the packages tab', (tester) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1?tab=services'));
    await tester.pumpAndSettle();
    expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
  });

  testWidgets('the portfolio marks evidence photos and opens a post', (
    tester,
  ) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _key('portfolio-a'),
      200,
      scrollable: _page,
    );
    expect(
      find.descendant(
        of: _key('portfolio-a'),
        matching: find.byIcon(Icons.workspace_premium_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('portfolio-e'),
        matching: find.byIcon(Icons.workspace_premium_outlined),
      ),
      findsNothing,
    );
    await tester.tap(_key('portfolio-a'));
    await tester.pumpAndSettle();
    expect(find.text('stub /p/a'), findsOneWidget);
  });

  testWidgets('"Xem thêm ảnh" loads the next page', (tester) async {
    final w = await _world(tester);
    for (var i = 0; i < 25; i++) {
      w.discovery.posts.add(
        fixturePost(
          'm$i',
          photographerId: 'p9',
          age: Duration(minutes: i + 1),
        ),
      );
    }
    w.profiles.add(
      PhotographerProfile(
        summary: fixturePhotographer('p9', name: 'Thu Hà'),
        intro: const PhotographerIntro(onboardingComplete: true),
      ),
    );
    await tester.pumpWidget(w.app('/u/p9'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _key('portfolio-more'),
      400,
      scrollable: _page,
    );
    await tester.tap(_key('portfolio-more'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _key('portfolio-m24'),
      400,
      scrollable: _page,
    );
    expect(_key('portfolio-m24'), findsOneWidget);
    expect(_key('portfolio-more'), findsNothing);
  });

  testWidgets('without packages the booking button waits and says why', (
    tester,
  ) async {
    final w = await _world(tester);
    w.profiles.add(
      PhotographerProfile(
        summary: fixturePhotographer('p9', name: 'Thu Hà'),
        intro: const PhotographerIntro(onboardingComplete: true),
      ),
    );
    await tester.pumpWidget(w.app('/u/p9'));
    await tester.pumpAndSettle();
    expect(find.text('Nhiếp ảnh gia chưa đăng gói'), findsOneWidget);
    expect(_enabled(tester, 'profile-book'), isFalse);
    expect(find.text('Đặt lịch'), findsOneWidget);
  });

  testWidgets(
    'the blue check only for verified photographers; follow toggles',
    (tester) async {
      final w = await _world(tester);
      await tester.pumpWidget(w.app('/u/p2'));
      await tester.pumpAndSettle();
      expect(find.byType(VerifiedMark), findsNothing);
      await tester.tap(_key('profile-follow'));
      await tester.pumpAndSettle();
      expect(find.text('Đang theo dõi'), findsOneWidget);
    },
  );

  testWidgets('unpublished, unknown and failing profiles each say so', (
    tester,
  ) async {
    final w = await _world(tester);
    w.profiles.add(
      PhotographerProfile(
        summary: fixturePhotographer('p8', name: 'Ẩn'),
        intro: const PhotographerIntro(),
      ),
    );
    await tester.pumpWidget(w.app('/u/p8'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ này chưa sẵn sàng'), findsOneWidget);

    await tester.pumpWidget(w.app('/u/nobody'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy hồ sơ.'), findsOneWidget);

    w.profiles.failWith = StateError('offline');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được hồ sơ.'), findsOneWidget);
    w.profiles.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.text(profileBio), findsOneWidget);
  });

  testWidgets('the owner edits instead of booking, even before publishing', (
    tester,
  ) async {
    final w = await _world(tester, role: UserRole.photographer);
    w.profiles.add(
      PhotographerProfile(
        summary: fixturePhotographer(w.uid, name: 'Lan Anh'),
        intro: const PhotographerIntro(),
      ),
    );
    await tester.pumpWidget(w.app('/u/${w.uid}'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ này chưa sẵn sàng'), findsNothing);
    expect(_key('profile-book'), findsNothing);
    expect(_key('profile-follow'), findsNothing);
    expect(find.byType(ContactDial), findsNothing);
    expect(find.byType(CompletenessMeter), findsOneWidget);
    final loadsBefore = w.profiles.loads;
    await tester.tap(_key('profile-edit'));
    await tester.pumpAndSettle();
    await tester.tap(_key('edit-skills'));
    await tester.pumpAndSettle();
    expect(find.text('stub /profile/skills'), findsOneWidget);
    w.router.pop();
    await tester.pumpAndSettle();
    expect(
      w.profiles.loads,
      greaterThan(loadsBefore),
      reason: 'coming back reloads the profile',
    );
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      final w = await _world(tester, width: 320);
      await tester.pumpWidget(w.app('/u/p1', brightness: b, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _toTabs(tester);
      await tester.tap(find.text('Gói'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _toTabs(tester);
      await tester.tap(find.text('Lịch'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

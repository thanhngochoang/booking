// test/features/photographer_profile/photographer_profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
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
  List<PhotographerSummary>? photographers,
}) async {
  usePhoneFor(tester, width: width, height: width < 390 ? 640 : 1400);
  final w = ProfileWorld(
    role: role,
    hasPhone: hasPhone,
    photographers: photographers,
  );
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
  testWidgets('artist profile shows the gold mark and the Nhiếp ảnh gia tag', (
    tester,
  ) async {
    final w = await _world(
      tester,
      photographers: [
        fixturePhotographer(
          'p1',
          name: 'Lê Hoàng Vũ',
          verified: true,
          providerType: ProviderType.artist,
          approvedAwards: 7,
        ),
      ],
    );
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(find.byType(VerifiedMark), findsNothing);
    expect(
      tester.widget<ProviderMark>(find.byType(ProviderMark)).kind,
      ProviderMarkKind.artist,
    );
    expect(_key('profile-provider-tag'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('profile-provider-tag'),
        matching: find.text('Nhiếp ảnh gia'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('studio profile shows the Studio tag and district', (
    tester,
  ) async {
    final w = await _world(
      tester,
      photographers: [
        fixturePhotographer(
          'p1',
          name: 'Cúc Studio',
          providerType: ProviderType.studio,
          studioDistrict: 'Quận 3',
          areaLabel: 'TP.HCM',
        ),
      ],
    );
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _key('profile-provider-tag'),
        matching: find.text('Studio'),
      ),
      findsOneWidget,
    );
    expect(find.text('Chân dung · Cưới · Quận 3'), findsOneWidget);
    expect(find.byType(VerifiedMark), findsNothing);
  });

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

  testWidgets(
    'a failed read shows "Thử lại" at once, with the default retry on',
    (tester) async {
      final w = await _world(tester);
      w.profiles.failWith = StateError('offline');
      await tester.pumpWidget(w.app('/u/p1', defaultRetry: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Không tải được hồ sơ.'), findsOneWidget);
      expect(find.byKey(const Key('error-retry')), findsOneWidget);
      expect(w.profiles.loads, 1, reason: 'no hidden retries');
    },
  );

  group('Portfolio toggle (Album / Dòng thời gian)', () {
    double offset(WidgetTester tester) =>
        tester.state<ScrollableState>(_page).position.pixels;

    /// Scrolls until the toggle sits clear of the app bar and footer bar.
    Future<void> toToggle(WidgetTester tester) async {
      final toggle = find.byType(PortfolioViewToggle);
      for (var i = 0; i < 12; i++) {
        if (toggle.evaluate().isNotEmpty) {
          final top = tester.getTopLeft(toggle).dy;
          if (top > 120 && top < 420) {
            return;
          }
        }
        await tester.drag(_page, const Offset(0, -100));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    PortfolioView shown(WidgetTester tester) => tester
        .widget<PortfolioViewToggle>(find.byType(PortfolioViewToggle))
        .value;

    void twoAlbums(ProfileWorld w) {
      w.albums
        ..add(
          fixtureAlbum(
            'al1',
            title: 'Tác phẩm đạt giải',
            position: 1,
            mediaCount: 12,
            coverUrl: 'https://img.test/al1.jpg',
          ),
        )
        ..add(
          fixtureAlbum(
            'al2',
            title: 'Hà Giang 2025',
            position: 2,
            mediaCount: 18,
          ),
        );
    }

    testWidgets('no visible album hides the toggle and shows the timeline', (
      tester,
    ) async {
      final w = await _world(tester);
      w.albums.add(fixtureAlbum('empty', visible: false, postCount: 0));
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        _key('portfolio-a'),
        200,
        scrollable: _page,
      );
      expect(find.byType(PortfolioViewToggle), findsNothing);
      expect(_key('portfolio-a'), findsOneWidget);
      expect(_key('portfolio-arrange'), findsNothing);
    });

    testWidgets('with albums the toggle defaults to Albums', (tester) async {
      final w = await _world(tester);
      twoAlbums(w);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await toToggle(tester);
      expect(shown(tester), PortfolioView.albums);
      expect(find.text('2 album'), findsOneWidget);
      expect(_key('album-al2'), findsOneWidget);
      expect(_key('portfolio-a'), findsNothing);
    });

    testWidgets('the first album is featured, the others are not', (
      tester,
    ) async {
      final w = await _world(tester);
      twoAlbums(w);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await toToggle(tester);
      expect(tester.widget<AlbumTile>(_key('album-al1')).featured, isTrue);
      expect(tester.widget<AlbumTile>(_key('album-al2')).featured, isFalse);
    });

    testWidgets('an album opens its detail page', (tester) async {
      final w = await _world(tester);
      twoAlbums(w);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await toToggle(tester);
      await tester.tap(_key('album-al2'));
      await tester.pumpAndSettle();
      expect(w.router.state.uri.path, '/u/p1/albums/al2');
      expect(find.text('Hà Giang 2025'), findsWidgets);
    });

    testWidgets('switching views keeps each scroll position', (tester) async {
      final w = await _world(tester, width: 360);
      twoAlbums(w);
      for (var i = 0; i < 12; i++) {
        w.discovery.posts.add(
          fixturePost('t$i', age: Duration(minutes: 10 + i)),
        );
      }
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await toToggle(tester);
      await tester.drag(_page, const Offset(0, -40));
      await tester.pumpAndSettle();
      final albumsAt = offset(tester);

      await tester.tap(find.text('Dòng thời gian'));
      await tester.pumpAndSettle();
      expect(_key('portfolio-t0'), findsOneWidget);
      await tester.drag(_page, const Offset(0, 30));
      await tester.pumpAndSettle();
      final timelineAt = offset(tester);
      expect(timelineAt, isNot(closeTo(albumsAt, 1)));

      await tester.tap(find.text('Album'));
      await tester.pumpAndSettle();
      expect(shown(tester), PortfolioView.albums);
      expect(offset(tester), closeTo(albumsAt, 1));

      await tester.tap(find.text('Dòng thời gian'));
      await tester.pumpAndSettle();
      expect(offset(tester), closeTo(timelineAt, 1));
    });

    testWidgets('the choice is kept when the tab is left and reopened', (
      tester,
    ) async {
      final w = await _world(tester);
      twoAlbums(w);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await toToggle(tester);
      await tester.tap(find.text('Dòng thời gian'));
      await tester.pumpAndSettle();
      await _toTabs(tester);
      await tester.tap(find.text('Gói'));
      await tester.pumpAndSettle();
      await _toTabs(tester);
      await tester.tap(find.text('Portfolio'));
      await tester.pumpAndSettle();
      await toToggle(tester);
      expect(shown(tester), PortfolioView.timeline);
    });

    testWidgets('the owner sees Sắp xếp and it opens /me/albums', (
      tester,
    ) async {
      final w = await _world(tester, role: UserRole.photographer);
      w.profiles.add(
        PhotographerProfile(
          summary: fixturePhotographer(w.uid, name: 'Lan Anh'),
          intro: const PhotographerIntro(onboardingComplete: true),
        ),
      );
      w.albums.add(fixtureAlbum('mine', photographerId: w.uid));
      await tester.pumpWidget(w.app('/u/${w.uid}'));
      await tester.pumpAndSettle();
      await toToggle(tester);
      expect(find.text('Sắp xếp'), findsOneWidget);
      await tester.tap(_key('portfolio-arrange'));
      await tester.pumpAndSettle();
      expect(find.text('stub /me/albums'), findsOneWidget);
    });

    testWidgets('a visitor does not see Sắp xếp', (tester) async {
      final w = await _world(tester);
      twoAlbums(w);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await toToggle(tester);
      expect(find.text('Sắp xếp'), findsNothing);
    });

    for (final b in Brightness.values) {
      testWidgets('album view fits 320dp at 1.3x text (${b.name})', (
        tester,
      ) async {
        final w = await _world(tester, width: 320, role: UserRole.photographer);
        w.profiles.add(
          PhotographerProfile(
            summary: fixturePhotographer(w.uid, name: 'Lan Anh'),
            intro: const PhotographerIntro(onboardingComplete: true),
          ),
        );
        w.albums
          ..add(
            fixtureAlbum(
              'x1',
              photographerId: w.uid,
              title: 'Một tên album rất dài để thử xuống dòng trên màn hẹp',
            ),
          )
          ..add(fixtureAlbum('x2', photographerId: w.uid, position: 2))
          ..add(fixtureAlbum('x3', photographerId: w.uid, position: 3));
        await tester.pumpWidget(
          w.app('/u/${w.uid}', brightness: b, textScale: 1.3),
        );
        await tester.pumpAndSettle();
        await toToggle(tester);
        await tester.drag(_page, const Offset(0, -120));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

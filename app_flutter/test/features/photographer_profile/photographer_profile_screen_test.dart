// test/features/photographer_profile/photographer_profile_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_bottom_bar.dart';

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

  Finder tile() => _key('profile-stat-reviews');

  testWidgets('the tile shows 97% with the tomato icon and "58 đánh giá"', (
    tester,
  ) async {
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: tile(), matching: find.text('97%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile(), matching: find.text('58 đánh giá')),
      findsOneWidget,
    );
    final icon = tester.widget<VerdictIcon>(
      find.descendant(of: tile(), matching: find.byType(VerdictIcon)),
    );
    expect(icon.kind, VerdictKind.tomato);
    expect(icon.color, isNull, reason: 'tomato colour on the icon only');
  });

  testWidgets('the tile reads "97% cà chua, 58 đánh giá"', (tester) async {
    final handle = tester.ensureSemantics();
    final w = await _world(tester);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('97% cà chua, 58 đánh giá'), findsOneWidget);
    expect(find.bySemanticsLabel('97%, 58 đánh giá'), findsNothing);
    handle.dispose();
  });

  testWidgets('under 5 reviews the tile shows "Mới" and "3 đánh giá"', (
    tester,
  ) async {
    final w = await _world(
      tester,
      photographers: [fixturePhotographer('p1', tomatoCount: 3)],
    );
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: tile(), matching: find.text('Mới')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile(), matching: find.text('3 đánh giá')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile(), matching: find.byType(VerdictIcon)),
      findsNothing,
    );
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('no reviews shows "Mới" and "0 đánh giá"', (tester) async {
    final w = await _world(tester, photographers: [fixturePhotographer('p1')]);
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: tile(), matching: find.text('Mới')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile(), matching: find.text('0 đánh giá')),
      findsOneWidget,
    );
    expect(find.text('—'), findsNothing);
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
      for (final t in ['97%', '58 đánh giá', '112', '~1 giờ', '6 năm']) {
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
        matching: find.byIcon(AppIcons.award),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('portfolio-e'),
        matching: find.byIcon(AppIcons.award),
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

    testWidgets('top bar shows save and more actions for visitors; owner sees more only', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final w = await _world(tester);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      expect(_key('profile-save'), findsOneWidget);
      expect(_key('profile-more'), findsOneWidget);

      await tester.tap(_key('profile-more'));
      await tester.pump();
      expect(copied, '/u/p1');
      expect(find.text('Đã sao chép liên kết hồ sơ'), findsOneWidget);
    });

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
    expect(_key('profile-save'), findsNothing);
    expect(_key('profile-more'), findsOneWidget);
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

  group('awards on S03.01', () {
    PhotographerSummary artist() => fixturePhotographer(
      'p1',
      name: 'Lê Hoàng Vũ',
      verified: true,
      providerType: ProviderType.artist,
      approvedAwards: 7,
    );

    void seed(ProfileWorld w, int n) {
      for (var i = 0; i < n; i++) {
        w.awards.add(
          fixtureAward(
            'a$i',
            year: 2020 + i,
            result: i.isEven ? AwardResult.gold : AwardResult.finalist,
            competition: 'VIPA',
            category: 'Phong cảnh',
            createdAt: fixtureNow.add(Duration(days: i)),
          ),
        );
      }
    }

    testWidgets('an artist shows the giải thưởng stat instead of phản hồi', (
      tester,
    ) async {
      final w = await _world(tester, photographers: [artist()]);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      expect(find.text('giải thưởng'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('phản hồi'), findsNothing);
      expect(find.text('buổi chụp'), findsOneWidget);
      expect(find.text('kinh nghiệm'), findsOneWidget);
    });

    testWidgets('an artist shows the awards strip above the bio', (
      tester,
    ) async {
      final w = await _world(tester, photographers: [artist()]);
      seed(w, 3);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      expect(find.byType(AwardChip), findsNWidgets(2));
      expect(
        tester.getTopLeft(_key('profile-awards-strip')).dy,
        lessThan(tester.getTopLeft(find.text(profileBio)).dy),
      );
      // Newest first: 2022 gold before 2021.
      expect(find.text('VIPA 2022 · Phong cảnh'), findsOneWidget);
      expect(find.text('VIPA 2021 · Phong cảnh'), findsOneWidget);
      expect(find.text('VIPA 2020 · Phong cảnh'), findsNothing);
    });

    testWidgets('the strip opens the full list read-only', (tester) async {
      final w = await _world(tester, photographers: [artist()]);
      seed(w, 3);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AwardChip).first);
      await tester.pumpAndSettle();
      expect(_key('profile-awards-sheet'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('profile-awards-sheet'),
          matching: find.byType(AwardRow),
        ),
        findsNWidgets(3),
      );
      expect(_key('award_status_badge'), findsNothing);
      expect(find.text('Giải thưởng'), findsOneWidget);
    });

    testWidgets('an individual with approved awards shows the strip below the '
        'bio and keeps phản hồi', (tester) async {
      final w = await _world(tester);
      w.awards.add(fixtureAward('a1', competition: 'VIPA', year: 2024));
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      expect(find.byType(AwardChip), findsOneWidget);
      expect(
        tester.getTopLeft(_key('profile-awards-strip')).dy,
        greaterThan(tester.getTopLeft(find.text(profileBio)).dy),
      );
      expect(find.text('phản hồi'), findsOneWidget);
      expect(find.text('giải thưởng'), findsNothing);
    });

    testWidgets('no approved awards: no strip', (tester) async {
      final w = await _world(tester, photographers: [artist()]);
      w.awards.add(
        fixtureAward('a1', status: AwardStatus.pending, competition: 'VIPA'),
      );
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      expect(find.byType(AwardChip), findsNothing);
      expect(_key('profile-awards-strip'), findsNothing);
    });

    testWidgets('the strip loads with chip skeletons', (tester) async {
      final w = await _world(tester, photographers: [artist()]);
      w.awards = _NeverAwards();
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(_key('profile-awards-skeleton'), findsOneWidget);
      expect(find.byType(AwardChip), findsNWidgets(2));
      expect(find.text('Giải thưởng'), findsNothing);
    });

    for (final b in Brightness.values) {
      testWidgets(
        'artist header and strip fit 320dp at 1.3x text (${b.name})',
        (tester) async {
          final w = await _world(tester, width: 320, photographers: [artist()]);
          seed(w, 3);
          await tester.pumpWidget(
            w.app('/u/p1', brightness: b, textScale: 1.3),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AwardChip), findsNWidgets(2));
          expect(_key('profile-awards-more'), findsOneWidget);
          await tester.drag(_page, const Offset(0, -150));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('orders closed (S03.01-new)', () {
    const note =
        'Bảo Ngọc chưa mở nhận đơn nên chưa đặt lịch hay xin báo giá được. '
        'Bạn vẫn nhắn hỏi được.';

    PhotographerSummary closed({
      String id = 'p1',
      ProviderType type = ProviderType.individual,
    }) => fixturePhotographer(
      id,
      name: 'Bảo Ngọc',
      verified: false,
      acceptingOrders: false,
      providerType: type,
      studioDistrict: type == ProviderType.studio ? 'Quận 10' : null,
    );

    Finder inBar(Finder f) =>
        find.descendant(of: find.byType(ProfileBottomBar), matching: f);

    testWidgets(
      'a closed provider shows the dashed tag "Chưa nhận đơn" under the name and no verified mark',
      (tester) async {
        final w = await _world(tester, photographers: [closed()]);
        await tester.pumpWidget(w.app('/u/p1'));
        await tester.pumpAndSettle();
        expect(find.byType(OrdersClosedTag), findsOneWidget);
        expect(find.text('Chưa nhận đơn'), findsOneWidget);
        expect(find.byType(VerifiedMark), findsNothing);
        expect(find.byType(ProviderMark), findsNothing);
        final name = tester.getRect(find.text('Bảo Ngọc', findRichText: true));
        final tag = tester.getRect(find.byType(OrdersClosedTag));
        expect(tag.top, greaterThanOrEqualTo(name.bottom - 1));
        expect(tag.left, closeTo(name.left, 1));
        expect(_key('profile-follow'), findsOneWidget);
      },
    );

    testWidgets(
      'a closed studio shows the Studio tag first, then the closed tag',
      (tester) async {
        final w = await _world(
          tester,
          photographers: [closed(type: ProviderType.studio)],
        );
        await tester.pumpWidget(w.app('/u/p1'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(_key('profile-provider-tag')).dy,
          lessThan(tester.getTopLeft(find.byType(OrdersClosedTag)).dy),
        );
      },
    );

    testWidgets(
      'the note names the provider: "{name} chưa mở nhận đơn nên chưa đặt lịch hay xin báo giá được. Bạn vẫn nhắn hỏi được."',
      (tester) async {
        final w = await _world(tester, photographers: [closed()]);
        await tester.pumpWidget(w.app('/u/p1'));
        await tester.pumpAndSettle();
        expect(find.text(note), findsOneWidget);
        final noteTop = tester.getTopLeft(find.text(note)).dy;
        expect(
          noteTop,
          greaterThan(tester.getBottomLeft(find.byType(StatTileRow)).dy),
        );
        expect(noteTop, lessThan(tester.getTopLeft(find.text(profileBio)).dy));
        expect(
          find.descendant(
            of: _key('profile-orders-closed-note'),
            matching: find.byIcon(AppIcons.info),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the bottom bar has a disabled outline "Chưa nhận đặt lịch" and no primary button',
      (tester) async {
        final w = await _world(tester, photographers: [closed()]);
        await tester.pumpWidget(w.app('/u/p1'));
        await tester.pumpAndSettle();
        expect(_key('profile-book-closed'), findsOneWidget);
        expect(
          tester.widget<AppButton>(_key('profile-book-closed')).onPressed,
          isNull,
        );
        expect(
          find.descendant(
            of: _key('profile-book-closed'),
            matching: find.text('Chưa nhận đặt lịch'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _key('profile-book-closed'),
            matching: find.byType(OutlinedButton),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<AppButton>(_key('profile-book-closed')).style,
          isNotNull,
          reason: 'mock .btn.out.dis look',
        );
        expect(_key('profile-book'), findsNothing);
        expect(inBar(find.byType(FilledButton)), findsNothing);
        expect(inBar(find.byType(CtaSurface)), findsNothing);
        expect(find.text('Nhiếp ảnh gia chưa đăng gói'), findsNothing);
      },
    );

    testWidgets('the inquiry button still opens /u/:uid/ask', (tester) async {
      final w = await _world(tester, photographers: [closed()]);
      await tester.pumpWidget(w.app('/u/p1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ContactDial));
      await tester.pumpAndSettle();
      expect(find.text('stub /u/p1/ask'), findsOneWidget);
    });

    testWidgets('tapping a package on the Gói tab does not open booking', (
      tester,
    ) async {
      final w = await _world(tester, photographers: [closed()]);
      await tester.pumpWidget(w.app('/u/p1?tab=services'));
      await tester.pumpAndSettle();
      expect(find.text('Cặp đôi nửa ngày'), findsOneWidget);
      await tester.ensureVisible(_key('service-s2'));
      await tester.tap(_key('service-s2'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(w.router.state.uri.path, '/u/p1');
      expect(find.textContaining('stub'), findsNothing);
    });

    testWidgets(
      'the owner of a closed profile sees "Chỉnh sửa hồ sơ" and no tag or note',
      (tester) async {
        final w = await _world(tester, role: UserRole.photographer);
        w.profiles.add(
          PhotographerProfile(
            summary: fixturePhotographer(
              w.uid,
              name: 'Bảo Ngọc',
              acceptingOrders: false,
            ),
            intro: const PhotographerIntro(
              bio: profileBio,
              onboardingComplete: true,
            ),
          ),
        );
        await tester.pumpWidget(w.app('/u/${w.uid}'));
        await tester.pumpAndSettle();
        expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
        expect(find.byType(OrdersClosedTag), findsNothing);
        expect(find.text(note), findsNothing);
        expect(_key('profile-book-closed'), findsNothing);
      },
    );

    testWidgets(
      'an open provider shows no tag, no note and the primary "Đặt lịch · từ …"',
      (tester) async {
        final w = await _world(tester);
        await tester.pumpWidget(w.app('/u/p1'));
        await tester.pumpAndSettle();
        expect(find.byType(OrdersClosedTag), findsNothing);
        expect(find.textContaining('chưa mở nhận đơn'), findsNothing);
        expect(_key('profile-book-closed'), findsNothing);
        expect(find.text('Đặt lịch · từ 1,5M'), findsOneWidget);
        expect(_enabled(tester, 'profile-book'), isTrue);
      },
    );

    for (final b in Brightness.values) {
      testWidgets('closed variant fits 320dp at 1.3x text (${b.name})', (
        tester,
      ) async {
        final w = await _world(
          tester,
          width: 320,
          photographers: [closed(type: ProviderType.studio)],
        );
        await tester.pumpWidget(w.app('/u/p1', brightness: b, textScale: 1.3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _toTabs(tester);
        await tester.tap(find.text('Gói'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// An award repository whose approved list never arrives.
class _NeverAwards extends FakeAwardRepository {
  @override
  Stream<List<Award>> watchApproved(String photographerId) =>
      StreamController<List<Award>>().stream;
}

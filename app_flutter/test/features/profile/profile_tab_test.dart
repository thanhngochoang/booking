import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/badges/badge_providers.dart';
import 'package:photobooking/data/badges/badge_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/content/saved_follow.dart';
import 'package:photobooking/data/content/saved_follow_providers.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/notifications/notification_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/profile/profile_tab.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/badges_world.dart';
import '../../support/content_fixtures.dart';
import '../../support/screen_host.dart';

/// A signed-in user on S09.01 with in-memory posts, notifications and
/// badges, and stub routes for every link of the tab.
class _World {
  _World({
    this.role = UserRole.customer,
    this.name = 'Lan Anh',
    this.setupComplete = true,
    FakePostRepository? posts,
  }) : posts = posts ?? FakePostRepository();

  final UserRole role;
  final String name;
  final bool setupComplete;
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final intro = FakePhotographerIntroRepository();
  final FakePostRepository posts;
  final notifications = FakeNotificationRepository();
  final badges = FakeBadgeRepository(catalog: badgeCatalogue());
  final savedFollow = FakeSavedFollowRepository();
  late SharedPreferences prefs;
  late String uid;

  /// Overridden only when a test needs the photographer's type (awards
  /// nudge); otherwise the nudge stays hidden, as before.
  FakePublicProfileRepository? profiles;
  FakeAwardRepository? awards;

  Future<void> init({SharedPreferences? sharedPrefs}) async {
    if (sharedPrefs == null) {
      SharedPreferences.setMockInitialValues({});
    }
    prefs = sharedPrefs ?? await SharedPreferences.getInstance();
    final u = await auth.registerWithEmail('lan@b.vn', 'password1', name);
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    uid = u.uid;
    intro.seed(uid, PhotographerIntro(onboardingComplete: setupComplete));
  }

  /// [n] posts by the user of [kind]; `<prefix>0` is the newest.
  void seedPosts(
    int n, {
    String prefix = 'w',
    PostKind kind = PostKind.work,
    int minutesOffset = 0,
  }) {
    for (var i = 0; i < n; i++) {
      posts.add(
        fixturePost(
          '$prefix$i',
          kind: kind,
          photographerId: kind == PostKind.work ? uid : 'p9',
          authorId: uid,
          age: Duration(minutes: minutesOffset + i + 1),
        ),
      );
    }
  }

  /// 3 work, 1 real shoot, 2 event shares, mixed in time: newest is e0.
  void seedMixed() {
    seedPosts(2, prefix: 'e', kind: PostKind.eventShare);
    seedPosts(1, prefix: 'r', kind: PostKind.realShoot, minutesOffset: 2);
    seedPosts(3, minutesOffset: 3);
  }

  Widget app({double textScale = 1.0, List<Override> extra = const []}) {
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileTab()),
        for (final p in [
          '/p/:postId',
          '/settings',
          '/action',
          '/setup',
          '/me/albums',
          '/me/awards',
          '/work/earnings',
          '/u/:uid/badges',
          '/notifications',
          '/me/following',
          '/me/saved',
          '/me/followers',
        ])
          GoRoute(path: p, builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      textScale: textScale,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        photographerIntroRepositoryProvider.overrideWithValue(intro),
        postRepositoryProvider.overrideWithValue(posts),
        notificationRepositoryProvider.overrideWithValue(notifications),
        badgeRepositoryProvider.overrideWithValue(badges),
        savedFollowRepositoryProvider.overrideWithValue(savedFollow),
        if (profiles != null)
          publicProfileRepositoryProvider.overrideWithValue(profiles!),
        if (awards != null) awardRepositoryProvider.overrideWithValue(awards!),
        ...extra,
      ],
    );
  }

  /// The signed-in photographer's public profile with [type].
  void useType(ProviderType type) {
    profiles = FakePublicProfileRepository([
      PhotographerProfile(
        summary: fixturePhotographer(uid, providerType: type),
      ),
    ]);
  }
}

void _usePhone(
  WidgetTester tester, {
  double width = 390,
  double height = 1600,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<_World> _open(
  WidgetTester tester, {
  UserRole role = UserRole.customer,
  String name = 'Lan Anh',
  bool setupComplete = true,
  void Function(_World w)? seed,
  double textScale = 1.0,
  List<Override> extra = const [],
}) async {
  final w = _World(role: role, name: name, setupComplete: setupComplete);
  await w.init();
  seed?.call(w);
  await tester.pumpWidget(w.app(textScale: textScale, extra: extra));
  await tester.pumpAndSettle();
  return w;
}

/// Every page read takes 200 ms, like a real network.
class _SlowPosts extends FakePostRepository {
  @override
  Future<PostPage> byAuthor(
    String uid, {
    PostKind? kind,
    String? cursor,
    int limit = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return super.byAuthor(uid, kind: kind, cursor: cursor, limit: limit);
  }
}

/// The tab's own vertical scroll (the chip row scrolls sideways).
final _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Finder _tile(String id) => find.byKey(Key('profile-post-$id'));

/// The chip row scrolls sideways on a phone; bring the chip in first.
Future<void> _tapChip(WidgetTester tester, String code) async {
  final chip = find.byKey(Key('profile-filter-$code'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
}

void main() {
  testWidgets('header is a row: avatar left, name and role right', (
    tester,
  ) async {
    _usePhone(tester);
    await _open(tester);
    final avatar = find.byType(AppAvatar);
    expect(tester.widget<AppAvatar>(avatar).size, AppAvatarSize.lg);
    final name = find.text('Lan Anh');
    final role = find.text('Khách hàng');
    expect(name, findsOneWidget);
    expect(role, findsOneWidget, reason: 'no area: the role alone');
    final avatarBox = tester.getRect(avatar);
    expect(tester.getTopLeft(name).dx, greaterThan(avatarBox.right));
    expect(tester.getTopLeft(role).dx, greaterThan(avatarBox.right));
    expect(tester.getTopLeft(role).dy, greaterThan(tester.getTopLeft(name).dy));
    expect(tester.getCenter(name).dy, lessThan(avatarBox.bottom));
    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
  });

  testWidgets('a photographer reads "Nhiếp ảnh gia"', (tester) async {
    _usePhone(tester);
    await _open(tester, role: UserRole.photographer, name: 'Minh Trí');
    expect(find.text('Nhiếp ảnh gia'), findsOneWidget);
  });

  testWidgets('shows the user\'s own posts in three columns, newest first', (
    tester,
  ) async {
    _usePhone(tester);
    await _open(
      tester,
      seed: (w) {
        w.seedPosts(6);
        w.posts.add(fixturePost('theirs', authorId: 'someone-else'));
      },
    );
    for (var i = 0; i < 6; i++) {
      expect(_tile('w$i'), findsOneWidget);
    }
    expect(_tile('theirs'), findsNothing);
    final first = tester.getTopLeft(_tile('w0'));
    final second = tester.getTopLeft(_tile('w1'));
    final third = tester.getTopLeft(_tile('w2'));
    final fourth = tester.getTopLeft(_tile('w3'));
    expect(second.dy, first.dy);
    expect(third.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(third.dx, greaterThan(second.dx));
    expect(fourth.dx, first.dx);
    expect(fourth.dy, greaterThan(first.dy));
    final size = tester.getSize(_tile('w0'));
    expect(size.width, closeTo(size.height, 0.01), reason: 'square tiles');
  });

  testWidgets('chips show only kinds the user has, with counts', (
    tester,
  ) async {
    _usePhone(tester);
    await _open(tester, seed: (w) => w.seedMixed());
    expect(find.text('Tất cả · 6'), findsOneWidget);
    expect(find.text('Tác phẩm · 3'), findsOneWidget);
    expect(find.text('Buổi chụp · 1'), findsOneWidget);
    expect(find.text('Sự kiện · 2'), findsOneWidget);
    final xs = [
      for (final k in ['all', 'work', 'real_shoot', 'event_share'])
        tester.getTopLeft(find.byKey(Key('profile-filter-$k'))).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    final all = tester.widget<AppChip>(
      find.byKey(const Key('profile-filter-all')),
    );
    expect(all.selected, isTrue);
    expect(all.kind, AppChipKind.filter);
  });

  testWidgets('kinds the user lacks have no chip', (tester) async {
    _usePhone(tester);
    await _open(
      tester,
      seed: (w) {
        w.seedPosts(2, prefix: 'r', kind: PostKind.realShoot);
        w.seedPosts(
          1,
          prefix: 'e',
          kind: PostKind.eventShare,
          minutesOffset: 5,
        );
      },
    );
    expect(find.text('Tất cả · 3'), findsOneWidget);
    expect(find.byKey(const Key('profile-filter-work')), findsNothing);
    expect(find.text('Buổi chụp · 2'), findsOneWidget);
    expect(find.text('Sự kiện · 1'), findsOneWidget);
  });

  testWidgets('one kind only hides the chip row', (tester) async {
    _usePhone(tester);
    await _open(tester, seed: (w) => w.seedPosts(4));
    expect(find.byKey(const Key('profile-filter-all')), findsNothing);
    expect(find.byType(AppChip), findsNothing);
    expect(_tile('w3'), findsOneWidget);
  });

  testWidgets('choosing "Sự kiện" shows only event shares; tags hide on a '
      'single kind', (tester) async {
    _usePhone(tester);
    await _open(tester, seed: (w) => w.seedMixed());
    await _tapChip(tester, 'event_share');
    await tester.pumpAndSettle();
    expect(_tile('e0'), findsOneWidget);
    expect(_tile('e1'), findsOneWidget);
    expect(_tile('w0'), findsNothing);
    expect(_tile('r0'), findsNothing);
    expect(
      find.descendant(of: _tile('e0'), matching: find.text('Sự kiện')),
      findsNothing,
    );
    expect(
      tester
          .widget<AppChip>(find.byKey(const Key('profile-filter-event_share')))
          .selected,
      isTrue,
    );
    // Back to all.
    await _tapChip(tester, 'all');
    await tester.pumpAndSettle();
    expect(_tile('w0'), findsOneWidget);
    expect(_tile('e0'), findsOneWidget);
  });

  testWidgets('on "Tất cả" event shares carry the tag "Sự kiện" and real '
      'shoots "Buổi chụp"; work has none', (tester) async {
    _usePhone(tester);
    await _open(tester, seed: (w) => w.seedMixed());
    expect(
      find.descendant(of: _tile('e0'), matching: find.text('Sự kiện')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tile('r0'), matching: find.text('Buổi chụp')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _tile('w0'), matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets(
    'the posts count shows the total; following and saved stay hidden when ready is false',
    (tester) async {
      _usePhone(tester);
      await _open(
        tester,
        seed: (w) => w.seedMixed(),
        extra: [savedListsReadyProvider.overrideWithValue(false)],
      );
      final posts = find.byKey(const Key('profile-count-posts'));
      expect(
        find.descendant(of: posts, matching: find.text('6')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: posts, matching: find.text('bài đăng')),
        findsOneWidget,
      );
      expect(find.text('đang theo dõi'), findsNothing);
      expect(find.text('đã lưu'), findsNothing);
    },
  );

  testWidgets(
    'customer row shows "4 đang theo dõi" and "12 đã lưu" and opens /me/following and /me/saved',
    (tester) async {
      _usePhone(tester);
      final w = await _open(
        tester,
        seed: (w) {
          w.seedMixed();
          w.savedFollow.seedCounts(
            w.uid,
            const SocialCounts(following: 4, savedPosts: 10, savedPhotographers: 2),
          );
        },
      );
      expect(find.text('4'), findsOneWidget);
      expect(find.text('đang theo dõi'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('đã lưu'), findsOneWidget);

      final following = find.byKey(const Key('profile-count-following'));
      expect(
        find.descendant(of: following, matching: find.byType(InkWell)),
        findsOneWidget,
      );
      await tester.tap(following);
      await tester.pumpAndSettle();
      expect(find.text('stub /me/following'), findsOneWidget);

      // Reopen to test saved tap
      await tester.pumpWidget(w.app());
      await tester.pumpAndSettle();
      final saved = find.byKey(const Key('profile-count-saved'));
      expect(
        find.descendant(of: saved, matching: find.byType(InkWell)),
        findsOneWidget,
      );
      await tester.tap(saved);
      await tester.pumpAndSettle();
      expect(find.text('stub /me/saved'), findsOneWidget);
    },
  );

  testWidgets(
    'photographer row adds "128 người theo dõi" → /me/followers',
    (tester) async {
      _usePhone(tester);
      await _open(
        tester,
        role: UserRole.photographer,
        seed: (w) {
          w.seedMixed();
          w.savedFollow.seedCounts(
            w.uid,
            const SocialCounts(following: 5, savedPosts: 3, savedPhotographers: 1),
          );
          w.savedFollow.seedFollowerCount(w.uid, 128);
        },
      );

      expect(find.text('128'), findsOneWidget);
      expect(find.text('người theo dõi'), findsOneWidget);

      final followers = find.byKey(const Key('profile-count-followers'));
      expect(
        find.descendant(of: followers, matching: find.byType(InkWell)),
        findsOneWidget,
      );
      await tester.tap(followers);
      await tester.pumpAndSettle();
      expect(find.text('stub /me/followers'), findsOneWidget);
    },
  );

  testWidgets(
    'while loading the row shows skeleton numbers, on error it shows "—" and stays tappable',
    (tester) async {
      _usePhone(tester);
      await _open(
        tester,
        seed: (w) {
          w.seedMixed();
          w.savedFollow.failWith = Exception('network error');
        },
      );

      expect(find.text('—'), findsAtLeastNWidgets(2));
      final following = find.byKey(const Key('profile-count-following'));
      await tester.tap(following);
      await tester.pumpAndSettle();
      expect(find.text('stub /me/following'), findsOneWidget);
    },
  );

  testWidgets('a selected kind that disappears falls back to all', (
    tester,
  ) async {
    _usePhone(tester);
    final w = await _open(tester, seed: (w) => w.seedMixed());
    await _tapChip(tester, 'event_share');
    await tester.pumpAndSettle();
    expect(_tile('w0'), findsNothing);

    // Both event shares are gone; pull to refresh re-counts.
    w.posts
      ..removeById('e0')
      ..removeById('e1');
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-filter-event_share')), findsNothing);
    expect(find.text('Tất cả · 4'), findsOneWidget);
    expect(
      tester
          .widget<AppChip>(find.byKey(const Key('profile-filter-all')))
          .selected,
      isTrue,
    );
    expect(_tile('w0'), findsOneWidget);
    expect(_tile('r0'), findsOneWidget);
  });

  testWidgets('tapping a tile opens /p/<id>', (tester) async {
    _usePhone(tester);
    await _open(tester, seed: (w) => w.seedPosts(2));
    await tester.tap(_tile('w1'));
    await tester.pumpAndSettle();
    expect(find.text('stub /p/w1'), findsOneWidget);
  });

  testWidgets('a tile reads its caption\'s first line, else "Bài đăng n"', (
    tester,
  ) async {
    _usePhone(tester);
    await _open(
      tester,
      seed: (w) {
        w.posts
          ..add(
            fixturePost(
              'a',
              authorId: w.uid,
              photographerId: w.uid,
              caption: 'Hoàng hôn\nở bến',
              age: const Duration(minutes: 1),
            ),
          )
          ..add(
            fixturePost(
              'b',
              authorId: w.uid,
              photographerId: w.uid,
              caption: '',
              age: const Duration(minutes: 2),
            ),
          );
      },
    );
    final handle = tester.ensureSemantics();
    expect(tester.getSemantics(_tile('a')).label, 'Hoàng hôn');
    expect(tester.getSemantics(_tile('b')).label, 'Bài đăng 2');
    handle.dispose();
  });

  testWidgets('pages load on scroll only, once per page', (tester) async {
    _usePhone(tester, height: 800);
    final w = _World(posts: _SlowPosts());
    await w.init();
    w.seedPosts(85);
    await tester.pumpWidget(w.app());
    await tester.pumpAndSettle();
    expect(_tile('w0'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(w.posts.byAuthorCursors, [
      null,
    ], reason: 'opening the tab reads the first page only');

    await tester.scrollUntilVisible(_tile('w19'), 300, scrollable: _vertical);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(w.posts.byAuthorCursors, [null, 'w19']);
    expect(
      tester.state<ScrollableState>(_vertical).position.extentAfter,
      greaterThan(0),
      reason: 'the second page is below, not read further',
    );
  });

  testWidgets('a failed pull to refresh keeps the posts and says so', (
    tester,
  ) async {
    _usePhone(tester);
    final w = await _open(tester, seed: (w) => w.seedPosts(3));
    w.posts.failWith = Exception('offline');
    await tester.fling(_vertical, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Không tải được bài đăng.'),
      ),
      findsOneWidget,
    );
    expect(_tile('w0'), findsOneWidget);
    expect(find.byType(ErrorState), findsNothing);
  });

  testWidgets('a failed next page keeps the grid and offers retry', (
    tester,
  ) async {
    _usePhone(tester, height: 3000);
    final w = _World();
    await w.init();
    w
      ..seedPosts(25)
      ..posts.failByAuthorNextPagesWith = Exception('offline');
    await tester.pumpWidget(w.app());
    await tester.pumpAndSettle();
    expect(_tile('w19'), findsOneWidget);
    expect(_tile('w20'), findsNothing);
    final retry = find.byKey(const Key('profile-posts-more-error'));
    expect(retry, findsOneWidget);
    expect(find.text('Không tải thêm được. Thử lại'), findsOneWidget);
    expect(
      w.posts.byAuthorCursors.where((c) => c != null),
      hasLength(1),
      reason: 'a failed page is not asked again by itself',
    );

    w.posts.failByAuthorNextPagesWith = null;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(_tile('w24'), findsOneWidget);
    expect(retry, findsNothing);
  });

  testWidgets('a failed first page offers retry', (tester) async {
    _usePhone(tester);
    final w = _World();
    await w.init();
    w
      ..seedPosts(3)
      ..posts.failWith = Exception('offline');
    await tester.pumpWidget(w.app());
    await tester.pumpAndSettle();
    expect(find.text('Không tải được bài đăng.'), findsOneWidget);
    w.posts.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(_tile('w0'), findsOneWidget);
  });

  testWidgets('empty for a photographer: "Chưa có bài đăng" and "Đăng bài '
      'đầu tiên" opens /action', (tester) async {
    _usePhone(tester);
    await _open(tester, role: UserRole.photographer);
    expect(find.text('Chưa có bài đăng'), findsOneWidget);
    final cta = find.widgetWithText(AppButton, 'Đăng bài đầu tiên');
    expect(cta, findsOneWidget);
    expect(
      find.descendant(of: cta, matching: find.byType(CtaSurface)),
      findsOneWidget,
      reason: 'the one primary action of the empty tab',
    );
    await tester.ensureVisible(cta);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.text('stub /action'), findsOneWidget);
  });

  testWidgets('empty for a customer: "Chưa có ảnh nào" and the explanation, '
      'no button', (tester) async {
    _usePhone(tester);
    await _open(tester);
    expect(find.text('Chưa có ảnh nào'), findsOneWidget);
    expect(
      find.text('Ảnh bạn chia sẻ sau buổi chụp sẽ hiện ở đây'),
      findsOneWidget,
    );
    expect(find.byType(AppButton), findsNothing);
    expect(find.byType(AppChip), findsNothing);
  });

  testWidgets('no primary button when there are posts', (tester) async {
    _usePhone(tester);
    await _open(
      tester,
      role: UserRole.photographer,
      seed: (w) => w.seedMixed(),
    );
    expect(find.byType(CtaSurface), findsNothing);
  });

  testWidgets('no switch-role button and no sign-out button here', (
    tester,
  ) async {
    _usePhone(tester);
    await _open(tester);
    expect(find.byKey(const Key('switch-role')), findsNothing);
    expect(find.byKey(const Key('sign-out')), findsNothing);
    expect(find.byKey(const Key('settings-sign-out')), findsNothing);
    expect(find.text('Tôi là nhiếp ảnh gia'), findsNothing);
  });

  testWidgets('the gear opens /settings', (tester) async {
    _usePhone(tester);
    await _open(tester);
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('stub /settings'), findsOneWidget);
  });

  // Moved from test/features/shell/placeholder_tabs_test.dart.

  testWidgets('S09.01: photographers see Album của tôi, customers do not', (
    tester,
  ) async {
    _usePhone(tester);
    await _open(tester, role: UserRole.photographer);
    expect(find.text('Album của tôi'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('open-my-albums')));
    await tester.tap(find.byKey(const Key('open-my-albums')));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/albums'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _open(tester);
    expect(find.text('Album của tôi'), findsNothing);
  });

  testWidgets('S09.01: photographers see Thu nhập and it opens S06.05', (
    tester,
  ) async {
    _usePhone(tester);
    await _open(tester, role: UserRole.photographer);
    expect(find.text('Thu nhập'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('open-earnings')));
    await tester.tap(find.byKey(const Key('open-earnings')));
    await tester.pumpAndSettle();
    expect(find.text('stub /work/earnings'), findsOneWidget);
  });

  testWidgets('S09.01: customers do not see Thu nhập', (tester) async {
    _usePhone(tester);
    await _open(tester);
    expect(find.text('Thu nhập'), findsNothing);
    expect(find.byKey(const Key('open-earnings')), findsNothing);
  });

  testWidgets('S09.01: photographer extras sit between the badges and the '
      'chips', (tester) async {
    _usePhone(tester);
    await _open(
      tester,
      role: UserRole.photographer,
      setupComplete: false,
      seed: (w) => w.seedMixed(),
    );
    double y(Key k) => tester.getTopLeft(find.byKey(k)).dy;
    final badges = y(const Key('profile-tab-badges'));
    final setup = y(const Key('continue-setup'));
    final albums = y(const Key('open-my-albums'));
    final earnings = y(const Key('open-earnings'));
    final chips = y(const Key('profile-filter-all'));
    expect(badges, lessThan(setup));
    expect(setup, lessThan(albums));
    expect(albums, lessThan(earnings));
    expect(earnings, lessThan(chips));
    expect(
      y(const Key('open-notifications')),
      lessThan(y(const Key('profile-count-posts'))),
    );
    expect(y(const Key('profile-count-posts')), lessThan(badges));
  });

  testWidgets('S09.01: the awards nudge shows for individuals and hides after '
      'Để sau', (tester) async {
    _usePhone(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final w = _World(role: UserRole.photographer);
    await w.init(sharedPrefs: prefs);
    w.useType(ProviderType.individual);
    await tester.pumpWidget(w.app());
    await tester.pumpAndSettle();
    expect(find.text('Có giải thưởng? Lên hạng Nhiếp ảnh gia'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('award-nudge')));
    await tester.tap(find.byKey(const Key('award-nudge')));
    await tester.pumpAndSettle();
    expect(find.text('stub /me/awards'), findsOneWidget);

    // Back on the tab, "Để sau" hides it and remembers per user.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(w.app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('award-nudge-later')));
    await tester.tap(find.byKey(const Key('award-nudge-later')));
    await tester.pumpAndSettle();
    expect(find.text('Có giải thưởng? Lên hạng Nhiếp ảnh gia'), findsNothing);
    expect(prefs.getBool('awardNudgeDismissed:${w.uid}'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(w.app());
    await tester.pumpAndSettle();
    expect(find.text('Có giải thưởng? Lên hạng Nhiếp ảnh gia'), findsNothing);
  });

  testWidgets('S09.01: the nudge hides when the live tier becomes artist', (
    tester,
  ) async {
    _usePhone(tester);
    final w = _World(role: UserRole.photographer);
    await w.init();
    w
      ..useType(ProviderType.individual)
      ..awards = (FakeAwardRepository(uid: w.uid)..setTier(const AwardTier()));
    await tester.pumpWidget(w.app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('award-nudge')), findsOneWidget);

    // The cached profile still says individual; the tier stream moves on.
    w.awards!.setTier(const AwardTier(providerType: ProviderType.artist));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('award-nudge')), findsNothing);
  });

  testWidgets('S09.01: no awards nudge for an artist, a studio or a customer', (
    tester,
  ) async {
    _usePhone(tester);
    for (final type in [ProviderType.artist, ProviderType.studio]) {
      final w = _World(role: UserRole.photographer);
      await w.init();
      w.useType(type);
      await tester.pumpWidget(w.app());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('award-nudge')),
        findsNothing,
        reason: '$type',
      );
      await tester.pumpWidget(const SizedBox());
    }
    await _open(tester);
    expect(find.byKey(const Key('award-nudge')), findsNothing);
  });

  testWidgets(
    'a photographer with unfinished setup is offered to continue it',
    (tester) async {
      _usePhone(tester);
      await _open(tester, role: UserRole.photographer, setupComplete: false);
      expect(find.text('Hoàn thiện hồ sơ nhiếp ảnh gia'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('continue-setup')));
      await tester.tap(find.byKey(const Key('continue-setup')));
      await tester.pumpAndSettle();
      expect(find.text('stub /setup'), findsOneWidget);
    },
  );

  testWidgets('the setup card is gone once setup is complete', (tester) async {
    _usePhone(tester);
    await _open(tester, role: UserRole.photographer);
    expect(find.byKey(const Key('continue-setup')), findsNothing);
  });

  for (final role in UserRole.values) {
    testWidgets('fits 320dp at 1.3x text (${role.name})', (tester) async {
      _usePhone(tester, width: 320, height: 640);
      final w = _World(
        role: role,
        name: 'Nguyễn Thị Phương Thảo',
        setupComplete: false,
      );
      await w.init();
      w
        ..seedMixed()
        ..useType(ProviderType.individual);
      await tester.pumpWidget(w.app(textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Nguyễn Thị Phương Thảo'), findsOneWidget);
      // The whole tab scrolls; the grid is reachable below the extras.
      await tester.scrollUntilVisible(_tile('w2'), 200, scrollable: _vertical);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

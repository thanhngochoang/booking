// test/support/badges_world.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/badges/badge.dart';
import 'package:photobooking/data/badges/badge_providers.dart';
import 'package:photobooking/data/badges/badge_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/badges/badges_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screen_host.dart';

/// 12:00 in Vietnam on Monday 12 October 2026.
final badgesNow = DateTime.utc(2026, 10, 12, 5);

BadgeDefinition _def(
  String id,
  String name,
  String description,
  String icon,
  BadgeSource source,
  String audience,
  int order, {
  String? shortName,
  bool hidden = false,
  bool progress = false,
}) => BadgeDefinition(
  id: id,
  name: name,
  shortName: shortName,
  description: description,
  icon: icon,
  source: source,
  audience: audience,
  order: order,
  hiddenWhenLocked: hidden,
  hasProgress: progress,
);

/// The 12 badges of the catalogue (plan Decision 14).
List<BadgeDefinition> badgeCatalogue() => [
  _def(
    'top_rated',
    'Được đánh giá cao',
    'Từ 4,8 sao với ít nhất 20 đánh giá',
    'favorite',
    BadgeSource.review,
    'photographer',
    10,
    progress: true,
  ),
  _def(
    'punctual',
    'Khen đúng giờ',
    '5 đánh giá khen đúng giờ',
    'schedule',
    BadgeSource.review,
    'photographer',
    20,
    progress: true,
  ),
  _def(
    'detailed_reviewer',
    'Nhận xét chi tiết',
    'Viết 5 nhận xét dài',
    'check',
    BadgeSource.review,
    'customer',
    30,
    progress: true,
  ),
  _def(
    'new_member',
    'Thành viên mới',
    '30 ngày đầu trên app',
    'celebration',
    BadgeSource.system,
    'both',
    40,
    hidden: true,
  ),
  _def(
    'complete_profile',
    'Hồ sơ đầy đủ',
    'Đủ ảnh và gói',
    'person',
    BadgeSource.system,
    'photographer',
    50,
    progress: true,
  ),
  _def(
    'fast_reply',
    'Phản hồi nhanh',
    'Trả lời trong 1 giờ',
    'chat_bubble',
    BadgeSource.system,
    'photographer',
    60,
  ),
  _def(
    'shoots_10',
    '10 buổi chụp',
    'Hoàn thành 10 buổi chụp',
    'photo_camera',
    BadgeSource.system,
    'photographer',
    70,
    shortName: '10 buổi',
    progress: true,
  ),
  _def(
    'shoots_50',
    '50 buổi chụp',
    'Hoàn thành 50 buổi chụp',
    'photo_camera',
    BadgeSource.system,
    'photographer',
    80,
    shortName: '50 buổi',
    progress: true,
  ),
  _def(
    'shoots_100',
    '100+ buổi chụp',
    'Hoàn thành 100 buổi chụp',
    'photo_camera',
    BadgeSource.system,
    'photographer',
    90,
    shortName: '100+ buổi',
    progress: true,
  ),
  _def(
    'event_host',
    'Chủ sự kiện',
    'Tổ chức 1 sự kiện',
    'calendar_today',
    BadgeSource.system,
    'photographer',
    100,
    progress: true,
  ),
  _def(
    'loyal_customer',
    'Khách thân thiết',
    'Hoàn thành 3 buổi chụp',
    'favorite',
    BadgeSource.system,
    'customer',
    110,
    progress: true,
  ),
  _def(
    'sharer',
    'Người chia sẻ',
    'Chia sẻ 5 bài Buổi chụp thật',
    'ios_share',
    BadgeSource.system,
    'customer',
    120,
    progress: true,
  ),
];

EarnedBadge earnedOn(String id, DateTime at, [String? text]) =>
    EarnedBadge(badgeId: id, awardedAt: at, snapshotText: text);

/// A repository whose catalogue never arrives (loading state).
class HangingBadgeRepository extends FakeBadgeRepository {
  @override
  Future<List<BadgeDefinition>> catalog() =>
      Completer<List<BadgeDefinition>>().future;
}

/// A signed-in user with in-memory badges and S03.02 mounted at
/// `/u/:uid/badges`. The mock's numbers: 5 / 12, reviews 2 / 3, system 3 / 9.
class BadgesWorld {
  BadgesWorld({this.role = UserRole.photographer, this.repository});

  final UserRole role;
  FakeBadgeRepository? repository;
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  late SharedPreferences sharedPrefs;
  late String uid;
  late GoRouter router;
  late FakeBadgeRepository repo;

  /// Other people of the tests.
  static const otherUid = 'someone-else';

  Future<void> init({Map<String, Object> prefsValues = const {}}) async {
    SharedPreferences.setMockInitialValues(prefsValues);
    sharedPrefs = await SharedPreferences.getInstance();
    final u = await auth.registerWithEmail('lan@b.vn', 'password1', 'Lan Anh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    uid = u.uid;
    final old = DateTime.utc(2026, 9, 1);
    repo =
        repository ??
        FakeBadgeRepository(
          catalog: badgeCatalogue(),
          earned: {
            uid: [
              earnedOn('top_rated', old, '4,9 sao từ 58 đánh giá'),
              earnedOn('punctual', old),
              earnedOn('new_member', old),
              earnedOn('fast_reply', old),
              earnedOn('shoots_100', old, 'Hoàn thành 112 buổi'),
            ],
            otherUid: [earnedOn('top_rated', old, '4,8 sao từ 30 đánh giá')],
          },
          progress: {
            uid: const {
              'top_rated': BadgeProgressEntry(current: 12, target: 20),
              'detailed_reviewer': BadgeProgressEntry(current: 3, target: 5),
              'complete_profile': BadgeProgressEntry(current: 4, target: 6),
              'event_host': BadgeProgressEntry(current: 0, target: 1),
              'loyal_customer': BadgeProgressEntry(current: 1, target: 3),
            },
          },
        );
  }

  List<Override> get overrides => [
    sharedPreferencesProvider.overrideWithValue(sharedPrefs),
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(users),
    badgeRepositoryProvider.overrideWithValue(repo),
    clockProvider.overrideWithValue(() => badgesNow),
  ];

  Widget app({
    String? location,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    router = GoRouter(
      initialLocation: location ?? '/u/$uid/badges',
      routes: [
        GoRoute(
          path: '/u/:uid/badges',
          builder: (_, s) => BadgesScreen(uid: s.pathParameters['uid']!),
        ),
        for (final p in ['/profile', '/u/:uid'])
          GoRoute(path: p, builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    );
  }
}

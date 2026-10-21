import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

import '../../support/content_fixtures.dart';
import '../../support/profile_world.dart';
import '../../support/studio_world.dart';

Finder _key(String k) => find.byKey(Key(k));

/// The profile's loaders are bounded: a second of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

PhotographerSummary _studio({String id = 'cuc', int memberCount = 6}) =>
    fixturePhotographer(
      id,
      name: 'Studio Mây',
      verified: true,
      businessVerified: true,
      providerType: ProviderType.studio,
      tomatoCount: 93,
      brickCount: 7,
      completed: 310,
      memberCount: memberCount,
    );

PhotographerSummary _member(String id, String name, int tomatoes) =>
    fixturePhotographer(
      id,
      name: name,
      verified: true,
      tomatoCount: tomatoes,
      brickCount: 100 - tomatoes,
      studioId: 'cuc',
    );

List<PhotographerSummary> _people() => [
  _studio(),
  _member('minh', 'Minh Trí', 97),
  _member('nhung', 'Hồng Nhung', 91),
  _member('bao', 'Quốc Bảo', 89),
  _member('linh', 'Khánh Linh', 92),
  fixturePhotographer('solo', name: 'Thu Hà', verified: true),
];

class _World {
  _World(this.profile, this.studios);
  final ProfileWorld profile;
  final FakeStudioRepository studios;
}

/// S03.01 of [location], seen by a [role] whose own photographer intro is
/// [intro] (none for a customer).
Future<_World> _open(
  WidgetTester tester,
  String location, {
  UserRole role = UserRole.customer,
  PhotographerIntro? intro,
  List<PhotographerSummary>? photographers,
}) async {
  usePhoneFor(tester);
  final w = ProfileWorld(role: role, photographers: photographers ?? _people());
  await w.init();
  w.skills.seed('cuc', const PhotographerSkills(yearsExperience: 8));
  if (intro != null) w.intros.seed(w.uid, intro);
  final studios = FakeStudioRepository(uid: w.uid);
  final overrides = <Override>[
    studioRepositoryProvider.overrideWithValue(studios),
    profileStudioNameProvider('cuc')
        .overrideWith((ref) => Stream.value('Studio Mây')),
  ];
  await tester.pumpWidget(w.app(location, extraOverrides: overrides));
  await _settle(tester);
  return _World(w, studios);
}

const _independent = PhotographerIntro(
  onboardingComplete: true,
  verified: true,
  acceptingOrders: true,
);

void main() {
  testWidgets('a studio shows the four stat tiles with members and years', (
    tester,
  ) async {
    await _open(tester, '/u/cuc');

    final tiles = tester.widgetList<StatTile>(find.byType(StatTile)).toList();
    expect(tiles, hasLength(4));
    expect(
      find.descendant(
        of: _key('profile-stat-reviews'),
        matching: find.text('93%'),
      ),
      findsOneWidget,
    );
    expect(find.text('310'), findsOneWidget);
    expect(
      find.descendant(
        of: _key('profile-stat-members'),
        matching: find.text('6'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('profile-stat-members'),
        matching: find.text('thành viên'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('profile-stat-years'),
        matching: find.text('8 năm'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('profile-stat-years'),
        matching: find.text('hoạt động'),
      ),
      findsOneWidget,
    );
    expect(find.text('phản hồi'), findsNothing);
  });

  testWidgets('the members strip shows 4 members with % and +2', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final w = await _open(tester, '/u/cuc');

    expect(find.text('Thành viên'), findsOneWidget);
    final strip = _key('profile-member-strip');
    for (final name in ['Minh Trí', 'Hồng Nhung', 'Quốc Bảo', 'Khánh Linh']) {
      expect(
        find.descendant(of: strip, matching: find.text(name)),
        findsOneWidget,
      );
    }
    expect(find.text('+2'), findsOneWidget);
    expect(find.bySemanticsLabel('Thành viên Studio Mây'), findsOneWidget);
    expect(find.bySemanticsLabel('Minh Trí, 97% cà chua'), findsOneWidget);
    expect(find.bySemanticsLabel('và 2 thành viên khác'), findsOneWidget);

    await tester.tap(_key('member-strip-nhung'));
    await _settle(tester);
    expect(w.profile.router.state.uri.toString(), '/u/nhung');
    semantics.dispose();
  });

  testWidgets('an independent photographer not in a studio sees Xin gia nhập '
      'and sending shows Đã xin gia nhập', (tester) async {
    final w = await _open(
      tester,
      '/u/cuc',
      role: UserRole.photographer,
      intro: _independent,
    );

    final join = _key('profile-join-studio');
    expect(tester.widget<AppButton>(join).label, 'Xin gia nhập');
    await tester.tap(join);
    await _settle(tester);

    final (call, payload) = w.studios.calls.single;
    expect(call, 'requestToJoin');
    expect(payload, {'studioId': 'cuc'});
    expect(find.text('Đã gửi yêu cầu tới Studio Mây'), findsOneWidget);
    expect(tester.widget<AppButton>(join).label, 'Đã xin gia nhập');
    expect(tester.widget<AppButton>(join).onPressed, isNull);
  });

  testWidgets('a pending own request reads Đã xin gia nhập from the start', (
    tester,
  ) async {
    final w = await _open(
      tester,
      '/u/cuc',
      role: UserRole.photographer,
      intro: _independent,
    );
    w.studios.seedRelation(
      makeRelation(
        studioId: 'cuc',
        memberId: w.profile.uid,
        status: RelationStatus.requested,
        initiatedBy: RelationInitiator.member,
      ),
    );
    await _settle(tester);

    final join = _key('profile-join-studio');
    expect(tester.widget<AppButton>(join).label, 'Đã xin gia nhập');
    expect(tester.widget<AppButton>(join).onPressed, isNull);
  });

  group('a customer, a member of any studio and the studio itself do not '
      'see it', () {
    testWidgets('customer', (tester) async {
      await _open(tester, '/u/cuc');
      expect(find.text('Thành viên'), findsOneWidget);
      expect(_key('profile-join-studio'), findsNothing);
    });

    testWidgets('member of a studio', (tester) async {
      await _open(
        tester,
        '/u/cuc',
        role: UserRole.photographer,
        intro: const PhotographerIntro(
          onboardingComplete: true,
          studioId: 'nang',
        ),
      );
      expect(_key('profile-join-studio'), findsNothing);
    });

    testWidgets('another studio', (tester) async {
      await _open(
        tester,
        '/u/cuc',
        role: UserRole.photographer,
        intro: const PhotographerIntro(
          onboardingComplete: true,
          providerType: ProviderType.studio,
        ),
      );
      expect(_key('profile-join-studio'), findsNothing);
    });

    testWidgets('the studio itself', (tester) async {
      final w = await _open(
        tester,
        '/u/cuc',
        role: UserRole.photographer,
        intro: _independent,
      );
      final me = w.profile.uid;
      w.profile.profiles.add(
        PhotographerProfile(
          summary: _studio(id: me),
          intro: const PhotographerIntro(onboardingComplete: true),
        ),
      );
      w.profile.router.go('/u/$me');
      await _settle(tester);

      expect(_key('profile-stat-members'), findsOneWidget);
      expect(_key('profile-join-studio'), findsNothing);
    });
  });

  testWidgets('cooldown answer shows profileJoinCooldown', (tester) async {
    final w = await _open(
      tester,
      '/u/cuc',
      role: UserRole.photographer,
      intro: PhotographerIntro(
        onboardingComplete: true,
        // 25/10 in Vietnam.
        studioCooldownUntil: DateTime.utc(2026, 10, 25, 3),
      ),
    );
    w.studios.nextError = 'cooldown';
    await tester.tap(_key('profile-join-studio'));
    await _settle(tester);

    expect(find.text('Bạn vào được studio từ 25/10'), findsOneWidget);
    expect(
      tester.widget<AppButton>(_key('profile-join-studio')).label,
      'Xin gia nhập',
    );
  });

  testWidgets('a member\'s profile shows Thành viên của Studio Mây and taps '
      'to the studio', (tester) async {
    final semantics = tester.ensureSemantics();
    final w = await _open(tester, '/u/minh');

    expect(find.text('Thành viên của Studio Mây'), findsOneWidget);
    expect(
      tester.getSemantics(_key('profile-member-of')),
      matchesSemantics(
        label: 'Thành viên của Studio Mây',
        isLink: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSize(_key('profile-member-of')).height,
      greaterThanOrEqualTo(48),
    );
    // A member's own stats stay a photographer's.
    expect(find.text('phản hồi'), findsOneWidget);
    expect(_key('profile-members'), findsNothing);

    await tester.tap(find.text('Thành viên của Studio Mây'));
    await _settle(tester);
    expect(w.profile.router.state.uri.toString(), '/u/cuc');
    semantics.dispose();
  });

  testWidgets('an individual not in a studio shows no label', (tester) async {
    await _open(tester, '/u/solo');

    expect(find.textContaining('Thành viên của'), findsNothing);
    expect(_key('profile-member-of'), findsNothing);
  });

  testWidgets('a studio with no members and no one to ask shows no section', (
    tester,
  ) async {
    await _open(tester, '/u/cuc', photographers: [_studio(memberCount: 0)]);
    expect(_key('profile-members'), findsNothing);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    usePhoneFor(tester, width: 320, height: 640);
    final w = ProfileWorld(
      role: UserRole.photographer,
      photographers: _people(),
    );
    await w.init();
    w.intros.seed(w.uid, _independent);
    await tester.pumpWidget(
      w.app(
        '/u/cuc',
        textScale: 1.3,
        extraOverrides: [
          studioRepositoryProvider.overrideWithValue(
            FakeStudioRepository(uid: w.uid),
          ),
        ],
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(_key('profile-join-studio'), findsOneWidget);
  });
}

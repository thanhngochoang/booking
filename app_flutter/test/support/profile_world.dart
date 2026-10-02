// test/support/profile_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';

import 'discovery_world.dart';
import 'screen_host.dart';

const profileBio =
    'Ánh sáng tự nhiên, ít dàn dựng. Chuyên chân dung ngoài trời ở Sài Gòn.';

/// A phone tall enough that S03's header, tabs and the start of the tab
/// content are all laid out (slivers below the viewport are not built).
void usePhoneFor(
  WidgetTester tester, {
  double width = 390,
  double height = 1400,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 3b4's discovery world (p1 Minh Trí verified, p2 Hồng Nhung, p3, p4 …)
/// plus what S03 reads: public profiles, skills, the availability month,
/// the photographer's contact flags, and stub routes for every link.
class ProfileWorld {
  ProfileWorld({UserRole role = UserRole.customer, bool hasPhone = true})
    : discovery = DiscoveryWorld(role: role, hasPhone: hasPhone);

  final DiscoveryWorld discovery;
  final profiles = FakePublicProfileRepository();
  final availability = FakeAvailabilityRepository();
  final skills = FakeSkillsRepository();
  final contacts = FakePhotographerContactRepository();
  late GoRouter router;

  String get uid => discovery.uid;

  Future<void> init() async {
    await discovery.init();
    for (final p in discoveryPhotographers()) {
      profiles.add(
        PhotographerProfile(
          summary: p,
          intro: const PhotographerIntro(
            bio: profileBio,
            equipment: ['Sony A7 IV'],
            onboardingComplete: true,
          ),
        ),
      );
    }
    skills.seed(
      'p1',
      const PhotographerSkills(
        specialties: [
          SpecialtySkill(
            id: 'portrait',
            level: SkillLevels.expert,
            evidencePostIds: ['a'],
          ),
          SpecialtySkill(id: 'wedding'),
        ],
        languages: ['vi'],
        yearsExperience: 6,
      ),
    );
  }

  List<Override> get overrides => [
    ...discovery.overrides,
    publicProfileRepositoryProvider.overrideWithValue(profiles),
    availabilityRepositoryProvider.overrideWithValue(availability),
    calendarTodayProvider.overrideWithValue(DateTime.utc(2026, 10, 1)),
    skillsRepositoryProvider.overrideWithValue(skills),
    photographerContactRepositoryProvider.overrideWithValue(contacts),
    externalLauncherProvider.overrideWithValue(FakeExternalLauncher()),
    contactLinkRepositoryProvider.overrideWithValue(
      FakeContactLinkRepository(),
    ),
  ];

  Widget app(
    String location, {
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    Widget stub(BuildContext _, GoRouterState s) => Text('stub ${s.uri}');
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/u/:uid',
          builder: (_, s) => PhotographerProfileScreen(
            uid: s.pathParameters['uid']!,
            initialSection: profileSectionFromQuery(
              s.uri.queryParameters['tab'],
            ),
          ),
          routes: [
            GoRoute(path: 'book', builder: stub),
            GoRoute(path: 'ask', builder: stub),
          ],
        ),
        for (final p in [
          '/home',
          '/profile/phone',
          '/profile/skills',
          '/setup/1',
          '/setup/2',
          '/setup/4',
          '/settings/profile',
          '/p/:id',
        ])
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

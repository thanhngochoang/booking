import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/saved_follow_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/saved/followers_screen.dart';
import 'package:photobooking/features/saved/following_screen.dart';
import 'package:photobooking/features/saved/saved_screen.dart';

import 'discovery_world.dart';
import 'screen_host.dart';

class SavedWorld {
  SavedWorld({
    this.hasPhone = true,
    this.role = UserRole.customer,
    List<PostSummary>? posts,
    List<PhotographerSummary>? photographers,
  })  : postsRepo = FakePostRepository(posts ?? discoveryPosts()),
        photographersRepo = FakePhotographerRepository(
          photographers ?? discoveryPhotographers(),
        ) {
    savedFollowRepo = FakeSavedFollowRepository(
      postRepo: postsRepo,
      photographerRepo: photographersRepo,
    );
  }

  final bool hasPhone;
  final UserRole role;
  final FakePostRepository postsRepo;
  final FakePhotographerRepository photographersRepo;
  late final FakeSavedFollowRepository savedFollowRepo;
  final contacts = FakeUserContactRepository();
  final users = FakeUserRepository();
  final engagement = FakePostEngagementRepository();
  late final FakeAuthRepository auth;
  late final String uid;
  late final GoRouter router;

  Future<void> init() async {
    auth = FakeAuthRepository();
    final u = await auth.registerWithEmail('user@test.vn', 'password1', 'Lan Anh');
    uid = u.uid;
    await users.ensureProfile(u);
    await users.setRole(uid, role);
    if (hasPhone) {
      contacts.seed(uid, const UserContact(phone: '+84903123456'));
    }
  }

  Future<void> addFollow(String uid, String photographerId, DateTime createdAt) async {
    savedFollowRepo.addFollow(uid, photographerId, createdAt);
    await engagement.setFollowing(uid, photographerId, true);
  }

  List<Override> get overrides => [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        postRepositoryProvider.overrideWithValue(postsRepo),
        photographerRepositoryProvider.overrideWithValue(photographersRepo),
        postEngagementRepositoryProvider.overrideWithValue(engagement),
        savedFollowRepositoryProvider.overrideWithValue(savedFollowRepo),
        userContactRepositoryProvider.overrideWithValue(contacts),
      ];

  Widget app(
    String initialLocation, {
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    Widget stub(BuildContext _, GoRouterState s) => Text('stub ${s.uri}');

    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/me/saved',
          builder: (_, state) => SavedScreen(
            initialTab: state.uri.queryParameters['tab'] == 'photographers'
                ? SavedTab.photographers
                : SavedTab.posts,
          ),
        ),
        GoRoute(
          path: '/me/following',
          builder: (_, _) => const FollowingScreen(),
        ),
        GoRoute(
          path: '/me/followers',
          redirect: (_, _) {
            if (role != UserRole.photographer) {
              return '/profile';
            }
            return null;
          },
          builder: (_, _) => const FollowersScreen(),
        ),
        GoRoute(path: '/p/:postId', builder: stub),
        GoRoute(path: '/u/:uid', builder: stub),
        GoRoute(path: '/u/:uid/book', builder: stub),
        GoRoute(path: '/profile/phone', builder: stub),
        GoRoute(path: '/profile', builder: stub),
        GoRoute(path: '/explore', builder: stub),
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

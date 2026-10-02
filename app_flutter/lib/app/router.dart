import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/auth/login_screen.dart';
import 'package:photobooking/features/auth/register_screen.dart';
import 'package:photobooking/features/calendar/my_calendar_screen.dart';
import 'package:photobooking/features/contact/add_phone_screen.dart';
import 'package:photobooking/features/explore/explore_screen.dart';
import 'package:photobooking/features/home/home_screen.dart';
import 'package:photobooking/features/onboarding/role_screen.dart';
import 'package:photobooking/features/onboarding/session_error_screen.dart';
import 'package:photobooking/features/onboarding/splash_screen.dart';
import 'package:photobooking/features/photo/photo_detail_screen.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/features/photographer_setup/contact_setup_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_intro_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';
import 'package:photobooking/features/settings/edit_profile_screen.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/features/shell/tab_shell.dart';
import 'package:photobooking/features/skills/skills_screen.dart';

const _authRoutes = {'/login', '/register'};
const _onboardingRoute = '/onboarding/role';
const _splashRoute = '/splash';
const _sessionErrorRoute = '/session-error';
const _nonResumable = {
  ..._authRoutes,
  _onboardingRoute,
  _splashRoute,
  _sessionErrorRoute,
};

String _toSplash(String location) =>
    '$_splashRoute?from=${Uri.encodeComponent(location)}';

/// Pure redirect rule; see router_test.dart.
///
/// While the session is still being restored (auth or profile loading) the app
/// parks on /splash and remembers where it was going in `from`, so a signed-in
/// user never sees the login form and deep links survive a cold start.
String? computeRedirect({
  bool authLoading = false,
  required bool signedIn,
  required bool profileLoaded,
  bool profileError = false,
  required bool needsRole,
  required String location,
  String? from,
}) {
  final onAuth = _authRoutes.contains(location);
  if (authLoading) return location == _splashRoute ? null : _toSplash(location);
  if (!signedIn) {
    if (location == _splashRoute) return '/login';
    return onAuth ? null : '/login';
  }
  if (profileError) {
    return location == _sessionErrorRoute ? null : _sessionErrorRoute;
  }
  if (!profileLoaded) {
    return location == _splashRoute ? null : _toSplash(location);
  }
  if (needsRole) return location == _onboardingRoute ? null : _onboardingRoute;
  if (location == _splashRoute) {
    return (from == null || _nonResumable.contains(from))
        ? AppTab.home.path
        : from;
  }
  if (_nonResumable.contains(location)) return AppTab.home.path;
  return null;
}

/// S20 and S24 are for photographers only (spec screens/README.md "Vai trò").
String? photographerOnlyRedirect(UserRole? role) =>
    role == UserRole.photographer ? null : AppTab.home.path;

/// Rebuilds GoRouter's redirect when auth or profile changes.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }
  final Ref ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = ref.read(authStateProvider);
    final profile = ref.read(currentProfileProvider);
    final signedIn = auth.value != null;
    final profileError = signedIn && profile.hasError;
    return computeRedirect(
      authLoading: !auth.hasValue,
      signedIn: signedIn,
      profileLoaded:
          !signedIn ||
          (!profile.hasError && profile.hasValue && profile.value != null),
      profileError: profileError,
      needsRole: profile.value?.needsRole ?? false,
      location: state.matchedLocation,
      from: state.uri.queryParameters['from'],
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  String? photographersOnly() =>
      photographerOnlyRedirect(ref.read(currentProfileProvider).value?.role);
  return GoRouter(
    initialLocation: AppTab.home.path,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: _splashRoute, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: _sessionErrorRoute,
        builder: (_, _) => const SessionErrorScreen(),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: _onboardingRoute, builder: (_, _) => const RoleScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (_, _) => const EditProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile/phone',
        builder: (_, state) =>
            AddPhoneScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: '/setup',
        redirect: (_, _) {
          final away = photographersOnly();
          if (away != null) {
            return away;
          }
          final uid = ref.read(authRepositoryProvider).currentUser?.uid;
          return setupResumePath(
            uid == null ? 1 : ref.read(setupDraftStoreProvider).step(uid),
          );
        },
      ),
      GoRoute(
        path: '/setup/1',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const SetupIntroScreen(),
      ),
      GoRoute(
        path: '/setup/2',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const SetupPackagesScreen(),
      ),
      GoRoute(
        path: '/work/calendar',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const MyCalendarScreen(),
      ),
      GoRoute(
        path: '/setup/3',
        builder: (_, _) => const SkillsScreen(mode: SkillsMode.setup),
      ),
      GoRoute(
        path: '/profile/skills',
        builder: (_, _) => const SkillsScreen(mode: SkillsMode.edit),
      ),
      GoRoute(
        path: '/profile/skills/evidence',
        builder: (_, state) => SkillsScreen(
          mode: SkillsMode.edit,
          openEvidenceFor: state.uri.queryParameters['skill'],
        ),
      ),
      GoRoute(path: '/setup/4', builder: (_, _) => const ContactSetupScreen()),
      GoRoute(
        path: '/p/:postId',
        builder: (_, state) =>
            PhotoDetailScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/u/:uid',
        builder: (_, state) => PhotographerProfileScreen(
          uid: state.pathParameters['uid']!,
          initialSection: profileSectionFromQuery(
            state.uri.queryParameters['tab'],
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TabShell(shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.home.path,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.explore.path,
                builder: (_, _) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.action.path,
                builder: (_, state) => ActionTab(
                  specialty: state.uri.queryParameters['specialty'],
                  style: state.uri.queryParameters['style'],
                  area: state.uri.queryParameters['area'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.bookings.path,
                builder: (_, _) => const BookingsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.profile.path,
                builder: (_, _) => const ProfileTab(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

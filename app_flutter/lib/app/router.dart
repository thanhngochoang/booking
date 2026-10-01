import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/features/auth/login_screen.dart';
import 'package:photobooking/features/auth/register_screen.dart';
import 'package:photobooking/features/onboarding/role_screen.dart';
import 'package:photobooking/features/onboarding/session_error_screen.dart';
import 'package:photobooking/features/onboarding/splash_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/features/shell/tab_shell.dart';

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
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TabShell(shell),
        branches: [
          for (final (tab, page) in [
            (AppTab.home, const HomeTab()),
            (AppTab.explore, const ExploreTab()),
            (AppTab.action, const ActionTab()),
            (AppTab.bookings, const BookingsTab()),
            (AppTab.profile, const ProfileTab()),
          ])
            StatefulShellBranch(
              routes: [GoRoute(path: tab.path, builder: (_, _) => page)],
            ),
        ],
      ),
    ],
  );
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/onboarding/role_screen.dart';
import '../features/shell/placeholder_tabs.dart';
import '../features/shell/tab_shell.dart';
import 'tabs.dart';

const _authRoutes = {'/login', '/register'};
const _onboardingRoute = '/onboarding/role';

/// Pure redirect rule; see router_test.dart.
String? computeRedirect({
  required bool signedIn,
  required bool profileLoaded,
  required bool needsRole,
  required String location,
}) {
  final onAuth = _authRoutes.contains(location);
  if (!signedIn) return onAuth ? null : '/login';
  if (!profileLoaded) return null;
  if (needsRole) return location == _onboardingRoute ? null : _onboardingRoute;
  if (onAuth || location == _onboardingRoute) return AppTab.home.path;
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
    final profileLoaded = !signedIn || (profile.hasValue && profile.value != null);
    return computeRedirect(
      signedIn: signedIn,
      profileLoaded: profileLoaded,
      needsRole: profile.value?.needsRole ?? false,
      location: state.matchedLocation,
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
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: _onboardingRoute, builder: (_, _) => const RoleScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TabShell(shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.home.path, builder: (_, _) => const HomeTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.explore.path, builder: (_, _) => const ExploreTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.action.path, builder: (_, _) => const ActionTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.bookings.path, builder: (_, _) => const BookingsTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.profile.path, builder: (_, _) => const ProfileTab()),
            ],
          ),
        ],
      ),
    ],
  );
});

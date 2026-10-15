import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';

class RoleController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> choose(UserRole role) async {
    // Synchronous read: the auth stream may be paused when nobody listens.
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).setRole(uid, role),
    );
  }
}

final roleControllerProvider = AsyncNotifierProvider<RoleController, void>(
  RoleController.new,
);

/// Switching mode from the profile tab. Its value is the role just applied
/// (null until the first switch), so the UI can confirm the right mode
/// without waiting for the profile stream.
class RoleSwitchController extends AsyncNotifier<UserRole?> {
  @override
  UserRole? build() => null;

  Future<void> switchTo(UserRole role) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(userRepositoryProvider).setRole(uid, role);
      return role;
    });
  }
}

final roleSwitchControllerProvider =
    AsyncNotifierProvider<RoleSwitchController, UserRole?>(
      RoleSwitchController.new,
    );

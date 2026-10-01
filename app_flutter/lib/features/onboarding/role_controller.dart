import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/auth_providers.dart';
import '../../data/user/user_profile.dart';

class RoleController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> choose(UserRole role) async {
    // Await the stream: on a fresh provider the first value is not in yet.
    final uid = (await ref.read(authStateProvider.future))?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(userRepositoryProvider).setRole(uid, role),
    );
  }
}

final roleControllerProvider =
    AsyncNotifierProvider<RoleController, void>(RoleController.new);

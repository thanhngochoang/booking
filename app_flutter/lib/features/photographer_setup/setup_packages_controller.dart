import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';

/// Writes the photographer's packages from S08.01 step 2. Each call answers
/// whether it went through; the screen shows the message.
class SetupPackagesController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> add(ServicePackageInput input) => _run((repo, uid) async {
    await repo.add(uid, input);
    await ref.read(setupDraftStoreProvider).clearPackage(uid);
  });

  Future<bool> save(String id, ServicePackageInput input) =>
      _run((repo, uid) async {
        await repo.update(uid, id, input);
        await ref.read(setupDraftStoreProvider).clearPackage(uid);
      });

  Future<bool> hide(String id) => _run((repo, uid) => repo.hide(uid, id));

  Future<bool> _run(
    Future<void> Function(ServicePackageRepository repo, String uid) job,
  ) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return false;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => job(ref.read(servicePackageRepositoryProvider), uid),
    );
    return !state.hasError;
  }
}

final setupPackagesControllerProvider =
    AsyncNotifierProvider.autoDispose<SetupPackagesController, void>(
      SetupPackagesController.new,
    );

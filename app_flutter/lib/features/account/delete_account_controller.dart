import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/account/account_repository.dart';

final deleteAccountControllerProvider =
    AsyncNotifierProvider<DeleteAccountController, List<DeletionBlocker>>(
  DeleteAccountController.new,
);

class DeleteAccountController extends AsyncNotifier<List<DeletionBlocker>> {
  @override
  Future<List<DeletionBlocker>> build() async {
    final repo = ref.watch(accountRepositoryProvider);
    return repo.deletionBlockers();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<DateTime> requestDeletion() async {
    final repo = ref.read(accountRepositoryProvider);
    return repo.requestDeletion();
  }
}

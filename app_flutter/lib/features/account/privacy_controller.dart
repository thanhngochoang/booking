import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/account/account_providers.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';

final privacyControllerProvider =
    NotifierProvider<PrivacyController, AsyncValue<void>>(
  PrivacyController.new,
);

class PrivacyController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> setHidden(bool hidden) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final repo = ref.read(accountRepositoryProvider);
    state = const AsyncValue.loading();
    try {
      await repo.setHiddenFromDiscovery(uid, hidden);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<DataExport> requestExport() async {
    final repo = ref.read(accountRepositoryProvider);
    return repo.requestExport();
  }

  Future<Uri> downloadUrl(String path) async {
    final repo = ref.read(accountRepositoryProvider);
    return repo.exportDownloadUrl(path);
  }
}

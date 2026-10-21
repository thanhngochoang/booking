import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/account/account_providers.dart';

final restoreAccountControllerProvider =
    NotifierProvider<RestoreAccountController, AsyncValue<void>>(
  RestoreAccountController.new,
);

class RestoreAccountController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> restore() async {
    final repo = ref.read(accountRepositoryProvider);
    state = const AsyncValue.loading();
    try {
      await repo.restore();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

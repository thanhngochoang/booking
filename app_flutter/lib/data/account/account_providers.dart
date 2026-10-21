import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/account/firebase_account_repository.dart';
import 'package:photobooking/data/auth/auth_providers.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return FirebaseAccountRepository();
});

final accountLockProvider = StreamProvider<AccountLock?>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield null;
    return;
  }
  yield* ref.watch(accountRepositoryProvider).watchLock(user.uid);
});

final dataExportProvider = StreamProvider<DataExport?>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield null;
    return;
  }
  yield* ref.watch(accountRepositoryProvider).watchExport(user.uid);
});

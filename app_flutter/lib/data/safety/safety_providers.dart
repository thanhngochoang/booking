import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/safety/firestore_safety_repository.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_repository.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  return FirestoreSafetyRepository(uid: authUser?.uid);
});

final blockIndexProvider = StreamProvider<BlockIndex>((ref) {
  final repo = ref.watch(safetyRepositoryProvider);
  return repo.watchIndex();
});

final hiddenUsersProvider = Provider<Set<String>>((ref) {
  final index = ref.watch(blockIndexProvider).value;
  return index?.hidden ?? const {};
});

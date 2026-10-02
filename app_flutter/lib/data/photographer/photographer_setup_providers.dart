import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/firestore_photographer_intro_repository.dart';
import 'package:photobooking/data/photographer/firestore_service_package_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/service_package.dart';

final photographerIntroRepositoryProvider =
    Provider<PhotographerIntroRepository>(
      (ref) => FirestorePhotographerIntroRepository(),
    );

final servicePackageRepositoryProvider = Provider<ServicePackageRepository>(
  (ref) => FirestoreServicePackageRepository(),
);

/// The signed-in photographer's own intro (S30 setup card). Own-profile
/// data, the one kind of listener allowed to live as long as the tab shell.
final myIntroProvider = StreamProvider.autoDispose<PhotographerIntro?>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return Stream.value(null);
  }
  return ref.watch(photographerIntroRepositoryProvider).watch(uid);
});

/// The signed-in photographer's packages, while S24 step 2 is open.
final myPackagesProvider = StreamProvider.autoDispose<List<ServicePackage>>((
  ref,
) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return Stream.value(const []);
  }
  return ref.watch(servicePackageRepositoryProvider).watchMine(uid);
});

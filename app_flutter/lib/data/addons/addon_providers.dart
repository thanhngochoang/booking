import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/addons/addon_repository.dart';
import 'package:photobooking/data/addons/firestore_addon_repository.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/auth/auth_providers.dart';

final addonRepositoryProvider = Provider<AddonRepository>(
  (ref) => FirestoreAddonRepository(),
);

/// Active add-ons of a photographer, read once (S04.01). A change before
/// payment is caught by the server's `addon_changed`.
final activeAddonsProvider = FutureProvider.autoDispose
    .family<List<ServiceAddon>, String>(
      (ref, providerId) =>
          ref.watch(addonRepositoryProvider).activeFor(providerId),
    );

/// The signed-in photographer's own add-ons, live (S08.06); empty when signed
/// out.
final myAddonsProvider = StreamProvider.autoDispose<List<ServiceAddon>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const <ServiceAddon>[]);
  return ref.watch(addonRepositoryProvider).watchMine(uid);
});

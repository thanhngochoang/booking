import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';

/// The type stored on the signed-in photographer's profile, the one source
/// S08.01 shows and the save compares against. A failed read is an error, never
/// "individual": deciding on a guess could switch a studio back by accident.
/// No photographer document yet is a known individual.
final storedProviderTypeProvider = FutureProvider.autoDispose<ProviderType>((
  ref,
) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    throw StateError('not signed in');
  }
  final p = await ref.watch(photographerProfileProvider(uid).future);
  return p?.summary.providerType ?? ProviderType.individual;
}, retry: (_, _) => null);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/award/award_providers.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';

/// The type stored on the signed-in photographer's profile, the one source
/// S08.01 shows and the save compares against. Read from the repository on
/// every visit (never the cached S03.01 profile, which can be stale after an
/// award was approved). A failed read is an error, never "individual":
/// deciding on a guess could switch a studio back by accident. No
/// photographer document yet is a known individual.
final storedProviderTypeProvider = FutureProvider.autoDispose<ProviderType>((
  ref,
) async {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    throw StateError('not signed in');
  }
  final p = await ref.watch(publicProfileRepositoryProvider).load(uid);
  return p?.summary.providerType ?? ProviderType.individual;
}, retry: (_, _) => null);

/// The signed-in photographer's type as the app shows it elsewhere (Settings,
/// the awards nudge): the live tier when it is known, so an award approved
/// mid-session shows at once, else the profile read. A missing profile is a
/// known individual; loading and error stay distinct.
final liveProviderTypeProvider = Provider.autoDispose<AsyncValue<ProviderType>>(
  (ref) {
    final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return AsyncError(StateError('not signed in'), StackTrace.empty);
    }
    final tier = ref.watch(myTierProvider).value;
    if (tier != null) {
      return AsyncData(tier.providerType);
    }
    return ref
        .watch(photographerProfileProvider(uid))
        .whenData((p) => p?.summary.providerType ?? ProviderType.individual);
  },
);

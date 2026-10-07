import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/badges/badge.dart';
import 'package:photobooking/data/badges/badge_repository.dart';
import 'package:photobooking/data/badges/badges_seen_store.dart';
import 'package:photobooking/data/badges/firestore_badge_repository.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';

final badgeRepositoryProvider = Provider<BadgeRepository>(
  (ref) => FirestoreBadgeRepository(),
);

/// The catalogue, read once per app run.
final badgeCatalogProvider = FutureProvider<List<BadgeDefinition>>(
  (ref) => ref.watch(badgeRepositoryProvider).catalog(),
);

/// A user's earned badges (public), live.
final earnedBadgesProvider = StreamProvider.autoDispose
    .family<List<EarnedBadge>, String>(
      (ref, uid) => ref.watch(badgeRepositoryProvider).watchEarned(uid),
    );

/// The signed-in user's own progress; empty when signed out.
final myBadgeProgressProvider =
    StreamProvider.autoDispose<Map<String, BadgeProgressEntry>>((ref) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) {
        return Stream.value(const <String, BadgeProgressEntry>{});
      }
      return ref.watch(badgeRepositoryProvider).watchProgress(uid);
    });

final badgesSeenStoreProvider = Provider<BadgesSeenStore>(
  (ref) => BadgesSeenStore(ref.watch(sharedPreferencesProvider)),
);

/// Earned badges of [uid] as chips: catalogue order, label `shortName ?? name`.
/// The chip code is the catalogue icon key.
final badgeChipsProvider = Provider.autoDispose
    .family<AsyncValue<List<BadgeView>>, String>((ref, uid) {
      final catalog = ref.watch(badgeCatalogProvider);
      final earned = ref.watch(earnedBadgesProvider(uid));
      if (catalog.hasError) {
        return AsyncError(catalog.error!, catalog.stackTrace!);
      }
      if (earned.hasError) {
        return AsyncError(earned.error!, earned.stackTrace!);
      }
      final defs = catalog.value;
      final mine = earned.value;
      if (defs == null || mine == null) {
        return const AsyncLoading();
      }
      final ids = {for (final e in mine) e.badgeId};
      final sorted = defs.where((d) => ids.contains(d.id)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return AsyncData([
        for (final d in sorted)
          BadgeView(
            code: d.icon,
            name: d.label,
            condition: d.description,
            earned: true,
          ),
      ]);
    });

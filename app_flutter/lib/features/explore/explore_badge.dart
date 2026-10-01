import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

/// When the viewer last opened the Explore tab (spec 3d.3).
class ExploreSeenAtController extends Notifier<DateTime?> {
  static const key = 'exploreSeenAt';

  @override
  DateTime? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> markSeen() async {
    final now = ref.read(clockProvider)();
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(key, now.toIso8601String());
    } on Object {
      return; // keep the old marker; the badge simply stays
    }
    if (ref.mounted) {
      state = now;
    }
  }
}

final exploreSeenAtProvider =
    NotifierProvider<ExploreSeenAtController, DateTime?>(
      ExploreSeenAtController.new,
    );

/// New events since the last visit: inside the 25 km cells of the current
/// origin, or everywhere while there is no location or area. At most 10, so
/// `TabBadge` shows "9+".
final exploreBadgeCountProvider = FutureProvider<int>((ref) {
  final seenAt = ref.watch(exploreSeenAtProvider);
  final origin = ref.watch(exploreResolutionProvider.select((r) => r.origin));
  final cells = origin == null
      ? null
      : (() {
          final q = geohashQueryFor(25);
          return geohashCells(origin.cellPrefix(q.precision), rings: q.rings);
        })();
  return ref
      .watch(nearbyEventsRepositoryProvider)
      .countCreatedSince(cells: cells, since: seenAt);
});

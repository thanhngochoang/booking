// lib/data/spots/spot_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/spots/firestore_spot_repository.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_repository.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/features/explore/location_controller.dart';

final spotRepositoryProvider = Provider<SpotRepository>(
  (ref) => FirestoreSpotRepository(),
);

final spotRegionProvider = Provider<String>((ref) {
  final loc = ref.watch(locationControllerProvider);
  return regionForLocation(
    areaId: loc.area?.id,
    lat: loc.location?.lat,
    lng: loc.location?.lng,
  );
});

/// Region ranking entries; cached per session (not autoDispose).
final hotSpotsProvider =
    FutureProvider.family<List<SpotEntry>, String>((ref, key) async {
  final repo = ref.watch(spotRepositoryProvider);
  return repo.hot(key);
});

/// All active spots; cached per session (not autoDispose).
final spotDirectoryProvider = FutureProvider<List<SpotEntry>>((ref) async {
  final repo = ref.watch(spotRepositoryProvider);
  return repo.directory();
});

final spotProvider = FutureProvider.autoDispose.family<Spot?, String>(
  (ref, spotId) async {
    final repo = ref.watch(spotRepositoryProvider);
    return repo.spot(spotId);
  },
);

final spotSchedulesAtProvider =
    FutureProvider.autoDispose.family<List<SpotSchedule>, String>(
  (ref, spotId) async {
    final repo = ref.watch(spotRepositoryProvider);
    return repo.openSchedulesAt(spotId);
  },
);

final spotOffersAtProvider =
    FutureProvider.autoDispose.family<List<SlotOffer>, String>(
  (ref, spotId) async {
    final repo = ref.watch(spotRepositoryProvider);
    return repo.openOffersAt(spotId);
  },
);

final spotDayProvider =
    FutureProvider.autoDispose.family<SpotDay?, ({String scheduleId, String day})>(
  (ref, arg) async {
    final repo = ref.watch(spotRepositoryProvider);
    return repo.spotDay(arg.scheduleId, arg.day);
  },
);

final spotEventsProvider =
    FutureProvider.autoDispose.family<List<EventSummary>, String>(
  (ref, spotId) async {
    final repo = ref.watch(spotRepositoryProvider);
    return repo.eventsAt(spotId);
  },
);

final mySpotSchedulesProvider =
    StreamProvider.autoDispose.family<List<SpotSchedule>, String>(
  (ref, uid) {
    final repo = ref.watch(spotRepositoryProvider);
    return repo.watchMine(uid);
  },
);

final mySlotOffersProvider =
    StreamProvider.autoDispose.family<List<SlotOffer>, String>(
  (ref, uid) {
    final repo = ref.watch(spotRepositoryProvider);
    return repo.watchMyOffers(uid);
  },
);

final spotPhotographerSummariesProvider =
    FutureProvider.autoDispose.family<Map<String, PhotographerSummary>, String>(
  (ref, key) async {
    if (key.isEmpty) return const {};
    final uids = key.split(',').where((id) => id.isNotEmpty).toList();
    final repo = ref.watch(photographerRepositoryProvider);
    return repo.summaries(uids);
  },
);



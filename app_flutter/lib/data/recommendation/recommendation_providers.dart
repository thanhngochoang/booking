import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/firestore_availability_lookup.dart';
import 'package:photobooking/data/recommendation/local_recommender.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';

final availabilityLookupProvider = Provider<AvailabilityLookup>(
  (ref) => FirestoreAvailabilityLookup(),
);

/// The on-device ranking. Kept separate so the remote wiring in step 3r can use
/// it as the fallback.
final localRecommenderProvider = Provider<LocalRecommender>(
  (ref) => LocalRecommender(
    posts: ref.watch(postRepositoryProvider),
    photographers: ref.watch(photographerRepositoryProvider),
    availability: ref.watch(availabilityLookupProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// What screens use. Until the recommender service exists this is the local
/// ranking.
final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => ref.watch(localRecommenderProvider),
);

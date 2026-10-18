import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';
import 'package:photobooking/data/delivery/firestore_delivery_repository.dart';
import 'package:photobooking/data/media/media_providers.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => FirestoreDeliveryRepository(
    uploader: ref.watch(mediaUploaderProvider),
    urlResolver: ref.watch(mediaUrlResolverProvider),
  ),
);

final deliveryRoundsProvider =
    StreamProvider.autoDispose.family<List<DeliveryRound>, String>(
  (ref, bookingId) =>
      ref.watch(deliveryRepositoryProvider).watchRounds(bookingId),
);

final deliveryLinkProvider =
    StreamProvider.autoDispose.family<DeliveryLink?, String>(
  (ref, bookingId) =>
      ref.watch(deliveryRepositoryProvider).watchLink(bookingId),
);

final stagedSamplesProvider =
    StreamProvider.autoDispose.family<List<StagedSample>, String>(
  (ref, bookingId) =>
      ref.watch(deliveryRepositoryProvider).watchStagedSamples(bookingId),
);

final deliveryImageUrlProvider =
    FutureProvider.autoDispose.family<String, String>(
  (ref, storagePath) =>
      ref.watch(deliveryRepositoryProvider).imageUrl(storagePath),
);

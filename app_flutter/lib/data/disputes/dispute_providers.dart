import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_repository.dart';
import 'package:photobooking/data/disputes/firestore_dispute_repository.dart';
import 'package:photobooking/data/media/media_providers.dart';

/// Rebuilt when the signed-in user changes (evidence paths and `mine` follow
/// it).
final disputeRepositoryProvider = Provider<DisputeRepository>((ref) {
  return FirestoreDisputeRepository(
    uid: ref.watch(authStateProvider).value?.uid,
    uploader: ref.watch(mediaUploaderProvider),
    urls: ref.watch(mediaUrlResolverProvider),
  );
});

/// One dispute, live (S18.02); null when missing or not mine.
final disputeProvider = StreamProvider.autoDispose.family<Dispute?, String>(
  (ref, id) => ref.watch(disputeRepositoryProvider).watch(id),
);

/// My latest disputes for S18.03 (one `get`).
final myDisputesProvider = FutureProvider.autoDispose<List<Dispute>>(
  (ref) => ref.watch(disputeRepositoryProvider).mine(),
);

/// A download URL for one evidence path.
final evidenceUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(disputeRepositoryProvider).evidenceUrl(path),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_repository.dart';
import 'package:photobooking/data/earnings/firestore_earnings_repository.dart';

final earningsRepositoryProvider = Provider<EarningsRepository>(
  (ref) => FirestoreEarningsRepository(),
);

/// The signed-in photographer's totals; all zero when signed out.
final earningsSummaryProvider = StreamProvider.autoDispose<EarningsSummary>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const EarningsSummary());
  return ref.watch(earningsRepositoryProvider).watchSummary(uid);
});

/// Earnings rows, newest first; the argument is the row limit.
final earningItemsProvider = StreamProvider.autoDispose
    .family<List<EarningItem>, int>((ref, limit) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return Stream.value(const <EarningItem>[]);
      return ref
          .watch(earningsRepositoryProvider)
          .watchItems(uid, limit: limit);
    });

/// The masked payout account; null when signed out or none registered.
final payoutAccountProvider = StreamProvider.autoDispose<PayoutAccountView?>((
  ref,
) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(earningsRepositoryProvider).watchAccount(uid);
});

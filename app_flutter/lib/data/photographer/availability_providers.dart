import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/firestore_availability_repository.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>(
  (ref) => FirestoreAvailabilityRepository(),
);

/// Whose calendar and which month (any day of it).
typedef AvailabilityMonth = ({String uid, DateTime month});

/// The non-free days of one photographer's month. Listens only while a
/// screen shows that month (S20, S03 "Lịch", later S06).
final availabilityMonthProvider = StreamProvider.autoDispose
    .family<Map<DateTime, AvailabilityDay>, AvailabilityMonth>((ref, key) {
      final m = monthOf(key.month);
      return ref
          .watch(availabilityRepositoryProvider)
          .watchRange(key.uid, from: m, to: lastDayOfMonth(m));
    });

/// Today on the Vietnamese calendar; tests override it.
final calendarTodayProvider = Provider<DateTime>(
  (ref) => vnToday(DateTime.now().toUtc()),
);

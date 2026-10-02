import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';

/// Days from [a] to [b] (either order) that are on or after [from] and
/// have no record yet: what a range press may mark off.
List<DateTime> freeDaysBetween(
  DateTime a,
  DateTime b,
  Map<DateTime, AvailabilityDay> known, {
  required DateTime from,
}) => [
  for (final d in daysBetween(a, b))
    if (!d.isBefore(calendarDay(from)) && !known.containsKey(d)) d,
];

/// The three month tabs around [month], kept inside [first]..[last].
List<DateTime> monthWindow(
  DateTime month, {
  required DateTime first,
  required DateTime last,
}) {
  var start = addMonths(monthOf(month), -1);
  if (start.isBefore(monthOf(first))) {
    start = monthOf(first);
  }
  if (addMonths(start, 2).isAfter(monthOf(last))) {
    start = addMonths(monthOf(last), -2);
  }
  return [start, addMonths(start, 1), addMonths(start, 2)];
}

/// Marks days off / frees them for the signed-in photographer (S20).
class CalendarEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// True when saved.
  Future<bool> markOff(List<DateTime> days) =>
      _run((repo, uid) => repo.markOff(uid, days));

  /// True when saved.
  Future<bool> clearOff(List<DateTime> days) =>
      _run((repo, uid) => repo.clearOff(uid, days));

  Future<bool> _run(
    Future<void> Function(AvailabilityRepository repo, String uid) write,
  ) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return false;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => write(ref.read(availabilityRepositoryProvider), uid),
    );
    return !state.hasError;
  }
}

final calendarEditControllerProvider =
    AsyncNotifierProvider.autoDispose<CalendarEditController, void>(
      CalendarEditController.new,
    );

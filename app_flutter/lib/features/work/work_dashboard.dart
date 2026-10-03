// S06.01's view model: the photographer's bookings folded into the
// dashboard numbers at the current minute.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';

/// How often the dashboard re-reads the clock: a request leaves the list
/// within a minute of its deadline (the cards' countdowns tick on their own).
const workTick = Duration(minutes: 1);

/// [WorkDashboard] of the signed-in photographer, live from the stream and
/// recomputed every [workTick].
final workDashboardProvider = Provider.autoDispose<AsyncValue<WorkDashboard>>((
  ref,
) {
  final mine = ref.watch(myBookingsProvider(BookingRole.photographer));
  final now =
      ref.watch(nowTickerProvider(workTick)).value ?? ref.read(clockProvider)();
  return mine.whenData((list) => workDashboard(list, now));
});

/// Requests waiting for the signed-in photographer's answer: the work tab's
/// badge, the same count as S06.01's "Yêu cầu mới". Zero for customers.
final workRequestCountProvider = Provider.autoDispose<int>((ref) {
  final role = ref.watch(currentProfileProvider).value?.role;
  if (role != UserRole.photographer) return 0;
  return ref.watch(workDashboardProvider).value?.requests.length ?? 0;
});

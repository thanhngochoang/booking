// lib/features/spots/spot_schedule_edit_controller.dart
// S29.04: the form behind "Thêm / sửa lịch tại điểm". Days, window and
// packages are checked on the device against the holder's own availability
// (conflicts in red before submit); the server's `day_conflict` and
// `schedule_has_bookings` details then override them.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_repository.dart';
import 'package:photobooking/data/spots/spot_rules.dart';

/// Domain limits (`spot_schedule.ts`, spec §5.1).
const int kSpotScheduleMaxDays = 40;
const int kSpotScheduleDaysAhead = 60;
const int kSpotScheduleMaxOpen = 8;
const String kSpotWindowEarliest = '05:00';
const String kSpotWindowLatest = '21:00';
const int kSpotWindowMinMinutes = 60;
const int kSpotWindowMaxMinutes = 720;
const int kSpotWindowStepMinutes = 15;

/// The day key [days] after the Vietnamese calendar day [day].
String _plusDays(DateTime day, int days) =>
    dayKeyOf(DateTime.utc(day.year, day.month, day.day + days));

/// Whether [window] is on the 15-minute grid, inside 05:00–21:00 and 1–12 h.
bool spotWindowValid(SpotWindow window) {
  final start = minutesOfTime(window.start);
  final end = minutesOfTime(window.end);
  final length = end - start;
  return start % kSpotWindowStepMinutes == 0 &&
      end % kSpotWindowStepMinutes == 0 &&
      start >= minutesOfTime(kSpotWindowEarliest) &&
      end <= minutesOfTime(kSpotWindowLatest) &&
      length >= kSpotWindowMinMinutes &&
      length <= kSpotWindowMaxMinutes;
}

/// The non-free days of [uid] from today (Vietnam) to the last day a
/// schedule may hold: the S29.04 conflict source.
final spotHolderAvailabilityProvider = StreamProvider.autoDispose
    .family<Map<DateTime, AvailabilityDay>, String>((ref, uid) {
      final today = vnToday(ref.watch(clockProvider)());
      return ref
          .watch(availabilityRepositoryProvider)
          .watchRange(
            uid,
            from: today,
            to: today.add(const Duration(days: kSpotScheduleDaysAhead)),
          );
    });

/// What S29.04 edits: an [existing] schedule, or a new one (on [spotId] when
/// opened from a spot page). [studio] names a member for the spot days.
@immutable
class SpotScheduleEditArgs {
  const SpotScheduleEditArgs({this.existing, this.spotId, this.studio = false});

  final SpotSchedule? existing;
  final String? spotId;
  final bool studio;

  @override
  bool operator ==(Object other) =>
      other is SpotScheduleEditArgs &&
      other.existing == existing &&
      other.spotId == spotId &&
      other.studio == studio;

  @override
  int get hashCode => Object.hash(existing, spotId, studio);
}

enum SpotScheduleMode { repeat, pick }

enum SpotSchedulePhase { idle, saving, done }

/// Why the form cannot be sent, mapped to a message by the screen.
enum SpotScheduleFailure {
  spotRequired,
  memberRequired,
  noDays,
  tooMany,
  windowInvalid,
  limit,
  notAccepting,
  memberNotAccepting,
  archived,
  hasBookings,
  noPackages,
  generic,
}

@immutable
class SpotScheduleEditState {
  const SpotScheduleEditState({
    required this.today,
    required this.studio,
    this.scheduleId,
    this.spotId,
    this.spotLocked = false,
    this.mode = SpotScheduleMode.repeat,
    this.weekdays = const {DateTime.saturday, DateTime.sunday},
    required this.from,
    required this.to,
    this.excluded = const {},
    this.picked = const {},
    this.window = const SpotWindow(start: '06:00', end: '11:00'),
    this.serviceIds = const {},
    this.assigneeId,
    this.availability = const AsyncLoading(),
    this.serverConflicts = const {},
    this.bookingCounts = const {},
    this.phase = SpotSchedulePhase.idle,
    this.failure,
  });

  /// Today on the Vietnamese calendar, `yyyy-MM-dd`.
  final String today;
  final bool studio;

  /// Set when editing; [spotId] and [assigneeId] are then fixed.
  final String? scheduleId;
  final String? spotId;
  final bool spotLocked;
  final SpotScheduleMode mode;

  /// "Lặp lại": `DateTime.monday`..`DateTime.sunday` from [from] to [to].
  final Set<int> weekdays;
  final String from;
  final String to;

  /// Repeat days the provider took out (a red day tapped away).
  final Set<String> excluded;

  /// "Chọn ngày".
  final Set<String> picked;
  final SpotWindow window;

  /// Empty = "Mọi gói đang bật".
  final Set<String> serviceIds;
  final String? assigneeId;

  /// The holder's non-free days (the member's for a studio).
  final AsyncValue<Map<DateTime, AvailabilityDay>> availability;

  /// `day_conflict` days from the last refused submit.
  final Map<String, SpotDayConflictReason> serverConflicts;

  /// `schedule_has_bookings` days from the last refused submit.
  final Map<String, int> bookingCounts;
  final SpotSchedulePhase phase;
  final SpotScheduleFailure? failure;

  bool get editing => scheduleId != null;
  bool get saving => phase == SpotSchedulePhase.saving;

  /// The days that would be sent, sorted.
  List<String> get days => mode == SpotScheduleMode.repeat
      ? [
          if (from.compareTo(to) <= 0)
            for (final d in expandWeekly(weekdays, from, to))
              if (!excluded.contains(d)) d,
        ]
      : ([...picked]..sort());

  /// Red days: the holder's own calendar, then what the server answered.
  Map<String, SpotDayConflictReason> get conflicts {
    final list = days;
    final local = switch (availability) {
      AsyncValue(:final value?) => scheduleConflicts(
        list,
        value,
        scheduleId: scheduleId,
      ),
      _ => const <String, SpotDayConflictReason>{},
    };
    return {
      ...local,
      for (final e in serverConflicts.entries)
        if (list.contains(e.key)) e.key: e.value,
    };
  }

  /// The first local rule the form breaks; null when it can be sent.
  SpotScheduleFailure? get problem {
    if (spotId == null) return SpotScheduleFailure.spotRequired;
    if (studio && assigneeId == null) return SpotScheduleFailure.memberRequired;
    final list = days;
    if (list.isEmpty) return SpotScheduleFailure.noDays;
    final last = _plusDays(parseDayKey(today)!, kSpotScheduleDaysAhead);
    if (list.length > kSpotScheduleMaxDays ||
        list.any((d) => d.compareTo(today) < 0 || d.compareTo(last) > 0)) {
      return SpotScheduleFailure.tooMany;
    }
    if (!spotWindowValid(window)) return SpotScheduleFailure.windowInvalid;
    return null;
  }

  SpotScheduleEditState copyWith({
    String? spotId,
    SpotScheduleMode? mode,
    Set<int>? weekdays,
    String? from,
    String? to,
    Set<String>? excluded,
    Set<String>? picked,
    SpotWindow? window,
    Set<String>? serviceIds,
    String? assigneeId,
    AsyncValue<Map<DateTime, AvailabilityDay>>? availability,
    Map<String, SpotDayConflictReason>? serverConflicts,
    Map<String, int>? bookingCounts,
    SpotSchedulePhase? phase,
    Object? failure = _keep,
  }) => SpotScheduleEditState(
    today: today,
    studio: studio,
    scheduleId: scheduleId,
    spotId: spotId ?? this.spotId,
    spotLocked: spotLocked,
    mode: mode ?? this.mode,
    weekdays: weekdays ?? this.weekdays,
    from: from ?? this.from,
    to: to ?? this.to,
    excluded: excluded ?? this.excluded,
    picked: picked ?? this.picked,
    window: window ?? this.window,
    serviceIds: serviceIds ?? this.serviceIds,
    assigneeId: assigneeId ?? this.assigneeId,
    availability: availability ?? this.availability,
    serverConflicts: serverConflicts ?? this.serverConflicts,
    bookingCounts: bookingCounts ?? this.bookingCounts,
    phase: phase ?? this.phase,
    failure: identical(failure, _keep)
        ? this.failure
        : failure as SpotScheduleFailure?,
  );
}

const Object _keep = Object();

class SpotScheduleEditController extends Notifier<SpotScheduleEditState> {
  SpotScheduleEditController(this.args);

  final SpotScheduleEditArgs args;

  late String _uid;
  ProviderSubscription<AsyncValue<Map<DateTime, AvailabilityDay>>>? _days;

  @override
  SpotScheduleEditState build() {
    _uid =
        ref.read(authStateProvider).value?.uid ??
        ref.read(authRepositoryProvider).currentUser?.uid ??
        '';
    final now = ref.read(clockProvider)();
    final todayDate = vnToday(now);
    final today = dayKeyOf(todayDate);
    final s = args.existing;
    final initial = s == null
        ? SpotScheduleEditState(
            today: today,
            studio: args.studio,
            spotId: args.spotId,
            spotLocked: args.spotId != null,
            from: today,
            to: _plusDays(todayDate, 34),
          )
        : SpotScheduleEditState(
            today: today,
            studio: args.studio,
            scheduleId: s.id,
            spotId: s.spotId,
            spotLocked: true,
            mode: SpotScheduleMode.pick,
            from: today,
            to: _plusDays(todayDate, 34),
            picked: {
              for (final d in s.days)
                if (d.compareTo(today) >= 0) d,
            },
            window: s.window,
            serviceIds: {...s.serviceIds},
            assigneeId: s.assigneeId,
          );
    return initial.copyWith(availability: _listenHolder(initial.assigneeId));
  }

  /// Follows the availability of whoever holds the spot days.
  AsyncValue<Map<DateTime, AvailabilityDay>> _listenHolder(String? assignee) {
    _days?.close();
    final holder = assignee ?? _uid;
    final sub = ref.listen(
      spotHolderAvailabilityProvider(holder),
      (_, next) => state = state.copyWith(availability: next),
    );
    _days = sub;
    return sub.read();
  }

  /// Any edit clears the last failure; the server's answers stay until
  /// the day they name is gone.
  void _edit(SpotScheduleEditState next) {
    if (state.saving) return;
    state = next.copyWith(phase: SpotSchedulePhase.idle, failure: null);
  }

  void pickSpot(String spotId) {
    if (state.spotLocked) return;
    _edit(state.copyWith(spotId: spotId));
  }

  void setMode(SpotScheduleMode mode) => _edit(state.copyWith(mode: mode));

  void setWeekdays(Set<int> weekdays) =>
      _edit(state.copyWith(weekdays: {...weekdays}));

  void toggleWeekday(int weekday) {
    final next = {...state.weekdays};
    next.contains(weekday) ? next.remove(weekday) : next.add(weekday);
    setWeekdays(next);
  }

  /// "Từ ngày" / "Tới ngày" of "Lặp lại" (`yyyy-MM-dd`).
  void setRange({String? from, String? to}) =>
      _edit(state.copyWith(from: from, to: to, excluded: const {}));

  /// "Chọn ngày": adds or removes [day]. "Lặp lại": takes a (red) day out
  /// of the repeat, or puts it back.
  void toggleDay(String day) {
    if (state.mode == SpotScheduleMode.pick) {
      final next = {...state.picked};
      next.contains(day) ? next.remove(day) : next.add(day);
      _edit(state.copyWith(picked: next));
    } else {
      final next = {...state.excluded};
      next.contains(day) ? next.remove(day) : next.add(day);
      _edit(state.copyWith(excluded: next));
    }
  }

  void setWindow(SpotWindow window) => _edit(state.copyWith(window: window));

  /// No package ticked means every active package.
  void togglePackage(String serviceId) {
    final next = {...state.serviceIds};
    next.contains(serviceId) ? next.remove(serviceId) : next.add(serviceId);
    _edit(state.copyWith(serviceIds: next));
  }

  /// "Mọi gói đang bật".
  void allPackages() => _edit(state.copyWith(serviceIds: const {}));

  /// A studio's member; fixed once the schedule exists.
  void setAssignee(String memberId) {
    if (state.editing || state.saving || state.assigneeId == memberId) return;
    final availability = _listenHolder(memberId);
    _edit(
      state.copyWith(
        assigneeId: memberId,
        availability: availability,
        serverConflicts: const {},
      ),
    );
  }

  /// Sends the schedule; true when the server took it.
  Future<bool> submit() async {
    final s = state;
    if (s.saving) return false;
    final problem = s.problem;
    if (problem != null) {
      state = s.copyWith(failure: problem);
      return false;
    }
    if (s.conflicts.isNotEmpty) return false;
    state = s.copyWith(phase: SpotSchedulePhase.saving, failure: null);
    try {
      await ref
          .read(spotRepositoryProvider)
          .saveSchedule(
            SpotScheduleInput(
              scheduleId: s.scheduleId,
              spotId: s.spotId!,
              days: s.days,
              window: s.window,
              serviceIds: [...s.serviceIds]..sort(),
              assigneeId: s.studio ? s.assigneeId : null,
            ),
          );
      if (!ref.mounted) return true;
      state = state.copyWith(phase: SpotSchedulePhase.done);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      _refused(spotErrorOf(e));
      return false;
    }
  }

  void _refused(SpotError e) {
    final next = state.copyWith(phase: SpotSchedulePhase.idle);
    state = switch (e.code) {
      SpotErrorCode.dayConflict => next.copyWith(
        serverConflicts: {...next.serverConflicts, ...e.conflicts},
        failure: null,
      ),
      SpotErrorCode.scheduleHasBookings => next.copyWith(
        bookingCounts: e.bookingCounts,
        failure: SpotScheduleFailure.hasBookings,
      ),
      SpotErrorCode.scheduleLimit => next.copyWith(
        failure: SpotScheduleFailure.limit,
      ),
      SpotErrorCode.notAcceptingOrders => next.copyWith(
        failure: e.field == 'assigneeId'
            ? SpotScheduleFailure.memberNotAccepting
            : SpotScheduleFailure.notAccepting,
      ),
      SpotErrorCode.spotArchived => next.copyWith(
        failure: SpotScheduleFailure.archived,
      ),
      SpotErrorCode.invalidArgument => next.copyWith(
        failure: switch (e.field) {
          'days' => SpotScheduleFailure.tooMany,
          'window' => SpotScheduleFailure.windowInvalid,
          'assigneeId' => SpotScheduleFailure.memberRequired,
          'spotId' => SpotScheduleFailure.spotRequired,
          'serviceIds' => SpotScheduleFailure.noPackages,
          _ => SpotScheduleFailure.generic,
        },
      ),
      _ => next.copyWith(failure: SpotScheduleFailure.generic),
    };
  }
}

final spotScheduleEditControllerProvider = NotifierProvider.autoDispose
    .family<
      SpotScheduleEditController,
      SpotScheduleEditState,
      SpotScheduleEditArgs
    >(SpotScheduleEditController.new);

/// Open schedules of the signed-in provider with a day from today: the
/// "{n} / 8" count (`schedule_limit` counts the same).
int openScheduleCount(List<SpotSchedule> schedules, String today) => schedules
    .where((s) => s.open && s.days.any((d) => d.compareTo(today) >= 0))
    .length;

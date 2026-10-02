import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';

/// One non-free day of a photographer (`AvailabilityDay` in the data model).
/// [day] is a calendar day (UTC midnight). `booked` and `pending` carry the
/// booking or event that took the day; only the server writes them.
@immutable
class AvailabilityDay {
  const AvailabilityDay({
    required this.day,
    required this.state,
    this.bookingId,
    this.eventId,
  });

  final DateTime day;
  final DayState state;
  final String? bookingId;
  final String? eventId;

  @override
  bool operator ==(Object other) =>
      other is AvailabilityDay &&
      other.day == day &&
      other.state == state &&
      other.bookingId == bookingId &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(day, state, bookingId, eventId);
}

/// `availability/{uid}/days/{yyyy-MM-dd}` → [AvailabilityDay]. A document
/// whose state the app does not know blocks the day (counted as booked).
AvailabilityDay? availabilityDayFromFirestore(
  String id,
  Map<String, dynamic> d,
) {
  final day = parseDayKey(id);
  if (day == null) {
    return null;
  }
  final state = switch (d['state']) {
    'off' => DayState.off,
    'pending' => DayState.pending,
    _ => DayState.booked,
  };
  final booking = d['bookingId'];
  final event = d['eventId'];
  return AvailabilityDay(
    day: day,
    state: state,
    bookingId: booking is String ? booking : null,
    eventId: event is String ? event : null,
  );
}

/// The only fields a photographer writes on a day (plus the server time).
Map<String, dynamic> offDayToFirestore() => {'state': 'off'};

abstract class AvailabilityRepository {
  /// Non-free days of [uid] from [from] to [to] (calendar days, inclusive):
  /// now, and again after every change.
  Stream<Map<DateTime, AvailabilityDay>> watchRange(
    String uid, {
    required DateTime from,
    required DateTime to,
  });

  /// Marks [days] off. Callers pass free days only: the Firestore adapter
  /// writes every given day and the rules refuse the whole batch if any of
  /// them already has a record; the fake skips days that have a record.
  Future<void> markOff(String uid, Iterable<DateTime> days);

  /// Frees [days] that are off; booked and pending days stay.
  Future<void> clearOff(String uid, Iterable<DateTime> days);
}

class FakeAvailabilityRepository implements AvailabilityRepository {
  FakeAvailabilityRepository({this.failWrites = false, this.failWatch = false});

  bool failWrites;

  /// New [watchRange] streams emit an error instead of days.
  bool failWatch;

  /// Open [watchRange] subscriptions, so tests can prove screens stop listening.
  int watchers = 0;
  int writes = 0;

  final _days = <String, Map<DateTime, AvailabilityDay>>{};
  final _changes = StreamController<String>.broadcast();

  void seed(String uid, AvailabilityDay day) {
    (_days[uid] ??= {})[calendarDay(day.day)] = day;
    _changes.add(uid);
  }

  Map<DateTime, AvailabilityDay> stored(String uid) =>
      Map.unmodifiable(_days[uid] ?? const {});

  Map<DateTime, AvailabilityDay> _slice(
    String uid,
    DateTime from,
    DateTime to,
  ) => {
    for (final e in (_days[uid] ?? const <DateTime, AvailabilityDay>{}).entries)
      if (!e.key.isBefore(calendarDay(from)) && !e.key.isAfter(calendarDay(to)))
        e.key: e.value,
  };

  @override
  Stream<Map<DateTime, AvailabilityDay>> watchRange(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) {
    late final StreamController<Map<DateTime, AvailabilityDay>> out;
    StreamSubscription<String>? inner;
    out = StreamController<Map<DateTime, AvailabilityDay>>(
      onListen: () {
        watchers++;
        if (failWatch) {
          out.addError(StateError('unavailable'));
          return;
        }
        out.add(_slice(uid, from, to));
        inner = _changes.stream
            .where((u) => u == uid)
            .listen((_) => out.add(_slice(uid, from, to)));
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  void _check() {
    if (failWrites) {
      throw StateError('unavailable');
    }
    writes++;
  }

  @override
  Future<void> markOff(String uid, Iterable<DateTime> days) async {
    _check();
    final map = _days[uid] ??= {};
    for (final raw in days) {
      final d = calendarDay(raw);
      map.putIfAbsent(d, () => AvailabilityDay(day: d, state: DayState.off));
    }
    _changes.add(uid);
  }

  @override
  Future<void> clearOff(String uid, Iterable<DateTime> days) async {
    _check();
    final map = _days[uid] ??= {};
    for (final raw in days) {
      final d = calendarDay(raw);
      if (map[d]?.state == DayState.off) {
        map.remove(d);
      }
    }
    _changes.add(uid);
  }
}

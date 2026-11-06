import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/data/pricing/day_pricing.dart';

/// A public holiday from `holidays/{year}` (server-written).
@immutable
class Holiday {
  const Holiday({required this.day, required this.name});

  /// `yyyy-MM-dd`.
  final String day;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is Holiday && other.day == day && other.name == name;

  @override
  int get hashCode => Object.hash(day, name);
}

/// One of the provider's own special ranges, `photographers/{uid}/special_days/{id}`.
/// [from] and [to] are `yyyy-MM-dd`, both inclusive.
@immutable
class SpecialDayRange {
  const SpecialDayRange({
    this.id = '',
    required this.name,
    required this.from,
    required this.to,
  });

  /// Empty for a range that is not saved yet.
  final String id;
  final String name;
  final String from;
  final String to;

  bool get isNew => id.isEmpty;

  SpecialDayRange withId(String id) =>
      SpecialDayRange(id: id, name: name, from: from, to: to);

  @override
  bool operator ==(Object other) =>
      other is SpecialDayRange &&
      other.id == id &&
      other.name == name &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(id, name, from, to);
}

/// The `SpecialDays` a price calculation needs.
SpecialDays specialDaysOf(
  List<Holiday> holidays,
  List<SpecialDayRange> ranges,
) => SpecialDays(
  holidays: [for (final h in holidays) h.day],
  ranges: [for (final r in ranges) (from: r.from, to: r.to)],
);

/// The holidays of one [year] and the provider's own ranges, as loaded for a
/// booking day: the dates to price with and the name to show under a special
/// day.
@immutable
class SpecialDayInfo {
  const SpecialDayInfo({
    required this.year,
    required this.holidays,
    required this.ranges,
  });

  final int year;
  final List<Holiday> holidays;
  final List<SpecialDayRange> ranges;

  SpecialDays get days => specialDaysOf(holidays, ranges);

  /// Name of the holiday on [day], else of the provider's range holding it.
  String? nameOf(String day) {
    for (final h in holidays) {
      if (h.day == day) {
        return h.name;
      }
    }
    for (final r in ranges) {
      if (r.from.compareTo(day) <= 0 && day.compareTo(r.to) <= 0) {
        return r.name;
      }
    }
    return null;
  }
}

/// Public holidays; read-only for clients.
abstract class HolidayRepository {
  /// The year's holidays; empty when the server has none for it.
  Future<List<Holiday>> forYear(int year);
}

/// A provider's own special ranges.
abstract class SpecialDayRepository {
  /// Ranges ordered by `from`; live.
  Stream<List<SpecialDayRange>> watch(String uid);

  /// Creates the range (empty id) or replaces the one with that id.
  Future<void> save(String uid, SpecialDayRange r);
  Future<void> delete(String uid, String id);
}

class FakeHolidayRepository implements HolidayRepository {
  FakeHolidayRepository([Map<int, List<Holiday>> years = const {}])
    : _years = {...years};

  final Map<int, List<Holiday>> _years;
  final requested = <int>[];

  void seed(int year, List<Holiday> days) => _years[year] = days;

  @override
  Future<List<Holiday>> forYear(int year) async {
    requested.add(year);
    return List.unmodifiable(_years[year] ?? const []);
  }
}

class FakeSpecialDayRepository implements SpecialDayRepository {
  FakeSpecialDayRepository({this.failWrites = false});

  bool failWrites;
  int _seq = 0;
  final _ranges = <String, List<SpecialDayRange>>{};
  final _changes = StreamController<String>.broadcast();

  void seed(String uid, SpecialDayRange r) {
    (_ranges[uid] ??= []).add(r);
    _changes.add(uid);
  }

  List<SpecialDayRange> stored(String uid) {
    final list = [...?_ranges[uid]]..sort((a, b) => a.from.compareTo(b.from));
    return List.unmodifiable(list);
  }

  @override
  Stream<List<SpecialDayRange>> watch(String uid) {
    late final StreamController<List<SpecialDayRange>> out;
    StreamSubscription<String>? inner;
    out = StreamController<List<SpecialDayRange>>(
      onListen: () {
        out.add(stored(uid));
        inner = _changes.stream
            .where((u) => u == uid)
            .listen((_) => out.add(stored(uid)));
      },
      onCancel: () async => inner?.cancel(),
    );
    return out.stream;
  }

  void _check() {
    if (failWrites) {
      throw StateError('unavailable');
    }
  }

  @override
  Future<void> save(String uid, SpecialDayRange r) async {
    _check();
    final list = _ranges[uid] ??= [];
    if (r.isNew) {
      list.add(r.withId('sd-${++_seq}'));
    } else {
      final i = list.indexWhere((x) => x.id == r.id);
      if (i < 0) {
        throw StateError('no special day ${r.id}');
      }
      list[i] = r;
    }
    _changes.add(uid);
  }

  @override
  Future<void> delete(String uid, String id) async {
    _check();
    _ranges[uid]?.removeWhere((x) => x.id == id);
    _changes.add(uid);
  }
}

// lib/data/spots/spot_rules.dart
import 'package:photobooking/core/geo.dart';
import 'package:photobooking/core/widgets/availability_calendar.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/spots/spot.dart';

const int spotBookingGapMinutes = 15;

/// Maps an areaId (e.g. 'hcm-q1', 'hn-ba-dinh', 'dn-hai-chau', 'da-lat') to region.
/// Decision 2: null/empty → 'all'. Prefix before first '-' when hcm, hn or dn, else id itself.
String regionOfArea(String? areaId) {
  if (areaId == null || areaId.isEmpty) return 'all';
  final dashIdx = areaId.indexOf('-');
  if (dashIdx > 0) {
    final prefix = areaId.substring(0, dashIdx);
    if (prefix == 'hcm' || prefix == 'hn' || prefix == 'dn') {
      return prefix;
    }
  }
  return areaId;
}

/// Computes region for a location: areaId if set; else nearest built-in area; else 'all'.
String regionForLocation({String? areaId, double? lat, double? lng}) {
  if (areaId != null && areaId.isNotEmpty) {
    return regionOfArea(areaId);
  }
  if (lat != null && lng != null) {
    AreaOption? nearest;
    double minDistance = double.infinity;
    for (final area in builtInAreas) {
      final d = haversineKm(lat, lng, area.lat, area.lng);
      if (d < minDistance) {
        minDistance = d;
        nearest = area;
      }
    }
    if (nearest != null) {
      return regionOfArea(nearest.id);
    }
  }
  return 'all';
}

/// True if [months] is non-empty and contains [month] (1..12).
bool inSeason(List<int> months, int month) {
  return months.isNotEmpty && months.contains(month);
}

/// True if [months] is empty or contains [month].
bool seasonOk(List<int> months, int month) {
  return months.isEmpty || inSeason(months, month);
}

/// Last month of the continuous season run containing [month].
/// Returns null if [month] is not in [months].
/// Wraps 12 → 1.
int? seasonRunEnd(List<int> months, int month) {
  if (!months.contains(month)) return null;

  final set = months.toSet();
  if (set.length == 12) {
    return ((month + 10) % 12) + 1;
  }

  var curr = month;
  while (true) {
    final next = (curr % 12) + 1;
    if (set.contains(next)) {
      curr = next;
    } else {
      break;
    }
  }
  return curr;
}

int minutesOfTime(String t) {
  final parts = t.split(':');
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

String timeOfMinutes(int minutes) {
  final hh = (minutes ~/ 60).toString().padLeft(2, '0');
  final mm = (minutes % 60).toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Returns slots [start, start + slotMinutes] every slotMinutes + gapMinutes
/// from window.start while slot ends <= window.end.
List<({String start, String end})> slotsFor(
  SpotWindow window,
  int slotMinutes,
  int gapMinutes,
) {
  final wStart = minutesOfTime(window.start);
  final wEnd = minutesOfTime(window.end);
  final slots = <({String start, String end})>[];

  var cursor = wStart;
  while (cursor + slotMinutes <= wEnd) {
    slots.add((
      start: timeOfMinutes(cursor),
      end: timeOfMinutes(cursor + slotMinutes),
    ));
    cursor += slotMinutes + gapMinutes;
  }
  return slots;
}

int requiredGap(SpotInterval a, SpotInterval b) {
  if (a.offerId != null && a.offerId == b.offerId) {
    return 0;
  }
  return spotBookingGapMinutes;
}

bool clashes(SpotInterval c, List<SpotInterval> taken) {
  final cStart = minutesOfTime(c.start);
  final cEnd = minutesOfTime(c.end);

  for (final t in taken) {
    final tStart = minutesOfTime(t.start);
    final tEnd = minutesOfTime(t.end);
    final gap = requiredGap(c, t);

    if (cEnd <= tStart) {
      if (tStart - cEnd < gap) return true;
    } else if (tEnd <= cStart) {
      if (cStart - tEnd < gap) return true;
    } else {
      return true;
    }
  }
  return false;
}

/// Candidate start times for a package booking within window, avoiding taken intervals.
List<String> freeStartTimes(
  SpotWindow window,
  int durationMinutes,
  List<SpotInterval> taken, {
  int step = 30,
}) {
  final wStart = minutesOfTime(window.start);
  final wEnd = minutesOfTime(window.end);
  final result = <String>[];

  for (var cursor = wStart; cursor + durationMinutes <= wEnd; cursor += step) {
    final startStr = timeOfMinutes(cursor);
    final endStr = timeOfMinutes(cursor + durationMinutes);
    final candidate = SpotInterval(start: startStr, end: endStr);
    if (!clashes(candidate, taken)) {
      result.add(startStr);
    }
  }
  return result;
}

/// Returns slot offers with their free/taken status.
List<({String start, String end, bool free})> freeSlots(
  SpotWindow window,
  SlotOffer offer,
  List<SpotInterval> taken,
) {
  final slots = slotsFor(window, offer.slotMinutes, offer.gapMinutes);
  return slots.map((s) {
    final iv = SpotInterval(start: s.start, end: s.end, offerId: offer.id);
    return (
      start: s.start,
      end: s.end,
      free: !clashes(iv, taken),
    );
  }).toList();
}

/// Orders spots: pinned first, then hot in season by score, then the rest by distance from origin.
List<SpotEntry> orderSpots(
  List<SpotEntry> all, {
  required int month,
  double? lat,
  double? lng,
}) {
  final pinned = all.where((s) => !s.hidden && s.pinned).toList();

  final hot = all.where((s) {
    if (s.hidden || s.pinned || s.hotScore <= 0) return false;
    return s.seasonMonths.isEmpty || inSeason(s.seasonMonths, month);
  }).toList()
    ..sort((a, b) {
      final scoreCmp = b.hotScore.compareTo(a.hotScore);
      if (scoreCmp != 0) return scoreCmp;
      return a.name.compareTo(b.name);
    });

  final pinnedOrHotIds = <String>{
    ...pinned.map((s) => s.spotId),
    ...hot.map((s) => s.spotId),
  };

  final rest = all.where((s) => !pinnedOrHotIds.contains(s.spotId)).toList();
  if (lat != null && lng != null) {
    rest.sort((a, b) {
      final distA = haversineKm(lat, lng, a.lat, a.lng);
      final distB = haversineKm(lat, lng, b.lat, b.lng);
      final cmp = distA.compareTo(distB);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });
  } else {
    rest.sort((a, b) => a.name.compareTo(b.name));
  }

  return [...pinned, ...hot, ...rest];
}

/// Expands weekly repetition: dates from [from] to [to] (inclusive) where weekday is in [weekdays].
List<String> expandWeekly(Set<int> weekdays, String from, String to) {
  final fromParts = from.split('-').map(int.parse).toList();
  final toParts = to.split('-').map(int.parse).toList();
  var curr = DateTime.utc(fromParts[0], fromParts[1], fromParts[2]);
  final end = DateTime.utc(toParts[0], toParts[1], toParts[2]);

  final result = <String>[];
  while (!curr.isAfter(end)) {
    if (weekdays.contains(curr.weekday)) {
      final y = curr.year.toString().padLeft(4, '0');
      final m = curr.month.toString().padLeft(2, '0');
      final d = curr.day.toString().padLeft(2, '0');
      result.add('$y-$m-$d');
    }
    curr = DateTime.utc(curr.year, curr.month, curr.day + 1);
  }
  return result;
}

enum SpotDayConflictReason { booked, pending, off, spot, full }

/// Reports conflicts for a list of days against own availability.
Map<String, SpotDayConflictReason> scheduleConflicts(
  List<String> days,
  Map<DateTime, AvailabilityDay> mine, {
  String? scheduleId,
}) {
  final conflicts = <String, SpotDayConflictReason>{};

  for (final dayStr in days) {
    final parts = dayStr.split('-').map(int.parse).toList();
    final dt = DateTime.utc(parts[0], parts[1], parts[2]);

    final entry = mine[dt];
    if (entry == null) continue;

    if (entry.scheduleId != null) {
      if (scheduleId != null && entry.scheduleId == scheduleId) {
        continue;
      }
      conflicts[dayStr] = SpotDayConflictReason.spot;
    } else if (entry.rawState == 'spot') {
      if (scheduleId != null && entry.scheduleId == scheduleId) {
        continue;
      }
      conflicts[dayStr] = SpotDayConflictReason.spot;
    } else {
      switch (entry.state) {
        case DayState.off:
          conflicts[dayStr] = SpotDayConflictReason.off;
        case DayState.pending:
          conflicts[dayStr] = SpotDayConflictReason.pending;
        case DayState.booked:
          conflicts[dayStr] = SpotDayConflictReason.booked;
        case DayState.full:
          conflicts[dayStr] = SpotDayConflictReason.full;
        case DayState.free:
          break;
      }
    }
  }

  return conflicts;
}

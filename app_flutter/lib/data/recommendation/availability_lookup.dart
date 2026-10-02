/// A day that is not free. A free day has no document and is absent from the
/// lookup result.
enum DayAvailability { pending, booked, off }

/// Reads the calendar state of many photographers on one day, for ranking and
/// for dropping people who are not free on the day a customer picked.
abstract class AvailabilityLookup {
  /// Keys are the photographer ids that have a non-free state on [dayKey]
  /// (`yyyy-MM-dd`).
  Future<Map<String, DayAvailability>> on(
    String dayKey,
    Iterable<String> photographerIds,
  );
}

class FakeAvailabilityLookup implements AvailabilityLookup {
  final _states = <String, Map<String, DayAvailability>>{};

  /// The id lists passed to [on], one entry per call.
  final List<List<String>> requested = [];
  Object? failWith;

  void set(String photographerId, String dayKey, DayAvailability state) {
    (_states[dayKey] ??= {})[photographerId] = state;
  }

  @override
  Future<Map<String, DayAvailability>> on(
    String dayKey,
    Iterable<String> photographerIds,
  ) async {
    if (failWith != null) {
      throw failWith!;
    }
    final ids = photographerIds.toList();
    requested.add(ids);
    final day = _states[dayKey] ?? const {};
    return {
      for (final id in ids.toSet())
        if (day[id] != null) id: day[id]!,
    };
  }
}

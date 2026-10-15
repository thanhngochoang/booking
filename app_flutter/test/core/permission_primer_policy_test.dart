import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/permission_primer_policy.dart';

class InMemoryPrimerStore implements PrimerStore {
  DateTime? _lastSnoozed;

  @override
  DateTime? get lastSnoozed => _lastSnoozed;

  @override
  Future<void> snooze(DateTime at) async {
    _lastSnoozed = at;
  }
}

void main() {
  group('PermissionPrimerPolicy', () {
    late InMemoryPrimerStore store;
    late DateTime currentTime;

    DateTime now() => currentTime;

    setUp(() {
      store = InMemoryPrimerStore();
      currentTime = DateTime(2026, 10, 1, 10, 0);
    });

    test('never asks at app start', () {
      final policy = PermissionPrimerPolicy(
        store: store,
        now: now,
      );

      expect(policy.shouldAsk(atAppStart: true), isFalse);
    });

    test('asks when never snoozed', () {
      final policy = PermissionPrimerPolicy(
        store: store,
        now: now,
      );

      expect(policy.shouldAsk(atAppStart: false), isTrue);
    });

    test('does not ask within 7 days of later()', () async {
      final policy = PermissionPrimerPolicy(
        store: store,
        now: now,
      );

      await policy.later();

      // Immediately after snooze
      expect(policy.shouldAsk(atAppStart: false), isFalse);

      // Advance by 3 days
      currentTime = currentTime.add(const Duration(days: 3));
      expect(policy.shouldAsk(atAppStart: false), isFalse);

      // Advance by 6 days, 23 hours
      currentTime = currentTime.add(const Duration(days: 3, hours: 23));
      expect(policy.shouldAsk(atAppStart: false), isFalse);
    });

    test('asks again after 7 days', () async {
      final policy = PermissionPrimerPolicy(
        store: store,
        now: now,
      );

      await policy.later();

      // Advance by exactly 7 days
      currentTime = currentTime.add(const Duration(days: 7));
      expect(policy.shouldAsk(atAppStart: false), isTrue);

      // Advance further
      currentTime = currentTime.add(const Duration(days: 2));
      expect(policy.shouldAsk(atAppStart: false), isTrue);
    });
  });
}

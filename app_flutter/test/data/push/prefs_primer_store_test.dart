import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/push/prefs_primer_store.dart';

void main() {
  test('primer store remembers later()', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime.utc(2026, 10, 6, 9);
    final policy = PermissionPrimerPolicy(
      store: PrefsPrimerStore(prefs),
      now: () => now,
    );
    expect(policy.shouldAsk(atAppStart: false), isTrue);

    await policy.later();
    expect(prefs.getInt('notifPrimerLaterAt'), now.millisecondsSinceEpoch);
    expect(policy.shouldAsk(atAppStart: false), isFalse);

    // A fresh store over the same preferences (a new app run) still knows.
    final again = PermissionPrimerPolicy(
      store: PrefsPrimerStore(prefs),
      now: () => now.add(const Duration(days: 6)),
    );
    expect(again.shouldAsk(atAppStart: false), isFalse);
    now = now.add(const Duration(days: 7));
    expect(
      PermissionPrimerPolicy(
        store: PrefsPrimerStore(prefs),
        now: () => now,
      ).shouldAsk(atAppStart: false),
      isTrue,
    );
  });
}

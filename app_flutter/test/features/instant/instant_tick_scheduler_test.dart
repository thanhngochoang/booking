// Decision 6: one timer at a time for the request's next deadline, one tick
// per deadline, once more on app resume; a failing tick is silent. Timers run
// in the widget tester's fake time (no widget is pumped).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_tick_scheduler.dart';

import '../../support/instant_customer_world.dart';

/// The scheduler with a clock that follows the tester's fake time.
class _Harness {
  _Harness(this.tester) {
    scheduler = InstantTickScheduler(tick: _tick, now: () => now);
  }

  final WidgetTester tester;
  DateTime now = instantNow;
  int ticks = 0;
  String? failWith;
  late final InstantTickScheduler scheduler;

  Future<void> _tick() async {
    ticks++;
    final e = failWith;
    if (e != null) throw InstantError(e);
  }

  Future<void> wait(Duration d) async {
    now = now.add(d);
    await tester.pump(d);
  }
}

InstantOfferRow _pending(String id, Duration expiresIn) => InstantOfferRow(
  photographerId: id,
  outcome: OfferOutcome.pending,
  expiresAt: instantNow.add(expiresIn),
);

InstantRequest _searching({
  List<InstantOfferRow> offers = const [],
  Duration deadline = const Duration(minutes: 10),
}) => customerRequestOf(
  status: InstantStatus.searching,
  committed: true,
).copyWith(offers: offers, searchDeadlineAt: instantNow.add(deadline));

void main() {
  testWidgets('tick once 1 s after the last expiry', (tester) async {
    final h = _Harness(tester);
    addTearDown(h.scheduler.dispose);
    h.scheduler.update(
      _searching(
        offers: [
          _pending('p1', const Duration(seconds: 30)),
          _pending('p2', const Duration(seconds: 42)),
        ],
      ),
    );
    await h.wait(const Duration(seconds: 42));
    expect(h.ticks, 0);
    await h.wait(const Duration(seconds: 1));
    expect(h.ticks, 1);
    // The same data: the next deadline is the search window, not a repeat.
    await h.wait(const Duration(minutes: 5));
    expect(h.ticks, 1);
    expect(h.scheduler.hasTimer, isTrue);
    await h.wait(const Duration(minutes: 5));
    expect(h.ticks, 2);
    expect(h.scheduler.hasTimer, isFalse);
  });

  testWidgets('reschedules when the request changes, never two timers', (
    tester,
  ) async {
    final h = _Harness(tester);
    addTearDown(h.scheduler.dispose);
    h.scheduler.update(
      _searching(offers: [_pending('p1', const Duration(seconds: 30))]),
    );
    // A new snapshot: p1 declined, p2 pending to +50 s.
    h.scheduler.update(
      _searching(
        offers: [
          const InstantOfferRow(
            photographerId: 'p1',
            outcome: OfferOutcome.declined,
          ),
          _pending('p2', const Duration(seconds: 50)),
        ],
      ),
    );
    // The old +31 s timer is gone.
    await h.wait(const Duration(seconds: 40));
    expect(h.ticks, 0);
    await h.wait(const Duration(seconds: 11));
    expect(h.ticks, 1);

    // Assigned: no deadline of its own, no timer.
    h.scheduler.update(customerRequestOf(status: InstantStatus.assigned));
    expect(h.scheduler.hasTimer, isFalse);
    await h.wait(const Duration(minutes: 15));
    expect(h.ticks, 1);
  });

  testWidgets('tick on resume', (tester) async {
    final h = _Harness(tester);
    addTearDown(h.scheduler.dispose);
    h.scheduler.update(customerRequestOf(status: InstantStatus.enRoute));
    h.scheduler.onResume();
    await tester.pump();
    expect(h.ticks, 1);

    // A closed request asks for nothing.
    h.scheduler.update(
      customerRequestOf(status: InstantStatus.cancelledByCustomer),
    );
    h.scheduler.onResume();
    await tester.pump();
    expect(h.ticks, 1);
  });

  testWidgets('a failing tick is silent and does not stop the next one', (
    tester,
  ) async {
    // The failure goes to the debug log only; keep it out of the test output.
    final logged = <String?>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add(message);
    try {
      final h = _Harness(tester)..failWith = 'network';
      addTearDown(h.scheduler.dispose);
      h.scheduler.update(
        _searching(
          offers: [_pending('p1', const Duration(seconds: 10))],
          deadline: const Duration(seconds: 30),
        ),
      );
      await h.wait(const Duration(seconds: 11));
      expect(h.ticks, 1);
      expect(tester.takeException(), isNull);
      await h.wait(const Duration(seconds: 19));
      expect(h.ticks, 2);
      expect(logged, hasLength(2));
    } finally {
      debugPrint = print;
    }
  });

  testWidgets('no timer after dispose', (tester) async {
    final h = _Harness(tester);
    h.scheduler.update(
      _searching(offers: [_pending('p1', const Duration(seconds: 10))]),
    );
    expect(h.scheduler.hasTimer, isTrue);
    h.scheduler.dispose();
    expect(h.scheduler.hasTimer, isFalse);
    // Late data after dispose schedules nothing.
    h.scheduler.update(
      _searching(offers: [_pending('p1', const Duration(seconds: 5))]),
    );
    h.scheduler.onResume();
    await h.wait(const Duration(minutes: 11));
    expect(h.ticks, 0);
  });
}

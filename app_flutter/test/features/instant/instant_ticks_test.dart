import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_ticks.dart';

import '../../support/instant_customer_world.dart';

InstantOfferRow _row(String id, OfferOutcome outcome, Duration expiresIn) =>
    InstantOfferRow(
      photographerId: id,
      outcome: outcome,
      expiresAt: instantNow.add(expiresIn),
    );

void main() {
  final now = instantNow;

  test('searching: 1 s after the latest pending expiry', () {
    final r = customerRequestOf(status: InstantStatus.searching).copyWith(
      committed: true,
      searchDeadlineAt: now.add(const Duration(minutes: 10)),
      offers: [
        _row('p1', OfferOutcome.pending, const Duration(seconds: 40)),
        _row('p2', OfferOutcome.pending, const Duration(seconds: 55)),
        // Over already: does not count.
        _row('p3', OfferOutcome.declined, const Duration(seconds: 90)),
      ],
    );
    expect(nextTickDelay(r, now), const Duration(seconds: 56));
  });

  test('searching without pending offers: at searchDeadlineAt', () {
    final r = customerRequestOf(status: InstantStatus.searching).copyWith(
      committed: true,
      searchDeadlineAt: now.add(const Duration(minutes: 7)),
      offers: [_row('p1', OfferOutcome.declined, const Duration(seconds: 40))],
    );
    expect(nextTickDelay(r, now), const Duration(minutes: 7));
  });

  test('searching: the search deadline first when it comes before', () {
    final r = customerRequestOf(status: InstantStatus.searching).copyWith(
      committed: true,
      searchDeadlineAt: now.add(const Duration(seconds: 20)),
      offers: [_row('p1', OfferOutcome.pending, const Duration(seconds: 40))],
    );
    expect(nextTickDelay(r, now), const Duration(seconds: 20));
  });

  test('committed choosing: at searchDeadlineAt', () {
    final r = customerRequestOf(committed: true)
        .copyWith(searchDeadlineAt: now.add(const Duration(minutes: 4)));
    expect(nextTickDelay(r, now), const Duration(minutes: 4));
  });

  test('uncommitted choosing has no deadline of its own', () {
    final r = customerRequestOf().copyWith(
      searchDeadlineAt: now.add(const Duration(minutes: 4)),
    );
    expect(nextTickDelay(r, now), isNull);
  });

  test('in_progress: at shootEndsAt', () {
    final r = customerRequestOf(status: InstantStatus.inProgress).copyWith(
      startedAt: now.subtract(const Duration(minutes: 20)),
      shootEndsAt: now.add(const Duration(minutes: 40)),
    );
    expect(nextTickDelay(r, now), const Duration(minutes: 40));
  });

  test('no deadline → null', () {
    for (final status in InstantStatus.values) {
      final r = customerRequestOf(status: status);
      expect(nextTickDelay(r, now), isNull, reason: status.code);
    }
  });

  test('past deadline → Duration.zero', () {
    final r = customerRequestOf(status: InstantStatus.inProgress)
        .copyWith(shootEndsAt: now.subtract(const Duration(seconds: 5)));
    expect(nextTickDelay(r, now), Duration.zero);
  });

  test('instantTickDeadlines lists every deadline, soonest first', () {
    final r = customerRequestOf(status: InstantStatus.searching).copyWith(
      committed: true,
      searchDeadlineAt: now.add(const Duration(minutes: 10)),
      offers: [_row('p1', OfferOutcome.pending, const Duration(seconds: 40))],
    );
    expect(instantTickDeadlines(r), [
      now.add(const Duration(seconds: 41)),
      now.add(const Duration(minutes: 10)),
    ]);
  });
}

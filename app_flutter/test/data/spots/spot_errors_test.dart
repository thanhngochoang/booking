// test/data/spots/spot_errors_test.dart
import 'dart:io' show SocketException;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/spots/spot_repository.dart';
import 'package:photobooking/data/spots/spot_rules.dart';

void main() {
  group('spotErrorOf', () {
    test('day_conflict details → dayConflict with conflicts {day: reason}', () {
      final exc = FirebaseFunctionsException(
        message: 'day_conflict',
        code: 'failed-precondition',
        details: {
          'code': 'day_conflict',
          'field': 'days',
          'days': [
            {'day': '2026-10-10', 'reason': 'booked'},
            {'day': '2026-10-11', 'reason': 'spot'},
            {'day': '2026-10-12', 'reason': 'off'},
            {'day': '2026-10-13', 'reason': 'pending'},
            {'day': '2026-10-14', 'reason': 'full'},
          ],
        },
      );

      final err = spotErrorOf(exc);
      expect(err.code, SpotErrorCode.dayConflict);
      expect(err.field, 'days');
      expect(err.conflicts['2026-10-10'], SpotDayConflictReason.booked);
      expect(err.conflicts['2026-10-11'], SpotDayConflictReason.spot);
      expect(err.conflicts['2026-10-12'], SpotDayConflictReason.off);
      expect(err.conflicts['2026-10-13'], SpotDayConflictReason.pending);
      expect(err.conflicts['2026-10-14'], SpotDayConflictReason.full);
    });

    test('schedule_has_bookings → bookingCounts {day: n}', () {
      final exc = FirebaseFunctionsException(
        message: 'schedule_has_bookings',
        code: 'failed-precondition',
        details: {
          'code': 'schedule_has_bookings',
          'days': [
            {'day': '2026-10-10', 'count': 2},
            {'day': '2026-10-11', 'count': 1},
          ],
        },
      );

      final err = spotErrorOf(exc);
      expect(err.code, SpotErrorCode.scheduleHasBookings);
      expect(err.bookingCounts['2026-10-10'], 2);
      expect(err.bookingCounts['2026-10-11'], 1);
    });

    test('schedule_limit → scheduleLimit', () {
      final exc = FirebaseFunctionsException(
        message: 'schedule_limit',
        code: 'resource-exhausted',
        details: {'code': 'schedule_limit'},
      );

      final err = spotErrorOf(exc);
      expect(err.code, SpotErrorCode.scheduleLimit);
    });

    test('contact_leak field name', () {
      final exc = FirebaseFunctionsException(
        message: 'contact_leak',
        code: 'invalid-argument',
        details: {'code': 'contact_leak', 'field': 'name'},
      );

      final err = spotErrorOf(exc);
      expect(err.code, SpotErrorCode.contactLeak);
      expect(err.field, 'name');
    });

    test('unavailable → network', () {
      final exc = FirebaseFunctionsException(
        message: 'Service unavailable',
        code: 'unavailable',
      );

      final err = spotErrorOf(exc);
      expect(err.code, SpotErrorCode.network);

      final sock = const SocketException('Connection refused');
      expect(spotErrorOf(sock).code, SpotErrorCode.network);
    });

    test('other error codes map properly', () {
      expect(
        spotErrorOf(FirebaseFunctionsException(message: 'spot_archived', code: 'failed-precondition', details: {'code': 'spot_archived'})).code,
        SpotErrorCode.spotArchived,
      );
      expect(
        spotErrorOf(FirebaseFunctionsException(message: 'limit_exceeded', code: 'failed-precondition', details: {'code': 'limit_exceeded'})).code,
        SpotErrorCode.limitExceeded,
      );
      expect(
        spotErrorOf(FirebaseFunctionsException(message: 'permission_denied', code: 'permission-denied', details: {'code': 'permission_denied'})).code,
        SpotErrorCode.permissionDenied,
      );
      expect(
        spotErrorOf(FirebaseFunctionsException(message: 'not_found', code: 'not-found', details: {'code': 'not_found'})).code,
        SpotErrorCode.notFound,
      );
      expect(
        spotErrorOf(FirebaseFunctionsException(message: 'not_accepting_orders', code: 'failed-precondition', details: {'code': 'not_accepting_orders'})).code,
        SpotErrorCode.notAcceptingOrders,
      );
    });

    test('not_accepting_orders keeps the field (a studio member refused)', () {
      final e = spotErrorOf(
        FirebaseFunctionsException(
          message: 'not_accepting_orders',
          code: 'failed-precondition',
          details: {'code': 'not_accepting_orders', 'field': 'assigneeId'},
        ),
      );
      expect(e.code, SpotErrorCode.notAcceptingOrders);
      expect(e.field, 'assigneeId');
    });

    test('schedule_has_bookings without a field (cancel) keeps the days', () {
      final e = spotErrorOf(
        FirebaseFunctionsException(
          message: 'schedule_has_bookings',
          code: 'failed-precondition',
          details: {
            'code': 'schedule_has_bookings',
            'days': [
              {'day': '2026-10-18', 'count': 2},
            ],
          },
        ),
      );
      expect(e.bookingCounts, {'2026-10-18': 2});
    });
  });
}

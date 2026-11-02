// lib/data/passes/pass_repository.dart
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';

/// The pass alphabet (`TRANSFER_CODE_ALPHABET`, payment_code.ts): no 0, 1, I,
/// L, O, U.
const passAlphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Mirrors the domain `normalizePassCode`: uppercase, strip `VE-` and dashes,
/// 8 characters of [passAlphabet] → the code; anything else → null.
String? normalizePassCode(String raw) {
  var s = raw.trim().toUpperCase();
  if (s.startsWith('VE-')) s = s.substring(3);
  s = s.replaceAll('-', '');
  if (s.length != 8) return null;
  for (final ch in s.split('')) {
    if (!passAlphabet.contains(ch)) return null;
  }
  return s;
}

bool isPassCode(String raw) => normalizePassCode(raw) != null;

/// `VE-XXXX-XXXX`, how a pass is shown under its QR.
String passDisplay(String code8) => code8.length == 8
    ? 'VE-${code8.substring(0, 4)}-${code8.substring(4)}'
    : code8;

/// Which pass: a booking's (`bookings/{id}/private/pass`) or a ticket's
/// (`events/{e}/registrations/{r}/private/pass`). The prefs cache key is
/// `pass.{bookingId|regId}` (Decision 18).
@immutable
class PassRef {
  const PassRef.booking(String this.bookingId) : eventId = null, regId = null;
  const PassRef.registration(String this.eventId, String this.regId)
    : bookingId = null;

  final String? bookingId;
  final String? eventId;
  final String? regId;

  String get cacheKey => 'pass.${bookingId ?? regId}';

  @override
  bool operator ==(Object other) =>
      other is PassRef &&
      other.bookingId == bookingId &&
      other.eventId == eventId &&
      other.regId == regId;

  @override
  int get hashCode => Object.hash(bookingId, eventId, regId);
}

/// What a scan let in, per the scanner's own role (S30.07 result sheet).
enum ScanKind {
  /// An entry ticket at its organizer's gate ("Vào cổng · {n} người").
  entry,

  /// An event ticket checked in by the event's manager.
  event,

  /// An event ticket let in at the venue's gate (managed spot).
  venueGate,
}

@immutable
class ScanBooking {
  const ScanBooking({required this.id, required this.customerName});

  final String id;
  final String customerName;

  @override
  bool operator ==(Object other) =>
      other is ScanBooking &&
      other.id == id &&
      other.customerName == customerName;

  @override
  int get hashCode => Object.hash(id, customerName);
}

@immutable
class ScanRegistration {
  const ScanRegistration({
    required this.id,
    required this.eventTitle,
    required this.quantity,
    required this.kind,
  });

  final String id;
  final String eventTitle;
  final int quantity;
  final ScanKind kind;
}

/// The `scanPass` answer: names, titles and counts, never a phone.
@immutable
class ScanResult {
  const ScanResult({
    this.booking,
    this.registrations = const [],
    this.waivedCount = 0,
    this.todayCount,
  });

  /// The booking the shooter's scan moved to `shooting`.
  final ScanBooking? booking;
  final List<ScanRegistration> registrations;

  /// Head count a resident's waiver let in on a booking pass (gate scan).
  final int waivedCount;

  /// After a gate scan of an entry day: that day's `checkedIn` count.
  final int? todayCount;

  /// People through the gate on this scan (tickets + waived heads).
  int get gateCount =>
      waivedCount +
      registrations
          .where((r) => r.kind != ScanKind.event)
          .fold(0, (n, r) => n + r.quantity);
}

ScanResult scanResultFrom(Object? raw) {
  final m = raw is Map
      ? raw.cast<String, dynamic>()
      : const <String, dynamic>{};
  final b = m['booking'];
  final regs = m['registrations'];
  final waived = m['waived'];
  return ScanResult(
    booking: b is Map && b['id'] is String
        ? ScanBooking(
            id: b['id'] as String,
            customerName: b['customerName'] is String
                ? b['customerName'] as String
                : '',
          )
        : null,
    registrations: [
      if (regs is List)
        for (final r in regs)
          if (r is Map && r['id'] is String)
            ScanRegistration(
              id: r['id'] as String,
              eventTitle: r['eventTitle'] is String
                  ? r['eventTitle'] as String
                  : '',
              quantity: r['quantity'] is num
                  ? (r['quantity'] as num).toInt()
                  : 0,
              kind: switch (r['kind']) {
                'entry' => ScanKind.entry,
                'venue_gate' => ScanKind.venueGate,
                _ => ScanKind.event,
              },
            ),
    ],
    waivedCount: waived is Map && waived['count'] is num
        ? (waived['count'] as num).toInt()
        : 0,
    todayCount: m['todayCount'] is num
        ? (m['todayCount'] as num).toInt()
        : null,
  );
}

enum PassErrorCode {
  notYourPass,
  wrongDay,
  tooEarly,
  alreadyCheckedIn,
  refunded,
  notFound,
  notEligible,
  invalidArgument,
  permissionDenied,
  /// The scanner's refused scans of the hour are spent (final fix D-I3).
  limitExceeded,
  network,
  unknown,
}

/// A refused scan. [day] (`wrong_day`), [opensAt] (`too_early`) and [at]
/// (`already_checked_in`) come from the server's `details` (S30.07 copy:
/// "Vé ngày {day}", "Mở quét từ {time}", "Đã vào lúc {time}").
class PassError implements Exception {
  const PassError(this.code, {this.day, this.opensAt, this.at});

  final PassErrorCode code;
  final String? day;
  final DateTime? opensAt;
  final DateTime? at;

  @override
  String toString() => 'PassError($code)';
}

PassErrorCode passErrorCodeOf(String code) => switch (code) {
  'not_your_pass' => PassErrorCode.notYourPass,
  'wrong_day' => PassErrorCode.wrongDay,
  'too_early' => PassErrorCode.tooEarly,
  'already_checked_in' => PassErrorCode.alreadyCheckedIn,
  'refunded' => PassErrorCode.refunded,
  'not_found' || 'not-found' => PassErrorCode.notFound,
  'not_eligible' => PassErrorCode.notEligible,
  'invalid_argument' || 'invalid-argument' => PassErrorCode.invalidArgument,
  'permission_denied' || 'permission-denied' => PassErrorCode.permissionDenied,
  'limit_exceeded' || 'resource-exhausted' => PassErrorCode.limitExceeded,
  'network' || 'unavailable' || 'deadline-exceeded' => PassErrorCode.network,
  _ => PassErrorCode.unknown,
};

/// Any error of a scan as a [PassError] (S30.07 "Chưa quét được, kiểm tra
/// kết nối" for [PassErrorCode.network]).
PassError passErrorOf(Object error) => switch (error) {
  PassError() => error,
  SocketException() => const PassError(PassErrorCode.network),
  _ => const PassError(PassErrorCode.unknown),
};

abstract class PassRepository {
  /// The customer's booking pass code (8 characters); null before the
  /// payment or for a booking without one (instant, paid before S30).
  Stream<String?> watchBookingPass(String bookingId);

  /// The customer's ticket pass; falls back to the registration's legacy
  /// public `ticketCode` (`VE-XXXX-MMDD`) when there is no private pass.
  Stream<String?> watchRegistrationPass(String eventId, String regId);

  /// S30.07: what the server lets this scanner change; throws [PassError].
  Future<ScanResult> scan(String code);
}

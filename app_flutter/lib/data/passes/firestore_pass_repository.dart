// lib/data/passes/firestore_pass_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/passes/pass_repository.dart';

/// Reads the customer's `private/pass` copies (rules: that customer only;
/// `passes/*` is never readable) and scans through `scanPass`.
class FirestorePassRepository implements PassRepository {
  FirestorePassRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
    : _override = db,
      _functionsOverride = functions;

  final FirebaseFirestore? _override;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  static bool _validId(String id) => id.isNotEmpty && !id.contains('/');

  static String? _code(Map<String, dynamic>? d) {
    final c = d?['code'];
    return c is String && c.isNotEmpty ? c : null;
  }

  /// A missing document read from the local cache says nothing (offline, never
  /// fetched): it is skipped so the prefs cache of `myPassProvider` keeps the
  /// QR on screen.
  static bool _known(DocumentSnapshot<Map<String, dynamic>> s) =>
      s.exists || !s.metadata.isFromCache;

  @override
  Stream<String?> watchBookingPass(String bookingId) {
    if (!_validId(bookingId)) return Stream.value(null);
    return _db
        .collection('bookings')
        .doc(bookingId)
        .collection('private')
        .doc('pass')
        .snapshots()
        .where(_known)
        .map((s) => _code(s.data()));
  }

  @override
  Stream<String?> watchRegistrationPass(String eventId, String regId) {
    if (!_validId(eventId) || !_validId(regId)) return Stream.value(null);
    final reg = _db
        .collection('events')
        .doc(eventId)
        .collection('registrations')
        .doc(regId);
    return reg
        .collection('private')
        .doc('pass')
        .snapshots()
        .where(_known)
        .asyncMap((s) async {
          final code = _code(s.data());
          if (code != null) return code;
          // Decision 8: an old registration keeps its public `ticketCode`.
          final legacy = (await reg.get()).data()?['ticketCode'];
          return legacy is String && legacy.isNotEmpty ? legacy : null;
        });
  }

  @override
  Future<ScanResult> scan(String code) async {
    final send = normalizePassCode(code) ?? code.trim().toUpperCase();
    try {
      final r = await _functions
          .httpsCallable(
            'scanPass',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>({'code': send});
      return scanResultFrom(r.data);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (details is Map && details['code'] is String) {
        DateTime? date(Object? v) =>
            v is String ? DateTime.tryParse(v)?.toUtc() : null;
        throw PassError(
          passErrorCodeOf(details['code'] as String),
          day: details['day'] is String ? details['day'] as String : null,
          opensAt: date(details['opensAt']),
          at: date(details['at']),
        );
      }
      throw PassError(passErrorCodeOf(e.code));
    }
  }
}

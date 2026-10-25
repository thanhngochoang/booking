import 'dart:io' show SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/booking/booking_repository.dart'
    show BookingException;
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';

/// Simulated transfer kind for fake gateway testing (emulator/dev only).
enum FakeTransferKind {
  exact('exact'),
  under('under'),
  over('over'),
  wrongContent('wrong_content');

  const FakeTransferKind(this.code);

  /// Wire code of the callable's `kind`.
  final String code;
}

class PaymentCheck {
  const PaymentCheck({required this.paid, this.instructions});

  final bool paid;
  final PaymentInstructions? instructions;
}

abstract class PaymentsRepository {
  /// confirmFakePayment {paymentId, kind}: returns the outcome code
  /// ('paid', 'partial', 'paid_with_refund', 'needs_review', …).
  Future<String> confirmFake(
    String paymentId, {
    FakeTransferKind kind = FakeTransferKind.exact,
  });

  /// getPaymentInstructions {paymentId}; null when the payment is no longer open.
  Future<PaymentInstructions?> instructions(String paymentId);

  /// The payer's S22.01 rows, newest first, at most [limit]; rows with an
  /// unknown status or subject are kept as generic rows.
  Stream<List<PayerPaymentRow>> watchHistory(String uid, {required int limit});

  /// What is held and being refunded for [uid]; zero while none.
  Stream<PaymentTotals> watchTotals(String uid);

  /// The refund of [subject] waiting for the caller's account choice
  /// (S22.04), or null. Throws [BookingException].
  Future<PendingRefund?> pendingRefund(RefundSubject subject);

  /// Asks the bank for the holder name of another account for [refundId]
  /// (at most 20 tries a day per refund: `limit_exceeded`). Throws
  /// [BookingException] (`not_found`, `not_eligible`, `conflict`, …).
  Future<({String holderName, String bankName, String accountLast4})>
  lookupRefundAccount({
    required String refundId,
    required String bankCode,
    required String accountNumber,
  });

  /// Sends the waiting refund to the paying account or the looked-up one;
  /// returns the refund status (`pending`, `done`, …). A late choice returns
  /// the status the refund already has. Throws [BookingException].
  ///
  /// A [RefundAccountChoice.candidate] choice names the account the customer
  /// was shown ([shown]: bank code and last 4); the server answers
  /// `conflict` when its stored candidate is another account, or when the
  /// refund already went elsewhere (the 24-hour default or another choice).
  Future<String> chooseRefundAccount({
    required String refundId,
    required RefundAccountChoice use,
    ({String bankCode, String accountLast4})? shown,
  });
}

bool _validId(String id) => id.isNotEmpty && !id.contains('/');

/// The stable code of a callable refusal: `details.code`, else the transport
/// code in snake_case (as `firestore_earnings_repository.dart`); `network`
/// when the server could not be reached.
String _codeOf(FirebaseFunctionsException error) {
  final details = error.details;
  if (details is Map && details['code'] is String) {
    return details['code'] as String;
  }
  return switch (error.code) {
    'unavailable' || 'deadline-exceeded' => 'network',
    'unauthenticated' || 'permission-denied' => 'permission_denied',
    'resource-exhausted' => 'limit_exceeded',
    'aborted' => 'conflict',
    final code => code.replaceAll('-', '_'),
  };
}

/// Payments on Firebase: the callables of V1 and S22.04, and the owner-only
/// S22.01 projection (`users/{uid}/payments`, `users/{uid}/private/paymentTotals`).
class FirebasePaymentsRepository implements PaymentsRepository {
  FirebasePaymentsRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functionsOverride = functions,
       _firestoreOverride = firestore;

  final FirebaseFunctions? _functionsOverride;
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: functionsRegion);
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  /// Calls [name]; a refusal or a network failure leaves as a
  /// [BookingException] with its code only. Anything else (a bug) is rethrown
  /// with its stack trace.
  Future<T> _call<T>(String name, Map<String, Object> payload) async {
    try {
      final res = await _functions.httpsCallable(name).call<T>(payload);
      return res.data;
    } on FirebaseFunctionsException catch (e) {
      throw BookingException(_codeOf(e));
    } on SocketException {
      throw const BookingException('network');
    }
  }

  @override
  Future<String> confirmFake(
    String paymentId, {
    FakeTransferKind kind = FakeTransferKind.exact,
  }) async {
    final data = await _call<Map<String, dynamic>>('confirmFakePayment', {
      'paymentId': paymentId,
      'kind': kind.code,
    });
    final outcome = data['outcome'];
    if (outcome is String) return outcome;
    return 'needs_review';
  }

  @override
  Future<PaymentInstructions?> instructions(String paymentId) async {
    final data = await _call<Map<String, dynamic>>('getPaymentInstructions', {
      'paymentId': paymentId,
    });
    return paymentInstructionsFrom(data['instructions']);
  }

  @override
  Stream<List<PayerPaymentRow>> watchHistory(String uid, {required int limit}) {
    if (!_validId(uid)) return Stream.value(const <PayerPaymentRow>[]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => [for (final d in snap.docs) ?payerRowFrom(d.id, d.data())],
        );
  }

  @override
  Stream<PaymentTotals> watchTotals(String uid) {
    if (!_validId(uid)) return Stream.value(const PaymentTotals());
    return _db
        .collection('users')
        .doc(uid)
        .collection('private')
        .doc('paymentTotals')
        .snapshots()
        .map((s) => paymentTotalsFrom(s.data()));
  }

  @override
  Future<PendingRefund?> pendingRefund(RefundSubject subject) async =>
      pendingRefundFrom(await _call<Object?>('pendingRefund', subject.payload));

  @override
  Future<({String holderName, String bankName, String accountLast4})>
  lookupRefundAccount({
    required String refundId,
    required String bankCode,
    required String accountNumber,
  }) async {
    final d = await _call<Object?>('lookupRefundAccount', {
      'refundId': refundId,
      'bankCode': bankCode,
      'accountNumber': accountNumber,
    });
    if (d is! Map ||
        d['holderName'] is! String ||
        d['bankName'] is! String ||
        d['accountLast4'] is! String) {
      throw const BookingException('unknown');
    }
    return (
      holderName: d['holderName'] as String,
      bankName: d['bankName'] as String,
      accountLast4: d['accountLast4'] as String,
    );
  }

  @override
  Future<String> chooseRefundAccount({
    required String refundId,
    required RefundAccountChoice use,
    ({String bankCode, String accountLast4})? shown,
  }) async {
    final d = await _call<Object?>('chooseRefundAccount', {
      'refundId': refundId,
      'use': use.code,
      if (shown != null) ...{
        'bankCode': shown.bankCode,
        'accountLast4': shown.accountLast4,
      },
    });
    final status = d is Map ? d['status'] : null;
    if (status is! String) throw const BookingException('unknown');
    return status;
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => FirebasePaymentsRepository(),
);

/// The signed-in payer's S22.01 rows, newest first; the argument is the row
/// limit. Empty when signed out.
final paymentHistoryProvider = StreamProvider.autoDispose
    .family<List<PayerPaymentRow>, int>((ref, limit) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return Stream.value(const <PayerPaymentRow>[]);
      return ref
          .watch(paymentsRepositoryProvider)
          .watchHistory(uid, limit: limit);
    });

/// The signed-in payer's held and refunding totals; zero when signed out.
final paymentTotalsProvider = StreamProvider.autoDispose<PaymentTotals>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const PaymentTotals());
  return ref.watch(paymentsRepositoryProvider).watchTotals(uid);
});

import 'dart:async';

import 'package:photobooking/data/booking/booking_repository.dart'
    show BookingException;
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/payments/payments_repository.dart';

class FakePaymentsRepository implements PaymentsRepository {
  final List<(String, FakeTransferKind)> confirms = [];
  final Map<String, PaymentInstructions?> instructionsById = {};
  final List<String> instructionCalls = [];
  Future<void> Function(String paymentId, FakeTransferKind kind)? onConfirm;
  Object? nextError;

  void seedInstructions(String paymentId, PaymentInstructions? instructions) {
    instructionsById[paymentId] = instructions;
  }

  @override
  Future<String> confirmFake(
    String paymentId, {
    FakeTransferKind kind = FakeTransferKind.exact,
  }) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      if (err is String) throw BookingException(err);
      throw err;
    }
    confirms.add((paymentId, kind));
    if (onConfirm != null) {
      await onConfirm!(paymentId, kind);
    }
    return switch (kind) {
      FakeTransferKind.exact => 'paid',
      FakeTransferKind.under => 'partial',
      FakeTransferKind.over => 'paid_with_refund',
      FakeTransferKind.wrongContent => 'needs_review',
    };
  }

  @override
  Future<PaymentInstructions?> instructions(String paymentId) async {
    instructionCalls.add(paymentId);
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      if (err is String) throw BookingException(err);
      throw err;
    }
    return instructionsById[paymentId];
  }

  // S22.01 history and totals (#141), per uid.
  final Map<String, List<PayerPaymentRow>> _history = {};
  final Map<String, PaymentTotals> _totals = {};
  final _historyChanges = StreamController<String>.broadcast();
  final _totalsChanges = StreamController<String>.broadcast();

  /// The limit of each [watchHistory] call.
  final List<int> historyLimits = [];

  /// Sets [uid]'s rows (kept newest first, as the query) and tells listeners.
  void emitHistory(String uid, List<PayerPaymentRow> rows) {
    _history[uid] = [...rows]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _historyChanges.add(uid);
  }

  void emitTotals(String uid, PaymentTotals totals) {
    _totals[uid] = totals;
    _totalsChanges.add(uid);
  }

  @override
  Stream<List<PayerPaymentRow>> watchHistory(
    String uid, {
    required int limit,
  }) async* {
    historyLimits.add(limit);
    List<PayerPaymentRow> page() =>
        (_history[uid] ?? const []).take(limit).toList();
    yield page();
    yield* _historyChanges.stream.where((u) => u == uid).map((_) => page());
  }

  @override
  Stream<PaymentTotals> watchTotals(String uid) async* {
    yield _totals[uid] ?? const PaymentTotals();
    yield* _totalsChanges.stream
        .where((u) => u == uid)
        .map((_) => _totals[uid] ?? const PaymentTotals());
  }

  // S22.04 refund account (#141).

  /// What [pendingRefund] answers per subject; absent → null.
  final Map<RefundSubject, PendingRefund> pendingBySubject = {};

  /// Every subject asked for, in order.
  final List<RefundSubject> pendingCalls = [];

  /// Lookup answers keyed `bankCode:accountNumber`; any other key gets
  /// [defaultLookup].
  final Map<String, ({String holderName, String bankName, String accountLast4})>
  lookups = {};
  ({String holderName, String bankName, String accountLast4}) defaultLookup = (
    holderName: 'TRAN VAN B',
    bankName: 'Techcombank',
    accountLast4: '4321',
  );

  /// `refundId:bankCode:last4` of each lookup, failed ones included; never a
  /// full account number.
  final List<String> lookupCalls = [];

  /// `refundId:payer|candidate` of each successful choice.
  final List<String> chooseCalls = [];

  /// The status [chooseRefundAccount] answers.
  String chooseStatus = 'pending';

  Future<void> Function(String refundId, RefundAccountChoice use)? onChoose;

  void _throwNextError() {
    final err = nextError;
    if (err == null) return;
    nextError = null;
    if (err is String) throw BookingException(err);
    throw err;
  }

  @override
  Future<PendingRefund?> pendingRefund(RefundSubject subject) async {
    pendingCalls.add(subject);
    _throwNextError();
    return pendingBySubject[subject];
  }

  @override
  Future<({String holderName, String bankName, String accountLast4})>
  lookupRefundAccount({
    required String refundId,
    required String bankCode,
    required String accountNumber,
  }) async {
    final last4 = accountNumber.length <= 4
        ? accountNumber
        : accountNumber.substring(accountNumber.length - 4);
    lookupCalls.add('$refundId:$bankCode:$last4');
    _throwNextError();
    return lookups['$bankCode:$accountNumber'] ?? defaultLookup;
  }

  @override
  Future<String> chooseRefundAccount({
    required String refundId,
    required RefundAccountChoice use,
  }) async {
    _throwNextError();
    chooseCalls.add('$refundId:${use.code}');
    if (onChoose != null) await onChoose!(refundId, use);
    return chooseStatus;
  }
}

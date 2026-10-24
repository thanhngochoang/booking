import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/core/core.dart';

/// S22.01 row status (`users/{uid}/payments/{id}.status`, Task 6's
/// `PAYER_ROW_STATUSES`).
enum PayerRowStatus {
  held('held'),
  disputed('disputed'),
  released('released'),
  refundAccountNeeded('refund_account_needed'),
  refunding('refunding'),
  refunded('refunded'),
  partiallyRefunded('partially_refunded'),

  /// A code this app does not know yet (the server is newer): the row stays
  /// and renders neutrally from its amount, date and `open`.
  unknown('unknown');

  const PayerRowStatus(this.code);

  /// Wire code written by the server.
  final String code;

  /// [unknown] for a missing or unknown code (the row is kept).
  static PayerRowStatus fromCode(Object? code) =>
      values.where((s) => s.code == code).firstOrNull ?? unknown;
}

/// What a payment paid for (`PaymentSubject` on the server).
enum PayerSubjectType {
  booking('booking'),
  eventRegistration('event_registration'),
  instantRequest('instant_request'),

  /// The S21 identity verification fee, paid to the platform.
  verificationFee('verification_fee'),

  /// A subject this app does not know yet: a generic row, no detail link.
  unknown('unknown');

  const PayerSubjectType(this.code);

  final String code;

  /// [unknown] for a missing or unknown code (the row is kept).
  static PayerSubjectType fromCode(Object? code) =>
      values.where((s) => s.code == code).firstOrNull ?? unknown;
}

/// One refund of a row: the amount, where it goes and whether it arrived.
/// Only the masked destination ever reaches the app.
@immutable
class PayerRefundView {
  const PayerRefundView({
    required this.refundId,
    required this.amount,
    required this.status,
    required this.wallet,
    required this.destinationLabel,
    required this.createdAt,
    this.doneAt,
  });

  final String refundId;
  final int amount;

  /// `awaiting_account` | `pending` | `done` | `failed`.
  final String status;

  /// Paid back through the wallet or gateway the customer paid with (the
  /// row's method names it); false for a bank transfer.
  final bool wallet;

  /// "Vietcombank •••• 6789" for a bank transfer with a chosen account; null
  /// for a wallet or while the account is not chosen yet.
  final String? destinationLabel;
  final DateTime createdAt;
  final DateTime? doneAt;

  /// The money is back with the customer ("đã về"); otherwise "đang xử lý".
  bool get done => status == 'done';
}

/// A payer's S22.01 row (`users/{uid}/payments/{paymentId}`, server-written).
///
/// The title is composed by the screen from the parts that apply to
/// [subjectType]: [photographerName] and [serviceName] (booking),
/// [eventTitle] and [quantity] (ticket), [areaLabel] (Chụp ngay), none for the
/// S21 fee. The server writes no display text.
@immutable
class PayerPaymentRow {
  const PayerPaymentRow({
    required this.paymentId,
    required this.subjectType,
    required this.subjectId,
    this.eventId,
    this.photographerName,
    this.serviceName,
    this.eventTitle,
    this.quantity,
    this.areaLabel,
    this.day,
    this.method,
    required this.amount,
    required this.status,
    required this.open,
    this.toPlatform = false,
    this.heldAmount = 0,
    this.refundingAmount = 0,
    this.refundedAmount = 0,
    this.searching = false,
    this.cancelled = false,
    this.refunds = const [],
    required this.createdAt,
    this.paidAt,
  });

  final String paymentId;
  final PayerSubjectType subjectType;
  final String subjectId;

  /// The event of a ticket row (its registration lives under it).
  final String? eventId;
  final String? photographerName;
  final String? serviceName;
  final String? eventTitle;
  final int? quantity;
  final String? areaLabel;

  /// `yyyy-MM-dd` (Vietnam) of the shoot or the event start; null for Chụp
  /// ngay and the S21 fee (the screen uses [createdAt]).
  final String? day;

  /// Null for legacy payments made before the method was recorded.
  final PayMethod? method;

  /// What the customer sent, in VND.
  final int amount;
  final PayerRowStatus status;

  /// Money still held or on its way back.
  final bool open;

  /// Paid to the platform (S21 fee, platform events): "Đã thanh toán".
  final bool toPlatform;
  final int heldAmount;
  final int refundingAmount;
  final int refundedAmount;

  /// A Chụp ngay request still looking for a photographer.
  final bool searching;

  /// The booking, ticket or request was cancelled.
  final bool cancelled;
  final List<PayerRefundView> refunds;
  final DateTime createdAt;
  final DateTime? paidAt;
}

/// `users/{uid}/private/paymentTotals`: what is held and what is being
/// refunded across every row; a missing document is zero.
@immutable
class PaymentTotals {
  const PaymentTotals({this.held = 0, this.refunding = 0});

  final int held;
  final int refunding;
}

int _int(Object? v) => v is num ? v.toInt() : 0;

String? _strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

DateTime? _time(Object? v) => switch (v) {
  Timestamp t => t.toDate().toUtc(),
  DateTime d => d.toUtc(),
  String s => DateTime.tryParse(s)?.toUtc(),
  _ => null,
};

PayerRefundView? _refundFrom(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['refundId'];
  final createdAt = _time(raw['createdAt']);
  if (id is! String || id.isEmpty || createdAt == null) return null;
  final status = raw['status'];
  return PayerRefundView(
    refundId: id,
    amount: _int(raw['amount']),
    status: status is String ? status : 'pending',
    wallet: raw['method'] != 'bank_transfer',
    destinationLabel: _strOrNull(raw['destinationLabel']),
    createdAt: createdAt,
    doneAt: _time(raw['doneAt']),
  );
}

/// Parses a `users/{uid}/payments/{id}` row; null only for a missing
/// document. An unknown status or subject keeps the row ([PayerRowStatus.unknown],
/// [PayerSubjectType.unknown]): installed apps lag behind the server, and a
/// dropped row would hide money and take a slot of the page's limit.
PayerPaymentRow? payerRowFrom(String id, Map<String, dynamic>? data) {
  if (data == null) return null;
  final status = PayerRowStatus.fromCode(data['status']);
  final subjectType = PayerSubjectType.fromCode(data['subjectType']);
  // The query orders by `createdAt`, so it is always there; a malformed value
  // falls back to `paidAt`, then to the epoch (oldest group) to keep the row.
  final createdAt =
      _time(data['createdAt']) ??
      _time(data['paidAt']) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final refunds = data['refunds'];
  final quantity = data['quantity'];
  return PayerPaymentRow(
    paymentId: id,
    subjectType: subjectType,
    subjectId: data['subjectId'] is String ? data['subjectId'] as String : '',
    eventId: _strOrNull(data['eventId']),
    photographerName: _strOrNull(data['photographerName']),
    serviceName: _strOrNull(data['serviceName']),
    eventTitle: _strOrNull(data['eventTitle']),
    quantity: quantity is num && quantity > 0 ? quantity.toInt() : null,
    areaLabel: _strOrNull(data['areaLabel']),
    day: _strOrNull(data['day']),
    method: PayMethod.fromCode(_strOrNull(data['method'])),
    amount: _int(data['amount']),
    status: status,
    open: data['open'] == true,
    toPlatform: data['toPlatform'] == true,
    heldAmount: _int(data['heldAmount']),
    refundingAmount: _int(data['refundingAmount']),
    refundedAmount: _int(data['refundedAmount']),
    searching: data['searching'] == true,
    cancelled: data['cancelled'] == true,
    refunds: refunds is List
        ? [for (final r in refunds) ?_refundFrom(r)]
        : const [],
    createdAt: createdAt,
    paidAt: _time(data['paidAt']),
  );
}

/// Parses `users/{uid}/private/paymentTotals`; missing is zero.
PaymentTotals paymentTotalsFrom(Map<String, dynamic>? data) => data == null
    ? const PaymentTotals()
    : PaymentTotals(
        held: _int(data['held']),
        refunding: _int(data['refunding']),
      );

/// Which S22.04 refund to look for: the callable `pendingRefund` takes
/// `{bookingId}`, `{eventId, registrationId}` or `{disputeId}`.
sealed class RefundSubject {
  const RefundSubject();

  /// The callable payload.
  Map<String, String> get payload;

  @override
  bool operator ==(Object other) =>
      other is RefundSubject &&
      other.runtimeType == runtimeType &&
      mapEquals(other.payload, payload);

  @override
  int get hashCode => Object.hash(
    runtimeType,
    Object.hashAllUnordered(
      payload.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

final class BookingRefund extends RefundSubject {
  const BookingRefund(this.bookingId);

  final String bookingId;

  @override
  Map<String, String> get payload => {'bookingId': bookingId};
}

final class TicketRefund extends RefundSubject {
  const TicketRefund(this.eventId, this.registrationId);

  final String eventId;
  final String registrationId;

  @override
  Map<String, String> get payload => {
    'eventId': eventId,
    'registrationId': registrationId,
  };
}

/// A dispute's refund (S18.02, #142).
final class DisputeRefund extends RefundSubject {
  const DisputeRefund(this.disputeId);

  final String disputeId;

  @override
  Map<String, String> get payload => {'disputeId': disputeId};
}

/// The masked paying account a waiting refund goes back to.
typedef RefundPayerAccount = ({
  String bankName,
  String accountLast4,
  String holderName,
});

/// A refund waiting for the customer's account choice (S22.04).
@immutable
class PendingRefund {
  const PendingRefund({
    required this.refundId,
    required this.amount,
    this.payer,
    this.confirmBy,
  });

  final String refundId;
  final int amount;

  /// The account the customer paid from; null when unknown (the sheet opens
  /// on the other-account form).
  final RefundPayerAccount? payer;

  /// When the refund goes to [payer] by itself (24 h); null without a payer.
  final DateTime? confirmBy;
}

/// Parses the `pendingRefund` answer; null when nothing waits.
PendingRefund? pendingRefundFrom(Object? data) {
  if (data is! Map) return null;
  final id = data['refundId'];
  if (id is! String || id.isEmpty) return null;
  final p = data['payer'];
  RefundPayerAccount? payer;
  if (p is Map &&
      p['bankName'] is String &&
      p['accountLast4'] is String &&
      p['holderName'] is String) {
    payer = (
      bankName: p['bankName'] as String,
      accountLast4: p['accountLast4'] as String,
      holderName: p['holderName'] as String,
    );
  }
  return PendingRefund(
    refundId: id,
    amount: _int(data['amount']),
    payer: payer,
    confirmBy: _time(data['confirmBy']),
  );
}

/// Where a waiting refund goes: the paying account or the looked-up one.
enum RefundAccountChoice {
  payer('payer'),
  candidate('candidate');

  const RefundAccountChoice(this.code);

  final String code;
}

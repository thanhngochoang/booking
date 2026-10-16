import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photobooking/core/core.dart';

/// Client representation of payment instructions returned by callables
/// (`getPaymentInstructions`, `registerEvent`, `createPayment`), or stored in
/// `payments/{id}.instructions` or `bookings/{id}.checkout`.
class PaymentInstructions {
  const PaymentInstructions({
    required this.paymentId,
    required this.method,
    required this.amount,
    required this.expiresAt,
    required this.transferCode,
    this.attempt,
    this.qrPayload,
    this.bankName,
    this.accountMasked,
    this.payUrl,
    this.bankAppsUrl,
  });

  final String paymentId;
  final PayMethod method;

  /// Integer VND.
  final int amount;

  /// UTC instant after which this payment expires.
  final DateTime expiresAt;

  /// "PB XXXXXX": the transfer content identifying the payment.
  final String transferCode;

  final int? attempt;
  final String? qrPayload;
  final String? bankName;
  final String? accountMasked;
  final String? payUrl;
  final String? bankAppsUrl;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// Time left at [now]; zero once expired, never negative.
  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentInstructions &&
          other.paymentId == paymentId &&
          other.method == method &&
          other.amount == amount &&
          other.expiresAt == expiresAt &&
          other.transferCode == transferCode &&
          other.attempt == attempt &&
          other.qrPayload == qrPayload &&
          other.bankName == bankName &&
          other.accountMasked == accountMasked &&
          other.payUrl == payUrl &&
          other.bankAppsUrl == bankAppsUrl;

  @override
  int get hashCode => Object.hash(
        paymentId,
        method,
        amount,
        expiresAt,
        transferCode,
        attempt,
        qrPayload,
        bankName,
        accountMasked,
        payUrl,
        bankAppsUrl,
      );
}

/// Parses payment instructions map from a callable response or document field.
/// Returns null when malformed.
PaymentInstructions? paymentInstructionsFrom(Object? raw) {
  if (raw is! Map) return null;
  final paymentId = raw['paymentId'];
  final method = PayMethod.fromCode(raw['method'] as String?);
  final amount = raw['amount'];
  final transferCode = raw['transferCode'];
  final attempt = raw['attempt'];
  final expiresRaw = raw['expiresAt'];
  final expiresAt = switch (expiresRaw) {
    Timestamp() => expiresRaw.toDate().toUtc(),
    DateTime() => expiresRaw.toUtc(),
    String() => DateTime.tryParse(expiresRaw)?.toUtc(),
    _ => null,
  };
  if (paymentId is! String || paymentId.isEmpty) return null;
  if (method == null || expiresAt == null) return null;
  if (amount is! num || transferCode is! String) return null;
  String? text(String key) {
    final v = raw[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  return PaymentInstructions(
    paymentId: paymentId,
    method: method,
    amount: amount.toInt(),
    expiresAt: expiresAt,
    transferCode: transferCode,
    attempt: attempt is num ? attempt.toInt() : null,
    qrPayload: text('qrPayload'),
    bankName: text('bankName'),
    accountMasked: text('accountMasked'),
    payUrl: text('payUrl'),
    bankAppsUrl: text('bankAppsUrl'),
  );
}

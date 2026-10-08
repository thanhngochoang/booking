import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:photobooking/core/core.dart';

/// What S04.04 shows to pay one booking: the client mirror of
/// `bookings/{id}.checkout`, written by the `createPayment` callable (the
/// callable answers with the same fields, `expiresAt` as an ISO-8601 string).
class BookingCheckout {
  const BookingCheckout({
    required this.paymentId,
    required this.method,
    required this.amount,
    required this.expiresAt,
    required this.transferCode,
    required this.attempt,
    this.qrPayload,
    this.bankName,
    this.accountMasked,
    this.payUrl,
    this.bankAppsUrl,
  });

  final String paymentId;
  final PayMethod method;

  /// Integer VND, the full price.
  final int amount;

  /// UTC instant after which this QR / link no longer counts.
  final DateTime expiresAt;

  /// "PB XXXXXX": the transfer content that identifies the payment.
  final String transferCode;

  /// 1 for the first QR, 2 after "Tạo QR mới" and so on (at most 3).
  final int attempt;

  /// VietQR (EMVCo) text to draw as a QR code; bank transfers only.
  final String? qrPayload;
  final String? bankName;
  final String? accountMasked;

  /// Wallet deep link / page (MoMo, ZaloPay).
  final String? payUrl;

  /// Where "Mở app ngân hàng" goes; null hides the button.
  final String? bankAppsUrl;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// Time left at [now]; zero once expired, never negative.
  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  bool operator ==(Object other) =>
      other is BookingCheckout &&
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

/// Parses `bookings/{id}.checkout` or the `createPayment` answer; null for a
/// missing or malformed map (a broken mirror must never break the booking).
BookingCheckout? bookingCheckoutFrom(Object? raw) {
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
  if (amount is! num || transferCode is! String || attempt is! num) return null;
  String? text(String key) {
    final v = raw[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  return BookingCheckout(
    paymentId: paymentId,
    method: method,
    amount: amount.toInt(),
    expiresAt: expiresAt,
    transferCode: transferCode,
    attempt: attempt.toInt(),
    qrPayload: text('qrPayload'),
    bankName: text('bankName'),
    accountMasked: text('accountMasked'),
    payUrl: text('payUrl'),
    bankAppsUrl: text('bankAppsUrl'),
  );
}

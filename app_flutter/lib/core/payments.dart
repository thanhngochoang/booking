// lib/core/payments.dart

/// The ways to pay (S04.04 and S11.03: "Chuyển khoản QR", "MoMo", "ZaloPay").
/// [code] is the wire `PaymentMethod` sent to `createPayment` and `registerEvent`.
enum PayMethod {
  bankQr('bank_qr'),
  momo('momo'),
  zaloPay('zalopay');

  const PayMethod(this.code);

  /// Stable wire code of the payment method.
  final String code;

  static PayMethod? fromCode(String? c) {
    for (final m in values) {
      if (m.code == c) return m;
    }
    return null;
  }
}

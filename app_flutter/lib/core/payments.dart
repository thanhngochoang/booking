// lib/core/payments.dart

/// Supported payment providers for booking and ticket payments.
enum PaymentProviderCode {
  momo('momo'),
  vnpay('vnpay');

  const PaymentProviderCode(this.code);

  /// Stable code used in domain rules, callable payloads and analytics.
  final String code;

  static PaymentProviderCode? fromCode(String? code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// The ways to pay (mock S04.03 and S11.03: "Chuyển khoản QR", "MoMo",
/// "ZaloPay"). [code] is the `PaymentMethod` the booking callables take
/// (`createPayment {bookingId, method}`); [provider] is what S11.03 tickets
/// still send to `registerEvent` until they move too: a bank QR and ZaloPay go
/// through the VNPay gateway (VNPAY-QR), MoMo through MoMo.
enum PayMethod {
  bankQr(PaymentProviderCode.vnpay, 'bank_qr'),
  momo(PaymentProviderCode.momo, 'momo'),
  zaloPay(PaymentProviderCode.vnpay, 'zalopay');

  const PayMethod(this.provider, this.code);

  /// The provider code sent to `registerEvent`.
  final PaymentProviderCode provider;

  /// Stable wire code of the booking payment method.
  final String code;

  static PayMethod? fromCode(String? c) {
    for (final m in values) {
      if (m.code == c) return m;
    }
    return null;
  }
}

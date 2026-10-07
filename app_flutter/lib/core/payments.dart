// lib/core/payments.dart

/// Supported payment providers for deposits and booking payments.
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

/// The ways to pay a ticket on S11.03 (mock: "Chuyển khoản QR", "MoMo",
/// "ZaloPay"). Until the VietQR / licensed-intermediary move (issue #129)
/// each one is sent as a provider code the current gateway accepts: a bank
/// QR and ZaloPay go through the VNPay gateway (VNPAY-QR), MoMo through MoMo.
enum PayMethod {
  bankQr(PaymentProviderCode.vnpay),
  momo(PaymentProviderCode.momo),
  zaloPay(PaymentProviderCode.vnpay);

  const PayMethod(this.provider);

  /// The provider code sent to `registerEvent`.
  final PaymentProviderCode provider;
}

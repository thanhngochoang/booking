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

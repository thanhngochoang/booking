import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';

void main() {
  final at = DateTime.utc(2026, 10, 10, 3, 0);

  group('paymentInstructionsFrom', () {
    test('parses the callable map with ISO expiresAt and returns UTC', () {
      final raw = {
        'paymentId': 'pay_1',
        'method': 'bank_qr',
        'amount': 250000,
        'transferCode': 'PB 7F3K2Q',
        'expiresAt': '2026-10-10T03:10:00.000Z',
        'attempt': 1,
        'qrPayload': '000201010212...',
        'bankName': 'BIDV',
        'accountMasked': '9624 •••• 3812',
        'payUrl': null,
        'bankAppsUrl': 'https://dl.vietqr.io/...',
      };
      final ins = paymentInstructionsFrom(raw);
      expect(ins, isNotNull);
      expect(ins!.paymentId, 'pay_1');
      expect(ins.method, PayMethod.bankQr);
      expect(ins.amount, 250000);
      expect(ins.transferCode, 'PB 7F3K2Q');
      expect(ins.expiresAt, DateTime.utc(2026, 10, 10, 3, 10));
      expect(ins.attempt, 1);
      expect(ins.qrPayload, '000201010212...');
      expect(ins.bankName, 'BIDV');
      expect(ins.accountMasked, '9624 •••• 3812');
      expect(ins.payUrl, isNull);
      expect(ins.bankAppsUrl, 'https://dl.vietqr.io/...');
    });

    test('parses Timestamp and DateTime expiresAt', () {
      final ts = Timestamp.fromDate(at);
      final fromTs = paymentInstructionsFrom({
        'paymentId': 'pay_2',
        'method': 'momo',
        'amount': 100000,
        'transferCode': 'PB MOMO01',
        'expiresAt': ts,
      });
      expect(fromTs?.expiresAt, at);

      final fromDt = paymentInstructionsFrom({
        'paymentId': 'pay_3',
        'method': 'zalopay',
        'amount': 150000,
        'transferCode': 'PB ZALO01',
        'expiresAt': at,
      });
      expect(fromDt?.expiresAt, at);
    });

    test('a missing or malformed map is null', () {
      expect(paymentInstructionsFrom(null), isNull);
      expect(paymentInstructionsFrom('not a map'), isNull);
      // missing paymentId
      expect(
        paymentInstructionsFrom({
          'method': 'bank_qr',
          'amount': 100000,
          'transferCode': 'PB 123',
          'expiresAt': at.toIso8601String(),
        }),
        isNull,
      );
      // unknown method
      expect(
        paymentInstructionsFrom({
          'paymentId': 'p1',
          'method': 'crypto',
          'amount': 100000,
          'transferCode': 'PB 123',
          'expiresAt': at.toIso8601String(),
        }),
        isNull,
      );
      // no transferCode
      expect(
        paymentInstructionsFrom({
          'paymentId': 'p1',
          'method': 'bank_qr',
          'amount': 100000,
          'expiresAt': at.toIso8601String(),
        }),
        isNull,
      );
      // bad amount
      expect(
        paymentInstructionsFrom({
          'paymentId': 'p1',
          'method': 'bank_qr',
          'amount': 'free',
          'transferCode': 'PB 123',
          'expiresAt': at.toIso8601String(),
        }),
        isNull,
      );
      // unparseable expiresAt
      expect(
        paymentInstructionsFrom({
          'paymentId': 'p1',
          'method': 'bank_qr',
          'amount': 100000,
          'transferCode': 'PB 123',
          'expiresAt': 'invalid-date',
        }),
        isNull,
      );
    });
  });

  group('expiry and duration', () {
    test('remainingAt never goes negative and isExpiredAt flips at expiresAt', () {
      final ins = PaymentInstructions(
        paymentId: 'p1',
        method: PayMethod.bankQr,
        amount: 500000,
        expiresAt: at,
        transferCode: 'PB 112233',
      );
      final before = at.subtract(const Duration(minutes: 5));
      expect(ins.isExpiredAt(before), isFalse);
      expect(ins.remainingAt(before), const Duration(minutes: 5));

      expect(ins.isExpiredAt(at), isTrue);
      expect(ins.remainingAt(at), Duration.zero);

      final after = at.add(const Duration(minutes: 10));
      expect(ins.isExpiredAt(after), isTrue);
      expect(ins.remainingAt(after), Duration.zero);
    });
  });

  test('BookingCheckout.toInstructions keeps every field and the attempt', () {
    final checkout = BookingCheckout(
      paymentId: 'pay_b1',
      method: PayMethod.bankQr,
      amount: 1500000,
      expiresAt: at,
      transferCode: 'PB B00K01',
      attempt: 2,
      qrPayload: 'payload_qr',
      bankName: 'Vietcombank',
      accountMasked: '1234 •••• 5678',
      payUrl: 'https://pay.test/b1',
      bankAppsUrl: 'https://bankapps.test',
    );

    final ins = checkout.toInstructions();
    expect(ins.paymentId, 'pay_b1');
    expect(ins.method, PayMethod.bankQr);
    expect(ins.amount, 1500000);
    expect(ins.expiresAt, at);
    expect(ins.transferCode, 'PB B00K01');
    expect(ins.attempt, 2);
    expect(ins.qrPayload, 'payload_qr');
    expect(ins.bankName, 'Vietcombank');
    expect(ins.accountMasked, '1234 •••• 5678');
    expect(ins.payUrl, 'https://pay.test/b1');
    expect(ins.bankAppsUrl, 'https://bankapps.test');
  });
}

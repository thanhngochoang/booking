import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_repository.dart';

Map<String, dynamic> _serverMap({Object? expiresAt}) => {
  'paymentId': 'pay_1',
  'method': 'bank_qr',
  'amount': 1500000,
  'expiresAt': expiresAt ?? '2026-10-07T03:15:00.000Z',
  'transferCode': 'PB 7F3K2Q',
  'attempt': 2,
  'qrPayload': '000201...',
  'bankName': 'BIDV',
  'accountMasked': '9624 •••• 3812',
  'bankAppsUrl': 'https://fake-pay.local/bank-apps',
};

void main() {
  group('bookingCheckoutFrom', () {
    test('parses the server map (ISO string), always UTC', () {
      final c = bookingCheckoutFrom(_serverMap());
      expect(c, isNotNull);
      expect(c!.paymentId, 'pay_1');
      expect(c.method, PayMethod.bankQr);
      expect(c.amount, 1500000);
      expect(c.expiresAt, DateTime.utc(2026, 10, 7, 3, 15));
      expect(c.expiresAt.isUtc, isTrue);
      expect(c.transferCode, 'PB 7F3K2Q');
      expect(c.attempt, 2);
      expect(c.qrPayload, '000201...');
      expect(c.bankName, 'BIDV');
      expect(c.accountMasked, '9624 •••• 3812');
      expect(c.bankAppsUrl, 'https://fake-pay.local/bank-apps');
      expect(c.payUrl, isNull);
    });

    test('parses a Firestore Timestamp and a wallet checkout', () {
      final c = bookingCheckoutFrom({
        'paymentId': 'pay_2',
        'method': 'momo',
        'amount': 900000,
        'expiresAt': Timestamp.fromDate(DateTime.utc(2026, 10, 7, 4)),
        'transferCode': 'PB ABCDEF',
        'attempt': 1,
        'payUrl': 'https://fake-pay.local/momo?paymentId=pay_2',
      });
      expect(c!.method, PayMethod.momo);
      expect(c.expiresAt, DateTime.utc(2026, 10, 7, 4));
      expect(c.expiresAt.isUtc, isTrue);
      expect(c.payUrl, 'https://fake-pay.local/momo?paymentId=pay_2');
      expect(c.qrPayload, isNull);
    });

    test('a missing or malformed checkout is null', () {
      expect(bookingCheckoutFrom(null), isNull);
      expect(bookingCheckoutFrom('x'), isNull);
      expect(bookingCheckoutFrom(<String, dynamic>{}), isNull);
      expect(bookingCheckoutFrom(_serverMap()..remove('paymentId')), isNull);
      expect(bookingCheckoutFrom(_serverMap()..['method'] = 'cash'), isNull);
      expect(bookingCheckoutFrom(_serverMap()..['amount'] = 'a lot'), isNull);
      expect(bookingCheckoutFrom(_serverMap(expiresAt: 'soon')), isNull);
      expect(bookingCheckoutFrom(_serverMap()..remove('transferCode')), isNull);
    });
  });

  test(
    'remainingAt never goes negative and isExpiredAt flips at expiresAt',
    () {
      final c = bookingCheckoutFrom(_serverMap())!;
      final at = c.expiresAt;
      expect(
        c.remainingAt(at.subtract(const Duration(seconds: 90))),
        const Duration(seconds: 90),
      );
      expect(
        c.isExpiredAt(at.subtract(const Duration(milliseconds: 1))),
        isFalse,
      );
      expect(c.remainingAt(at), Duration.zero);
      expect(c.isExpiredAt(at), isTrue);
      expect(c.remainingAt(at.add(const Duration(minutes: 5))), Duration.zero);
      expect(c.isExpiredAt(at.add(const Duration(minutes: 5))), isTrue);
    },
  );

  test('PayMethod.fromCode round-trips', () {
    for (final m in PayMethod.values) {
      expect(PayMethod.fromCode(m.code), m);
    }
    expect(PayMethod.bankQr.code, 'bank_qr');
    expect(PayMethod.momo.code, 'momo');
    expect(PayMethod.zaloPay.code, 'zalopay');
    expect(PayMethod.fromCode('cash'), isNull);
    expect(PayMethod.fromCode(null), isNull);
    // Tickets (S11.03) still map to a provider.
    expect(PayMethod.zaloPay.provider, PaymentProviderCode.vnpay);
  });

  test('FakeTransferKind codes match the callable', () {
    expect(FakeTransferKind.exact.code, 'exact');
    expect(FakeTransferKind.under.code, 'under');
    expect(FakeTransferKind.over.code, 'over');
    expect(FakeTransferKind.wrongContent.code, 'wrong_content');
  });

  test('bookingErrorOf maps payment_attempts_exceeded', () {
    expect(
      bookingErrorOf(const BookingException('payment_attempts_exceeded')),
      BookingErrorCode.paymentAttemptsExceeded,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/payment/pay_subject.dart';

void main() {
  test('payPathOf gives /b/{id}/pay and /e/{eventId}/pay/{regId}', () {
    expect(payPathOf(const BookingPay('b1')), '/b/b1/pay');
    expect(payPathOf(const TicketPay('ev1', 'r1')), '/e/ev1/pay/r1');
  });

  test('subjects with the same fields are equal and share a hash', () {
    const b1 = BookingPay('b1');
    const b2 = BookingPay('b1');
    const bOther = BookingPay('b2');

    expect(b1, b2);
    expect(b1.hashCode, b2.hashCode);
    expect(b1 == bOther, isFalse);

    const t1 = TicketPay('ev1', 'r1');
    const t2 = TicketPay('ev1', 'r1');
    const tOther = TicketPay('ev1', 'r2');

    expect(t1, t2);
    expect(t1.hashCode, t2.hashCode);
    expect(t1 == tOther, isFalse);
  });

  test('the verification fee pays at /verify/start/fee/pay and every '
      'instance is the same subject', () {
    expect(payPathOf(const VerificationFeePay()), '/verify/start/fee/pay');
    // ignore: prefer_const_constructors
    final a = VerificationFeePay();
    expect(a, const VerificationFeePay());
    expect(a.hashCode, const VerificationFeePay().hashCode);
    expect(a == const BookingPay('b1'), isFalse);
  });

  test('a Chụp ngay request pays at /instant/{id}/pay (#202)', () {
    expect(payPathOf(const InstantPay('req1')), '/instant/req1/pay');
    expect(const InstantPay('req1'), const InstantPay('req1'));
    expect(
      const InstantPay('req1').hashCode,
      const InstantPay('req1').hashCode,
    );
    expect(const InstantPay('req1') == const InstantPay('req2'), isFalse);
    expect(const InstantPay('req1') == const BookingPay('req1'), isFalse);
  });
}

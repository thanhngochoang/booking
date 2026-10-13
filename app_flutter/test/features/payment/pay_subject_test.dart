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
}

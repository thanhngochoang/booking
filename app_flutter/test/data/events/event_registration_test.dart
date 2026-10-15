import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/events/event_registration.dart';

void main() {
  group('TicketRefundStatus', () {
    test('fromCode reads awaiting_account as awaitingAccount and its code round-trips', () {
      expect(TicketRefundStatus.fromCode('awaiting_account'), TicketRefundStatus.awaitingAccount);
      expect(TicketRefundStatus.awaitingAccount.code, 'awaiting_account');

      expect(TicketRefundStatus.fromCode('pending'), TicketRefundStatus.pending);
      expect(TicketRefundStatus.pending.code, 'pending');

      expect(TicketRefundStatus.fromCode('done'), TicketRefundStatus.done);
      expect(TicketRefundStatus.done.code, 'done');

      expect(TicketRefundStatus.fromCode('failed'), TicketRefundStatus.failed);
      expect(TicketRefundStatus.failed.code, 'failed');
    });

    test('unknown codes are null', () {
      expect(TicketRefundStatus.fromCode(null), isNull);
      expect(TicketRefundStatus.fromCode(''), isNull);
      expect(TicketRefundStatus.fromCode('unknown'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 8, 2);

  test(
    'the fake answers lookups from nextLookup and records only last 4',
    () async {
      final repo = FakeEarningsRepository(clock: () => now)
        ..nextLookup['MB:0123454321'] = const PayoutNameLookup(
          decision: PayoutNameDecision.mismatch,
          holderName: 'TRAN VAN B',
          verifiedName: 'Nguyễn Văn An',
        );
      final r = await repo.lookupAccountName(
        bankCode: 'MB',
        accountNumber: '0123454321',
      );
      expect(r.decision, PayoutNameDecision.mismatch);
      final other = await repo.lookupAccountName(
        bankCode: 'MB',
        accountNumber: '0123451234',
      );
      expect(other.decision, PayoutNameDecision.matched);
      expect(repo.lookupCalls, ['MB:4321', 'MB:1234']);

      repo.failNextLookup('limit_exceeded');
      await expectLater(
        repo.lookupAccountName(bankCode: 'MB', accountNumber: '0123451234'),
        throwsA(isA<PayoutAccountError>()),
      );
      expect(repo.lookupCalls, hasLength(3));
    },
  );

  test(
    'a first save is active now; a change waits 72 h and records the otp',
    () async {
      final repo = FakeEarningsRepository(clock: () => now);
      final first = await repo.saveAccount(
        bankCode: 'VCB',
        accountNumber: '0123456789',
      );
      expect(first.activeFrom, now);

      final ticket = await repo.requestAccountOtp(
        bankCode: 'MB',
        accountNumber: '0123451234',
      );
      expect(ticket.phoneLast4, '0001');
      expect(repo.otpCalls, ['MB:1234']);

      repo.failNextOtp('limit_exceeded');
      await expectLater(
        repo.requestAccountOtp(bankCode: 'MB', accountNumber: '0123451234'),
        throwsA(
          isA<PayoutAccountError>().having(
            (e) => e.code,
            'code',
            'limit_exceeded',
          ),
        ),
      );

      final change = await repo.saveAccount(
        bankCode: 'MB',
        accountNumber: '0123451234',
        otpCode: '123456',
      );
      expect(change.activeFrom, now.add(const Duration(hours: 72)));
      expect(repo.saves, ['VCB:6789', 'MB:1234:123456']);
      final view = await repo.watchAccount('u1').first;
      expect(view!.pendingAt(now), isTrue);
      expect(repo.saves.join().contains('0123451234'), isFalse);
    },
  );
}

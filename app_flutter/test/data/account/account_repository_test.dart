import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import '../../support/fake_account_repository.dart';

void main() {
  group('DeletionBlocker', () {
    test('DeletionBlocker parses kinds, count, amount, first', () {
      final json = {
        'kind': 'open_booking',
        'count': 2,
        'amount': null,
        'first': {
          'id': 'b1',
          'title': 'Minh Trí · Chân dung',
          'day': '2026-10-25',
        },
      };

      final blocker = DeletionBlocker.fromJson(json);
      expect(blocker, isNotNull);
      expect(blocker!.kind, BlockerKind.openBooking);
      expect(blocker.count, 2);
      expect(blocker.amount, isNull);
      expect(blocker.first?.id, 'b1');
      expect(blocker.first?.title, 'Minh Trí · Chân dung');
      expect(blocker.first?.day, '2026-10-25');
    });

    test('DeletionBlocker parses money blockers with amount', () {
      final json = {
        'kind': 'held_payment',
        'count': 1,
        'amount': 1500000,
        'first': {
          'id': 'pay1',
          'title': 'Payment 1',
        },
      };

      final blocker = DeletionBlocker.fromJson(json);
      expect(blocker, isNotNull);
      expect(blocker!.kind, BlockerKind.heldPayment);
      expect(blocker.amount, 1500000);
    });
  });

  group('DataExport', () {
    test('DataExport.usableAt is false at expiresAt', () {
      final now = DateTime(2026, 10, 21, 10);
      final expiresAt = now.add(const Duration(days: 7));
      final export = DataExport(
        path: 'exports/u1/exp1.json',
        sizeBytes: 500,
        createdAt: now,
        expiresAt: expiresAt,
      );

      expect(export.usableAt(now), isTrue);
      expect(export.usableAt(now.add(const Duration(days: 6))), isTrue);
      expect(export.usableAt(expiresAt), isFalse);
      expect(export.usableAt(expiresAt.add(const Duration(seconds: 1))), isFalse);
    });
  });

  group('PhotographerSummary hiddenFromDiscovery & deletionPending', () {
    test('photographerSummaryFrom reads hiddenFromDiscovery and deletionPending (missing → false)', () {
      final summaryDefault = photographerSummaryFrom(
        id: 'p1',
        user: {'displayName': 'An'},
        photographer: {},
      );

      expect(summaryDefault.hiddenFromDiscovery, isFalse);
      expect(summaryDefault.deletionPending, isFalse);

      final summarySet = photographerSummaryFrom(
        id: 'p2',
        user: {'displayName': 'Bình'},
        photographer: {
          'hiddenFromDiscovery': true,
          'deletionPending': true,
        },
      );

      expect(summarySet.hiddenFromDiscovery, isTrue);
      expect(summarySet.deletionPending, isTrue);
    });
  });

  group('FakeAccountRepository operations', () {
    test('requestDeletion returns restoreUntil and maps reauth_required and conflict to AccountException', () async {
      final repo = FakeAccountRepository();
      final restoreUntil = await repo.requestDeletion();
      expect(restoreUntil, repo.restoreUntil);

      repo.reauthRequiredOnDeletion = true;
      expect(() => repo.requestDeletion(), throwsA(isA<AccountException>().having((e) => e.code, 'code', 'reauth_required')));

      repo.reauthRequiredOnDeletion = false;
      repo.conflictOnDeletion = true;
      expect(() => repo.requestDeletion(), throwsA(isA<AccountException>().having((e) => e.code, 'code', 'conflict')));
    });

    test('restore maps deadline_passed and not_found', () async {
      final repo = FakeAccountRepository();
      repo.deadlinePassedOnRestore = true;
      expect(() => repo.restore(), throwsA(isA<AccountException>().having((e) => e.code, 'code', 'deadline_passed')));

      repo.deadlinePassedOnRestore = false;
      repo.notFoundOnRestore = true;
      expect(() => repo.restore(), throwsA(isA<AccountException>().having((e) => e.code, 'code', 'not_found')));
    });

    test('watchLock emits AccountLock for deletion_pending and null for active or missing', () async {
      final repo = FakeAccountRepository();
      expect(await repo.watchLock('u1').first, isNull);

      final lockTime = DateTime(2026, 11, 20);
      repo.emitLock(AccountLock(lockTime));
      expect(await repo.watchLock('u1').first, AccountLock(lockTime));
    });
  });
}

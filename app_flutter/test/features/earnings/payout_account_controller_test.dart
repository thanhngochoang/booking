import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/features/earnings/payout_account_controller.dart';

import '../../support/earnings_world.dart';

VnBank get _vcb => vnBanks.firstWhere((b) => b.code == 'VCB');

Future<(EarningsWorld, ProviderContainer)> _setup() async {
  final w = EarningsWorld();
  await w.init();
  final c = ProviderContainer(overrides: w.overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  c.listen(payoutAccountControllerProvider, (_, _) {});
  return (w, c);
}

PayoutAccountController _ctl(ProviderContainer c) =>
    c.read(payoutAccountControllerProvider.notifier);

void _fill(ProviderContainer c) => _ctl(c)
  ..setBank(_vcb)
  ..setNumber('0123 4567 890')
  ..setHolder('NGUYEN MINH TRI');

void main() {
  test('the form is valid only with a bank, a number and a holder', () async {
    final (_, c) = await _setup();
    final ctl = _ctl(c);
    expect(c.read(payoutAccountControllerProvider).valid, isNull);
    ctl.setBank(_vcb);
    expect(c.read(payoutAccountControllerProvider).valid, isNull);
    ctl.setNumber('12345');
    ctl.setHolder('TRI');
    expect(c.read(payoutAccountControllerProvider).valid, isNull);
    ctl.setNumber('123456');
    expect(c.read(payoutAccountControllerProvider).valid, isNotNull);
    ctl.setHolder('T1');
    expect(c.read(payoutAccountControllerProvider).valid, isNull);
  });

  test('save sends normalised values and clears the input', () async {
    final (w, c) = await _setup();
    _fill(c);
    final outcome = await _ctl(c).save(reauth: () async => false);
    expect(outcome, PayoutSaveOutcome.saved);
    expect(w.repo.saves, ['VCB:7890']);
    final s = c.read(payoutAccountControllerProvider);
    expect(s.number, isEmpty);
    expect(s.holder, isEmpty);
    expect(s.bank, isNull);
    expect(s.editing, isFalse);
    expect(s.saving, isFalse);
  });

  test('invalid input never reaches the repository', () async {
    final (w, c) = await _setup();
    _ctl(c).setBank(_vcb);
    expect(
      await _ctl(c).save(reauth: () async => true),
      PayoutSaveOutcome.invalid,
    );
    expect(w.repo.saves, isEmpty);
  });

  test('reauth_required re-authenticates and retries once', () async {
    final (w, c) = await _setup();
    _fill(c);
    w.repo.failNextSave('reauth_required');
    var asked = 0;
    final outcome = await _ctl(c).save(
      reauth: () async {
        asked++;
        return true;
      },
    );
    expect(asked, 1);
    expect(outcome, PayoutSaveOutcome.saved);
    expect(w.repo.saves, ['VCB:7890']);
  });

  test('a second reauth_required after re-authenticating fails', () async {
    final (w, c) = await _setup();
    _fill(c);
    w.repo.failNextSave('reauth_required');
    final repo = w.repo;
    var asked = 0;
    final outcome = await _ctl(c).save(
      reauth: () async {
        asked++;
        repo.failNextSave('reauth_required');
        return true;
      },
    );
    expect(asked, 1, reason: 'asks once, never loops');
    expect(outcome, PayoutSaveOutcome.failed);
    expect(c.read(payoutAccountControllerProvider).number, '0123 4567 890');
  });

  test('a cancelled re-authentication keeps the input', () async {
    final (w, c) = await _setup();
    _fill(c);
    w.repo.failNextSave('reauth_required');
    final outcome = await _ctl(c).save(reauth: () async => false);
    expect(outcome, PayoutSaveOutcome.cancelled);
    expect(w.repo.saves, isEmpty);
    final s = c.read(payoutAccountControllerProvider);
    expect(s.number, '0123 4567 890');
    expect(s.holder, 'NGUYEN MINH TRI');
    expect(s.saving, isFalse);
  });

  test('conflict and other errors keep the input', () async {
    final (w, c) = await _setup();
    _fill(c);
    w.repo.failNextSave('conflict');
    expect(
      await _ctl(c).save(reauth: () async => true),
      PayoutSaveOutcome.conflict,
    );
    w.repo.failNextSave('network');
    expect(
      await _ctl(c).save(reauth: () async => true),
      PayoutSaveOutcome.failed,
    );
    expect(c.read(payoutAccountControllerProvider).number, '0123 4567 890');
  });

  test('startChange preselects the bank and opens the empty form', () async {
    final (_, c) = await _setup();
    _ctl(c).startChange('TCB');
    final s = c.read(payoutAccountControllerProvider);
    expect(s.editing, isTrue);
    expect(s.bank?.code, 'TCB');
    expect(s.number, isEmpty);
    _ctl(c).cancelChange();
    expect(c.read(payoutAccountControllerProvider).editing, isFalse);
  });

  test('analytics carries only whether it was a change', () async {
    final (w, c) = await _setup();
    _fill(c);
    await _ctl(c).save(reauth: () async => true);
    _ctl(c).startChange('VCB');
    _ctl(c)
      ..setNumber('9876543210')
      ..setHolder('LE VAN A');
    await _ctl(c).save(reauth: () async => true);
    expect(w.events.map((e) => e.$1), [
      'payout_account_save',
      'payout_account_save',
    ]);
    expect(w.events.map((e) => e.$2), [
      {'change': false},
      {'change': true},
    ]);
  });
}

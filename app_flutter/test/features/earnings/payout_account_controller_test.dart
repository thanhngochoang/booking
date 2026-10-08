import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/features/earnings/payout_account_controller.dart';
import 'package:photobooking/features/earnings/widgets/payout_otp_sheet.dart';

import '../../support/earnings_world.dart';

VnBank get _vcb => vnBanks.firstWhere((b) => b.code == 'VCB');
VnBank get _mb => vnBanks.firstWhere((b) => b.code == 'MB');

Future<(EarningsWorld, ProviderContainer)> _setup({
  bool account = false,
}) async {
  final w = EarningsWorld();
  await w.init();
  if (account) w.repo.setAccount(w.account());
  final c = ProviderContainer(overrides: w.overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  c.listen(payoutAccountControllerProvider, (_, _) {});
  return (w, c);
}

PayoutAccountController _ctl(ProviderContainer c) =>
    c.read(payoutAccountControllerProvider.notifier);

PayoutAccountForm _form(ProviderContainer c) =>
    c.read(payoutAccountControllerProvider);

/// Bank and number, then the lookup at once (as on submit).
Future<void> _fill(
  ProviderContainer c, {
  VnBank? bank,
  String number = '0123 4567 890',
}) async {
  _ctl(c)
    ..setBank(bank ?? _vcb)
    ..setNumber(number);
  await _ctl(c).lookupNow();
}

/// An askOtp that never opens a sheet: fails the test if it is called.
Future<bool> _noOtp(PayoutOtpTicket _) async {
  fail('askOtp must not be called');
}

/// No account number may appear in any recorded call, event or message.
void _expectNoNumber(EarningsWorld w, List<String> numbers) {
  final seen = [
    ...w.repo.saves,
    ...w.repo.lookupCalls,
    ...w.repo.otpCalls,
    for (final e in w.events) '${e.$2}',
  ].join('|');
  for (final n in numbers) {
    expect(
      seen.contains(n),
      isFalse,
      reason: 'a full account number leaked (masked)',
    );
  }
}

void main() {
  group('lookup', () {
    testWidgets('a valid number looks up after 800 ms, once', (tester) async {
      final (w, c) = await _setup();
      _ctl(c)
        ..setBank(_vcb)
        ..setNumber('123456');
      await tester.pump(const Duration(milliseconds: 300));
      _ctl(c).setNumber('1234567');
      await tester.pump(const Duration(milliseconds: 300));
      _ctl(c).setNumber('12345678');
      await tester.pump(const Duration(milliseconds: 300));
      _ctl(c).setNumber('123456789');
      await tester.pump(const Duration(milliseconds: 799));
      expect(w.repo.lookupCalls, isEmpty, reason: 'still typing');
      expect(_form(c).lookup, isA<LookupIdle>());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(w.repo.lookupCalls, ['VCB:6789']);
      final view = _form(c).lookup;
      expect(view, isA<LookupDone>());
      expect((view as LookupDone).result.decision, PayoutNameDecision.matched);
      await tester.pump(const Duration(seconds: 2));
      expect(w.repo.lookupCalls, hasLength(1));
    });

    testWidgets('an invalid number or no bank never looks up', (tester) async {
      final (w, c) = await _setup();
      _ctl(c).setNumber('123456');
      await tester.pump(const Duration(seconds: 1));
      _ctl(c)
        ..setBank(_vcb)
        ..setNumber('12345');
      await tester.pump(const Duration(seconds: 1));
      expect(w.repo.lookupCalls, isEmpty);
      expect(_form(c).lookup, isA<LookupIdle>());
    });

    test('the same bank and number is not looked up twice', () async {
      final (w, c) = await _setup();
      await _fill(c);
      _ctl(c).setNumber('0123 4567 89');
      expect(_form(c).lookup, isA<LookupIdle>());
      _ctl(c).setNumber('0123 4567 890');
      expect(_form(c).lookup, isA<LookupDone>(), reason: 'from the cache');
      await _ctl(c).lookupNow();
      expect(w.repo.lookupCalls, ['VCB:7890']);
      _ctl(c).setBank(_mb);
      await _ctl(c).lookupNow();
      expect(w.repo.lookupCalls, ['VCB:7890', 'MB:7890']);
    });

    test('a failed lookup reads limit, network or unknown', () async {
      final (w, c) = await _setup();
      w.repo.failNextLookup('limit_exceeded');
      await _fill(c);
      expect((_form(c).lookup as LookupFailed).code, 'limit_exceeded');
      w.repo.failNextLookup('network');
      await _ctl(c).lookupNow();
      expect((_form(c).lookup as LookupFailed).code, 'network');
      w.repo.failNextLookup('permission_denied');
      await _ctl(c).lookupNow();
      expect((_form(c).lookup as LookupFailed).code, 'unknown');
      await _ctl(c).lookupNow();
      expect(_form(c).lookup, isA<LookupDone>(), reason: 'retried');
    });

    test('save is invalid until the lookup is matched or review', () async {
      final (w, c) = await _setup();
      _ctl(c)
        ..setBank(_vcb)
        ..setNumber('0123 4567 890');
      expect(_form(c).valid, isNull, reason: 'not looked up yet');
      expect(await _ctl(c).save(askOtp: _noOtp), PayoutSaveOutcome.invalid);
      for (final (decision, ok) in [
        (PayoutNameDecision.mismatch, false),
        (PayoutNameDecision.notFound, false),
        (PayoutNameDecision.unverifiable, false),
        (PayoutNameDecision.review, true),
        (PayoutNameDecision.matched, true),
      ]) {
        final number = '01234567${decision.index}';
        w.repo.nextLookup['VCB:$number'] = PayoutNameLookup(
          decision: decision,
          holderName: 'TRAN VAN B',
          verifiedName: 'NGUYEN MINH TRI',
        );
        _ctl(c).setNumber(number);
        await _ctl(c).lookupNow();
        expect(_form(c).valid != null, ok, reason: decision.name);
      }
      w.repo.failNextLookup('network');
      _ctl(c).setNumber('9999999999');
      await _ctl(c).lookupNow();
      expect(_form(c).valid, isNull, reason: 'failed lookup');
      expect(w.repo.saves, isEmpty);
    });
  });

  group('save', () {
    test('first account saves without asking for OTP', () async {
      final (w, c) = await _setup();
      await _fill(c);
      final outcome = await _ctl(c).save(askOtp: _noOtp);
      expect(outcome, PayoutSaveOutcome.saved);
      expect(w.repo.saves, ['VCB:7890']);
      expect(w.repo.otpCalls, isEmpty);
    });

    test('the typed number is cleared after a successful save', () async {
      final (w, c) = await _setup();
      await _fill(c);
      await _ctl(c).save(askOtp: _noOtp);
      final s = _form(c);
      expect(s.number, isEmpty);
      expect(s.bank, isNull);
      expect(s.lookup, isA<LookupIdle>());
      expect(s.editing, isFalse);
      expect(s.saving, isFalse);
      _expectNoNumber(w, ['01234567890']);
    });

    test(
      'a change asks for OTP with the ticket, then saves with the code',
      () async {
        final (w, c) = await _setup(account: true);
        _ctl(c).startChange('VCB');
        await _fill(c, bank: _mb, number: '1903 5566 7788');
        final tickets = <PayoutOtpTicket>[];
        final outcome = await _ctl(c).save(
          askOtp: (ticket) async {
            tickets.add(ticket);
            expect(w.repo.saves, isEmpty, reason: 'nothing saved before OTP');
            return await _ctl(c).submitOtp('482913') == PayoutOtpSubmit.saved;
          },
        );
        expect(outcome, PayoutSaveOutcome.changed);
        expect(w.repo.otpCalls, ['MB:7788']);
        expect(tickets.single.phoneLast4, '0001');
        expect(w.repo.saves, ['MB:7788:482913']);
        expect(_form(c).number, isEmpty);
        expect(w.events.single.$2, {'change': true});
        _expectNoNumber(w, ['190355667788']);
      },
    );

    test('wrong code keeps the sheet open (askOtp sees wrong)', () async {
      final (w, c) = await _setup(account: true);
      _ctl(c).startChange('VCB');
      await _fill(c, bank: _mb, number: '1903 5566 7788');
      w.repo.failNextSave('otp_invalid');
      final seen = <PayoutOtpSubmit>[];
      final outcome = await _ctl(c).save(
        askOtp: (_) async {
          seen.add(await _ctl(c).submitOtp('111111'));
          expect(_form(c).number, '1903 5566 7788', reason: 'input kept');
          seen.add(await _ctl(c).submitOtp('482913'));
          return seen.last == PayoutOtpSubmit.saved;
        },
      );
      expect(seen, [PayoutOtpSubmit.wrong, PayoutOtpSubmit.saved]);
      expect(outcome, PayoutSaveOutcome.changed);
      expect(w.repo.saves, ['MB:7788:482913']);
    });

    test('expired, used and too many codes stay in the sheet', () async {
      final (w, c) = await _setup(account: true);
      _ctl(c).startChange('VCB');
      await _fill(c, bank: _mb, number: '1903 5566 7788');
      final seen = <PayoutOtpSubmit>[];
      final outcome = await _ctl(c).save(
        askOtp: (_) async {
          for (final code in [
            'otp_expired',
            'otp_required',
            'limit_exceeded',
          ]) {
            w.repo.failNextSave(code);
            seen.add(await _ctl(c).submitOtp('111111'));
          }
          return false; // closed by the user
        },
      );
      expect(seen, [
        PayoutOtpSubmit.expired,
        PayoutOtpSubmit.expired,
        PayoutOtpSubmit.tooMany,
      ]);
      expect(outcome, PayoutSaveOutcome.cancelled);
      expect(_form(c).number, '1903 5566 7788');
      expect(_form(c).saving, isFalse);
    });

    test('resend asks for a new code; a refused resend is null', () async {
      final (w, c) = await _setup(account: true);
      _ctl(c).startChange('VCB');
      await _fill(c, bank: _mb, number: '1903 5566 7788');
      PayoutOtpTicket? again;
      PayoutOtpTicket? refused;
      await _ctl(c).save(
        askOtp: (_) async {
          w.repo.otpTicket = const PayoutOtpTicket(
            phoneLast4: '4567',
            expiresInSeconds: 300,
            resendInSeconds: 60,
          );
          again = await _ctl(c).resendOtp();
          w.repo.failNextOtp('limit_exceeded');
          refused = await _ctl(c).resendOtp();
          return false;
        },
      );
      expect(again?.phoneLast4, '4567');
      expect(refused, isNull);
      expect(w.repo.otpCalls, ['MB:7788', 'MB:7788', 'MB:7788']);
    });

    test('closing the sheet and saving again reuses the code', () async {
      final (w, c) = await _setup(account: true);
      _ctl(c).startChange('VCB');
      await _fill(c, bank: _mb, number: '1903 5566 7788');
      expect(
        await _ctl(c).save(askOtp: (_) async => false),
        PayoutSaveOutcome.cancelled,
      );
      w.now = w.now.add(const Duration(seconds: 20));
      PayoutOtpTicket? second;
      await _ctl(c).save(
        askOtp: (t) async {
          second = t;
          return false;
        },
      );
      expect(w.repo.otpCalls, ['MB:7788'], reason: 'no second send');
      expect(second?.resendInSeconds, 40);
      expect(second?.expiresInSeconds, 280);
    });

    for (final (code, outcome) in [
      ('phone_required', PayoutSaveOutcome.phoneRequired),
      ('not_eligible', PayoutSaveOutcome.otpUnavailable),
      ('limit_exceeded', PayoutSaveOutcome.otpLimit),
      ('conflict', PayoutSaveOutcome.sameAccount),
      ('network', PayoutSaveOutcome.failed),
    ]) {
      test('$code from requestAccountOtp → ${outcome.name}', () async {
        final (w, c) = await _setup(account: true);
        _ctl(c).startChange('VCB');
        await _fill(c, bank: _mb, number: '1903 5566 7788');
        w.repo.failNextOtp(code);
        expect(await _ctl(c).save(askOtp: _noOtp), outcome);
        expect(w.repo.saves, isEmpty);
        expect(_form(c).number, '1903 5566 7788');
        expect(_form(c).saving, isFalse);
      });
    }

    test('a fatal error in the sheet closes it with that outcome', () async {
      final (w, c) = await _setup(account: true);
      _ctl(c).startChange('VCB');
      await _fill(c, bank: _mb, number: '1903 5566 7788');
      w.repo.failNextSave('name_mismatch');
      PayoutOtpSubmit? seen;
      final outcome = await _ctl(c).save(
        askOtp: (_) async {
          seen = await _ctl(c).submitOtp('482913');
          return false;
        },
      );
      expect(seen, PayoutOtpSubmit.failed);
      expect(outcome, PayoutSaveOutcome.mismatch);
    });

    for (final (code, outcome) in [
      ('name_mismatch', PayoutSaveOutcome.mismatch),
      ('limit_exceeded', PayoutSaveOutcome.lookupLimit),
      ('conflict', PayoutSaveOutcome.conflict),
      ('network', PayoutSaveOutcome.failed),
    ]) {
      test('$code from a first save → ${outcome.name}, input kept', () async {
        final (w, c) = await _setup();
        await _fill(c);
        w.repo.failNextSave(code);
        expect(await _ctl(c).save(askOtp: _noOtp), outcome);
        expect(_form(c).number, '0123 4567 890');
        expect(_form(c).saving, isFalse);
      });
    }

    test('startChange preselects the bank and opens the empty form', () async {
      final (_, c) = await _setup(account: true);
      _ctl(c).startChange('TCB');
      final s = _form(c);
      expect(s.editing, isTrue);
      expect(s.bank?.code, 'TCB');
      expect(s.number, isEmpty);
      expect(s.lookup, isA<LookupIdle>());
      _ctl(c).cancelChange();
      expect(_form(c).editing, isFalse);
    });

    test('analytics carries only whether it was a change', () async {
      final (w, c) = await _setup();
      await _fill(c);
      await _ctl(c).save(askOtp: _noOtp);
      _ctl(c).startChange('VCB');
      await _fill(c, number: '9876543210');
      await _ctl(c).save(
        askOtp: (_) async =>
            await _ctl(c).submitOtp('123456') == PayoutOtpSubmit.saved,
      );
      expect(w.events.map((e) => e.$1), [
        'payout_account_save',
        'payout_account_save',
      ]);
      expect(w.events.map((e) => e.$2), [
        {'change': false},
        {'change': true},
      ]);
      _expectNoNumber(w, ['01234567890', '9876543210']);
    });
  });
}

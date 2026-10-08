// lib/features/earnings/payout_account_controller.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_providers.dart';
import 'package:photobooking/data/earnings/payout_account_rules.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/features/earnings/earnings_analytics.dart';
import 'package:photobooking/features/earnings/widgets/payout_otp_sheet.dart';

/// Where the bank's holder-name lookup for the typed account stands.
sealed class PayoutLookupView {
  const PayoutLookupView();
}

/// No lookup yet (no bank, an invalid number, or still typing).
class LookupIdle extends PayoutLookupView {
  const LookupIdle();
}

class LookupLoading extends PayoutLookupView {
  const LookupLoading();
}

class LookupDone extends PayoutLookupView {
  const LookupDone(this.result);
  final PayoutNameLookup result;
}

/// [code] is `limit_exceeded`, `network` or `unknown`.
class LookupFailed extends PayoutLookupView {
  const LookupFailed(this.code);
  final String code;
}

/// The S06.06 form. [number] is what the user typed (with its group spaces);
/// it is cleared as soon as a save succeeds and never leaves the screen: not
/// to analytics, logs or error reports. The holder name comes from the bank.
@immutable
class PayoutAccountForm {
  const PayoutAccountForm({
    this.bank,
    this.number = '',
    this.editing = false,
    this.saving = false,
    this.justSaved = false,
    this.lookup = const LookupIdle(),
  });

  final VnBank? bank;
  final String number;

  /// True while changing an existing account (the read view shows otherwise).
  final bool editing;
  final bool saving;

  /// Set after a successful save until the new masked account arrives, so the
  /// screen does not flash the empty form.
  final bool justSaved;

  /// The lookup of the current bank and number.
  final PayoutLookupView lookup;

  /// What the server will receive, or null while the account is not valid or
  /// its lookup is not `matched` or `review`.
  ({String bankCode, String number})? get valid {
    final b = bank;
    final n = normalizeAccountNumber(number);
    if (b == null || n == null) return null;
    final l = lookup;
    if (l is! LookupDone) return null;
    return switch (l.result.decision) {
      PayoutNameDecision.matched ||
      PayoutNameDecision.review => (bankCode: b.code, number: n),
      _ => null,
    };
  }

  PayoutAccountForm copyWith({
    VnBank? bank,
    String? number,
    bool? editing,
    bool? saving,
    bool? justSaved,
    PayoutLookupView? lookup,
  }) => PayoutAccountForm(
    bank: bank ?? this.bank,
    number: number ?? this.number,
    editing: editing ?? this.editing,
    saving: saving ?? this.saving,
    justSaved: justSaved ?? this.justSaved,
    lookup: lookup ?? this.lookup,
  );
}

/// [saved] a first account, [changed] a change (active 72 h later);
/// [sameAccount] the change is to the account already in use; [lookupLimit]
/// the save used the last lookup of the day; [notFound] the bank has no such
/// account; [otpWait] a code was sent less than 60 s ago (for any account:
/// the server's resend wait is per user), see
/// [PayoutAccountController.otpWaitSeconds].
enum PayoutSaveOutcome {
  saved,
  changed,
  cancelled,
  conflict,
  failed,
  invalid,
  phoneRequired,
  otpLimit,
  otpUnavailable,
  mismatch,
  sameAccount,
  lookupLimit,
  notFound,
  otpWait,
}

/// A code was sent less than the resend wait ago; nothing was requested.
class _OtpWait implements Exception {
  const _OtpWait(this.seconds);
  final int seconds;
}

/// How long typing must pause before the bank is asked for the holder name.
const payoutLookupDelay = Duration(milliseconds: 800);

class PayoutAccountController extends Notifier<PayoutAccountForm> {
  Timer? _debounce;

  /// Lookups per `bankCode:number` for the screen's life.
  final _cache = <String, PayoutNameLookup>{};
  String? _inFlight;

  /// The change waiting for its OTP, and how it ended.
  ({String bankCode, String number})? _otpTarget;
  bool _changed = false;
  PayoutSaveOutcome? _fatal;

  /// The last code sent, so closing the sheet and saving again within its
  /// validity does not ask for another (the server refuses a resend < 60 s).
  ({String key, PayoutOtpTicket ticket, DateTime at})? _lastOtp;

  /// Seconds left before another code can be sent, after
  /// [PayoutSaveOutcome.otpWait].
  int otpWaitSeconds = 0;

  /// Why the last [resendOtp] returned null.
  PayoutOtpResendRefusal? lastResendError;

  @override
  PayoutAccountForm build() {
    ref.onDispose(() => _debounce?.cancel());
    return const PayoutAccountForm();
  }

  DateTime _now() => ref.read(clockProvider)();

  static String _key(String bankCode, String number) => '$bankCode:$number';

  /// The lookup key of the form, or null while bank or number is not valid.
  String? _formKey(PayoutAccountForm f) {
    final b = f.bank;
    final n = normalizeAccountNumber(f.number);
    return b == null || n == null ? null : _key(b.code, n);
  }

  /// Puts the form's cached lookup (or idle) and, when [delay] is given,
  /// schedules the lookup.
  void _refresh(PayoutAccountForm next, {Duration? delay}) {
    _debounce?.cancel();
    final key = _formKey(next);
    final cached = key == null ? null : _cache[key];
    state = next.copyWith(
      lookup: cached != null ? LookupDone(cached) : const LookupIdle(),
    );
    if (key == null || cached != null || delay == null) return;
    _debounce = Timer(delay, () => unawaited(lookupNow()));
  }

  void setBank(VnBank bank) {
    if (state.saving) return;
    _refresh(state.copyWith(bank: bank), delay: Duration.zero);
  }

  void setNumber(String v) {
    if (state.saving) return;
    _refresh(state.copyWith(number: v), delay: payoutLookupDelay);
  }

  /// Looks the current bank and number up at once (on submit, on retry).
  Future<void> lookupNow() async {
    _debounce?.cancel();
    final b = state.bank;
    final n = normalizeAccountNumber(state.number);
    if (b == null || n == null) return;
    final key = _key(b.code, n);
    final cached = _cache[key];
    if (cached != null) {
      state = state.copyWith(lookup: LookupDone(cached));
      return;
    }
    if (_inFlight == key) return;
    _inFlight = key;
    state = state.copyWith(lookup: const LookupLoading());
    PayoutLookupView result;
    try {
      final r = await ref
          .read(earningsRepositoryProvider)
          .lookupAccountName(bankCode: b.code, accountNumber: n);
      _cache[key] = r;
      result = LookupDone(r);
    } on PayoutAccountError catch (e) {
      result = LookupFailed(switch (e.code) {
        'limit_exceeded' || 'network' => e.code,
        _ => 'unknown',
      });
    } catch (_) {
      result = const LookupFailed('unknown');
    }
    if (_inFlight == key) _inFlight = null;
    // The user may have typed on meanwhile: only the current key counts.
    if (!ref.mounted || _formKey(state) != key) return;
    state = state.copyWith(lookup: result);
  }

  /// Opens the empty form for a change, bank preselected.
  void startChange(String bankCode) {
    _debounce?.cancel();
    VnBank? bank;
    for (final b in vnBanks) {
      if (b.code == bankCode) bank = b;
    }
    state = PayoutAccountForm(bank: bank, editing: true);
  }

  /// The new account arrived: stop holding the screen.
  void ackSaved() {
    if (state.justSaved) state = const PayoutAccountForm();
  }

  /// Back to the read view; whatever was typed is dropped.
  void cancelChange() {
    _debounce?.cancel();
    state = const PayoutAccountForm();
  }

  /// Saves the form. A first account saves at once. A change first sends an
  /// OTP, then [askOtp] shows the code sheet, whose submit calls [submitOtp]
  /// and resend [resendOtp]. The input stays in every outcome but
  /// [PayoutSaveOutcome.saved] and [PayoutSaveOutcome.changed].
  Future<PayoutSaveOutcome> save({
    required Future<bool> Function(PayoutOtpTicket ticket) askOtp,
  }) async {
    final v = state.valid;
    if (v == null || state.saving) return PayoutSaveOutcome.invalid;
    final isChange = state.editing;
    final repo = ref.read(earningsRepositoryProvider);
    final before = ref.read(payoutAccountProvider).value;
    state = state.copyWith(saving: true);

    PayoutSaveOutcome stop(PayoutSaveOutcome o) {
      if (ref.mounted) state = state.copyWith(saving: false);
      return o;
    }

    if (!isChange) {
      try {
        await repo.saveAccount(bankCode: v.bankCode, accountNumber: v.number);
      } on PayoutAccountError catch (e) {
        _serverRefusedName(v, e.code);
        return stop(switch (e.code) {
          'name_mismatch' => PayoutSaveOutcome.mismatch,
          'not_found' => PayoutSaveOutcome.notFound,
          'limit_exceeded' => PayoutSaveOutcome.lookupLimit,
          'conflict' => PayoutSaveOutcome.conflict,
          _ => PayoutSaveOutcome.failed,
        });
      } catch (_) {
        return stop(PayoutSaveOutcome.failed);
      }
      return _finish(before, isChange: false);
    }

    final PayoutOtpTicket ticket;
    try {
      ticket = await _ticketFor(v);
    } on _OtpWait catch (w) {
      otpWaitSeconds = w.seconds;
      return stop(PayoutSaveOutcome.otpWait);
    } on PayoutAccountError catch (e) {
      return stop(switch (e.code) {
        'phone_required' => PayoutSaveOutcome.phoneRequired,
        'not_eligible' => PayoutSaveOutcome.otpUnavailable,
        'limit_exceeded' => PayoutSaveOutcome.otpLimit,
        // requestPayoutOtp refuses only the account already active so.
        'conflict' => PayoutSaveOutcome.sameAccount,
        _ => PayoutSaveOutcome.failed,
      });
    } catch (_) {
      return stop(PayoutSaveOutcome.failed);
    }
    if (!ref.mounted) return PayoutSaveOutcome.cancelled;
    _otpTarget = v;
    _changed = false;
    _fatal = null;
    try {
      await askOtp(ticket);
    } finally {
      _otpTarget = null;
    }
    if (!ref.mounted) {
      return _changed ? PayoutSaveOutcome.changed : PayoutSaveOutcome.cancelled;
    }
    if (_changed) {
      _lastOtp = null;
      return _finish(before, isChange: true);
    }
    return stop(_fatal ?? PayoutSaveOutcome.cancelled);
  }

  /// The ticket of a code still valid for this account, or a new code.
  /// Throws [_OtpWait] while a code for another account is inside its resend
  /// wait: the server counts that wait per user and would refuse the send
  /// as `limit_exceeded` (read as the daily limit).
  Future<PayoutOtpTicket> _ticketFor(
    ({String bankCode, String number}) v,
  ) async {
    final key = _key(v.bankCode, v.number);
    final last = _lastOtp;
    if (last != null) {
      final elapsed = _now().difference(last.at).inSeconds;
      final left = last.ticket.expiresInSeconds - elapsed;
      final wait = last.ticket.resendInSeconds - elapsed;
      if (last.key == key && elapsed >= 0 && left > 0) {
        return PayoutOtpTicket(
          phoneLast4: last.ticket.phoneLast4,
          expiresInSeconds: left,
          resendInSeconds: math.max(0, wait),
        );
      }
      if (last.key != key && elapsed >= 0 && wait > 0) throw _OtpWait(wait);
    }
    final ticket = await ref
        .read(earningsRepositoryProvider)
        .requestAccountOtp(bankCode: v.bankCode, accountNumber: v.number);
    _lastOtp = (key: key, ticket: ticket, at: _now());
    return ticket;
  }

  /// Saves the pending change with [code] (from the OTP sheet). Wrong,
  /// expired and too-many keep the sheet open; [PayoutOtpSubmit.failed]
  /// closes it and [save] returns the reason.
  Future<PayoutOtpSubmit> submitOtp(String code) async {
    final v = _otpTarget;
    if (v == null || _changed) return PayoutOtpSubmit.failed;
    try {
      await ref
          .read(earningsRepositoryProvider)
          .saveAccount(
            bankCode: v.bankCode,
            accountNumber: v.number,
            otpCode: code,
          );
      _changed = true;
      return PayoutOtpSubmit.saved;
    } on PayoutAccountError catch (e) {
      switch (e.code) {
        // An old code after a resend is also otp_invalid.
        case 'otp_invalid':
          return PayoutOtpSubmit.wrong;
        // otp_required: the code was used, or sent for another account.
        case 'otp_expired' || 'otp_required':
          return PayoutOtpSubmit.expired;
        // Five wrong codes (or the day's lookups used up).
        case 'limit_exceeded':
          return PayoutOtpSubmit.tooMany;
        case 'name_mismatch':
          _serverRefusedName(v, e.code);
          _fatal = PayoutSaveOutcome.mismatch;
        case 'not_found':
          _serverRefusedName(v, e.code);
          _fatal = PayoutSaveOutcome.notFound;
        case 'conflict':
          _fatal = PayoutSaveOutcome.conflict;
        default:
          _fatal = PayoutSaveOutcome.failed;
      }
      return PayoutOtpSubmit.failed;
    } catch (_) {
      _fatal = PayoutSaveOutcome.failed;
      return PayoutOtpSubmit.failed;
    }
  }

  /// Sends a new code for the pending change; null when refused, with the
  /// reason in [lastResendError].
  Future<PayoutOtpTicket?> resendOtp() async {
    final v = _otpTarget;
    lastResendError = null;
    if (v == null) {
      lastResendError = PayoutOtpResendRefusal.failed;
      return null;
    }
    try {
      final ticket = await ref
          .read(earningsRepositoryProvider)
          .requestAccountOtp(bankCode: v.bankCode, accountNumber: v.number);
      _lastOtp = (key: _key(v.bankCode, v.number), ticket: ticket, at: _now());
      return ticket;
    } on PayoutAccountError catch (e) {
      lastResendError = e.code == 'limit_exceeded'
          ? PayoutOtpResendRefusal.limit
          : PayoutOtpResendRefusal.failed;
      return null;
    } catch (_) {
      lastResendError = PayoutOtpResendRefusal.failed;
      return null;
    }
  }

  /// The server's own lookup at save time disagreed with the cached one:
  /// forget it and show the server's verdict (save is then disabled).
  void _serverRefusedName(({String bankCode, String number}) v, String code) {
    final decision = switch (code) {
      'name_mismatch' => PayoutNameDecision.mismatch,
      'not_found' => PayoutNameDecision.notFound,
      _ => null,
    };
    if (decision == null) return;
    final key = _key(v.bankCode, v.number);
    final before = _cache.remove(key);
    if (!ref.mounted || _formKey(state) != key) return;
    state = state.copyWith(
      lookup: LookupDone(
        PayoutNameLookup(
          decision: decision,
          verifiedName: before?.verifiedName,
        ),
      ),
    );
  }

  PayoutSaveOutcome _finish(
    PayoutAccountView? before, {
    required bool isChange,
  }) {
    if (!ref.mounted) {
      return isChange ? PayoutSaveOutcome.changed : PayoutSaveOutcome.saved;
    }
    // The full number is not kept past this point.
    // The new masked account may already have arrived while the call ran.
    final arrived = !identical(ref.read(payoutAccountProvider).value, before);
    state = PayoutAccountForm(justSaved: !arrived);
    ref.read(earningsAnalyticsProvider)('payout_account_save', {
      'change': isChange,
    });
    return isChange ? PayoutSaveOutcome.changed : PayoutSaveOutcome.saved;
  }
}

final payoutAccountControllerProvider =
    NotifierProvider.autoDispose<PayoutAccountController, PayoutAccountForm>(
      PayoutAccountController.new,
    );

// lib/features/payments/refund_account_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart'
    show BookingException;
import 'package:photobooking/data/earnings/payout_account_rules.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payments_repository.dart';

/// The refund of [subject] waiting for the customer's account choice, or
/// null (S18.02 shows its button only while one waits). Not retried: a
/// failure hides the button until the screen is opened again.
final pendingRefundProvider = FutureProvider.autoDispose
    .family<PendingRefund?, RefundSubject>(
      (ref, subject) =>
          ref.watch(paymentsRepositoryProvider).pendingRefund(subject),
      retry: (_, _) => null,
    );

/// How many S22.01 rows are read to find where a refund that already left
/// went (the newest ones; the refund is recent).
const refundDestinationRowsRead = 50;

/// Which half of S22.04 shows: the paying account (mock `#S22.04`) or the
/// other-account form (`#S22.04-other`).
enum RefundAccountStep { payer, other }

/// Where the bank's holder-name lookup of the typed account stands.
sealed class RefundLookup {
  const RefundLookup();
}

/// Nothing asked yet, or the bank or number changed since.
class RefundLookupIdle extends RefundLookup {
  const RefundLookupIdle();
}

class RefundLookupLoading extends RefundLookup {
  const RefundLookupLoading();
}

/// The bank's answer for the account on screen: the name, the bank and the
/// last 4 digits the server stored (never the number). A confirm names this
/// account, so the server refuses a candidate a later lookup replaced.
class RefundLookupFound extends RefundLookup {
  const RefundLookupFound({
    required this.holderName,
    required this.bankCode,
    required this.accountLast4,
  });
  final String holderName;
  final String bankCode;
  final String accountLast4;
}

/// [code] is the server's (`not_found`, `not_eligible`, `limit_exceeded`,
/// `network`, …).
class RefundLookupFailed extends RefundLookup {
  const RefundLookupFailed(this.code);
  final String code;
}

/// Why the last confirm did not go through; the sheet stays open.
enum RefundConfirmError {
  /// Not sent (network, unknown): try again.
  failed,

  /// The server's stored candidate is not the account on screen: look it up
  /// again before confirming.
  stale,
}

/// The S22.04 sheet. [number] is what the customer typed (with its group
/// spaces); it never leaves the sheet except in the lookup call.
@immutable
class RefundAccountState {
  const RefundAccountState({
    required this.step,
    this.bank,
    this.number = '',
    this.lookup = const RefundLookupIdle(),
    this.sending = false,
    this.error,
  });

  final RefundAccountStep step;
  final VnBank? bank;
  final String number;
  final RefundLookup lookup;
  final bool sending;
  final RefundConfirmError? error;

  /// The bank and number are locked while the bank answers, so the account
  /// on screen is always the one looked up.
  bool get lookingUp => lookup is RefundLookupLoading;

  /// "Tra tên chủ tài khoản" is enabled: a bank, a valid number and no
  /// lookup in flight.
  bool get canLookup =>
      bank != null &&
      normalizeAccountNumber(number) != null &&
      !lookingUp &&
      !sending;

  /// "Hoàn về tài khoản này" is enabled: the paying account, or the other
  /// account after a successful lookup.
  bool get canConfirm =>
      !sending &&
      switch (step) {
        RefundAccountStep.payer => true,
        RefundAccountStep.other => lookup is RefundLookupFound,
      };

  RefundAccountState copyWith({
    RefundAccountStep? step,
    VnBank? bank,
    String? number,
    RefundLookup? lookup,
    bool? sending,
    RefundConfirmError? Function()? error,
  }) => RefundAccountState(
    step: step ?? this.step,
    bank: bank ?? this.bank,
    number: number ?? this.number,
    lookup: lookup ?? this.lookup,
    sending: sending ?? this.sending,
    error: error == null ? this.error : error(),
  );
}

/// What a confirm (or a lookup refused because the refund left) ended in.
sealed class RefundChooseResult {
  const RefundChooseResult();
}

/// The server took the choice (`pending` or `done`).
class RefundChosen extends RefundChooseResult {
  const RefundChosen();
}

/// The refund no longer waits and went elsewhere (the 24-hour default sent
/// it to the paying account, another choice or staff): the chosen account
/// was not used. [destination] is the S22.01 row's label ("Vietcombank ••••
/// 6789"), or null when it is not known yet.
class RefundAlreadySent extends RefundChooseResult {
  const RefundAlreadySent(this.destination);
  final String? destination;
}

/// Not sent; the state says why ([RefundAccountState.error]).
class RefundNotChosen extends RefundChooseResult {
  const RefundNotChosen();
}

/// The refund the sheet is for: what was asked ([subject], read again when
/// the server refuses a choice) and what the server answered ([pending]).
typedef RefundAccountArgs = ({RefundSubject subject, PendingRefund pending});

/// The S22.04 sheet for one waiting refund. Every outcome follows the
/// server's answer, never the device clock.
class RefundAccountController extends Notifier<RefundAccountState> {
  RefundAccountController(RefundAccountArgs args)
    : subject = args.subject,
      pending = args.pending;

  final RefundSubject subject;
  final PendingRefund pending;

  PaymentsRepository get _repo => ref.read(paymentsRepositoryProvider);

  @override
  RefundAccountState build() {
    // Keeps the signed-in user at hand for [_destination] (a provider
    // nobody listens to is paused) without rebuilding the form.
    ref.listen(authStateProvider, (_, _) {});
    return RefundAccountState(
      step: pending.payer == null
          ? RefundAccountStep.other
          : RefundAccountStep.payer,
    );
  }

  void useOther() =>
      state = state.copyWith(step: RefundAccountStep.other, error: () => null);

  /// Back to the paying account card (only when there is one).
  void usePayer() {
    if (pending.payer == null || state.sending) return;
    state = state.copyWith(step: RefundAccountStep.payer, error: () => null);
  }

  void setBank(VnBank bank) {
    if (bank.code == state.bank?.code || state.lookingUp) return;
    state = state.copyWith(
      bank: bank,
      lookup: const RefundLookupIdle(),
      error: () => null,
    );
  }

  void setNumber(String number) {
    if (number == state.number || state.lookingUp) return;
    state = state.copyWith(
      number: number,
      lookup: const RefundLookupIdle(),
      error: () => null,
    );
  }

  /// Asks the bank for the holder name of the typed account. A `conflict`
  /// (the refund stopped waiting) resolves where it went instead.
  Future<RefundChooseResult?> lookup() async {
    final bank = state.bank;
    final number = normalizeAccountNumber(state.number);
    if (bank == null || number == null || !state.canLookup) return null;
    state = state.copyWith(
      lookup: const RefundLookupLoading(),
      error: () => null,
    );
    RefundLookup result;
    try {
      final r = await _repo.lookupRefundAccount(
        refundId: pending.refundId,
        bankCode: bank.code,
        accountNumber: number,
      );
      result = RefundLookupFound(
        holderName: r.holderName,
        bankCode: bank.code,
        accountLast4: r.accountLast4,
      );
    } on BookingException catch (e) {
      result = RefundLookupFailed(e.code);
    } catch (_) {
      result = const RefundLookupFailed('unknown');
    }
    if (!ref.mounted) return null;
    state = state.copyWith(lookup: result);
    if (result is RefundLookupFailed && result.code == 'conflict') {
      return _refused();
    }
    return null;
  }

  /// Sends the refund to the paying account or to the looked-up one shown on
  /// screen. A `conflict` means the server did not use this choice: the
  /// refund is read again to tell a replaced candidate (still waiting: look
  /// it up again) from a refund that already went elsewhere.
  Future<RefundChooseResult> confirm() async {
    if (!state.canConfirm) return const RefundNotChosen();
    final lookup = state.lookup;
    final shown = state.step == RefundAccountStep.other
        ? lookup is RefundLookupFound
              ? (bankCode: lookup.bankCode, accountLast4: lookup.accountLast4)
              : null
        : null;
    state = state.copyWith(sending: true, error: () => null);
    RefundChooseResult result;
    try {
      await _repo.chooseRefundAccount(
        refundId: pending.refundId,
        use: shown == null
            ? RefundAccountChoice.payer
            : RefundAccountChoice.candidate,
        shown: shown,
      );
      result = const RefundChosen();
    } on BookingException catch (e) {
      result = switch (e.code) {
        'conflict' || 'not_found' => await _refused(),
        _ => _notChosen(RefundConfirmError.failed),
      };
    } catch (_) {
      result = _notChosen(RefundConfirmError.failed);
    }
    if (ref.mounted) state = state.copyWith(sending: false);
    return result;
  }

  RefundNotChosen _notChosen(RefundConfirmError error) {
    if (ref.mounted) state = state.copyWith(error: () => error);
    return const RefundNotChosen();
  }

  /// The server refused the choice: still waiting means the stored candidate
  /// is another account (look up again); otherwise it already went, and
  /// S22.01's row says where.
  Future<RefundChooseResult> _refused() async {
    try {
      final still = await _repo.pendingRefund(subject);
      if (still?.refundId == pending.refundId) {
        if (ref.mounted) {
          state = state.copyWith(lookup: const RefundLookupIdle());
        }
        return _notChosen(RefundConfirmError.stale);
      }
    } catch (_) {
      return _notChosen(RefundConfirmError.failed);
    }
    return RefundAlreadySent(await _destination());
  }

  /// The masked account the refund went to, from the payer's S22.01 rows.
  Future<String?> _destination() async {
    try {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return null;
      final rows = await _repo
          .watchHistory(uid, limit: refundDestinationRowsRead)
          .first
          .timeout(const Duration(seconds: 10));
      for (final row in rows) {
        for (final r in row.refunds) {
          if (r.refundId == pending.refundId) return r.destinationLabel;
        }
      }
    } catch (_) {
      // Unknown: the sheet points to S22.01 instead.
    }
    return null;
  }
}

/// One controller per waiting refund the sheet shows.
final refundAccountControllerProvider = NotifierProvider.autoDispose
    .family<RefundAccountController, RefundAccountState, RefundAccountArgs>(
      RefundAccountController.new,
    );

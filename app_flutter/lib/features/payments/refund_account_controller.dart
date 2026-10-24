// lib/features/payments/refund_account_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/booking/booking_repository.dart'
    show BookingException;
import 'package:photobooking/data/clock/clock.dart';
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

/// The bank's answer: the name and the masked account, never the number.
class RefundLookupFound extends RefundLookup {
  const RefundLookupFound(this.holderName);
  final String holderName;
}

/// [code] is the server's (`not_found`, `not_eligible`, `limit_exceeded`,
/// `network`, …).
class RefundLookupFailed extends RefundLookup {
  const RefundLookupFailed(this.code);
  final String code;
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
    this.failed = false,
  });

  final RefundAccountStep step;
  final VnBank? bank;
  final String number;
  final RefundLookup lookup;
  final bool sending;

  /// The last confirm failed for a reason worth retrying.
  final bool failed;

  /// "Tra tên chủ tài khoản" is enabled: a bank, a valid number and no
  /// lookup in flight.
  bool get canLookup =>
      bank != null &&
      normalizeAccountNumber(number) != null &&
      lookup is! RefundLookupLoading;

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
    bool? failed,
  }) => RefundAccountState(
    step: step ?? this.step,
    bank: bank ?? this.bank,
    number: number ?? this.number,
    lookup: lookup ?? this.lookup,
    sending: sending ?? this.sending,
    failed: failed ?? this.failed,
  );
}

/// What a confirm ended in.
enum RefundChooseOutcome {
  /// The server took the choice (`pending` or `done`).
  sent,

  /// The refund no longer waits (the 24-hour default or staff sent it): the
  /// chosen account was not used; S22.01 shows where it went.
  alreadySent,

  /// Not sent; the sheet stays open to try again.
  failed,
}

/// The refund the sheet is for: what was asked ([subject], read again before
/// a late choice) and what the server answered ([pending]).
typedef RefundAccountArgs = ({RefundSubject subject, PendingRefund pending});

/// The S22.04 sheet for one waiting refund.
class RefundAccountController extends Notifier<RefundAccountState> {
  RefundAccountController(RefundAccountArgs args)
    : subject = args.subject,
      pending = args.pending;

  final RefundSubject subject;
  final PendingRefund pending;

  PaymentsRepository get _repo => ref.read(paymentsRepositoryProvider);

  @override
  RefundAccountState build() => RefundAccountState(
    step: pending.payer == null
        ? RefundAccountStep.other
        : RefundAccountStep.payer,
  );

  void useOther() =>
      state = state.copyWith(step: RefundAccountStep.other, failed: false);

  void setBank(VnBank bank) {
    if (bank.code == state.bank?.code) return;
    state = state.copyWith(
      bank: bank,
      lookup: const RefundLookupIdle(),
      failed: false,
    );
  }

  void setNumber(String number) {
    if (number == state.number) return;
    state = state.copyWith(
      number: number,
      lookup: const RefundLookupIdle(),
      failed: false,
    );
  }

  /// Asks the bank for the holder name of the typed account.
  Future<void> lookup() async {
    final bank = state.bank;
    final number = normalizeAccountNumber(state.number);
    if (bank == null || number == null || !state.canLookup) return;
    final typed = state.number;
    state = state.copyWith(lookup: const RefundLookupLoading(), failed: false);
    RefundLookup result;
    try {
      final r = await _repo.lookupRefundAccount(
        refundId: pending.refundId,
        bankCode: bank.code,
        accountNumber: number,
      );
      result = RefundLookupFound(r.holderName);
    } on BookingException catch (e) {
      result = RefundLookupFailed(e.code);
    } catch (_) {
      result = const RefundLookupFailed('unknown');
    }
    if (!ref.mounted) return;
    // A bank or number changed while the bank answered: that answer is stale.
    if (state.bank?.code != bank.code || state.number != typed) return;
    state = state.copyWith(lookup: result);
  }

  /// Sends the refund to the paying account or the looked-up one. Once the
  /// 24-hour default may have fired, the refund is read again first, so a
  /// refund that already left is never reported as going to the choice.
  Future<RefundChooseOutcome> confirm() async {
    if (!state.canConfirm) return RefundChooseOutcome.failed;
    state = state.copyWith(sending: true, failed: false);
    final outcome = await _confirm();
    if (ref.mounted) {
      state = state.copyWith(
        sending: false,
        failed: outcome == RefundChooseOutcome.failed,
      );
    }
    return outcome;
  }

  Future<RefundChooseOutcome> _confirm() async {
    try {
      final confirmBy = pending.confirmBy;
      if (confirmBy != null && !ref.read(clockProvider)().isBefore(confirmBy)) {
        final still = await _repo.pendingRefund(subject);
        if (still?.refundId != pending.refundId) {
          return RefundChooseOutcome.alreadySent;
        }
      }
      await _repo.chooseRefundAccount(
        refundId: pending.refundId,
        use: state.step == RefundAccountStep.payer
            ? RefundAccountChoice.payer
            : RefundAccountChoice.candidate,
      );
      return RefundChooseOutcome.sent;
    } on BookingException catch (e) {
      return switch (e.code) {
        'conflict' || 'not_found' => RefundChooseOutcome.alreadySent,
        _ => RefundChooseOutcome.failed,
      };
    } catch (_) {
      return RefundChooseOutcome.failed;
    }
  }
}

/// One controller per waiting refund the sheet shows.
final refundAccountControllerProvider = NotifierProvider.autoDispose
    .family<RefundAccountController, RefundAccountState, RefundAccountArgs>(
      RefundAccountController.new,
    );

// lib/features/earnings/payout_account_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_providers.dart';
import 'package:photobooking/data/earnings/payout_account_rules.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/features/earnings/earnings_analytics.dart';

/// The S06.06 form. [number] and [holder] are what the user typed (the number
/// with its group spaces); they are cleared as soon as a save succeeds and
/// never leave the screen: not to analytics, logs or error reports.
@immutable
class PayoutAccountForm {
  const PayoutAccountForm({
    this.bank,
    this.number = '',
    this.holder = '',
    this.editing = false,
    this.saving = false,
    this.justSaved = false,
  });

  final VnBank? bank;
  final String number;
  final String holder;

  /// True while changing an existing account (the read view shows otherwise).
  final bool editing;
  final bool saving;

  /// Set after a successful save until the new masked account arrives, so the
  /// screen does not flash the empty form.
  final bool justSaved;

  /// What the server will receive, or null while a field is not valid.
  ({String bankCode, String number, String holder})? get valid {
    final b = bank;
    final n = normalizeAccountNumber(number);
    final h = normalizeHolderName(holder);
    if (b == null || n == null || h == null) return null;
    return (bankCode: b.code, number: n, holder: h);
  }

  PayoutAccountForm copyWith({
    VnBank? bank,
    String? number,
    String? holder,
    bool? editing,
    bool? saving,
    bool? justSaved,
  }) => PayoutAccountForm(
    bank: bank ?? this.bank,
    number: number ?? this.number,
    holder: holder ?? this.holder,
    editing: editing ?? this.editing,
    saving: saving ?? this.saving,
    justSaved: justSaved ?? this.justSaved,
  );
}

enum PayoutSaveOutcome { saved, cancelled, conflict, failed, invalid }

class PayoutAccountController extends Notifier<PayoutAccountForm> {
  @override
  PayoutAccountForm build() => const PayoutAccountForm();

  void setBank(VnBank bank) => state = state.copyWith(bank: bank);
  void setNumber(String v) => state = state.copyWith(number: v);
  void setHolder(String v) => state = state.copyWith(holder: v);

  /// Opens the empty form for a change, bank preselected.
  void startChange(String bankCode) {
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
  void cancelChange() => state = const PayoutAccountForm();

  /// Saves the form. A change of an existing account that needs a fresh
  /// sign-in calls [reauth] and, when it returns true, retries once. The input
  /// stays in every outcome but [PayoutSaveOutcome.saved].
  Future<PayoutSaveOutcome> save({
    required Future<bool> Function() reauth,
  }) async {
    final v = state.valid;
    if (v == null || state.saving) return PayoutSaveOutcome.invalid;
    final isChange = state.editing;
    final repo = ref.read(earningsRepositoryProvider);
    final before = ref.read(payoutAccountProvider).value;
    state = state.copyWith(saving: true);
    Future<void> attempt() async {
      await repo.saveAccount(
        bankCode: v.bankCode,
        accountNumber: v.number,
        holderName: v.holder,
      );
    }

    try {
      try {
        await attempt();
      } on PayoutAccountError catch (e) {
        if (e.code != 'reauth_required') rethrow;
        final ok = await reauth();
        if (!ref.mounted) return PayoutSaveOutcome.cancelled;
        if (!ok) {
          state = state.copyWith(saving: false);
          return PayoutSaveOutcome.cancelled;
        }
        await attempt();
      }
    } on PayoutAccountError catch (e) {
      if (ref.mounted) state = state.copyWith(saving: false);
      return e.code == 'conflict'
          ? PayoutSaveOutcome.conflict
          : PayoutSaveOutcome.failed;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(saving: false);
      return PayoutSaveOutcome.failed;
    }
    if (!ref.mounted) return PayoutSaveOutcome.saved;
    // The full number is not kept past this point.
    // The new masked account may already have arrived while the call ran.
    final arrived = !identical(ref.read(payoutAccountProvider).value, before);
    state = PayoutAccountForm(justSaved: !arrived);
    ref.read(earningsAnalyticsProvider)('payout_account_save', {
      'change': isChange,
    });
    return PayoutSaveOutcome.saved;
  }
}

final payoutAccountControllerProvider =
    NotifierProvider.autoDispose<PayoutAccountController, PayoutAccountForm>(
      PayoutAccountController.new,
    );

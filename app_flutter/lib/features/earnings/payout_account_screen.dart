// lib/features/earnings/payout_account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_providers.dart';
import 'package:photobooking/data/earnings/payout_account_rules.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/features/earnings/payout_account_controller.dart';
import 'package:photobooking/features/earnings/widgets/account_inputs.dart';
import 'package:photobooking/features/earnings/widgets/bank_picker_sheet.dart';
import 'package:photobooking/features/earnings/widgets/name_lookup_card.dart';
import 'package:photobooking/features/earnings/widgets/payout_otp_sheet.dart';

VnBank? _bankOf(String code) {
  for (final b in vnBanks) {
    if (b.code == code) return b;
  }
  return null;
}

/// `10:15, 13/10` in Vietnam time.
String _vnTimeLabel(DateTime instant) {
  final v = toVn(instant);
  final hh = v.hour.toString().padLeft(2, '0');
  final mm = v.minute.toString().padLeft(2, '0');
  return '$hh:$mm, ${formatDayMonth(v)}';
}

/// S06.06 "Tài khoản nhận tiền" at `/work/earnings/account`: one bank account
/// for payouts. The form takes a bank and a number; the bank answers the
/// holder name, which must match the verified name (S06.06-mismatch) or is
/// left to staff (S06.06-review). A change asks for an OTP (S06.06-otp) and
/// is active 72 hours later (S06.06-pending). The full number is never shown
/// again after a save.
class PayoutAccountScreen extends ConsumerStatefulWidget {
  const PayoutAccountScreen({super.key});

  @override
  ConsumerState<PayoutAccountScreen> createState() =>
      _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends ConsumerState<PayoutAccountScreen> {
  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final l = context.l10n;
    final form = ref.read(payoutAccountControllerProvider);
    if (form.valid == null || form.saving) return;
    final controller = ref.read(payoutAccountControllerProvider.notifier);
    final outcome = await controller.save(
      askOtp: (ticket) async =>
          mounted &&
          await showPayoutOtpSheet(
            context,
            ticket: ticket,
            onSubmit: controller.submitOtp,
            onResend: controller.resendOtp,
          ),
    );
    if (!mounted) return;
    final message = switch (outcome) {
      PayoutSaveOutcome.saved => l.payoutAccountSaved,
      PayoutSaveOutcome.changed => l.payoutAccountChangeSaved,
      PayoutSaveOutcome.conflict => l.payoutAccountBusy,
      PayoutSaveOutcome.sameAccount => l.payoutAccountSameAccount,
      PayoutSaveOutcome.failed => l.payoutAccountSaveError,
      PayoutSaveOutcome.phoneRequired => l.payoutPhoneRequired,
      PayoutSaveOutcome.otpLimit => l.payoutOtpLimit,
      PayoutSaveOutcome.otpUnavailable => l.payoutOtpUnavailable,
      PayoutSaveOutcome.mismatch => l.payoutLookupMismatchBody,
      PayoutSaveOutcome.lookupLimit => l.payoutLookupLimit,
      PayoutSaveOutcome.cancelled || PayoutSaveOutcome.invalid => null,
    };
    if (message != null) _say(message);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final account = ref.watch(payoutAccountProvider);
    final form = ref.watch(payoutAccountControllerProvider);
    ref.listen(payoutAccountProvider, (prev, next) {
      if (next.hasValue && prev?.value != next.value) {
        ref.read(payoutAccountControllerProvider.notifier).ackSaved();
      }
    });
    final showForm =
        account.hasValue &&
        !form.justSaved &&
        (account.requireValue == null || form.editing);
    return ScreenCode(
      ScreenCodes.payoutAccount,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: context.canPop()
                ? null
                : IconButton(
                    tooltip: l.back,
                    icon: const AppIcon(AppIcons.back),
                    onPressed: () => context.go('/work/earnings'),
                  ),
            title: Text(l.payoutAccountTitle),
          ),
          body: AsyncView<PayoutAccountView?>(
            value: account,
            onRetry: () => ref.invalidate(payoutAccountProvider),
            skeleton: (_) => const _Skeleton(),
            error: (context, _, _) => ErrorState(
              message: l.earningsLoadError,
              onRetry: () => ref.invalidate(payoutAccountProvider),
            ),
            data: (context, a) => form.justSaved
                ? const _Skeleton()
                : showForm
                ? _AccountForm(current: a, onSubmit: _save)
                : _ReadView(account: a!),
          ),
          bottomNavigationBar: showForm
              ? AppFooterBar(
                  child: AppButton.primary(
                    l.payoutAccountSave,
                    key: const Key('payout-save'),
                    loading: form.saving,
                    onPressed: form.valid == null || form.saving ? null : _save,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      AppSkeleton.line(widthFactor: 0.8),
      const SizedBox(height: AppSpace.s4),
      for (var i = 0; i < 3; i++) ...[
        AppSkeleton.box(height: AppSpace.s12 + AppSpace.s2),
        const SizedBox(height: AppSpace.s3),
      ],
    ],
  );
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({required this.current, required this.onSubmit});

  /// The account being changed, or null for a first account.
  final PayoutAccountView? current;
  final VoidCallback onSubmit;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _number = TextEditingController();
  final _numberFocus = FocusNode();
  var _numberTouched = false;

  @override
  void initState() {
    super.initState();
    _numberFocus.addListener(() {
      if (!_numberFocus.hasFocus && !_numberTouched) {
        setState(() => _numberTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _number.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  Future<void> _pickBank() async {
    final form = ref.read(payoutAccountControllerProvider);
    final bank = await showBankPicker(context, selected: form.bank?.code);
    if (bank != null && mounted) {
      ref.read(payoutAccountControllerProvider.notifier).setBank(bank);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final form = ref.watch(payoutAccountControllerProvider);
    final controller = ref.read(payoutAccountControllerProvider.notifier);
    // A finished save clears the form; clear the field with it.
    ref.listen(payoutAccountControllerProvider, (prev, next) {
      if (next.number.isEmpty && _number.text.isNotEmpty) _number.clear();
    });
    final numberBad =
        _numberTouched && normalizeAccountNumber(form.number) == null;
    final lookup = form.lookup;
    final mismatch =
        lookup is LookupDone &&
        lookup.result.decision == PayoutNameDecision.mismatch;
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final current = widget.current;
    final changing = form.editing && current != null;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          changing
              ? l.payoutAccountIntroChange(
                  _bankOf(current.bankCode)?.shortName ?? current.bankCode,
                  current.accountLast4,
                )
              : l.payoutAccountIntro,
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpace.s4),
        BankField(bank: form.bank, onTap: form.saving ? null : _pickBank),
        const SizedBox(height: AppSpace.s3),
        TextField(
          key: const Key('payout-number'),
          controller: _number,
          focusNode: _numberFocus,
          enabled: !form.saving,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [],
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: const [AccountNumberFormatter()],
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          onChanged: controller.setNumber,
          onSubmitted: (_) => controller.lookupNow(),
          decoration: InputDecoration(
            labelText: l.payoutAccountNumber,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            errorText: numberBad ? l.payoutAccountNumberError : null,
            // The mismatch alert below explains the red border.
            error: !numberBad && mismatch ? const SizedBox.shrink() : null,
          ),
        ),
        if (lookup is! LookupIdle) ...[
          const SizedBox(height: AppSpace.s3),
          NameLookupCard(view: lookup, onRetry: controller.lookupNow),
        ],
        const SizedBox(height: AppSpace.s3),
        Text(
          l.payoutAccountHint,
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        if (changing) ...[
          const SizedBox(height: AppSpace.s3),
          LockNote(text: l.payoutAccountChangeNote),
          const SizedBox(height: AppSpace.s3),
          AppButton.text(
            l.actionCancel,
            key: const Key('payout-cancel-change'),
            onPressed: form.saving ? null : controller.cancelChange,
          ),
        ],
      ],
    );
  }
}

class _ReadView extends ConsumerWidget {
  const _ReadView({required this.account});

  final PayoutAccountView account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final bank = _bankOf(account.bankCode);
    final bankName = bank?.shortName ?? account.bankCode;
    final masked = maskedAccount(account.accountLast4);
    final pending = account.pendingAt(ref.watch(clockProvider)());
    final review = account.nameStatus == PayoutNameStatus.pendingReview;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        GlassCard(
          highlight: false,
          child: Semantics(
            container: true,
            label: [
              bankName,
              l.payoutAccountMasked(account.accountLast4),
              account.holderName,
              if (pending) l.payoutAccountPendingBadge,
            ].join(', '),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Row(
                children: [
                  BankBadge(code: account.bankCode),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$bankName $masked',
                          key: const Key('payout-masked'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          account.holderName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(width: AppSpace.s2),
                    Flexible(
                      child: StatusBadge.custom(
                        label: l.payoutAccountPendingBadge,
                        color: AppColors.warning,
                        onColor: AppColors.foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (pending) ...[
          const SizedBox(height: AppSpace.s3),
          GlassCard(
            highlight: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(AppIcons.schedule, color: secondary),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.payoutAccountPendingTitle(
                            _vnTimeLabel(account.activeFrom),
                          ),
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpace.s1),
                        Text(
                          l.payoutAccountPendingBody,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (review) ...[
          const SizedBox(height: AppSpace.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(AppIcons.info, size: AppText.base, color: secondary),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  l.payoutAccountReviewNote,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s4),
        AppButton.outline(
          l.payoutAccountChange,
          key: const Key('payout-change'),
          onPressed: () => ref
              .read(payoutAccountControllerProvider.notifier)
              .startChange(account.bankCode),
        ),
      ],
    );
  }
}

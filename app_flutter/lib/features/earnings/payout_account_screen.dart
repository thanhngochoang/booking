// lib/features/earnings/payout_account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/earnings/earnings.dart';
import 'package:photobooking/data/earnings/earnings_providers.dart';
import 'package:photobooking/data/earnings/payout_account_rules.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/features/earnings/payout_account_controller.dart';
import 'package:photobooking/features/earnings/widgets/account_inputs.dart';
import 'package:photobooking/features/earnings/widgets/bank_picker_sheet.dart';
import 'package:photobooking/features/earnings/widgets/reauth_sheet.dart';

/// S06.06 "Tài khoản nhận tiền" at `/work/earnings/account`: one bank account
/// for payouts. Without one it is a form; with one it shows the masked number
/// ("•••• 3456") and "Đổi tài khoản". The full number is never shown again.
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
    if (form.editing) {
      final go = await showConfirmSheet(
        context,
        title: l.payoutAccountChangeTitle,
        body: l.payoutAccountChangeBody,
        confirmLabel: l.payoutAccountChangeConfirm,
        keepLabel: l.actionCancel,
        danger: false,
      );
      if (!go || !mounted) return;
    }
    final outcome = await ref
        .read(payoutAccountControllerProvider.notifier)
        .save(reauth: () async => mounted && await showReauthSheet(context));
    if (!mounted) return;
    switch (outcome) {
      case PayoutSaveOutcome.saved:
        _say(l.payoutAccountSaved);
      case PayoutSaveOutcome.conflict:
        _say(l.payoutAccountBusy);
      case PayoutSaveOutcome.failed:
        _say(l.payoutAccountSaveError);
      case PayoutSaveOutcome.cancelled || PayoutSaveOutcome.invalid:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final account = ref.watch(payoutAccountProvider);
    final form = ref.watch(payoutAccountControllerProvider);
    final showForm =
        account.hasValue && (account.requireValue == null || form.editing);
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
            data: (context, a) => showForm
                ? _AccountForm(onSubmit: _save)
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
  const _AccountForm({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _bank = TextEditingController();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _numberFocus = FocusNode();
  final _holderFocus = FocusNode();
  var _numberTouched = false;
  var _holderTouched = false;

  @override
  void initState() {
    super.initState();
    _bank.text =
        ref.read(payoutAccountControllerProvider).bank?.shortName ?? '';
    _numberFocus.addListener(() {
      if (!_numberFocus.hasFocus && !_numberTouched) {
        setState(() => _numberTouched = true);
      }
    });
    _holderFocus.addListener(() {
      if (!_holderFocus.hasFocus && !_holderTouched) {
        setState(() => _holderTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _holder.dispose();
    _numberFocus.dispose();
    _holderFocus.dispose();
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
    // A finished save clears the form; clear the fields with it.
    ref.listen(payoutAccountControllerProvider, (prev, next) {
      final name = next.bank?.shortName ?? '';
      if (_bank.text != name) _bank.text = name;
      if (next.number.isEmpty && _number.text.isNotEmpty) _number.clear();
      if (next.holder.isEmpty && _holder.text.isNotEmpty) _holder.clear();
    });
    final numberBad =
        _numberTouched && normalizeAccountNumber(form.number) == null;
    final holderBad =
        _holderTouched && normalizeHolderName(form.holder) == null;
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          l.payoutAccountIntro,
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpace.s4),
        Semantics(
          button: true,
          excludeSemantics: true,
          label:
              '${l.payoutAccountBank}, ${form.bank?.shortName ?? l.payoutAccountBankPick}',
          onTap: form.saving ? null : _pickBank,
          child: TextField(
            key: const Key('payout-bank'),
            controller: _bank,
            readOnly: true,
            enabled: !form.saving,
            onTap: _pickBank,
            decoration: InputDecoration(
              labelText: l.payoutAccountBank,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: l.payoutAccountBankPick,
              suffixIcon: const AppIcon(AppIcons.expandMore),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        TextField(
          key: const Key('payout-number'),
          controller: _number,
          focusNode: _numberFocus,
          enabled: !form.saving,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [],
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: const [AccountNumberFormatter()],
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          onChanged: controller.setNumber,
          onSubmitted: (_) => _holderFocus.requestFocus(),
          decoration: InputDecoration(
            labelText: l.payoutAccountNumber,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            errorText: numberBad ? l.payoutAccountNumberError : null,
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        TextField(
          key: const Key('payout-holder'),
          controller: _holder,
          focusNode: _holderFocus,
          enabled: !form.saving,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          enableSuggestions: false,
          autocorrect: false,
          inputFormatters: const [HolderNameFormatter()],
          onChanged: controller.setHolder,
          onSubmitted: (_) {
            if (form.valid != null) widget.onSubmit();
          },
          decoration: InputDecoration(
            labelText: l.payoutAccountHolder,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            errorText: holderBad ? l.payoutAccountHolderError : null,
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        Text(
          l.payoutAccountHint,
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        if (form.editing) ...[
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
    VnBank? bank;
    for (final b in vnBanks) {
      if (b.code == account.bankCode) bank = b;
    }
    final masked = maskedAccount(account.accountLast4);
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        Text(
          l.payoutAccountIntro,
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpace.s4),
        GlassCard(
          highlight: false,
          child: Semantics(
            container: true,
            label:
                '${bank?.shortName ?? account.bankCode}, ${l.payoutAccountMasked(account.accountLast4)}, ${account.holderName}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Row(
                children: [
                  const AppIcon(AppIcons.payment),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank?.shortName ?? account.bankCode,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (bank != null)
                          Text(bank.name, style: theme.textTheme.bodySmall),
                        const SizedBox(height: AppSpace.s2),
                        Text(
                          masked,
                          key: const Key('payout-masked'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          account.holderName,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        Text(
          l.payoutAccountHint,
          style: theme.textTheme.bodySmall?.copyWith(color: secondary),
        ),
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

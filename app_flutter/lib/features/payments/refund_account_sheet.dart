// lib/features/payments/refund_account_sheet.dart
//
// S22.04 "Tài khoản nhận hoàn" (#141): where a policy refund of a bank
// transfer goes. By default the account the money came from (mock
// `#S22.04`); "Dùng tài khoản khác" opens the S06.06-like form (mock
// `#S22.04-other`): pick a bank, type the number, the bank answers the
// holder name. Without a paying account the sheet opens on the form. Only
// the bank, the last 4 digits and the holder name are ever shown.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/earnings/payout_account_rules.dart';
import 'package:photobooking/data/earnings/vn_banks.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/features/earnings/widgets/account_inputs.dart';
import 'package:photobooking/features/earnings/widgets/bank_picker_sheet.dart';
import 'package:photobooking/features/payments/refund_account_controller.dart';

/// Opens S22.04 for the refund of [subject] that waits for the customer's
/// account; does nothing when none waits. Says "Đã gửi yêu cầu hoàn tiền"
/// only when the server took the choice; when the refund already left (the
/// 24-hour default, another choice or staff) it names the account the money
/// went to (S22.01's row), never the one chosen.
Future<void> showRefundAccountSheet(
  BuildContext context,
  WidgetRef ref,
  RefundSubject subject,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String text) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  final repo = ref.read(paymentsRepositoryProvider);
  PendingRefund? pending;
  try {
    pending = await repo.pendingRefund(subject);
  } catch (_) {
    say(l.refundAccountLoadError);
    return;
  }
  if (pending == null || !context.mounted) return;
  final outcome = await showAppSheet<RefundChooseResult>(
    context,
    // The form has a text field: dragging would fight typing.
    enableDrag: false,
    builder: (_) =>
        _RefundAccountSheet(args: (subject: subject, pending: pending!)),
  );
  switch (outcome) {
    case RefundChosen():
      say(l.refundAccountSent);
    case RefundAlreadySent(:final destination):
      say(
        destination == null
            ? l.refundAccountAlreadySent
            : l.refundAccountWentTo(destination),
      );
    case RefundNotChosen() || null:
      break;
  }
}

/// The bank of a payer account the server names by its short name.
VnBank? _bankNamed(String name) {
  for (final b in vnBanks) {
    if (b.shortName == name || b.name == name || b.code == name) return b;
  }
  return null;
}

class _RefundAccountSheet extends ConsumerStatefulWidget {
  const _RefundAccountSheet({required this.args});

  final RefundAccountArgs args;

  @override
  ConsumerState<_RefundAccountSheet> createState() =>
      _RefundAccountSheetState();
}

class _RefundAccountSheetState extends ConsumerState<_RefundAccountSheet> {
  final _number = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  RefundAccountController get _controller =>
      ref.read(refundAccountControllerProvider(widget.args).notifier);

  Future<void> _pickBank() async {
    final current = ref.read(refundAccountControllerProvider(widget.args));
    final bank = await showBankPicker(context, selected: current.bank?.code);
    if (bank != null && mounted) _controller.setBank(bank);
  }

  Future<void> _lookup() async {
    if (!ref.read(refundAccountControllerProvider(widget.args)).canLookup) {
      return;
    }
    FocusScope.of(context).unfocus();
    final result = await _controller.lookup();
    // The refund stopped waiting while the sheet was open.
    if (mounted && result is RefundAlreadySent) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _confirm() async {
    final result = await _controller.confirm();
    if (!mounted || result is RefundNotChosen) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(refundAccountControllerProvider(widget.args));
    final pending = widget.args.pending;
    final payer = pending.payer;
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final quiet = theme.textTheme.bodySmall?.copyWith(color: secondary);
    const gap = SizedBox(height: AppSpace.s3);
    final onPayer = state.step == RefundAccountStep.payer && payer != null;
    return ScreenCode(
      ScreenCodes.refundAccount,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s4,
          0,
          AppSpace.s4,
          AppSpace.s4,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.refundAccountTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('refund-account-close'),
                  tooltip: l.refundAccountClose,
                  icon: const AppIcon(AppIcons.close),
                  onPressed: state.sending
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text(l.refundAccountYouGet, style: quiet)),
                const SizedBox(width: AppSpace.s2),
                Text(
                  formatMoney(pending.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: AppText.md,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            gap,
            if (onPayer) ...[
              Text(l.refundAccountToPayer, style: quiet),
              const SizedBox(height: AppSpace.s2),
              _PayerCard(payer: payer),
            ] else
              ..._form(context, state, quiet),
            gap,
            if (state.error case final error?) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  switch (error) {
                    RefundConfirmError.failed => l.refundAccountFailed,
                    RefundConfirmError.stale => l.refundAccountLookupStale,
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s2),
            ],
            AppButton.primary(
              l.refundAccountConfirm,
              key: const Key('refund-account-confirm'),
              loading: state.sending,
              onPressed: state.canConfirm ? _confirm : null,
            ),
            if (onPayer) ...[
              const SizedBox(height: AppSpace.s1),
              AppButton.text(
                l.refundAccountOther,
                key: const Key('refund-account-other'),
                onPressed: state.sending ? null : _controller.useOther,
              ),
              if (pending.confirmBy != null) ...[
                const SizedBox(height: AppSpace.s1),
                Text(l.refundAccountAutoNote, style: quiet),
              ],
              const SizedBox(height: AppSpace.s2),
              Text(l.refundAccountWalletNote, style: quiet),
            ] else ...[
              if (payer != null) ...[
                const SizedBox(height: AppSpace.s1),
                AppButton.text(
                  l.refundAccountBackToPayer,
                  key: const Key('refund-account-back-to-payer'),
                  onPressed: state.sending || state.lookingUp
                      ? null
                      : _controller.usePayer,
                ),
              ],
              const SizedBox(height: AppSpace.s2),
              Text(l.refundAccountEncrypted, style: quiet),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _form(
    BuildContext context,
    RefundAccountState state,
    TextStyle? quiet,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final lookup = state.lookup;
    final failure = switch (lookup) {
      RefundLookupFailed(code: 'not_found') => l.refundAccountNotFound,
      RefundLookupFailed(code: 'not_eligible') => l.refundAccountUnsupported,
      RefundLookupFailed(code: 'limit_exceeded') => l.refundAccountLookupLimit,
      RefundLookupFailed() => l.refundAccountLookupError,
      _ => null,
    };
    return [
      if (widget.args.pending.payer == null) ...[
        Text(l.refundAccountNoPayer, style: quiet),
        const SizedBox(height: AppSpace.s3),
      ],
      BankField(
        label: l.refundAccountBank,
        bank: state.bank,
        // Locked while the bank answers: the account shown is the one asked.
        onTap: state.sending || state.lookingUp ? null : _pickBank,
      ),
      const SizedBox(height: AppSpace.s3),
      TextField(
        key: const Key('refund-number'),
        controller: _number,
        enabled: !state.sending && !state.lookingUp,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.search,
        autofillHints: const [],
        enableSuggestions: false,
        autocorrect: false,
        inputFormatters: const [AccountNumberFormatter()],
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        onChanged: _controller.setNumber,
        onSubmitted: (_) => _lookup(),
        decoration: InputDecoration(
          labelText: l.refundAccountNumber,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
      const SizedBox(height: AppSpace.s2),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: AppButton.outline(
          l.refundAccountLookup,
          key: const Key('refund-account-lookup'),
          size: AppButtonSize.small,
          loading: lookup is RefundLookupLoading,
          onPressed: state.canLookup ? _lookup : null,
        ),
      ),
      if (lookup is RefundLookupFound) ...[
        const SizedBox(height: AppSpace.s2),
        _LookupCard(holderName: lookup.holderName),
      ],
      if (failure != null) ...[
        const SizedBox(height: AppSpace.s2),
        Semantics(
          liveRegion: true,
          child: Text(
            failure,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ];
  }
}

/// The mock's `.lkp` for the paying account: bank badge, "Vietcombank ••••
/// 6789", the holder name and a check.
class _PayerCard extends StatelessWidget {
  const _PayerCard({required this.payer});

  final RefundPayerAccount payer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final bank = _bankNamed(payer.bankName);
    final account = '${payer.bankName} ${maskedAccount(payer.accountLast4)}';
    return GlassCard(
      highlight: false,
      child: Semantics(
        container: true,
        label: '$account, ${payer.holderName}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            children: [
              if (bank != null) ...[
                BankBadge(code: bank.code),
                const SizedBox(width: AppSpace.s3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      payer.holderName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              const _OkMark(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The looked-up holder name of the other account (mock `#S22.04-other`).
class _LookupCard extends StatelessWidget {
  const _LookupCard({required this.holderName});

  final String holderName;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Semantics(
      liveRegion: true,
      container: true,
      child: GlassCard(
        highlight: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Row(
            children: [
              const _OkMark(),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(holderName, style: theme.textTheme.titleSmall),
                    Text(
                      l.refundAccountLookupNote,
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
    );
  }
}

/// The mock's `.ok`: a round success mark with a check.
class _OkMark extends StatelessWidget {
  const _OkMark();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: AppSpace.s6,
      height: AppSpace.s6,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const AppIcon(
        AppIcons.check,
        size: AppText.base,
        color: AppColors.foregroundInverse,
      ),
    ),
  );
}

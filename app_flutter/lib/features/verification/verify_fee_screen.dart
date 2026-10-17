// lib/features/verification/verify_fee_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/features/payment/open_payment.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/verification/widgets/verify_parts.dart';

/// S21.02-fee "Phí xác minh" (#203, mock `#S21.02-fee`): what the fee buys,
/// the amount of the provider's kind (individual 99.000₫, studio 299.000₫),
/// the no-refund note and the shared method list. "Thanh toán {amount}"
/// starts the fee (`startVerificationFee`) and opens V1's S04.04 for the
/// [VerificationFeePay] subject, which comes back to S21.02 once paid.
class VerifyFeeScreen extends ConsumerStatefulWidget {
  const VerifyFeeScreen({super.key});

  @override
  ConsumerState<VerifyFeeScreen> createState() => _VerifyFeeScreenState();
}

class _VerifyFeeScreenState extends ConsumerState<VerifyFeeScreen> {
  PayMethod _method = PayMethod.bankQr;
  bool _busy = false;

  Future<void> _pay() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.verifyFeeFailed;
    try {
      final instructions = await ref
          .read(verificationRepositoryProvider)
          .startFee(_method);
      if (!mounted) {
        return;
      }
      await openPayment(
        context,
        ref,
        subject: const VerificationFeePay(),
        instructions: instructions,
      );
    } on Exception {
      // A refusal, an unreachable server or a wallet link that would not
      // open: the method stays chosen for another try.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(myVerificationProvider);
    final s = async.value;
    final steps = s?.requiredSteps ?? const <VerifyStep>[];
    final position = steps.indexOf(VerifyStep.fee) + 1;
    return ScreenCode(
      ScreenCodes.verifyPhotographer,
      label: 'fee',
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l.verifyFeeTitle),
            actions: [
              if (position > 0)
                VerifyCounter(position: position, total: steps.length),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: AsyncView<VerificationState>(
              value: async,
              loadingLabel: l.loadingLabel,
              onRetry: () => ref.invalidate(myVerificationProvider),
              data: (context, s) => _body(context, s, position),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, VerificationState s, int position) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final amount = formatMoney(s.feeAmount ?? verificationFeeVnd[s.kind]!);
    final paid = s.isDone(VerifyStep.fee);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (position > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
            child: StepProgress(
              current: position,
              total: s.requiredSteps.length,
              showCount: false,
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Benefits(),
                const SizedBox(height: AppSpace.s4),
                Text(
                  amount,
                  key: const Key('verify-fee-amount'),
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontSize: AppText.xl,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSpace.s1),
                VerifyMeta(
                  s.kind == VerificationKind.studio
                      ? l.verifyFeeKindStudio
                      : l.verifyFeeKindIndividual,
                ),
                const SizedBox(height: AppSpace.s3),
                VerifyNote(icon: AppIcons.info, text: l.verifyFeeNoRefund),
                const SizedBox(height: AppSpace.s4),
                if (paid)
                  VerifyMeta(l.verifyFeePaid)
                else
                  PayMethodSelector(
                    value: _method,
                    enabled: !_busy,
                    onChanged: (m) => setState(() => _method = m),
                  ),
              ],
            ),
          ),
        ),
        AppFooterBar(
          child: AppButton.primary(
            l.verifyFeePay(amount),
            key: const Key('verify-fee-pay'),
            loading: _busy,
            onPressed: paid || _busy ? null : _pay,
          ),
        ),
      ],
    );
  }
}

/// Mock `.card` with `.ben`: "Bạn nhận được" and three checks.
class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final check = dark ? AppColorsDark.freeInk : AppColors.freeInk;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.verifyFeeYouGet,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            for (final text in [
              l.verifyFeeBenefitTick,
              l.verifyFeeBenefitOrders,
              l.verifyFeeBenefitReview,
            ]) ...[
              const SizedBox(height: AppSpace.s2),
              Row(
                children: [
                  ExcludeSemantics(
                    child: AppIcon(
                      AppIcons.check,
                      size: AppText.md,
                      color: check,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

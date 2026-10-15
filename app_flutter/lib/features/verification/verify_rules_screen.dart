// lib/features/verification/verify_rules_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/data/verification/verification_repository.dart';
import 'package:photobooking/features/verification/verify_start_screen.dart';

/// S21.02 rules step (mock `#S21.02-rules`): five lines (Decision 10), one
/// check box, then "Gửi duyệt" accepts [providerRulesVersion] and, when the
/// other required steps are done, sends the record for review. Either way it
/// returns to S21.02, which shows what comes next.
class VerifyRulesScreen extends ConsumerStatefulWidget {
  const VerifyRulesScreen({super.key});

  @override
  ConsumerState<VerifyRulesScreen> createState() => _VerifyRulesScreenState();
}

class _VerifyRulesScreenState extends ConsumerState<VerifyRulesScreen> {
  bool? _agreed;
  bool _busy = false;

  Future<void> _send() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(verificationRepositoryProvider);
    final before = ref.read(myVerificationProvider).value;
    try {
      await repo.acceptRules(providerRulesVersion);
      // The rules were the last step: send now, as the button says.
      final othersDone =
          before != null &&
          before.requiredSteps
              .where((s) => s != VerifyStep.rules)
              .every(before.isDone);
      if (othersDone && before.status != VerificationStatus.rejected) {
        await repo.submit();
      }
      if (mounted) {
        // S21.02 is underneath when opened from it: pop keeps its back stack.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(verifyStartPath);
        }
      }
    } on VerificationError {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.engagementError)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = ref.watch(myVerificationProvider).value;
    final total =
        (s ??
                VerificationState.initial(
                  VerificationKind.individual,
                  feeRequired: ref.watch(verificationFeeRequiredProvider),
                ))
            .requiredSteps;
    final position = total.indexOf(VerifyStep.rules) + 1;
    final agreed = _agreed ?? s?.rulesAcceptedAt != null;
    final rules = [
      l.verifyRule1,
      l.verifyRule2,
      l.verifyRule3,
      l.verifyRule4,
      l.verifyRule5,
    ];
    return ScreenCode(
      ScreenCodes.verifyPhotographer,
      label: 'rules',
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l.verifyRulesTitle),
            actions: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpace.s4),
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      l.verifyStepCounter(position, total.length),
                      key: const Key('verify-counter'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
                  child: StepProgress(
                    current: position,
                    total: total.length,
                    showCount: false,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.verifyRulesIntro,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? AppColorsDark.foregroundSecondary
                                : AppColors.foregroundSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.s4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final (i, rule) in rules.indexed) ...[
                                  if (i > 0)
                                    const SizedBox(height: AppSpace.s2),
                                  Text.rich(
                                    key: Key('verify-rule-${i + 1}'),
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${i + 1}. ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(text: rule),
                                      ],
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        CheckboxListTile(
                          key: const Key('verify-rules-agree'),
                          value: agreed,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _agreed = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            l.verifyRulesAgree,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AppFooterBar(
                  child: AppButton.primary(
                    l.verifySubmit,
                    key: const Key('verify-rules-submit'),
                    loading: _busy,
                    onPressed: agreed && s != null ? _send : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

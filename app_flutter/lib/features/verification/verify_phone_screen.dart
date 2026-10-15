// lib/features/verification/verify_phone_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/features/contact/return_to.dart';
import 'package:photobooking/features/verification/verify_phone_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The S21.02 checklist; opened from there, S21.01 shows "1 / {total}".
const _verifyStartPath = '/verify/start';

/// S21.01: verify the phone number by SMS code (Firebase Auth), then go to
/// [returnTo] (or back). Frames `#S21.01` (number) and `#S21.01-code`.
class VerifyPhoneScreen extends ConsumerWidget {
  const VerifyPhoneScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final to = safeReturnTo(returnTo);
    final inFlow = to != null && Uri.parse(to).path == _verifyStartPath;
    final total = VerificationState.initial(
      VerificationKind.individual,
      feeRequired: ref.watch(verificationFeeRequiredProvider),
    ).requiredSteps.length;
    return ScreenCode(
      ScreenCodes.verifyPhone,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l.verifyPhoneTitle),
            actions: [
              if (inFlow)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.s4),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(
                        l.stepProgressCount(1, total),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // The bottom inset belongs to the sticky AppFooterBar.
          body: SafeArea(
            top: false,
            bottom: false,
            child: AsyncView<UserContact?>(
              value: ref.watch(currentContactProvider),
              loadingLabel: l.loadingLabel,
              onRetry: () => ref.invalidate(currentContactProvider),
              data: (context, _) => _VerifyPhoneBody(
                returnTo: to,
                progressTotal: inFlow ? total : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerifyPhoneBody extends ConsumerStatefulWidget {
  const _VerifyPhoneBody({required this.returnTo, this.progressTotal});

  final String? returnTo;

  /// Steps of the S21.02 flow, or null when opened on its own.
  final int? progressTotal;

  @override
  ConsumerState<_VerifyPhoneBody> createState() => _VerifyPhoneBodyState();
}

class _VerifyPhoneBodyState extends ConsumerState<_VerifyPhoneBody> {
  late final TextEditingController _phone;
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    final saved = ref.read(verifyPhoneControllerProvider).phone;
    _phone = TextEditingController(
      text: saved == null ? '' : nationalFromE164(saved),
    );
  }

  VerifyPhoneController get _controller =>
      ref.read(verifyPhoneControllerProvider.notifier);

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _leave() {
    final to = widget.returnTo;
    if (to != null) {
      context.go(to);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.profile.path);
    }
  }

  String? _issueText(AppLocalizations l, VerifyPhoneIssue? issue) =>
      switch (issue) {
        null => null,
        VerifyPhoneIssue.required => l.phoneRequired,
        VerifyPhoneIssue.invalidPhone => l.verifyPhoneInvalid,
        VerifyPhoneIssue.inUse => l.verifyPhoneInUse,
        VerifyPhoneIssue.tooMany => l.verifyPhoneTooMany,
        VerifyPhoneIssue.wrongCode => l.verifyCodeWrong,
        VerifyPhoneIssue.expiredCode => l.verifyCodeExpired,
        VerifyPhoneIssue.failed => l.engagementError,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(verifyPhoneControllerProvider);
    ref.listen(verifyPhoneControllerProvider, (prev, next) {
      if (next.justVerified && !(prev?.justVerified ?? false)) {
        _leave();
        return;
      }
      if (prev?.step != next.step && next.step == VerifyPhoneStep.code) {
        // A new code (or a wrong one) starts from empty boxes; a failed
        // server call after a good code keeps it for the retry.
        if (prev?.step != VerifyPhoneStep.confirming ||
            next.issue == VerifyPhoneIssue.wrongCode ||
            next.issue == VerifyPhoneIssue.expiredCode) {
          _code.clear();
        }
      }
    });

    final (Widget content, Widget action) = switch (s.step) {
      VerifyPhoneStep.enter || VerifyPhoneStep.sending => (
        _NumberStep(
          controller: _phone,
          errorText: _issueText(l, s.issue),
          enabled: !s.busy,
          onChanged: (_) => _controller.clearIssue(),
        ),
        AppButton.primary(
          l.verifyPhoneSend,
          key: const Key('verify-send'),
          loading: s.step == VerifyPhoneStep.sending,
          onPressed: () => _controller.send(_phone.text),
        ),
      ),
      VerifyPhoneStep.code || VerifyPhoneStep.confirming => (
        _CodeStep(
          state: s,
          controller: _code,
          errorText: _issueText(l, s.issue),
          onChanged: _controller.clearIssue,
          onResend: _controller.resend,
          onChangeNumber: _controller.changeNumber,
        ),
        ListenableBuilder(
          listenable: _code,
          builder: (context, _) => AppButton.primary(
            l.verifyCodeConfirm,
            key: const Key('verify-confirm'),
            loading: s.step == VerifyPhoneStep.confirming,
            onPressed: _code.text.length == otpCodeLength && !s.busy
                ? () => _controller.confirm(_code.text)
                : null,
          ),
        ),
      ),
      VerifyPhoneStep.done => (
        _DoneStep(phone: s.phone, onChangeNumber: _controller.changeNumber),
        AppButton.primary(
          l.setupNext,
          key: const Key('verify-continue'),
          onPressed: _leave,
        ),
      ),
    };

    final total = widget.progressTotal;
    final onCode =
        s.step == VerifyPhoneStep.code || s.step == VerifyPhoneStep.confirming;
    return PopScope(
      // Back from the code step returns to the number, like "Đổi số".
      canPop: !onCode && !s.busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && s.step == VerifyPhoneStep.code) {
          _controller.changeNumber();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (total != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
              child: StepProgress(current: 1, total: total, showCount: false),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: content,
            ),
          ),
          AppFooterBar(child: action),
        ],
      ),
    );
  }
}

Color _secondary(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColorsDark.foregroundSecondary
    : AppColors.foregroundSecondary;

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpace.s1),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _secondary(theme),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// `#S21.01`: heading, body, the +84 number field and the example line.
class _NumberStep extends StatelessWidget {
  const _NumberStep({
    required this.controller,
    required this.errorText,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(title: l.verifyPhoneHeading, body: l.verifyPhoneBody),
        const SizedBox(height: AppSpace.s4),
        Semantics(
          liveRegion: errorText != null,
          child: PhoneField(
            key: const Key('verify-phone'),
            controller: controller,
            errorText: errorText,
            enabled: enabled,
            autofocus: true,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Text(
          l.verifyPhoneExample,
          style: theme.textTheme.bodySmall?.copyWith(color: _secondary(theme)),
        ),
      ],
    );
  }
}

/// `#S21.01-code`: heading, "Đã gửi tới •••• 5678", the six-digit input, the
/// resend countdown (then "Gửi lại mã") and "Đổi số điện thoại".
class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.state,
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onResend,
    required this.onChangeNumber,
  });

  final VerifyPhoneState state;
  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onResend;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final busy = state.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(
          title: l.verifyCodeHeading,
          body: l.verifyCodeSentTo(state.last4),
        ),
        const SizedBox(height: AppSpace.s4),
        Semantics(
          liveRegion: errorText != null,
          child: _OnEdit(
            controller: controller,
            onChanged: onChanged,
            child: OtpCodeField(
              key: const Key('verify-code'),
              controller: controller,
              errorText: errorText,
              enabled: state.step != VerifyPhoneStep.confirming,
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: state.resendIn > 0
              ? Semantics(
                  liveRegion: isCountdownAnnounceSecond(state.resendIn),
                  child: Text(
                    l.verifyCodeResendIn(_clock(state.resendIn)),
                    key: const Key('verify-resend-in'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _secondary(theme),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                )
              : AppButton.text(
                  l.verifyCodeResend,
                  key: const Key('verify-resend'),
                  size: AppButtonSize.small,
                  tapAlignment: AlignmentDirectional.centerStart.resolve(
                    Directionality.of(context),
                  ),
                  loading: state.resending,
                  onPressed: busy ? null : onResend,
                ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.text(
            l.verifyCodeChangePhone,
            key: const Key('verify-change'),
            size: AppButtonSize.small,
            tapAlignment: AlignmentDirectional.centerStart.resolve(
              Directionality.of(context),
            ),
            onPressed: busy ? null : onChangeNumber,
          ),
        ),
      ],
    );
  }
}

/// Calls [onChanged] when the user edits [controller]'s text (not on
/// programmatic clears that leave it empty).
class _OnEdit extends StatefulWidget {
  const _OnEdit({
    required this.controller,
    required this.onChanged,
    required this.child,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final Widget child;

  @override
  State<_OnEdit> createState() => _OnEditState();
}

class _OnEditState extends State<_OnEdit> {
  late String _last = widget.controller.text;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final text = widget.controller.text;
    if (text == _last) {
      return;
    }
    _last = text;
    if (text.isNotEmpty) {
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Already verified (or just now, without a place to go back to): the number
/// and a way to change it.
class _DoneStep extends StatelessWidget {
  const _DoneStep({required this.phone, required this.onChangeNumber});

  final String? phone;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIcon(
              AppIcons.checkCircle,
              size: AppText.xl,
              color: theme.brightness == Brightness.dark
                  ? AppColorsDark.success
                  : AppColors.success,
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  l.verifyPhoneDone,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
        if (p != null) ...[
          const SizedBox(height: AppSpace.s1),
          Text(
            '0${nationalFromE164(p)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _secondary(theme),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(height: AppSpace.s2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.text(
            l.verifyCodeChangePhone,
            key: const Key('verify-change'),
            size: AppButtonSize.small,
            tapAlignment: AlignmentDirectional.centerStart.resolve(
              Directionality.of(context),
            ),
            onPressed: onChangeNumber,
          ),
        ),
      ],
    );
  }
}

/// `42` → `0:42`, `60` → `1:00`.
String _clock(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

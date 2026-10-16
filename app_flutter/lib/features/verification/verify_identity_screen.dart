// lib/features/verification/verify_identity_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/features/verification/fake_identity_sheet.dart';
import 'package:photobooking/features/verification/verify_identity_controller.dart';
import 'package:photobooking/features/verification/verify_start_screen.dart';
import 'package:photobooking/features/verification/widgets/verify_parts.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S21.03 "Xác minh danh tính": VNeID first (mock `#S21.03`), the chip
/// fallback in two steps (`#S21.03-nfc`, `#S21.03-selfie`), then the result.
/// [method] picks the screen it opens on (`/verify/identity?method=nfc`).
/// The identity step needs no fee while `verificationFeeRequiredProvider` is
/// false (#203 adds that gate).
class VerifyIdentityScreen extends ConsumerWidget {
  const VerifyIdentityScreen({super.key, this.method = IdentityMethod.vneid});

  final IdentityMethod method;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myVerificationProvider);
    if (async.hasValue) {
      return _IdentityView(initial: method);
    }
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.verifyIdentity,
      label: method == IdentityMethod.nfc ? 'nfc' : null,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              method == IdentityMethod.nfc ? l.verifyNfcTitle : l.verifyIdTitle,
            ),
          ),
          body: AsyncView<VerificationState>(
            value: async,
            loadingLabel: l.loadingLabel,
            onRetry: () => ref.invalidate(myVerificationProvider),
            data: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _IdentityView extends ConsumerStatefulWidget {
  const _IdentityView({required this.initial});

  final IdentityMethod initial;

  @override
  ConsumerState<_IdentityView> createState() => _IdentityViewState();
}

class _IdentityViewState extends ConsumerState<_IdentityView> {
  VerifyIdentityController get _controller =>
      ref.read(verifyIdentityControllerProvider(widget.initial).notifier);

  Future<void> _askConsent() async {
    final agreed = await showFakeIdentitySheet(context);
    if (mounted) {
      await _controller.consent(agreed: agreed);
    }
  }

  /// Back to S21.02: pop when it is underneath, so its back stack stays.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(verifyStartPath);
    }
  }

  String _issueText(AppLocalizations l, IdentityIssue issue) => switch (issue) {
    IdentityIssue.underage => l.verifyIdUnderage,
    IdentityIssue.inUse => l.verifyIdInUse,
    IdentityIssue.rateLimited => l.verifyIdRateLimited,
    IdentityIssue.failed => l.verifyIdFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = verifyIdentityControllerProvider(widget.initial);
    final s = ref.watch(provider);
    ref.listen(provider, (prev, next) {
      if (next.phase == IdentityPhase.consent &&
          prev?.phase != IdentityPhase.consent) {
        _askConsent();
      }
    });
    final record =
        ref.watch(myVerificationProvider).value ??
        VerificationState.initial(
          VerificationKind.individual,
          feeRequired: ref.watch(verificationFeeRequiredProvider),
        );
    final steps = record.requiredSteps;
    final position = steps.indexOf(VerifyStep.identity) + 1;

    final passed = s.phase == IdentityPhase.passed;
    final nfc = !passed && s.method == IdentityMethod.nfc;
    final selfie =
        nfc &&
        (s.phase == IdentityPhase.selfie ||
            s.phase == IdentityPhase.completing);
    final issue = s.issue;
    final alert = issue == null
        ? null
        : VerifyAlert(
            _issueText(l, issue),
            key: const Key('verify-id-issue'),
            icon: issue.canRetry ? AppIcons.info : AppIcons.warning,
          );

    final (Widget content, Widget? action) = passed
        ? (
            _Passed(name: s.maskedName ?? ''),
            AppButton.primary(
              l.verifyContinue,
              key: const Key('verify-id-continue'),
              onPressed: _leave,
            ),
          )
        : selfie
        ? (
            _Selfie(alert: alert),
            AppButton.primary(
              l.verifySelfieStart,
              key: const Key('verify-selfie-start'),
              loading: s.phase == IdentityPhase.completing,
              onPressed: s.phase == IdentityPhase.selfie
                  ? _controller.capture
                  : null,
            ),
          )
        : nfc
        ? (
            _Chip(alert: alert),
            s.canTry
                ? AppButton.primary(
                    l.verifyNfcStart,
                    key: const Key('verify-nfc-start'),
                    loading: s.busy,
                    onPressed: s.phase == IdentityPhase.intro
                        ? _controller.start
                        : null,
                  )
                : null,
          )
        : (
            _Vneid(
              alert: alert,
              onNfc: s.canTry && !s.busy
                  ? () => _controller.useMethod(IdentityMethod.nfc)
                  : null,
              showNfc: s.canTry,
            ),
            s.canTry
                ? AppButton.primary(
                    l.verifyIdVneid,
                    key: const Key('verify-vneid'),
                    loading: s.busy,
                    onPressed: s.phase == IdentityPhase.intro
                        ? _controller.start
                        : null,
                  )
                : null,
          );

    // Back steps inside the screen before leaving it: selfie → chip, and
    // chip → VNeID when the screen opened on VNeID.
    final innerBack =
        s.phase == IdentityPhase.selfie ||
        (nfc &&
            s.phase == IdentityPhase.intro &&
            widget.initial == IdentityMethod.vneid);
    final calling =
        s.phase == IdentityPhase.starting ||
        s.phase == IdentityPhase.completing;

    return ScreenCode(
      ScreenCodes.verifyIdentity,
      label: nfc ? 'nfc' : null,
      child: AuroraBackground(
        child: PopScope(
          canPop: !innerBack && !calling,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              return;
            }
            if (s.phase == IdentityPhase.selfie) {
              _controller.backToChip();
            } else if (innerBack) {
              _controller.useMethod(IdentityMethod.vneid);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(nfc ? l.verifyNfcTitle : l.verifyIdTitle),
              actions: [VerifyCounter(position: position, total: steps.length)],
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!nfc)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s5,
                      ),
                      child: StepProgress(
                        current: position,
                        total: steps.length,
                        showCount: false,
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpace.s5),
                      child: content,
                    ),
                  ),
                  if (action != null) AppFooterBar(child: action),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `#S21.03`: illustration, heading, what is shared, consent and the chip
/// fallback link.
class _Vneid extends StatelessWidget {
  const _Vneid({
    required this.alert,
    required this.onNfc,
    required this.showNfc,
  });

  final Widget? alert;
  final VoidCallback? onNfc;
  final bool showNfc;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final warn = alert;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const VerifyIllustration(AppIcons.badge),
        const SizedBox(height: AppSpace.s3),
        VerifyHeading(title: l.verifyIdHeading, body: l.verifyIdBody),
        if (warn != null) ...[const SizedBox(height: AppSpace.s3), warn],
        const SizedBox(height: AppSpace.s3),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.verifyIdWeOnlyGet,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpace.s2),
                Wrap(
                  spacing: AppSpace.s1,
                  runSpacing: AppSpace.s1,
                  children: [
                    for (final field in [
                      l.verifyIdFieldName,
                      l.verifyIdFieldDob,
                      l.verifyIdFieldNumber,
                    ])
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColorsDark.surfaceMuted
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s2,
                            vertical: AppSpace.s1,
                          ),
                          child: Text(
                            field,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: verifySecondary(theme),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.s2),
                VerifyNote(icon: AppIcons.lock, text: l.verifyIdPrivacy),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        VerifyMeta(l.verifyIdConsent),
        if (showNfc) ...[
          const SizedBox(height: AppSpace.s4),
          TextButton(
            key: const Key('verify-id-nfc'),
            onPressed: onNfc,
            style: TextButton.styleFrom(
              foregroundColor: verifyAccent(theme),
              minimumSize: const Size.fromHeight(AppSpace.s12),
            ),
            child: Text(
              l.verifyIdNfcLink,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: verifyAccent(theme),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Bước 1/2 · Đọc chip" and "Bước 2/2 · Selfie", the current one bold, and
/// the two-segment bar (mock `.row` + `.prog`).
class _ChipSteps extends StatelessWidget {
  const _ChipSteps({required this.current});

  /// 1 (chip) or 2 (selfie).
  final int current;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final on = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    final off = theme.textTheme.bodySmall?.copyWith(
      color: verifySecondary(theme),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(l.verifyNfcStep1, style: current == 1 ? on : off),
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Text(
                l.verifyNfcStep2,
                textAlign: TextAlign.end,
                style: current == 2 ? on : off,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s2),
        StepProgress(current: current, total: 2, showCount: false),
      ],
    );
  }
}

/// `#S21.03-nfc`: step 1/2, hold the card to the back of the phone.
class _Chip extends StatelessWidget {
  const _Chip({required this.alert});

  final Widget? alert;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final warn = alert;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ChipSteps(current: 1),
        const SizedBox(height: AppSpace.s4),
        const Center(child: _NfcArt()),
        const SizedBox(height: AppSpace.s3),
        VerifyHeading(title: l.verifyNfcHeading, body: l.verifyNfcBody),
        if (warn != null) ...[const SizedBox(height: AppSpace.s3), warn],
        const SizedBox(height: AppSpace.s3),
        _NextRow(title: l.verifyNfcNextTitle, body: l.verifyNfcNextBody),
        const SizedBox(height: AppSpace.s3),
        VerifyNote(icon: AppIcons.info, text: l.verifyNfcNote),
      ],
    );
  }
}

/// `#S21.03-selfie`: step 2/2, a short liveness selfie.
class _Selfie extends StatelessWidget {
  const _Selfie({required this.alert});

  final Widget? alert;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final warn = alert;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ChipSteps(current: 2),
        const SizedBox(height: AppSpace.s4),
        const VerifyIllustration(AppIcons.camera),
        const SizedBox(height: AppSpace.s3),
        VerifyHeading(title: l.verifySelfieHeading, body: l.verifySelfieBody),
        if (warn != null) ...[const SizedBox(height: AppSpace.s3), warn],
        const SizedBox(height: AppSpace.s3),
        VerifyNote(icon: AppIcons.info, text: l.verifySelfieNote),
      ],
    );
  }
}

/// The result: "Đã xác minh: {masked name}".
class _Passed extends StatelessWidget {
  const _Passed({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: AppSpace.s4),
      const VerifyIllustration(AppIcons.verifiedUser),
      const SizedBox(height: AppSpace.s3),
      Semantics(
        liveRegion: true,
        child: VerifyHeading(title: context.l10n.verifyIdPassed(name)),
      ),
    ],
  );
}

/// Mock `.vstep` without a state: what comes after the chip.
class _NextRow extends StatelessWidget {
  const _NextRow({required this.title, required this.body});

  final String title;
  final String body;

  /// Mock `.vstep .no`.
  static const _circle = 26.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return MergeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.glass : AppColors.glass,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: dark ? AppColorsDark.border : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: _circle,
                  height: _circle,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 2,
                      color: dark
                          ? AppColorsDark.borderStrong
                          : AppColors.borderStrong,
                    ),
                  ),
                  child: AppIcon(
                    AppIcons.camera,
                    size: AppText.base,
                    color: verifyMuted(theme),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2h),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: verifySecondary(theme),
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

/// Mock `.nfc`: a phone outline with the ID card held against its back and
/// the contactless waves (accent; the phone in the muted ink). Decorative:
/// the heading below says the same.
class _NfcArt extends StatelessWidget {
  const _NfcArt();

  /// Mock `.nfc` box and its SVG viewBox.
  static const _size = Size(180, 140);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: _size,
        painter: _NfcPainter(
          accent: verifyAccent(theme),
          device: verifyMuted(theme),
        ),
      ),
    );
  }
}

class _NfcPainter extends CustomPainter {
  _NfcPainter({required this.accent, required this.device});

  final Color accent;
  final Color device;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn in the mock's 180×140 viewBox, scaled to [size].
    canvas.scale(size.width / 180, size.height / 140);
    Paint stroke(Color c, [double w = 2]) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dev = stroke(device);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(56, 4, 68, 128),
          const Radius.circular(14),
        ),
        dev,
      )
      ..drawLine(const Offset(82, 12), const Offset(98, 12), dev);

    final card = RRect.fromRectAndRadius(
      const Rect.fromLTWH(22, 64, 136, 70),
      const Radius.circular(9),
    );
    final ink = stroke(accent);
    canvas
      ..drawRRect(card, Paint()..color = accent.withValues(alpha: 0.14))
      ..drawRRect(card, ink)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(36, 82, 20, 16),
          const Radius.circular(3),
        ),
        ink,
      )
      ..drawLine(const Offset(68, 84), const Offset(116, 84), ink)
      ..drawLine(const Offset(68, 96), const Offset(102, 96), ink)
      ..drawLine(const Offset(36, 116), const Offset(108, 116), ink);

    final waves = stroke(accent, 2.4);
    canvas
      ..drawPath(
        Path()
          ..moveTo(78, 42)
          ..arcToPoint(
            const Offset(102, 42),
            radius: const Radius.circular(17),
          ),
        waves,
      )
      ..drawPath(
        Path()
          ..moveTo(71, 33)
          ..arcToPoint(
            const Offset(109, 33),
            radius: const Radius.circular(27),
          ),
        waves,
      )
      ..drawCircle(const Offset(90, 51), 3, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_NfcPainter old) =>
      old.accent != accent || old.device != device;
}

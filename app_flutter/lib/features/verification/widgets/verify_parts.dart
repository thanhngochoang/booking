// lib/features/verification/widgets/verify_parts.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

/// Small pieces shared by S21.03 and S21.04 (mock classes `.idill`,
/// `.lockn`, `.warnc`, `.meta`, the bar counter).

Color verifySecondary(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColorsDark.foregroundSecondary
    : AppColors.foregroundSecondary;

Color verifyMuted(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColorsDark.foregroundMuted
    : AppColors.foregroundMuted;

Color verifyAccent(ThemeData theme) => theme.brightness == Brightness.dark
    ? AppColorsDark.accent
    : AppColors.accent;

/// "{n} / {total}" at the end of the app bar (mock `.bar .meta.tn`).
class VerifyCounter extends StatelessWidget {
  const VerifyCounter({super.key, required this.position, required this.total});

  final int position;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: AppSpace.s4),
    child: Center(
      child: ExcludeSemantics(
        child: Text(
          context.l10n.verifyStepCounter(position, total),
          key: const Key('verify-counter'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    ),
  );
}

/// Mock `.idill`: an accent icon on a soft accent circle.
class VerifyIllustration extends StatelessWidget {
  const VerifyIllustration(this.icon, {super.key});

  final IconData icon;

  /// Mock `.idill` 72px.
  static const size = 72.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Center(
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? AppColorsDark.accentSoft : AppColors.accentSoft,
          ),
          child: AppIcon(icon, size: AppText.xxl, color: verifyAccent(theme)),
        ),
      ),
    );
  }
}

/// Centered heading and secondary body under an illustration.
class VerifyHeading extends StatelessWidget {
  const VerifyHeading({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (text != null) ...[
          const SizedBox(height: AppSpace.s1),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: verifySecondary(theme),
            ),
          ),
        ],
      ],
    );
  }
}

/// Mock `.meta`: secondary small text.
class VerifyMeta extends StatelessWidget {
  const VerifyMeta(this.text, {super.key, this.textAlign});

  final String text;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: textAlign,
      style: theme.textTheme.bodySmall?.copyWith(
        color: verifySecondary(theme),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Mock `.lockn`: a small muted icon and note.
class VerifyNote extends StatelessWidget {
  const VerifyNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = verifyMuted(theme);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: AppText.base, color: muted),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// Mock `.warnc` (role alert): a red-outlined card with a message, and an
/// optional bold [title] above it (the message then reads secondary).
class VerifyAlert extends StatelessWidget {
  const VerifyAlert(
    this.text, {
    super.key,
    this.title,
    this.icon = AppIcons.info,
  });

  final String text;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bad = dark ? AppColorsDark.error : AppColors.error;
    final heading = title;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bad.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: bad.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(icon, size: AppText.md, color: bad),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (heading != null) ...[
                      Text(
                        heading,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s1),
                    ],
                    Text(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: heading != null
                            ? verifySecondary(theme)
                            : theme.colorScheme.onSurface,
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

/// Mock `.st` status pill: `ok` (free colours) or `dis` (error).
class VerifyStatusPill extends StatelessWidget {
  const VerifyStatusPill(this.label, {super.key, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bad = dark ? AppColorsDark.error : AppColors.error;
    final (Color bg, Color ink) = ok
        ? (
            dark ? AppColorsDark.freeBg : AppColors.freeBg,
            dark ? AppColorsDark.freeInk : AppColors.freeInk,
          )
        : (bad.withValues(alpha: 0.18), bad);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

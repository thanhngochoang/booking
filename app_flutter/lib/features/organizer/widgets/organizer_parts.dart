// lib/features/organizer/widgets/organizer_parts.dart
//
// Small pieces the S30 screens share (mock classes `.idill`, `.irow`,
// `.lockn`, `.sec`, `.badge`).
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

bool _dark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Mock `.idill`: a round tinted disc with one icon.
class OrgIllustration extends StatelessWidget {
  const OrgIllustration(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AppIcon(
            icon,
            size: 32,
            color: dark ? AppColorsDark.primary : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Mock `.irow`: an icon tile, a title and an optional second line.
class OrgInfoRow extends StatelessWidget {
  const OrgInfoRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, color: context.mutedForeground),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                if (subtitle case final s?)
                  Text(
                    s,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.mutedForeground,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpace.s2),
            const AppIcon(AppIcons.chevron),
          ],
        ],
      ),
    );
    return onTap == null
        ? row
        : InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: row,
          );
  }
}

enum OrgBandTone { info, warning, error }

/// Mock `.lockn` / status bands: a tinted note with an icon.
class OrgBand extends StatelessWidget {
  const OrgBand({
    super.key,
    required this.text,
    this.icon = AppIcons.info,
    this.tone = OrgBandTone.info,
  });

  final String text;
  final IconData icon;
  final OrgBandTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = _dark(context);
    final (bg, fg) = switch (tone) {
      OrgBandTone.info =>
        dark
            ? (AppColorsDark.surfaceMuted, AppColorsDark.foregroundSecondary)
            : (AppColors.surfaceMuted, AppColors.foregroundSecondary),
      OrgBandTone.warning =>
        dark
            ? (AppColorsDark.warningSubtle, AppColorsDark.foreground)
            : (AppColors.warningSubtle, AppColors.foreground),
      OrgBandTone.error =>
        dark
            ? (AppColorsDark.errorSubtle, AppColorsDark.foreground)
            : (AppColors.errorSubtle, AppColors.foreground),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mock `.sec`: a section title, optionally with a count or an action.
class OrgSection extends StatelessWidget {
  const OrgSection(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s4, bottom: AppSpace.s2),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Mock `.badge.b-ok` (green) and `.badge.b-pen` (amber).
class OrgBadge extends StatelessWidget {
  const OrgBadge(this.label, {super.key, this.pending = false});

  final String label;
  final bool pending;

  @override
  Widget build(BuildContext context) => pending
      ? StatusBadge.custom(
          label: label,
          color: AppColors.warning,
          onColor: AppColors.foreground,
        )
      : StatusBadge.custom(
          label: label,
          color: AppColors.success,
          onColor: AppColors.foregroundInverse,
        );
}

/// A bottom-sheet title row with a close button (mock sheet header).
class OrgSheetHeader extends StatelessWidget {
  const OrgSheetHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      IconButton(
        tooltip: context.l10n.s30_close,
        icon: const AppIcon(AppIcons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

/// A red text action (mock `.btn.txt` in red): "Gỡ", "Đóng ngày này".
class OrgDangerText extends StatelessWidget {
  const OrgDangerText(this.label, {super.key, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
      minimumSize: const Size.fromHeight(44),
    ),
    onPressed: onPressed,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

/// Shows [text] in a SnackBar, replacing the one on screen.
void orgSay(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

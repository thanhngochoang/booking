// lib/core/widgets/earning_row.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

/// One line of an expanded [EarningRow]: a label on the left and a full
/// amount on the right (mock `.brk`). [strong] marks the bottom line.
@immutable
class EarningBreakdownLine {
  const EarningBreakdownLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;

  /// Already formatted, full (`1.395.000₫`).
  final String value;
  final bool strong;
}

/// One money row of S06.05 (mock `.card`): title and date on the left, the
/// short amount (tabular figures) and a state badge on the right, and an
/// optional note line (the hold reason) under both. The amount is plain
/// foreground colour: accent is for actions, never money.
///
/// With a [breakdown] the row can expand (the caller owns [expanded] and flips
/// it from [onTap]) to show one line per figure; screen readers hear the
/// expanded state and, once open, the lines.
///
/// S22.01 adds two optional controls that stay their own buttons for screen
/// readers: [action] under the meta line (a small outline button) and
/// [footer] under the open breakdown (a text link).
class EarningRow extends StatelessWidget {
  const EarningRow({
    super.key,
    required this.title,
    required this.meta,
    required this.amount,
    required this.amountLabel,
    required this.badge,
    this.note,
    this.noteIcon,
    this.onTap,
    this.breakdown,
    this.expanded = false,
    this.statusLabel,
    this.action,
    this.footer,
  });

  static Widget skeleton({Key? key}) => _EarningRowSkeleton(key: key);

  final String title;
  final String meta;

  /// Already formatted, short (`450K`).
  final String amount;

  /// The full amount, read by screen readers (`450.000₫`).
  final String amountLabel;
  final Widget badge;
  final String? note;
  final IconData? noteIcon;
  final VoidCallback? onTap;

  /// The lines shown when [expanded]; null makes the row a plain row.
  final List<EarningBreakdownLine>? breakdown;
  final bool expanded;

  /// The badge's text, read with the row (the badge itself is decorative).
  final String? statusLabel;

  /// Shown under [meta] (S22.01 "Chọn tài khoản nhận hoàn").
  final Widget? action;

  /// Shown under the open [breakdown] (S22.01 "Xem buổi chụp").
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final radius = BorderRadius.circular(AppRadius.md);
    final n = note;
    final lines = breakdown;
    final open = lines != null && expanded;
    final act = action;
    final foot = open ? footer : null;
    // Without controls the whole card is one node; with them only the texts
    // are hidden, so the controls stay buttons of their own.
    final controls = action != null || footer != null;
    Widget text(Widget child) =>
        controls ? ExcludeSemantics(child: child) : child;
    return Semantics(
      container: true,
      button: onTap != null,
      expanded: lines == null ? null : expanded,
      onTap: onTap,
      label: [
        title,
        meta,
        amountLabel,
        ?statusLabel,
        ?n,
        if (open)
          for (final l in lines) '${l.label}, ${l.value}',
      ].join(', '),
      child: ExcludeSemantics(
        excluding: !controls,
        child: Material(
          color: dark ? AppColorsDark.glass : AppColors.glass,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(borderRadius: radius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              text(
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: AppText.base2,
                                    fontWeight: FontWeight.w700,
                                    color: fg,
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpace.s1),
                              text(
                                Text(
                                  meta,
                                  style: TextStyle(
                                    fontSize: AppText.xs2,
                                    color: fgSec,
                                  ),
                                ),
                              ),
                              if (act != null) ...[
                                const SizedBox(height: AppSpace.s2),
                                act,
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpace.s3),
                        text(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                amount,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: fg,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpace.s1),
                              badge,
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (n != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      text(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (noteIcon != null) ...[
                              AppIcon(noteIcon!, size: 16, color: fgSec),
                              const SizedBox(width: AppSpace.s1),
                            ],
                            Expanded(
                              child: Text(
                                n,
                                style: TextStyle(
                                  fontSize: AppText.xs2,
                                  color: fgSec,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (lines != null)
                      text(
                        AnimatedSize(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          alignment: Alignment.topCenter,
                          child: open
                              ? _Breakdown(lines: lines, fg: fg, fgSec: fgSec)
                              : const SizedBox(width: double.infinity),
                        ),
                      ),
                    ?foot,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.lines,
    required this.fg,
    required this.fgSec,
  });

  final List<EarningBreakdownLine> lines;
  final Color fg;
  final Color fgSec;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpace.s2),
      padding: const EdgeInsets.only(top: AppSpace.s2),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l.label,
                      style: TextStyle(
                        fontSize: AppText.xs2,
                        fontWeight: l.strong
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: l.strong ? fg : fgSec,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Text(
                    l.value,
                    style: TextStyle(
                      fontSize: AppText.xs2,
                      fontWeight: l.strong ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EarningRowSkeleton extends StatelessWidget {
  const _EarningRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton.line(widthFactor: 0.7),
                    const SizedBox(height: AppSpace.s1),
                    AppSkeleton.line(widthFactor: 0.3),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppSkeleton.box(width: 40, height: 14),
                  const SizedBox(height: AppSpace.s1),
                  AppSkeleton.box(width: 64, height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

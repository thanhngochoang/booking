// lib/core/widgets/escrow_notice.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

/// Escrow notice container (spec .esc): shows a lock icon and safety copy
/// explaining that the payment is held in escrow.
class EscrowNotice extends StatelessWidget {
  const EscrowNotice({
    super.key,
    required this.text,
    this.maxLines = 2,
    this.icon = AppIcons.lock,
    this.title,
    this.trailing,
    this.onTap,
  });

  final String text;

  /// A bold first line above [text] (S05.02's dispute banner).
  final String? title;

  /// A widget at the end of the row, e.g. the "Xem khiếu nại" link.
  final Widget? trailing;

  /// Makes the whole notice tappable (ink on the notice's own background).
  final VoidCallback? onTap;

  /// The leading icon: the lock of held money, or e.g. the clock of S18.01's
  /// dispute window.
  final IconData icon;

  /// Null lets a long notice wrap in full (S13.01's three-clause note).
  final int? maxLines;

  static Widget skeleton() => const _EscrowNoticeSkeleton();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final iconColor = dark
        ? AppColorsDark.foregroundMuted
        : AppColors.foregroundMuted;
    final textColor = dark ? AppColorsDark.foreground : AppColors.foreground;

    final radius = BorderRadius.circular(AppRadius.md);
    final body = Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(fontSize: AppText.chip, height: 1.35, color: textColor),
    );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: AppIcon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: title == null
                  ? body
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: AppText.chip,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: textColor,
                          ),
                        ),
                        if (text.isNotEmpty) body,
                      ],
                    ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      child: onTap == null
          ? DecoratedBox(
              decoration: BoxDecoration(color: bg, borderRadius: radius),
              child: content,
            )
          : Material(
              color: bg,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

class _EscrowNoticeSkeleton extends StatelessWidget {
  const _EscrowNoticeSkeleton()
    : super(key: const ValueKey('escrow_notice_skeleton'));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1.0),
                child: AppSkeleton.box(
                  width: 16,
                  height: 16,
                  radius: AppRadius.full,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton.line(height: 11.5),
                    const SizedBox(height: 5),
                    FractionallySizedBox(
                      widthFactor: 0.7,
                      child: AppSkeleton.line(height: 11.5),
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

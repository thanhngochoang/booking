// lib/core/widgets/escrow_notice.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';

/// Escrow notice container (spec .esc): shows a lock icon and safety copy
/// explaining escrow deposit protection.
class EscrowNotice extends StatelessWidget {
  const EscrowNotice({super.key, required this.text});

  final String text;

  static Widget skeleton() => const _EscrowNoticeSkeleton();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final iconColor = dark ? AppColorsDark.primary : AppColors.primary;
    final textColor = dark ? AppColorsDark.foreground : AppColors.foreground;

    return Semantics(
      container: true,
      child: DecoratedBox(
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
                  child: Icon(Icons.lock_outline, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppText.chip,
                      height: 1.35,
                      color: textColor,
                    ),
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
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1.0),
                child: AppSkeleton.box(
                  width: 16,
                  height: 16,
                  radius: AppRadius.full,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton.line(height: 11.5),
                    SizedBox(height: 5),
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

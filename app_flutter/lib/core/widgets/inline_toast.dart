import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// Inline result line with a green check (mock `.toast`): S05.02 after the
/// payment, S18.02 once a dispute has an outcome.
class InlineToast extends StatelessWidget {
  const InlineToast(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final success = dark ? AppColorsDark.success : AppColors.success;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.surface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: dark ? AppColorsDark.border : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s3,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: success,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: AppIcon(
                    AppIcons.check,
                    size: 12,
                    color: AppColors.foregroundInverse,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

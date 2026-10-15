import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.note,
    this.actionLabel,
    this.onAction,
    this.illustration,
  });
  final String title;

  /// The line under the title; null leaves it out (no empty line).
  final String? body;

  /// A small caption under the body (e.g. "Staff duyệt trong 24 giờ…").
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
            const SizedBox(height: AppSpace.s4),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            if (body case final body?) ...[
              const SizedBox(height: AppSpace.s2),
              Text(body, style: t.bodySmall, textAlign: TextAlign.center),
            ],
            if (note case final note?) ...[
              const SizedBox(height: AppSpace.s2),
              Text(
                note,
                style: t.bodySmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColorsDark.foregroundSecondary
                      : AppColors.foregroundSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpace.s4),
              AppButton.primary(actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

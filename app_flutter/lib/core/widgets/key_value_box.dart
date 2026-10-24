import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Bordered box of label/value rows (mock `.kv`): S04.04's transfer details,
/// S18.02's held money and outcome.
class KeyValueBox extends StatelessWidget {
  const KeyValueBox({super.key, required this.rows});

  final List<KeyValueRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One row of a [KeyValueBox]: a muted label, a bold value with an optional
/// note under it, and an optional trailing widget (e.g. a copy chip).
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.trailing,
  });

  final String label;
  final String value;
  final String? note;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 78,
              child: Text(
                label,
                style: TextStyle(fontSize: AppText.xs2, color: muted),
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: AppText.sm + 0.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (note != null)
                    Text(
                      note!,
                      style: TextStyle(fontSize: AppText.xs2, color: muted),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.s2),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

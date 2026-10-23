// lib/core/widgets/fit_pill.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// A rounded pill showing recommendation fit (e.g. "Hợp 92%").
///
/// Semantics announces the same text as visible ("Hợp {n}%").
class FitPill extends StatelessWidget {
  const FitPill({super.key, required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final text = context.l10n.fitPill(percent);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final fg = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
              height: 1.2,
            ),
          ),
        ),
      ),
      ),
    );
  }
}

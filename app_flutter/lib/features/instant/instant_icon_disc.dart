// Mock `.empty .idill`: the 96dp disc with one icon above a Chụp ngay empty
// or closed view's title (S13.02 empty, S13.07, S13.08 done).
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

class InstantIconDisc extends StatelessWidget {
  const InstantIconDisc(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ExcludeSemantics(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: AppIcon(
            icon,
            size: 40,
            color: dark
                ? AppColorsDark.foregroundSecondary
                : AppColors.foregroundSecondary,
          ),
        ),
      ),
    );
  }
}

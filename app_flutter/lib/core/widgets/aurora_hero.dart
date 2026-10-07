import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Two-line display headline, the second line in the violet accent.
class AuroraHero extends StatelessWidget {
  const AuroraHero({
    super.key,
    required this.lead,
    required this.accent,
    required this.tagline,
  });

  final String lead;
  final String accent;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final headline = TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 36,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.5,
      color: theme.colorScheme.onSurface,
    );
    // The one violet accent of the screen: second headline line.
    final accentColor = dark ? AppColorsDark.accent : AppColors.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lead, style: headline),
        // Vietnamese stacks tone marks above and dots below the letters, so
        // the line gets vertical room.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Text(accent, style: headline.copyWith(color: accentColor)),
        ),
        Text(
          tagline,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Two-line display headline, the second line in the logo's spectrum.
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
      height: 1.05,
      letterSpacing: -0.5,
      color: theme.colorScheme.onSurface,
    );
    // The bright spectrum only reads on the dark canvas; on light the
    // headline uses the CTA stops (all >= 3:1, fine for 36px text).
    final accentColors = dark
        ? const [
            AppColors.spectrumCyan,
            AppColors.spectrumPink,
            AppColors.spectrumOrange,
            AppColors.spectrumYellow,
          ]
        : const [AppColors.ctaStart, AppColors.ctaMid, AppColors.ctaEnd];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lead, style: headline),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              LinearGradient(colors: accentColors).createShader(bounds),
          child: Text(accent, style: headline),
        ),
        const SizedBox(height: AppSpace.s2),
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

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// 70% white: 9.7:1 on the aperture canvas.
const onHeroSecondary = Color(0xB3FFFFFF);

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
    const headline = TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 36,
      fontWeight: FontWeight.w600,
      height: 1.05,
      letterSpacing: -0.5,
      color: Colors.white,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lead, style: headline),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppColors.spectrumCyan,
              AppColors.spectrumPink,
              AppColors.spectrumOrange,
              AppColors.spectrumYellow,
            ],
          ).createShader(bounds),
          child: Text(accent, style: headline),
        ),
        const SizedBox(height: AppSpace.s2),
        Text(
          tagline,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: onHeroSecondary),
        ),
      ],
    );
  }
}

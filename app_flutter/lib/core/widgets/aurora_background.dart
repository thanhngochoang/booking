import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Soft glows in the logo's colours behind the hero.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.child});

  /// Content painted above the glows.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Pastel on the light canvas, so text over it keeps its contrast.
    final strength = theme.brightness == Brightness.dark ? 1.0 : 0.5;
    Widget glow(Color c, double size, double alpha) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            c.withValues(alpha: alpha * strength),
            c.withValues(alpha: 0),
          ],
        ),
      ),
    );
    final glows = IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -w * 0.45,
                top: -w * 0.35,
                child: glow(AppColors.spectrumCyan, w * 1.1, 0.45),
              ),
              Positioned(
                right: -w * 0.5,
                top: -w * 0.1,
                child: glow(AppColors.spectrumPink, w * 1.2, 0.4),
              ),
              Positioned(
                left: -w * 0.1,
                top: w * 0.45,
                child: glow(AppColors.spectrumViolet, w, 0.35),
              ),
            ],
          );
        },
      ),
    );
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Stack(fit: StackFit.expand, children: [glows, ?child]),
    );
  }
}

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Frosted panel with a hairline in the logo's spectrum.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.highlight = true});

  final Widget child;

  /// Spectrum hairline; without it the edge is the theme's plain hairline.
  final bool highlight;

  static const _radius = BorderRadius.all(Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: Color(dark ? 0x59000000 : 0x1A000000),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: CustomPaint(
            foregroundPainter: SpectrumBorder(
              _radius,
              highlight: highlight,
              plain: theme.colorScheme.outlineVariant,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  // Frosted white either way: faint on dark, milky on light.
                  colors: dark
                      ? const [Color(0x26FFFFFF), Color(0x0DFFFFFF)]
                      : const [Color(0xD9FFFFFF), Color(0xA6FFFFFF)],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class SpectrumBorder extends CustomPainter {
  const SpectrumBorder(
    this.radius, {
    this.highlight = true,
    this.plain = AppColorsDark.border,
  });

  final BorderRadius radius;
  final bool highlight;

  /// Edge colour when [highlight] is off.
  final Color plain;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: highlight
            ? [
                AppColors.spectrumCyan.withValues(alpha: 0.7),
                Colors.white.withValues(alpha: 0.12),
                AppColors.spectrumPink.withValues(alpha: 0.7),
              ]
            : [plain, plain],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect.deflate(0.6)), paint);
  }

  @override
  bool shouldRepaint(SpectrumBorder old) =>
      old.radius != radius || old.highlight != highlight || old.plain != plain;
}

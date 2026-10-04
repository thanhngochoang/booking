import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/signature_loader.dart'
    show LoaderSize;

const _cycle = Duration(milliseconds: 2000);
const _turnShare = 0.75;
const _dots = 12;

/// Turns of the ring (0 … 1) at [t] ∈ [0, 1] of one 2 s cycle: one eased turn
/// over the first 75 % (1.5 s), then it rests until the cycle ends.
double dotRingTurnAt(double t) =>
    t >= _turnShare ? 1 : Curves.easeInOutCubic.transform(t / _turnShare);

/// Ring diameter and dot diameter per [LoaderSize] (spec "DotRingLoader").
(double, double) dotRingMetrics(LoaderSize size) => switch (size) {
  LoaderSize.screen => (96, 11),
  LoaderSize.block => (64, 8),
  LoaderSize.inline => (24, 4),
};

/// Twelve dots on a circle: dot k sits k·30° behind the head, scaled by
/// 1 − 0.06k and faded by 1 − 0.075k, so the ring reads as a head and a tail.
class DotRingPainter extends CustomPainter {
  const DotRingPainter({
    required this.turn,
    required this.color,
    required this.dotSize,
  });

  final double turn;
  final Color color;
  final double dotSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - dotSize / 2;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var k = 0; k < _dots; k++) {
      final angle = -math.pi / 2 + 2 * math.pi * turn - k * math.pi / 6;
      paint.color = color.withValues(alpha: color.a * (1 - k * 0.075));
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        dotSize / 2 * (1 - k * 0.06),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DotRingPainter old) =>
      old.turn != turn || old.color != color || old.dotSize != dotSize;
}

/// Loader of [AsyncView] (no skeleton) and of `AppButton.loading`: a ring of
/// dots that turns once, rests, and turns again. Transparent background.
///
/// [dimension] and [dotSize] override the [size] metrics (AppButton sizes the
/// ring to the button height).
class DotRingLoader extends StatefulWidget {
  const DotRingLoader({
    super.key,
    this.size = LoaderSize.screen,
    this.dimension,
    this.dotSize,
    this.color,
    this.active = true,
    this.semanticsLabel,
  });

  final LoaderSize size;
  final double? dimension;
  final double? dotSize;
  final Color? color;
  final bool active;
  final String? semanticsLabel;

  @override
  State<DotRingLoader> createState() => _DotRingLoaderState();
}

class _DotRingLoaderState extends State<DotRingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _cycle,
  );

  void _sync() {
    final run =
        widget.active &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DotRingLoader old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (ringSize, defaultDot) = dotRingMetrics(widget.size);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color =
        widget.color ?? (dark ? AppColorsDark.primary : AppColors.primary);
    final dotSize = widget.dotSize ?? defaultDot;

    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.dimension ?? ringSize,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: DotRingPainter(
                turn: _c.isAnimating ? dotRingTurnAt(_c.value) : 0,
                color: color,
                dotSize: dotSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

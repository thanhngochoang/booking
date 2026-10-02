import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

const _cycle = Duration(milliseconds: 2400);

/// Closure (0 open … 1 closed) at [t] ∈ [0, 1] of one 2.4 s cycle:
/// close over 0–45 %, hold to 55 %, open again by 100 %.
double apertureClosureAt(double t) {
  const ease = Curves.easeInOutCubic;
  if (t <= 0.45) {
    return ease.transform(t / 0.45);
  }
  if (t <= 0.55) {
    return 1;
  }
  return ease.transform((1 - t) / 0.45);
}

/// Logical sizes for [SignatureLoader] per spec:
/// screen (150), block (96), inline (56).
enum LoaderSize {
  screen(150),
  block(96),
  inline(56);

  const LoaderSize(this.dimension);
  final double dimension;
}

enum LoaderWave { ripple, vibration }

/// Closed wavy path for vibration waves: r(θ) = R + a·sin(nθ) rotated by [angle].
Path wavyPath(Offset center, double radius, int n, double a, double angle) {
  final path = Path();
  const steps = 120;
  for (var i = 0; i <= steps; i++) {
    final theta = i * 2 * math.pi / steps;
    final r = radius + a * math.sin(n * theta);
    final phi = theta + angle;
    final x = center.dx + r * math.cos(phi);
    final y = center.dy + r * math.sin(phi);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}

/// Paints the outer waves (ripple or vibration) of [SignatureLoader].
class SignatureWavesPainter extends CustomPainter {
  const SignatureWavesPainter({
    required this.t,
    required this.wave,
    required this.size,
    required this.waveColor,
    this.reduced = false,
  });

  final double t;
  final LoaderWave wave;
  final LoaderSize size;
  final Color waveColor;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (size == LoaderSize.inline) return;

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = canvasSize.width / 2;

    if (reduced) {
      // Reduced motion: one faint still ring, no waves
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = waveColor.withValues(alpha: 0.45);
      canvas.drawCircle(center, radius * 0.72, paint);
      return;
    }

    if (wave == LoaderWave.ripple) {
      // ripple: 3 concentric rings expanding from 38% to 100% of radius,
      // phase-shifted by 1/3 (0.8s), color primary fading out.
      for (var i = 0; i < 3; i++) {
        final p = (t + i / 3.0) % 1.0;
        final r =
            lerpDouble(0.38, 1.0, Curves.easeOutCubic.transform(p))! * radius;
        final alpha = (0.9 * (1.0 - p)).clamp(0.0, 1.0);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = waveColor.withValues(alpha: alpha);
        canvas.drawCircle(center, r, paint);
      }
    } else {
      // vibration: 2 sine rings r(θ) = R + a·sin(nθ), growing and rocking ±4–6°,
      // cyan focus and pink #FF45D0, shifted by 1.2s (phase 0.17 and 0.67).
      const waves = [
        (
          n: 12,
          a: 0.024,
          phase: 0.17,
          swing: 5.0,
          color: AppColors.spectrumCyan,
        ),
        (n: 9, a: 0.032, phase: 0.67, swing: 6.0, color: Color(0xFFFF45D0)),
      ];
      for (final w in waves) {
        final p = (t + w.phase) % 1.0;
        final scale = lerpDouble(0.4, 1.04, p)!;
        final angle = math.sin(p * math.pi * 5) * w.swing * math.pi / 180;
        final alpha = (0.95 * (1.0 - p)).clamp(0.0, 1.0);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = w.color.withValues(alpha: alpha);
        canvas.drawPath(
          wavyPath(center, radius * scale, w.n, w.a * radius, angle),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(SignatureWavesPainter old) =>
      old.t != t ||
      old.wave != wave ||
      old.size != size ||
      old.waveColor != waveColor ||
      old.reduced != reduced;
}

/// The monochrome aperture of `design-system/brand/logo-mono.svg`, drawn in
/// one painter. [closure] turns each blade about its rim end by up to −18°.
class ApertureMark extends StatelessWidget {
  const ApertureMark({super.key, this.size = 34, this.closure = 0, this.color});

  final double size;
  final double closure;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: AperturePainter(
        closure: closure,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class AperturePainter extends CustomPainter {
  const AperturePainter({required this.closure, required this.color});
  final double closure;
  final Color color;

  static double _rad(double deg) => deg * math.pi / 180;
  static Offset _dir(double rad) => Offset(math.cos(rad), math.sin(rad));
  static Offset _about(Offset q, Offset pivot, double a) {
    final d = q - pivot;
    return pivot +
        Offset(
          d.dx * math.cos(a) - d.dy * math.sin(a),
          d.dx * math.sin(a) + d.dy * math.cos(a),
        );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    const c = Offset(50, 50);
    canvas.drawCircle(c, 42, stroke);
    final turn = _rad(-18 * closure.clamp(0.0, 1.0));
    final blades = Path();
    for (var k = 0; k < 8; k++) {
      final t = _rad(k * 45.0 - 90);
      final end = c + _dir(t + _rad(118)) * 42;
      final start = _about(c + _dir(t) * 10, end, turn);
      final control = _about(c + _dir(t + _rad(32)) * 33, end, turn);
      blades
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    }
    canvas.drawPath(blades, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AperturePainter old) =>
      old.closure != closure || old.color != color;
}

/// Signature loading widget: aperture blades at center with one wave type
/// (ripple concentric rings or vibration sine waves) around it.
///
/// Transparent background: no filled disc, gradient, or shadow.
class SignatureLoader extends StatefulWidget {
  const SignatureLoader({
    super.key,
    this.size = LoaderSize.screen,
    this.wave = LoaderWave.ripple,
    this.active = true,
    this.semanticsLabel,
    this.color,
  });

  final LoaderSize size;
  final LoaderWave wave;
  final bool active;
  final String? semanticsLabel;
  final Color? color;

  @override
  State<SignatureLoader> createState() => _SignatureLoaderState();
}

class _SignatureLoaderState extends State<SignatureLoader>
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
  void didUpdateWidget(SignatureLoader old) {
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
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    final waveColor =
        widget.color ??
        (widget.wave == LoaderWave.vibration
            ? AppColors.spectrumCyan
            : primary);
    final bladeColor = waveColor;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final dimension = widget.size.dimension;
    final apertureSize = switch (widget.size) {
      LoaderSize.screen => 57.0,
      LoaderSize.block => 36.5,
      LoaderSize.inline => 34.0,
    };

    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: dimension,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.isAnimating ? _c.value : 0.0;
              final closure = _c.isAnimating
                  ? apertureClosureAt(_c.value)
                  : 0.0;
              return CustomPaint(
                painter: SignatureWavesPainter(
                  t: t,
                  wave: widget.wave,
                  size: widget.size,
                  waveColor: waveColor,
                  reduced: reduced,
                ),
                child: Center(
                  child: ApertureMark(
                    size: apertureSize,
                    closure: closure,
                    color: bladeColor,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

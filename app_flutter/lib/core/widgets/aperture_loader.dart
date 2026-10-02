import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

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

/// The app's screen-level wait (S48 searching, S47 opening payment, S54
/// resuming…). Runs only while [active] and visible; reduced motion shows
/// the open mark, still.
class ApertureLoader extends StatefulWidget {
  const ApertureLoader({
    super.key,
    this.size = 66,
    this.active = true,
    this.semanticsLabel,
  });

  final double size;
  final bool active;
  final String? semanticsLabel;

  @override
  State<ApertureLoader> createState() => _ApertureLoaderState();
}

class _ApertureLoaderState extends State<ApertureLoader>
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
  void didUpdateWidget(ApertureLoader old) {
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(widget.size / 2);
    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Same glow as the primary button (_GradientFill in app_button.dart).
            boxShadow: [
              BoxShadow(
                color: dark
                    ? AppColors.ctaMid.withValues(alpha: 0.35)
                    : AppColors.ctaLightStart.withValues(alpha: 0.25),
                blurRadius: dark ? 18 : 12,
                offset: Offset(0, dark ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox.square(
              dimension: widget.size,
              child: CtaSurface(
                borderRadius: radius,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => ApertureMark(
                      size: widget.size * 34 / 66,
                      closure: _c.isAnimating ? apertureClosureAt(_c.value) : 0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

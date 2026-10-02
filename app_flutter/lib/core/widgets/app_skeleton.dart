import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Single controller for skeleton sweeps under this scope.
class AppSkeletonScope extends StatefulWidget {
  const AppSkeletonScope({super.key, required this.child});

  final Widget child;

  @override
  State<AppSkeletonScope> createState() => _AppSkeletonScopeState();
}

class _AppSkeletonScopeState extends State<AppSkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  void _sync() {
    final run =
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
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScopeData(
      animation: _c,
      child: widget.child,
    );
  }
}

class _SkeletonScopeData extends InheritedWidget {
  const _SkeletonScopeData({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_SkeletonScopeData old) => animation != old.animation;
}

/// Placeholder blocks shown while content loads.
///
/// White only, no aurora hues (r == g == b):
/// - Dark: base white 8%, shine white 14%.
/// - Light: base light grey #E2E2E2 (r=g=b=226), shine white 85%.
/// 1.6s diagonal sweep moving across.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton._({
    super.key,
    this.width,
    required this.height,
    required this.radius,
  });

  final double? width;
  final double height;
  final double radius;

  static (Color base, Color shine) colorsFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return (
      dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E2E2),
      dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.85),
    );
  }

  static Widget box({
    Key? key,
    double? width,
    required double height,
    double radius = AppRadius.sm,
  }) => AppSkeleton._(
    key: key,
    width: width,
    height: height,
    radius: radius,
  );

  static Widget line({
    Key? key,
    double widthFactor = 1.0,
    double? width,
    double height = 12.0,
  }) {
    if (width != null) {
      return AppSkeleton._(
        key: key,
        width: width,
        height: height,
        radius: AppRadius.sm,
      );
    }
    return FractionallySizedBox(
      key: key,
      widthFactor: widthFactor,
      child: AppSkeleton._(
        height: height,
        radius: AppRadius.sm,
      ),
    );
  }

  static Widget circle({Key? key, required double size}) => AppSkeleton._(
    key: key,
    width: size,
    height: size,
    radius: size / 2,
  );

  static Widget card({Key? key, double height = 120.0}) => AppSkeleton._(
    key: key,
    height: height,
    radius: AppRadius.card,
  );

  /// Groups skeleton blocks under one "Đang tải" live region.
  static Widget group({required Widget child}) => Semantics(
    liveRegion: true,
    label: 'Đang tải',
    child: child,
  );

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;

  void _syncMotion(AnimationController c, BuildContext context) {
    final run =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (!run && c.isAnimating) {
      c
        ..stop()
        ..value = 0;
    } else if (run && !c.isAnimating) {
      c.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scoped = context.dependOnInheritedWidgetOfExactType<_SkeletonScopeData>();
    if (scoped != null) {
      _own?.dispose();
      _own = null;
      return;
    }
    final c = _own ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _syncMotion(c, context);
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoped = context.dependOnInheritedWidgetOfExactType<_SkeletonScopeData>();
    final anim = scoped?.animation ?? _own;
    final (baseColor, shineColor) = AppSkeleton.colorsFor(Theme.of(context).brightness);
    final reduced = MediaQuery.disableAnimationsOf(context);

    Widget buildBox(double t) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: CustomPaint(
            painter: _SkeletonPainter(
              baseColor: baseColor,
              shineColor: shineColor,
              radius: widget.radius,
              t: t,
              reduced: reduced,
            ),
          ),
        ),
      );
    }

    final child = anim != null && !reduced
        ? AnimatedBuilder(
            animation: anim,
            builder: (_, _) => buildBox(anim.value),
          )
        : buildBox(0.0);

    return ExcludeSemantics(child: child);
  }
}

class _SkeletonPainter extends CustomPainter {
  const _SkeletonPainter({
    required this.baseColor,
    required this.shineColor,
    required this.radius,
    required this.t,
    required this.reduced,
  });

  final Color baseColor;
  final Color shineColor;
  final double radius;
  final double t;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = baseColor);

    if (reduced) return;

    final dx = lerpDouble(-2.0, 2.0, t)!;
    final gradient = LinearGradient(
      begin: Alignment(dx - 0.7, -0.3),
      end: Alignment(dx + 0.7, 0.3),
      stops: const [0.35, 0.50, 0.65],
      colors: [
        Colors.transparent,
        shineColor,
        Colors.transparent,
      ],
    );

    final shinePaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, shinePaint);
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.t != t ||
      old.baseColor != baseColor ||
      old.shineColor != shineColor ||
      old.reduced != reduced ||
      old.radius != radius;
}

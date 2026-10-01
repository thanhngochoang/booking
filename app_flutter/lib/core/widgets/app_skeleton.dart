import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

// Card skeletons are rounder than boxes (matches the 20dp card corner); kept
// local instead of adding a token.
const double _cardRadius = AppRadius.lg + 8;

const Duration _pulseDuration = Duration(milliseconds: 900);

/// Drives the 0.55..1 pulse. Static (value 1) under reduced motion.
void _syncMotion(AnimationController c, BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) {
    c.stop();
    c.value = 1;
  } else if (!c.isAnimating) {
    c.repeat(reverse: true);
  }
}

/// Animation for a [AppSkeletonScope]; bones inside listen to it.
class _SkeletonPulse extends InheritedWidget {
  const _SkeletonPulse({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_SkeletonPulse old) => animation != old.animation;
}

/// Owns ONE pulse for every [AppSkeleton] below it, so a loading view runs a
/// single ticker however many placeholder blocks it shows. The ticker follows
/// [TickerMode], so a hidden route pauses.
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
    duration: _pulseDuration,
  );
  late final Animation<double> _opacity = _c.drive(
    Tween<double>(begin: 0.55, end: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion(_c, context);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonPulse(animation: _opacity, child: widget.child);
}

/// Placeholder blocks shown while content loads. They have the shape of the
/// content they stand in for, pulse gently and stop under reduced motion.
/// Wrap a group in [AppSkeletonScope] so they share one pulse; a bare block
/// pulses on its own.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton.box({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.lg,
  });

  const AppSkeleton.line({super.key, this.width, this.height = 12})
    : radius = AppRadius.md;

  const AppSkeleton.card({super.key, this.height = 120})
    : width = null,
      radius = _cardRadius;

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;
  Animation<double>? _ownOpacity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scoped = context.dependOnInheritedWidgetOfExactType<_SkeletonPulse>();
    if (scoped != null) {
      _own?.dispose();
      _own = null;
      _ownOpacity = null;
      return;
    }
    final c = _own ??= AnimationController(
      vsync: this,
      duration: _pulseDuration,
    );
    _ownOpacity ??= c.drive(Tween<double>(begin: 0.55, end: 1));
    _syncMotion(c, context);
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoped = context.getInheritedWidgetOfExactType<_SkeletonPulse>();
    final opacity = scoped?.animation ?? _ownOpacity!;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: opacity,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        ),
      ),
    );
  }
}

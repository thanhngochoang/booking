import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Placeholder blocks shown while content loads. They have the shape of the
/// content they stand in for, pulse gently and stop under reduced motion.
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
      radius = AppRadius.lg + 8;

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.secondary;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Opacity(
          opacity: 0.55 + 0.45 * _c.value,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(widget.radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

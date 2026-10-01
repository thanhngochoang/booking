import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

enum _Kind { primary, outline, text }

/// The blue → violet → magenta of the logo; white text passes AA on every stop.
const ctaGradient = LinearGradient(
  colors: [AppColors.ctaStart, AppColors.ctaMid, AppColors.ctaEnd],
);

class AppButton extends StatelessWidget {
  /// The screen's main action, filled with [ctaGradient]. Use once per screen.
  const AppButton.primary(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
  }) : _kind = _Kind.primary;

  const AppButton.outline(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
  }) : _kind = _Kind.outline;
  const AppButton.text(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
  }) : _kind = _Kind.text;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Trailing on primary (e.g. an arrow), leading otherwise.
  final Widget? icon;

  /// Overrides on top of the theme, e.g. a provider's brand colours.
  final ButtonStyle? style;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final onGradient = _kind == _Kind.primary;
    final Widget child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: onGradient
                  ? Colors.white
                  : style?.foregroundColor?.resolve(const {}),
            ),
          )
        : icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!onGradient) ...[icon!, const SizedBox(width: AppSpace.s2)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (onGradient) ...[const SizedBox(width: AppSpace.s2), icon!],
            ],
          );
    final cb = loading ? null : onPressed;
    return switch (_kind) {
      _Kind.primary => _GradientFill(
        dimmed: cb == null && !loading,
        child: FilledButton(
          onPressed: cb,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shadowColor: Colors.transparent,
          ).merge(style),
          child: child,
        ),
      ),
      _Kind.outline => OutlinedButton(
        onPressed: cb,
        style: style,
        child: child,
      ),
      _Kind.text => TextButton(onPressed: cb, style: style, child: child),
    };
  }
}

class _GradientFill extends StatelessWidget {
  const _GradientFill({required this.child, required this.dimmed});

  final Widget child;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final shape = Theme.of(context).filledButtonTheme.style?.shape
        ?.resolve(const {});
    final radius = shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(Directionality.of(context))
        : BorderRadius.circular(AppRadius.md);
    return AnimatedOpacity(
      opacity: dimmed ? 0.5 : 1,
      duration: const Duration(milliseconds: 150),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: ctaGradient,
          borderRadius: radius,
          boxShadow: dimmed
              ? null
              : [
                  BoxShadow(
                    color: AppColors.ctaMid.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: child,
      ),
    );
  }
}

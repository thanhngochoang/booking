import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

enum _Kind { primary, outline, text }

class AppButton extends StatelessWidget {
  /// The screen's main action, filled by [CtaSurface] (theme gradient, or the
  /// blurred avatar when the viewer chose that). Use once per screen.
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
        ? Stack(
            alignment: Alignment.center,
            children: [
              // Keeps the width and the accessible name while the spinner shows.
              Opacity(
                opacity: 0,
                alwaysIncludeSemantics: true,
                child: Text(label),
              ),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: onGradient
                      ? Colors.white
                      : style?.foregroundColor?.resolve(const {}),
                ),
              ),
            ],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedOpacity(
      opacity: dimmed ? 0.5 : 1,
      duration: const Duration(milliseconds: 150),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: dimmed
              ? null
              : [
                  BoxShadow(
                    color: dark
                        ? AppColors.ctaMid.withValues(alpha: 0.35)
                        : AppColors.ctaLightStart.withValues(alpha: 0.25),
                    blurRadius: dark ? 18 : 12,
                    offset: Offset(0, dark ? 8 : 4),
                  ),
                ],
        ),
        child: CtaSurface(borderRadius: radius, child: child),
      ),
    );
  }
}

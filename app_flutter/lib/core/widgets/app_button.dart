import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

enum _Kind { primary, outline, text }

/// Mock `.btn` (48, here [controlHeight]), `.btn.sm` (38) and `.btn.xs`
/// (30, intrinsic width). The hit area stays at least 48dp at every size.
enum AppButtonSize { regular, small, xsmall }

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
    this.size = AppButtonSize.regular,
  }) : _kind = _Kind.primary;

  const AppButton.outline(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
    this.size = AppButtonSize.regular,
  }) : _kind = _Kind.outline;
  const AppButton.text(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
    this.size = AppButtonSize.regular,
  }) : _kind = _Kind.text;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Trailing on primary (e.g. an arrow), leading otherwise.
  final Widget? icon;

  /// Overrides on top of the theme, e.g. a provider's brand colours.
  final ButtonStyle? style;
  final AppButtonSize size;
  final _Kind _kind;

  ButtonStyle? get _sizeStyle => switch (size) {
    AppButtonSize.regular => null,
    AppButtonSize.small => _compact(38, wide: true),
    AppButtonSize.xsmall => _compact(30, wide: false),
  };

  static ButtonStyle _compact(double height, {required bool wide}) =>
      ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          wide ? Size.fromHeight(height) : Size(0, height),
        ),
        maximumSize: WidgetStatePropertyAll(Size.fromHeight(height)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpace.s3),
        ),
        // Mock 12 / 11 -> AppText.sm (no 11 token).
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: AppText.sm, fontWeight: FontWeight.w600),
        ),
        // Mock 14 / 12 -> AppRadius.lg (no 14 token).
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  @override
  Widget build(BuildContext context) {
    final button = _buildButton(context);
    if (size == AppButtonSize.regular) return button;
    // Visual height follows the size; the outer box restores the 48dp target
    // (outside the gradient, which a padded Material target would stretch).
    final cb = loading ? null : onPressed;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: cb,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpace.s12,
          minWidth: AppSpace.s12,
        ),
        child: Align(
          widthFactor: size == AppButtonSize.xsmall ? 1 : null,
          heightFactor: 1,
          child: button,
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context) {
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
          ).merge(_sizeStyle).merge(style),
          child: child,
        ),
      ),
      _Kind.outline => OutlinedButton(
        onPressed: cb,
        style: _sizeStyle?.merge(style) ?? style,
        child: child,
      ),
      _Kind.text => TextButton(
        onPressed: cb,
        style: _sizeStyle?.merge(style) ?? style,
        child: child,
      ),
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

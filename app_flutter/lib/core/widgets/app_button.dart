import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';
import 'package:photobooking/core/widgets/signature_loader.dart';

enum _Kind { primary, outline, text, danger }

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
    this.tapAlignment = Alignment.center,
  }) : _kind = _Kind.primary;

  const AppButton.outline(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
    this.size = AppButtonSize.regular,
    this.tapAlignment = Alignment.center,
  }) : _kind = _Kind.outline;
  const AppButton.text(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
    this.size = AppButtonSize.regular,
    this.tapAlignment = Alignment.center,
  }) : _kind = _Kind.text;

  const AppButton.danger(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.style,
    this.size = AppButtonSize.regular,
    this.tapAlignment = Alignment.center,
  }) : _kind = _Kind.danger;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Trailing on primary (e.g. an arrow), leading otherwise.
  final Widget? icon;

  /// Overrides on top of the theme, e.g. a provider's brand colours.
  final ButtonStyle? style;
  final AppButtonSize size;

  /// Where the visual sits inside the 48dp tap box of a small or xsmall
  /// button (e.g. top, so the slack below doubles as the caller's padding).
  final Alignment tapAlignment;
  final _Kind _kind;

  /// Corner radius of a compact size; null for regular (theme shape).
  double? get _sizeRadius => switch (size) {
    AppButtonSize.regular => null,
    AppButtonSize.small => AppRadius.control,
    AppButtonSize.xsmall => AppRadius.lg,
  };

  /// [base] is the kind's theme text style: a button `textStyle` replaces the
  /// theme's instead of merging, so the compact one keeps its family.
  ButtonStyle? _sizeStyle(TextStyle? base) => switch (size) {
    AppButtonSize.regular => null,
    AppButtonSize.small => _compact(38, AppText.sm, base, wide: true),
    AppButtonSize.xsmall => _compact(30, AppText.xs2, base, wide: false),
  };

  ButtonStyle _compact(
    double height,
    double font,
    TextStyle? base, {
    required bool wide,
  }) => ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      wide ? Size.fromHeight(height) : Size(0, height),
    ),
    maximumSize: WidgetStatePropertyAll(Size.fromHeight(height)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpace.s3),
    ),
    textStyle: WidgetStatePropertyAll(
      (base ?? const TextStyle()).copyWith(
        fontSize: font,
        fontWeight: FontWeight.w600,
      ),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sizeRadius!)),
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
          alignment: tapAlignment,
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
              SizedBox.square(
                dimension: switch (size) {
                  AppButtonSize.regular => 24,
                  AppButtonSize.small => 20,
                  AppButtonSize.xsmall => 18,
                },
                child: FittedBox(
                  child: SignatureLoader(
                    size: LoaderSize.inline,
                    color: (onGradient || _kind == _Kind.danger)
                        ? Colors.white
                        : style?.foregroundColor?.resolve(const {}),
                  ),
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
    final theme = Theme.of(context);
    TextStyle? themeText(ButtonStyle? s) => s?.textStyle?.resolve(const {});
    // `a.merge(b)` keeps a's values: caller style first, then size, then base.
    ButtonStyle? layered(TextStyle? base, [ButtonStyle? kindBase]) {
      final layers = [style, _sizeStyle(base), kindBase].nonNulls;
      return layers.isEmpty ? null : layers.reduce((a, b) => a.merge(b));
    }

    final filledText = themeText(theme.filledButtonTheme.style);
    return switch (_kind) {
      _Kind.primary => _GradientFill(
        dimmed: cb == null && !loading,
        radius: _sizeRadius,
        child: FilledButton(
          onPressed: cb,
          style: layered(
            filledText,
            FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shadowColor: Colors.transparent,
            ),
          ),
          child: child,
        ),
      ),
      _Kind.outline => OutlinedButton(
        onPressed: cb,
        style: layered(
          themeText(theme.outlinedButtonTheme.style) ?? filledText,
        ),
        child: child,
      ),
      _Kind.text => TextButton(
        onPressed: cb,
        style: layered(themeText(theme.textButtonTheme.style) ?? filledText),
        child: child,
      ),
      _Kind.danger => FilledButton(
        onPressed: cb,
        style: layered(
          filledText,
          FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            disabledBackgroundColor: AppColors.error.withValues(alpha: 0.4),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
            shadowColor: Colors.transparent,
            shape: _sizeRadius != null
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_sizeRadius!),
                  )
                : null,
          ),
        ),
        child: child,
      ),
    };
  }
}

class _GradientFill extends StatelessWidget {
  const _GradientFill({required this.child, required this.dimmed, this.radius});

  final Widget child;
  final bool dimmed;

  /// The compact size's radius; null uses the theme's filled-button shape.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final shape = Theme.of(context).filledButtonTheme.style?.shape
        ?.resolve(const {});
    final radius = this.radius != null
        ? BorderRadius.circular(this.radius!)
        : shape is RoundedRectangleBorder
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

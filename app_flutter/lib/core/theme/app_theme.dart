import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Controls (buttons, inputs, chips) share the login card's rounder shape.
const controlRadius = AppRadius.xl;
const controlHeight = 48.0;

/// Status bar icons that read on [theme]'s canvas, over a transparent bar.
SystemUiOverlayStyle overlayStyleFor(ThemeData theme) =>
    (theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(statusBarColor: Colors.transparent);

ThemeData buildLightTheme() => _build(
  brightness: Brightness.light,
  primary: AppColors.primary,
  onPrimary: AppColors.primaryForeground,
  background: AppColors.background,
  surface: AppColors.surface,
  surfaceMuted: AppColors.surfaceMuted,
  foreground: AppColors.foreground,
  foregroundSecondary: AppColors.foregroundSecondary,
  foregroundMuted: AppColors.foregroundMuted,
  border: AppColors.border,
  borderStrong: AppColors.borderStrong,
  focusRing: AppColors.focusRing,
  error: AppColors.error,
);

/// The app's look: glass controls on the dark aperture canvas.
ThemeData buildDarkTheme() => _build(
  brightness: Brightness.dark,
  primary: AppColorsDark.primary,
  onPrimary: AppColorsDark.primaryForeground,
  background: AppColorsDark.background,
  surface: AppColorsDark.surface,
  surfaceMuted: AppColorsDark.surfaceMuted,
  foreground: AppColorsDark.foreground,
  foregroundSecondary: AppColorsDark.foregroundSecondary,
  foregroundMuted: AppColorsDark.foregroundMuted,
  border: AppColorsDark.border,
  borderStrong: AppColorsDark.borderStrong,
  focusRing: AppColorsDark.focusRing,
  error: AppColorsDark.error,
);

ThemeData _build({
  required Brightness brightness,
  required Color primary,
  required Color onPrimary,
  required Color background,
  required Color surface,
  required Color surfaceMuted,
  required Color foreground,
  required Color foregroundSecondary,
  required Color foregroundMuted,
  required Color border,
  required Color borderStrong,
  required Color focusRing,
  required Color error,
}) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    secondary: surfaceMuted,
    onSecondary: foreground,
    error: error,
    onError: Colors.white,
    surface: surface,
    onSurface: foreground,
    outline: borderStrong,
    outlineVariant: border,
  );
  TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? c}) =>
      TextStyle(
        fontFamily: AppFonts.body,
        fontSize: size,
        fontWeight: w,
        color: c ?? foreground,
        height: 1.4,
      );
  TextStyle display(double size) => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: foreground,
    height: 1.15,
  );
  final radius = BorderRadius.circular(controlRadius);
  final shape = RoundedRectangleBorder(borderRadius: radius);
  OutlineInputBorder side(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide(color: c, width: w),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: AppFonts.body,
    textTheme: TextTheme(
      displayLarge: display(AppText.xxl),
      headlineMedium: display(AppText.xl),
      titleLarge: display(AppText.lg),
      titleMedium: body(AppText.md, w: FontWeight.w600),
      bodyLarge: body(AppText.md),
      bodyMedium: body(AppText.base),
      bodySmall: body(AppText.sm, c: foregroundSecondary),
      labelLarge: body(AppText.base, w: FontWeight.w600),
      labelSmall: body(AppText.xs, w: FontWeight.w500, c: foregroundSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      systemOverlayStyle:
          (brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(statusBarColor: Colors.transparent),
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(controlHeight),
        shape: shape,
        textStyle: body(AppText.base2, w: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(controlHeight),
        side: BorderSide(color: borderStrong),
        foregroundColor: foreground,
        shape: shape,
        textStyle: body(AppText.base2, w: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: body(AppText.base, w: FontWeight.w600),
      ),
    ),
    // Filled, borderless fields; the focus ring is the only outline.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s4,
      ),
      border: side(Colors.transparent),
      enabledBorder: side(Colors.transparent),
      disabledBorder: side(Colors.transparent),
      focusedBorder: side(focusRing, 2),
      errorBorder: side(error),
      focusedErrorBorder: side(error, 2),
    ),
    cardTheme: CardThemeData(
      color: surfaceMuted,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    navigationBarTheme: NavigationBarThemeData(
      // Material 3 defaults to 80dp; 64 keeps the labels and gives the page
      // 16dp more room.
      height: 64,
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      // Mock `.tab` / `.tab.on`: selected in the accent colour at 600,
      // unselected in the tertiary grey at 500.
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? primary : foregroundMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        return body(
          AppText.tab,
          w: on ? FontWeight.w600 : FontWeight.w500,
          c: on ? primary : foregroundMuted,
        );
      }),
    ),
    dividerColor: border,
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
  );
}

import 'package:flutter/material.dart';
import 'tokens.g.dart';

ThemeData buildLightTheme() => _build(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      background: AppColors.background,
      surface: AppColors.surface,
      surfaceMuted: AppColors.surfaceMuted,
      foreground: AppColors.foreground,
      foregroundSecondary: AppColors.foregroundSecondary,
      border: AppColors.border,
      error: AppColors.error,
    );

ThemeData buildDarkTheme() => _build(
      brightness: Brightness.dark,
      primary: AppColorsDark.primary,
      onPrimary: AppColorsDark.primaryForeground,
      background: AppColorsDark.background,
      surface: AppColorsDark.surface,
      surfaceMuted: AppColorsDark.surfaceMuted,
      foreground: AppColorsDark.foreground,
      foregroundSecondary: AppColorsDark.foregroundSecondary,
      border: AppColorsDark.border,
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
  required Color border,
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
    outline: border,
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
        fontWeight: FontWeight.w500,
        color: foreground,
        height: 1.15,
      );
  final radiusMd = BorderRadius.circular(AppRadius.md);
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
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpace.s12),
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        textStyle: body(AppText.base, w: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpace.s12),
        side: BorderSide(color: border),
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s3,
      ),
      border: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radiusMd,
        borderSide: BorderSide(color: primary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => body(
          AppText.xs,
          w: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
        ),
      ),
    ),
    dividerColor: border,
  );
}

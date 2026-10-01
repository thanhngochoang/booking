import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Hosts a screen the way the app does, with the given provider overrides.
/// `retry` is off so a failing provider does not leave a retry timer running.
Widget screenApp({
  required Widget home,
  List<Override> overrides = const [],
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) {
  return ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: MaterialApp(
      theme: brightness == Brightness.dark
          ? buildDarkTheme()
          : buildLightTheme(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

/// Same, for screens that navigate.
Widget screenRouterApp({
  required GoRouter router,
  List<Override> overrides = const [],
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) {
  return ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      theme: brightness == Brightness.dark
          ? buildDarkTheme()
          : buildLightTheme(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

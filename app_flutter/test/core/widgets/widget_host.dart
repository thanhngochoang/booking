// test/core/widgets/widget_host.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Hosts [child] the way the app does: app theme, Vietnamese strings, and a
/// fixed logical width so layout limits can be tested (320 = narrowest phone).
Widget hostWidget(
  Widget child, {
  Brightness brightness = Brightness.dark,
  double width = 390,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: c!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        // Loose inside the fixed width, so small widgets keep their own size.
        child: SizedBox(
          width: width,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}

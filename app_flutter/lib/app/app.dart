import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/l10n/app_localizations.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.router, this.theme, this.darkTheme});
  final GoRouter router;
  final ThemeData? theme;
  final ThemeData? darkTheme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      routerConfig: router,
      theme: theme,
      darkTheme: darkTheme,
      // The brand look is the dark aperture canvas; light stays available.
      themeMode: ThemeMode.dark,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

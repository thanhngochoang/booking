import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.router,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.dark,
    this.ctaAvatar,
    this.showScreenCodes = false,
  });
  final GoRouter router;
  final ThemeData? theme;
  final ThemeData? darkTheme;

  /// The brand look is the dark canvas; users can pick light in Settings.
  final ThemeMode themeMode;

  /// Avatar painted (blurred, tinted) behind main buttons; null = gradient.
  final ImageProvider? ctaAvatar;

  /// Debug aid, see [ScreenCode].
  final bool showScreenCodes;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      routerConfig: router,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      builder: (context, child) => ScreenCodeScope(
        visible: showScreenCodes,
        child: CtaAvatarScope(
          avatar: ctaAvatar,
          child: child ?? const SizedBox(),
        ),
      ),
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

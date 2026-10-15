import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/skills/skills_screen.dart';
import 'package:photobooking/l10n/app_localizations.dart';

import 'photo_scope.dart';
import 'skills_world.dart';

/// The skills routes as the app registers them, plus stubs for where they
/// lead. `/start` pushes `/profile/skills` so Back has somewhere to go.
Widget skillsApp(
  SkillsWorld w, {
  required String initialLocation,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/profile/skills'),
              child: const Text('open skills'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/setup/2',
        builder: (_, _) => const Scaffold(body: Text('S08.01 bước 2')),
      ),
      GoRoute(
        path: '/setup/3',
        builder: (_, _) => const SkillsScreen(mode: SkillsMode.setup),
      ),
      GoRoute(
        path: '/setup/4',
        builder: (_, _) => const Scaffold(body: Text('S08.05')),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('S09.01')),
      ),
      GoRoute(
        path: '/profile/skills',
        builder: (_, _) => const SkillsScreen(mode: SkillsMode.edit),
      ),
      GoRoute(
        path: '/profile/skills/evidence',
        builder: (_, s) => SkillsScreen(
          mode: SkillsMode.edit,
          openEvidenceFor: s.uri.queryParameters['skill'],
        ),
      ),
      GoRoute(
        path: '/action',
        builder: (_, _) => const Scaffold(body: Text('S10.01')),
      ),
    ],
  );
  return ProviderScope(
    retry: (_, _) => null,
    overrides: w.overrides,
    child: MaterialApp.router(
      routerConfig: router,
      theme: brightness == Brightness.dark
          ? buildDarkTheme()
          : buildLightTheme(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => testPhotoScope(
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/app/app.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/features/settings/button_style_controller.dart';
import 'package:photobooking/features/settings/show_screen_codes_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (_, prefs) = await (
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    SharedPreferences.getInstance(),
  ).wait;
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const _Root(),
    ),
  );
}

class _Root extends ConsumerWidget {
  const _Root();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final avatarUrl = ref.watch(currentProfileProvider).value?.avatarUrl;
    final useAvatar =
        ref.watch(buttonStyleProvider) == ButtonStyleMode.avatar &&
        avatarUrl != null;
    return MyApp(
      router: router,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      ctaAvatar: useAvatar ? NetworkImage(avatarUrl) : null,
      showScreenCodes: kDebugMode && ref.watch(showScreenCodesProvider),
    );
  }
}

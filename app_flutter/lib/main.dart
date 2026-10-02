import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/app/app.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/backend/backend_config.dart';
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
  final emulators = emulatorConfigFromEnvironment();
  if (emulators != null) await _connectEmulators(emulators);
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const _Root(),
    ),
  );
}

/// Debug builds started with `--dart-define=USE_EMULATORS=true` talk to the
/// local Firebase Emulator Suite (scripts/backend-local.sh) instead of the
/// cloud project. Runs before any other Firebase call. The host is already
/// resolved for the device, so the SDKs' own localhost mapping is turned off.
Future<void> _connectEmulators(EmulatorConfig e) async {
  // No offline cache: it would mix cloud and emulator documents (same project id).
  final firestore = FirebaseFirestore.instance
    ..settings = const Settings(persistenceEnabled: false);
  firestore.useFirestoreEmulator(
    e.host,
    e.firestorePort,
    automaticHostMapping: false,
  );
  await FirebaseAuth.instance.useAuthEmulator(
    e.host,
    e.authPort,
    automaticHostMapping: false,
  );
  FirebaseFunctions.instanceFor(
    region: functionsRegion,
  ).useFunctionsEmulator(e.host, e.functionsPort, automaticHostMapping: false);
  await FirebaseStorage.instance.useStorageEmulator(
    e.host,
    e.storagePort,
    automaticHostMapping: false,
  );
  debugPrint('Firebase: using local emulators at ${e.host}');
}

class _Root extends ConsumerWidget {
  const _Root();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MyApp(
      router: router,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      ctaAvatar: ref.watch(ctaAvatarProvider),
      showScreenCodes: kDebugMode && ref.watch(showScreenCodesProvider),
    );
  }
}

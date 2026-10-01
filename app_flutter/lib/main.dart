import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/app/app.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: _Root()));
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
    );
  }
}

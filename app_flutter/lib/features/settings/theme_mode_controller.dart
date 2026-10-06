import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';

// The provider lives in data/ so the data layer can read device settings;
// features keep importing it from here.
export 'package:photobooking/data/prefs/shared_preferences_provider.dart';

const _key = 'themeMode';

/// The viewer's theme choice, kept on this device. Dark is the brand default.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.asNameMap()[saved] ?? ThemeMode.dark;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

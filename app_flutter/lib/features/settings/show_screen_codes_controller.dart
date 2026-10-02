// lib/features/settings/show_screen_codes_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/features/settings/theme_mode_controller.dart';

const _key = 'showScreenCodes';

/// Debug aid: show each screen's `Sxx` tag. On by default in debug builds
/// (the user can turn it off in Settings); never shown in release builds.
class ShowScreenCodesController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_key) ?? kDebugMode;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final showScreenCodesProvider =
    NotifierProvider<ShowScreenCodesController, bool>(
      ShowScreenCodesController.new,
    );

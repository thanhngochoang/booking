// lib/features/settings/show_screen_codes_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/features/settings/theme_mode_controller.dart';

const _key = 'showScreenCodes';

/// Debug aid: show each screen's `Sxx` tag. Off by default; only offered in
/// debug builds (see the Settings screen) and ignored by `ScreenCode` in release.
class ShowScreenCodesController extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final showScreenCodesProvider =
    NotifierProvider<ShowScreenCodesController, bool>(
      ShowScreenCodesController.new,
    );

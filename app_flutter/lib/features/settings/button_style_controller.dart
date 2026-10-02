import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

const _key = 'buttonStyle';

/// How main buttons are filled.
enum ButtonStyleMode {
  /// The theme gradient.
  gradient,

  /// The viewer's avatar, blurred and tinted with the theme gradient.
  avatar,
}

/// The viewer's choice, kept on this device. Gradient is the default; the
/// avatar style falls back to it while there is no avatar.
class ButtonStyleController extends Notifier<ButtonStyleMode> {
  @override
  ButtonStyleMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return ButtonStyleMode.values.asNameMap()[saved] ??
        ButtonStyleMode.gradient;
  }

  Future<void> set(ButtonStyleMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final buttonStyleProvider =
    NotifierProvider<ButtonStyleController, ButtonStyleMode>(
      ButtonStyleController.new,
    );

/// What `CtaAvatarScope` paints behind main buttons: the viewer's photo when
/// they chose the avatar style and have one, else null (gradient). It
/// follows the profile stream, so a new avatar shows on the next frame.
final ctaAvatarProvider = Provider<ImageProvider?>((ref) {
  final url = ref.watch(currentProfileProvider).value?.avatarUrl;
  final avatarStyle = ref.watch(buttonStyleProvider) == ButtonStyleMode.avatar;
  return avatarStyle && url != null ? NetworkImage(url) : null;
});

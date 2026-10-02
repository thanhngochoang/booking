import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/features/settings/avatar_controller.dart';

/// The avatar and its "Đổi ảnh đại diện" button (S42, S24 step 1), centred as
/// in the mock. The circle crops the photo; it is uploaded as picked.
class AvatarEditor extends ConsumerWidget {
  const AvatarEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider).value;
    final busy = ref.watch(avatarControllerProvider).isLoading;
    ref.listen(avatarControllerProvider, (prev, next) {
      if (next.isLoading) {
        return;
      }
      // An error counts even when the picker failed before the upload began.
      final text = next.hasError
          ? l.editProfileAvatarError
          : (prev?.isLoading ?? false) && (next.value ?? false)
          ? l.editProfileAvatarSaved
          : null;
      if (text != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text)));
      }
    });
    return Column(
      children: [
        AppAvatar(
          url: profile?.avatarUrl,
          name: profile?.displayName ?? '',
          size: AppAvatarSize.lg,
        ),
        const SizedBox(height: AppSpace.s2),
        AppButton.outline(
          l.editProfileChangeAvatar,
          key: const Key('change-avatar'),
          size: AppButtonSize.small,
          icon: const Icon(Icons.photo_library_outlined),
          loading: busy,
          onPressed: busy
              ? null
              : () => ref.read(avatarControllerProvider.notifier).change(),
        ),
      ],
    );
  }
}

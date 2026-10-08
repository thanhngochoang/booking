import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/onboarding/role_controller.dart';

/// Whether the signed-in photographer still has setup (S08.01) to finish.
/// Offline (or signed out) counts as finished: Hồ sơ's setup card still
/// offers it.
Future<bool> _setupUnfinished(WidgetRef ref) async {
  final uid = ref.read(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return false;
  }
  try {
    final intro = await ref.read(photographerIntroRepositoryProvider).get(uid);
    return !(intro?.onboardingComplete ?? false);
  } catch (_) {
    return false;
  }
}

/// S09.02 "Chế độ": offers the other mode and switches to it. It owns the
/// one listener on [roleSwitchControllerProvider], so a finished switch shows
/// one SnackBar, then opens setup (a photographer who has not finished it)
/// or goes back to Hồ sơ in the new mode.
class RoleModeCard extends ConsumerWidget {
  const RoleModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    final isPhotographer = profile?.role == UserRole.photographer;
    final switching = ref.watch(roleSwitchControllerProvider).isLoading;
    ref.listen(roleSwitchControllerProvider, (prev, next) async {
      // Only a finished switch the user started: loading -> data/error.
      if (next.isLoading || !(prev?.isLoading ?? false)) return;
      final messenger = ScaffoldMessenger.of(context);
      if (next.hasError) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.profileSwitchError)));
        return;
      }
      // The controller's value, not the profile stream, which may lag.
      final role = next.value;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              role == UserRole.photographer
                  ? l.profileSwitchedToPhotographer
                  : l.profileSwitchedToCustomer,
            ),
          ),
        );
      if (role == UserRole.photographer && await _setupUnfinished(ref)) {
        if (context.mounted) context.go('/setup');
        return;
      }
      if (context.mounted) context.go(AppTab.profile.path);
    });
    return GlassCard(
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The card offers the other mode, so its text names that mode.
            Text(
              isPhotographer
                  ? l.profileOfferCustomerTitle
                  : l.profileOfferPhotographerTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              isPhotographer
                  ? l.profileOfferCustomerBody
                  : l.profileOfferPhotographerBody,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpace.s3),
            AppButton.outline(
              isPhotographer
                  ? l.profileSwitchToCustomer
                  : l.profileSwitchToPhotographer,
              key: const Key('switch-role'),
              size: AppButtonSize.small,
              icon: const AppIcon(AppIcons.swap),
              loading: switching,
              onPressed: profile == null
                  ? null
                  : () => ref
                        .read(roleSwitchControllerProvider.notifier)
                        .switchTo(
                          isPhotographer
                              ? UserRole.customer
                              : UserRole.photographer,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

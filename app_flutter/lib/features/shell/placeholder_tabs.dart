import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/my_bookings_screen.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/home/home_controller.dart';
import 'package:photobooking/features/onboarding/role_controller.dart';
import 'package:photobooking/features/work/work_screen.dart';

UserRole _role(WidgetRef ref) =>
    ref.watch(currentProfileProvider).value?.role ?? UserRole.customer;

/// After switching to photographer: open the setup while it is unfinished
/// (spec S09.01). Without a router above (some widget tests) it does nothing.
Future<void> _openSetupIfUnfinished(BuildContext context, WidgetRef ref) async {
  final uid = ref.read(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return;
  }
  PhotographerIntro? intro;
  try {
    intro = await ref.read(photographerIntroRepositoryProvider).get(uid);
  } catch (_) {
    return; // offline: the card on this tab still offers it
  }
  if (!context.mounted || (intro?.onboardingComplete ?? false)) {
    return;
  }
  GoRouter.maybeOf(context)?.push('/setup');
}

class ActionTab extends ConsumerWidget {
  const ActionTab({super.key, this.specialty, this.style, this.area});

  /// Filters carried by the link `/action?specialty=…&style=…&area=…`.
  final String? specialty;
  final String? style;
  final String? area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.role;
    if (role == null) {
      return const SizedBox.shrink();
    }
    if (role == UserRole.customer) {
      return FindPhotographerScreen(
        initialSpecialty: specialty,
        initialStyle: style,
        initialArea: area,
      );
    }
    return CreatePostScreen(
      onAddService: () => context.push('/setup/2'),
      onPublished: (postId) {
        ref.read(homeFeedProvider.notifier).pinToTop(postId);
        context.go(AppTab.home.path);
      },
    );
  }
}

class BookingsTab extends ConsumerWidget {
  const BookingsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing until the role is known, so neither side flashes the other's tab.
    if (!ref.watch(currentProfileProvider).hasValue) {
      return const SizedBox.shrink();
    }
    return _role(ref) == UserRole.customer
        ? const MyBookingsScreen()
        : const WorkScreen();
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    final isPhotographer = profile?.role == UserRole.photographer;
    final setupOpen =
        isPhotographer &&
        !(ref.watch(myIntroProvider).value?.onboardingComplete ?? true);
    final switching = ref.watch(roleSwitchControllerProvider).isLoading;
    ref.listen(roleSwitchControllerProvider, (prev, next) {
      // Only a finished switch the user started: loading -> data/error.
      if (next.isLoading || !(prev?.isLoading ?? false)) return;
      final message = next.hasError
          ? l.profileSwitchError
          : next.value == UserRole.photographer
          ? l.profileSwitchedToPhotographer
          : l.profileSwitchedToCustomer;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      if (!next.hasError && next.value == UserRole.photographer) {
        _openSetupIfUnfinished(context, ref);
      }
    });
    final avatar = profile?.avatarUrl;
    return ScreenCode(
      ScreenCodes.profile,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          titleTextStyle: tabRootTitleStyle(context),
          title: Text(l.tabProfile),
          actions: [
            IconButton(
              key: const Key('open-settings'),
              tooltip: l.settingsTitle,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: SafeArea(
          // Scrolls on short or landscape screens; sign-out still sits at the
          // bottom when there is room.
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: box.maxHeight - AppSpace.s5 * 2,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: AppAvatar(
                          url: avatar,
                          name: profile?.displayName ?? '',
                          size: AppAvatarSize.lg,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s3),
                      Text(
                        profile?.displayName ?? '',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        isPhotographer
                            ? l.profileRolePhotographer
                            : l.profileRoleCustomer,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      if (setupOpen) ...[
                        const SizedBox(height: AppSpace.s6),
                        GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.s4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l.profileSetupTitle,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpace.s1),
                                Text(
                                  l.profileSetupBody,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: AppSpace.s4),
                                AppButton.outline(
                                  l.profileSetupContinue,
                                  key: const Key('continue-setup'),
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  onPressed: () => context.push('/setup'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpace.s6),
                      GlassCard(
                        highlight: false,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // The card offers the other mode, so its text
                              // names the mode you'd switch to.
                              Text(
                                isPhotographer
                                    ? l.profileOfferCustomerTitle
                                    : l.profileOfferPhotographerTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: AppSpace.s2),
                              Text(
                                isPhotographer
                                    ? l.profileOfferCustomerBody
                                    : l.profileOfferPhotographerBody,
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSpace.s3),
                              AppButton.primary(
                                isPhotographer
                                    ? l.profileSwitchToCustomer
                                    : l.profileSwitchToPhotographer,
                                key: const Key('switch-role'),
                                size: AppButtonSize.small,
                                icon: const Icon(Icons.swap_horiz_rounded),
                                loading: switching,
                                onPressed: profile == null
                                    ? null
                                    : () => ref
                                          .read(
                                            roleSwitchControllerProvider
                                                .notifier,
                                          )
                                          .switchTo(
                                            isPhotographer
                                                ? UserRole.customer
                                                : UserRole.photographer,
                                          ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: AppSpace.s5),
                      AppButton.outline(
                        l.signOut,
                        key: const Key('sign-out'),
                        onPressed: switching
                            ? null
                            : () => ref.read(authRepositoryProvider).signOut(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/onboarding/role_controller.dart';

UserRole _role(WidgetRef ref) =>
    ref.watch(currentProfileProvider).value?.role ?? UserRole.customer;

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.home,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.tabHome)),
        body: EmptyState(title: l.emptyHomeTitle, body: l.emptyHomeBody),
      ),
    );
  }
}

class ActionTab extends ConsumerWidget {
  const ActionTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final photographer = _role(ref) == UserRole.photographer;
    return ScreenCode(
      photographer ? ScreenCodes.createPost : ScreenCodes.findPhotographer,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(photographer ? l.tabCreate : l.tabFind)),
        body: EmptyState(
          title: photographer ? l.emptyCreateTitle : l.emptyFindTitle,
          body: photographer ? l.emptyCreateBody : l.emptyFindBody,
        ),
      ),
    );
  }
}

class BookingsTab extends ConsumerWidget {
  const BookingsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final photographer = _role(ref) == UserRole.photographer;
    return ScreenCode(
      photographer ? ScreenCodes.workEmpty : ScreenCodes.bookings,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(photographer ? l.tabWork : l.tabBookings)),
        body: EmptyState(
          title: photographer ? l.emptyWorkTitle : l.emptyBookingsTitle,
          body: photographer ? l.emptyWorkBody : l.emptyBookingsBody,
        ),
      ),
    );
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
    });
    final avatar = profile?.avatarUrl;
    return ScreenCode(
      ScreenCodes.profile,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
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

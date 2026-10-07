import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/badges/badge_providers.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/awards/award_nudge.dart';
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
      onOpenEvents: () => context.push('/events/new'),
      onPublished: (postId) {
        ref.read(homeFeedProvider.notifier).pinToTop(postId);
        context.go(AppTab.home.path);
      },
    );
  }
}

class BookingsTab extends ConsumerWidget {
  const BookingsTab({super.key, this.tab, this.highlight});

  /// `events` opens the customer's "Vé sự kiện" (`/bookings?tab=events`).
  final String? tab;

  /// The ticket to emphasise (`&highlight=<registrationId>`).
  final String? highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nothing until the role is known, so neither side flashes the other's tab.
    if (!ref.watch(currentProfileProvider).hasValue) {
      return const SizedBox.shrink();
    }
    return _role(ref) == UserRole.customer
        ? MyBookingsScreen(
            showTickets: true,
            initialTab: tab,
            highlightTicketId: highlight,
          )
        : const WorkScreen(showEvents: true);
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
              icon: const AppIcon(AppIcons.settings),
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
                      const SizedBox(height: AppSpace.s4),
                      const _NotificationsRow(),
                      if (profile != null) ...[
                        const SizedBox(height: AppSpace.s3),
                        _BadgesRow(uid: profile.uid),
                      ],
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
                                  icon: const AppIcon(AppIcons.forward),
                                  onPressed: () => context.push('/setup'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (isPhotographer) ...[
                        const SizedBox(height: AppSpace.s4),
                        const _MyAlbumsRow(),
                        const SizedBox(height: AppSpace.s2),
                        const _EarningsRow(),
                        AwardNudgeRow(uid: profile!.uid),
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
                                icon: const AppIcon(AppIcons.swap),
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
                            : () =>
                                  ref.read(pushRegistrationProvider).signOut(),
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

/// S09.01: up to three earned badges under the Thông báo row. "Tất cả" is
/// always there so S03.02 (locked badges and progress) stays reachable.
class _BadgesRow extends ConsumerWidget {
  const _BadgesRow({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgeChipsProvider(uid)).value ?? const [];
    return BadgeRow(
      key: const Key('profile-tab-badges'),
      badges: badges,
      max: 3,
      alwaysShowSeeAll: true,
      onSeeAll: () => context.push('/u/$uid/badges'),
    );
  }
}

/// S09.01: photographers open S24.02 from here.
class _MyAlbumsRow extends StatelessWidget {
  const _MyAlbumsRow();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _LinkRow(
      key: const Key('open-my-albums'),
      icon: AppIcons.album,
      title: l.profileMyAlbums,
      sub: l.profileMyAlbumsSub,
      path: '/me/albums',
    );
  }
}

/// S09.01: photographers open S06.05 Thu nhập from here (the mock is silent;
/// same card as "Album của tôi").
class _EarningsRow extends StatelessWidget {
  const _EarningsRow();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _LinkRow(
      key: const Key('open-earnings'),
      icon: AppIcons.wallet,
      title: l.profileEarnings,
      sub: l.profileEarningsSub,
      path: '/work/earnings',
    );
  }
}

/// A glass card with an icon, a title and a sub line that opens [path].
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String sub;
  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      highlight: false,
      child: Semantics(
        button: true,
        label: '$title. $sub',
        excludeSemantics: true,
        onTap: () => context.push(path),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push(path),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Row(
                children: [
                  AppIcon(icon),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(sub, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const AppIcon(AppIcons.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// S09.01: the newest notification and the unread count; opens S17.01. Reads
/// the count from the one `unreadCount` document and re-fetches the newest
/// row when it changes; it never listens to the inbox itself.
class _NotificationsRow extends ConsumerWidget {
  const _NotificationsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final latest = ref.watch(latestNotificationProvider).value;
    final summary = latest?.title ?? l.notifEmptyTitle;
    final scheme = theme.colorScheme;
    void open() => context.push('/notifications');
    return GlassCard(
      highlight: false,
      child: Semantics(
        button: true,
        label: unread > 0
            ? l.notifRowSemantics(unread, summary)
            : l.notifRowSemanticsRead(summary),
        excludeSemantics: true,
        onTap: open,
        child: InkWell(
          key: const Key('open-notifications'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpace.s12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColorsDark.surfaceMuted
                          : AppColors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: AppIcon(
                          AppIcons.notifications,
                          color: context.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.notificationTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (unread > 0) ...[
                    const SizedBox(width: AppSpace.s2),
                    DecoratedBox(
                      key: const Key('notifications-count'),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s2,
                            vertical: 2,
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppText.xs2,
                              fontWeight: FontWeight.w700,
                              color: scheme.onError,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpace.s1),
                  const AppIcon(AppIcons.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

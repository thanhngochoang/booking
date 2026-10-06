import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/notifications/notification_targets.dart';
import 'package:photobooking/features/notifications/notification_visuals.dart';
import 'package:photobooking/features/notifications/notifications_analytics.dart';
import 'package:photobooking/features/notifications/notifications_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S17.01: the in-app inbox.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(notificationsAnalyticsProvider)('notifications_open', {
        'unread': ref.read(unreadCountProvider).value ?? 0,
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.extentAfter < 400) {
      ref.read(notificationsControllerProvider.notifier).loadMore();
    }
  }

  void _say(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _open(AppNotification n) async {
    final ctrl = ref.read(notificationsControllerProvider.notifier);
    final l = context.l10n;
    ctrl.markRead(n.id);
    ref.read(notificationsAnalyticsProvider)('notification_tap', {
      'type': n.type,
    });
    final target = safeTarget(n.target);
    if (target == null) {
      _say(l.notifTargetGone);
      return;
    }
    if (targetNeedsExistenceCheck(target)) {
      bool exists;
      try {
        exists = await ref
            .read(notificationRepositoryProvider)
            .targetExists(target);
      } on Object {
        // No answer is not "gone": the destination shows its own error.
        exists = true;
      }
      if (!mounted) {
        return;
      }
      if (!exists) {
        _say(l.notifTargetGone);
        return;
      }
    }
    openNotificationTarget(GoRouter.of(context), target);
  }

  Future<void> _mute(AppNotification n) async {
    final l = context.l10n;
    final ctrl = ref.read(notificationsControllerProvider.notifier);
    try {
      final undo = await ctrl.mute(n);
      if (undo == null || !mounted) {
        return;
      }
      ref.read(notificationsAnalyticsProvider)('notification_mute_type', {
        'type': n.type,
      });
      _say(
        l.notifMuted,
        action: SnackBarAction(
          label: l.notifUndo,
          onPressed: () => undo.undo().catchError((_) {}),
        ),
      );
    } on Object catch (e) {
      if (mounted) {
        _say(errorMessage(e, l));
      }
    }
  }

  Future<void> _markAll() async {
    final l = context.l10n;
    try {
      await ref.read(notificationsControllerProvider.notifier).markAllRead();
      ref.read(notificationsAnalyticsProvider)('notification_mark_all', {});
    } on Object catch (e) {
      if (mounted) {
        _say(errorMessage(e, l));
      }
    }
  }

  String _tabLabel(NotificationTab? t, UserRole? role, AppLocalizations l) =>
      switch (t) {
        null => l.notifTabAll,
        NotificationTab.activity =>
          role == UserRole.photographer ? l.notifTabWork : l.notifTabBooking,
        NotificationTab.events => l.notifTabEvents,
        NotificationTab.system => l.notifTabSystem,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final role = ref.watch(currentProfileProvider).value?.role;
    final tab = ref.watch(notificationTabFilterProvider);
    final async = ref.watch(notificationsControllerProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final fromCache = async.value?.fromCache ?? false;
    return ScreenCode(
      ScreenCodes.notifications,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(l.notificationTitle),
            actions: [
              IconButton(
                key: const Key('notifications-settings'),
                tooltip: l.notifSettingsTooltip,
                icon: const AppIcon(AppIcons.settings),
                onPressed: () => context.push('/settings/notifications'),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (fromCache) const OfflineBanner(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s4,
                    AppSpace.s2,
                    AppSpace.s4,
                    AppSpace.s1,
                  ),
                  child: SegmentedTabs<NotificationTab?>(
                    options: [
                      for (final t in <NotificationTab?>[
                        null,
                        NotificationTab.activity,
                        NotificationTab.events,
                        NotificationTab.system,
                      ])
                        SegmentOption(value: t, label: _tabLabel(t, role, l)),
                    ],
                    value: tab,
                    onChanged: (t) {
                      ref.read(notificationTabFilterProvider.notifier).state =
                          t;
                      ref.read(notificationsAnalyticsProvider)(
                        'notifications_filter',
                        {'tab': t?.name ?? 'all'},
                      );
                    },
                  ),
                ),
                if (unread > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          l.notifUnreadHeader(unread),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              key: const Key('notifications-mark-all'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: fromCache ? null : _markAll,
                              child: Text(
                                l.notifMarkAllRead,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: AsyncView<NotificationsState>(
                    value: async,
                    loadingLabel: l.notificationTitle,
                    skeleton: (_) => ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var i = 0; i < 6; i++) NotificationRow.skeleton(),
                      ],
                    ),
                    onRetry: () =>
                        ref.invalidate(notificationsControllerProvider),
                    isEmpty: (s) => s.items.isEmpty,
                    empty: (_) => _empty(context, tab, role),
                    data: (_, s) => _list(context, s, role),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context, NotificationTab? tab, UserRole? role) {
    final l = context.l10n;
    final photographer = role == UserRole.photographer;
    if (tab != null) {
      return EmptyState(
        title: l.notifEmptyFiltered(_tabLabel(tab, role, l)),
        body: l.notifEmptyFilteredBody,
        illustration: const _BellDisc(),
      );
    }
    return EmptyState(
      title: l.notifEmptyTitle,
      body: l.notifEmptyBody,
      illustration: const _BellDisc(),
      actionLabel: photographer
          ? l.notifEmptyCtaPhotographer
          : l.notifEmptyCtaCustomer,
      onAction: () =>
          context.go(photographer ? AppTab.bookings.path : AppTab.action.path),
    );
  }

  Widget _list(BuildContext context, NotificationsState s, UserRole? role) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final entries = <Object>[];
    NotificationSection? last;
    for (final n in s.items) {
      final section = sectionOf(n.createdAt, now);
      if (section != last) {
        entries.add(section);
        last = section;
      }
      entries.add(n);
    }
    if (s.loadingMore) {
      entries.add(#loading);
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(notificationsControllerProvider.notifier).refresh(),
      child: ListView.builder(
        key: const Key('notifications-list'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          if (e is NotificationSection) {
            return SectionHeader(
              title: switch (e) {
                NotificationSection.today => l.notifSectionToday,
                NotificationSection.week => l.notifSectionWeek,
                NotificationSection.earlier => l.notifSectionEarlier,
              },
            );
          }
          if (e is AppNotification) {
            return _row(e, now, l);
          }
          return NotificationRow.skeleton();
        },
      ),
    );
  }

  Widget _row(AppNotification n, DateTime now, AppLocalizations l) {
    final visual = notificationVisualOf(n.type);
    final ctrl = ref.read(notificationsControllerProvider.notifier);
    return NotificationRow(
      key: ValueKey('notification-${n.id}'),
      item: NotificationRowData(
        id: n.id,
        icon: visual.icon,
        tone: visual.tone,
        title: n.title,
        body: n.body,
        timeLabel: notificationTimeLabel(n.createdAt, now, l),
        unread: n.unread,
        thumbUrl: n.thumbUrl,
        groupAvatars: n.count > 1
            ? [for (final a in n.actors) a.avatarUrl ?? '']
            : const [],
      ),
      onTap: () => _open(n),
      onMarkRead: () => ctrl.markRead(n.id),
      // Booking rows cannot be muted (Decision 7).
      onMuteKind: n.category == NotificationCategory.booking
          ? null
          : () => _mute(n),
    );
  }
}

class _BellDisc extends StatelessWidget {
  const _BellDisc();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: AppIcon(
          AppIcons.notifications,
          size: 40,
          color: context.mutedForeground,
        ),
      ),
    );
  }
}

/// Tab destinations switch tabs; everything else opens on top.
void openNotificationTarget(GoRouter router, String path) {
  if (path == AppTab.bookings.path) {
    router.go(path);
  } else {
    router.push(path);
  }
}

// lib/features/events/event_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/events/event_info_tab.dart';
import 'package:photobooking/features/events/event_join_bar.dart';
import 'package:photobooking/features/events/event_links.dart';
import 'package:photobooking/features/events/register_sheet.dart';
import 'package:photobooking/features/events/timeline_controller.dart';
import 'package:photobooking/features/events/timeline_tab.dart';

/// The three tabs of an event (Decision 26): `/e/:id` opens "Thông tin",
/// `/e/:id/timeline` opens "Timeline".
enum EventTab { info, timeline, chat }

/// S11.02 (and S11.05 on the Timeline tab): one event.
class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({
    super.key,
    required this.eventId,
    this.initialTab = EventTab.info,
    this.openRegister = false,
    this.initialReview = false,
  });

  final String eventId;
  final EventTab initialTab;

  /// Open the timeline on "Chờ duyệt" (managers; `/e/:id/timeline?review=1`).
  final bool initialReview;

  /// Coming back from "add phone" (`/e/:id/join`): open S11.03 at once.
  final bool openRegister;

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  late EventTab _tab = widget.initialTab;
  bool _busy = false;
  bool _autoJoinDone = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/events');
    }
  }

  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = context.l10n.eventLinkCopied;
    await copyEventLink(widget.eventId);
    if (!mounted) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// "Đăng ký tham gia": a customer needs a phone number first (spec 3b.1);
  /// reading the contact fails closed, so a failure also goes to S04.05.
  Future<void> _join(EventDetail event) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    Object? contact;
    final hold = ref.listenManual(currentContactProvider, (_, _) {});
    try {
      contact = await ref.read(currentContactProvider.future);
    } catch (_) {
      contact = null;
    } finally {
      hold.close();
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (contact == null) {
      final back = Uri.encodeComponent('/e/${event.id}/join');
      context.push('/profile/phone?returnTo=$back');
      return;
    }
    await _openRegister(event);
  }

  Future<void> _openRegister(EventDetail event) =>
      showRegisterSheet(context, event: event);

  /// "Đăng ảnh với #Tag": photographers write a post (S10.01), everyone else
  /// shares photos here.
  void _post(EventDetail e, TimelinePostMode mode) {
    if (mode == TimelinePostMode.photographer) {
      context.go(timelineCaptionRoute(e.hashtag));
    } else {
      context.push('/e/${e.id}/share');
    }
  }

  /// Pull to refresh on the Timeline tab: both lists reload.
  Widget _refreshable(
    EventDetail e, {
    required bool enabled,
    required Widget child,
  }) {
    if (!enabled) {
      return child;
    }
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          for (final status in [TimelineStatus.visible, TimelineStatus.pending])
            ref
                .read(
                  timelineControllerProvider((eventId: e.id, status: status))
                      .notifier,
                )
                .refresh(),
        ]);
      },
      child: child,
    );
  }

  void _viewTicket(EventRegistration? r) {
    final highlight = r == null ? '' : '&highlight=${r.id}';
    context.go('/bookings?tab=events$highlight');
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventProvider(widget.eventId));
    final code = _tab == EventTab.timeline
        ? ScreenCodes.eventTimeline
        : ScreenCodes.eventDetail;
    return ScreenCode(
      code,
      child: AsyncView<EventDetail?>(
        value: event,
        skeleton: (_) => _skeleton(),
        onRetry: () => ref.invalidate(eventProvider(widget.eventId)),
        isEmpty: (e) => e == null,
        empty: (_) => _gone(),
        data: (_, e) => _content(e!),
      ),
    );
  }

  Widget _skeleton() => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      leading: IconButton(
        tooltip: context.l10n.back,
        icon: const AppIcon(AppIcons.back),
        onPressed: _back,
      ),
    ),
    body: AppSkeletonScope(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          AppSkeleton.box(
            width: double.infinity,
            height: 180,
            radius: AppRadius.card,
          ),
          const SizedBox(height: AppSpace.s3),
          AppSkeleton.line(height: 26),
          const SizedBox(height: AppSpace.s3),
          CapacityBar.skeleton(),
        ],
      ),
    ),
  );

  Widget _gone() {
    final l = context.l10n;
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            tooltip: l.back,
            icon: const AppIcon(AppIcons.back),
            onPressed: _back,
          ),
        ),
        body: EmptyState(
          title: l.eventGone,
          body: l.eventGoneBody,
          actionLabel: l.back,
          onAction: _back,
        ),
      ),
    );
  }

  Widget _content(EventDetail e) {
    final l = context.l10n;
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final role = ref.watch(staffRoleProvider).value;
    final reg = ref.watch(myEventRegistrationProvider(e.id)).value;
    final manager = e.isManagedBy(uid, role);
    if (e.summary.status == EventStatus.draft && !manager) {
      return _gone();
    }
    final now = ref.watch(clockProvider)();
    final state = eventJoinState(
      e,
      reg,
      uid: uid,
      role: role,
      now: now,
      paymentsReady: ref.watch(eventPaymentsReadyProvider),
    );
    if (widget.openRegister && !_autoJoinDone && state == EventJoinState.join) {
      _autoJoinDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _join(e);
        }
      });
    }

    final s = e.summary;
    final cancelled = state == EventJoinState.cancelled;
    final member = manager || (reg?.status == RegistrationStatus.paid);
    final timeline = _tab == EventTab.timeline;
    final postMode = timelinePostMode(
      e,
      manager: manager,
      paidAttendee: isPaidAttendee(reg),
      role: ref.watch(currentProfileProvider).value?.role,
      now: now,
    );
    final theme = Theme.of(context);

    final cover = s.coverUrl;
    final tabs = SegmentedTabs<EventTab>(
      options: [
        SegmentOption(value: EventTab.info, label: l.eventTabInfo),
        SegmentOption(value: EventTab.timeline, label: l.eventTabTimeline),
        SegmentOption(value: EventTab.chat, label: l.eventTabChat),
      ],
      value: _tab,
      onChanged: (t) {
        // Members open the group chat on its own screen (S11.06).
        if (t == EventTab.chat && member) {
          context.push('/e/${e.id}/chat');
          return;
        }
        setState(() => _tab = t);
      },
    );

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: timeline
          ? AppBar(
              leading: IconButton(
                tooltip: l.back,
                icon: const AppIcon(AppIcons.back),
                onPressed: _back,
              ),
              title: Text(
                s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  key: const Key('event-share'),
                  tooltip: l.eventShareTooltip,
                  icon: const AppIcon(AppIcons.share),
                  onPressed: _share,
                ),
              ],
            )
          : null,
      body: _refreshable(
        e,
        enabled: timeline,
        child: ListView(
          physics: timeline ? const AlwaysScrollableScrollPhysics() : null,
          padding: EdgeInsets.zero,
          children: [
            if (!timeline)
              _Cover(
                url: cover,
                onBack: _back,
                onShare: _share,
                shareTooltip: l.eventShareTooltip,
                backTooltip: l.back,
              ),
            if (cancelled) _CancelledStrip(text: l.eventCancelled),
            if (s.isFree && !cancelled && !timeline) const FreeBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s3,
                AppSpace.s4,
                AppSpace.s6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!timeline) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s2,
                            vertical: 3,
                          ),
                          child: Text(
                            s.type.label(l),
                            style: const TextStyle(
                              fontSize: AppText.xs,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      s.title,
                      key: const Key('event-title'),
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s3),
                  ],
                  tabs,
                  const SizedBox(height: AppSpace.s3),
                  switch (_tab) {
                    EventTab.info => EventInfoTab(
                      event: e,
                      registration: reg,
                      isManager: manager,
                    ),
                    EventTab.timeline => TimelineTab(
                      event: e,
                      isManager: manager,
                      initialReview: widget.initialReview,
                    ),
                    // A member never lands here: the tab opens S11.06.
                    EventTab.chat => _Panel(
                      title: l.eventChatLocked,
                      body: l.eventChatLockedBody,
                      icon: AppIcons.lock,
                    ),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: cancelled
          ? null
          : postMode != TimelinePostMode.none && timeline
          ? TimelinePostBar(
              mode: postMode,
              hashtag: e.hashtag,
              onPost: () => _post(e, postMode),
            )
          : EventJoinBar(
              event: e,
              state: state,
              busy: _busy,
              onJoin: () => _join(e),
              onViewTicket: () => _viewTicket(reg),
              onManage: () => context.push('/events/${e.id}/manage'),
            ),
    );

    return cover == null || cover.isEmpty
        ? AuroraBackground(child: scaffold)
        : ImageBackdrop(image: NetworkImage(cover), child: scaffold);
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.url,
    required this.onBack,
    required this.onShare,
    required this.backTooltip,
    required this.shareTooltip,
  });

  final String? url;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final String backTooltip;
  final String shareTooltip;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + AppSpace.s2;
    Widget round(Key key, String tip, IconData icon, VoidCallback onTap) =>
        Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: IconButton(
            key: key,
            tooltip: tip,
            icon: AppIcon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        );
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url!.isNotEmpty)
            NetworkPhoto(url: url!, fit: BoxFit.cover)
          else
            ColoredBox(color: Theme.of(context).colorScheme.secondary),
          Positioned(
            top: top,
            left: AppSpace.s2,
            child: round(
              const Key('event-back'),
              backTooltip,
              AppIcons.back,
              onBack,
            ),
          ),
          Positioned(
            top: top,
            right: AppSpace.s2,
            child: round(
              const Key('event-share'),
              shareTooltip,
              AppIcons.share,
              onShare,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledStrip extends StatelessWidget {
  const _CancelledStrip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: const Key('event-cancelled-strip'),
        decoration: BoxDecoration(color: error.withValues(alpha: 0.16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4,
            vertical: AppSpace.s3,
          ),
          child: Row(
            children: [
              AppIcon(AppIcons.error, color: error),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontWeight: FontWeight.w700, color: error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, this.body});
  final String title;
  final String? body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('event-panel'),
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: Column(
        children: [
          AppIcon(icon, size: AppIconSize.lg),
          const SizedBox(height: AppSpace.s3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

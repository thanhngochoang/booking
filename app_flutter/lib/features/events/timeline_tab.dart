// lib/features/events/timeline_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_social_providers.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/events/timeline_controller.dart';
import 'package:photobooking/features/safety/report_sheet.dart';

/// Timeline closes for new posts 30 days after the event completed (domain
/// `TIMELINE_OPEN_DAYS`).
const timelineOpenDays = 30;

/// What the bottom of the Timeline tab offers the viewer.
enum TimelinePostMode {
  /// The viewer cannot post (a visitor, or the event is a draft or cancelled).
  none,

  /// A paid attendee or a manager without the photographer role: the share composer.
  share,

  /// A photographer: S10.01 with the hashtag in the caption.
  photographer,

  /// Allowed to post, but the timeline closed: the note "Timeline đã đóng đăng mới".
  closed,
}

TimelinePostMode timelinePostMode(
  EventDetail e, {
  required bool manager,
  required bool paidAttendee,
  required UserRole? role,
  required DateTime now,
}) {
  final status = e.summary.status.name;
  if (status == 'draft' || status == 'cancelled') {
    return TimelinePostMode.none;
  }
  final photographer = role == UserRole.photographer;
  if (!manager && !paidAttendee && !photographer) {
    return TimelinePostMode.none;
  }
  final done = e.completedAt;
  if (done != null &&
      now.isAfter(done.add(const Duration(days: timelineOpenDays)))) {
    return TimelinePostMode.closed;
  }
  return photographer ? TimelinePostMode.photographer : TimelinePostMode.share;
}

/// Whether [reg] is a paid registration (the attendee may post).
bool isPaidAttendee(EventRegistration? reg) =>
    reg != null && reg.status == RegistrationStatus.paid;

/// S10.01 with the hashtag and a space already in the caption.
String timelineCaptionRoute(String hashtag) =>
    '/action?caption=${Uri.encodeQueryComponent('#$hashtag ')}';

/// S11.05 bottom bar: "Đăng ảnh với #Tag" (primary) or the closed note.
class TimelinePostBar extends StatelessWidget {
  const TimelinePostBar({
    super.key,
    required this.mode,
    required this.hashtag,
    required this.onPost,
  });

  final TimelinePostMode mode;
  final String hashtag;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppFooterBar(
      child: mode == TimelinePostMode.closed
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
              child: Text(
                l.timelineClosed,
                key: const Key('timeline-closed'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : AppButton.primary(
              l.timelinePost('#$hashtag'),
              key: const Key('timeline-post'),
              onPressed: onPost,
            ),
    );
  }
}

/// The Timeline tab of an event (S11.05): hashtag chip, a two-column masonry
/// of the first photo of each post with the author overlaid, and for managers
/// the "Chờ duyệt" review list.
class TimelineTab extends ConsumerStatefulWidget {
  const TimelineTab({
    super.key,
    required this.event,
    required this.isManager,
    this.initialReview = false,
  });

  final EventDetail event;
  final bool isManager;

  /// Open on "Chờ duyệt" (`/e/:id/timeline?review=1`).
  final bool initialReview;

  @override
  ConsumerState<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends ConsumerState<TimelineTab> {
  /// What the person picked; until then the link decides. The manager flag
  /// can arrive after the first build (the account loads on its own).
  bool? _picked;

  /// The event screen's list this tab sits in: the next page loads when it
  /// nears the end (review M15; the mock draws no "Xem thêm" button).
  ScrollPosition? _position;

  /// How close to the end (in logical pixels) the next page starts loading.
  static const _loadAhead = 600.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context)?.position;
    if (!identical(p, _position)) {
      _position?.removeListener(_nearEnd);
      _position = p;
      p?.addListener(_nearEnd);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_nearEnd);
    super.dispose();
  }

  /// Loads the next page when the list is within [_loadAhead] of its end,
  /// or when the page does not even fill the screen. A failed page waits for
  /// the retry link instead of looping.
  void _nearEnd() {
    if (!mounted) {
      return;
    }
    final p = _position;
    if (p == null || !p.hasContentDimensions || p.extentAfter > _loadAhead) {
      return;
    }
    final state = ref.read(timelineControllerProvider(_key));
    if (state.cursor == null ||
        state.loading ||
        state.loadingMore ||
        state.moreFailed) {
      return;
    }
    ref.read(timelineControllerProvider(_key).notifier).loadMore();
  }

  bool get _review => widget.isManager && (_picked ?? widget.initialReview);

  TimelineKey get _key => (
    eventId: widget.event.id,
    status: _review ? TimelineStatus.pending : TimelineStatus.visible,
  );

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _menu(TimelineItem item) async {
    final l = context.l10n;
    final myUid = ref.read(authStateProvider).value?.uid;
    final isMine = myUid != null && myUid == item.authorId;
    final action = await showAppSheet<_MenuChoice>(
      context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isManager && item.status == TimelineStatus.pending)
              _MenuTile(
                key: const Key('timeline-approve'),
                icon: AppIcons.check,
                label: l.timelineApprove,
                onTap: () => Navigator.of(sheet).pop(_MenuChoice.approve),
              ),
            if (widget.isManager && item.status == TimelineStatus.visible)
              _MenuTile(
                key: const Key('timeline-hide'),
                icon: AppIcons.visibilityOff,
                label: l.timelineHide,
                onTap: () => Navigator.of(sheet).pop(_MenuChoice.hide),
              ),
            if (!isMine)
              _MenuTile(
                key: const Key('timeline-report'),
                icon: AppIcons.flag,
                label: l.timelineReport,
                onTap: () => Navigator.of(sheet).pop(_MenuChoice.report),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) {
      return;
    }
    if (action == _MenuChoice.report) {
      showReportSheet(
        context,
        target: ReportTarget.post(
          postId: item.postId,
          authorId: item.authorId,
          authorName: item.authorName,
          thumbUrl: item.imageUrl,
        ),
      );
      return;
    }
    final ok = await ref
        .read(timelineControllerProvider(_key).notifier)
        .moderate(
          item,
          action == _MenuChoice.approve
              ? TimelineAction.approve
              : TimelineAction.hide,
        );
    if (!ok && mounted) {
      _say(l.timelineModerateFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = widget.event;
    final state = ref.watch(timelineControllerProvider(_key));
    final controller = ref.read(timelineControllerProvider(_key).notifier);
    final hiddenUsers = ref.watch(hiddenUsersProvider);
    final visibleItems = state.items
        .where((i) => !hiddenUsers.contains(i.authorId))
        .toList();
    final pending = widget.isManager
        ? ref.watch(timelinePendingCountProvider(e.id)).value ?? 0
        : 0;

    Widget body;
    if (state.loading) {
      body = const _MasonrySkeleton();
    } else if (state.failed) {
      body = ErrorState(
        message: l.authErrorNetwork,
        onRetry: controller.refresh,
      );
    } else if (visibleItems.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Column(
          key: const Key('timeline-empty'),
          children: [
            const AppIcon(AppIcons.image, size: AppIconSize.lg),
            const SizedBox(height: AppSpace.s3),
            Text(
              _review ? l.timelinePendingEmpty : l.timelineEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    } else {
      if (state.cursor != null && !state.loadingMore && !state.moreFailed) {
        // A short page may not fill the screen, so no scroll would ever ask.
        WidgetsBinding.instance.addPostFrameCallback((_) => _nearEnd());
      }
      body = Column(
        children: [
          _Masonry(
            items: visibleItems,
            showPending: _review,
            onOpen: (i) => context.push('/p/${i.postId}'),
            onMenu: _menu,
          ),
          if (state.loadingMore)
            const Padding(
              key: Key('timeline-loading-more'),
              padding: EdgeInsets.all(AppSpace.s3),
              child: Center(child: DotRingLoader(size: LoaderSize.inline)),
            ),
          if (state.moreFailed)
            Center(
              child: TextButton(
                key: const Key('timeline-more-retry'),
                onPressed: controller.loadMore,
                child: Text(l.skillEvidenceLoadMoreRetry),
              ),
            ),
        ],
      );
    }

    return Column(
      key: const Key('timeline-tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: HashtagChip(
            key: const Key('timeline-hashtag'),
            tag: '#${e.hashtag}',
            count: e.postCount,
          ),
        ),
        if (widget.isManager) ...[
          const SizedBox(height: AppSpace.s2),
          Wrap(
            spacing: AppSpace.s2,
            children: [
              AppChip(
                key: const Key('timeline-tab-visible'),
                label: l.timelineVisibleTab,
                selected: !_review,
                onChanged: (_) => setState(() => _picked = false),
              ),
              AppChip(
                key: const Key('timeline-tab-pending'),
                label: '${l.timelinePending} · $pending',
                selected: _review,
                onChanged: (_) => setState(() => _picked = true),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s2),
        body,
      ],
    );
  }
}

enum _MenuChoice { approve, hide, report }

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The sheet paints a background; the tile's ink needs a Material of its own.
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        minTileHeight: 48,
        enabled: onTap != null,
        leading: AppIcon(icon),
        title: Text(label),
        onTap: onTap,
      ),
    );
  }
}

/// Two columns; each photo goes under the shorter one, so the columns end level.
class _Masonry extends StatelessWidget {
  const _Masonry({
    required this.items,
    required this.showPending,
    required this.onOpen,
    required this.onMenu,
  });

  final List<TimelineItem> items;
  final bool showPending;
  final ValueChanged<TimelineItem> onOpen;
  final ValueChanged<TimelineItem> onMenu;

  @override
  Widget build(BuildContext context) {
    final left = <TimelineItem>[];
    final right = <TimelineItem>[];
    var hl = 0.0;
    var hr = 0.0;
    for (final i in items) {
      if (hl <= hr) {
        left.add(i);
        hl += i.aspect;
      } else {
        right.add(i);
        hr += i.aspect;
      }
    }
    Widget column(List<TimelineItem> list) => Expanded(
      child: Column(
        children: [
          for (final i in list) ...[
            _Tile(
              item: i,
              showPending: showPending,
              onOpen: () => onOpen(i),
              onMenu: () => onMenu(i),
            ),
            const SizedBox(height: AppSpace.s2),
          ],
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        column(left),
        const SizedBox(width: AppSpace.s2),
        column(right),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.item,
    required this.showPending,
    required this.onOpen,
    required this.onMenu,
  });

  final TimelineItem item;
  final bool showPending;
  final VoidCallback onOpen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final name = item.isHost
        ? '${item.authorName} · ${l.timelineHostSuffix}'
        : item.authorName;
    return Semantics(
      button: true,
      label: l.timelineItemLabel(name),
      hint: l.timelineMenuHint,
      excludeSemantics: true,
      onTap: onOpen,
      onLongPress: onMenu,
      child: GestureDetector(
        key: Key('timeline-item-${item.postId}'),
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        onLongPress: onMenu,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AspectRatio(
            aspectRatio: 1 / item.aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetworkPhoto(url: item.imageUrl, fit: BoxFit.cover),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.scrim],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.s2,
                        AppSpace.s5,
                        AppSpace.s2,
                        AppSpace.s2,
                      ),
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // Mock `.ph .ov small`: 11px, white at 90%.
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onScrim,
                          fontSize: AppText.xs2,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showPending)
                  Positioned(
                    top: AppSpace.s2,
                    left: AppSpace.s2,
                    child: StatusBadge.custom(
                      label: l.timelinePending,
                      color: AppColors.warning,
                      onColor: AppColors.foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MasonrySkeleton extends StatelessWidget {
  const _MasonrySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget box(double h) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s2),
      child: AppSkeleton.box(height: h, radius: AppRadius.card),
    );
    return AppSkeletonScope(
      child: Row(
        key: const Key('timeline-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: [box(200), box(150)])),
          const SizedBox(width: AppSpace.s2),
          Expanded(child: Column(children: [box(150), box(200)])),
        ],
      ),
    );
  }
}

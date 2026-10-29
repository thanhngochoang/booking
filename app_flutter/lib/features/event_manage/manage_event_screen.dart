// lib/features/event_manage/manage_event_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_social_providers.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/event_create/create_event_screen.dart';
import 'package:photobooking/features/scan/scan_screen.dart';
import 'package:photobooking/features/event_manage/announce_sheet.dart';
import 'package:photobooking/features/event_manage/cancel_event_sheet.dart';
import 'package:photobooking/features/event_manage/entry_days_tab.dart';
import 'package:photobooking/features/event_manage/manage_event_controller.dart';
import 'package:photobooking/features/events/event_links.dart';
import 'package:photobooking/features/explore/event_routes.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// The badge text and colours of an event status (mock `.badge`): "Đang mở"
/// green, "Hết chỗ" amber, "Đã huỷ" red, the rest grey.
({String label, Color color, Color onColor}) eventStatusBadge(
  AppLocalizations l,
  EventStatus s,
) => switch (s) {
  EventStatus.open => (
    label: l.eventStatusOpen,
    color: AppColors.success,
    onColor: AppColors.foregroundInverse,
  ),
  EventStatus.full => (
    label: l.eventStatusFull,
    color: AppColors.warning,
    onColor: AppColors.foreground,
  ),
  EventStatus.cancelled => (
    label: l.eventStatusCancelled,
    color: AppColors.error,
    onColor: AppColors.foregroundInverse,
  ),
  EventStatus.draft => (
    label: l.eventStatusDraft,
    color: AppColors.foregroundSecondary,
    onColor: AppColors.foregroundInverse,
  ),
  EventStatus.closed => (
    label: l.eventStatusClosed,
    color: AppColors.foregroundSecondary,
    onColor: AppColors.foregroundInverse,
  ),
  EventStatus.completed => (
    label: l.eventStatusCompleted,
    color: AppColors.foregroundSecondary,
    onColor: AppColors.foregroundInverse,
  ),
};

/// A status badge for an event.
class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge(this.status, {super.key});
  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final b = eventStatusBadge(context.l10n, status);
    return StatusBadge.custom(
      label: b.label,
      color: b.color,
      onColor: b.onColor,
    );
  }
}

String _hm(DateTime instant) {
  final v = toVn(instant);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(v.hour)}:${two(v.minute)}';
}

/// S12.03: manage one event: numbers, people, check-in, cancel. At
/// `/events/:eventId/manage` (also where the notification for a staff-created
/// event leads: the named photographer answers there, owner decision O1).
class ManageEventScreen extends ConsumerStatefulWidget {
  const ManageEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<ManageEventScreen> createState() => _ManageEventScreenState();
}

class _ManageEventScreenState extends ConsumerState<ManageEventScreen> {
  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _back() => context.canPop() ? context.pop() : context.go('/events/mine');

  Future<void> _share() async {
    await copyEventLink(widget.eventId);
    if (mounted) {
      _say(context.l10n.eventLinkCopied);
    }
  }

  /// S30.07 for this event (`scanPass` checks the ticket in as its
  /// manager; the old in-screen scanner is gone, Task 9).
  void _scan(EventDetail event) =>
      context.push(scanLocation(eventId: event.id));

  /// "Nhắn nhóm": pins an announcement at the top of the group chat.
  Future<void> _announce() async {
    final pinned = await showAnnounceSheet(context, eventId: widget.eventId);
    if (pinned && mounted) {
      _say(context.l10n.manageAnnounceDone);
    }
  }

  Future<void> _cancel(ManageStats stats) async {
    final l = context.l10n;
    final yes = await showCancelEventSheet(
      context,
      tickets: stats.tickets,
      refundVnd: stats.refundVnd,
    );
    if (!yes || !mounted) {
      return;
    }
    final ok = await ref
        .read(manageEventControllerProvider(widget.eventId).notifier)
        .cancelEvent();
    if (mounted) {
      _say(ok ? l.manageCancelDone : l.manageCancelFailed);
    }
  }

  Future<void> _respond({required bool accept}) async {
    final l = context.l10n;
    final ok = await ref
        .read(manageEventControllerProvider(widget.eventId).notifier)
        .respond(accept: accept);
    if (!mounted) {
      return;
    }
    if (!ok) {
      _say(l.manageInviteFailed);
      return;
    }
    _say(accept ? l.manageInviteAccepted : l.manageInviteDeclined);
    if (!accept) {
      _back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final event = ref.watch(eventProvider(widget.eventId));
    final me = ref.watch(authStateProvider).value?.uid;
    return AsyncView<EventDetail?>(
      value: event,
      onRetry: () => ref.invalidate(eventProvider(widget.eventId)),
      isEmpty: (e) => e == null,
      empty: (_) => _frame(
        context,
        body: EmptyState(title: l.manageGone, body: ''),
      ),
      data: (context, e) {
        final detail = e!;
        if (detail.summary.status == EventStatus.draft) {
          final invited =
              detail.hostConsent == HostConsent.pending &&
              detail.summary.hostId == me &&
              detail.createdBy != me;
          if (invited) {
            return _frame(context, body: _invitation(context, detail));
          }
          // My own draft is edited in S12.01; a staff-made draft I accepted
          // as host stays here (read-only until staff publish it, O1).
          // Decision 16: a published draft that waits for its venue stays
          // here with "Địa điểm: chờ đồng ý" (S12.03).
          if (detail.createdBy == me &&
              detail.venueConsent != HostConsent.pending) {
            return EventRouteRedirect('/events/new?draft=${detail.id}');
          }
        }
        // S12.03-entry: an entry event is managed per visit day.
        if (detail.entry case final entry? when detail.isEntry) {
          return _frame(
            context,
            title: context.l10n.s3004_title,
            body: EntryDaysTab(event: entry),
          );
        }
        return _content(context, detail);
      },
    );
  }

  Widget _frame(
    BuildContext context, {
    required Widget body,
    String? title,
    List<Widget>? actions,
    Widget? footer,
  }) {
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.manageEvent,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: IconButton(
              key: const Key('manage-back'),
              tooltip: l.back,
              icon: const AppIcon(AppIcons.back),
              onPressed: _back,
            ),
            title: Text(title ?? l.manageTitle),
            actions: actions,
          ),
          body: body,
          bottomNavigationBar: footer,
        ),
      ),
    );
  }

  // ---- invitation (O1) ----------------------------------------------------

  Widget _invitation(BuildContext context, EventDetail e) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final busy = ref.watch(manageEventControllerProvider(widget.eventId)).busy;
    final until = e.hostConsentExpiresAt;
    final time = until == null
        ? ''
        : '${_hm(until)} ${formatDayMonth(toVn(until))}';
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        _SummaryCard(event: e),
        const SizedBox(height: AppSpace.s4),
        Semantics(
          header: true,
          child: Text(l.manageInviteTitle, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpace.s2),
        Text(l.manageInviteBody(time), style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpace.s4),
        AppButton.primary(
          l.manageInviteAccept,
          key: const Key('manage-accept'),
          loading: busy,
          onPressed: busy ? null : () => _respond(accept: true),
        ),
        const SizedBox(height: AppSpace.s2),
        AppButton.outline(
          l.manageInviteDecline,
          key: const Key('manage-decline'),
          onPressed: busy ? null : () => _respond(accept: false),
        ),
      ],
    );
  }

  // ---- manage -------------------------------------------------------------

  Widget _content(BuildContext context, EventDetail e) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider)();
    final regs = ref.watch(eventRegistrationsProvider(e.id));
    final stats = ManageStats.of(e, regs.value ?? const [], now);
    final cancelled = e.summary.status == EventStatus.cancelled;
    final canCancel =
        !cancelled &&
        e.summary.status != EventStatus.completed &&
        now.isBefore(e.endsAt);
    final scanOpen = manageCanScan(e, now);
    final window = checkinWindowOf(e, now);
    final busy = ref.watch(manageEventControllerProvider(e.id)).busy;
    final free = e.summary.isFree;

    final footer = cancelled
        ? null
        : AppFooterBar(
            child: SizedBox(
              height: controlHeight,
              child: Row(
                children: [
                  Expanded(
                    flex: 40,
                    child: AppButton.outline(
                      l.manageBroadcast,
                      key: const Key('manage-broadcast'),
                      // The group chat exists from the moment the event is published.
                      // Never for a cancelled event (the footer is gone too);
                      // its chat closes 7 days after the cancel (M5).
                      onPressed:
                          e.summary.status == EventStatus.draft ||
                              cancelled ||
                              busy
                          ? null
                          : _announce,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(
                    flex: 60,
                    child: Tooltip(
                      message: switch (window) {
                        CheckinWindow.open => '',
                        CheckinWindow.notYet => l.checkinNotYet,
                        CheckinWindow.closed => l.manageScanClosed,
                      },
                      child: AppButton.primary(
                        l.manageScan,
                        key: const Key('manage-scan'),
                        onPressed: scanOpen && !busy ? () => _scan(e) : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    final people = [
      for (final r in regs.value ?? const <EventRegistration>[])
        if (r.isActive) r,
    ];

    return _frame(
      context,
      actions: [
        PopupMenuButton<String>(
          key: const Key('manage-more'),
          icon: const AppIcon(AppIcons.more),
          onSelected: (v) {
            if (v == 'view') {
              context.push(eventPath(e.id));
            } else {
              _share();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'view', child: Text(l.manageViewPage)),
            PopupMenuItem(value: 'share', child: Text(l.manageShare)),
          ],
        ),
      ],
      footer: footer,
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          _SummaryCard(event: e),
          if (venueStatusLine(l, e) case final venue?) ...[
            const SizedBox(height: AppSpace.s2),
            Text(
              venue,
              key: const Key('manage-venue-status'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (cancelled) ...[
            const SizedBox(height: AppSpace.s3),
            _CancelledStrip(text: l.eventCancelled),
          ],
          const SizedBox(height: AppSpace.s3),
          StatTileRow(
            tiles: [
              StatTile(
                key: const Key('manage-kpi-registered'),
                value: '${stats.registered}/${stats.capacity}',
                label: l.manageRegistered,
              ),
              StatTile(
                key: const Key('manage-kpi-revenue'),
                value: free
                    ? l.manageNoMoney
                    : formatMoney(stats.revenueVnd, short: true),
                label: l.manageRevenue,
              ),
              StatTile(
                key: const Key('manage-kpi-days'),
                value: '${stats.daysLeft}',
                label: l.manageDaysLeft,
              ),
            ],
          ),
          if (e.summary.status != EventStatus.draft) ...[
            const SizedBox(height: AppSpace.s3),
            _PendingPostsRow(eventId: e.id),
          ],
          const SizedBox(height: AppSpace.s3),
          // Mock S12.03 `.sec`: "Người tham gia" with a "Check‑in" link that
          // opens the same scanner as the footer button, under the same window.
          _ParticipantsHeader(
            title: l.manageParticipants,
            linkLabel: cancelled ? null : l.manageCheckinLink,
            onLink: scanOpen && !busy ? () => _scan(e) : null,
          ),
          AsyncView<List<EventRegistration>>(
            value: regs,
            skeleton: (_) => Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  AppSkeleton.box(height: 64, radius: AppRadius.card),
                  const SizedBox(height: AppSpace.s2),
                ],
              ],
            ),
            onRetry: () => ref.invalidate(eventRegistrationsProvider(e.id)),
            loaderSize: LoaderSize.inline,
            isEmpty: (_) => people.isEmpty,
            empty: (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
              child: Column(
                children: [
                  Text(
                    l.manageEmpty,
                    key: const Key('manage-empty'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (!cancelled) ...[
                    const SizedBox(height: AppSpace.s2),
                    AppButton.outline(
                      l.manageShare,
                      key: const Key('manage-empty-share'),
                      size: AppButtonSize.small,
                      icon: const AppIcon(AppIcons.share, size: 18),
                      onPressed: _share,
                    ),
                  ],
                ],
              ),
            ),
            data: (context, _) => Column(
              children: [
                for (final r in people) ...[
                  _ParticipantRow(eventId: e.id, registration: r),
                  const SizedBox(height: AppSpace.s2),
                ],
              ],
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: AppSpace.s2),
            Center(
              child: TextButton(
                key: const Key('manage-cancel'),
                onPressed: busy ? null : () => _cancel(stats),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  minimumSize: const Size(48, 48),
                ),
                // Nothing to refund on a free event: "Huỷ sự kiện" alone.
                child: Text(free ? l.manageCancelConfirm : l.manageCancel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Bài chờ duyệt · n": opens the timeline in review mode.
class _PendingPostsRow extends ConsumerWidget {
  const _PendingPostsRow({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final n = ref.watch(timelinePendingCountProvider(eventId)).value ?? 0;
    return Semantics(
      button: true,
      label: '${l.managePending}, $n',
      excludeSemantics: true,
      onTap: () => context.push('/e/$eventId/timeline?review=1'),
      child: Material(
        key: const Key('manage-pending-row'),
        color: dark ? AppColorsDark.glass : AppColors.glass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push('/e/$eventId/timeline?review=1'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpace.s12 + AppSpace.s2,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
              child: Row(
                children: [
                  const AppIcon(AppIcons.image),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Text(
                      l.managePending,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '$n',
                    key: const Key('manage-pending-count'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
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

/// The date block, title, time and place, and the status (mock S12.03 card).
/// "Người tham gia" and, at its right, the "Check‑in" link (S12.03).
class _ParticipantsHeader extends StatelessWidget {
  const _ParticipantsHeader({
    required this.title,
    required this.linkLabel,
    required this.onLink,
  });

  final String title;

  /// Null hides the link (a cancelled event).
  final String? linkLabel;

  /// Null shows the link disabled (outside the check-in window, or a scan
  /// already open), exactly when the footer button is.
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = linkLabel;
    // The list already pads 16dp: no extra inset (mock `.sec`).
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (label != null)
          TextButton(
            key: const Key('manage-checkin-link'),
            onPressed: onLink,
            style: TextButton.styleFrom(
              minimumSize: const Size(AppSpace.s12, AppSpace.s12),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
              textStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(label),
          ),
      ],
    );
  }
}

/// S12.03: "Địa điểm: {consent} · phí quản lý {fee}" of an event at a
/// managed spot whose manager was asked (the host's own spot asks no one);
/// without a fee the amount is left out (never "0₫"). Null otherwise.
String? venueStatusLine(AppLocalizations l, EventDetail e) {
  if (e.venue?.kind != VenueKind.managedSpot ||
      e.venueConsent == HostConsent.notRequired) {
    return null;
  }
  final status = l.s1203_venueConsent(e.venueConsent.code);
  final fee = e.venueFeePerGuest;
  return e.venueConsent == HostConsent.accepted && fee > 0
      ? l.s1203_venueStatus(status, formatMoney(fee))
      : l.s1203_venueStatusNoFee(status);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.event});
  final EventDetail event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final s = event.summary;
    final when = s.hasSchedule ? '${_hm(s.startsAt)}–${_hm(event.endsAt)}' : '';
    final line = [
      if (when.isNotEmpty) when,
      if (s.locationName != null) s.locationName!,
    ].join(' · ');
    return DecoratedBox(
      key: const Key('manage-summary'),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          children: [
            if (s.hasSchedule) ...[
              DateBlock(day: s.startsAt),
              const SizedBox(width: AppSpace.s3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (line.isNotEmpty)
                    Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            EventStatusBadge(s.status),
          ],
        ),
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
        key: const Key('manage-cancelled-strip'),
        decoration: BoxDecoration(
          color: error.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: Text(text, style: TextStyle(color: error)),
        ),
      ),
    );
  }
}

/// One attendee: avatar, name, "{q} vé · {code}" (paid tickets only), the
/// state, and the call/Zalo buttons of a paid ticket's phone.
class _ParticipantRow extends ConsumerWidget {
  const _ParticipantRow({required this.eventId, required this.registration});

  final String eventId;
  final EventRegistration registration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final r = registration;
    final paidTicket = r.status == RegistrationStatus.paid && r.amount > 0;
    final contact = paidTicket
        ? ref
              .watch(
                registrationContactProvider((
                  eventId: eventId,
                  registrationId: r.id,
                )),
              )
              .value
        : null;
    final sub = paidTicket && r.ticketCode.isNotEmpty
        ? l.manageTicketCode(r.quantity, r.ticketCode)
        : l.manageTicketQty(r.quantity);
    final badge = r.isCheckedIn
        ? (l.manageCheckedIn, AppColors.success, AppColors.foregroundInverse)
        : r.status == RegistrationStatus.held
        ? (l.manageUnpaid, AppColors.warning, AppColors.foreground)
        : paidTicket
        ? (l.managePaid, AppColors.success, AppColors.foregroundInverse)
        : (l.manageRegistered, AppColors.success, AppColors.foregroundInverse);
    return DecoratedBox(
      key: Key('manage-row-${r.id}'),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          children: [
            AppAvatar(
              url: r.userAvatarUrl,
              name: r.userName,
              size: AppAvatarSize.sm,
              decorative: true,
            ),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    sub,
                    key: Key('manage-row-sub-${r.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge.custom(
                  label: badge.$1,
                  color: badge.$2,
                  onColor: badge.$3,
                ),
                if (contact != null)
                  CustomerContactDial(
                    key: Key('manage-dial-${r.id}'),
                    copy: contact,
                    style: ContactDialStyle.icon,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

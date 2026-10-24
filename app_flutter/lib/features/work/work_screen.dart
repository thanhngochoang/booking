// S06.01: the photographer's work tab: today's shoot, new requests with a
// live deadline, and the month's numbers; the last segment "Tuyển thợ" is
// S27.01 (Decision 20 of #151).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/features/addons/addon_format.dart';
import 'package:photobooking/features/booking/booking_errors.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';
import 'package:photobooking/features/booking/decline_sheet.dart';
import 'package:photobooking/features/event_manage/my_events_section.dart';
import 'package:photobooking/features/instant_work/live_shutter_card.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:photobooking/features/recruit/recruit_list_screen.dart';
import 'package:photobooking/features/recruit/recruit_list_view.dart';
import 'package:photobooking/features/studio/assign_sheet.dart';
import 'package:photobooking/features/studio/decline_change_sheet.dart';
import 'package:photobooking/features/studio/return_job_sheet.dart';
import 'package:photobooking/features/work/studio_work_cards.dart';
import 'package:photobooking/features/work/work_dashboard.dart';
import 'package:photobooking/features/work/work_empty.dart';

/// The segments of S06.01 (`SegmentedTabs`, Decision 20 of #151): the jobs
/// plan (#139) inserts its two between them.
enum WorkSegment { today, recruit }

/// Tab root of `/bookings` for photographers.
class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key, this.showEvents = false});

  /// "Sự kiện của tôi" (Decision 9): the photographer's next events, drafts
  /// tagged "Nháp", under the month's numbers.
  final bool showEvents;

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
  WorkSegment _segment = WorkSegment.today;

  /// The request being accepted; every Nhận/Từ chối waits for it.
  String? _accepting;

  /// Customer names seen on the cards, kept for the expiry toast after the
  /// card is gone (Decision 11).
  final _names = <String, String>{};

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Plan 4d provides the destination behind the chat flag.
  void _onMessage(Booking b) {
    final chatId = b.chatId;
    if (chatId != null) context.push('/chat/$chatId');
  }

  void _onDirections(Booking b) =>
      ref.read(externalLauncherProvider).open(directionsUri(b));

  /// Decision 12: accept, then open S05.02 (plan 4d changes it to the chat).
  Future<void> _accept(Booking b) async {
    if (_accepting != null) return;
    setState(() => _accepting = b.id);
    final l10n = context.l10n;
    try {
      await ref
          .read(bookingRepositoryProvider)
          .transitionBooking(
            bookingId: b.id,
            action: BookingAction.accept.code,
          );
      if (!mounted) return;
      setState(() => _accepting = null);
      // Accepting is the reason to ask (S17.03); the chat opens after it.
      await maybeAskForNotifications(context, ref, const PhotographerPrimer());
      if (!mounted) return;
      final chatId = b.chatId;
      if (chatId != null) {
        await context.push('/chat/$chatId');
      } else {
        await context.push('/b/${b.id}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _accepting = null);
      _say(bookingErrorText(e, l10n));
    }
  }

  Future<void> _decline(Booking b, String name) async {
    final l10n = context.l10n;
    final declined = await showDeclineSheet(
      context,
      booking: b,
      customerName: name,
    );
    if (declined == true && mounted) _say(l10n.declineDoneToast(name));
  }

  /// Decision 11: a request that was `requested` in the previous emission
  /// and arrives `expired`.
  void _onBookings(
    AsyncValue<List<Booking>>? prev,
    AsyncValue<List<Booking>> next,
  ) {
    final before = prev?.value;
    final after = next.value;
    if (before == null || after == null) return;
    final waiting = {
      for (final b in before)
        if (b.status == BookingStatus.requested) b.id,
    };
    for (final b in after) {
      if (b.status == BookingStatus.expired && waiting.contains(b.id)) {
        _say(context.l10n.workRequestExpired(_names[b.id] ?? ''));
      }
    }
  }

  /// The customer's name: the contact copy first (Decision 4), else the
  /// public profile.
  String _customerName(Booking b) {
    final copyName = ref.watch(bookingContactProvider(b.id)).value?.name;
    final name = copyName != null && copyName.isNotEmpty
        ? copyName
        : ref.watch(partyProfileProvider(b.customerId)).value?.displayName ??
              '';
    if (name.isNotEmpty) _names[b.id] = name;
    return name;
  }

  String? _customerAvatar(Booking b) =>
      ref.watch(partyProfileProvider(b.customerId)).value?.avatarUrl;

  /// The public name of the studio that booked [b]; '' while it loads.
  String _studioName(Booking b) =>
      ref.watch(partyProfileProvider(b.photographerId)).value?.displayName ??
      '';

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      BookingCard.skeleton(),
      const SizedBox(height: AppSpace.s3),
      BookingCard.skeleton(),
      const SizedBox(height: AppSpace.s4),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.s2),
              Expanded(
                child: StatTile.skeleton(
                  key: ValueKey('stat_tile_skeleton_$i'),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    ref.listen(myBookingsProvider(BookingRole.photographer), _onBookings);
    final dashboard = ref.watch(workDashboardProvider);
    final now =
        ref.watch(nowTickerProvider(workTick)).value ??
        ref.read(clockProvider)();
    final features = ref.watch(bookingFeaturesProvider);

    final recruit = _segment == WorkSegment.recruit;

    return ScreenCode(
      ScreenCodes.work,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          titleTextStyle: tabRootTitleStyle(context),
          // Mock: small "Công việc" over today's date (S27.01: over "Tuyển
          // thợ").
          title: recruit
              ? const RecruitBarTitle()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.workTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dark
                            ? AppColorsDark.foregroundSecondary
                            : AppColors.foregroundSecondary,
                      ),
                    ),
                    Text(_dateTitle(context, now)),
                  ],
                ),
          actions: [
            if (recruit)
              const RecruitStudioPostsAction()
            else
              IconButton(
                key: const Key('open-calendar'),
                tooltip: l10n.myCalendarTitle,
                icon: const AppIcon(AppIcons.calendarCheck),
                onPressed: () => context.push('/work/calendar'),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s1,
                AppSpace.s4,
                AppSpace.s2,
              ),
              child: SegmentedTabs<WorkSegment>(
                key: const Key('work-segments'),
                options: [
                  SegmentOption(
                    value: WorkSegment.today,
                    label: l10n.workToday,
                  ),
                  SegmentOption(
                    value: WorkSegment.recruit,
                    label: l10n.recruitTab,
                  ),
                ],
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
            ),
            Expanded(
              child: recruit
                  ? const RecruitListView()
                  : _today(context, dashboard, features, now),
            ),
          ],
        ),
      ),
    );
  }

  Widget _today(
    BuildContext context,
    AsyncValue<WorkDashboard> dashboard,
    BookingFeatures features,
    DateTime now,
  ) => AsyncView<WorkDashboard>(
    value: dashboard,
    skeleton: (_) => _skeleton(),
    onRetry: () => ref.invalidate(myBookingsProvider(BookingRole.photographer)),
    isEmpty: (d) => d.isEmpty,
    // Scrolls, so the entry under S06.02 fits 320 dp at 1.3× text.
    empty: (_) => ListView(
      children: [
        const _InstantEntry(),
        const SizedBox(height: 480, child: WorkEmptyState()),
        const _SpotSchedulesEntry(),
        if (widget.showEvents) const MyEventsSection(),
        const SizedBox(height: AppSpace.s4),
      ],
    ),
    data: (context, d) => _dashboard(context, d, features, now),
  );

  /// "Thứ 5, 08/10" on the Vietnamese calendar.
  String _dateTitle(BuildContext context, DateTime now) {
    final l10n = context.l10n;
    final day = toVn(now);
    final date = formatDayMonth(day);
    return day.weekday == DateTime.sunday
        ? l10n.workDateTitleSunday(date)
        : l10n.workDateTitle(day.weekday + 1, date);
  }

  Widget _dashboard(
    BuildContext context,
    WorkDashboard d,
    BookingFeatures features,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final today = d.today;
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.s4);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      children: [
        // S06.01-instant: Live Shutter above "Hôm nay".
        const _InstantEntry(),
        if (today != null) ...[
          SectionHeader(title: l10n.workToday),
          Padding(padding: gutter, child: _todayCard(context, today, features)),
          const SizedBox(height: AppSpace.s2),
        ],
        // S06.01-studio: the studio's accepted bookings to staff.
        for (final b in d.studioJobs) ...[
          Padding(
            padding: gutter,
            child: StudioJobCard(
              booking: b,
              customerName: _customerName(b),
              thumbUrl: _customerAvatar(b),
              now: now,
              onAssign: () => showAssignSheet(context, b.id),
              onDeclineChange: () => showDeclineChangeSheet(context, b),
            ),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        // S06.01-member: shoots a studio gave me.
        for (final (b, studio) in [
          for (final b in d.assignedJobs) (b, _studioName(b)),
        ]) ...[
          Padding(
            padding: gutter,
            child: AssignedJobCard(
              booking: b,
              customerName: _customerName(b),
              thumbUrl: _customerAvatar(b),
              studioName: studio,
              onReturn: () =>
                  showReturnJobSheet(context, booking: b, studioName: studio),
            ),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        if (d.toDeliver.isNotEmpty) ...[
          Row(
            key: const Key('to-deliver-section'),
            children: [
              Expanded(child: SectionHeader(title: l10n.workToDeliver)),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpace.s4),
                child: Text(
                  '${d.toDeliver.length}',
                  key: const Key('work-to-deliver-count'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          for (final (b, name) in [
            for (final b in d.toDeliver) (b, _customerName(b)),
          ]) ...[
            Padding(
              padding: gutter,
              child: _ToDeliverCard(
                key: Key('to-deliver-${b.id}'),
                booking: b,
                name: name,
                avatarUrl: _customerAvatar(b),
                onOpen: () => context.push('/b/${b.id}'),
              ),
            ),
            const SizedBox(height: AppSpace.s3),
          ],
          const SizedBox(height: AppSpace.s2),
        ],
        Row(
          children: [
            Expanded(child: SectionHeader(title: l10n.workRequests)),
            if (d.requests.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpace.s4),
                child: Text(
                  '${d.requests.length}',
                  key: const Key('work-requests-count'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
          ],
        ),
        if (d.requests.isEmpty)
          Padding(
            padding: gutter,
            child: Text(
              l10n.workNoRequests,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final (b, name) in [
            for (final b in d.requests) (b, _customerName(b)),
          ]) ...[
            Padding(
              padding: gutter,
              child: _RequestCard(
                key: ValueKey(b.id),
                booking: b,
                name: name,
                avatarUrl: _customerAvatar(b),
                accepting: _accepting == b.id,
                busy: _accepting != null,
                onAccept: () => _accept(b),
                onDecline: () => _decline(b, name),
                onOpen: () => context.push('/b/${b.id}'),
              ),
            ),
            const SizedBox(height: AppSpace.s3),
          ],
        const SizedBox(height: AppSpace.s2),
        Padding(
          padding: gutter,
          child: StatTileRow(
            tiles: [
              StatTile(
                value: formatMoney(d.monthRevenueVnd, short: true),
                label: l10n.workMonth,
              ),
              StatTile(
                value: formatMoney(d.heldVnd, short: true, decimals: 2),
                label: l10n.workHeld,
                onTap: () => context.push('/work/earnings'),
              ),
              StatTile(value: '${d.upcomingCount}', label: l10n.workUpcoming),
            ],
          ),
        ),
        // S29.03's entry (spec §8: one line under the numbers, no frame).
        const SizedBox(height: AppSpace.s2),
        const _SpotSchedulesEntry(),
        if (widget.showEvents) ...[
          const SizedBox(height: AppSpace.s2),
          const MyEventsSection(),
        ],
        const SizedBox(height: AppSpace.s4),
      ],
    );
  }

  /// Today's shoot: the only highlighted card on the screen (mock).
  Widget _todayCard(BuildContext context, Booking b, BookingFeatures features) {
    final l10n = context.l10n;
    final message = features.chat && b.chatId != null;
    final uid = ref.watch(authStateProvider).value?.uid;
    // A studio's booking assigned to me (Decision 18): name the studio.
    final studio = uid == null || b.photographerId == uid
        ? null
        : ref.watch(partyProfileProvider(b.photographerId)).value?.displayName;
    return BookingCard(
      data: bookingSummaryFor(
        b,
        name: _customerName(b),
        thumbUrl: _customerAvatar(b),
        tag: studio == null || studio.isEmpty
            ? null
            : l10n.workAssignedBy(studio),
      ),
      highlight: true,
      onTap: () => context.push('/b/${b.id}'),
      actions: Row(
        children: [
          if (message) ...[
            Expanded(
              child: AppButton.outline(
                l10n.workMessage,
                size: AppButtonSize.small,
                onPressed: () => _onMessage(b),
              ),
            ),
            const SizedBox(width: AppSpace.s2),
          ],
          Expanded(
            child: AppButton.outline(
              l10n.workDirections,
              size: AppButtonSize.small,
              icon: const AppIcon(AppIcons.nearMe, size: 18),
              onPressed: () => _onDirections(b),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Live Shutter card with the gutter, or nothing while Chụp ngay is off.
class _InstantEntry extends ConsumerWidget {
  const _InstantEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(instantEnabledProvider)) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s2,
        AppSpace.s4,
        AppSpace.s2,
      ),
      child: LiveShutterCard(),
    );
  }
}

/// "Lịch tại điểm · {n} đang mở" (mock S06.01 caption): opens S29.03
/// (`/me/spot-schedules`). Without an open schedule, or while the list
/// loads, the plain line.
class _SpotSchedulesEntry extends ConsumerWidget {
  const _SpotSchedulesEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final secondary = theme.brightness == Brightness.dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final uid = ref.watch(authStateProvider).value?.uid;

    Widget row(String title, String? sub) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const Key('open-spot-schedules'),
          onTap: () => context.push('/me/spot-schedules'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
            child: Row(
              children: [
                AppIcon(AppIcons.place, size: 20, color: secondary),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (sub != null)
                        Text(
                          sub,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                        ),
                    ],
                  ),
                ),
                AppIcon(AppIcons.chevron, size: 18, color: secondary),
              ],
            ),
          ),
        ),
      ),
    );

    final plain = row(l10n.workSpotSchedules, l10n.workSpotSchedulesSub);
    if (uid == null) return plain;
    final today = vnDateKey(ref.watch(clockProvider)());
    return AsyncView<List<SpotSchedule>>(
      value: ref.watch(mySpotSchedulesProvider(uid)),
      skeleton: (_) => row(l10n.workSpotSchedules, null),
      error: (_, _, _) => plain,
      data: (context, list) {
        final open = openScheduleCount(list, today);
        return open == 0 ? plain : row(l10n.workSpotSchedulesOpen(open), null);
      },
    );
  }
}

/// One new request (mock S06.01): customer, package, when and where, price,
/// the note and the payment, contact, and the two answers.
class _RequestCard extends ConsumerWidget {
  const _RequestCard({
    super.key,
    required this.booking,
    required this.name,
    required this.avatarUrl,
    required this.accepting,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
  });

  final Booking booking;
  final String name;
  final String? avatarUrl;
  final bool accepting;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final b = booking;
    final day = parseDayKey(b.day);
    final when = '${day == null ? b.day : formatDay(day)} ${b.start}';
    final deposit = l10n.workDepositPaid(formatMoney(b.deposit, short: true));
    final note = b.note?.trim();
    final copy = ref.watch(bookingContactProvider(b.id)).value;
    final hasDial = copyChannels(copy).isNotEmpty;

    // Same surface as BookingCard (mock `.card`).
    final radius = BorderRadius.circular(AppRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          onTap: onOpen,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      url: avatarUrl,
                      name: name,
                      size: AppAvatarSize.sm,
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.workRequestMeta(
                              b.serviceSnapshot.name,
                              when,
                              b.place.name,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Text(
                      formatMoney(b.totalVnd, short: true),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (b.addons.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    addonsSummary(l10n, b.addons),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.s2),
                Text(
                  note == null || note.isEmpty
                      ? deposit
                      : l10n.workRequestNote(note, deposit),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpace.s2),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outline(
                        l10n.workDecline,
                        size: AppButtonSize.small,
                        onPressed: busy ? null : onDecline,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(child: _acceptButton(context, ref)),
                    // Last in the row: the dial's tray opens towards the
                    // start.
                    if (hasDial) ...[
                      const SizedBox(width: AppSpace.s2),
                      CustomerContactDial(
                        copy: copy,
                        style: ContactDialStyle.icon,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Nhận · còn 22 giờ", ticking through core's [CountdownText] (every
  /// minute, every second in the last hour).
  Widget _acceptButton(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final deadline = booking.acceptDeadline;
    // A small primary per card is allowed (like PhotographerCard's "Đặt").
    Widget button(String? time) => AppButton.primary(
      time == null ? l10n.workAccept : l10n.workAcceptIn(time),
      size: AppButtonSize.small,
      loading: accepting,
      onPressed: busy || (deadline != null && time == null) ? null : onAccept,
    );
    if (deadline == null) return button(null);
    return CountdownText(
      deadline: deadline,
      now: ref.read(clockProvider),
      builder: (_, left) => button(countdownLabel(left, l10n)),
    );
  }
}

class _ToDeliverCard extends StatelessWidget {
  const _ToDeliverCard({
    super.key,
    required this.booking,
    required this.name,
    required this.avatarUrl,
    required this.onOpen,
  });

  final Booking booking;
  final String name;
  final String? avatarUrl;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    final b = booking;
    final day = parseDayKey(b.day);
    final dayStr = day == null ? b.day : formatDay(day);

    String badgeLabel;
    Color badgeColor;
    String subtitle;

    if (b.status == BookingStatus.revisionRequested) {
      final round = b.deliveryRound > 0 ? b.deliveryRound : 1;
      badgeLabel = 'Vòng $round';
      badgeColor = AppColors.warning;
      subtitle = l10n.workToDeliverRevision(round);
    } else if (b.status == BookingStatus.delivered &&
        b.extraRound?.status == 'pending') {
      badgeLabel = 'Xin thêm';
      badgeColor = AppColors.info;
      subtitle = l10n.workToDeliverExtra;
    } else {
      badgeLabel = 'Đã chụp';
      badgeColor = AppColors.success;
      subtitle = l10n.workToDeliverShot(dayStr);
    }

    final radius = BorderRadius.circular(AppRadius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          onTap: onOpen,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Row(
              children: [
                AppAvatar(
                  url: avatarUrl,
                  name: name,
                  size: AppAvatarSize.sm,
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.s1),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                const AppIcon(AppIcons.chevron, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


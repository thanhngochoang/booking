// S06.01: the photographer's work tab: today's shoot, new requests with a
// live deadline, and the month's numbers.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/features/booking/booking_errors.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';
import 'package:photobooking/features/booking/decline_sheet.dart';
import 'package:photobooking/features/work/work_dashboard.dart';
import 'package:photobooking/features/work/work_empty.dart';

/// Tab root of `/bookings` for photographers.
class WorkScreen extends ConsumerStatefulWidget {
  const WorkScreen({super.key, this.showEvents = false});

  /// "Sự kiện của tôi" (Decision 9): off until the photographer's events
  /// (S12.03) exist.
  final bool showEvents;

  @override
  ConsumerState<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends ConsumerState<WorkScreen> {
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
      await context.push('/b/${b.id}');
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

    return ScreenCode(
      ScreenCodes.work,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          titleTextStyle: tabRootTitleStyle(context),
          // Mock: small "Công việc" over today's date.
          title: Column(
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
            IconButton(
              key: const Key('open-calendar'),
              tooltip: l10n.myCalendarTitle,
              icon: const Icon(Icons.event_available_outlined),
              onPressed: () => context.push('/work/calendar'),
            ),
          ],
        ),
        body: AsyncView<WorkDashboard>(
          value: dashboard,
          skeleton: (_) => _skeleton(),
          onRetry: () =>
              ref.invalidate(myBookingsProvider(BookingRole.photographer)),
          isEmpty: (d) => d.isEmpty,
          empty: (_) => const WorkEmptyState(),
          data: (context, d) => _dashboard(context, d, features),
        ),
      ),
    );
  }

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
  ) {
    final l10n = context.l10n;
    final today = d.today;
    const gutter = EdgeInsets.symmetric(horizontal: AppSpace.s4);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      children: [
        if (today != null) ...[
          SectionHeader(title: l10n.workToday),
          Padding(padding: gutter, child: _todayCard(context, today, features)),
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
              // Tapping does nothing until S06.05 exists (no dead route).
              StatTile(
                value: formatMoney(d.heldVnd, short: true),
                label: l10n.workHeld,
              ),
              StatTile(value: '${d.upcomingCount}', label: l10n.workUpcoming),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s4),
      ],
    );
  }

  /// Today's shoot: the only highlighted card on the screen (mock).
  Widget _todayCard(BuildContext context, Booking b, BookingFeatures features) {
    final l10n = context.l10n;
    final message = features.chat && b.chatId != null;
    return BookingCard(
      data: bookingSummaryFor(
        b,
        name: _customerName(b),
        thumbUrl: _customerAvatar(b),
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
              icon: const Icon(Icons.near_me_outlined, size: 18),
              onPressed: () => _onDirections(b),
            ),
          ),
        ],
      ),
    );
  }
}

/// One new request (mock S06.01): customer, package, when and where, price,
/// the note and the deposit, contact, and the two answers.
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
                      formatMoney(b.serviceSnapshot.price, short: true),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
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

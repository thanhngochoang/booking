// S05.01: the customer's bookings, grouped Sắp tới / Đang chờ / Đã xong.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';

/// Tab root of `/bookings` for customers.
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key, this.showTickets = false});

  /// The top level "Buổi chụp | Vé sự kiện" (Decision 8): off until event
  /// tickets (S11.04) exist.
  final bool showTickets;

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  static const _tick = Duration(minutes: 1);

  BookingTab _tab = BookingTab.upcoming;

  void _open(Booking b) => context.push('/b/${b.id}');

  /// Plan 4e provides the destination behind the review flag.
  void _onReview(Booking b) => context.push('/b/${b.id}/review');

  /// Plan 4d provides the destination behind the chat flag.
  void _onMessage(Booking b) {
    final chatId = b.chatId;
    if (chatId != null) context.push('/chat/$chatId');
  }

  void _onDirections(Booking b) =>
      ref.read(externalLauncherProvider).open(directionsUri(b));

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(height: AppSpace.s3),
        BookingCard.skeleton(),
      ],
    ],
  );

  Widget _empty(BuildContext context) {
    final l10n = context.l10n;
    return switch (_tab) {
      BookingTab.upcoming => EmptyState(
        title: l10n.bookingsEmptyUpcoming,
        body: l10n.bookingsEmptyUpcomingBody,
        actionLabel: l10n.bookingsFindPhotographer,
        onAction: () => context.go('/action'),
      ),
      BookingTab.pending => EmptyState(
        title: l10n.bookingsEmptyPending,
        body: l10n.bookingsEmptyPendingBody,
      ),
      BookingTab.history => EmptyState(
        title: l10n.bookingsEmptyDone,
        body: l10n.bookingsEmptyDoneBody,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final features = ref.watch(bookingFeaturesProvider);
    final now =
        ref.watch(nowTickerProvider(_tick)).value ?? ref.read(clockProvider)();
    final bookings = ref.watch(myBookingsProvider(BookingRole.customer));

    return ScreenCode(
      ScreenCodes.bookings,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: false,
          titleTextStyle: tabRootTitleStyle(context),
          title: Text(l10n.bookingsTitle),
          actions: [
            if (features.chat)
              IconButton(
                key: const Key('bookings-chats'),
                tooltip: l10n.bookingsChats,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () => context.push('/chats'),
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s4,
                AppSpace.s2,
                AppSpace.s4,
                0,
              ),
              child: SegmentedTabs<BookingTab>(
                options: [
                  SegmentOption(
                    value: BookingTab.upcoming,
                    label: l10n.bookingsUpcoming,
                  ),
                  SegmentOption(
                    value: BookingTab.pending,
                    label: l10n.bookingsPending,
                  ),
                  SegmentOption(
                    value: BookingTab.history,
                    label: l10n.bookingsDone,
                  ),
                ],
                value: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
            Expanded(
              child: AsyncView<List<Booking>>(
                value: bookings,
                skeleton: (_) => _skeleton(),
                onRetry: () =>
                    ref.invalidate(myBookingsProvider(BookingRole.customer)),
                isEmpty: (all) => bucket(all, _tab).isEmpty,
                empty: _empty,
                data: (_, all) => _list(bucket(all, _tab), now, features),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Booking> list, DateTime now, BookingFeatures features) {
    return ListView.separated(
      key: PageStorageKey(_tab),
      padding: const EdgeInsets.all(AppSpace.s4),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s3),
      itemBuilder: (context, i) {
        final b = list[i];
        return _BookingTile(
          key: ValueKey(b.id),
          booking: b,
          actions: _cardActions(context, b, nearest: i == 0, now, features),
          onTap: () => _open(b),
        );
      },
    );
  }

  /// The row under a card (mock): Chỉ đường + Nhắn tin on the nearest
  /// upcoming card, Đánh giá on a completed one.
  Widget? _cardActions(
    BuildContext context,
    Booking b,
    DateTime now,
    BookingFeatures features, {
    required bool nearest,
  }) {
    final l10n = context.l10n;
    final buttons = <Widget>[];
    if (_tab == BookingTab.upcoming && nearest) {
      final actions = detailActions(b, BookingRole.customer, now, features);
      if (actions.contains(DetailAction.directions)) {
        buttons.add(
          AppButton.outline(
            l10n.bookingsDirections,
            size: AppButtonSize.small,
            icon: const Icon(Icons.near_me_outlined, size: 18),
            onPressed: () => _onDirections(b),
          ),
        );
      }
      if (actions.contains(DetailAction.message)) {
        buttons.add(
          AppButton.outline(
            l10n.bookingsMessage,
            size: AppButtonSize.small,
            onPressed: () => _onMessage(b),
          ),
        );
      }
    }
    if (_tab == BookingTab.history &&
        b.status == BookingStatus.completed &&
        features.review) {
      buttons.add(
        AppButton.outline(
          l10n.bookingsReview,
          size: AppButtonSize.small,
          onPressed: () => _onReview(b),
        ),
      );
    }
    if (buttons.isEmpty) return null;
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.s2),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}

/// One card; its photographer's name and avatar load per card, and the
/// slot shows the card's skeleton until they do.
class _BookingTile extends ConsumerWidget {
  const _BookingTile({
    super.key,
    required this.booking,
    required this.actions,
    required this.onTap,
  });

  final Booking booking;
  final Widget? actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      photographerProfileProvider(booking.photographerId),
    );
    if (profile.isLoading && !profile.hasValue) return BookingCard.skeleton();
    final summary = profile.value?.summary;
    return BookingCard(
      data: bookingSummaryFor(
        booking,
        name: summary?.displayName ?? '',
        thumbUrl: summary?.avatarUrl,
      ),
      actions: actions,
      onTap: onTap,
    );
  }
}

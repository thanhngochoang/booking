// S05.02: one screen for every state of a booking, for both parties.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/safety/safety_providers.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/data/payments/payment_history.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/booking/ask_shot_sheet.dart';
import 'package:photobooking/features/booking/booking_errors.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';
import 'package:photobooking/features/booking/cancel_sheet.dart';
import 'package:photobooking/features/booking/decline_sheet.dart';
import 'package:photobooking/features/booking/widgets/pass_card.dart';
import 'package:photobooking/features/entry/entry_rules.dart';
import 'package:photobooking/features/booking/widgets/booking_addons_block.dart';
import 'package:photobooking/features/booking/widgets/studio_assignee_block.dart';
import 'package:photobooking/features/booking/widgets/studio_offer_line.dart';
import 'package:photobooking/features/contact/contact_action.dart';
import 'package:photobooking/features/delivery/delivery_review_screen.dart';
import 'package:photobooking/features/disputes/dispute_entry.dart';
import 'package:photobooking/features/delivery/submit_delivery_sheet.dart';
import 'package:photobooking/features/studio/assign_sheet.dart';
import 'package:photobooking/features/studio/change_request_sheet.dart';
import 'package:photobooking/features/studio/return_job_sheet.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';
import 'package:photobooking/features/payments/refund_account_sheet.dart';
import 'package:photobooking/features/review/review_screen.dart';

/// A sheet S05.02 opens over itself after its first frame (deep links
/// `/b/:id/cancel`, `/b/:id/decline`, `/b/:id/dispute`).
enum DetailSheet { cancel, decline, dispute }

/// `/b/:id`, `/b/:id/cancel`, `/b/:id/decline`, `/b/:id/dispute`,
/// `/b/:id/review`, `/b/:id/delivery`
List<RouteBase> bookingDetailRoutes() => [
  GoRoute(
    path: '/b/:id',
    builder: (_, s) => BookingDetailScreen(
      bookingId: s.pathParameters['id']!,
      justPaid: s.uri.queryParameters['paid'] == '1',
    ),
  ),
  GoRoute(
    path: '/b/:id/cancel',
    builder: (_, s) => BookingDetailScreen(
      bookingId: s.pathParameters['id']!,
      openSheet: DetailSheet.cancel,
    ),
  ),
  GoRoute(
    path: '/b/:id/decline',
    builder: (_, s) => BookingDetailScreen(
      bookingId: s.pathParameters['id']!,
      openSheet: DetailSheet.decline,
    ),
  ),
  // S18.01 over S05.02 (Decision 13). `?from=delivery` comes from S05.06:
  // the variant follows the booking's state (an approved booking is in its
  // delivery check), so the query needs no handling of its own.
  GoRoute(
    path: '/b/:id/dispute',
    builder: (_, s) => BookingDetailScreen(
      bookingId: s.pathParameters['id']!,
      openSheet: DetailSheet.dispute,
    ),
  ),
  GoRoute(
    path: '/b/:id/review',
    builder: (_, s) => ReviewScreen(bookingId: s.pathParameters['id']!),
  ),
  GoRoute(
    path: '/b/:id/delivery',
    builder: (_, s) => DeliveryReviewScreen(bookingId: s.pathParameters['id']!),
  ),
];

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    this.justPaid = false,
    this.openSheet,
  });

  final String bookingId;

  /// Opened right after the payment (`?paid=1`): shows the paid toast.
  final bool justPaid;
  final DetailSheet? openSheet;

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  /// The transition in flight; every action button waits for it.
  DetailAction? _busy;
  bool _sheetHandled = false;

  /// The notification primer is offered once per visit, after the paid toast.
  bool _primerAsked = false;

  static const _tick = Duration(minutes: 1);

  void _say(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _transition(
    Booking b,
    DetailAction a,
    BookingAction action,
  ) async {
    if (_busy != null) return;
    setState(() => _busy = a);
    final l10n = context.l10n;
    try {
      await ref
          .read(bookingRepositoryProvider)
          .transitionBooking(bookingId: b.id, action: action.code);
      // A photographer who just accepted has a reason to hear back (S17.03).
      if (action == BookingAction.accept && mounted) {
        unawaited(
          maybeAskForNotifications(context, ref, const PhotographerPrimer()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _say(bookingErrorText(e, l10n));
      if (bookingErrorOf(e) == BookingErrorCode.conflict) {
        ref.invalidate(bookingProvider(widget.bookingId));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// The one place that maps an action to what it does; plans 4d and 4e
  /// provide the chat and review destinations behind their flags.
  Future<void> _onAction(
    DetailAction a,
    Booking b,
    BookingRole role,
    String counterpartName,
  ) async {
    switch (a) {
      case DetailAction.message:
        final chatId = b.chatId;
        if (chatId != null) await context.push('/chat/$chatId');
      case DetailAction.reschedule:
        final chatId = b.chatId;
        if (chatId != null) await context.push('/chat/$chatId?reschedule=1');
      case DetailAction.contact:
        break; // handled by the dial itself
      case DetailAction.directions:
        await ref.read(externalLauncherProvider).open(directionsUri(b));
      case DetailAction.accept:
        await _transition(b, a, BookingAction.accept);
      case DetailAction.complete:
        await _transition(b, a, BookingAction.complete);
      case DetailAction.decline:
        final l10n = context.l10n;
        final declined = await showDeclineSheet(
          context,
          booking: b,
          customerName: counterpartName,
        );
        if (declined == true && mounted) {
          _say(l10n.declineDoneToast(counterpartName));
        }
      case DetailAction.cancel:
        final l10n = context.l10n;
        final cancelled = await showCancelSheet(
          context,
          booking: b,
          role: role,
          counterpartName: counterpartName,
        );
        if (cancelled != true || !mounted) return;
        if (role == BookingRole.photographer) {
          _say(l10n.cancelDonePhotographer(counterpartName));
          return;
        }
        // The server's refund when the stream already has it, else the
        // policy at the moment of the cancel.
        final refunded =
            ref.read(bookingProvider(b.id)).value?.depositRefunded ??
            refundAmountAt(b, ref.read(clockProvider)());
        _say(
          refunded > 0
              ? l10n.cancelDoneToast(formatMoney(refunded))
              : l10n.cancelDoneNoRefund,
        );
        if (refunded > 0) await openRefundAccountAfterCancel(context, ref, b);
      case DetailAction.bookAgain:
        await context.push(
          bookingPath(photographerId: b.photographerId, serviceId: b.serviceId),
        );
      case DetailAction.review:
      case DetailAction.viewReview:
        await context.push('/b/${b.id}/review');
      case DetailAction.markShot:
        await _transition(b, a, BookingAction.markShot);
      case DetailAction.deliver:
        final round = await showSubmitDeliverySheet(context, booking: b);
        if (round != null && mounted) {
          _say(context.l10n.deliverySubmitted(round));
        }
      case DetailAction.answerExtraRound:
        break;
      case DetailAction.viewDelivery:
        await context.push('/b/${b.id}/delivery');
      case DetailAction.assign:
        await showAssignSheet(context, b.id);
      case DetailAction.cancelStudioFault:
        final l10n = context.l10n;
        final cancelled = await showStudioFaultCancelSheet(
          context,
          booking: b,
        );
        if (cancelled != true || !mounted) return;
        final refunded =
            ref.read(bookingProvider(b.id)).value?.depositRefunded ??
            b.deposit;
        _say(l10n.cancelDoneToast(formatMoney(refunded)));
        await openRefundAccountAfterCancel(context, ref, b);
      case DetailAction.reportProblem:
        await _reportProblem(b, counterpartName);
      case DetailAction.returnJob:
        await showReturnJobSheet(
          context,
          booking: b,
          studioName:
              ref.read(partyProfileProvider(b.photographerId)).value?.displayName ??
              '',
        );
    }
  }

  /// S18.01 for [b]; a sent dispute opens S18.02. [reason] presets the
  /// reason (S05.02-askshot "Không diễn ra").
  Future<void> _reportProblem(
    Booking b,
    String counterpartName, {
    DisputeReason? reason,
  }) async {
    final closesAt = bookingDisputeClosesAt(b, now: ref.read(clockProvider)());
    if (closesAt == null) return;
    final l10n = context.l10n;
    final summary = bookingSummaryFor(b, name: counterpartName);
    final id = await showOpenDisputeSheet(
      context,
      subject: DisputeSubject.booking(b.id),
      summary: DisputeSubjectSummary(
        title: counterpartName.isEmpty
            ? summary.serviceName
            : '$counterpartName · ${summary.serviceName}',
        subtitle: '${summary.day} · ${summary.start}–${summary.end}',
      ),
      closesAt: closesAt,
      origin: bookingDisputeOrigin(b),
      reason: reason,
    );
    if (id == null || !mounted) return;
    _say(l10n.disputeSent);
    await context.push('/disputes/$id');
  }

  /// The shoot question was offered on this visit (S05.02-askshot).
  bool _askOffered = false;

  /// S05.02-askshot: the sheet; "Không diễn ra" opens S18.01 with the reason
  /// preset (the booking stays `upcoming` with its money held).
  Future<void> _askShot(Booking b, String name) async {
    final happened = await showAskShotSheet(
      context,
      booking: b,
      photographerName: name,
    );
    if (happened == null || !mounted) return;
    if (happened) {
      _say(context.l10n.s0502_askThanks);
      return;
    }
    final denied = b.copyWith(shootDeniedAt: ref.read(clockProvider)());
    await _reportProblem(denied, name, reason: DisputeReason.noShow);
  }

  void _maybeAskShot(Booking b, BookingRole role, String name, DateTime now) {
    if (_askOffered ||
        role != BookingRole.customer ||
        !asksShootHappened(b, now)) {
      return;
    }
    if (name.isEmpty && _nameLoading(b, role)) return;
    _askOffered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_askShot(b, name));
    });
  }

  /// "Xin đổi thợ (1 lần)" → S26.05 (it confirms the request itself).
  Future<void> _requestChange(Booking b) => showChangeRequestSheet(context, b);

  void _maybeOpenSheet(
    Booking b,
    BookingRole role,
    List<DetailAction> actions,
    String counterpartName,
  ) {
    final sheet = widget.openSheet;
    if (sheet == null || _sheetHandled) return;
    // The sheet's title names the other party: wait for the name while it
    // is still loading (this build watches it, so it runs again).
    if (counterpartName.isEmpty && _nameLoading(b, role)) return;
    _sheetHandled = true;
    final wanted = switch (sheet) {
      DetailSheet.cancel when actions.contains(DetailAction.cancelStudioFault) =>
        DetailAction.cancelStudioFault,
      DetailSheet.cancel => DetailAction.cancel,
      DetailSheet.decline => DetailAction.decline,
      DetailSheet.dispute => DetailAction.reportProblem,
    };
    if (!actions.contains(wanted)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onAction(wanted, b, role, counterpartName);
    });
  }

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.all(AppSpace.s4),
    children: [
      BookingCard.skeleton(),
      const SizedBox(height: AppSpace.s4),
      StatusTimeline.skeleton(steps: 7),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = widget.bookingId;
    final bookingAsync = ref.watch(bookingProvider(id));
    final auth = ref.watch(authStateProvider);
    final features = ref.watch(bookingFeaturesProvider);
    final now =
        ref.watch(nowTickerProvider(_tick)).value ?? ref.read(clockProvider)();

    final current = bookingAsync.value;
    final currentRole = current == null
        ? null
        : roleIn(current, auth.value?.uid);
    final menu = currentRole == null
        ? const <DetailAction>[]
        : [
            for (final a in detailActions(
              current!,
              currentRole,
              now,
              features,
              assignee: isAssigneeOf(current, auth.value?.uid),
            ))
              if (a == DetailAction.reschedule) a,
          ];
    final menuName = menu.isEmpty
        ? ''
        : _counterpartName(current!, currentRole!);

    return ScreenCode(
      ScreenCodes.bookingDetail,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.detailTitle(bookingCode(id))),
          actions: [
            if (menu.isNotEmpty)
              PopupMenuButton<DetailAction>(
                key: const Key('detail-more'),
                tooltip: l10n.detailMore,
                icon: const AppIcon(AppIcons.more),
                itemBuilder: (_) => [
                  for (final a in menu)
                    PopupMenuItem(value: a, child: Text(l10n.detailReschedule)),
                ],
                onSelected: (a) =>
                    _onAction(a, current!, currentRole!, menuName),
              ),
          ],
        ),
        body: SafeArea(
          child: AsyncView<Booking?>(
            value: bookingAsync,
            skeleton: (_) => _skeleton(),
            onRetry: () => ref.invalidate(bookingProvider(id)),
            data: (ctx, b) {
              if (!auth.hasValue) return _skeleton();
              final role = b == null ? null : roleIn(b, auth.value?.uid);
              if (b == null || role == null) {
                return EmptyState(
                  title: l10n.detailNotFound,
                  body: l10n.detailNotFoundBody,
                  actionLabel: l10n.detailGoHome,
                  onAction: () => context.go('/home'),
                );
              }
              final actions = detailActions(
                b,
                role,
                now,
                features,
                assignee: isAssigneeOf(b, auth.value?.uid),
              );
              final name = _counterpartName(b, role);
              _maybeOpenSheet(b, role, actions, name);
              _maybeAskShot(b, role, name, now);
              return _body(context, b, role, actions, now, name);
            },
          ),
        ),
      ),
    );
  }

  bool _nameLoading(Booking b, BookingRole role) {
    if (role == BookingRole.customer) {
      return ref.read(photographerProfileProvider(b.photographerId)).isLoading;
    }
    // The profile is only watched once the copy turned out to have no name.
    if (ref.read(bookingContactProvider(b.id)).isLoading) return true;
    return ref.read(partyProfileProvider(b.customerId)).isLoading;
  }

  String _counterpartName(Booking b, BookingRole role) {
    if (role == BookingRole.customer) {
      return ref
              .watch(photographerProfileProvider(b.photographerId))
              .value
              ?.summary
              .displayName ??
          '';
    }
    final copyName = ref.watch(bookingContactProvider(b.id)).value?.name;
    if (copyName != null && copyName.isNotEmpty) return copyName;
    return ref.watch(partyProfileProvider(b.customerId)).value?.displayName ??
        '';
  }

  /// A studio booking still in play shows the customer who shoots it.
  bool _showsStudioBlock(Booking b) =>
      b.studio != null &&
      switch (b.status) {
        BookingStatus.draft ||
        BookingStatus.declined ||
        BookingStatus.expired ||
        BookingStatus.cancelled => false,
        _ => true,
      };

  /// The assigned member's name for the timeline; '' while unknown (and for
  /// a collaborator who has not accepted yet, S27).
  String _assigneeName(Booking b) {
    final id = b.studio?.confirmedAssigneeId;
    if (id == null) return '';
    return ref
            .watch(photographerProfileProvider(id))
            .value
            ?.summary
            .displayName ??
        '';
  }

  Widget _body(
    BuildContext context,
    Booking b,
    BookingRole role,
    List<DetailAction> actions,
    DateTime now,
    String name,
  ) {
    final l10n = context.l10n;
    final customer = role == BookingRole.customer;
    final thumbUrl = customer
        ? ref
              .watch(photographerProfileProvider(b.photographerId))
              .value
              ?.summary
              .avatarUrl
        : ref.watch(partyProfileProvider(b.customerId)).value?.avatarUrl;
    final paidToast =
        widget.justPaid && customer && b.status == BookingStatus.requested;
    // The money of a studio booking is the studio's, not the assignee's.
    final assignee = isAssigneeOf(b, ref.watch(authStateProvider).value?.uid);

    void run(DetailAction a) => _onAction(a, b, role, name);

    if (paidToast && !_primerAsked && name.isNotEmpty) {
      _primerAsked = true;
      // After the toast is on screen: the payment is the meaningful action.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            maybeAskForNotifications(context, ref, CustomerBookingPrimer(name)),
          );
        }
      });
    }

    // Short, bounded content: a plain scroll view builds every action, so
    // the dial and the buttons exist even below the fold.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (paidToast) ...[
            InlineToast(l10n.detailPaidToast(formatMoney(b.deposit))),
            const SizedBox(height: AppSpace.s3),
          ] else if (b.escrowStatus == EscrowStatus.held && !assignee) ...[
            EscrowNotice(
              text: customer
                  ? l10n.escrowNoticeHeld(formatMoney(b.deposit))
                  : l10n.escrowNoticeHeldPhotographer(formatMoney(b.deposit)),
            ),
            const SizedBox(height: AppSpace.s3),
          ],
          // S05.02-pass: the meeting pass on top, from 24 h before.
          if (customer && showsPassCard(b, now)) ...[
            PassCard(booking: b, photographerName: name, now: now),
            const SizedBox(height: AppSpace.s3),
          ],
          // S05.02-askshot reopened from the screen.
          if (customer && asksShootHappened(b, now)) ...[
            AppButton.outline(
              l10n.s0502_askOpen,
              key: const Key('ask-shot-open'),
              onPressed: () => _askShot(b, name),
            ),
            const SizedBox(height: AppSpace.s3),
          ],
          BookingCard(
            data: bookingSummaryFor(b, name: name, thumbUrl: thumbUrl),
          ),
          if (customer) _EntryLine(booking: b),
          const SizedBox(height: AppSpace.s4),
          // Mock S05.02-refund: a policy refund of a bank transfer waits for
          // the customer's account (server mirror) until S22.04 or 24 h.
          if (customer && b.refundAccountNeeded) ...[
            _RefundAccountCard(
              amount: b.depositRefunded,
              onChoose: () =>
                  showRefundAccountSheet(context, ref, BookingRefund(b.id)),
            ),
            const SizedBox(height: AppSpace.s4),
          ],
          // Mock S05.02-disputed: under the card, for both parties. The
          // dispute freezes the money (`escrowStatus: disputed`) until it is
          // resolved, so the booking alone says which banner it is. A studio
          // member assigned to the job is not a party of the dispute (it is
          // the studio's), so S18.02 would not open for them: no banner.
          if (b.disputeId != null && !assignee) ...[
            DisputeBanner(
              open: b.escrowStatus == EscrowStatus.disputed,
              onTap: () => context.push('/disputes/${b.disputeId}'),
            ),
            const SizedBox(height: AppSpace.s4),
          ],
          // S27 studio side: a collaborator offer waiting or declined.
          if (!customer && !assignee && b.studio != null) ...[
            StudioOfferLine(booking: b),
            const SizedBox(height: AppSpace.s2),
          ],
          if (customer && _showsStudioBlock(b)) ...[
            StudioAssigneeBlock(
              booking: b,
              studioName: name,
              now: now,
              canCancel: actions.contains(DetailAction.cancelStudioFault),
              busy: _busy != null,
              onCancel: () => run(DetailAction.cancelStudioFault),
              onChange: () => _requestChange(b),
            ),
            const SizedBox(height: AppSpace.s4),
          ],
          if (b.addons.isNotEmpty || b.pickup != null) ...[
            BookingAddonsBlock(booking: b),
            const SizedBox(height: AppSpace.s4),
          ],
          AsyncView<List<BookingEventRecord>>(
            value: ref.watch(bookingEventsProvider(b.id)),
            skeleton: (_) => StatusTimeline.skeleton(steps: 7),
            onRetry: () => ref.invalidate(bookingEventsProvider(b.id)),
            data: (_, events) => StatusTimeline(
              steps: timelineSteps(
                b,
                events,
                now,
                l10n,
                photographerName: customer ? name : l10n.detailYou,
                studioRows: customer,
                assigneeName: customer ? _assigneeName(b) : '',
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          ..._actions(context, b, role, actions, name, run),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    Booking b,
    BookingRole role,
    List<DetailAction> actions,
    String counterpartName,
    void Function(DetailAction) run,
  ) {
    final l10n = context.l10n;
    final busy = _busy != null;
    bool has(DetailAction a) => actions.contains(a);
    final primaries = primaryActions(b, actions);
    final out = <Widget>[];
    void add(Widget w) {
      if (out.isNotEmpty) out.add(const SizedBox(height: AppSpace.s3));
      out.add(w);
    }

    final counterpartId =
        role == BookingRole.customer ? b.photographerId : b.customerId;
    final hiddenUsers = ref.watch(hiddenUsersProvider);
    final isBlockedPair = hiddenUsers.contains(counterpartId);

    if (isBlockedPair) {
      add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: AppIcon(AppIcons.block, size: 16),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  l10n.bookingBlockedNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // "Nhắn tin" (outline) + "Liên hệ" (dial), side by side (mock).
      final contact = has(DetailAction.contact) ? _contact(b, role) : null;
      // A customer's studio booking: "Nhắn studio", the screen's one
      // primary unless another action already is (mock S05.02-studio).
      final studioMessage = role == BookingRole.customer && b.studio != null;
      final otherPrimary = primaries.isNotEmpty;
      final message = has(DetailAction.message)
          ? Expanded(
              child: studioMessage && !otherPrimary
                  ? AppButton.primary(
                      l10n.detailMessageStudio,
                      key: const Key('detail-message'),
                      size: AppButtonSize.small,
                      onPressed: () => run(DetailAction.message),
                    )
                  : AppButton.outline(
                      studioMessage
                          ? l10n.detailMessageStudio
                          : l10n.detailMessage,
                      key: const Key('detail-message'),
                      size: AppButtonSize.small,
                      onPressed: () => run(DetailAction.message),
                    ),
            )
          : null;
      // The studio frame puts the dial first; individual bookings keep
      // "Nhắn tin" before "Liên hệ".
      final row = studioMessage
          ? <Widget>[?contact, ?message]
          : <Widget>[?message, ?contact];
      if (row.isNotEmpty) {
        add(
          Row(
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpace.s2),
                row[i],
              ],
            ],
          ),
        );
      }
    }

    if (has(DetailAction.directions)) {
      add(
        AppButton.outline(
          l10n.detailDirections,
          size: AppButtonSize.small,
          icon: const AppIcon(AppIcons.nearMe, size: 18),
          onPressed: () => run(DetailAction.directions),
        ),
      );
    }

    if (has(DetailAction.accept) || has(DetailAction.decline)) {
      add(
        Row(
          children: [
            if (has(DetailAction.decline))
              Expanded(
                child: AppButton.outline(
                  l10n.detailDecline,
                  onPressed: busy ? null : () => run(DetailAction.decline),
                ),
              ),
            if (has(DetailAction.accept) && has(DetailAction.decline))
              const SizedBox(width: AppSpace.s2),
            if (has(DetailAction.accept))
              Expanded(child: _acceptButton(b, run)),
          ],
        ),
      );
    }

    if (has(DetailAction.assign)) {
      add(
        AppButton.outline(
          l10n.workAssignAction,
          key: const Key('detail-assign'),
          onPressed: busy ? null : () => run(DetailAction.assign),
        ),
      );
    }

    if (has(DetailAction.complete)) {
      add(
        AppButton.primary(
          l10n.detailComplete,
          loading: _busy == DetailAction.complete,
          onPressed: busy ? null : () => run(DetailAction.complete),
        ),
      );
    }
    if (has(DetailAction.markShot)) {
      add(
        AppButton.primary(
          l10n.detailMarkShot,
          loading: _busy == DetailAction.markShot,
          onPressed: busy ? null : () => run(DetailAction.markShot),
        ),
      );
    }
    final studioSide =
        role == BookingRole.photographer &&
        !isAssigneeOf(b, ref.watch(authStateProvider).value?.uid);
    if (studioSide) {
      if (b.status == BookingStatus.revisionRequested) {
        add(
          _StatusNoticeCard(
            text: l10n.detailRevisionCard(b.deliveryRound > 0 ? b.deliveryRound : 1),
            icon: AppIcons.info,
          ),
        );
      } else if (b.status == BookingStatus.delivered) {
        if (b.extraRound?.status == 'pending') {
          add(
            _ExtraRoundCard(
              booking: b,
              counterpartName: counterpartName,
              busy: busy,
              onGrant: () => _answerExtraRound(b, grant: true),
              onDecline: () => _confirmDeclineExtraRound(b, counterpartName),
            ),
          );
        } else {
          add(
            _StatusNoticeCard(
              text: l10n.detailWaitingApproval(b.deliveryRound > 0 ? b.deliveryRound : 1),
              icon: AppIcons.info,
            ),
          );
        }
      } else if (b.status == BookingStatus.approved) {
        add(
          _StatusNoticeCard(
            text: l10n.detailApprovedProvider,
            icon: AppIcons.checkCircle,
          ),
        );
      }
    }
    if (has(DetailAction.deliver)) {
      final round = b.deliveryRound > 0 ? b.deliveryRound + 1 : 1;
      add(
        AppButton.primary(
          b.deliveryRound >= 1 ? l10n.detailDeliverRound(round) : l10n.detailDeliver,
          loading: _busy == DetailAction.deliver,
          onPressed: busy ? null : () => run(DetailAction.deliver),
        ),
      );
    }
    if (has(DetailAction.viewDelivery)) {
      add(
        !primaries.contains(DetailAction.viewDelivery)
            ? AppButton.outline(
                l10n.detailViewDelivery,
                onPressed: () => run(DetailAction.viewDelivery),
              )
            : AppButton.primary(
                l10n.detailViewDelivery,
                onPressed: () => run(DetailAction.viewDelivery),
              ),
      );
    }
    if (has(DetailAction.bookAgain)) {
      add(
        AppButton.primary(
          l10n.detailBookAgain,
          onPressed: () => run(DetailAction.bookAgain),
        ),
      );
    }
    if (has(DetailAction.review)) {
      add(
        AppButton.primary(
          l10n.detailReview,
          onPressed: () => run(DetailAction.review),
        ),
      );
    }
    if (has(DetailAction.viewReview)) {
      add(
        AppButton.outline(
          l10n.detailViewReview,
          onPressed: () => run(DetailAction.viewReview),
        ),
      );
    }

    if (has(DetailAction.returnJob)) {
      // Kept alive here so the sheet reads the studio's name on tap.
      ref.watch(partyProfileProvider(b.photographerId));
      final dark = Theme.of(context).brightness == Brightness.dark;
      add(
        AppButton.text(
          l10n.workReturnJob,
          key: const Key('detail-return-job'),
          size: AppButtonSize.small,
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(
              dark ? AppColorsDark.destructive : AppColors.destructive,
            ),
          ),
          onPressed: busy ? null : () => run(DetailAction.returnJob),
        ),
      );
    }
    if (has(DetailAction.reportProblem)) {
      // Mock S05.02-problem: red text under the actions, like the cancel.
      final dark = Theme.of(context).brightness == Brightness.dark;
      final now =
          ref.watch(nowTickerProvider(_tick)).value ??
          ref.read(clockProvider)();
      final hours = disputeHoursLeft(bookingDisputeClosesAt(b, now: now)!, now) ?? 0;
      add(
        AppButton.text(
          l10n.disputeReportProblem(hours),
          key: const Key('detail-report-problem'),
          size: AppButtonSize.small,
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(
              dark ? AppColorsDark.destructive : AppColors.destructive,
            ),
          ),
          onPressed: busy ? null : () => run(DetailAction.reportProblem),
        ),
      );
    }
    if (has(DetailAction.cancel)) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final now =
          ref.watch(nowTickerProvider(_tick)).value ??
          ref.read(clockProvider)();
      add(
        AppButton.text(
          role == BookingRole.customer
              ? l10n.detailCancelCustomer(refundPercentAt(b, now))
              : l10n.detailCancelPhotographer,
          size: AppButtonSize.small,
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(
              dark ? AppColorsDark.destructive : AppColors.destructive,
            ),
          ),
          onPressed: busy ? null : () => run(DetailAction.cancel),
        ),
      );
    }
    return out;
  }

  Widget _acceptButton(Booking b, void Function(DetailAction) run) {
    final l10n = context.l10n;
    final busy = _busy != null;
    final deadline = b.acceptDeadline;
    if (deadline == null) {
      return AppButton.primary(
        l10n.detailAcceptNow,
        loading: _busy == DetailAction.accept,
        onPressed: busy ? null : () => run(DetailAction.accept),
      );
    }
    return CountdownText(
      deadline: deadline,
      now: ref.read(clockProvider),
      builder: (_, left) {
        final time = countdownLabel(left, l10n);
        return AppButton.primary(
          time == null ? l10n.detailAcceptNow : l10n.detailAccept(time),
          loading: _busy == DetailAction.accept,
          onPressed: busy || time == null
              ? null
              : () => run(DetailAction.accept),
        );
      },
    );
  }

  /// The dial for the viewer's side, or null when there is no channel to
  /// offer (S05.04: no outside channel → no Liên hệ button).
  Widget? _contact(Booking b, BookingRole role) {
    if (role == BookingRole.photographer) {
      final copy = ref.watch(bookingContactProvider(b.id)).value;
      if (copyChannels(copy).isEmpty) return null;
      return Expanded(child: CustomerContactDial(copy: copy));
    }
    final flags = ref
        .watch(photographerChannelsProvider(b.photographerId))
        .value;
    final channels = flags?.external ?? const <ContactChannel>[];
    if (channels.isEmpty) return null;
    return Expanded(
      child: ContactAction(
        access: ContactAccess.unlocked,
        channels: channels,
        subject: ContactSubject.booking(b.id),
        source: ScreenCodes.bookingDetail,
        style: ContactDialStyle.labeled,
      ),
    );
  }

  Future<void> _answerExtraRound(Booking b, {required bool grant}) async {
    final l10n = context.l10n;
    setState(() => _busy = DetailAction.answerExtraRound);
    try {
      await ref.read(deliveryRepositoryProvider).answerExtraRound(
            bookingId: b.id,
            grant: grant,
          );
      if (mounted) {
        _say(grant ? l10n.detailExtraGranted : l10n.detailExtraDeclined);
      }
    } catch (e) {
      if (mounted) _say(bookingErrorText(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _confirmDeclineExtraRound(Booking b, String counterpartName) async {
    final l10n = context.l10n;
    final name = counterpartName.isNotEmpty ? counterpartName : 'Khách';
    final confirmed = await showConfirmSheet(
      context,
      title: l10n.detailExtraDeclineTitle,
      body: l10n.detailExtraDeclineBody(name),
      confirmLabel: l10n.detailExtraDecline,
      keepLabel: l10n.cancelKeep,
      danger: true,
      onConfirm: () => _answerExtraRound(b, grant: false),
    );
    if (confirmed == true && mounted) {
      ref.invalidate(bookingProvider(widget.bookingId));
    }
  }
}

class _StatusNoticeCard extends StatelessWidget {
  const _StatusNoticeCard({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: 18),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtraRoundCard extends StatelessWidget {
  const _ExtraRoundCard({
    required this.booking,
    required this.counterpartName,
    required this.busy,
    required this.onGrant,
    required this.onDecline,
  });

  final Booking booking;
  final String counterpartName;
  final bool busy;
  final VoidCallback onGrant;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final note = booking.extraRound?.note?.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIcon(AppIcons.info, size: 18),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  l10n.detailExtraRoundTitle(counterpartName),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s1),
          Text(
            l10n.detailExtraRoundUsed(booking.revisionsIncluded),
            style: theme.textTheme.bodySmall?.copyWith(
              color: dark
                  ? AppColorsDark.foregroundSecondary
                  : AppColors.foregroundSecondary,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s2),
            Text('“$note”', style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpace.s3),
          Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  l10n.detailExtraDecline,
                  size: AppButtonSize.small,
                  onPressed: busy ? null : onDecline,
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: AppButton.primary(
                  l10n.detailExtraGrant,
                  size: AppButtonSize.small,
                  onPressed: busy ? null : onGrant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mock S05.02-refund: "Bạn được hoàn {amount}", "Chọn tài khoản để nhận
/// tiền hoàn." and the outline "Chọn tài khoản nhận hoàn" (S22.04). The
/// amount is the server's refund; without it the title is left out.
class _RefundAccountCard extends StatelessWidget {
  const _RefundAccountCard({required this.amount, required this.onChoose});

  final int? amount;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final a = amount;
    return GlassCard(
      key: const Key('detail-refund-account'),
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (a != null && a > 0)
              Text(
                l10n.detailRefundAccountTitle(formatMoney(a)),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            Text(
              l10n.detailRefundAccountBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            AppButton.outline(
              l10n.payChooseRefundAccount,
              key: const Key('detail-refund-account-choose'),
              size: AppButtonSize.small,
              onPressed: onChoose,
            ),
          ],
        ),
      ),
    );
  }
}

/// S05.02 under the booking card: the entry tickets the booking carries
/// ("Đã gồm vé vào cửa cho bạn và thợ"), or what the gate of a ticketed spot
/// asks for both ("Tự mua tại cổng ≈ {x}"); nothing elsewhere.
class _EntryLine extends ConsumerWidget {
  const _EntryLine({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    String? text;
    if (booking.entry != null) {
      text = l10n.s0502_entryIncluded;
    } else if (booking.spotId case final id?) {
      final spot = ref.watch(spotProvider(id)).value;
      if (spot != null && spot.isTicketed) {
        final unit = entryUnitPrice(
          ref.watch(entryEventProvider(id)).value,
          spot.access,
        );
        if (unit != null) text = l10n.s0502_entryOnSite(formatMoney(unit * 2));
      }
    }
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s2),
      child: Row(
        key: const Key('detail-entry-line'),
        children: [
          AppIcon(
            AppIcons.ticket,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpace.s2),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

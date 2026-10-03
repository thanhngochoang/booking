// S05.02: one screen for every state of a booking, for both parties.
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
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/booking/booking_view_rules.dart';
import 'package:photobooking/features/booking/cancel_sheet.dart';
import 'package:photobooking/features/booking/decline_sheet.dart';
import 'package:photobooking/features/contact/contact_action.dart';
import 'package:photobooking/features/discovery/book_entry.dart';

/// A sheet S05.02 opens over itself after its first frame (deep links
/// `/b/:id/cancel`, `/b/:id/decline`).
enum DetailSheet { cancel, decline }

/// `/b/:id`, `/b/:id/cancel`, `/b/:id/decline` (outside the tab shell).
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
];

class BookingDetailScreen extends ConsumerStatefulWidget {
  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    this.justPaid = false,
    this.openSheet,
  });

  final String bookingId;

  /// Opened right after the deposit (`?paid=1`): shows the paid toast.
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
    } catch (e) {
      if (!mounted) return;
      final code = bookingErrorOf(e);
      _say(switch (code) {
        BookingErrorCode.deadlinePassed => l10n.detailErrorExpired,
        BookingErrorCode.notEligible => l10n.detailErrorNotEligible,
        BookingErrorCode.conflict => l10n.detailErrorConflict,
        _ => l10n.detailErrorNetwork,
      });
      if (code == BookingErrorCode.conflict) {
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
      case DetailAction.reschedule:
        final chatId = b.chatId;
        if (chatId != null) await context.push('/chat/$chatId');
      case DetailAction.contact:
        break; // handled by the dial itself
      case DetailAction.directions:
        await ref.read(externalLauncherProvider).open(directionsUri(b));
      case DetailAction.accept:
        await _transition(b, a, BookingAction.accept);
      case DetailAction.complete:
        await _transition(b, a, BookingAction.complete);
      case DetailAction.decline:
        await showDeclineSheet(
          context,
          booking: b,
          customerName: counterpartName,
        );
      case DetailAction.cancel:
        await showCancelSheet(
          context,
          booking: b,
          role: role,
          counterpartName: counterpartName,
        );
      case DetailAction.bookAgain:
        await context.push(
          bookingPath(photographerId: b.photographerId, serviceId: b.serviceId),
        );
      case DetailAction.review:
      case DetailAction.viewReview:
        await context.push('/b/${b.id}/review');
    }
  }

  void _maybeOpenSheet(
    Booking b,
    BookingRole role,
    List<DetailAction> actions,
    String counterpartName,
  ) {
    final sheet = widget.openSheet;
    if (sheet == null || _sheetHandled) return;
    _sheetHandled = true;
    final wanted = sheet == DetailSheet.cancel
        ? DetailAction.cancel
        : DetailAction.decline;
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
            for (final a in detailActions(current!, currentRole, now, features))
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
                icon: const Icon(Icons.more_horiz_rounded),
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
              final actions = detailActions(b, role, now, features);
              final name = _counterpartName(b, role);
              _maybeOpenSheet(b, role, actions, name);
              return _body(context, b, role, actions, now, name);
            },
          ),
        ),
      ),
    );
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

    void run(DetailAction a) => _onAction(a, b, role, name);

    // Short, bounded content: a plain scroll view builds every action, so
    // the dial and the buttons exist even below the fold.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (paidToast) ...[
            _PaidToast(l10n.detailPaidToast(formatMoney(b.deposit), name)),
            const SizedBox(height: AppSpace.s3),
          ] else if (b.escrowStatus == EscrowStatus.held) ...[
            EscrowNotice(
              text: customer
                  ? l10n.escrowNoticeHeld(formatMoney(b.deposit))
                  : l10n.escrowNoticeHeldPhotographer(formatMoney(b.deposit)),
            ),
            const SizedBox(height: AppSpace.s3),
          ],
          BookingCard(
            data: bookingSummaryFor(b, name: name, thumbUrl: thumbUrl),
          ),
          const SizedBox(height: AppSpace.s4),
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
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          ..._actions(context, b, role, actions, run),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    Booking b,
    BookingRole role,
    List<DetailAction> actions,
    void Function(DetailAction) run,
  ) {
    final l10n = context.l10n;
    final busy = _busy != null;
    bool has(DetailAction a) => actions.contains(a);
    final out = <Widget>[];
    void add(Widget w) {
      if (out.isNotEmpty) out.add(const SizedBox(height: AppSpace.s3));
      out.add(w);
    }

    // "Nhắn tin" (outline) + "Liên hệ" (dial), side by side (mock).
    final contact = has(DetailAction.contact) ? _contact(b, role) : null;
    final row = <Widget>[
      if (has(DetailAction.message))
        Expanded(
          child: AppButton.outline(
            l10n.detailMessage,
            size: AppButtonSize.small,
            onPressed: () => run(DetailAction.message),
          ),
        ),
      ?contact,
    ];
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

    if (has(DetailAction.directions)) {
      add(
        AppButton.outline(
          l10n.detailDirections,
          size: AppButtonSize.small,
          icon: const Icon(Icons.near_me_outlined, size: 18),
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

    if (has(DetailAction.complete)) {
      add(
        AppButton.primary(
          l10n.detailComplete,
          loading: _busy == DetailAction.complete,
          onPressed: busy ? null : () => run(DetailAction.complete),
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
}

/// Inline result line after the deposit (mock `.toast`).
class _PaidToast extends StatelessWidget {
  const _PaidToast(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final success = dark ? AppColorsDark.success : AppColors.success;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.surface : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: dark ? AppColorsDark.border : AppColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s3,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: success,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: AppColors.foregroundInverse,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

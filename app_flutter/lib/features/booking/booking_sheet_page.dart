import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking_repository.dart';

import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/steps/datetime_step.dart';
import 'package:photobooking/features/booking/steps/place_step.dart';
import 'package:photobooking/features/booking/steps/review_step.dart';
import 'package:photobooking/features/booking/steps/service_step.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/payment/open_payment.dart';
import 'package:photobooking/features/payment/pay_subject.dart';

class BookingSheetPage extends Page<void> {
  const BookingSheetPage({required this.args, super.key});
  final BookingFlowArgs args;

  @override
  Route<void> createRoute(BuildContext context) => PageRouteBuilder<void>(
    settings: this,
    opaque: false,
    barrierDismissible: false,
    barrierColor: AppColors.overlay,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, _, _) => BookingSheet(args: args),
    transitionsBuilder: (context, animation, _, child) {
      final reduce = MediaQuery.of(context).disableAnimations;
      if (reduce) return child;
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation),
        child: child,
      );
    },
  );
}

class BookingSheet extends ConsumerStatefulWidget {
  const BookingSheet({super.key, required this.args});
  final BookingFlowArgs args;

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  ProviderSubscription<BookingFlowState>? _flowSub;
  StreamSubscription<SubmitOutcome>? _outcomeSub;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(
      bookingFlowControllerProvider(widget.args).notifier,
    );
    _outcomeSub = controller.outcomes.listen(_handleOutcome);

    _flowSub = ref.listenManual(
      bookingFlowControllerProvider(widget.args),
      (prev, next) {
        if (next.error != null && next.error != prev?.error) {
          _handleError(next.error!);
        }
        if (next.droppedAddonNames.isNotEmpty &&
            next.droppedAddonNames != prev?.droppedAddonNames) {
          _showDropped(next.droppedAddonNames);
        }
      },
    );
  }

  @override
  void dispose() {
    _outcomeSub?.cancel();
    _flowSub?.close();
    super.dispose();
  }

  void _handleOutcome(SubmitOutcome outcome) {
    if (!mounted) return;
    switch (outcome) {
      case GoToPayment(:final bookingId, :final checkout):
        openPayment(
          context,
          ref,
          subject: BookingPay(bookingId),
          instructions: checkout.toInstructions(),
          replace: true,
        );
      case NeedPhone():
        final state = ref.read(bookingFlowControllerProvider(widget.args));
        final date = state.day != null ? parseDayKey(state.day!) : null;
        final returnTo = bookingPath(
          photographerId: widget.args.photographerId,
          serviceId: state.isSlot ? null : state.serviceId,
          date: date,
          area: widget.args.area,
          scheduleId: widget.args.scheduleId,
          slotOfferId: widget.args.slotOfferId,
          start: state.isSlot ? state.start : null,
        );
        context.push('/profile/phone?returnTo=${Uri.encodeComponent(returnTo)}');
    }
  }

  /// "Đã bỏ … vì không áp dụng cho gói này", shown once per package change.
  void _showDropped(List<String> names) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.bookAddonDropped(names.join(', ')))),
    );
    final controller = ref.read(
      bookingFlowControllerProvider(widget.args).notifier,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.consumeDropped();
    });
  }

  void _handleError(BookingErrorCode err) {
    if (!mounted) return;
    final l10n = context.l10n;
    switch (err) {
      case BookingErrorCode.dayTaken:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookDayTaken)),
        );
      case BookingErrorCode.deadlinePassed:
      case BookingErrorCode.notFound:
      // S30: the ticket day closed or sold out (S04.03-entry copy: Task 9).
      case BookingErrorCode.dayClosed:
      case BookingErrorCode.soldOutDay:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookTryAgain)),
        );
      case BookingErrorCode.notEligible:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookPaymentsOff)),
        );
      case BookingErrorCode.notAcceptingOrders:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookNotAcceptingOrders)),
        );
      case BookingErrorCode.blocked:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookingErrBlocked)),
        );
      case BookingErrorCode.paymentAttemptsExceeded:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.payAttemptsExceeded)),
        );
      case BookingErrorCode.addonChanged:
      case BookingErrorCode.addonNotApplicable:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookAddonsChanged)),
        );
      case BookingErrorCode.slotTaken:
      case BookingErrorCode.outsideSchedule:
        // The slot path closes back to S29.02, whose grid reads again.
        final slot = ref
            .read(bookingFlowControllerProvider(widget.args))
            .isSlot;
        final message = err == BookingErrorCode.outsideSchedule
            ? l10n.bookOutsideSchedule
            : (slot ? l10n.slotTakenError : l10n.bookSlotTaken);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        if (slot) _dismiss();
      case BookingErrorCode.spotArchived:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.bookSpotArchived)),
        );
        _dismiss();
      case BookingErrorCode.network:
      case BookingErrorCode.conflict:
      case BookingErrorCode.permissionDenied:
      case BookingErrorCode.invalidArgument:
      case BookingErrorCode.unknown:
        final controller = ref.read(
          bookingFlowControllerProvider(widget.args).notifier,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.bookNetworkError),
            action: SnackBarAction(
              label: l10n.actionRetry,
              onPressed: controller.submit,
            ),
          ),
        );
      case BookingErrorCode.phoneRequired:
      case BookingErrorCode.priceChanged:
      // S04.06 shows it under the "Điểm đón" field.
      case BookingErrorCode.pickupRequired:
        break;
    }
  }

  void _dismiss() {
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/u/${widget.args.photographerId}');
      }
    });
  }

  Future<void> _handleBack() async {
    final controller = ref.read(
      bookingFlowControllerProvider(widget.args).notifier,
    );
    final didStepBack = controller.back();
    if (didStepBack) return;

    final state = ref.read(bookingFlowControllerProvider(widget.args));
    if (state.isSlot) {
      // S29.06 opened S04.03 directly: back returns to the slot picker's page.
      _dismiss();
      return;
    }
    if (state.hasChoices) {
      final l10n = context.l10n;
      final discard = await showConfirmSheet(
        context,
        title: l10n.bookDiscardTitle,
        confirmLabel: l10n.bookDiscard,
        keepLabel: l10n.bookKeepGoing,
        danger: true,
      );
      if (discard && mounted) {
        _dismiss();
      }
    } else {
      _dismiss();
    }
  }

  static Widget _skeleton(BuildContext _) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++) ...[
        AppOptionTile.skeleton(withThumb: true),
        if (i < 2) const SizedBox(height: AppSpace.s2),
      ],
    ],
  );

  /// The sheet frame around [child] while the flow cannot start yet (a
  /// Scaffold, so a closing SnackBar has somewhere to go).
  Widget _waiting(Widget child) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: AppSheetFrame(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: child,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final contactAsync = ref.watch(currentContactProvider);

    if (contactAsync.isLoading) {
      return _waiting(_skeleton(context));
    }

    if (contactAsync.hasError || contactAsync.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final uri = GoRouterState.of(context).uri.toString();
        context.replace(
          '/profile/phone?returnTo=${Uri.encodeComponent(uri)}',
        );
      });
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final state = ref.watch(bookingFlowControllerProvider(widget.args));

    // From a spot: nothing to choose until the schedule (and offer) is read.
    if (widget.args.scheduleId != null && state.spot == null) {
      final contextProvider = bookingSpotContextProvider(widget.args);
      return _waiting(
        AsyncView<SpotBookingContext?>(
          value: ref.watch(contextProvider),
          skeleton: _skeleton,
          onRetry: () => ref.invalidate(contextProvider),
          data: (context, ctx) => ctx != null
              ? _skeleton(context)
              : EmptyState(
                  title: l10n.bookOutsideSchedule,
                  body: '',
                  actionLabel: l10n.bookClose,
                  onAction: _dismiss,
                ),
        ),
      );
    }

    final profileAsync = ref.watch(
      photographerProfileProvider(widget.args.photographerId),
    );
    final profile = profileAsync.value;
    final photographerName = profile?.summary.displayName ?? '';

    final headerText = state.step == BookingStep.service
        ? l10n.bookWith(photographerName)
        : '${state.serviceName ?? ''} · $photographerName';

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: AppSheetFrame(
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s4,
                  vertical: AppSpace.s2,
                ),
                child: Row(
                  children: [
                    AppAvatar(
                      url: profile?.summary.avatarUrl,
                      name: photographerName,
                      size: AppAvatarSize.xs,
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: Text(
                        headerText,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s2),
                    SizedBox(
                      width: 88,
                      child: StepProgress(
                        current: state.step.index + 1,
                        total: 4,
                        showCount: true,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: profile != null && !profile.summary.acceptingOrders
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s6,
                        ),
                        child: EmptyState(
                          title: l10n.bookNotAcceptingOrders,
                          body: '',
                          actionLabel: l10n.bookClose,
                          onAction: _dismiss,
                        ),
                      )
                    : switch (state.step) {
                  BookingStep.service => ServiceStep(args: widget.args),
                  BookingStep.datetime => DateTimeStep(args: widget.args),
                  BookingStep.place => PlaceStep(args: widget.args),
                  BookingStep.review => ReviewStep(args: widget.args),
                },
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

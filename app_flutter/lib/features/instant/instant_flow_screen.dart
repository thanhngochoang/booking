// `/instant/:id`: the customer's Chụp ngay request, one route whose view
// follows the request's status (Decision 4). Also asks the server to settle
// its timers once per deadline and on app resume (Decision 6), and shows the
// match moment (S13.04) over S13.05 when a photographer accepts (Decision 5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/choose_view.dart';
import 'package:photobooking/features/instant/closed_view.dart';
import 'package:photobooking/features/instant/done_view.dart';
import 'package:photobooking/features/instant/instant_tick_scheduler.dart';
import 'package:photobooking/features/instant/no_match_view.dart';
import 'package:photobooking/features/instant/shooting_view.dart';
import 'package:photobooking/features/instant/tracking_view.dart';
import 'package:photobooking/features/instant/waiting_view.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';

class InstantFlowScreen extends ConsumerStatefulWidget {
  const InstantFlowScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<InstantFlowScreen> createState() => _InstantFlowScreenState();
}

/// An assignment younger than this, opened from a push, still gets the match
/// moment (Decision 5).
const kInstantFreshMatch = Duration(seconds: 60);

class _InstantFlowScreenState extends ConsumerState<InstantFlowScreen>
    with WidgetsBindingObserver {
  late final InstantTickScheduler _ticks;

  /// The request has ended (or is gone) and Home was told.
  bool _ended = false;

  /// The status of the previous snapshot; null before the first one.
  InstantStatus? _previous;

  /// S13.04 is up over S13.05.
  bool _matching = false;

  String get _id => widget.requestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticks = InstantTickScheduler(
      tick: () => ref.read(instantRepositoryProvider).tick(_id),
      now: ref.read(clockProvider),
    );
    ref.listenManual<AsyncValue<InstantRequest?>>(instantRequestProvider(_id), (
      _,
      next,
    ) {
      if (next.hasValue) _onRequest(next.value);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _ticks.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onRequest(InstantRequest? r) {
    final ended = r == null || !r.status.isActive;
    if (ended && !_ended) {
      // Home's "Yêu cầu chụp ngay đang mở" card reads again.
      ref.invalidate(instantActiveRequestIdProvider);
    }
    _ended = ended;
    _ticks.update(r);
    final match = _isMatch(_previous, r);
    _previous = r?.status;
    if (match) {
      _setMatching(true);
    } else if (_matching && (r == null || !_tracking(r.status))) {
      // The request moved on under the overlay (cancelled, closed).
      _setMatching(false);
    }
  }

  /// Decision 5: `searching → assigned` seen here, or the first snapshot an
  /// assignment younger than [kInstantFreshMatch] (opened from the push).
  bool _isMatch(InstantStatus? previous, InstantRequest? r) {
    if (r == null || r.status != InstantStatus.assigned) return false;
    if (previous == InstantStatus.searching) return true;
    if (previous != null) return false;
    final at = r.assignedAt;
    return at != null &&
        ref.read(clockProvider)().difference(at) < kInstantFreshMatch;
  }

  static bool _tracking(InstantStatus s) =>
      s == InstantStatus.assigned ||
      s == InstantStatus.enRoute ||
      s == InstantStatus.arrived;

  void _setMatching(bool on) {
    if (_matching == on || !mounted) return;
    setState(() => _matching = on);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ticks.onResume();
  }

  Future<void> _askPrimer() async {
    if (!mounted) return;
    await maybeAskForNotifications(context, ref, const CustomerInstantPrimer());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final value = ref.watch(instantRequestProvider(_id));
    return AsyncView<InstantRequest?>(
      value: value,
      skeleton: (_) => const _Frame(child: Center(child: SignatureLoader())),
      error: (context, e, _) => _Frame(
        child: Center(
          child: ErrorState(
            message: instantErrorText(l, e),
            onRetry: () => ref.invalidate(instantRequestProvider(_id)),
          ),
        ),
      ),
      data: (context, r) {
        if (r == null) {
          return _Frame(
            child: EmptyState(
              title: l.instantNotFoundTitle,
              body: l.instantNotFoundBody,
              actionLabel: l.doneHome,
              onAction: () => context.go('/home'),
            ),
          );
        }
        return switch (r.status) {
          // pending_payment is reached only from #202 (Task 8 adds its
          // "Thanh toán tiếp" mode).
          InstantStatus.choosing || InstantStatus.pendingPayment => ChooseView(
            request: r,
            askPrimer: _askPrimer,
          ),
          InstantStatus.searching => WaitingView(request: r),
          InstantStatus.assigned ||
          InstantStatus.enRoute ||
          InstantStatus.arrived when _matching => _Matched(
            request: r,
            onContinue: () => _setMatching(false),
          ),
          InstantStatus.assigned ||
          InstantStatus.enRoute ||
          InstantStatus.arrived => TrackingView(request: r),
          InstantStatus.inProgress ||
          InstantStatus.finished => ShootingView(request: r),
          InstantStatus.completed => DoneView(request: r),
          InstantStatus.noMatch => NoMatchView(request: r),
          InstantStatus.cancelledByCustomer ||
          InstantStatus.abandoned ||
          InstantStatus.noShowCustomer => ClosedView(request: r),
        };
      },
    );
  }
}

/// A page with the "Chụp ngay" bar and Back, for the states without a view of
/// their own (loading, error, not found).
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: l.back,
            icon: const AppIcon(AppIcons.back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          title: Text(l.instantTitle),
        ),
        body: child,
      ),
    );
  }
}

/// S13.04 (`#S13.04`), customer side: "Đã match với Minh Trí", then S13.05
/// (after "Tiếp tục" or by itself after ~3 s).
class _Matched extends StatelessWidget {
  const _Matched({required this.request, required this.onContinue});

  final InstantRequest request;
  final VoidCallback onContinue;

  /// The ETA at assignment; the accepted invite's when the request has none;
  /// null when neither is known (the body then leaves the minutes out).
  int? get _etaMinutes =>
      request.etaMinutes ??
      request.offers
          .where((o) => o.photographerId == request.photographerId)
          .firstOrNull
          ?.etaMinutes;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = request.photographer?.name ?? '';
    final place = request.meetPoint.name;
    final eta = _etaMinutes;
    return ScreenCode(
      ScreenCodes.instantMatched,
      // System Back continues to S13.05 instead of leaving the request.
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onContinue();
        },
        child: AuroraBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: MatchOverlay(
                name: name,
                body: eta == null
                    ? l.matchBodyCustomerNoEta(name, place)
                    : l.matchBodyCustomer(name, place, eta),
                myAvatarUrl: request.customerAvatarUrl,
                theirAvatarUrl: request.photographer?.avatarUrl,
                onContinue: onContinue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// `/instant/:id`: the customer's Chụp ngay request, one route whose view
// follows the request's status (Decision 4). Also asks the server to settle
// its timers once per deadline and on app resume (Decision 6).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/choose_view.dart';
import 'package:photobooking/features/instant/closed_view.dart';
import 'package:photobooking/features/instant/instant_ticks.dart';
import 'package:photobooking/features/instant_work/instant_copy.dart';
import 'package:photobooking/features/notifications/notification_primer.dart';

class InstantFlowScreen extends ConsumerStatefulWidget {
  const InstantFlowScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<InstantFlowScreen> createState() => _InstantFlowScreenState();
}

class _InstantFlowScreenState extends ConsumerState<InstantFlowScreen>
    with WidgetsBindingObserver {
  Timer? _tickTimer;

  /// Deadlines already ticked: one call each, however often the request
  /// changes.
  final _ticked = <DateTime>{};

  /// The request has ended (or is gone) and Home was told.
  bool _ended = false;

  String get _id => widget.requestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<AsyncValue<InstantRequest?>>(instantRequestProvider(_id), (
      _,
      next,
    ) {
      if (next.hasValue) _onRequest(next.value);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
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
    _schedule(r);
  }

  /// One timer for the soonest deadline not ticked yet.
  void _schedule(InstantRequest? r) {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (r == null) return;
    final at = instantTickDeadlines(r)
        .where((d) => !_ticked.contains(d))
        .firstOrNull;
    if (at == null) return;
    final wait = at.difference(ref.read(clockProvider)());
    _tickTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _ticked.add(at);
      unawaited(_tick());
      if (mounted) _schedule(ref.read(instantRequestProvider(_id)).value);
    });
  }

  /// A failing tick is silent: the listener shows the truth.
  Future<void> _tick() async {
    try {
      await ref.read(instantRepositoryProvider).tick(_id);
    } on Object catch (e) {
      debugPrint('instant tick failed: ${instantErrorCodeOf(e)}');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final r = ref.read(instantRequestProvider(_id)).value;
    if (r != null && r.status.isActive) unawaited(_tick());
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
          // Placeholders until Tasks 5–6 build these views.
          InstantStatus.searching => const _Pending(
            ScreenCodes.instantSearching,
          ),
          InstantStatus.assigned ||
          InstantStatus.enRoute ||
          InstantStatus.arrived => const _Pending(ScreenCodes.instantTracking),
          InstantStatus.inProgress || InstantStatus.finished => const _Pending(
            ScreenCodes.instantInProgress,
          ),
          InstantStatus.completed => const _Pending(
            ScreenCodes.instantInProgress,
            label: 'done',
          ),
          InstantStatus.noMatch => const _Pending(ScreenCodes.instantNoMatch),
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

/// A status whose view comes in a later task: its screen code over the
/// waiting loader.
class _Pending extends StatelessWidget {
  const _Pending(this.code, {this.label});

  final String code;
  final String? label;

  @override
  Widget build(BuildContext context) => ScreenCode(
    code,
    label: label,
    child: const _Frame(
      child: Center(child: SignatureLoader(wave: LoaderWave.vibration)),
    ),
  );
}

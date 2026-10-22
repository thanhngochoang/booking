// S14.02 in the foreground: a new pending offer opens the offer screen.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';

/// S14.02's path prefix.
const _offerPath = '/work/instant/offer/';

/// While a photographer is online and the app is foregrounded, a new pending
/// offer opens S14.02 unless it is already open (an open S14.02 stacks the
/// new card itself). An offer is opened once: back from S14.02 does not
/// bring it again. In the background the offer's push does the job (tapping
/// it opens the same screen through the push-open handler); no full-screen
/// intent, no background work (Decision 10). With [enabled] false (Chụp ngay
/// off, not a photographer) nothing is listened to; the widget stays in the
/// tree so the child keeps its place.
class InstantOfferListener extends ConsumerStatefulWidget {
  const InstantOfferListener({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  ConsumerState<InstantOfferListener> createState() =>
      _InstantOfferListenerState();
}

class _InstantOfferListenerState extends ConsumerState<InstantOfferListener>
    with WidgetsBindingObserver {
  ProviderSubscription<AsyncValue<LiveShutterState?>>? _presence;
  ProviderSubscription<AsyncValue<List<InstantOffer>>>? _offers;
  List<InstantOffer> _latest = const [];
  final _opened = <String>{};
  bool _foreground = true;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (widget.enabled) _listen();
  }

  @override
  void didUpdateWidget(InstantOfferListener old) {
    super.didUpdateWidget(old);
    if (widget.enabled == old.enabled) return;
    if (widget.enabled) {
      _listen();
    } else {
      _presence?.close();
      _presence = null;
      _setOnline(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presence?.close();
    _offers?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        _scheduleCheck();
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        _foreground = false;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _listen() {
    _presence = ref.listenManual<AsyncValue<LiveShutterState?>>(
      livePresenceProvider,
      (_, next) {
        if (next.hasValue) _setOnline(next.requireValue?.online ?? false);
      },
      fireImmediately: true,
    );
  }

  /// Offers are listened to only while Live Shutter is on.
  void _setOnline(bool online) {
    if (online == (_offers != null)) return;
    if (!online) {
      _offers?.close();
      _offers = null;
      _latest = const [];
      return;
    }
    _offers = ref.listenManual<AsyncValue<List<InstantOffer>>>(
      pendingOffersProvider,
      (_, next) {
        if (!next.hasValue) return;
        _latest = next.requireValue;
        _scheduleCheck();
      },
      fireImmediately: true,
    );
  }

  /// Navigation waits for the end of the frame (a listener may fire while
  /// the tree builds).
  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _checkScheduled = false;
        _check();
      })
      ..scheduleFrame();
  }

  void _check() {
    if (!mounted || _offers == null || !_foreground) return;
    final now = ref.read(clockProvider)();
    final fresh = [
      for (final o in _latest)
        if (o.outcome == OfferOutcome.pending &&
            o.expiresAt.isAfter(now) &&
            !_opened.contains(o.id))
          o,
    ];
    if (fresh.isEmpty) return;
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    _opened.addAll(fresh.map((o) => o.id));
    if (router.state.uri.path.startsWith(_offerPath)) return;
    // The repository lists the soonest expiry first.
    router.push('$_offerPath${fresh.first.id}');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

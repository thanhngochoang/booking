// Asks the server to settle a Chụp ngay request's timers (`tickInstantRequest`,
// Decision 6) from the customer's screen: once per deadline of
// [instantTickDeadlines], and once on app resume. A failing tick is silent:
// the request listener shows the truth.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_ticks.dart';

/// Calls [tick] once when the next deadline of the latest request passes, and
/// once on app resume; one timer at a time, cancelled on dispose or when the
/// request changes (rescheduled from the new data). Each deadline is ticked
/// once, however often the request changes.
class InstantTickScheduler {
  InstantTickScheduler({
    required Future<void> Function() tick,
    required DateTime Function() now,
  }) : _tickCall = tick,
       _clock = now;

  final Future<void> Function() _tickCall;
  final DateTime Function() _clock;

  Timer? _timer;
  InstantRequest? _request;
  bool _disposed = false;

  /// Deadlines already ticked.
  final _ticked = <DateTime>{};

  @visibleForTesting
  bool get hasTimer => _timer?.isActive ?? false;

  /// The request as the listener now reads it; null when it is gone.
  void update(InstantRequest? r) {
    if (_disposed) return;
    _request = r;
    _schedule();
  }

  /// Back in the app: one tick while the request is active.
  void onResume() {
    if (_disposed) return;
    final r = _request;
    if (r != null && r.status.isActive) _fire();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }

  /// One timer for the soonest deadline not ticked yet.
  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final r = _request;
    if (r == null) return;
    final at = instantTickDeadlines(r)
        .where((d) => !_ticked.contains(d))
        .firstOrNull;
    if (at == null) return;
    final wait = at.difference(_clock());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _timer = null;
      if (_disposed) return;
      _ticked.add(at);
      _fire();
      _schedule();
    });
  }

  void _fire() {
    unawaited(
      _tickCall().catchError((Object e) {
        debugPrint('instant tick failed: ${instantErrorCodeOf(e)}');
      }),
    );
  }
}

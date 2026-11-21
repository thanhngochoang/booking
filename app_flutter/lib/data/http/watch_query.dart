// lib/data/http/watch_query.dart
import 'dart:async';

import 'package:photobooking/data/http/realtime_channel.dart';

export 'package:photobooking/data/http/realtime_channel.dart'
    show RealtimeChannelHolder;

/// Watches data over HTTP backed by a [RealtimeChannel].
///
/// - Emits the first fetch immediately on listen.
/// - Any event on any of [topics] (including `reconnected`) schedules a refetch
///   after [debounce] of quiet.
/// - Never runs two fetches in flight concurrently: an event during a fetch
///   schedules exactly one more fetch after the current one ends.
/// - A fetch error is emitted to the stream via [StreamController.addError] and
///   the subscription stays active for future events.
/// - Cancelling the stream cancels all channel subscriptions and pending timers.
/// - Each emitted value comes from the latest fetch only (older fetches never
///   overwrite newer ones).
/// - If [channel] is null, falls back to [RealtimeChannelHolder.current].
///   If both are null, throws [StateError] when listened.
Stream<T> watchQuery<T>({
  required List<String> topics,
  required Future<T> Function() fetch,
  RealtimeChannel? channel,
  Duration debounce = const Duration(milliseconds: 300),
}) {
  return _WatchQueryStream<T>(
    topics: topics,
    fetch: fetch,
    channel: channel,
    debounce: debounce,
  );
}

class _WatchQueryStream<T> extends Stream<T> {
  _WatchQueryStream({
    required this.topics,
    required this.fetch,
    required this.channel,
    required this.debounce,
  });

  final List<String> topics;
  final Future<T> Function() fetch;
  final RealtimeChannel? channel;
  final Duration debounce;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final activeChannel = channel ?? RealtimeChannelHolder.current;
    if (activeChannel == null) {
      throw StateError('RealtimeChannel is not set');
    }

    late final StreamController<T> controller;

    var fetchSeq = 0;
    var latestEmittedSeq = 0;
    var inFlight = false;
    var pendingRefetch = false;
    var cancelled = false;

    Timer? debounceTimer;
    final subscriptions = <StreamSubscription<ChangeEvent>>[];

    Future<void> executeFetch() async {
      final seq = ++fetchSeq;
      inFlight = true;
      try {
        final value = await fetch();
        if (cancelled) return;
        if (seq > latestEmittedSeq && !controller.isClosed) {
          latestEmittedSeq = seq;
          controller.add(value);
        }
      } catch (error, st) {
        if (cancelled) return;
        if (seq > latestEmittedSeq && !controller.isClosed) {
          latestEmittedSeq = seq;
          controller.addError(error, st);
        }
      } finally {
        inFlight = false;
        if (!cancelled && pendingRefetch) {
          pendingRefetch = false;
          executeFetch();
        }
      }
    }

    void onEvent(ChangeEvent event) {
      if (cancelled) return;
      if (inFlight) {
        pendingRefetch = true;
      } else {
        debounceTimer?.cancel();
        debounceTimer = Timer(debounce, () {
          debounceTimer = null;
          if (!cancelled) {
            executeFetch();
          }
        });
      }
    }

    controller = StreamController<T>(
      onCancel: () {
        cancelled = true;
        pendingRefetch = false;
        debounceTimer?.cancel();
        debounceTimer = null;
        for (final sub in subscriptions) {
          sub.cancel();
        }
        subscriptions.clear();
      },
    );

    for (final topic in topics.toSet()) {
      subscriptions.add(activeChannel.on(topic).listen(onEvent));
    }

    executeFetch();

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

// test/data/http/watch_query_test.dart
import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/http/realtime_channel.dart';
import 'package:photobooking/data/http/watch_query.dart';

class FakeRealtimeChannel implements RealtimeChannel {
  final Map<String, List<StreamController<ChangeEvent>>> _topicControllers = {};

  int listenersFor(String topic) => _topicControllers[topic]?.length ?? 0;

  bool get hasAnyListeners =>
      _topicControllers.values.any((list) => list.isNotEmpty);

  @override
  Stream<ChangeEvent> on(String topic) {
    late final StreamController<ChangeEvent> controller;
    controller = StreamController<ChangeEvent>(
      onListen: () {
        _topicControllers.putIfAbsent(topic, () => []).add(controller);
      },
      onCancel: () {
        _topicControllers[topic]?.remove(controller);
      },
    );
    return controller.stream;
  }

  void emit(ChangeEvent event) {
    final list = _topicControllers[event.topic];
    if (list != null) {
      for (final c in list.toList()) {
        c.add(event);
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  tearDown(() {
    RealtimeChannelHolder.current = null;
  });

  test('emits the first fetch on listen', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      final values = <int>[];
      final sub = watchQuery<int>(
        topics: ['topicA'],
        channel: channel,
        fetch: () async => 42,
      ).listen(values.add);

      async.flushMicrotasks();
      expect(values, [42]);
      sub.cancel();
    });
  });

  test('a burst of ten events inside 300 ms causes one refetch', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      var fetchCount = 0;
      final values = <int>[];
      final sub = watchQuery<int>(
        topics: ['topicA'],
        channel: channel,
        fetch: () async => ++fetchCount,
      ).listen(values.add);

      async.flushMicrotasks();
      expect(values, [1]);
      expect(fetchCount, 1);

      // Burst of 10 events within 300 ms (every 25 ms = 225 ms total)
      for (var i = 0; i < 10; i++) {
        async.elapse(const Duration(milliseconds: 25));
        channel.emit(const ChangeEvent(topic: 'topicA', kind: 'change'));
      }

      // Still debouncing (only 25 ms elapsed since last event)
      expect(fetchCount, 1);

      // Elapse 300 ms of quiet after the last event
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();

      expect(fetchCount, 2);
      expect(values, [1, 2]);

      sub.cancel();
    });
  });

  test('events of unrelated topics do not refetch', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      var fetchCount = 0;
      final sub = watchQuery<int>(
        topics: ['topicA', 'topicB'],
        channel: channel,
        fetch: () async => ++fetchCount,
      ).listen((_) {});

      async.flushMicrotasks();
      expect(fetchCount, 1);

      // Emit an event on an unrelated topic
      channel.emit(const ChangeEvent(topic: 'topicC', kind: 'change'));
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();

      expect(fetchCount, 1);
      sub.cancel();
    });
  });

  test('an event during a fetch causes one more fetch after it', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      var fetchCount = 0;
      final completers = [Completer<int>(), Completer<int>()];
      final values = <int>[];

      final sub = watchQuery<int>(
        topics: ['topicA'],
        channel: channel,
        fetch: () {
          final c = completers[fetchCount];
          fetchCount++;
          return c.future;
        },
      ).listen(values.add);

      async.flushMicrotasks();
      expect(fetchCount, 1);

      // Emit an event while fetch 1 is in flight
      channel.emit(const ChangeEvent(topic: 'topicA', kind: 'change'));
      async.flushMicrotasks();
      // Second fetch should not have started yet (never two fetches in flight)
      expect(fetchCount, 1);

      // Complete fetch 1
      completers[0].complete(100);
      async.flushMicrotasks();

      // Completing fetch 1 emits value 1 and triggers fetch 2
      expect(values, [100]);
      expect(fetchCount, 2);

      // Complete fetch 2
      completers[1].complete(200);
      async.flushMicrotasks();

      expect(values, [100, 200]);
      sub.cancel();
    });
  });

  test('reconnected event refetches', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      var fetchCount = 0;
      final values = <int>[];

      final sub = watchQuery<int>(
        topics: ['topicA'],
        channel: channel,
        fetch: () async => ++fetchCount,
      ).listen(values.add);

      async.flushMicrotasks();
      expect(values, [1]);

      // Emit 'reconnected' event on topicA
      channel.emit(const ChangeEvent(topic: 'topicA', kind: 'reconnected'));
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();

      expect(fetchCount, 2);
      expect(values, [1, 2]);

      sub.cancel();
    });
  });

  test('a fetch error is emitted and the next event recovers', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      var fetchCount = 0;
      final values = <int>[];
      final errors = <Object>[];

      final sub = watchQuery<int>(
        topics: ['topicA'],
        channel: channel,
        fetch: () async {
          fetchCount++;
          if (fetchCount == 2) {
            throw Exception('network error');
          }
          return fetchCount;
        },
      ).listen(
        values.add,
        onError: errors.add,
      );

      async.flushMicrotasks();
      expect(values, [1]);
      expect(errors, isEmpty);

      // Emit event: second fetch fails
      channel.emit(const ChangeEvent(topic: 'topicA', kind: 'change'));
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();

      expect(values, [1]);
      expect(errors.length, 1);
      expect(errors.first, isA<Exception>());

      // Next event: third fetch recovers
      channel.emit(const ChangeEvent(topic: 'topicA', kind: 'change'));
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();

      expect(values, [1, 3]);
      expect(fetchCount, 3);

      sub.cancel();
    });
  });

  test('cancel removes channel subscriptions and timers', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      final sub = watchQuery<int>(
        topics: ['topicA', 'topicB'],
        channel: channel,
        fetch: () async => 1,
      ).listen((_) {});

      async.flushMicrotasks();
      expect(channel.listenersFor('topicA'), 1);
      expect(channel.listenersFor('topicB'), 1);
      expect(channel.hasAnyListeners, isTrue);

      // Emit event to start the debounce timer
      channel.emit(const ChangeEvent(topic: 'topicA', kind: 'change'));

      // Cancel the stream
      sub.cancel();
      async.flushMicrotasks();

      expect(channel.listenersFor('topicA'), 0);
      expect(channel.listenersFor('topicB'), 0);
      expect(channel.hasAnyListeners, isFalse);

      // Pending debounce timer should have been cancelled
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('older fetch result never overwrites a newer one', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      final values = <String>[];
      final completers = [Completer<String>(), Completer<String>()];
      var call = 0;

      final sub = watchQuery<String>(
        topics: ['topicA'],
        channel: channel,
        fetch: () {
          final c = completers[call];
          call++;
          return c.future;
        },
      ).listen(values.add);

      async.flushMicrotasks();
      // Fetch 1 is in flight (e.g. slow network)
      expect(call, 1);

      // An event arrives while fetch 1 is in flight
      channel.emit(const ChangeEvent(topic: 'topicA', kind: 'change'));
      async.flushMicrotasks();

      // Fetch 1 completes later with 'first'
      completers[0].complete('first');
      async.flushMicrotasks();
      expect(values, ['first']);

      // Fetch 2 started after fetch 1 ended
      expect(call, 2);
      completers[1].complete('second');
      async.flushMicrotasks();

      expect(values, ['first', 'second']);
      // The latest value is 'second'; older fetch result 'first' never overwrote it
      expect(values.last, 'second');

      sub.cancel();
    });
  });

  test('two listeners of a broadcast-style use create two independent subscriptions', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      var fetchCount1 = 0;
      var fetchCount2 = 0;
      final values1 = <int>[];
      final values2 = <int>[];

      final stream1 = watchQuery<int>(
        topics: ['topicA'],
        channel: channel,
        fetch: () async => ++fetchCount1,
      );
      final stream2 = watchQuery<int>(
        topics: ['topicA'],
        channel: channel,
        fetch: () async => ++fetchCount2,
      );

      final sub1 = stream1.listen(values1.add);
      final sub2 = stream2.listen(values2.add);

      async.flushMicrotasks();
      expect(values1, [1]);
      expect(values2, [1]);
      expect(channel.listenersFor('topicA'), 2);

      // Cancel sub1 only
      sub1.cancel();
      async.flushMicrotasks();
      expect(channel.listenersFor('topicA'), 1);

      // Emit event on topicA: only stream2 should refetch
      channel.emit(const ChangeEvent(topic: 'topicA', kind: 'change'));
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();

      expect(values1, [1]); // Stream 1 unchanged
      expect(values2, [1, 2]); // Stream 2 refetched

      sub2.cancel();
      async.flushMicrotasks();
      expect(channel.listenersFor('topicA'), 0);
    });
  });

  test('throws StateError on listen if channel is null and RealtimeChannelHolder.current is null', () {
    RealtimeChannelHolder.current = null;
    final stream = watchQuery<int>(
      topics: ['topicA'],
      fetch: () async => 1,
    );
    expect(
      () => stream.listen((_) {}),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'RealtimeChannel is not set',
        ),
      ),
    );
  });

  test('uses RealtimeChannelHolder.current when channel parameter is null', () {
    fakeAsync((async) {
      final channel = FakeRealtimeChannel();
      RealtimeChannelHolder.current = channel;
      final values = <int>[];
      final sub = watchQuery<int>(
        topics: ['topicA'],
        fetch: () async => 99,
      ).listen(values.add);

      async.flushMicrotasks();
      expect(values, [99]);
      sub.cancel();
    });
  });
}

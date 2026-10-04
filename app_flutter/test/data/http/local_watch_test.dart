// test/data/http/local_watch_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/http/local_watch.dart';

void main() {
  test('emits the fetched value, then local writes', () async {
    final local = StreamController<int>.broadcast();
    final seen = <int>[];
    final sub = fetchThenLocal(() async => 1, local.stream).listen(seen.add);
    await pumpEventQueue();
    local.add(2);
    await pumpEventQueue();
    expect(seen, [1, 2]);
    await sub.cancel();
    expect(local.hasListener, isFalse);
  });

  test('writes made during the fetch arrive after it, in order', () async {
    final local = StreamController<int>.broadcast();
    final gate = Completer<int>();
    final seen = <int>[];
    fetchThenLocal(() => gate.future, local.stream).listen(seen.add);
    await pumpEventQueue();
    local
      ..add(2)
      ..add(3);
    gate.complete(1);
    await pumpEventQueue();
    expect(seen, [1, 2, 3]);
  });

  test('a failed fetch is an error event; later writes still arrive', () async {
    final local = StreamController<int>.broadcast();
    final events = <Object>[];
    fetchThenLocal<int>(
      () async => throw StateError('down'),
      local.stream,
    ).listen(events.add, onError: events.add);
    await pumpEventQueue();
    local.add(5);
    await pumpEventQueue();
    expect(events.first, isA<StateError>());
    expect(events.last, 5);
  });
}

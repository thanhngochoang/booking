// lib/data/http/local_watch.dart
import 'dart:async';

/// `watch` over plain HTTP without polling: one [fetch] per subscription,
/// then every value from [local] (the adapter's own writes). Writes made
/// while the fetch runs are delivered after it, in order. Changes made on
/// another device show up the next time a screen subscribes.
Stream<T> fetchThenLocal<T>(Future<T> Function() fetch, Stream<T> local) {
  late final StreamController<T> out;
  StreamSubscription<T>? sub;
  out = StreamController<T>(
    onListen: () {
      final pending = <T>[];
      var fetched = false;
      void drain() {
        fetched = true;
        pending.forEach(out.add);
        pending.clear();
      }

      sub = local.listen((v) => fetched ? out.add(v) : pending.add(v));
      fetch().then(
        (v) {
          out.add(v);
          drain();
        },
        onError: (Object e, StackTrace s) {
          out.addError(e, s);
          drain();
        },
      );
    },
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}

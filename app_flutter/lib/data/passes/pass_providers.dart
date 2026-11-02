// lib/data/passes/pass_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/passes/firestore_pass_repository.dart';
import 'package:photobooking/data/passes/pass_repository.dart';
import 'package:photobooking/data/prefs/shared_preferences_provider.dart';

final passRepositoryProvider = Provider<PassRepository>(
  (ref) => FirestorePassRepository(),
);

/// The customer's pass code for S05.02-pass and S11.04-entry, offline too
/// (spec §6.1, Decision 18): every code read is kept in prefs under
/// `pass.{bookingId|regId}`; the cached code is served first and again when
/// the stream fails, so the QR draws without network. A pass the server says
/// is gone clears the cache.
final myPassProvider = StreamProvider.autoDispose.family<String?, PassRef>((
  ref,
  pass,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = ref.watch(passRepositoryProvider);
  final source = pass.bookingId != null
      ? repo.watchBookingPass(pass.bookingId!)
      : repo.watchRegistrationPass(pass.eventId!, pass.regId!);
  return cachedPassStream(source, prefs, pass.cacheKey);
});

/// [source] with the prefs cache under [key] (see [myPassProvider]).
Stream<String?> cachedPassStream(
  Stream<String?> source,
  SharedPreferences prefs,
  String key,
) {
  late final StreamController<String?> out;
  StreamSubscription<String?>? sub;
  String? read() {
    try {
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  out = StreamController<String?>(
    onListen: () {
      final cached = read();
      if (cached != null) out.add(cached);
      sub = source.listen(
        (code) {
          if (code == null) {
            unawaited(prefs.remove(key));
          } else if (code != read()) {
            unawaited(prefs.setString(key, code));
          }
          out.add(code);
        },
        onError: (Object e, StackTrace st) {
          final c = read();
          if (c != null) {
            out.add(c);
          } else {
            out.addError(e, st);
          }
        },
        onDone: out.close,
      );
    },
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}

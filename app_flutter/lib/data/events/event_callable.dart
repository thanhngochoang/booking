// lib/data/events/event_callable.dart
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/events/event_repository.dart';

/// Calls the callable [name] and returns its data. A refusal becomes an
/// [EventError] with the domain code the function sent in `details.code`;
/// an unreachable backend becomes `EventError('network')`.
Future<Object?> callEventFunction(
  FirebaseFunctions functions,
  String name,
  Map<String, Object?> data,
) async {
  try {
    final r = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<Object?>(data);
    return r.data;
  } on FirebaseFunctionsException catch (e) {
    final details = e.details;
    if (details is Map && details['code'] is String) {
      throw EventError(details['code'] as String);
    }
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      throw const EventError('network');
    }
    throw EventError(e.message ?? e.code);
  }
}

bool validEventPathId(String id) => id.isNotEmpty && !id.contains('/');

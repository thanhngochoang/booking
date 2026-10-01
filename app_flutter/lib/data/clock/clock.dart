import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now" as a UTC instant. Tests override it to make time deterministic.
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

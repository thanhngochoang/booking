import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Indicates whether real payment gateways are enabled.
/// Defaults to false (fake payment mode).
final realPaymentsProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('REAL_PAYMENTS'),
);

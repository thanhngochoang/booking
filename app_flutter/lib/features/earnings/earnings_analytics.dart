// lib/features/earnings/earnings_analytics.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No analytics layer exists yet; S06.05 and S06.06 report through this hook
/// and a later plan points it at the real sink. Parameters never hold
/// amounts, account numbers, holder names or ids.
typedef EarningsEventLogger = void Function(
  String name,
  Map<String, Object> params,
);

final earningsAnalyticsProvider = Provider<EarningsEventLogger>(
  (ref) => (_, _) {},
);

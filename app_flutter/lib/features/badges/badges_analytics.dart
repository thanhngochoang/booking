// lib/features/badges/badges_analytics.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No analytics layer exists yet; S03.02 reports through this hook
/// (`badges_open{own}`, `badge_detail{badgeId}`) and a later plan points it at
/// the real sink.
typedef BadgesEventLogger = void Function(
  String name,
  Map<String, Object> params,
);

final badgesAnalyticsProvider = Provider<BadgesEventLogger>((ref) => (_, _) {});

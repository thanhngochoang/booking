import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No analytics layer exists yet; the inbox and settings report through this
/// hook and a later plan points it at the real sink (events of the S17 specs).
/// Parameters never hold notification text.
typedef NotificationsEventLogger = void Function(
  String name,
  Map<String, Object> params,
);

final notificationsAnalyticsProvider = Provider<NotificationsEventLogger>(
  (ref) => (_, _) {},
);

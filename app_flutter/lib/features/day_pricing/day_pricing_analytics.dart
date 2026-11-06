import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No analytics layer exists yet; S08.10 reports through this hook and a later
/// plan points it at the real sink (like `skillsAnalyticsProvider`). Events,
/// from the S08.10 screen spec: `price_rule_save{repeat, lunar, scope:
/// "new"|"all"|"following", applyAll}`, `price_rule_exception{kind:
/// "price"|"skip"}` and `price_rule_delete{scope}`. Parameters never hold a
/// price, a name or a day.
typedef DayPricingEventLogger = void Function(
  String name,
  Map<String, Object> params,
);

final dayPricingAnalyticsProvider = Provider<DayPricingEventLogger>(
  (ref) => (_, _) {},
);

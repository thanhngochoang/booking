// lib/features/skills/skills_analytics.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// No analytics layer exists yet; the skills screens report through this
/// hook and a later plan points it at the real sink. Parameters never hold
/// post ids or personal data.
typedef SkillsEventLogger = void Function(
  String name,
  Map<String, Object> params,
);

final skillsAnalyticsProvider = Provider<SkillsEventLogger>((ref) => (_, _) {});

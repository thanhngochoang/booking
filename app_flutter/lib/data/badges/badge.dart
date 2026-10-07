import 'package:flutter/foundation.dart';

enum BadgeSource {
  review,
  system;

  static BadgeSource fromCode(Object? code) => BadgeSource.values.firstWhere(
    (s) => s.name == code,
    orElse: () => BadgeSource.system,
  );
}

/// `badges/{id}`: the read-only catalogue.
@immutable
class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.name,
    this.shortName,
    required this.description,
    required this.icon,
    required this.source,
    required this.audience,
    required this.order,
    required this.hiddenWhenLocked,
    required this.hasProgress,
  });

  final String id;
  final String name;

  /// Chip label when the full name is long.
  final String? shortName;

  /// The locked condition.
  final String description;

  /// Catalogue icon key (see `badgeIconOf`).
  final String icon;
  final BadgeSource source;

  /// `photographer`, `customer` or `both`.
  final String audience;
  final int order;
  final bool hiddenWhenLocked;
  final bool hasProgress;

  String get label => shortName ?? name;
}

/// `users/{uid}/badges/{badgeId}`, public to signed-in users.
@immutable
class EarnedBadge {
  const EarnedBadge({
    required this.badgeId,
    required this.awardedAt,
    this.snapshotText,
  });

  final String badgeId;
  final DateTime awardedAt;

  /// Text frozen at award time ("4,9 sao từ 58 đánh giá").
  final String? snapshotText;
}

/// One entry of `users/{uid}/private/badgeProgress.entries` (owner only).
@immutable
class BadgeProgressEntry {
  const BadgeProgressEntry({required this.current, required this.target});

  final int current;
  final int target;
}

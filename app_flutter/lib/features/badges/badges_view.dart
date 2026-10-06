// lib/features/badges/badges_view.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/badges/badge.dart';

/// One tile of S03.02.
@immutable
class BadgeTileVm {
  const BadgeTileVm({
    required this.badge,
    required this.progress,
    required this.isNew,
    required this.awardedAt,
    required this.description,
  });

  /// Name, the line under it (snapshot text when earned) and the state.
  final BadgeView badge;

  /// Locked badges of the own view that have a progress entry.
  final BadgeProgress? progress;
  final bool isNew;
  final DateTime? awardedAt;

  /// The catalogue condition, shown in the detail sheet.
  final String description;

  double get ratio {
    final p = progress;
    if (p == null || p.total <= 0) {
      return 0;
    }
    return p.current / p.total;
  }
}

/// What S03.02 shows: two sections and the counts of the header.
@immutable
class BadgesView {
  const BadgesView({
    required this.fromReviews,
    required this.fromSystem,
    required this.earned,
    required this.shown,
    required this.reviewsEarned,
    required this.reviewsShown,
    required this.systemEarned,
    required this.systemShown,
    required this.nearest,
  });

  final List<BadgeTileVm> fromReviews;
  final List<BadgeTileVm> fromSystem;
  final int earned;
  final int shown;
  final int reviewsEarned;
  final int reviewsShown;
  final int systemEarned;
  final int systemShown;

  /// Own view with nothing earned only: the locked badge closest to done.
  final BadgeTileVm? nearest;

  bool get isEmpty => fromReviews.isEmpty && fromSystem.isEmpty;
}

/// Builds the screen model. [progress] is null for other people's views.
/// [seenAt] is when this device last showed the own badges; null counts every
/// earned badge as new.
BadgesView buildBadgesView({
  required List<BadgeDefinition> catalog,
  required List<EarnedBadge> earned,
  Map<String, BadgeProgressEntry>? progress,
  required bool own,
  required bool photographer,
  DateTime? seenAt,
}) {
  final held = {for (final e in earned) e.badgeId: e};
  final audiences = photographer
      ? const {'photographer', 'customer', 'both'}
      : const {'customer', 'both'};

  final shown = [
    for (final d in catalog)
      if (own
          ? (held.containsKey(d.id) ||
                (audiences.contains(d.audience) && !d.hiddenWhenLocked))
          : held.containsKey(d.id))
        d,
  ]..sort((a, b) => a.order.compareTo(b.order));

  BadgeTileVm tile(BadgeDefinition d) {
    final e = held[d.id];
    if (e != null) {
      return BadgeTileVm(
        badge: BadgeView(
          code: d.icon,
          name: d.name,
          condition: e.snapshotText ?? d.description,
          earned: true,
        ),
        progress: null,
        isNew: own && (seenAt == null || e.awardedAt.isAfter(seenAt)),
        awardedAt: e.awardedAt,
        description: d.description,
      );
    }
    final entry = (own && d.hasProgress && progress != null)
        ? progress[d.id]
        : null;
    return BadgeTileVm(
      badge: BadgeView(
        code: d.icon,
        name: d.name,
        condition: d.description,
        earned: false,
      ),
      progress: entry == null
          ? null
          : BadgeProgress(current: entry.current, total: entry.target),
      isNew: false,
      awardedAt: null,
      description: d.description,
    );
  }

  // Earned first, then locked, each by catalogue order.
  List<BadgeTileVm> section(BadgeSource source) {
    final defs = shown.where((d) => d.source == source).toList();
    return [
      for (final d in defs)
        if (held.containsKey(d.id)) tile(d),
      for (final d in defs)
        if (!held.containsKey(d.id)) tile(d),
    ];
  }

  final reviews = section(BadgeSource.review);
  final system = section(BadgeSource.system);
  int earnedIn(List<BadgeTileVm> l) => l.where((t) => t.badge.earned).length;

  BadgeTileVm? nearest;
  if (own && held.isEmpty) {
    for (final t in [...reviews, ...system]) {
      if (t.progress == null) {
        continue;
      }
      if (nearest == null || t.ratio > nearest.ratio) {
        nearest = t;
      }
    }
  }

  return BadgesView(
    fromReviews: reviews,
    fromSystem: system,
    earned: earnedIn(reviews) + earnedIn(system),
    shown: reviews.length + system.length,
    reviewsEarned: earnedIn(reviews),
    reviewsShown: reviews.length,
    systemEarned: earnedIn(system),
    systemShown: system.length,
    nearest: nearest,
  );
}

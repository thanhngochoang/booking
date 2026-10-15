import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

@immutable
class BadgeView {
  const BadgeView({
    required this.code,
    required this.name,
    required this.condition,
    required this.earned,
  });

  final String code;
  final String name;
  final String condition;
  final bool earned;
}

@immutable
class BadgeProgress {
  const BadgeProgress({required this.current, required this.total});

  final int current;
  final int total;
}

IconData badgeIconOf(String code) => switch (code) {
  'top_rated' || 'star' => AppIcons.star,
  'fast_reply' || 'quick' => AppIcons.instant,
  'verified' || 'id' => AppIcons.verified,
  'expert' || 'pro' => AppIcons.award,
  'shoots_10' || 'shoots_50' || 'shoots_100' || 'camera' => AppIcons.camera,
  'punctual' || 'on_time' => AppIcons.schedule,
  'rising_star' => AppIcons.trendingUp,
  'community' => AppIcons.people,
  // Catalogue icon keys (badges/{id}.icon).
  'favorite' => AppIcons.favorite,
  'schedule' => AppIcons.schedule,
  'check' => AppIcons.check,
  'celebration' => AppIcons.celebration,
  'person' => AppIcons.profile,
  'chat_bubble' => AppIcons.chat,
  'photo_camera' => AppIcons.camera,
  'calendar_today' => AppIcons.calendar,
  'ios_share' => AppIcons.share,
  _ => AppIcons.medal,
};

/// Chip showing an earned or locked badge (spec S03.01, S09.01, photographer cards).
class BadgeChip extends StatelessWidget {
  const BadgeChip({super.key, required this.badge, this.onTap});

  final BadgeView badge;
  final VoidCallback? onTap;

  static Widget skeleton({Key? key}) =>
      _BadgeChipSkeleton(key: key ?? const ValueKey('badge_chip_skeleton'));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final l = context.l10n;

    final disc = badge.earned
        ? CtaSurface(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: 16,
              child: Center(
                child: AppIcon(
                  badgeIconOf(badge.code),
                  selected: true,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 16,
              child: Center(
                child: AppIcon(badgeIconOf(badge.code), size: 10, color: fgSec),
              ),
            ),
          );

    return Semantics(
      label: l.badgeChipSemantics(badge.name),
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        shape: StadiumBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s2,
              vertical: AppSpace.s1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                disc,
                const SizedBox(width: AppSpace.s2),
                Flexible(
                  child: Text(
                    badge.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeChipSkeleton extends StatelessWidget {
  const _BadgeChipSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: dark ? AppColorsDark.glass : AppColors.glass,
      shape: StadiumBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSkeleton.circle(size: 16),
            const SizedBox(width: AppSpace.s2),
            AppSkeleton.line(width: 60, height: 17),
          ],
        ),
      ),
    );
  }
}

/// Up to [max] chips then "Tất cả" (Wrap). Profile rows use max 3, photographer cards max 2 and no "Tất cả".
class BadgeRow extends StatelessWidget {
  const BadgeRow({
    super.key,
    required this.badges,
    this.max = 3,
    this.onSeeAll,
    this.alwaysShowSeeAll = false,
  });

  final List<BadgeView> badges;
  final int max;
  final VoidCallback? onSeeAll;

  /// Show "Tất cả" even when every badge fits (profile rows, so the full
  /// badges screen stays reachable).
  final bool alwaysShowSeeAll;

  static Widget skeleton({int count = 3}) => _BadgeRowSkeleton(count: count);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final l = context.l10n;

    final shown = badges.take(max).toList();
    final hasMore = badges.length > max;

    return Wrap(
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final b in shown) BadgeChip(badge: b),
        if ((hasMore || alwaysShowSeeAll) && onSeeAll != null)
          Material(
            color: dark ? AppColorsDark.glass : AppColors.glass,
            shape: StadiumBorder(
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: InkWell(
              onTap: onSeeAll,
              customBorder: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: AppSpace.s1,
                ),
                child: Text(
                  l.badgeSeeAll,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BadgeRowSkeleton extends StatelessWidget {
  const _BadgeRowSkeleton({required this.count})
    : super(key: const ValueKey('badge_row_skeleton'));

  final int count;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.s2,
      runSpacing: AppSpace.s2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          BadgeChip.skeleton(key: ValueKey('badge_chip_skeleton_$i')),
      ],
    );
  }
}

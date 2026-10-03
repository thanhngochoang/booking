import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/badge_chip.dart';
import 'package:photobooking/core/widgets/capacity_bar.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

/// Large badge tile showing icon disc, title, condition, and optional progress (spec S03.02).
class BadgeTile extends StatelessWidget {
  const BadgeTile({
    super.key,
    required this.badge,
    this.progress,
    this.isNew = false,
    this.onTap,
  });

  final BadgeView badge;
  final BadgeProgress? progress;
  final bool isNew;
  final VoidCallback? onTap;

  static Widget skeleton() => const _BadgeTileSkeleton();

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
            borderRadius: BorderRadius.circular(18),
            child: SizedBox.square(
              dimension: 36,
              child: Center(
                child: Icon(
                  badgeIconOf(badge.code),
                  size: 20,
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
              dimension: 36,
              child: Center(
                child: Icon(
                  badgeIconOf(badge.code),
                  size: 20,
                  color: fgSec,
                ),
              ),
            ),
          );

    return Material(
      color: dark ? AppColorsDark.glass : AppColors.glass,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s3),
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
                  maxWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        disc,
                        if (isNew)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                l.badgeNew,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s2),
                    Text(
                      badge.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      badge.condition,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: fgSec,
                      ),
                    ),
                    if (!badge.earned) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        l.badgeNotEarned,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: fgSec,
                        ),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: AppSpace.s1),
                        CapacityBar(
                          used: progress!.current,
                          total: progress!.total,
                          label: '${progress!.current} / ${progress!.total}',
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeTileSkeleton extends StatelessWidget {
  const _BadgeTileSkeleton()
      : super(key: const ValueKey('badge_tile_skeleton'));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton.circle(size: 36),
            const SizedBox(height: AppSpace.s2),
            AppSkeleton.line(width: 80, height: 18),
            const SizedBox(height: AppSpace.s1),
            AppSkeleton.line(width: 120, height: 14),
          ],
        ),
      ),
    );
  }
}

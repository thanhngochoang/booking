// lib/core/widgets/spot_card.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/app_icons.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/network_photo.dart';
import 'package:photobooking/core/widgets/season_tag.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/features/spots/spot_format.dart';

enum SpotCardVariant {
  /// S29.01 full-width card with 16:9 photo, title, season, and stats below.
  large,

  /// S02.01 horizontal carousel card: 4:5 photo with overlay text.
  horizontal,

  /// S02.03 2-column explore tile: 4:5 photo with overlay text.
  tile,
}

typedef SpotCardSize = SpotCardVariant;

/// Card showing a photo spot in various layouts (S29.01, S02.01, S02.03, S02.04).
class SpotCard extends StatelessWidget {
  const SpotCard({
    super.key,
    required this.entry,
    this.variant,
    this.size,
    this.onTap,
  });

  final SpotEntry entry;
  final SpotCardVariant? variant;
  final SpotCardSize? size;
  final VoidCallback? onTap;

  SpotCardVariant get effectiveVariant =>
      size ?? variant ?? SpotCardVariant.large;

  @override
  Widget build(BuildContext context) {
    return switch (effectiveVariant) {
      SpotCardVariant.large => _buildLarge(context),
      SpotCardVariant.horizontal => _buildHorizontal(context),
      SpotCardVariant.tile => _buildTile(context),
    };
  }

  Widget _buildPhoto({required double aspectRatio, Widget? overlay}) {
    final photo = entry.cardUrl != null && entry.cardUrl!.isNotEmpty
        ? NetworkPhoto(
            url: entry.cardUrl!,
            fit: BoxFit.cover,
            semanticLabel: entry.name,
          )
        : Container(
            color: const Color(0xFF2C3E50),
            child: const Center(
              child: AppIcon(
                AppIcons.landscape,
                size: 32,
                color: Colors.white38,
              ),
            ),
          );

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          if (entry.inSeason)
            const Positioned(
              top: 10,
              left: 10,
              child: SeasonTag(pill: true),
            ),
          ?overlay,
        ],
      ),
    );
  }

  Widget _buildLarge(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final seasonText = entry.seasonMonths.isNotEmpty
        ? l.spotSeasonBest('tháng ${formatSeasonRange(entry.seasonMonths)}')
        : l.spotSeasonAllYear;

    final statsText = spotCardStats(l, entry);

    final scheme = theme.colorScheme;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;

    return Material(
      color: glass,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPhoto(aspectRatio: 16 / 9),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s3,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.city} · $seasonText',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dark
                            ? AppColorsDark.foregroundSecondary
                            : AppColors.foregroundSecondary,
                        fontSize: 11.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statsText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: dark
                            ? AppColorsDark.foregroundMuted
                            : AppColors.foregroundMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    final l = context.l10n;

    return Semantics(
      link: true,
      label: entry.name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: SizedBox(
              width: 150,
              child: _buildPhoto(
                aspectRatio: 4 / 5,
                overlay: Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 36, 10, 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xB8000000),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          entry.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          entry.city,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l.homeSpotProvidersWeek(entry.providersWeek),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context) {
    return Semantics(
      link: true,
      label: entry.name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: _buildPhoto(
              aspectRatio: 4 / 5,
              overlay: Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xB8000000),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${entry.city} · ${entry.providersWeek} thợ',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

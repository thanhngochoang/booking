import 'package:flutter/material.dart';
import 'package:photobooking/core/format.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/vn_time.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/date_block.dart';
import 'package:photobooking/core/widgets/free_tag.dart';
import 'package:photobooking/core/widgets/network_photo.dart';
import 'package:photobooking/l10n/app_localizations.dart';

@immutable
class EventCardData {
  const EventCardData({
    required this.id,
    required this.title,
    required this.hostName,
    this.hostVerified = false,
    required this.typeTag,
    required this.typeLabel,
    required this.startsAt,
    this.placeName,
    required this.priceVnd,
    required this.seatsLeft,
    required this.soldOut,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String hostName;
  final bool hostVerified;
  final String typeTag;
  final String typeLabel;
  final DateTime startsAt;
  final String? placeName;
  final int priceVnd;
  final int seatsLeft;
  final bool soldOut;
  final String? coverUrl;
}

enum EventCardSize { row, featured, compact }

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.data,
    this.size = EventCardSize.row,
    this.distanceLabel,
    this.onTap,
  });

  final EventCardData data;
  final EventCardSize size;
  final String? distanceLabel;
  final VoidCallback? onTap;

  static Widget skeleton({Key? key, EventCardSize size = EventCardSize.row}) {
    return switch (size) {
      EventCardSize.row => _EventCardRowSkeleton(key: key),
      EventCardSize.featured => _EventCardFeaturedSkeleton(key: key),
      EventCardSize.compact => _EventCardCompactSkeleton(key: key),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final vn = toVn(data.startsAt);
    final isSoldOut = data.soldOut || data.seatsLeft == 0;

    final dateSpoken = l.eventDateSpoken(
      vn.weekday.toString(),
      vn.day,
      vn.month,
    );
    final placeParts = [
      if (distanceLabel != null && distanceLabel!.isNotEmpty) distanceLabel!,
      if (data.hostName.isNotEmpty) data.hostName,
      if (data.placeName != null && data.placeName!.isNotEmpty) data.placeName!,
    ];
    final placeSpoken = placeParts.join(', ');
    final priceSpoken = data.priceVnd == 0 ? l.freeTag : formatMoney(data.priceVnd);
    final seatsSpoken = isSoldOut ? l.eventSoldOut : l.eventSeatsLeft(data.seatsLeft);

    final semanticLabel = [
      data.title,
      dateSpoken,
      if (placeSpoken.isNotEmpty) placeSpoken,
      priceSpoken,
      seatsSpoken,
    ].join(', ');

    final content = switch (size) {
      EventCardSize.row => _buildRow(context, theme, dark, vn, isSoldOut, l),
      EventCardSize.featured => _buildFeatured(context, theme, dark, vn, isSoldOut, l),
      EventCardSize.compact => _buildCompact(context, theme, dark, vn, isSoldOut, l),
    };

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: content,
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    ThemeData theme,
    bool dark,
    DateTime vn,
    bool isSoldOut,
    AppLocalizations l,
  ) {
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    final placeParts = [
      if (distanceLabel != null && distanceLabel!.isNotEmpty) distanceLabel!,
      if (data.hostName.isNotEmpty) data.hostName,
      if (data.placeName != null && data.placeName!.isNotEmpty) data.placeName!,
    ];

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DateBlock(day: data.startsAt),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      key: const Key('event-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (placeParts.isNotEmpty)
                      Text(
                        placeParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: fgSec,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      data.typeTag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.priceVnd == 0)
                    const FreeTag()
                  else
                    Text(
                      formatMoney(data.priceVnd, short: true),
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    isSoldOut ? l.eventSoldOut : l.eventSeatsLeft(data.seatsLeft),
                    key: const Key('event-seats'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSoldOut ? theme.colorScheme.error : fgSec,
                      fontWeight: isSoldOut ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatured(
    BuildContext context,
    ThemeData theme,
    bool dark,
    DateTime vn,
    bool isSoldOut,
    AppLocalizations l,
  ) {
    final pillParts = [
      if (distanceLabel != null && distanceLabel!.isNotEmpty) distanceLabel!,
      isSoldOut ? l.eventSoldOut : l.eventSeatsLeft(data.seatsLeft),
    ];

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (data.coverUrl != null && data.coverUrl!.isNotEmpty)
                NetworkPhoto(
                  url: data.coverUrl!,
                  fit: BoxFit.cover,
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(
                      pillParts.join(' · '),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${vn.day.toString().padLeft(2, '0')}/${vn.month.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (data.priceVnd == 0)
                          const FreeTag()
                        else
                          Text(
                            formatMoney(data.priceVnd),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    ThemeData theme,
    bool dark,
    DateTime vn,
    bool isSoldOut,
    AppLocalizations l,
  ) {
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;

    return SizedBox(
      width: 176,
      child: Material(
        color: dark ? AppColorsDark.glass : AppColors.glass,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: data.coverUrl != null && data.coverUrl!.isNotEmpty
                    ? NetworkPhoto(
                        url: data.coverUrl!,
                        fit: BoxFit.cover,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColorsDark.surfaceMuted
                              : AppColors.surfaceMuted,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpace.s2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${vn.day.toString().padLeft(2, '0')}/${vn.month.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: fgSec,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: data.priceVnd == 0
                              ? const FittedBox(fit: BoxFit.scaleDown, child: FreeTag())
                              : Text(
                                  formatMoney(data.priceVnd),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: fg,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCardRowSkeleton extends StatelessWidget {
  const _EventCardRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateBlock.skeleton(),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSkeleton.line(widthFactor: 0.75, height: 15),
                  const SizedBox(height: 6),
                  AppSkeleton.line(widthFactor: 0.55, height: 12),
                  const SizedBox(height: 6),
                  AppSkeleton.line(widthFactor: 0.30, height: 12),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSkeleton.box(width: 52, height: 16, radius: AppRadius.sm),
                const SizedBox(height: 6),
                AppSkeleton.box(width: 44, height: 12, radius: AppRadius.sm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCardFeaturedSkeleton extends StatelessWidget {
  const _EventCardFeaturedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: outline),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AppSkeleton.box(
            width: double.infinity,
            height: double.infinity,
            radius: AppRadius.card,
          ),
        ),
      ),
    );
  }
}

class _EventCardCompactSkeleton extends StatelessWidget {
  const _EventCardCompactSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return SizedBox(
      width: 176,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: glass,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: AppSkeleton.box(
                width: double.infinity,
                height: double.infinity,
                radius: AppRadius.card,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSkeleton.line(widthFactor: 0.9, height: 16),
                  const SizedBox(height: 6),
                  AppSkeleton.line(widthFactor: 0.6, height: 16),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppSkeleton.box(width: 36, height: 11, radius: AppRadius.sm),
                      AppSkeleton.box(width: 48, height: 12, radius: AppRadius.sm),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

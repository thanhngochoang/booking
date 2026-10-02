// lib/core/widgets/booking_card.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/status_badge.dart';
import 'package:photobooking/data/booking/booking_status.dart';

@immutable
class BookingSummary {
  const BookingSummary({
    required this.photographerName,
    required this.serviceName,
    this.thumbUrl,
    required this.day,
    required this.start,
    required this.end,
    required this.placeName,
    this.status,
    this.statusLabel,
  });

  final String photographerName;
  final String serviceName;
  final String? thumbUrl;
  final String day;
  final String start;
  final String end;
  final String placeName;
  final BookingStatus? status;
  final String? statusLabel;
}

enum BookingCardSize { normal, compact }

/// Card showing a booking overview (spec #bookingcard, S04.03, S05.01, S05.02, etc.):
/// photographer name, package, date/time, location and status badge.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.data,
    this.size = BookingCardSize.normal,
    this.actions,
    this.highlight = false,
    this.onTap,
  });

  final BookingSummary data;
  final BookingCardSize size;
  final Widget? actions;
  final bool highlight;
  final VoidCallback? onTap;

  static Widget skeleton({BookingCardSize size = BookingCardSize.normal}) =>
      _BookingCardSkeleton(size: size);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColorsDark.foreground : AppColors.foreground;
    final fgSec = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;

    final isNormal = size == BookingCardSize.normal;
    final thumbSize = isNormal ? 64.0 : 48.0;

    final decoration = BoxDecoration(
      color: glass,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(
        color: highlight ? primary : outline,
        width: highlight ? 1.5 : 1.0,
      ),
    );

    Widget cardContent = Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  color: dark
                      ? AppColorsDark.surfaceMuted
                      : AppColors.surfaceMuted,
                  child: data.thumbUrl != null && data.thumbUrl!.isNotEmpty
                      ? Image.network(
                          data.thumbUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.grey,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.photographerName} · ${data.serviceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isNormal) ...[
                      Text(
                        '${data.day} · ${data.start}–${data.end}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: fgSec,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: fgSec),
                      ),
                    ] else ...[
                      Text(
                        data.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: fgSec),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Badge
              if (data.statusLabel != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.bookingWaiting,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s2,
                      vertical: AppSpace.s1,
                    ),
                    child: Text(
                      data.statusLabel!,
                      style: const TextStyle(
                        fontSize: AppText.xs,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.foregroundInverse,
                      ),
                    ),
                  ),
                )
              else if (data.status != null)
                StatusBadge(data.status!),
            ],
          ),
          if (actions != null) ...[const SizedBox(height: 8), actions!],
        ],
      ),
    );

    if (onTap != null) {
      return DecoratedBox(
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: cardContent,
          ),
        ),
      );
    }

    return DecoratedBox(decoration: decoration, child: cardContent);
  }
}

class _BookingCardSkeleton extends StatelessWidget {
  const _BookingCardSkeleton({required this.size})
    : super(key: const ValueKey('booking_card_skeleton'));

  final BookingCardSize size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;
    final outline = Theme.of(context).colorScheme.outlineVariant;

    final isNormal = size == BookingCardSize.normal;
    final thumbSize = isNormal ? 64.0 : 48.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppSkeleton.box(
              width: thumbSize,
              height: thumbSize,
              radius: AppRadius.lg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.7,
                    child: AppSkeleton.line(height: 12),
                  ),
                  const SizedBox(height: 6),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: isNormal ? 0.5 : 0.45,
                    child: AppSkeleton.line(height: 10),
                  ),
                  if (isNormal) ...[
                    const SizedBox(height: 4),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.4,
                      child: AppSkeleton.line(height: 10),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppSkeleton.box(width: 52, height: 18, radius: AppRadius.sm),
          ],
        ),
      ),
    );
  }
}

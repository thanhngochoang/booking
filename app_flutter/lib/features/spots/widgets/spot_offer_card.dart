// lib/features/spots/widgets/spot_offer_card.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/spots/spot.dart';

/// Card displaying a slot offer at a photo spot (S29.02, S29.05).
class SpotOfferCard extends StatelessWidget {
  const SpotOfferCard({
    super.key,
    required this.offer,
    this.providerName,
    required this.freeSlotsCount,
    required this.dayFormatted,
    this.onPickSlot,
  });

  final SlotOffer offer;
  final String? providerName;
  final int freeSlotsCount;
  final String dayFormatted;
  final VoidCallback? onPickSlot;

  /// The card's shape while S29.02's offers load.
  static Widget skeleton({Key? key}) => _SpotOfferCardSkeleton(key: key);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;

    final metaParts = [
      if (providerName != null && providerName!.isNotEmpty) providerName!,
      '${offer.editedCount} ảnh chỉnh',
      'giao trong ${offer.deliveryDays} ngày',
    ].join(' · ');

    final slotsText = freeSlotsCount > 0
        ? l.spotFreeSlotsCount(freeSlotsCount, dayFormatted)
        : '${l.spotSlotsFull} $dayFormatted';

    return Material(
      color: glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              offer.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              metaParts,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: dark
                    ? AppColorsDark.foregroundSecondary
                    : AppColors.foregroundSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              slotsText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: freeSlotsCount > 0
                    ? scheme.primary
                    : (dark
                        ? AppColorsDark.foregroundMuted
                        : AppColors.foregroundMuted),
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  formatMoney(offer.price),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                FilledButton(
                  onPressed: onPickSlot,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    l.spotPickSlot,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotOfferCardSkeleton extends StatelessWidget {
  const _SpotOfferCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: dark ? AppColorsDark.glass : AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton.line(widthFactor: 0.6),
            const SizedBox(height: AppSpace.s2),
            AppSkeleton.line(widthFactor: 0.9, height: 10),
            const SizedBox(height: AppSpace.s2),
            AppSkeleton.line(widthFactor: 0.4, height: 10),
          ],
        ),
      ),
    );
  }
}

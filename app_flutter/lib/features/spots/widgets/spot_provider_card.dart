// lib/features/spots/widgets/spot_provider_card.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/features/spots/spot_format.dart';

/// Photographer card on S29.02 showing availability for the chosen day.
class SpotProviderCard extends StatelessWidget {
  const SpotProviderCard({
    super.key,
    required this.summary,
    required this.schedule,
    required this.day,
    this.onProfile,
    this.onBook,
  });

  final PhotographerSummary summary;
  final SpotSchedule schedule;
  final String day;
  final VoidCallback? onProfile;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final glass = dark ? AppColorsDark.glass : AppColors.glass;

    final availLabel = spotAvailableLabel(l, day, schedule.window);
    final priceLabel = priceFromLabel(
      schedule.priceFrom ?? summary.startingPriceVnd,
      l,
    );

    final mark = providerMarkOf(
      type: summary.providerType,
      verified: summary.verified,
    );

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAvatar(
                  url: summary.avatarUrl,
                  name: summary.displayName,
                  size: AppAvatarSize.md,
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: ProviderName(
                              summary.displayName,
                              mark: mark,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (summary.providerType == ProviderType.studio) ...[
                            const SizedBox(width: AppSpace.s2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                                decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.full,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    AppIcons.work,
                                    size: 11,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Studio',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        availLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: dark
                              ? AppColorsDark.foregroundSecondary
                              : AppColors.foregroundSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (summary.tomatoPct > 0 || summary.reviewCount > 0) ...[
                            const VerdictIcon(VerdictKind.tomato, size: 14),
                            const SizedBox(width: 3),
                            Text(
                              '${summary.tomatoPct}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            const Text('·', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: AppSpace.s2),
                          ],
                          if (priceLabel != null)
                            Text(
                              priceLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onProfile,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(l.spotProfile),
                  ),
                ),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: FilledButton(
                    onPressed: onBook,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(l.spotBook),
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

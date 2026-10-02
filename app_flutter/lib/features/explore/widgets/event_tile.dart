// lib/features/explore/widgets/event_tile.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_summary.dart';

/// A row for one event. Stand-in for `EventCard(size: row)` of the events
/// plan: same content (date block, title, place, type, price or "Không thu
/// phí", seats) without the cover image.
class NearbyEventTile extends StatelessWidget {
  const NearbyEventTile({
    super.key,
    required this.event,
    this.distanceLabel,
    this.onTap,
  });

  final EventSummary event;
  final String? distanceLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final vn = toVn(event.startsAt);
    final soldOut = event.status == EventStatus.full || event.seatsLeft == 0;
    final place = [?distanceLabel, ?event.locationName].join(' · ');
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        // A list row never blurs (one BackdropFilter per row would make a
        // long list janky): translucent fill and a hairline instead.
        child: Material(
          color: theme.colorScheme.secondary,
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
                  SizedBox(
                    width: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: subtle,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s2,
                        ),
                        child: Semantics(
                          label: l.eventDateSpoken(
                            vn.weekday.toString(),
                            vn.day,
                            vn.month,
                          ),
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  vn.day.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                    fontFamily: AppFonts.display,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                Text(
                                  l.eventMonthShort(vn.month),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: theme.textTheme.titleMedium),
                        if (place.isNotEmpty)
                          Text(place, style: theme.textTheme.bodySmall),
                        const SizedBox(height: AppSpace.s1),
                        Wrap(
                          spacing: AppSpace.s3,
                          runSpacing: AppSpace.s1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              event.type.label(l),
                              style: TextStyle(
                                fontSize: AppText.sm,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (event.isFree)
                              const FreeTag()
                            else
                              Text(
                                formatMoney(event.priceVnd, short: true),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            Text(
                              soldOut
                                  ? l.eventSoldOut
                                  : l.eventSeatsLeft(event.seatsLeft),
                              style: TextStyle(
                                fontSize: AppText.sm,
                                color: secondary,
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
        ),
      ),
    );
  }
}

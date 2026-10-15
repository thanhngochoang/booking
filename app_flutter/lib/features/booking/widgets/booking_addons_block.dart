// S05.02: the add-ons a booking was made with and its pick-up point, under
// the booking card. Both parties see the same snapshot lines.
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/features/addons/addon_format.dart';

/// "Dịch vụ đi kèm": one row per add-on line (icon, name, quantity × unit
/// price, amount) and a "Điểm đón" row when the booking has a pick-up.
/// Renders nothing for a booking without add-ons and pick-up.
class BookingAddonsBlock extends StatelessWidget {
  const BookingAddonsBlock({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final lines = booking.addons;
    final pickup = booking.pickup;
    if (lines.isEmpty && pickup == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.addonsTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpace.s2),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s1,
            ),
            child: Column(
              children: [
                for (final line in lines)
                  _Row(
                    icon: addonKindIcon(line.kind),
                    title: line.name,
                    meta: line.unit == AddonUnit.perBooking
                        ? l10n.addonOnce
                        : l10n.addonBlockMeta(
                            line.qty,
                            addonUnitNoun(l10n, line.kind, line.unit),
                            formatMoney(line.unitPrice),
                          ),
                    amount: formatMoney(line.amount),
                  ),
                if (pickup != null)
                  _Row(
                    icon: AppIcons.place,
                    title: l10n.bookPickupTitle,
                    meta: pickup.name,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.meta,
    this.amount,
  });

  final IconData icon;
  final String title;
  final String meta;
  final String? amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
            ),
            child: SizedBox.square(
              dimension: AppSpace.s8,
              child: Center(child: AppIcon(icon, size: AppSpace.s4)),
            ),
          ),
          const SizedBox(width: AppSpace.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          if (amount case final a?) ...[
            const SizedBox(width: AppSpace.s2),
            Text(
              a,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

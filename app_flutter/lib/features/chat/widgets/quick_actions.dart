import 'package:flutter/material.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/l10n/app_localizations.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.thread,
    this.booking,
    this.rescheduleEnabled = false,
    this.hasPendingProposal = false,
    required this.onSendLocation,
    required this.onSendRefImage,
    required this.onReschedule,
    required this.onConfirmPlace,
  });

  final ChatThread thread;
  final Booking? booking;
  final bool rescheduleEnabled;
  final bool hasPendingProposal;
  final VoidCallback onSendLocation;
  final VoidCallback onSendRefImage;
  final VoidCallback onReschedule;
  final ValueChanged<String> onConfirmPlace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBooking = thread.kind == ChatKind.booking && booking != null;
    final isAcceptedOrUpcoming = isBooking &&
        (booking!.status == BookingStatus.accepted ||
            booking!.status == BookingStatus.upcoming);

    final showReschedule = isAcceptedOrUpcoming &&
        rescheduleEnabled &&
        !thread.rescheduleUsed &&
        !hasPendingProposal;

    final placeName = booking?.place.name;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s1),
      child: Row(
        children: [
          _ActionChip(
            icon: Icons.location_on_outlined,
            label: l10n.chatSendLocation,
            onTap: onSendLocation,
          ),
          const SizedBox(width: AppSpace.s2),
          _ActionChip(
            icon: Icons.photo_outlined,
            label: l10n.chatSendRef,
            onTap: onSendRefImage,
          ),
          if (showReschedule) ...[
            const SizedBox(width: AppSpace.s2),
            _ActionChip(
              icon: Icons.event_repeat_outlined,
              label: l10n.chatReschedule,
              onTap: onReschedule,
            ),
          ],
          if (isAcceptedOrUpcoming && placeName != null && placeName.isNotEmpty) ...[
            const SizedBox(width: AppSpace.s2),
            _ActionChip(
              icon: Icons.place_outlined,
              label: l10n.chatConfirmPlace,
              onTap: () => onConfirmPlace(placeName),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted;
    final border = theme.colorScheme.outlineVariant;

    return ActionChip(
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(label, style: theme.textTheme.labelMedium),
      backgroundColor: bg,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      onPressed: onTap,
    );
  }
}

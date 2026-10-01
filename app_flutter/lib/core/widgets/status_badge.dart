import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/data/booking/booking_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          status.label(context.l10n).toUpperCase(),
          style: TextStyle(
            fontSize: AppText.xs,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: status.onColor,
          ),
        ),
      ),
    );
  }
}

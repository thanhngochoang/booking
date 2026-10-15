import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/data/booking/booking_status.dart';

class StatusBadge extends StatelessWidget {
  // ignore_for_file: prefer_initializing_formals
  const StatusBadge(this.status, {super.key, this.label})
    : _color = null,
      _onColor = null;

  /// Same look as the booking badges for any other state (e.g. awards).
  const StatusBadge.custom({
    super.key,
    required String this.label,
    required Color color,
    required Color onColor,
  }) : status = null,
       _color = color,
       _onColor = onColor;

  /// Null for [StatusBadge.custom].
  final BookingStatus? status;
  final String? label;
  final Color? _color;
  final Color? _onColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _color ?? status!.color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s2,
          vertical: AppSpace.s1,
        ),
        child: Text(
          label == null
              ? status!.label(context.l10n).toUpperCase()
              : (_color == null ? label! : label!.toUpperCase()),
          style: TextStyle(
            fontSize: AppText.xs,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: _onColor ?? status!.onColor,
          ),
        ),
      ),
    );
  }
}

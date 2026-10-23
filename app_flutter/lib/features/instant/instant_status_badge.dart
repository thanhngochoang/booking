// Mock `.badge.b-ok`: a Chụp ngay request's status on the customer's views
// ("Đã nhận", "Đang đến", "Đã đến", "Đang chụp").
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

class InstantStatusBadge extends StatelessWidget {
  const InstantStatusBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return StatusBadge.custom(
      label: label,
      color: dark ? AppColorsDark.successSubtle : AppColors.successSubtle,
      onColor: dark ? AppColorsDark.success : AppColors.success,
    );
  }
}

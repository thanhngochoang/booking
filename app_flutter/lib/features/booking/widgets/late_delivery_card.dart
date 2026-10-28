// S05.02-late: customer warning block and action when the provider is overdue
// on submitting the first delivery round (#207).
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/features/verification/widgets/verify_parts.dart'
    show VerifyAlert;

/// Mock `#S05.02-late`: section header "Bàn giao ảnh" with red "Quá hạn",
/// the red `.warnc` alert and the red text button "Huỷ phần bàn giao" → S05.08.
class LateDeliveryCard extends StatelessWidget {
  const LateDeliveryCard({
    super.key,
    required this.booking,
    required this.providerName,
    required this.onCancel,
    this.busy = false,
  });

  final Booking booking;
  final String providerName;
  final VoidCallback onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final red = dark ? AppColorsDark.error : AppColors.error;
    final due = BookingRules.deliveryDueAt(booking);
    final dueText = due == null ? '' : formatDayMonth(toVn(due));
    final name = providerName.isEmpty
        ? l.earningsCustomerFallback
        : providerName;

    return Column(
      key: const Key('late-delivery-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          label: '${l.lateDeliverySection}, ${l.lateDeliveryOverdueLabel}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    l.lateDeliverySection,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  l.lateDeliveryOverdueLabel,
                  key: const Key('late-delivery-overdue-label'),
                  style: theme.textTheme.bodySmall?.copyWith(color: red),
                ),
              ],
            ),
          ),
        ),
        VerifyAlert(
          l.lateDeliveryBody,
          title: l.lateDeliveryTitle(name, dueText),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton.text(
            l.lateDeliveryCancel,
            key: const Key('late-delivery-cancel'),
            size: AppButtonSize.small,
            style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(red)),
            onPressed: busy ? null : onCancel,
          ),
        ),
      ],
    );
  }
}

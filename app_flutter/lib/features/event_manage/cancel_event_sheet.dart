// lib/features/event_manage/cancel_event_sheet.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

/// "Huỷ sự kiện · hoàn tiền mọi vé": asks with the ticket count and the money
/// that goes back ("Không có khoản hoàn" for a free event; never "0₫").
/// Returns true when the host confirms; the caller then calls `cancelEvent`.
Future<bool> showCancelEventSheet(
  BuildContext context, {
  required int tickets,
  required int refundVnd,
}) {
  final l = context.l10n;
  final body = refundVnd > 0
      ? l.manageCancelBody(tickets, formatMoney(refundVnd))
      : '${l.manageTicketQty(tickets)} · ${l.manageNoRefund}';
  return showConfirmSheet(
    context,
    title: l.manageCancelTitle,
    body: body,
    confirmLabel: l.manageCancelConfirm,
    keepLabel: l.manageCancelKeep,
  );
}

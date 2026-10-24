// S18.02-resolved (#142): the staff decision in money, as each party reads
// it, and the staff note. Amounts come from the dispute's stored outcome
// (server-computed); nothing is recomputed here.
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/features/disputes/dispute_entry.dart';

class DisputeOutcomeCard extends StatelessWidget {
  const DisputeOutcomeCard({
    super.key,
    required this.dispute,
    required this.outcome,
    required this.viewerIsCustomer,
  });

  final Dispute dispute;
  final DisputeOutcome outcome;

  /// The customer reads "Hoàn cho bạn" / "Chuyển cho {name}"; the provider
  /// reads "Hoàn cho khách" / "Chuyển cho bạn".
  final bool viewerIsCustomer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = disputeReceiverName(l, dispute);
    final kind = switch (outcome.kind) {
      DisputeOutcomeKind.release => l.disputeOutcomeRelease(name),
      DisputeOutcomeKind.refund => l.disputeOutcomeRefund,
      DisputeOutcomeKind.split => l.disputeOutcomeSplit(outcome.refundPercent),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyValueBox(
          key: const Key('dispute-outcome'),
          rows: [
            KeyValueRow(label: l.disputeOutcome, value: kind),
            if (outcome.refundAmount > 0)
              KeyValueRow(
                label: viewerIsCustomer
                    ? l.disputeRefundToYou
                    : l.disputeRefundToCustomer,
                value: formatMoney(outcome.refundAmount),
                note: l.disputeRefundWhere,
              ),
            if (outcome.releaseAmount > 0)
              KeyValueRow(
                label: viewerIsCustomer
                    ? l.disputeReleaseTo(name)
                    : l.disputeReleaseToYou,
                value: formatMoney(outcome.releaseAmount),
              ),
          ],
        ),
        if (outcome.note.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s3),
          EscrowNotice(
            icon: AppIcons.info,
            text: l.disputeStaffNote(outcome.note),
            maxLines: null,
          ),
        ],
      ],
    );
  }
}

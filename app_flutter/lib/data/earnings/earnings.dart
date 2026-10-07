import 'package:flutter/foundation.dart';

/// Money state of one earnings row. Codes are the server's string codes.
enum EarningState {
  held('held'),
  disputed('disputed'),
  released('released'),
  paidOut('paid_out');

  const EarningState(this.code);
  final String code;

  /// Null for a code this app does not know (the row is skipped).
  static EarningState? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// Fixed hold-reason codes the server writes on a row; the UI maps each to a
/// label (never the customer's text).
const String holdReasonDispute = 'dispute';
const String holdReasonPayoutOnHold = 'payout_on_hold';

/// One payment of the photographer as a row in S06.05.
@immutable
class EarningItem {
  const EarningItem({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.counterpartName,
    required this.subjectLabel,
    required this.day,
    required this.amountVnd,
    required this.state,
    this.holdReason,
    this.paidOutAt,
  });

  final String id;
  final String subjectType;
  final String subjectId;
  final String counterpartName;
  final String subjectLabel;

  /// yyyy-MM-dd.
  final String day;
  final int amountVnd;
  final EarningState state;
  final String? holdReason;
  final DateTime? paidOutAt;
}

/// The three totals of S06.05: Đang giữ, Sắp nhận, Đã nhận.
@immutable
class EarningsSummary {
  const EarningsSummary({
    this.heldVnd = 0,
    this.soonVnd = 0,
    this.receivedVnd = 0,
    this.lastPayoutFailed = false,
    this.lastPayoutAt,
    this.fromCache = false,
  });

  final int heldVnd;
  final int soonVnd;
  final int receivedVnd;
  final bool lastPayoutFailed;

  /// When the last payout row was written (`lastPayout.at`); null if unknown.
  final DateTime? lastPayoutAt;

  /// True while the numbers come from the local cache (maybe stale).
  final bool fromCache;
}

/// Masked view of the active payout account. The full number is never readable
/// by the app.
@immutable
class PayoutAccountView {
  const PayoutAccountView({
    required this.accountId,
    required this.bankCode,
    required this.accountLast4,
    required this.holderName,
    required this.updatedAt,
  });

  final String accountId;
  final String bankCode;
  final String accountLast4;
  final String holderName;
  final DateTime updatedAt;
}

/// Failure of saving a payout account. [code] is one of `reauth_required`,
/// `conflict`, `invalid_argument`, `permission_denied`, `network`, `unknown`.
class PayoutAccountError implements Exception {
  const PayoutAccountError(this.code);
  final String code;

  // Never include arguments: only the code.
  @override
  String toString() => 'PayoutAccountError($code)';
}

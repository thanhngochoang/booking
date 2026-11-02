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
    this.feeVnd = 0,
    this.taxVnd = 0,
    int? netVnd,
    this.feeRateBp = 0,
    this.taxRateBp = 0,
    this.estimated = true,
    this.milestonesDone,
    this.milestonesTotal,
    this.milestonesRefunded = const <String>[],
  }) : netVnd = netVnd ?? amountVnd;

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

  /// Platform commission withheld from [amountVnd] (0 today for every type).
  final int feeVnd;

  /// Tax withheld from [amountVnd] (individuals and artists; 0 for studios).
  final int taxVnd;

  /// What the photographer receives: [amountVnd] − [feeVnd] − [taxVnd].
  final int netVnd;

  /// Rates in basis points (700 = 7%).
  final int feeRateBp;
  final int taxRateBp;

  /// True while the breakdown comes from the policy (not paid out yet); false
  /// once it is the payout item's own numbers.
  final bool estimated;

  /// Released milestones of the booking and their count; null when the booking
  /// has no milestone documents.
  final int? milestonesDone;
  final int? milestonesTotal;

  /// Milestone kinds (`shoot` / `delivery`) refunded back to the customer
  /// (#207 Decision 15).
  final List<String> milestonesRefunded;
}

/// The three totals of S06.05: Đang giữ, Chờ chi trả, Đã nhận.
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

/// How the holder name of a payout account was checked. Codes are the server's.
enum PayoutNameStatus {
  matched('matched'),
  pendingReview('pending_review'),
  staffConfirmed('staff_confirmed');

  const PayoutNameStatus(this.code);
  final String code;

  /// An unknown or missing code reads [matched] (accounts saved before the
  /// name check).
  static PayoutNameStatus fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return matched;
  }
}

/// The server's verdict on a looked-up holder name against the verified name.
enum PayoutNameDecision {
  matched('matched'),
  mismatch('mismatch'),
  review('review'),
  notFound('not_found'),
  unverifiable('unverifiable');

  const PayoutNameDecision(this.code);
  final String code;

  /// An unknown code reads [review] (staff compares).
  static PayoutNameDecision fromCode(Object? code) {
    for (final d in values) {
      if (d.code == code) return d;
    }
    return review;
  }
}

/// Answer of the bank name lookup for a bank and account number.
@immutable
class PayoutNameLookup {
  const PayoutNameLookup({
    required this.decision,
    this.holderName,
    this.verifiedName,
  });

  final PayoutNameDecision decision;

  /// The name the bank returned (upper case, no diacritics); null when the bank
  /// cannot be asked or the account does not exist.
  final String? holderName;

  /// The caller's verified legal name as stored; null when not verified yet.
  final String? verifiedName;
}

/// An OTP was sent for an account change.
@immutable
class PayoutOtpTicket {
  const PayoutOtpTicket({
    required this.phoneLast4,
    required this.expiresInSeconds,
    required this.resendInSeconds,
  });

  final String phoneLast4;
  final int expiresInSeconds;
  final int resendInSeconds;
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
    required this.activeFrom,
    this.nameStatus = PayoutNameStatus.matched,
  });

  final String accountId;
  final String bankCode;
  final String accountLast4;
  final String holderName;
  final DateTime updatedAt;

  /// Payouts go to this account from this instant (72 h after a change).
  final DateTime activeFrom;
  final PayoutNameStatus nameStatus;

  /// True while a changed account is not yet in effect at [now].
  bool pendingAt(DateTime now) => activeFrom.isAfter(now);
}

/// Failure of a payout account call. [code] is one of `name_mismatch`,
/// `not_found`, `not_eligible`, `otp_required`, `otp_invalid`, `otp_expired`,
/// `limit_exceeded`, `phone_required`, `reauth_required`, `conflict`,
/// `invalid_argument`, `permission_denied`, `network`, `unknown`.
class PayoutAccountError implements Exception {
  const PayoutAccountError(this.code);
  final String code;

  // Never include arguments: only the code.
  @override
  String toString() => 'PayoutAccountError($code)';
}

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';

/// S21 provider verification as the owner sees it: the server-written
/// `verifications/{uid}` document, the contact's `phoneVerified` flag and the
/// provider type, read together (rules: owner reads, server writes).

/// `not_started → in_progress → submitted → approved | rejected`;
/// `approved → revoked` (terminal in the app).
enum VerificationStatus {
  notStarted('not_started'),
  inProgress('in_progress'),
  submitted('submitted'),
  approved('approved'),
  rejected('rejected'),
  revoked('revoked');

  const VerificationStatus(this.code);
  final String code;

  /// Missing or unknown → [notStarted].
  static VerificationStatus fromCode(Object? raw) {
    for (final s in values) {
      if (s.code == raw) {
        return s;
      }
    }
    return notStarted;
  }
}

/// Which fee applies: a studio pays the studio fee, everyone else (artists
/// included) the individual one.
enum VerificationKind {
  individual('individual'),
  studio('studio');

  const VerificationKind(this.code);
  final String code;

  static VerificationKind? fromCode(Object? raw) {
    for (final k in values) {
      if (k.code == raw) {
        return k;
      }
    }
    return null;
  }
}

/// The kind of a provider type (Decision 5).
VerificationKind verificationKindOf(ProviderType type) =>
    type == ProviderType.studio
    ? VerificationKind.studio
    : VerificationKind.individual;

enum VerifyStep { phone, fee, identity, rules }

enum IdentityMethod {
  vneid('vneid'),
  nfc('nfc');

  const IdentityMethod(this.code);
  final String code;

  static IdentityMethod? fromCode(Object? raw) {
    for (final m in values) {
      if (m.code == raw) {
        return m;
      }
    }
    return null;
  }
}

/// Why staff rejected the provider (Decision 13).
enum RejectReason {
  fakeAvatar('fake_avatar', resubmittable: true),
  stolenPortfolio('stolen_portfolio', resubmittable: true),
  identityMismatch('identity_mismatch', resubmittable: true),
  duplicateAccount('duplicate_account', resubmittable: false),
  underage('underage', resubmittable: false),
  other('other', resubmittable: true);

  const RejectReason(this.code, {required this.resubmittable});
  final String code;

  /// False for the final reasons (no resubmit, support line instead).
  final bool resubmittable;

  static RejectReason? fromCode(Object? raw) {
    for (final r in values) {
      if (r.code == raw) {
        return r;
      }
    }
    return null;
  }
}

enum BusinessStatus {
  submitted('submitted'),
  approved('approved'),
  rejected('rejected');

  const BusinessStatus(this.code);
  final String code;

  static BusinessStatus? fromCode(Object? raw) {
    for (final s in values) {
      if (s.code == raw) {
        return s;
      }
    }
    return null;
  }
}

/// `PROVIDER_RULES_VERSION` of the domain: the rules the provider accepts.
const providerRulesVersion = '2026-10-06';

/// Integer VND per kind (`VERIFICATION_FEE_VND`); charged only once #203 turns
/// the fee on.
const verificationFeeVnd = {
  VerificationKind.individual: 99000,
  VerificationKind.studio: 299000,
};

/// `IDENTITY_ATTEMPTS_PER_DAY`: identity tries per Vietnam calendar day.
const identityAttemptsPerDay = 3;

/// The studio's business sub-record (S21.04).
@immutable
class BusinessVerification {
  const BusinessVerification({
    required this.status,
    required this.kind,
    required this.taxCode,
    required this.name,
    required this.address,
    this.rejectCode,
    this.rejectText,
  });

  final BusinessStatus status;

  /// `company` or `household`.
  final String kind;
  final String taxCode;
  final String name;
  final String address;

  /// `inactive`, `representative_mismatch`, `doc_unreadable` or `other`.
  final String? rejectCode;
  final String? rejectText;

  @override
  bool operator ==(Object other) =>
      other is BusinessVerification &&
      other.status == status &&
      other.kind == kind &&
      other.taxCode == taxCode &&
      other.name == name &&
      other.address == address &&
      other.rejectCode == rejectCode &&
      other.rejectText == rejectText;

  @override
  int get hashCode =>
      Object.hash(status, kind, taxCode, name, address, rejectCode, rejectText);
}

@immutable
class VerificationState {
  const VerificationState({
    required this.status,
    required this.kind,
    this.feeRequired = false,
    this.phoneDone = false,
    this.feeAmount,
    this.feePaidAt,
    this.identityPassed = false,
    this.identityMethod,
    this.identityCheckedAt,
    this.maskedName,
    this.identityFailure,
    this.rulesAcceptedAt,
    this.submittedAt,
    this.decidedAt,
    this.rejectReason,
    this.rejectText,
    this.freeResubmitsLeft = 1,
    this.identityAttemptsLeft = identityAttemptsPerDay,
    this.business,
  });

  /// No document yet.
  static VerificationState initial(
    VerificationKind kind, {
    bool feeRequired = false,
  }) => VerificationState(
    status: VerificationStatus.notStarted,
    kind: kind,
    feeRequired: feeRequired,
    feeAmount: verificationFeeVnd[kind],
  );

  final VerificationStatus status;
  final VerificationKind kind;

  /// `verificationFeeRequiredProvider` (Decision 24): false until #203.
  final bool feeRequired;

  /// The contact's `phoneVerified` flag (Decision 3).
  final bool phoneDone;

  /// What was paid (`steps.fee.amount`), else the kind's fee.
  final int? feeAmount;
  final DateTime? feePaidAt;
  final bool identityPassed;
  final IdentityMethod? identityMethod;

  /// `steps.identity.checkedAt`: when the last check (passed or failed)
  /// finished. A new value is how the app tells a new result from an old one.
  final DateTime? identityCheckedAt;

  /// `NGUYỄN M** T**`; the full name never reaches the app.
  final String? maskedName;

  /// `underage`, `identity_in_use` or `provider_failed` after a failed check.
  final String? identityFailure;
  final DateTime? rulesAcceptedAt;
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final RejectReason? rejectReason;
  final String? rejectText;
  final int freeResubmitsLeft;
  final int identityAttemptsLeft;
  final BusinessVerification? business;

  /// The domain's `requiredSteps(feeRequired)`.
  List<VerifyStep> get requiredSteps => feeRequired
      ? const [
          VerifyStep.phone,
          VerifyStep.fee,
          VerifyStep.identity,
          VerifyStep.rules,
        ]
      : const [VerifyStep.phone, VerifyStep.identity, VerifyStep.rules];

  bool isDone(VerifyStep step) => switch (step) {
    VerifyStep.phone => phoneDone,
    VerifyStep.fee => feePaidAt != null,
    VerifyStep.identity => identityPassed,
    VerifyStep.rules => rulesAcceptedAt != null,
  };

  /// The first undone required step ("Tiếp tục"); null when all are done.
  VerifyStep? get nextStep {
    for (final s in requiredSteps) {
      if (!isDone(s)) {
        return s;
      }
    }
    return null;
  }

  int get stepsLeft => requiredSteps.where((s) => !isDone(s)).length;

  /// "Gửi duyệt": every required step done on an `in_progress` record.
  bool get canSubmit =>
      status == VerificationStatus.inProgress && stepsLeft == 0;

  /// A final rejection (`duplicate_account`, `underage`): no resubmit, the
  /// screen shows the support line and no primary button.
  bool get rejectionFinal =>
      status == VerificationStatus.rejected &&
      !(rejectReason?.resubmittable ?? false);

  /// "Sửa và gửi lại" can be sent now: a non-final rejection with every
  /// required step done, the server's `resubmitVerification` gate. A
  /// non-final rejection with a step undone (`identity_mismatch` clears the
  /// identity step; a changed number resets the phone) is neither this nor
  /// [rejectionFinal]: the screen sends the provider to [nextStep] first.
  bool get resubmittable =>
      status == VerificationStatus.rejected &&
      (rejectReason?.resubmittable ?? false) &&
      stepsLeft == 0;

  @override
  bool operator ==(Object other) =>
      other is VerificationState &&
      other.status == status &&
      other.kind == kind &&
      other.feeRequired == feeRequired &&
      other.phoneDone == phoneDone &&
      other.feeAmount == feeAmount &&
      other.feePaidAt == feePaidAt &&
      other.identityPassed == identityPassed &&
      other.identityMethod == identityMethod &&
      other.identityCheckedAt == identityCheckedAt &&
      other.maskedName == maskedName &&
      other.identityFailure == identityFailure &&
      other.rulesAcceptedAt == rulesAcceptedAt &&
      other.submittedAt == submittedAt &&
      other.decidedAt == decidedAt &&
      other.rejectReason == rejectReason &&
      other.rejectText == rejectText &&
      other.freeResubmitsLeft == freeResubmitsLeft &&
      other.identityAttemptsLeft == identityAttemptsLeft &&
      other.business == business;

  @override
  int get hashCode => Object.hashAll([
    status,
    kind,
    feeRequired,
    phoneDone,
    feeAmount,
    feePaidAt,
    identityPassed,
    identityMethod,
    identityCheckedAt,
    maskedName,
    identityFailure,
    rulesAcceptedAt,
    submittedAt,
    decidedAt,
    rejectReason,
    rejectText,
    freeResubmitsLeft,
    identityAttemptsLeft,
    business,
  ]);
}

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

String? _str(Object? v) => v is String ? v : null;

/// A Firestore `Timestamp`, a `DateTime` (fakes) or an ISO string, as UTC.
DateTime? _instant(Object? v) => switch (v) {
  Timestamp() => v.toDate().toUtc(),
  DateTime() => v.toUtc(),
  String() => DateTime.tryParse(v)?.toUtc(),
  _ => null,
};

int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;

/// Reads `verifications/{uid}` ([d] null = no document yet). [phoneVerified]
/// is the contact flag, [kind] the one of the current provider type (used
/// while no fee is recorded, Decision 5), [now] counts today's identity tries
/// on the Vietnam calendar day.
VerificationState verificationFromFirestore(
  Map<String, dynamic>? d, {
  required bool phoneVerified,
  required VerificationKind kind,
  required bool feeRequired,
  required DateTime now,
}) {
  if (d == null) {
    return VerificationState(
      status: VerificationStatus.notStarted,
      kind: kind,
      feeRequired: feeRequired,
      phoneDone: phoneVerified,
      feeAmount: verificationFeeVnd[kind],
    );
  }
  final steps = _map(d['steps']);
  final fee = steps['fee'] is Map ? _map(steps['fee']) : null;
  final identity = steps['identity'] is Map ? _map(steps['identity']) : null;
  final rules = steps['rules'] is Map ? _map(steps['rules']) : null;
  final effectiveKind = fee != null
      ? VerificationKind.fromCode(d['kind']) ?? kind
      : kind;

  final attempts = _map(d['identityAttempts']);
  final attemptsToday = attempts['dayKey'] == vnDateKey(now)
      ? _int(attempts['count'], 0)
      : 0;

  final reject = d['rejectReason'] is Map ? _map(d['rejectReason']) : null;

  final b = d['business'] is Map ? _map(d['business']) : null;
  final businessStatus = BusinessStatus.fromCode(b?['status']);
  final bReject = b?['rejectReason'] is Map ? _map(b!['rejectReason']) : null;

  return VerificationState(
    status: VerificationStatus.fromCode(d['status']),
    kind: effectiveKind,
    feeRequired: feeRequired,
    phoneDone: phoneVerified,
    feeAmount: fee?['amount'] is num
        ? (fee!['amount'] as num).toInt()
        : verificationFeeVnd[effectiveKind],
    feePaidAt: _instant(fee?['paidAt']),
    identityPassed: identity?['result'] == 'passed',
    identityMethod: IdentityMethod.fromCode(identity?['method']),
    identityCheckedAt: _instant(identity?['checkedAt']),
    maskedName: _str(identity?['maskedName']),
    identityFailure: identity?['result'] == 'failed'
        ? _str(identity?['failure'])
        : null,
    rulesAcceptedAt: _instant(rules?['acceptedAt']),
    submittedAt: _instant(d['submittedAt']),
    decidedAt: _instant(d['decidedAt']),
    rejectReason: RejectReason.fromCode(reject?['code']),
    rejectText: _str(reject?['text']),
    freeResubmitsLeft: _int(d['freeResubmitsLeft'], 1),
    identityAttemptsLeft: (identityAttemptsPerDay - attemptsToday).clamp(
      0,
      identityAttemptsPerDay,
    ),
    business: b == null || businessStatus == null
        ? null
        : BusinessVerification(
            status: businessStatus,
            kind: _str(b['kind']) ?? 'company',
            taxCode: _str(b['taxCode']) ?? '',
            name: _str(b['name']) ?? '',
            address: _str(b['address']) ?? '',
            rejectCode: _str(bReject?['code']),
            rejectText: _str(bReject?['text']),
          ),
  );
}

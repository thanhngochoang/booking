import 'package:flutter/foundation.dart';

import 'package:photobooking/data/content/provider_type.dart';

/// What the photographer won. Codes match the server (`awards.result`).
enum AwardResult {
  gold('gold'),
  silver('silver'),
  bronze('bronze'),
  honorable('honorable'),
  finalist('finalist'),
  exhibited('exhibited');

  const AwardResult(this.code);
  final String code;

  /// Null for an unknown code: the caller skips such a document.
  static AwardResult? fromCode(Object? raw) {
    for (final r in values) {
      if (r.code == raw) {
        return r;
      }
    }
    return null;
  }
}

/// Review state of an award. Codes match the server (`awards.status`).
enum AwardStatus {
  pending('pending'),
  needsInfo('needs_info'),
  approved('approved'),
  rejected('rejected'),
  revoked('revoked');

  const AwardStatus(this.code);
  final String code;

  /// An unknown code reads as [pending].
  static AwardStatus fromCode(Object? raw) {
    for (final s in values) {
      if (s.code == raw) {
        return s;
      }
    }
    return pending;
  }
}

/// One award claim of a photographer, as listed (proofs are not included).
@immutable
class Award {
  const Award({
    required this.id,
    required this.photographerId,
    required this.competition,
    required this.year,
    this.category,
    required this.result,
    this.workPostId,
    required this.status,
    this.reviewNote,
    required this.createdAt,
  });

  final String id;
  final String photographerId;
  final String competition;
  final int year;
  final String? category;
  final AwardResult result;
  final String? workPostId;
  final AwardStatus status;
  final String? reviewNote;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is Award &&
      other.id == id &&
      other.photographerId == photographerId &&
      other.competition == competition &&
      other.year == year &&
      other.category == category &&
      other.result == result &&
      other.workPostId == workPostId &&
      other.status == status &&
      other.reviewNote == reviewNote &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    photographerId,
    competition,
    year,
    category,
    result,
    workPostId,
    status,
    reviewNote,
    createdAt,
  );
}

/// What the owner submits (create) or loads for editing: the award fields plus
/// its proof storage paths and links.
@immutable
class AwardDraft {
  const AwardDraft({
    required this.awardId,
    required this.competition,
    required this.year,
    this.category,
    required this.result,
    this.workPostId,
    this.proofPaths = const [],
    this.proofLinks = const [],
  });

  final String awardId;
  final String competition;
  final int year;
  final String? category;
  final AwardResult result;
  final String? workPostId;
  final List<String> proofPaths;
  final List<String> proofLinks;

  @override
  bool operator ==(Object other) =>
      other is AwardDraft &&
      other.awardId == awardId &&
      other.competition == competition &&
      other.year == year &&
      other.category == category &&
      other.result == result &&
      other.workPostId == workPostId &&
      listEquals(other.proofPaths, proofPaths) &&
      listEquals(other.proofLinks, proofLinks);

  @override
  int get hashCode => Object.hash(
    awardId,
    competition,
    year,
    category,
    result,
    workPostId,
    Object.hashAll(proofPaths),
    Object.hashAll(proofLinks),
  );
}

/// Carries the server's error code (`invalid_argument`, `permission_denied`,
/// `limit_exceeded`, `conflict`, `not_found`, ...).
class AwardError implements Exception {
  const AwardError(this.code);
  final String code;

  @override
  String toString() => 'AwardError($code)';
}

/// The owner's tier as the server keeps it on `photographers/{uid}`: how many
/// awards are approved and whether the artist (NAG) tier is on. It is live, so
/// S25.01 turns gold when the third award is approved.
@immutable
class AwardTier {
  const AwardTier({
    this.providerType = ProviderType.individual,
    this.approvedCount = 0,
    this.artistSince,
  });

  final ProviderType providerType;
  final int approvedCount;

  /// When the artist tier began; null unless [providerType] is artist.
  final DateTime? artistSince;

  @override
  bool operator ==(Object other) =>
      other is AwardTier &&
      other.providerType == providerType &&
      other.approvedCount == approvedCount &&
      other.artistSince == artistSince;

  @override
  int get hashCode => Object.hash(providerType, approvedCount, artistSince);
}

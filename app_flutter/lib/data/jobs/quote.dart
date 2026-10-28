// lib/data/jobs/quote.dart
//
// Dart models for quotes, invites, matches and open jobs.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/jobs/job.dart';

enum QuoteStatus {
  submitted('submitted'),
  withdrawn('withdrawn'),
  accepted('accepted'),
  notSelected('not_selected'),
  declined('declined');

  const QuoteStatus(this.code);
  final String code;

  static QuoteStatus fromCode(String? c) {
    for (final s in values) {
      if (s.code == c) return s;
    }
    return submitted;
  }
}

@immutable
class MilestoneSpec {
  const MilestoneSpec({required this.kind, required this.percent});

  final String kind; // 'shoot' | 'delivery'
  final int percent;

  factory MilestoneSpec.fromJson(Map<String, dynamic> json) {
    return MilestoneSpec(
      kind: json['kind'] as String? ?? 'shoot',
      percent: (json['percent'] as num?)?.toInt() ?? 50,
    );
  }

  Map<String, dynamic> toJson() => {'kind': kind, 'percent': percent};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilestoneSpec &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          percent == other.percent;

  @override
  int get hashCode => Object.hash(kind, percent);
}

@immutable
class QuoteTerms {
  const QuoteTerms({
    required this.price,
    required this.durationMinutes,
    this.photoCount,
    this.editedCount = 0,
    this.deliveryDays = 7,
    this.revisions = 1,
    this.milestones = const [
      MilestoneSpec(kind: 'shoot', percent: 50),
      MilestoneSpec(kind: 'delivery', percent: 50),
    ],
  });

  final int price;
  final int durationMinutes;
  final int? photoCount;
  final int editedCount;
  final int deliveryDays;
  final int revisions;
  final List<MilestoneSpec> milestones;

  factory QuoteTerms.fromJson(Map<String, dynamic> json) {
    final milestonesRaw = json['milestones'];
    final ms = <MilestoneSpec>[];
    if (milestonesRaw is List) {
      for (final m in milestonesRaw) {
        if (m is Map<String, dynamic>) {
          ms.add(MilestoneSpec.fromJson(m));
        }
      }
    }
    return QuoteTerms(
      price: (json['price'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
      photoCount: (json['photoCount'] as num?)?.toInt(),
      editedCount: (json['editedCount'] as num?)?.toInt() ?? 0,
      deliveryDays: (json['deliveryDays'] as num?)?.toInt() ?? 7,
      revisions: (json['revisions'] as num?)?.toInt() ?? 1,
      milestones: ms.isNotEmpty
          ? ms
          : const [
              MilestoneSpec(kind: 'shoot', percent: 50),
              MilestoneSpec(kind: 'delivery', percent: 50),
            ],
    );
  }

  Map<String, dynamic> toJson() => {
    'price': price,
    'durationMinutes': durationMinutes,
    if (photoCount != null) 'photoCount': photoCount,
    'editedCount': editedCount,
    'deliveryDays': deliveryDays,
    'revisions': revisions,
    'milestones': milestones.map((m) => m.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteTerms &&
          runtimeType == other.runtimeType &&
          price == other.price &&
          durationMinutes == other.durationMinutes &&
          photoCount == other.photoCount &&
          editedCount == other.editedCount &&
          deliveryDays == other.deliveryDays &&
          revisions == other.revisions &&
          listEquals(milestones, other.milestones);

  @override
  int get hashCode => Object.hash(
        price,
        durationMinutes,
        photoCount,
        editedCount,
        deliveryDays,
        revisions,
        Object.hashAll(milestones),
      );
}

@immutable
class QuoteMilestoneAmounts {
  const QuoteMilestoneAmounts({required this.shoot, required this.delivery});

  final int shoot;
  final int delivery;

  factory QuoteMilestoneAmounts.fromJson(Map<String, dynamic> json) {
    return QuoteMilestoneAmounts(
      shoot: (json['shoot'] as num?)?.toInt() ?? 0,
      delivery: (json['delivery'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'shoot': shoot, 'delivery': delivery};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteMilestoneAmounts &&
          runtimeType == other.runtimeType &&
          shoot == other.shoot &&
          delivery == other.delivery;

  @override
  int get hashCode => Object.hash(shoot, delivery);
}

@immutable
class QuoteProposal {
  const QuoteProposal({
    required this.day,
    required this.start,
    required this.end,
  });

  final String day;
  final String start;
  final String end;

  factory QuoteProposal.fromJson(Map<String, dynamic> json) {
    return QuoteProposal(
      day: json['day'] as String? ?? '',
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'start': start,
    'end': end,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteProposal &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(day, start, end);
}

@immutable
class QuoteProvider {
  const QuoteProvider({
    required this.name,
    this.avatarUrl,
    required this.providerType,
    this.verified = false,
    this.tomatoPct = 0,
    this.score = 0.0,
    this.reviewCount = 0,
    this.completedCount = 0,
    this.approvedAwardCount = 0,
    this.studioDistrict,
  });

  final String name;
  final String? avatarUrl;
  final ProviderType providerType;
  final bool verified;
  final int tomatoPct;
  final double score;
  final int reviewCount;
  final int completedCount;
  final int approvedAwardCount;
  final String? studioDistrict;

  factory QuoteProvider.fromJson(Map<String, dynamic> json) {
    return QuoteProvider(
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      providerType: ProviderType.fromCode(json['providerType']),
      verified: json['verified'] == true,
      tomatoPct: (json['tomatoPct'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      approvedAwardCount: (json['approvedAwardCount'] as num?)?.toInt() ?? 0,
      studioDistrict: json['studioDistrict'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'providerType': providerType.code,
    'verified': verified,
    'tomatoPct': tomatoPct,
    'score': score,
    'reviewCount': reviewCount,
    'completedCount': completedCount,
    'approvedAwardCount': approvedAwardCount,
    if (studioDistrict != null) 'studioDistrict': studioDistrict,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteProvider &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          avatarUrl == other.avatarUrl &&
          providerType == other.providerType &&
          verified == other.verified &&
          tomatoPct == other.tomatoPct &&
          score == other.score &&
          reviewCount == other.reviewCount &&
          completedCount == other.completedCount &&
          approvedAwardCount == other.approvedAwardCount &&
          studioDistrict == other.studioDistrict;

  @override
  int get hashCode => Object.hash(
        name,
        avatarUrl,
        providerType,
        verified,
        tomatoPct,
        score,
        reviewCount,
        completedCount,
        approvedAwardCount,
        studioDistrict,
      );
}

@immutable
class QuoteAlbum {
  const QuoteAlbum({
    required this.title,
    this.coverUrl,
    this.postCount = 0,
  });

  final String title;
  final String? coverUrl;
  final int postCount;

  factory QuoteAlbum.fromJson(Map<String, dynamic> json) {
    return QuoteAlbum(
      title: json['title'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      postCount: (json['postCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    if (coverUrl != null) 'coverUrl': coverUrl,
    'postCount': postCount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteAlbum &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          coverUrl == other.coverUrl &&
          postCount == other.postCount;

  @override
  int get hashCode => Object.hash(title, coverUrl, postCount);
}

DateTime? _parseQuoteDate(Object? val) {
  if (val is Timestamp) return val.toDate().toUtc();
  if (val is DateTime) return val.toUtc();
  if (val is String) return DateTime.tryParse(val)?.toUtc();
  return null;
}

@immutable
class Quote {
  const Quote({
    required this.id,
    required this.jobId,
    required this.photographerId,
    required this.customerId,
    required this.jobTitle,
    required this.photographer,
    this.basedOnServiceId,
    required this.terms,
    required this.milestoneAmounts,
    required this.proposal,
    required this.message,
    this.albumId,
    this.album,
    this.invited = false,
    this.fit = 0,
    required this.status,
    this.notSelectedReason,
    this.autoWithdrawn = false,
    this.declineReason,
    this.bookingId,
    this.withdrawnAt,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String jobId;
  final String photographerId;
  final String customerId;
  final String jobTitle;
  final QuoteProvider photographer;
  final String? basedOnServiceId;
  final QuoteTerms terms;
  final QuoteMilestoneAmounts milestoneAmounts;
  final QuoteProposal proposal;
  final String message;
  final String? albumId;
  final QuoteAlbum? album;
  final bool invited;
  final int fit;
  final QuoteStatus status;
  final String? notSelectedReason;
  final bool autoWithdrawn;
  final String? declineReason;
  final String? bookingId;
  final DateTime? withdrawnAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  static Quote? fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      final pRaw = data['photographer'];
      final photographer = pRaw is Map<String, dynamic>
          ? QuoteProvider.fromJson(pRaw)
          : const QuoteProvider(name: '', providerType: ProviderType.individual);

      final termsRaw = data['terms'];
      final terms = termsRaw is Map<String, dynamic>
          ? QuoteTerms.fromJson(termsRaw)
          : const QuoteTerms(price: 0, durationMinutes: 60);

      final maRaw = data['milestoneAmounts'];
      final milestoneAmounts = maRaw is Map<String, dynamic>
          ? QuoteMilestoneAmounts.fromJson(maRaw)
          : const QuoteMilestoneAmounts(shoot: 0, delivery: 0);

      final propRaw = data['proposal'];
      final proposal = propRaw is Map<String, dynamic>
          ? QuoteProposal.fromJson(propRaw)
          : const QuoteProposal(day: '', start: '', end: '');

      final albumRaw = data['album'];
      final album = albumRaw is Map<String, dynamic>
          ? QuoteAlbum.fromJson(albumRaw)
          : null;

      final createdAt = _parseQuoteDate(data['createdAt']) ?? DateTime.now().toUtc();
      final updatedAt = _parseQuoteDate(data['updatedAt']) ?? createdAt;

      return Quote(
        id: id,
        jobId: data['jobId'] as String? ?? '',
        photographerId: data['photographerId'] as String? ?? id,
        customerId: data['customerId'] as String? ?? '',
        jobTitle: data['jobTitle'] as String? ?? '',
        photographer: photographer,
        basedOnServiceId: data['basedOnServiceId'] as String?,
        terms: terms,
        milestoneAmounts: milestoneAmounts,
        proposal: proposal,
        message: data['message'] as String? ?? '',
        albumId: data['albumId'] as String?,
        album: album,
        invited: data['invited'] == true,
        fit: (data['fit'] as num?)?.toInt() ?? 0,
        status: QuoteStatus.fromCode(data['status'] as String?),
        notSelectedReason: data['notSelectedReason'] as String?,
        autoWithdrawn: data['autoWithdrawn'] == true,
        declineReason: data['declineReason'] as String?,
        bookingId: data['bookingId'] as String?,
        withdrawnAt: _parseQuoteDate(data['withdrawnAt']),
        version: (data['version'] as num?)?.toInt() ?? 1,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toFirestore() => {
    'jobId': jobId,
    'photographerId': photographerId,
    'customerId': customerId,
    'jobTitle': jobTitle,
    'photographer': photographer.toJson(),
    'basedOnServiceId': basedOnServiceId,
    'terms': terms.toJson(),
    'milestoneAmounts': milestoneAmounts.toJson(),
    'proposal': proposal.toJson(),
    'message': message,
    'albumId': albumId,
    'album': album?.toJson(),
    'invited': invited,
    'fit': fit,
    'status': status.code,
    'notSelectedReason': notSelectedReason,
    'autoWithdrawn': autoWithdrawn,
    'declineReason': declineReason,
    'bookingId': bookingId,
    'withdrawnAt': withdrawnAt != null ? Timestamp.fromDate(withdrawnAt!) : null,
    'version': version,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}

@immutable
class JobInvite {
  const JobInvite({
    required this.id,
    required this.jobId,
    required this.photographerId,
    required this.customerId,
    required this.fit,
    required this.jobStatus,
    required this.createdAt,
    this.seenAt,
  });

  final String id;
  final String jobId;
  final String photographerId;
  final String customerId;
  final int fit;
  final String jobStatus; // 'open' | 'closed'
  final DateTime createdAt;
  final DateTime? seenAt;

  static JobInvite? fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    return JobInvite(
      id: id,
      jobId: data['jobId'] as String? ?? '',
      photographerId: data['photographerId'] as String? ?? id,
      customerId: data['customerId'] as String? ?? '',
      fit: (data['fit'] as num?)?.toInt() ?? 0,
      jobStatus: data['jobStatus'] as String? ?? 'open',
      createdAt: _parseQuoteDate(data['createdAt']) ?? DateTime.now().toUtc(),
      seenAt: _parseQuoteDate(data['seenAt']),
    );
  }
}

@immutable
class JobMatch {
  const JobMatch({
    required this.id,
    required this.jobId,
    required this.photographerId,
    required this.fit,
    required this.jobStatus,
    required this.createdAt,
  });

  final String id;
  final String jobId;
  final String photographerId;
  final int fit;
  final String jobStatus; // 'open' | 'closed'
  final DateTime createdAt;

  static JobMatch? fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    return JobMatch(
      id: id,
      jobId: data['jobId'] as String? ?? '',
      photographerId: data['photographerId'] as String? ?? id,
      fit: (data['fit'] as num?)?.toInt() ?? 0,
      jobStatus: data['jobStatus'] as String? ?? 'open',
      createdAt: _parseQuoteDate(data['createdAt']) ?? DateTime.now().toUtc(),
    );
  }
}

/// One item in the photographer's open jobs list (S16.02).
@immutable
class OpenJobItem {
  const OpenJobItem({
    required this.job,
    this.fit,
    this.invited = false,
    this.locked = false,
  });

  final Job job;
  final int? fit;
  final bool invited;

  /// True for an artist-only job when viewed by an individual photographer.
  final bool locked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenJobItem &&
          runtimeType == other.runtimeType &&
          job.id == other.job.id &&
          fit == other.fit &&
          invited == other.invited &&
          locked == other.locked;

  @override
  int get hashCode => Object.hash(job.id, fit, invited, locked);
}

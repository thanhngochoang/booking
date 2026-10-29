// lib/data/events/event_detail.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/organizer/organizer.dart';

/// A staff-entered question and answer shown on a platform-hosted event
/// (owner decision O2: no "ask first" chat for platform events).
@immutable
class EventFaq {
  const EventFaq({required this.question, required this.answer});

  final String question;
  final String answer;

  Map<String, Object?> toJson() => {'question': question, 'answer': answer};

  factory EventFaq.fromJson(Map<String, Object?> json) => EventFaq(
    question: json['question'] as String? ?? '',
    answer: json['answer'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is EventFaq && other.question == question && other.answer == answer;

  @override
  int get hashCode => Object.hash(question, answer);
}

/// Where a staff-created draft stands with the photographer it names (O1).
enum HostConsent {
  notRequired('not_required'),
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  expired('expired');

  const HostConsent(this.code);
  final String code;

  static HostConsent fromCode(String? code) => values.firstWhere(
    (c) => c.code == code,
    orElse: () => HostConsent.notRequired,
  );
}

/// Where an event happens (S12.01 "Địa điểm · bắt buộc", Decision 16).
enum VenueKind {
  managedSpot('managed_spot'),
  paidPlace('paid_place'),
  publicPlace('public');

  const VenueKind(this.code);
  final String code;

  static VenueKind? fromCode(Object? code) {
    for (final k in values) {
      if (k.code == code) return k;
    }
    return null;
  }
}

/// `ORGANIZER_TERMS_VERSION` (Decision 17): the organizer terms an S12.01 host
/// ticks; the server refuses a venue with any other version.
const organizerTermsVersion = '2026-10-18';

/// `events/{id}.venue`: the venue kind, its spot (managed spot), whether the
/// ticket price includes the entry fee (and the reference fee when not), the
/// public-place commitment and the organizer terms version.
@immutable
class EventVenue {
  const EventVenue({
    required this.kind,
    this.spotId,
    this.entryFeeIncluded = true,
    this.entryFeeVnd,
    this.commitmentAt,
    required this.termsVersion,
  });

  final VenueKind kind;
  final String? spotId;
  final bool entryFeeIncluded;

  /// Reference entry fee per guest (integer VND) when not included.
  final int? entryFeeVnd;

  /// When the host ticked "Tôi tự chịu trách nhiệm xin phép…" (public place).
  final DateTime? commitmentAt;

  /// `ORGANIZER_TERMS_VERSION` the host agreed to.
  final String termsVersion;

  Map<String, Object?> toJson() => {
    'kind': kind.code,
    'spotId': spotId,
    'entryFee': {'included': entryFeeIncluded, 'amountVnd': entryFeeVnd},
    'commitmentAt': commitmentAt?.toUtc().toIso8601String(),
    'termsVersion': termsVersion,
  };

  /// Reads the stored block or [toJson]'s; null when it has no known kind.
  static EventVenue? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = VenueKind.fromCode(raw['kind']);
    if (kind == null) return null;
    final fee = raw['entryFee'] is Map ? raw['entryFee'] as Map : const {};
    final at = raw['commitmentAt'];
    return EventVenue(
      kind: kind,
      spotId: raw['spotId'] is String && (raw['spotId'] as String).isNotEmpty
          ? raw['spotId'] as String
          : null,
      entryFeeIncluded: fee['included'] != false,
      entryFeeVnd: fee['amountVnd'] is num
          ? (fee['amountVnd'] as num).toInt()
          : null,
      // The server stores the instant as an ISO string (`Venue.commitmentAt`).
      commitmentAt: at is String
          ? DateTime.tryParse(at)?.toUtc()
          : at is DateTime
          ? at.toUtc()
          : null,
      termsVersion: raw['termsVersion'] is String
          ? raw['termsVersion'] as String
          : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EventVenue &&
      other.kind == kind &&
      other.spotId == spotId &&
      other.entryFeeIncluded == entryFeeIncluded &&
      other.entryFeeVnd == entryFeeVnd &&
      other.commitmentAt == commitmentAt &&
      other.termsVersion == termsVersion;

  @override
  int get hashCode => Object.hash(
    kind,
    spotId,
    entryFeeIncluded,
    entryFeeVnd,
    commitmentAt,
    termsVersion,
  );
}

/// The whole event as the event screens need it (S11.02, S11.05, S12.03).
///
/// A draft saved before its schedule was chosen has no dates: [endsAt] and
/// [registrationDeadline] then equal `summary.startsAt` and
/// `summary.hasSchedule` is false. `priceSet` / `capacitySet` tell a draft that
/// never chose these from one that chose "free" or a capacity.
@immutable
class EventDetail {
  const EventDetail({
    required this.summary,
    required this.description,
    required this.hashtag,
    required this.endsAt,
    required this.registrationDeadline,
    required this.createdBy,
    this.meetingPoint,
    this.hostAvatarUrl,
    this.chatId,
    this.postCount = 0,
    this.completedAt,
    this.faq = const [],
    this.hostConsent = HostConsent.notRequired,
    this.hostConsentExpiresAt,
    this.hashtagLocked = false,
    this.areaId,
    this.coverPath,
    this.priceSet = true,
    this.capacitySet = true,
    this.spotId,
    this.spotDecided = false,
    this.venue,
    this.venueConsent = HostConsent.notRequired,
    this.venueConsentExpiresAt,
    this.venueFeePerGuest = 0,
    this.entry,
  });

  final EventSummary summary;
  final String description;

  /// Display case, without the `#`.
  final String hashtag;

  /// UTC instants.
  final DateTime endsAt;
  final DateTime registrationDeadline;
  final String createdBy;
  final String? meetingPoint;
  final String? hostAvatarUrl;

  /// The group chat id (`event_{id}`), set when published.
  final String? chatId;

  /// Visible timeline posts.
  final int postCount;
  final DateTime? completedAt;

  /// Staff-entered Q&A (platform-hosted events only).
  final List<EventFaq> faq;
  final HostConsent hostConsent;
  final DateTime? hostConsentExpiresAt;
  final bool hashtagLocked;
  final String? areaId;
  final String? coverPath;
  final bool priceSet;
  final bool capacitySet;

  /// The photo spot the event is tagged with (S29); null = none.
  final String? spotId;

  /// The organizer made the S12.01 choice: a spot, or "Không thuộc điểm chụp
  /// nào". False for events made before S29 (the field is missing) and for a
  /// draft saved before the choice.
  final bool spotDecided;

  /// S30 (Decision 16): the venue block; null on events made before it.
  final EventVenue? venue;

  /// The spot manager's answer to an event at their managed spot (72 h).
  final HostConsent venueConsent;
  final DateTime? venueConsentExpiresAt;

  /// The venue fee inside the ticket price, per guest (integer VND; 0 none).
  final int venueFeePerGuest;

  /// The per-day rules of an entry event (`type == entry`); null otherwise.
  final EntryEvent? entry;

  bool get isEntry => summary.type == EventType.entry;

  String get id => summary.id;

  /// Mirrors the domain `isEventManager`: the hosting photographer or
  /// organizer, an admin, or the sales member who created the event. Gate
  /// staff are never managers (Decision 9).
  bool isManagedBy(String? uid, StaffRole? role) {
    if (uid == null) {
      return false;
    }
    if ((summary.hostType == HostType.photographer ||
            summary.hostType == HostType.organizer) &&
        summary.hostId == uid) {
      return true;
    }
    return role == StaffRole.admin ||
        (role == StaffRole.sales && createdBy == uid);
  }

  /// Mirrors the moderators the server gives the group chat at publish: the
  /// hosting photographer and whoever created the event. An admin who is
  /// neither is a manager but not in the chat (review M10).
  bool isGroupModerator(String? uid) {
    if (uid == null || uid.isEmpty) {
      return false;
    }
    return ((summary.hostType == HostType.photographer ||
                summary.hostType == HostType.organizer) &&
            summary.hostId == uid) ||
        createdBy == uid;
  }

  /// Registration is still possible (open, deadline not passed).
  bool canRegisterAt(DateTime now) =>
      summary.status == EventStatus.open &&
      summary.seatsLeft > 0 &&
      !now.isAfter(registrationDeadline);
}

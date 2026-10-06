// lib/data/events/event_detail.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_summary.dart';

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

  String get id => summary.id;

  /// Mirrors the domain `isEventManager`: the hosting photographer, an admin,
  /// or the sales member who created the event.
  bool isManagedBy(String? uid, StaffRole? role) {
    if (uid == null) {
      return false;
    }
    if (summary.hostType == HostType.photographer && summary.hostId == uid) {
      return true;
    }
    return role == StaffRole.admin ||
        (role == StaffRole.sales && createdBy == uid);
  }

  /// Registration is still possible (open, deadline not passed).
  bool canRegisterAt(DateTime now) =>
      summary.status == EventStatus.open &&
      summary.seatsLeft > 0 &&
      !now.isAfter(registrationDeadline);
}

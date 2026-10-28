// lib/data/spots/spot_repository.dart
import 'dart:io' show SocketException;

import 'package:cloud_functions/cloud_functions.dart'
    show FirebaseFunctionsException;
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_rules.dart';

abstract class SpotRepository {
  /// Reads ranking entries: `spot_rankings/{key}`; falls back to `spot_rankings/all` if missing.
  Future<List<SpotEntry>> hot(String key);

  /// Reads directory entries from `spot_directory/all`.
  Future<List<SpotEntry>> directory();

  /// Gets a single spot by id.
  Future<Spot?> spot(String spotId);

  /// Open schedules at a spot (`spotId == id, status == open`).
  Future<List<SpotSchedule>> openSchedulesAt(String spotId);

  /// Open slot offers at a spot (`spotId == id, status == open`).
  Future<List<SlotOffer>> openOffersAt(String spotId);

  /// Public availability projection `spot_days/{scheduleId}_{day}`.
  Future<SpotDay?> spotDay(String scheduleId, String day);

  /// Gets a single schedule by id.
  Future<SpotSchedule?> schedule(String scheduleId);

  /// Gets a single offer by id.
  Future<SlotOffer?> offer(String offerId);

  /// Posts tagged at a spot, ordered by `createdAt` desc, 20 per page.
  Future<List<PostSummary>> postsAt(
    String spotId, {
    DateTime? before,
    int limit = 20,
  });

  /// Upcoming events at a spot (`status in [open, full]`, `startAt >= now`).
  /// Entry-ticket events are never listed (Decision 11): S29.02 shows the
  /// spot's entry event through [watchEntryEvent].
  Future<List<EventSummary>> eventsAt(String spotId, {int limit = 10});

  /// The spot's resident photographers (`spots/{id}/residents`, S29.02,
  /// S30.03), expired rows included: callers apply `Resident.waiverFor`.
  Stream<List<Resident>> watchResidents(String spotId);

  /// The spot's entry-ticket event on sale: `events` where `type == entry`,
  /// `spotId == id`, `status in [open, full]` (index `type, spotId, status`);
  /// null when it sells none.
  Stream<EntryEvent?> watchEntryEvent(String spotId);

  /// Watches provider's open schedules (`providerId == uid, status == open`).
  Stream<List<SpotSchedule>> watchMine(String uid);

  /// Watches provider's open offers (`providerId == uid, status == open`).
  Stream<List<SlotOffer>> watchMyOffers(String uid);

  /// Creates or updates a spot schedule.
  Future<({String scheduleId, List<String> addedDays})> saveSchedule(
    SpotScheduleInput input,
  );

  /// Cancels a spot schedule.
  Future<void> cancelSchedule(String scheduleId);

  /// Creates a slot offer.
  Future<String> saveOffer(SlotOfferInput input);

  /// Closes a slot offer.
  Future<void> closeOffer(String offerId);
}

@immutable
class SpotScheduleInput {
  const SpotScheduleInput({
    this.scheduleId,
    required this.spotId,
    required this.days,
    required this.window,
    required this.serviceIds,
    this.assigneeId,
  });

  final String? scheduleId;
  final String spotId;
  final List<String> days;
  final SpotWindow window;
  final List<String> serviceIds;
  final String? assigneeId;

  Map<String, dynamic> toCallable() => {
    if (scheduleId != null) 'scheduleId': scheduleId,
    'spotId': spotId,
    'days': days,
    'window': {'start': window.start, 'end': window.end},
    'serviceIds': serviceIds,
    if (assigneeId != null) 'assigneeId': assigneeId,
  };
}

@immutable
class SlotOfferInput {
  const SlotOfferInput({
    this.offerId,
    required this.scheduleId,
    required this.name,
    required this.price,
    required this.slotMinutes,
    required this.gapMinutes,
    required this.photoCount,
    required this.editedCount,
    required this.deliveryDays,
  });

  final String? offerId;
  final String scheduleId;
  final String name;
  final int price;
  final int slotMinutes;
  final int gapMinutes;
  final int photoCount;
  final int editedCount;
  final int deliveryDays;

  Map<String, dynamic> toCallable() => {
    if (offerId != null) 'offerId': offerId,
    'scheduleId': scheduleId,
    'name': name,
    'price': price,
    'slotMinutes': slotMinutes,
    'gapMinutes': gapMinutes,
    'photoCount': photoCount,
    'editedCount': editedCount,
    'deliveryDays': deliveryDays,
  };
}

enum SpotErrorCode {
  invalidArgument,
  contactLeak,
  notAcceptingOrders,
  notFound,
  permissionDenied,
  spotArchived,
  scheduleLimit,
  dayConflict,
  scheduleHasBookings,
  limitExceeded,
  network,
  unknown,
}

@immutable
class SpotError implements Exception {
  const SpotError(
    this.code, {
    this.field,
    this.conflicts = const {},
    this.bookingCounts = const {},
  });

  final SpotErrorCode code;
  final String? field;
  final Map<String, SpotDayConflictReason> conflicts;
  final Map<String, int> bookingCounts;

  @override
  String toString() =>
      'SpotError($code, field: $field, conflicts: $conflicts, bookingCounts: $bookingCounts)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotError &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          field == other.field &&
          mapEquals(conflicts, other.conflicts) &&
          mapEquals(bookingCounts, other.bookingCounts);

  @override
  int get hashCode => Object.hash(
    code,
    field,
    Object.hashAll(conflicts.entries),
    Object.hashAll(bookingCounts.entries),
  );
}

SpotError spotErrorOf(Object error) {
  if (error is SocketException) {
    return const SpotError(SpotErrorCode.network);
  }
  if (error is SpotError) {
    return error;
  }
  if (error is FirebaseFunctionsException) {
    if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
      return const SpotError(SpotErrorCode.network);
    }
    final details = error.details;
    if (details is Map) {
      final code = details['code'] as String?;
      final field = details['field'] as String?;
      if (code != null) {
        return _codeToSpotError(code, field: field, details: details);
      }
    }
    if (error.message != null) {
      return _codeToSpotError(error.message!);
    }
  }
  final errType = error.runtimeType.toString();
  if (errType.contains('FunctionsException')) {
    dynamic dyn = error;
    try {
      final code = dyn.code;
      if (code == 'unavailable' || code == 'deadline-exceeded') {
        return const SpotError(SpotErrorCode.network);
      }
      final details = dyn.details;
      if (details is Map) {
        final dCode = details['code'] as String?;
        final dField = details['field'] as String?;
        if (dCode != null) {
          return _codeToSpotError(dCode, field: dField, details: details);
        }
      }
      if (dyn.message is String) {
        return _codeToSpotError(dyn.message as String);
      }
    } catch (_) {}
  }
  return const SpotError(SpotErrorCode.unknown);
}

SpotError _codeToSpotError(
  String code, {
  String? field,
  Map? details,
}) {
  switch (code) {
    case 'invalid_argument':
    case 'invalid-argument':
      return SpotError(SpotErrorCode.invalidArgument, field: field);
    case 'contact_leak':
      return SpotError(SpotErrorCode.contactLeak, field: field);
    case 'not_accepting_orders':
      // field `assigneeId`: the studio's chosen member is the one refused.
      return SpotError(SpotErrorCode.notAcceptingOrders, field: field);
    case 'not_found':
    case 'not-found':
      return SpotError(SpotErrorCode.notFound, field: field);
    case 'permission_denied':
    case 'permission-denied':
      return const SpotError(SpotErrorCode.permissionDenied);
    case 'spot_archived':
      return const SpotError(SpotErrorCode.spotArchived);
    case 'schedule_limit':
      return const SpotError(SpotErrorCode.scheduleLimit);
    case 'limit_exceeded':
      return const SpotError(SpotErrorCode.limitExceeded);
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network':
      return const SpotError(SpotErrorCode.network);
    case 'day_conflict':
      final conflicts = <String, SpotDayConflictReason>{};
      final days = details?['days'];
      if (days is List) {
        for (final item in days) {
          if (item is Map) {
            final day = item['day'] as String?;
            final reason = item['reason'] as String?;
            if (day != null && reason != null) {
              conflicts[day] = switch (reason) {
                'pending' => SpotDayConflictReason.pending,
                'off' => SpotDayConflictReason.off,
                'spot' => SpotDayConflictReason.spot,
                'full' => SpotDayConflictReason.full,
                _ => SpotDayConflictReason.booked,
              };
            }
          }
        }
      }
      return SpotError(
        SpotErrorCode.dayConflict,
        field: field,
        conflicts: conflicts,
      );
    case 'schedule_has_bookings':
      final bookingCounts = <String, int>{};
      final days = details?['days'];
      if (days is List) {
        for (final item in days) {
          if (item is Map) {
            final day = item['day'] as String?;
            final count = (item['count'] as num?)?.toInt() ?? 0;
            if (day != null) {
              bookingCounts[day] = count;
            }
          }
        }
      }
      return SpotError(
        SpotErrorCode.scheduleHasBookings,
        bookingCounts: bookingCounts,
      );
    default:
      return const SpotError(SpotErrorCode.unknown);
  }
}

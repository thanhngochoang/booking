// lib/data/organizer/organizer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:photobooking/core/vn_time.dart';
import 'package:photobooking/data/events/event_summary.dart';

part 'organizer.freezed.dart';

/// S30 (#223) read models: organizers, spot access, residents, gate staff,
/// spot claims, entry events and their days. The server writes every one of
/// these documents (rules: `write: if false`); the mappers below read the
/// shapes of `infra/organizer_firestore.ts`, `spot_firestore.ts` and
/// `event_firestore.ts`, and the `toCallable` helpers build what the S30
/// callables take back.

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is DateTime) return v.toUtc();
  if (v is String) return DateTime.tryParse(v)?.toUtc();
  return null;
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
int? _intOrNull(Object? v) => v is num ? v.toInt() : null;
List<String> _strings(Object? v) =>
    v is List ? v.whereType<String>().toList() : const [];
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

// ---- organizers/{uid} -------------------------------------------------------

enum OrganizerStatus { active, suspended }

@freezed
abstract class Organizer with _$Organizer {
  const Organizer._();

  const factory Organizer({
    required String id,
    required String name,
    @Default('') String bio,
    String? avatarUrl,
    required OrganizerStatus status,
    @Default(false) bool phoneVerified,
    @Default(false) bool businessVerified,
    @Default(false) bool payoutAccountOk,
    @Default(<String>[]) List<String> managedSpotIds,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Organizer;

  /// Mirrors the domain `canSell` (Decision 3): paid tickets, priced events
  /// and a venue fee need an active organizer with a verified business and a
  /// payout account.
  bool get canSell =>
      status == OrganizerStatus.active && businessVerified && payoutAccountOk;

  bool get isActive => status == OrganizerStatus.active;
}

/// `organizers/{uid}`; null when missing. An unknown status is suspended.
Organizer? organizerFromFirestore(String id, Map<String, dynamic>? d) {
  if (d == null) return null;
  final createdAt = _date(d['createdAt']) ?? _epoch;
  return Organizer(
    id: id,
    name: d['name'] is String ? d['name'] as String : '',
    bio: d['bio'] is String ? d['bio'] as String : '',
    avatarUrl: _str(d['avatarUrl']),
    status: d['status'] == 'active'
        ? OrganizerStatus.active
        : OrganizerStatus.suspended,
    phoneVerified: d['phoneVerified'] == true,
    businessVerified: d['businessVerified'] == true,
    payoutAccountOk: d['payoutAccountOk'] == true,
    managedSpotIds: _strings(d['managedSpotIds']),
    createdAt: createdAt,
    updatedAt: _date(d['updatedAt']) ?? createdAt,
  );
}

// ---- spots/{id}.access and openHours ---------------------------------------

@freezed
abstract class OpenHours with _$OpenHours {
  const OpenHours._();

  /// `HH:mm` in Vietnam time.
  const factory OpenHours({required String start, required String end}) =
      _OpenHours;

  Map<String, Object?> toCallable() => {'start': start, 'end': end};
}

OpenHours? openHoursFromFirestore(Object? v) {
  final m = _map(v);
  final start = _str(m['start']);
  final end = _str(m['end']);
  return start == null || end == null
      ? null
      : OpenHours(start: start, end: end);
}

enum SpotAccessType {
  open('open'),
  ticket('ticket');

  const SpotAccessType(this.code);
  final String code;
}

enum SpotAccessSource { staff, organizer }

@freezed
abstract class AccessFee with _$AccessFee {
  const AccessFee._();

  const factory AccessFee({required String label, required int amountVnd}) =
      _AccessFee;

  Map<String, Object?> toCallable() => {'label': label, 'amountVnd': amountVnd};
}

/// The entry fee a spot asks for (S29.02 "Vào cửa"): reference prices typed
/// by staff or the spot's manager. `updatedAt`/`source` are null on a block
/// the app is about to send (the server stamps them).
@freezed
abstract class SpotAccess with _$SpotAccess {
  const SpotAccess._();

  const factory SpotAccess({
    required SpotAccessType type,
    @Default(<AccessFee>[]) List<AccessFee> fees,
    @Default('') String note,
    DateTime? updatedAt,
    SpotAccessSource? source,
  }) = _SpotAccess;

  /// The `access` block of `updateManagedSpot` (the server validates it with
  /// `validateAccess`: ≤ 6 fees, note ≤ 120).
  Map<String, Object?> toCallable() => {
    'type': type.code,
    'fees': [for (final f in fees) f.toCallable()],
    'note': note,
  };
}

/// `spots/{id}.access`; a malformed block reads as null (as on the server).
SpotAccess? spotAccessFromFirestore(Object? v) {
  if (v is! Map) return null;
  final type = switch (v['type']) {
    'open' => SpotAccessType.open,
    'ticket' => SpotAccessType.ticket,
    _ => null,
  };
  final source = switch (v['source']) {
    'staff' => SpotAccessSource.staff,
    'organizer' => SpotAccessSource.organizer,
    _ => null,
  };
  final updatedAt = _date(v['updatedAt']);
  if (type == null || source == null || updatedAt == null) return null;
  final fees = <AccessFee>[];
  final raw = v['fees'];
  if (raw is List) {
    for (final f in raw) {
      if (f is Map && f['label'] is String && f['amountVnd'] is num) {
        fees.add(
          AccessFee(
            label: f['label'] as String,
            amountVnd: (f['amountVnd'] as num).toInt(),
          ),
        );
      }
    }
  }
  return SpotAccess(
    type: type,
    fees: fees,
    note: v['note'] is String ? v['note'] as String : '',
    updatedAt: updatedAt,
    source: source,
  );
}

// ---- spots/{spotId}/residents/{providerId} ---------------------------------

/// What a resident's waiver lets in today (domain `waiverFor`).
typedef Waiver = ({bool provider, bool guests, int? maxGuests});

@freezed
abstract class Resident with _$Resident {
  const Resident._();

  const factory Resident({
    required String providerId,
    required bool waivesProvider,
    required bool waivesGuests,
    int? maxGuests,

    /// Last valid Vietnam day `yyyy-MM-dd`; null = no end.
    String? validUntil,
    DateTime? addedAt,
    String? addedBy,
  }) = _Resident;

  /// No waiver after [validUntil] (the `rankSpots` job deletes the row later,
  /// so the date is checked here too, Decision 5).
  Waiver waiverFor(String today) {
    final end = validUntil;
    if (end != null && end.compareTo(today) < 0) {
      return (provider: false, guests: false, maxGuests: null);
    }
    return (
      provider: waivesProvider,
      guests: waivesGuests,
      maxGuests: waivesGuests ? maxGuests : null,
    );
  }

  /// The `saveResident` payload.
  Map<String, Object?> toCallable(String spotId) => {
    'spotId': spotId,
    'providerId': providerId,
    'waivesProvider': waivesProvider,
    'waivesGuests': waivesGuests,
    'maxGuests': maxGuests,
    'validUntil': validUntil,
  };
}

Resident? residentFromFirestore(String providerId, Map<String, dynamic>? d) {
  if (d == null) return null;
  return Resident(
    providerId: providerId,
    waivesProvider: d['waivesProvider'] == true,
    waivesGuests: d['waivesGuests'] == true,
    maxGuests: _intOrNull(d['maxGuests']),
    validUntil: _str(d['validUntil']),
    addedAt: _date(d['addedAt']),
    addedBy: _str(d['addedBy']),
  );
}

// ---- organizers/{uid}/gate_staff/{staffUid} --------------------------------

enum GateStaffStatus { invited, active, removed }

/// An invite stays open 72 h (`GATE_INVITE_HOURS`).
const gateInviteValidity = Duration(hours: 72);

@freezed
abstract class GateStaff with _$GateStaff {
  const GateStaff._();

  const factory GateStaff({
    required String organizerId,
    required String staffUid,
    required GateStaffStatus status,
    required DateTime invitedAt,
    DateTime? respondedAt,

    /// `scansToday {day, count}`: the count belongs to [scansDay] only.
    String? scansDay,
    @Default(0) int scansCount,
  }) = _GateStaff;

  /// S30.06 "{n} mã hôm nay": 0 unless the counter is of [today].
  int scansOn(String today) => scansDay == today ? scansCount : 0;

  /// Mirrors the domain `inviteOpen`.
  bool inviteOpen(DateTime now) =>
      status == GateStaffStatus.invited &&
      now.toUtc().isBefore(invitedAt.add(gateInviteValidity));

  /// Mirrors the domain `holdsGateSeat`: active staff and invites still open
  /// count towards the 10 seats; an expired invite frees its seat.
  bool holdsSeat(DateTime now) =>
      status == GateStaffStatus.active || inviteOpen(now);
}

GateStaff? gateStaffFromFirestore(
  String organizerId,
  String staffUid,
  Map<String, dynamic>? d,
) {
  if (d == null) return null;
  final status = switch (d['status']) {
    'invited' => GateStaffStatus.invited,
    'active' => GateStaffStatus.active,
    _ => GateStaffStatus.removed,
  };
  final scans = _map(d['scansToday']);
  return GateStaff(
    organizerId: _str(d['organizerId']) ?? organizerId,
    staffUid: _str(d['staffUid']) ?? staffUid,
    status: status,
    invitedAt: _date(d['invitedAt']) ?? _epoch,
    respondedAt: _date(d['respondedAt']),
    scansDay: _str(scans['day']),
    scansCount: _intOrNull(scans['count']) ?? 0,
  );
}

// ---- spot_claims/{id} -------------------------------------------------------

enum SpotClaimStatus { pending, approved, rejected }

@freezed
abstract class SpotProposal with _$SpotProposal {
  const SpotProposal._();

  /// "Gửi đề xuất điểm mới": a place that is not a spot yet.
  const factory SpotProposal({required String name, required String address}) =
      _SpotProposal;

  Map<String, Object?> toCallable() => {'name': name, 'address': address};
}

@freezed
abstract class SpotClaim with _$SpotClaim {
  const factory SpotClaim({
    required String id,

    /// Null for a proposal.
    String? spotId,
    SpotProposal? proposal,
    required String organizerId,
    required SpotClaimStatus status,
    @Default(<String>[]) List<String> proofPaths,
    @Default('') String note,
    String? reason,
    required DateTime createdAt,
    DateTime? reviewedAt,
  }) = _SpotClaim;
}

SpotClaim? spotClaimFromFirestore(String id, Map<String, dynamic>? d) {
  if (d == null) return null;
  final status = switch (d['status']) {
    'pending' => SpotClaimStatus.pending,
    'approved' => SpotClaimStatus.approved,
    _ => SpotClaimStatus.rejected,
  };
  final p = d['proposal'];
  return SpotClaim(
    id: id,
    spotId: _str(d['spotId']),
    proposal: p is Map
        ? SpotProposal(
            name: p['name'] is String ? p['name'] as String : '',
            address: p['address'] is String ? p['address'] as String : '',
          )
        : null,
    organizerId: _str(d['organizerId']) ?? '',
    status: status,
    proofPaths: _strings(d['proofPaths']),
    note: d['note'] is String ? d['note'] as String : '',
    reason: _str(d['reason']),
    createdAt: _date(d['createdAt']) ?? _epoch,
    reviewedAt: _date(d['reviewedAt']),
  );
}

// ---- entry events (events/{id} with type entry) ----------------------------

@freezed
abstract class EntryTicketType with _$EntryTicketType {
  const EntryTicketType._();

  /// [id] is empty for a new type (the server names it); [price] integer VND.
  const factory EntryTicketType({
    required String id,
    required String name,
    required int price,
    @Default(false) bool hidden,
  }) = _EntryTicketType;

  Map<String, Object?> toCallable() => {
    if (id.isNotEmpty) 'id': id,
    'name': name,
    'price': price,
    'hidden': hidden,
  };
}

/// One line of a ticket order (`registerEntry`, `createBooking.entry`).
@freezed
abstract class EntryItem with _$EntryItem {
  const EntryItem._();

  const factory EntryItem({required String ticketTypeId, required int qty}) =
      _EntryItem;

  Map<String, Object?> toCallable() => {
    'ticketTypeId': ticketTypeId,
    'qty': qty,
  };
}

/// A priced line as stored on a registration or a booking's `entry`.
@freezed
abstract class EntryLine with _$EntryLine {
  const EntryLine._();

  const factory EntryLine({
    required String ticketTypeId,
    required String name,
    required int price,
    required int qty,
  }) = _EntryLine;

  int get amount => price * qty;
}

List<EntryLine> entryLinesFrom(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final i in raw)
      if (i is Map &&
          i['ticketTypeId'] is String &&
          i['price'] is num &&
          i['qty'] is num)
        EntryLine(
          ticketTypeId: i['ticketTypeId'] as String,
          name: i['name'] is String ? i['name'] as String : '',
          price: (i['price'] as num).toInt(),
          qty: (i['qty'] as num).toInt(),
        ),
  ];
}

/// An organizer's entry-ticket event (Decision 11): sold per visit day of the
/// sale range [startDay]…[endDay] (Vietnam days), closed on [closedWeekdays]
/// (0 = Sunday, as the domain's `weekdayOf`) and [closedDays].
@freezed
abstract class EntryEvent with _$EntryEvent {
  const EntryEvent._();

  const factory EntryEvent({
    required String id,
    required String title,
    required String spotId,
    required String organizerId,
    @Default('') String organizerName,
    required EventStatus status,
    required String startDay,
    required String endDay,
    @Default(<int>[]) List<int> closedWeekdays,
    @Default(<String>[]) List<String> closedDays,
    required OpenHours openHours,
    @Default(<EntryTicketType>[]) List<EntryTicketType> ticketTypes,
    int? dailyCapacity,
    @Default(48) int refundCutoffHours,
  }) = _EntryEvent;

  /// What S30.05 and S29.02 offer (hidden types stay for sold tickets).
  List<EntryTicketType> get visibleTicketTypes => [
    for (final t in ticketTypes)
      if (!t.hidden) t,
  ];

  /// Mirrors the domain `isOpenDay`.
  bool isOpenDay(String day) {
    final date = parseDayKey(day);
    if (date == null) return false;
    if (day.compareTo(startDay) < 0 || day.compareTo(endDay) > 0) return false;
    final weekday = date.weekday % 7; // DateTime: Monday 1 … Sunday 7
    return !closedWeekdays.contains(weekday) && !closedDays.contains(day);
  }

  /// Mirrors the domain `openDays`: up to [count] open days from [from] (or
  /// the range start, whichever is later).
  List<String> openDays(String from, int count) {
    final out = <String>[];
    var day = from.compareTo(startDay) < 0 ? startDay : from;
    var date = parseDayKey(day);
    while (date != null && out.length < count && day.compareTo(endDay) <= 0) {
      if (isOpenDay(day)) out.add(day);
      date = date.add(const Duration(days: 1));
      day = dayKeyOf(date);
    }
    return out;
  }
}

/// `events/{id}` of type `entry`; null for any other event or a malformed one.
EntryEvent? entryEventFromFirestore(String id, Map<String, dynamic>? d) {
  if (d == null || d['type'] != 'entry') return null;
  final spotId = _str(d['spotId']);
  final startAt = _date(d['startAt']);
  final endAt = _date(d['endAt']);
  final hours = openHoursFromFirestore(d['openHours']);
  if (spotId == null || startAt == null || endAt == null || hours == null) {
    return null;
  }
  final host = _map(d['host']);
  final types = <EntryTicketType>[];
  final raw = d['ticketTypes'];
  if (raw is List) {
    for (final t in raw) {
      if (t is Map && t['id'] is String && t['price'] is num) {
        types.add(
          EntryTicketType(
            id: t['id'] as String,
            name: t['name'] is String ? t['name'] as String : '',
            price: (t['price'] as num).toInt(),
            hidden: t['hidden'] == true,
          ),
        );
      }
    }
  }
  return EntryEvent(
    id: id,
    title: d['title'] is String ? d['title'] as String : '',
    spotId: spotId,
    organizerId: _str(host['id']) ?? '',
    organizerName: _str(host['name']) ?? '',
    status: EventStatus.fromCode(_str(d['status'])),
    // `entryRangeDays`: start 00:00 VN of the first day, end 00:00 VN of the
    // day after the last one.
    startDay: vnDateKey(startAt),
    endDay: vnDateKey(endAt.subtract(const Duration(milliseconds: 1))),
    closedWeekdays: d['closedWeekdays'] is List
        ? (d['closedWeekdays'] as List)
              .whereType<num>()
              .map((n) => n.toInt())
              .toList()
        : const [],
    closedDays: _strings(d['closedDays']),
    openHours: hours,
    ticketTypes: types,
    dailyCapacity: _intOrNull(d['dailyCapacity']),
    refundCutoffHours: _intOrNull(d['refundCutoffHours']) ?? 48,
  );
}

/// `entry_days/{eventId}_{day}`: the day's counters (server-written).
@freezed
abstract class EntryDay with _$EntryDay {
  const EntryDay._();

  const factory EntryDay({
    required String eventId,
    required String day,
    @Default(0) int sold,
    @Default(0) int held,
    @Default(0) int checkedIn,
    @Default(false) bool closed,
  }) = _EntryDay;

  /// Tickets still for sale under [capacity]; null without a cap.
  int? left(int? capacity) {
    if (capacity == null) return null;
    final n = capacity - sold - held;
    return n < 0 ? 0 : n;
  }
}

EntryDay? entryDayFromFirestore(Map<String, dynamic>? d) {
  if (d == null) return null;
  final eventId = _str(d['eventId']);
  final day = _str(d['day']);
  if (eventId == null || day == null) return null;
  return EntryDay(
    eventId: eventId,
    day: day,
    sold: _intOrNull(d['sold']) ?? 0,
    held: _intOrNull(d['held']) ?? 0,
    checkedIn: _intOrNull(d['checkedIn']) ?? 0,
    closed: d['closed'] == true,
  );
}

// lib/features/booking/booking_flow_state.dart
import 'package:flutter/widgets.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/phone.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_rules.dart';

enum BookingStep { service, datetime, place, review }

@immutable
class BookingFlowArgs {
  const BookingFlowArgs({
    required this.photographerId,
    this.serviceId,
    this.day,
    this.area,
    this.scheduleId,
    this.slotOfferId,
    this.start,
  });

  final String photographerId;
  final String? serviceId;
  final String? day;
  final String? area;
  final String? scheduleId;
  final String? slotOfferId;
  final String? start;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingFlowArgs &&
          runtimeType == other.runtimeType &&
          photographerId == other.photographerId &&
          serviceId == other.serviceId &&
          day == other.day &&
          area == other.area &&
          scheduleId == other.scheduleId &&
          slotOfferId == other.slotOfferId &&
          start == other.start;

  @override
  int get hashCode => Object.hash(
        photographerId,
        serviceId,
        day,
        area,
        scheduleId,
        slotOfferId,
        start,
      );
}

enum SubmitPhase { idle, creating, paying, done }

/// What a booking from a spot (S29.02 "Đặt", S29.06 "Chọn suất") is limited
/// to: the schedule's packages, days and window; the place is the spot
/// (Decision 9). With [offer] it is a slot booking: no add-ons (T6).
@immutable
class SpotBookingContext {
  const SpotBookingContext({
    required this.schedule,
    required this.spotName,
    required this.lat,
    required this.lng,
    this.offer,
    this.takenByDay = const {},
    this.failedDays = const {},
    this.archived = false,
  });

  final SpotSchedule schedule;
  final String spotName;
  final double lat;
  final double lng;
  final SlotOffer? offer;

  /// `spot_days/{scheduleId}_{day}.taken` of the days read so far.
  final Map<String, List<SpotInterval>> takenByDay;

  /// Days whose `spot_days` read failed (S04.02 offers a retry).
  final Set<String> failedDays;
  final bool archived;

  /// Packages the schedule takes: [ServiceSummary] ids in
  /// `serviceIds`, or every active package when it is empty.
  List<ServiceSummary> packagesOf(List<ServiceSummary> all) {
    final ids = schedule.serviceIds;
    if (ids.isEmpty) return [for (final s in all) if (s.active) s];
    return [for (final s in all) if (s.active && ids.contains(s.id)) s];
  }

  /// The schedule's days from [today] (`yyyy-MM-dd`) on; none once closed.
  List<String> daysFrom(String today) => schedule.open
      ? ([for (final d in schedule.days) if (d.compareTo(today) >= 0) d]
          ..sort())
      : const [];

  SpotBookingContext copyWith({
    SpotSchedule? schedule,
    String? spotName,
    double? lat,
    double? lng,
    SlotOffer? offer,
    Map<String, List<SpotInterval>>? takenByDay,
    Set<String>? failedDays,
    bool? archived,
  }) {
    return SpotBookingContext(
      schedule: schedule ?? this.schedule,
      spotName: spotName ?? this.spotName,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      offer: offer ?? this.offer,
      takenByDay: takenByDay ?? this.takenByDay,
      failedDays: failedDays ?? this.failedDays,
      archived: archived ?? this.archived,
    );
  }
}

@immutable
class BookingFlowState {
  const BookingFlowState({
    required this.step,
    this.serviceId,
    this.priceVnd,
    this.durationMinutes,
    this.serviceName,
    this.day,
    this.start,
    this.placeName = '',
    this.note = '',
    this.phone,
    this.method = PayMethod.bankQr,
    this.phase = SubmitPhase.idle,
    this.error,
    this.takenDays = const {},
    this.priceChanged = false,
    this.bookingId,
    this.paymentId,
    this.addons = const [],
    this.picks = const {},
    this.pickupName = '',
    this.droppedAddonNames = const [],
    this.spot,
  });

  final BookingStep step;
  final String? serviceId;
  final int? priceVnd;
  final int? durationMinutes;
  final String? serviceName;
  final String? day;
  final String? start;
  final String placeName;
  final String note;
  final String? phone;
  final PayMethod method;
  final SubmitPhase phase;
  final BookingErrorCode? error;
  final Set<String> takenDays;
  final bool priceChanged;
  final String? bookingId;
  final String? paymentId;

  /// Every active add-on of the photographer (S04.01), as last loaded.
  final List<ServiceAddon> addons;

  /// Chosen add-ons: addonId → quantity (always > 0).
  final Map<String, int> picks;

  /// "Điểm đón" (S04.06); asked and sent only with a transport add-on.
  final String pickupName;

  /// Names of picks dropped by the last package change; the sheet shows them
  /// once and calls `consumeDropped`.
  final List<String> droppedAddonNames;

  /// Set when booking from a spot (S29.02, S29.06).
  final SpotBookingContext? spot;

  /// A slot-offer booking (S29.06): opens on S04.03, no add-ons or pickup.
  bool get isSlot => spot?.offer != null;

  bool get hasChoices =>
      serviceId != null ||
      day != null ||
      start != null ||
      (spot == null && placeName.isNotEmpty) || // a spot's place is given
      note.isNotEmpty ||
      picks.isNotEmpty ||
      pickupName.isNotEmpty;

  /// Add-ons that apply to the chosen package, grouped in kind order.
  List<ServiceAddon> get applicableAddons {
    final id = serviceId;
    if (id == null || isSlot) return const []; // T6: slots carry no add-ons
    return [
      for (final kind in AddonKind.values)
        ...addons.where((a) => a.kind == kind && a.appliesTo(id)),
    ];
  }

  /// Display sum of the picks; the server prices the booking (Decision 4).
  int get addonsVnd {
    var sum = 0;
    for (final a in addons) {
      final qty = picks[a.id];
      if (qty != null) sum += a.price * qty;
    }
    return sum;
  }

  /// Package + add-ons; null until a package is chosen.
  int? get totalVnd => priceVnd != null ? priceVnd! + addonsVnd : null;

  /// The picked transport add-on, if any: it makes S04.06 ask for a pickup.
  ServiceAddon? get transportAddon {
    for (final a in addons) {
      if (a.kind == AddonKind.transport && picks.containsKey(a.id)) return a;
    }
    return null;
  }

  bool get needsPickup => transportAddon != null;

  /// What the customer pays when booking: the whole total (payments spec M2).
  int? get payVnd => totalVnd != null ? depositFor(totalVnd!).deposit : null;

  /// S04.02 at a spot: start times on the chosen day that fit the package in
  /// the schedule's window around the taken intervals (≥ 15 min apart) and
  /// lie after [now]; null until that day's `spot_days` is read.
  List<String>? availableStarts(DateTime now) {
    final ctx = spot;
    final d = day;
    final minutes = durationMinutes;
    if (ctx == null || d == null || minutes == null) return null;
    final taken = ctx.takenByDay[d];
    if (taken == null) return null;
    return [
      for (final t in freeStartTimes(ctx.schedule.window, minutes, taken))
        if (BookingRules.parseBookingDateTime(d, t).isAfter(now)) t,
    ];
  }

  String? get end => (start != null && durationMinutes != null)
      ? endTimeFor(start!, durationMinutes!)
      : null;

  /// True from the tap on pay until S04.04 replaces the sheet, so a second tap
  /// cannot start another payment while the first outcome is being handled.
  bool get busy => phase != SubmitPhase.idle;

  bool get canContinue {
    switch (step) {
      case BookingStep.service:
        return serviceId != null;
      case BookingStep.datetime:
        return day != null && start != null;
      case BookingStep.place:
        return placeName.characters.length >= kPlaceMinLength &&
            (!needsPickup ||
                pickupName.trim().characters.length >= kPlaceMinLength);
      case BookingStep.review:
        final p = phone;
        if (p == null || busy) return false;
        if (serviceId == null || day == null || start == null) return false;
        return normalizePhone(p, international: true) != null ||
            phoneFromField(p) != null;
    }
  }

  BookingFlowState copyWith({
    BookingStep? step,
    String? serviceId,
    bool clearServiceId = false,
    int? priceVnd,
    int? durationMinutes,
    String? serviceName,
    String? day,
    bool clearDay = false,
    String? start,
    bool clearStart = false,
    String? placeName,
    String? note,
    String? phone,
    bool clearPhone = false,
    PayMethod? method,
    SubmitPhase? phase,
    BookingErrorCode? error,
    bool clearError = false,
    Set<String>? takenDays,
    bool? priceChanged,
    String? bookingId,
    bool? clearBookingId,
    String? paymentId,
    List<ServiceAddon>? addons,
    Map<String, int>? picks,
    String? pickupName,
    List<String>? droppedAddonNames,
    SpotBookingContext? spot,
  }) {
    return BookingFlowState(
      step: step ?? this.step,
      serviceId: clearServiceId ? null : (serviceId ?? this.serviceId),
      priceVnd: clearServiceId ? null : (priceVnd ?? this.priceVnd),
      durationMinutes:
          clearServiceId ? null : (durationMinutes ?? this.durationMinutes),
      serviceName: clearServiceId ? null : (serviceName ?? this.serviceName),
      day: clearDay ? null : (day ?? this.day),
      start: clearStart ? null : (start ?? this.start),
      placeName: placeName ?? this.placeName,
      note: note ?? this.note,
      phone: clearPhone ? null : (phone ?? this.phone),
      method: method ?? this.method,
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
      takenDays: takenDays ?? this.takenDays,
      priceChanged: priceChanged ?? this.priceChanged,
      bookingId: clearBookingId == true ? null : (bookingId ?? this.bookingId),
      paymentId: paymentId ?? this.paymentId,
      addons: addons ?? this.addons,
      picks: picks ?? this.picks,
      pickupName: pickupName ?? this.pickupName,
      droppedAddonNames: droppedAddonNames ?? this.droppedAddonNames,
      spot: spot ?? this.spot,
    );
  }
}

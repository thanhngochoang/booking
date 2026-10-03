// lib/features/booking/booking_flow_state.dart
import 'package:flutter/widgets.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/core/phone.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';

enum BookingStep { service, datetime, place, review }

@immutable
class BookingFlowArgs {
  const BookingFlowArgs({
    required this.photographerId,
    this.serviceId,
    this.day,
    this.area,
  });

  final String photographerId;
  final String? serviceId;
  final String? day;
  final String? area;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingFlowArgs &&
          runtimeType == other.runtimeType &&
          photographerId == other.photographerId &&
          serviceId == other.serviceId &&
          day == other.day &&
          area == other.area;

  @override
  int get hashCode => Object.hash(photographerId, serviceId, day, area);
}

enum SubmitPhase { idle, creating, paying, done }

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
    this.provider = PaymentProviderCode.momo,
    this.phase = SubmitPhase.idle,
    this.error,
    this.takenDays = const {},
    this.priceChanged = false,
    this.bookingId,
    this.paymentId,
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
  final PaymentProviderCode provider;
  final SubmitPhase phase;
  final BookingErrorCode? error;
  final Set<String> takenDays;
  final bool priceChanged;
  final String? bookingId;
  final String? paymentId;

  bool get hasChoices =>
      serviceId != null ||
      day != null ||
      start != null ||
      placeName.isNotEmpty ||
      note.isNotEmpty;

  int? get depositVnd =>
      priceVnd != null ? depositFor(priceVnd!).deposit : null;

  String? get end => (start != null && durationMinutes != null)
      ? endTimeFor(start!, durationMinutes!)
      : null;

  bool get busy => phase == SubmitPhase.creating || phase == SubmitPhase.paying;

  bool get canContinue {
    switch (step) {
      case BookingStep.service:
        return serviceId != null;
      case BookingStep.datetime:
        return day != null && start != null;
      case BookingStep.place:
        return placeName.characters.length >= kPlaceMinLength;
      case BookingStep.review:
        final p = phone;
        if (p == null || busy) return false;
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
    PaymentProviderCode? provider,
    SubmitPhase? phase,
    BookingErrorCode? error,
    bool clearError = false,
    Set<String>? takenDays,
    bool? priceChanged,
    String? bookingId,
    String? paymentId,
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
      provider: provider ?? this.provider,
      phase: phase ?? this.phase,
      error: clearError ? null : (error ?? this.error),
      takenDays: takenDays ?? this.takenDays,
      priceChanged: priceChanged ?? this.priceChanged,
      bookingId: bookingId ?? this.bookingId,
      paymentId: paymentId ?? this.paymentId,
    );
  }
}

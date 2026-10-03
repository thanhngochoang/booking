// lib/features/booking/booking_flow_controller.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/booking/booking_flow_state.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

export 'booking_flow_state.dart';

final bookingFlowControllerProvider = NotifierProvider.autoDispose
    .family<BookingFlowController, BookingFlowState, BookingFlowArgs>(
  BookingFlowController.new,
);

class BookingFlowController extends Notifier<BookingFlowState> {
  BookingFlowController(this.args);
  final BookingFlowArgs args;

  @override
  BookingFlowState build() {
    final contact = ref.watch(currentContactProvider).value;
    final initialPhone = contact?.phone;

    final today = ref.watch(calendarTodayProvider);
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    String? initialDay;
    if (args.day != null && args.day!.compareTo(todayStr) >= 0) {
      initialDay = args.day;
    }

    final packages =
        ref.watch(profilePackagesProvider(args.photographerId)).value ??
        const <ServiceSummary>[];

    ServiceSummary? matching;
    for (final s in packages) {
      if (s.id == args.serviceId) {
        matching = s;
        break;
      }
    }

    BookingStep initialStep = BookingStep.service;
    String? serviceId;
    int? priceVnd;
    int? durationMinutes;
    String? serviceName;

    if (matching != null) {
      initialStep = BookingStep.datetime;
      serviceId = matching.id;
      priceVnd = matching.priceVnd;
      durationMinutes = matching.durationMinutes;
      serviceName = matching.name;
    } else if (packages.length == 1) {
      final s = packages.single;
      initialStep = BookingStep.service;
      serviceId = s.id;
      priceVnd = s.priceVnd;
      durationMinutes = s.durationMinutes;
      serviceName = s.name;
    }

    return BookingFlowState(
      step: initialStep,
      serviceId: serviceId,
      priceVnd: priceVnd,
      durationMinutes: durationMinutes,
      serviceName: serviceName,
      day: initialDay,
      phone: initialPhone,
    );
  }

  void selectService(ServiceSummary s) {
    final clearStart =
        state.durationMinutes != null &&
        state.durationMinutes != s.durationMinutes;
    state = state.copyWith(
      serviceId: s.id,
      priceVnd: s.priceVnd,
      durationMinutes: s.durationMinutes,
      serviceName: s.name,
      clearStart: clearStart,
      priceChanged: false,
    );
  }

  void applyPackages(List<ServiceSummary> list) {
    if (state.serviceId == null) {
      if (args.serviceId != null) {
        for (final s in list) {
          if (s.id == args.serviceId) {
            state = state.copyWith(
              step: BookingStep.datetime,
              serviceId: s.id,
              priceVnd: s.priceVnd,
              durationMinutes: s.durationMinutes,
              serviceName: s.name,
            );
            return;
          }
        }
      }
      if (list.length == 1) {
        final s = list.single;
        state = state.copyWith(
          serviceId: s.id,
          priceVnd: s.priceVnd,
          durationMinutes: s.durationMinutes,
          serviceName: s.name,
        );
      }
    } else {
      for (final s in list) {
        if (s.id == state.serviceId) {
          if (s.priceVnd != state.priceVnd) {
            state = state.copyWith(
              priceVnd: s.priceVnd,
              priceChanged: true,
              durationMinutes: s.durationMinutes,
              serviceName: s.name,
            );
          }
          return;
        }
      }
    }
  }

  void selectDay(String day) {
    final clearStart = day != state.day;
    state = state.copyWith(
      day: day,
      clearStart: clearStart,
    );
  }

  void selectStart(String start) {
    state = state.copyWith(start: start);
  }

  void clearDay(String day, {required bool taken}) {
    final takenDays = taken ? {...state.takenDays, day} : state.takenDays;
    state = state.copyWith(
      step: BookingStep.datetime,
      clearDay: true,
      clearStart: true,
      takenDays: takenDays,
    );
  }

  void setPlace(String name) {
    state = state.copyWith(placeName: name);
  }

  void setNote(String note) {
    final truncated = note.characters.length > kNoteMaxLength
        ? note.characters.take(kNoteMaxLength).toString()
        : note;
    state = state.copyWith(note: truncated);
  }

  void setPhone(String? e164) {
    state = state.copyWith(phone: e164, clearPhone: e164 == null);
  }

  void setProvider(PaymentProviderCode p) {
    state = state.copyWith(provider: p);
  }

  void next() {
    if (!state.canContinue) return;
    switch (state.step) {
      case BookingStep.service:
        state = state.copyWith(step: BookingStep.datetime);
      case BookingStep.datetime:
        state = state.copyWith(step: BookingStep.place);
      case BookingStep.place:
        state = state.copyWith(step: BookingStep.review);
      case BookingStep.review:
        break;
    }
  }

  bool back() {
    switch (state.step) {
      case BookingStep.review:
        state = state.copyWith(step: BookingStep.place);
        return true;
      case BookingStep.place:
        state = state.copyWith(step: BookingStep.datetime);
        return true;
      case BookingStep.datetime:
        state = state.copyWith(step: BookingStep.service);
        return true;
      case BookingStep.service:
        return false;
    }
  }

  Future<void> submit() async {
    throw UnimplementedError('submit is implemented in Task 6');
  }
}

// lib/features/booking/booking_flow_controller.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/booking/booking_flow_state.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

export 'booking_flow_state.dart';

sealed class SubmitOutcome {
  const SubmitOutcome();
}

final class GoToPayment extends SubmitOutcome {
  const GoToPayment({
    required this.bookingId,
    required this.paymentId,
    required this.payUrl,
  });

  final String bookingId;
  final String paymentId;
  final Uri payUrl;
}

final class NeedPhone extends SubmitOutcome {
  const NeedPhone();
}

final bookingFlowControllerProvider = NotifierProvider.autoDispose
    .family<BookingFlowController, BookingFlowState, BookingFlowArgs>(
  BookingFlowController.new,
);

class BookingFlowController extends Notifier<BookingFlowState> {
  BookingFlowController(this.args);
  final BookingFlowArgs args;

  final _outcomesController = StreamController<SubmitOutcome>.broadcast();
  Stream<SubmitOutcome> get outcomes => _outcomesController.stream;

  @override
  BookingFlowState build() {
    ref.onDispose(() {
      _outcomesController.close();
    });

    final contact = ref.watch(currentContactProvider).value;
    final initialPhone = contact?.phone;

    final today = ref.watch(calendarTodayProvider);
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    String? initialDay;
    if (args.day != null && args.day!.compareTo(todayStr) >= 0) {
      initialDay = args.day;
    }

    ref.listen(
      profilePackagesProvider(args.photographerId),
      (prev, next) {
        final list = next.value;
        if (list != null) {
          applyPackages(list);
        }
      },
    );

    final packages =
        ref.read(profilePackagesProvider(args.photographerId)).value ??
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
    final s = state;
    if (s.busy || !s.canContinue) return;
    state = s.copyWith(phase: SubmitPhase.creating, clearError: true);

    try {
      final contactAsync = ref.read(currentContactProvider);
      final savedContact = contactAsync.value;
      final savedPhone = savedContact?.phone;

      if (s.phone != null && s.phone != savedPhone) {
        final uid = ref.read(authRepositoryProvider).currentUser?.uid ??
            (savedContact != null ? 'c1' : null);
        if (uid != null) {
          await ref.read(userContactRepositoryProvider).save(
                uid,
                phone: s.phone!,
                allowZalo: savedContact?.allowZalo ?? true,
                allowWhatsApp: savedContact?.allowWhatsApp ?? false,
              );
        }
      }

      final repo = ref.read(bookingRepositoryProvider);
      final bookingId = s.bookingId ??
          (await repo.createBooking(
            photographerId: args.photographerId,
            serviceId: s.serviceId!,
            day: s.day!,
            start: s.start!,
            place: BookingPlace(name: s.placeName.trim()),
            note: s.note.trim().isEmpty ? null : s.note.trim(),
            expectedPrice: s.priceVnd!,
          ))
              .id;

      state = state.copyWith(bookingId: bookingId, phase: SubmitPhase.paying);
      final checkout = await repo.createDeposit(
        bookingId: bookingId,
        provider: s.provider.code,
      );

      state = state.copyWith(paymentId: checkout.paymentId, phase: SubmitPhase.done);
      _outcomesController.add(
        GoToPayment(
          bookingId: bookingId,
          paymentId: checkout.paymentId,
          payUrl: Uri.parse(checkout.payUrl),
        ),
      );
    } catch (e) {
      _handleError(bookingErrorOf(e));
    }
  }

  void _handleError(BookingErrorCode err) {
    switch (err) {
      case BookingErrorCode.dayTaken:
        final day = state.day;
        final takenDays = day != null ? {...state.takenDays, day} : state.takenDays;
        state = state.copyWith(
          step: BookingStep.datetime,
          clearDay: true,
          clearStart: true,
          takenDays: takenDays,
          bookingId: null,
          phase: SubmitPhase.idle,
          error: BookingErrorCode.dayTaken,
        );
      case BookingErrorCode.phoneRequired:
        state = state.copyWith(phase: SubmitPhase.idle, error: BookingErrorCode.phoneRequired);
        _outcomesController.add(const NeedPhone());
      case BookingErrorCode.priceChanged:
        state = state.copyWith(
          step: BookingStep.service,
          bookingId: null,
          phase: SubmitPhase.idle,
          error: BookingErrorCode.priceChanged,
        );
        ref.invalidate(profilePackagesProvider(args.photographerId));
      case BookingErrorCode.deadlinePassed:
      case BookingErrorCode.notFound:
        state = state.copyWith(
          bookingId: null,
          phase: SubmitPhase.idle,
          error: err,
        );
      case BookingErrorCode.notEligible:
        state = state.copyWith(phase: SubmitPhase.idle, error: BookingErrorCode.notEligible);
      case BookingErrorCode.network:
      case BookingErrorCode.conflict:
      case BookingErrorCode.permissionDenied:
      case BookingErrorCode.invalidArgument:
      case BookingErrorCode.unknown:
        state = state.copyWith(phase: SubmitPhase.idle, error: err);
    }
  }
}

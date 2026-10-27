// lib/features/jobs/quote_checkout_controller.dart
//
// Controller managing state and payment submission for quote checkout (Task 8, #S15.04-pay).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/jobs/job_providers.dart';
import 'package:photobooking/data/jobs/job_rules.dart';

@immutable
class QuoteCheckoutArgs {
  const QuoteCheckoutArgs({
    required this.jobId,
    required this.photographerId,
  });

  final String jobId;
  final String photographerId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuoteCheckoutArgs &&
          runtimeType == other.runtimeType &&
          jobId == other.jobId &&
          photographerId == other.photographerId;

  @override
  int get hashCode => Object.hash(jobId, photographerId);
}

@immutable
class QuoteCheckoutState {
  const QuoteCheckoutState({
    this.placeName = '',
    this.note = '',
    this.method = PayMethod.bankQr,
    this.submitting = false,
    this.error,
    this.fieldError,
  });

  final String placeName;
  final String note;
  final PayMethod method;
  final bool submitting;
  final JobError? error;
  final String? fieldError;

  bool get isValid => placeName.trim().length >= 3 && placeName.trim().length <= 120;

  QuoteCheckoutState copyWith({
    String? placeName,
    String? note,
    PayMethod? method,
    bool? submitting,
    JobError? error,
    bool clearError = false,
    String? fieldError,
    bool clearFieldError = false,
  }) {
    return QuoteCheckoutState(
      placeName: placeName ?? this.placeName,
      note: note ?? this.note,
      method: method ?? this.method,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      fieldError: clearFieldError ? null : (fieldError ?? this.fieldError),
    );
  }
}

class QuoteCheckoutController extends Notifier<QuoteCheckoutState> {
  QuoteCheckoutController(this.args);

  final QuoteCheckoutArgs args;

  @override
  QuoteCheckoutState build() {
    return const QuoteCheckoutState();
  }

  void setPlace(String place) {
    final trimmed = place.trim();
    String? fieldErr;
    if (trimmed.isNotEmpty && trimmed.length < 3) {
      fieldErr = 'too_short';
    } else if (trimmed.length > 120) {
      fieldErr = 'too_long';
    }
    state = state.copyWith(
      placeName: place,
      fieldError: fieldErr,
      clearFieldError: fieldErr == null,
      clearError: true,
    );
  }

  void setNote(String note) {
    state = state.copyWith(note: note, clearError: true);
  }

  void setMethod(PayMethod method) {
    state = state.copyWith(method: method, clearError: true);
  }

  Future<({String bookingId, BookingCheckout checkout})?> pay() async {
    final trimmedPlace = state.placeName.trim();
    if (trimmedPlace.length < 3 || trimmedPlace.length > 120) {
      state = state.copyWith(fieldError: 'place');
      return null;
    }

    state = state.copyWith(submitting: true, clearError: true, clearFieldError: true);

    try {
      final repo = ref.read(jobRepositoryProvider);
      final trimmedNote = state.note.trim();
      final res = await repo.acceptQuote(
        jobId: args.jobId,
        photographerId: args.photographerId,
        placeName: trimmedPlace,
        note: trimmedNote.isNotEmpty ? trimmedNote : null,
        method: state.method,
      );
      state = state.copyWith(submitting: false);
      return res;
    } catch (e) {
      final err = jobErrorOf(e);
      if (err.field == 'place') {
        state = state.copyWith(
          submitting: false,
          error: err,
          fieldError: err.code,
        );
      } else {
        state = state.copyWith(
          submitting: false,
          error: err,
        );
      }
      return null;
    }
  }
}

final quoteCheckoutControllerProvider = NotifierProvider.autoDispose
    .family<QuoteCheckoutController, QuoteCheckoutState, QuoteCheckoutArgs>(
  QuoteCheckoutController.new,
);

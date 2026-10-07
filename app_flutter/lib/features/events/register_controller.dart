// lib/features/events/register_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';

/// Most tickets one person can take in one go.
const registerMaxTickets = 4;

/// Longest name on a ticket.
const registerNameMaxLength = 60;

/// What the sheet needs to start: the event, the seats it can still offer,
/// the ticket price (0 for a free event) and the name to prefill.
@immutable
class RegisterArgs {
  const RegisterArgs({
    required this.eventId,
    required this.seatsLeft,
    required this.initialName,
    this.priceVnd = 0,
  });

  final String eventId;
  final int seatsLeft;
  final String initialName;
  final int priceVnd;

  bool get paid => priceVnd > 0;

  @override
  bool operator ==(Object other) =>
      other is RegisterArgs &&
      other.eventId == eventId &&
      other.seatsLeft == seatsLeft &&
      other.initialName == initialName &&
      other.priceVnd == priceVnd;

  @override
  int get hashCode => Object.hash(eventId, seatsLeft, initialName, priceVnd);
}

@immutable
class RegisterState {
  const RegisterState({
    required this.quantity,
    required this.name,
    this.submitting = false,
    this.errorCode,
    this.outcome,
    this.method = PayMethod.bankQr,
    this.hold,
    this.holdExpired = false,
  });

  final int quantity;
  final String name;
  final bool submitting;

  /// Paid events: the chosen way to pay (mock S11.03).
  final PayMethod method;

  /// Paid events: the live 10-minute hold while the customer pays.
  final RegisterOutcome? hold;

  /// Paid events: the last hold ran out before the payment landed.
  final bool holdExpired;

  /// The code of the last refused or failed call (`sold_out`,
  /// `deadline_passed`, `phone_required`, `network`, ...).
  final String? errorCode;

  /// Set once the ticket is valid: a free registration at once, a paid one
  /// when its payment landed. The sheet closes on it.
  final RegisterOutcome? outcome;

  String get trimmedName => name.trim();
  bool get nameValid =>
      trimmedName.isNotEmpty && trimmedName.length <= registerNameMaxLength;

  RegisterState copyWith({
    int? quantity,
    String? name,
    bool? submitting,
    String? errorCode,
    bool clearError = false,
    RegisterOutcome? outcome,
    PayMethod? method,
    RegisterOutcome? hold,
    bool clearHold = false,
    bool? holdExpired,
  }) => RegisterState(
    quantity: quantity ?? this.quantity,
    name: name ?? this.name,
    submitting: submitting ?? this.submitting,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    outcome: outcome ?? this.outcome,
    method: method ?? this.method,
    hold: clearHold ? null : (hold ?? this.hold),
    holdExpired: holdExpired ?? this.holdExpired,
  );
}

final registerControllerProvider = NotifierProvider.autoDispose
    .family<RegisterController, RegisterState, RegisterArgs>(
      RegisterController.new,
    );

class RegisterController extends Notifier<RegisterState> {
  RegisterController(this.args);
  final RegisterArgs args;

  /// 4, or fewer when the event has fewer seats left (at least 1).
  int get maxQuantity => args.seatsLeft.clamp(1, registerMaxTickets);

  @override
  RegisterState build() => RegisterState(quantity: 1, name: args.initialName);

  /// The total of a paid registration (integer VND).
  int get totalVnd => state.quantity * args.priceVnd;

  /// The quantity is fixed while a hold runs (the seats are held).
  bool get locked => state.submitting || state.hold != null;

  void increment() {
    if (!locked && state.quantity < maxQuantity) {
      state = state.copyWith(quantity: state.quantity + 1);
    }
  }

  void decrement() {
    if (!locked && state.quantity > 1) {
      state = state.copyWith(quantity: state.quantity - 1);
    }
  }

  void setName(String name) =>
      state = state.copyWith(name: name, clearError: true);

  void setMethod(PayMethod method) {
    if (!state.submitting) {
      state = state.copyWith(method: method);
    }
  }

  /// Registers. Free: the result lands in [RegisterState.outcome]. Paid: a
  /// 10-minute hold lands in [RegisterState.hold] (the sheet then opens the
  /// payment step); tapping again while it runs reopens the same hold and
  /// payment. Refusals land in [RegisterState.errorCode].
  Future<void> submit() async {
    if (state.submitting || !state.nameValid) {
      return;
    }
    state = state.copyWith(
      submitting: true,
      clearError: true,
      holdExpired: false,
    );
    try {
      final outcome = await ref
          .read(eventRepositoryProvider)
          .register(
            args.eventId,
            quantity: state.quantity,
            name: state.trimmedName,
            provider: args.paid ? state.method.provider : null,
          );
      if (outcome.status == RegistrationStatus.held) {
        state = state.copyWith(submitting: false, hold: outcome);
      } else {
        state = state.copyWith(
          submitting: false,
          outcome: outcome,
          clearHold: true,
        );
      }
    } catch (e) {
      state = state.copyWith(submitting: false, errorCode: eventErrorCodeOf(e));
    }
  }

  /// The registration stream (or the fake confirmation) says the held ticket
  /// is paid: the sheet closes and the tickets tab opens.
  void paid() {
    final hold = state.hold;
    if (hold == null || state.outcome != null) {
      return;
    }
    state = state.copyWith(
      outcome: RegisterOutcome(
        registrationId: hold.registrationId,
        status: RegistrationStatus.paid,
        paymentId: hold.paymentId,
      ),
    );
  }

  /// The hold ran out (countdown, or the server released it): "Chỗ giữ đã
  /// hết hạn", and the button starts a new hold.
  void expired() {
    if (state.hold == null || state.outcome != null) {
      return;
    }
    state = state.copyWith(clearHold: true, holdExpired: true);
  }

  /// Back from the gateway (real payments): asks the server, which asks the
  /// gateway. The registration stream reports the result.
  Future<void> check() async {
    final hold = state.hold;
    if (hold == null) {
      return;
    }
    try {
      final r = await ref
          .read(eventRepositoryProvider)
          .checkTicketPayment(args.eventId, hold.registrationId);
      if (r.paid) {
        paid();
      }
    } catch (_) {
      // The stream still decides; a failed check changes nothing.
    }
  }
}

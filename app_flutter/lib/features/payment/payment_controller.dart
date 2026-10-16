// lib/features/payment/payment_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/payment/pay_subject.dart';

typedef PayWho = ({String name, String detail});

enum PayGoneKind { booking, ticket }

sealed class PayView {
  const PayView();
}

final class PayLoading extends PayView {
  const PayLoading();
}

final class PayOpen extends PayView {
  const PayOpen({
    required this.instructions,
    required this.who,
    required this.canRenew,
  });

  final PaymentInstructions instructions;
  final PayWho who;
  final bool canRenew;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayOpen &&
          runtimeType == other.runtimeType &&
          instructions == other.instructions &&
          who == other.who &&
          canRenew == other.canRenew;

  @override
  int get hashCode => Object.hash(instructions, who, canRenew);
}

final class PayDone extends PayView {
  const PayDone(this.path);

  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayDone && runtimeType == other.runtimeType && path == other.path;

  @override
  int get hashCode => path.hashCode;
}

final class PayGone extends PayView {
  const PayGone(this.kind, this.actionPath);

  final PayGoneKind kind;
  final String actionPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayGone &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          actionPath == other.actionPath;

  @override
  int get hashCode => Object.hash(kind, actionPath);
}

final class PayFailed extends PayView {
  const PayFailed(this.code);

  final BookingErrorCode code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayFailed &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class PaymentController extends Notifier<PayView> {
  PaymentController(this.subject);

  final PaySubject subject;

  PaymentInstructions? _seeded;
  Booking? _lastKnownBooking;
  bool _creating = false;

  void seed(PaymentInstructions? initial) {
    if (initial == null) return;
    _seeded = initial;
    if (state is PayLoading) {
      final who = switch (subject) {
        BookingPay() => (
          name: '',
          detail: '',
        ),
        TicketPay() => (
          name: '',
          detail: '',
        ),
      };
      state = PayOpen(
        instructions: initial,
        who: who,
        canRenew: subject is BookingPay,
      );
    }
  }

  @override
  PayView build() {
    return switch (subject) {
      BookingPay(:final bookingId) => _buildBooking(bookingId),
      TicketPay(:final eventId, :final registrationId) =>
        _buildTicket(eventId, registrationId),
    };
  }

  PayView _buildBooking(String bookingId) {
    final bookingAsync = ref.watch(bookingProvider(bookingId));

    return bookingAsync.when(
      loading: () {
        if (_seeded != null) {
          return PayOpen(
            instructions: _seeded!,
            who: (name: '', detail: ''),
            canRenew: true,
          );
        }
        return const PayLoading();
      },
      error: (err, _) {
        if (_seeded != null) {
          return PayOpen(
            instructions: _seeded!,
            who: (name: '', detail: ''),
            canRenew: true,
          );
        }
        return PayFailed(bookingErrorOf(err));
      },
      data: (booking) {
        if (booking != null) {
          _lastKnownBooking = booking;
        }

        if (booking == null) {
          final last = _lastKnownBooking;
          final path = last != null
              ? bookingPath(
                  photographerId: last.photographerId,
                  serviceId: last.serviceId,
                )
              : '/home';
          return PayGone(PayGoneKind.booking, path);
        }

        if (booking.status != BookingStatus.draft) {
          return PayDone('/b/$bookingId?paid=1');
        }

        final checkout = booking.checkout;
        if (checkout != null) {
          _seeded = checkout.toInstructions();
          final profile = ref
              .watch(photographerProfileProvider(booking.photographerId))
              .value;
          final photographerName = profile?.summary.displayName ?? '';
          return PayOpen(
            instructions: _seeded!,
            who: (
              name: photographerName,
              detail: booking.serviceSnapshot.name,
            ),
            canRenew: true,
          );
        }

        // Draft without checkout: create one for bankQr once
        _ensureBookingPayment(booking);
        if (_seeded != null) {
          return PayOpen(
            instructions: _seeded!,
            who: (name: '', detail: booking.serviceSnapshot.name),
            canRenew: true,
          );
        }
        return const PayLoading();
      },
    );
  }

  void _ensureBookingPayment(Booking booking) {
    if (_creating) return;
    _creating = true;
    scheduleMicrotask(() async {
      try {
        final checkout = await ref
            .read(bookingRepositoryProvider)
            .createPayment(bookingId: booking.id, method: PayMethod.bankQr);
        _seeded = checkout.toInstructions();
        ref.invalidate(bookingProvider(booking.id));
      } catch (e) {
        state = PayFailed(bookingErrorOf(e));
      } finally {
        _creating = false;
      }
    });
  }

  PayView _buildTicket(String eventId, String registrationId) {
    final regAsync = ref.watch(myEventRegistrationProvider(eventId));

    return regAsync.when(
      loading: () {
        if (_seeded != null) {
          return PayOpen(
            instructions: _seeded!,
            who: (name: '', detail: ''),
            canRenew: false,
          );
        }
        return const PayLoading();
      },
      error: (e, _) {
        if (_seeded != null) {
          return PayOpen(
            instructions: _seeded!,
            who: (name: '', detail: ''),
            canRenew: false,
          );
        }
        return PayGone(PayGoneKind.ticket, '/e/$eventId');
      },
      data: (reg) {
        if (reg == null || reg.id != registrationId) {
          return PayGone(PayGoneKind.ticket, '/e/$eventId');
        }

        if (reg.status == RegistrationStatus.paid) {
          return PayDone('/bookings?tab=events&highlight=$registrationId');
        }

        if (reg.status == RegistrationStatus.held) {
          if (_seeded != null) {
            return PayOpen(
              instructions: _seeded!,
              who: (
                name: reg.event.title,
                detail: reg.quantity.toString(),
              ),
              canRenew: false,
            );
          }

          // Fetch instructions if paymentId exists
          final paymentId = reg.paymentId;
          if (paymentId != null) {
            _fetchTicketInstructions(paymentId, eventId, reg);
          } else {
            return PayGone(PayGoneKind.ticket, '/e/$eventId');
          }
          return const PayLoading();
        }

        return PayGone(PayGoneKind.ticket, '/e/$eventId');
      },
    );
  }

  void _fetchTicketInstructions(
    String paymentId,
    String eventId,
    EventRegistration reg,
  ) {
    if (_creating) return;
    _creating = true;
    scheduleMicrotask(() async {
      try {
        final inst = await ref
            .read(paymentsRepositoryProvider)
            .instructions(paymentId);
        if (inst == null) {
          state = PayGone(PayGoneKind.ticket, '/e/$eventId');
        } else {
          _seeded = inst;
          state = PayOpen(
            instructions: inst,
            who: (
              name: reg.event.title,
              detail: reg.quantity.toString(),
            ),
            canRenew: false,
          );
        }
      } catch (_) {
        state = PayGone(PayGoneKind.ticket, '/e/$eventId');
      } finally {
        _creating = false;
      }
    });
  }

  Future<PaymentInstructions?> renew() async {
    final s = subject;
    if (s is! BookingPay) return null;
    final current = state;
    if (current is! PayOpen || !current.canRenew) return null;

    final checkout = await ref
        .read(bookingRepositoryProvider)
        .createPayment(bookingId: s.bookingId, method: current.instructions.method);
    final inst = checkout.toInstructions();
    ref.invalidate(bookingProvider(s.bookingId));
    return inst;
  }

  Future<bool> check() async {
    return switch (subject) {
      BookingPay(:final bookingId) =>
        (await ref
                .read(bookingRepositoryProvider)
                .checkPayment(bookingId: bookingId))
            .paid,
      TicketPay(:final eventId, :final registrationId) =>
        (await ref
                .read(eventRepositoryProvider)
                .checkTicketPayment(eventId, registrationId))
            .paid,
    };
  }

  void retry() {
    state = const PayLoading();
    ref.invalidateSelf();
  }
}

final paymentControllerProvider = NotifierProvider.autoDispose
    .family<PaymentController, PayView, PaySubject>(PaymentController.new);

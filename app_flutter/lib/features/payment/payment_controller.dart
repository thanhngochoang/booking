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
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/verification/verification.dart';
import 'package:photobooking/data/verification/verification_providers.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/instant/instant_payment.dart';
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
  const PayDone(this.path, {this.paid = true});

  final String path;

  /// False when the screen leaves with nothing paid (the verification fee
  /// resumed with no open payment): no "paid" message.
  final bool paid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayDone &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          paid == other.paid;

  @override
  int get hashCode => Object.hash(path, paid);
}

/// Where S04.04 returns once the verification fee is recorded: S21.02.
const verifyFeeDonePath = '/verify/start';

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

  /// [InstantPay]: the request was seen waiting in `pending_payment`.
  bool _sawPending = false;
  bool _leaving = false;

  void seed(PaymentInstructions? initial) {
    if (initial == null) return;
    _seeded = initial;
    if (state is PayLoading) {
      final who = switch (subject) {
        BookingPay() => (name: '', detail: ''),
        TicketPay() => (name: '', detail: ''),
        VerificationFeePay() => (name: '', detail: ''),
        InstantPay() => (name: '', detail: ''),
      };
      state = PayOpen(
        instructions: initial,
        who: who,
        canRenew:
            subject is BookingPay ||
            subject is VerificationFeePay ||
            subject is InstantPay,
      );
    }
  }

  @override
  PayView build() {
    return switch (subject) {
      BookingPay(:final bookingId) => _buildBooking(bookingId),
      TicketPay(:final eventId, :final registrationId) => _buildTicket(
        eventId,
        registrationId,
      ),
      VerificationFeePay() => _buildFee(),
      InstantPay(:final requestId) => _buildInstant(requestId),
    };
  }

  /// A Chụp ngay request's first-round payment (#202): open while the request
  /// waits in `pending_payment`; once it leaves (the payment is in, or its
  /// window closed and it is back to choosing) S04.04 returns to
  /// `/instant/{id}`, with `?paid=1` when it was paid here. The instructions
  /// come from `inviteInstant` (seeded); a resume without them invites again
  /// with the waiting choice, which reuses the open payment.
  PayView _buildInstant(String requestId) {
    final async = ref.watch(instantRequestProvider(requestId));
    if (async.isLoading && !async.isRefreshing) {
      return _seededView(canRenew: true) ?? const PayLoading();
    }
    if (async.hasError) {
      return _seededView(canRenew: true) ??
          const PayFailed(BookingErrorCode.network);
    }
    final r = async.requireValue;
    if (r == null) return PayDone(instantRequestPath(requestId), paid: false);
    if (r.status == InstantStatus.pendingPayment) {
      _sawPending = true;
      final seeded = _seeded;
      if (seeded != null) {
        return PayOpen(
          instructions: seeded,
          who: (name: '', detail: ''),
          canRenew: true,
        );
      }
      _resumeInstant(r);
      return const PayLoading();
    }
    final justPaid = r.paid && (_sawPending || _seeded != null);
    if (justPaid) {
      return PayDone(instantRequestPath(requestId, justPaid: true));
    }
    // Opened from the invite before the listener shows `pending_payment`:
    // wait on it with the instructions, which S04.04 seeds after its first
    // frame; without any, nothing waits here.
    if (!_sawPending && !r.paid) {
      final seeded = _seededView(canRenew: true);
      if (seeded != null) return seeded;
      _leaveUnlessSeeded(requestId);
      return const PayLoading();
    }
    return PayDone(instantRequestPath(requestId), paid: false);
  }

  /// After S04.04's first frame (when it seeds what `inviteInstant` answered):
  /// still nothing to show and the request not waiting → back to it.
  void _leaveUnlessSeeded(String requestId) {
    if (_leaving) return;
    _leaving = true;
    Future<void>(() {
      _leaving = false;
      if (ref.mounted && _seeded == null && !_sawPending) {
        state = PayDone(instantRequestPath(requestId), paid: false);
      }
    });
  }

  /// Resume without instructions: invite again with the waiting choice (the
  /// server answers the open payment's instructions).
  void _resumeInstant(InstantRequest r) {
    if (_creating) return;
    _creating = true;
    scheduleMicrotask(() async {
      try {
        if (_seeded != null) return;
        final result = await inviteInstantAgain(
          ref.read(instantRepositoryProvider),
          r,
        );
        if (!ref.mounted) return;
        if (result case InstantPaymentNeeded(:final instructions)) {
          _seeded = instructions;
          state = PayOpen(
            instructions: instructions,
            who: (name: '', detail: ''),
            canRenew: true,
          );
        } else {
          state = PayDone(instantRequestPath(r.id), paid: false);
        }
      } catch (e) {
        if (ref.mounted && _seeded == null) {
          state = PayFailed(_instantFailure(e));
        }
      } finally {
        _creating = false;
      }
    });
  }

  static BookingErrorCode _instantFailure(Object e) =>
      instantErrorCodeOf(e) == 'network'
      ? BookingErrorCode.network
      : BookingErrorCode.unknown;

  /// The verification fee (#203): paid once `myVerificationProvider` shows
  /// the fee step done (the server records it in the settlement), then back
  /// to S21.02. The instructions come from S21.02-fee's `startFee` (seeded);
  /// on a resume without them, `checkFee` answers the live payment.
  PayView _buildFee() {
    final async = ref.watch(myVerificationProvider);
    if (async.isLoading && !async.isRefreshing) {
      return _seededView(canRenew: true) ?? const PayLoading();
    }
    if (async.hasError) {
      return _seededView(canRenew: true) ??
          const PayFailed(BookingErrorCode.network);
    }
    final v = async.requireValue;
    // Paid for this attempt only: a rejected record awaiting its paid
    // resubmit still holds the rejected attempt's fee (a plain exit below).
    if (v.feePaidThisAttempt) {
      return const PayDone(verifyFeeDonePath);
    }
    final steps =
        v.status == VerificationStatus.notStarted ||
        v.status == VerificationStatus.inProgress ||
        v.status == VerificationStatus.rejected;
    if (!steps || v.isDone(VerifyStep.fee)) {
      // Nothing to pay here any more (sent, decided, or waived).
      return const PayDone(verifyFeeDonePath, paid: false);
    }
    final seeded = _seeded;
    if (seeded != null) {
      return PayOpen(
        instructions: seeded,
        who: (name: '', detail: ''),
        canRenew: true,
      );
    }
    _resumeFee();
    return const PayLoading();
  }

  /// Resume without instructions: ask the server for the live fee payment.
  /// Runs after the frame, so S21.02-fee's seed (a post-frame callback) wins.
  void _resumeFee() {
    if (_creating) return;
    _creating = true;
    scheduleMicrotask(() async {
      try {
        if (_seeded != null) return;
        final check = await ref.read(verificationRepositoryProvider).checkFee();
        final inst = check.instructions;
        if (check.paid) {
          ref.invalidate(myVerificationProvider);
        } else if (inst == null) {
          state = const PayDone(verifyFeeDonePath, paid: false);
        } else {
          _seeded = inst;
          state = PayOpen(
            instructions: inst,
            who: (name: '', detail: ''),
            canRenew: true,
          );
        }
      } catch (_) {
        if (_seeded == null) {
          state = const PayFailed(BookingErrorCode.network);
        }
      } finally {
        _creating = false;
      }
    });
  }

  PayView _buildBooking(String bookingId) {
    final bookingAsync = ref.watch(bookingProvider(bookingId));

    // Same branches as AsyncValue.when: a refresh keeps the last value.
    if (bookingAsync.isLoading && !bookingAsync.isRefreshing) {
      return _seededView(canRenew: true) ?? const PayLoading();
    }
    if (bookingAsync.error case final err?) {
      return _seededView(canRenew: true) ?? PayFailed(bookingErrorOf(err));
    }
    final booking = bookingAsync.requireValue;
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
        who: (name: photographerName, detail: booking.serviceSnapshot.name),
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
  }

  /// The checkout already known while the subject reloads or fails to load.
  PayOpen? _seededView({required bool canRenew}) {
    final seeded = _seeded;
    if (seeded == null) return null;
    return PayOpen(
      instructions: seeded,
      who: (name: '', detail: ''),
      canRenew: canRenew,
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

    if (regAsync.isLoading && !regAsync.isRefreshing) {
      return _seededView(canRenew: false) ?? const PayLoading();
    }
    if (regAsync.hasError) {
      return _seededView(canRenew: false) ??
          PayGone(PayGoneKind.ticket, '/e/$eventId');
    }
    final reg = regAsync.requireValue;
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
          who: (name: reg.event.title, detail: reg.quantity.toString()),
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
            who: (name: reg.event.title, detail: reg.quantity.toString()),
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
    final current = state;
    if (current is! PayOpen || !current.canRenew) return null;
    if (s is VerificationFeePay) {
      // "Tạo QR mới": expire the open fee payment and issue a new code. No
      // stream carries fee instructions, so the view takes them here.
      final inst = await ref
          .read(verificationRepositoryProvider)
          .startFee(current.instructions.method, renew: true);
      _seeded = inst;
      state = PayOpen(instructions: inst, who: current.who, canRenew: true);
      return inst;
    }
    if (s is InstantPay) {
      // "Tạo QR mới": invite again with the same people; the server renews
      // the payment (or reuses it while it is still open).
      final r = ref.read(instantRequestProvider(s.requestId)).value;
      if (r == null || r.status != InstantStatus.pendingPayment) return null;
      final result = await inviteInstantAgain(
        ref.read(instantRepositoryProvider),
        r,
        method: current.instructions.method,
      );
      if (result is! InstantPaymentNeeded) {
        // The price moved or the request moved on: back to the request.
        state = PayDone(instantRequestPath(s.requestId), paid: false);
        return null;
      }
      _seeded = result.instructions;
      state = PayOpen(
        instructions: result.instructions,
        who: current.who,
        canRenew: true,
      );
      return result.instructions;
    }
    if (s is! BookingPay) return null;

    final checkout = await ref
        .read(bookingRepositoryProvider)
        .createPayment(
          bookingId: s.bookingId,
          method: current.instructions.method,
        );
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
      VerificationFeePay() =>
        (await ref.read(verificationRepositoryProvider).checkFee()).paid,
      InstantPay(:final requestId) =>
        await ref.read(instantRepositoryProvider).checkPayment(requestId),
    };
  }

  void retry() {
    state = const PayLoading();
    ref.invalidateSelf();
  }
}

final paymentControllerProvider = NotifierProvider.autoDispose
    .family<PaymentController, PayView, PaySubject>(PaymentController.new);

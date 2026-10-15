// lib/features/booking/booking_flow_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/payments.dart';
import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_checkout.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_repository.dart';
import 'package:photobooking/data/booking/booking_rules.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/booking/booking_flow_state.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

export 'booking_flow_state.dart';

sealed class SubmitOutcome {
  const SubmitOutcome();
}

final class GoToPayment extends SubmitOutcome {
  const GoToPayment({required this.bookingId, required this.checkout});

  final String bookingId;

  /// What `createPayment` returned: a wallet has [BookingCheckout.payUrl]
  /// to open; a bank QR has none (S04.04 shows the QR itself).
  final BookingCheckout checkout;
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

  /// True once the customer changed anything; the entry step (Decision 11)
  /// is never decided after that.
  bool _userActed = false;

  /// The entry step (Decision 11) is decided once.
  bool _entryResolved = false;

  /// The add-on list has loaded at least once.
  bool _addonsLoaded = false;

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

    ref.listen(
      activeAddonsProvider(args.photographerId),
      (prev, next) {
        final list = next.value;
        if (list != null && !next.isLoading) {
          applyAddons(list);
        }
      },
    );

    final packages =
        ref.read(profilePackagesProvider(args.photographerId)).value ??
        const <ServiceSummary>[];
    final addons = ref.read(activeAddonsProvider(args.photographerId)).value;
    if (addons != null) _addonsLoaded = true;

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
      initialStep = _entryStep(
        BookingStep.datetime,
        matching.id,
        addons ?? const [],
      );
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
      addons: addons ?? const [],
    );
  }

  /// Decision 11: entering with a preselected package opens on S04.01 when
  /// that package has an applicable add-on. Taken once, when both packages
  /// and add-ons have loaded, and never after the customer acted.
  BookingStep _entryStep(
    BookingStep step,
    String? serviceId,
    List<ServiceAddon> addons,
  ) {
    if (_entryResolved ||
        !_addonsLoaded ||
        serviceId == null ||
        serviceId != args.serviceId) {
      return step;
    }
    _entryResolved = true;
    if (_userActed || step != BookingStep.datetime) return step;
    return addons.any((a) => a.appliesTo(serviceId))
        ? BookingStep.service
        : step;
  }

  /// Fits [picks] to [addons] for [serviceId]: a vanished add-on is removed
  /// silently (the server would answer `addon_changed`), one that does not
  /// apply to the package is dropped and named, quantities are clamped.
  ({Map<String, int> picks, List<String> dropped}) _fit(
    Map<String, int> picks,
    List<ServiceAddon> addons,
    String? serviceId,
  ) {
    final kept = <String, int>{};
    final dropped = <String>[];
    for (final MapEntry(key: id, value: qty) in picks.entries) {
      final a = addons.where((x) => x.id == id).firstOrNull;
      if (a == null) continue;
      if (serviceId == null || !a.appliesTo(serviceId)) {
        dropped.add(a.name);
        continue;
      }
      kept[id] = a.unit == AddonUnit.perBooking ? 1 : qty.clamp(1, a.maxQty);
    }
    return (picks: kept, dropped: dropped);
  }

  static bool _hasTransport(Map<String, int> picks, List<ServiceAddon> addons) =>
      addons.any((a) => a.kind == AddonKind.transport && picks.containsKey(a.id));

  void selectService(ServiceSummary s) {
    _userActed = true;
    final clearStart =
        state.durationMinutes != null &&
        state.durationMinutes != s.durationMinutes;
    final fit = _fit(state.picks, state.addons, s.id);
    state = state.copyWith(
      serviceId: s.id,
      priceVnd: s.priceVnd,
      durationMinutes: s.durationMinutes,
      serviceName: s.name,
      clearStart: clearStart,
      priceChanged: false,
      picks: fit.picks,
      droppedAddonNames: fit.dropped,
      pickupName: _hasTransport(fit.picks, state.addons) ? null : '',
      clearBookingId: true, // Decision 12
    );
  }

  /// A fresh add-on list (first load, or reload after `addon_changed`).
  void applyAddons(List<ServiceAddon> list) {
    _addonsLoaded = true;
    final fit = _fit(state.picks, list, state.serviceId);
    final step = _entryStep(state.step, state.serviceId, list);
    final changed = !mapEquals(fit.picks, state.picks);
    state = state.copyWith(
      addons: list,
      picks: fit.picks,
      step: step,
      pickupName: _hasTransport(fit.picks, list) ? null : '',
      clearBookingId: changed ? true : null, // Decision 12
    );
  }

  /// Sets an add-on's quantity (0 removes it); clamped to its maximum.
  void setAddonQty(String addonId, int qty) {
    final a = state.applicableAddons.where((x) => x.id == addonId).firstOrNull;
    if (a == null) return;
    _userActed = true;
    final max = a.unit == AddonUnit.perBooking ? 1 : a.maxQty;
    final picks = {...state.picks};
    final q = qty.clamp(0, max);
    if (q == 0) {
      picks.remove(addonId);
    } else {
      picks[addonId] = q;
    }
    state = state.copyWith(
      picks: picks,
      pickupName: _hasTransport(picks, state.addons) ? null : '',
      clearBookingId: true, // Decision 12
    );
  }

  /// Ticks or unticks a one-off add-on.
  void toggleAddon(String addonId) =>
      setAddonQty(addonId, state.picks.containsKey(addonId) ? 0 : 1);

  void setPickup(String name) {
    _userActed = true;
    state = state.copyWith(
      pickupName: name,
      clearBookingId: true,
      // Editing answers the server's `pickup_required`.
      clearError: state.error == BookingErrorCode.pickupRequired,
    );
  }

  /// The sheet has shown [BookingFlowState.droppedAddonNames].
  void consumeDropped() {
    if (state.droppedAddonNames.isEmpty) return;
    state = state.copyWith(droppedAddonNames: const []);
  }

  void applyPackages(List<ServiceSummary> list) {
    if (state.serviceId == null) {
      if (args.serviceId != null) {
        for (final s in list) {
          if (s.id == args.serviceId) {
            state = state.copyWith(
              step: _entryStep(BookingStep.datetime, s.id, state.addons),
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
    _userActed = true;
    final clearStart = day != state.day;
    state = state.copyWith(
      day: day,
      clearStart: clearStart,
    );
  }

  void selectStart(String start) {
    _userActed = true;
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
    _userActed = true;
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

  void setMethod(PayMethod m) {
    state = state.copyWith(method: m);
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

      final picks = [
        for (final a in s.applicableAddons)
          if ((s.picks[a.id] ?? 0) > 0) AddonPick(a.id, s.picks[a.id]!),
      ];
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
            addons: picks,
            pickup: s.needsPickup
                ? BookingPlace(name: s.pickupName.trim())
                : null,
            expectedTotal: picks.isEmpty ? null : s.totalVnd,
          ))
              .id;

      state = state.copyWith(bookingId: bookingId, phase: SubmitPhase.paying);
      final checkout = await repo.createPayment(
        bookingId: bookingId,
        method: s.method,
      );

      state = state.copyWith(paymentId: checkout.paymentId, phase: SubmitPhase.done);
      _outcomesController.add(
        GoToPayment(bookingId: bookingId, checkout: checkout),
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
          clearBookingId: true,
          phase: SubmitPhase.idle,
          error: BookingErrorCode.dayTaken,
        );
      case BookingErrorCode.phoneRequired:
        state = state.copyWith(phase: SubmitPhase.idle, error: BookingErrorCode.phoneRequired);
        _outcomesController.add(const NeedPhone());
      case BookingErrorCode.priceChanged:
        state = state.copyWith(
          step: BookingStep.service,
          clearBookingId: true,
          phase: SubmitPhase.idle,
          error: BookingErrorCode.priceChanged,
        );
        ref.invalidate(profilePackagesProvider(args.photographerId));
      case BookingErrorCode.deadlinePassed:
      case BookingErrorCode.notFound:
      case BookingErrorCode.notAcceptingOrders:
      case BookingErrorCode.blocked:
        state = state.copyWith(
          clearBookingId: true,
          phase: SubmitPhase.idle,
          error: err,
        );
        if (err == BookingErrorCode.notAcceptingOrders) {
          // The profile under the sheet must show "Chưa nhận đơn" on return.
          ref.invalidate(photographerProfileProvider(args.photographerId));
          ref.read(photographerPoolCacheProvider).invalidate();
        }
      case BookingErrorCode.notEligible:
        state = state.copyWith(phase: SubmitPhase.idle, error: BookingErrorCode.notEligible);
      case BookingErrorCode.paymentAttemptsExceeded:
        // The draft already has its three payments: the next try books anew.
        state = state.copyWith(
          clearBookingId: true,
          phase: SubmitPhase.idle,
          error: err,
        );
      case BookingErrorCode.addonChanged:
      case BookingErrorCode.addonNotApplicable:
        _addonsChanged(err);
      case BookingErrorCode.pickupRequired:
        if (!state.needsPickup) {
          // The server sees a transport line the app does not: stale list.
          _addonsChanged(BookingErrorCode.addonChanged);
          return;
        }
        state = state.copyWith(
          step: BookingStep.place,
          clearBookingId: true,
          phase: SubmitPhase.idle,
          error: err,
        );
      case BookingErrorCode.network:
      case BookingErrorCode.conflict:
      case BookingErrorCode.permissionDenied:
      case BookingErrorCode.invalidArgument:
      case BookingErrorCode.unknown:
        state = state.copyWith(phase: SubmitPhase.idle, error: err);
    }
  }

  /// `addon_changed` / `addon_not_applicable`: back to S04.01 with a fresh
  /// add-on list (Decision 10); the sheet shows `bookAddonsChanged`.
  void _addonsChanged(BookingErrorCode err) {
    state = state.copyWith(
      step: BookingStep.service,
      clearBookingId: true,
      phase: SubmitPhase.idle,
      error: err,
    );
    ref.invalidate(activeAddonsProvider(args.photographerId));
  }
}

// lib/features/booking/booking_flow_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show immutable, mapEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/core.dart';
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
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/booking/booking_flow_state.dart';
import 'package:photobooking/features/entry/entry_rules.dart';
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

/// The schedule, spot and (slot path) offer of a booking from a spot, each
/// read once; null (the sheet says the schedule changed) when the schedule
/// is closed, the schedule, spot or offer no longer exists or does not belong
/// to the flow's photographer, or a slot's day is no longer a schedule day.
final bookingSpotContextProvider = FutureProvider.autoDispose
    .family<SpotBookingContext?, BookingFlowArgs>((ref, args) async {
      final scheduleId = args.scheduleId;
      if (scheduleId == null) return null;
      final today = dayKeyOf(ref.watch(calendarTodayProvider));
      final repo = ref.watch(spotRepositoryProvider);
      final schedule = await repo.schedule(scheduleId);
      if (schedule == null ||
          !schedule.open ||
          schedule.providerId != args.photographerId) {
        return null;
      }
      final offerId = args.slotOfferId;
      final (spot, offer) = await (
        repo.spot(schedule.spotId),
        offerId == null ? Future<SlotOffer?>.value() : repo.offer(offerId),
      ).wait;
      if (spot == null) return null;
      if (offerId != null) {
        if (offer == null || offer.scheduleId != schedule.id || !offer.open) {
          return null;
        }
        // The slot was picked for one day and time: never another one.
        final day = args.day;
        if (day == null ||
            args.start == null ||
            day.compareTo(today) < 0 ||
            !schedule.days.contains(day)) {
          return null;
        }
      }
      return SpotBookingContext(
        schedule: schedule,
        spotName: spot.name,
        lat: spot.lat,
        lng: spot.lng,
        offer: offer,
        archived: spot.archived,
      );
    });

/// What S04.03-entry knows about the booking's spot (spec §5.1): the spot,
/// its entry event on sale and the provider's waiver on the day. A booking
/// "at" a spot is one from its schedule (`spotId`); a typed place carries
/// no coordinates, so `spotCoversPoint` has nothing to test in the flow.
@immutable
class BookingEntryInfo {
  const BookingEntryInfo({
    required this.spot,
    required this.event,
    required this.waiver,
  });

  final Spot spot;

  /// Null: the spot only has reference prices ("Chi phí tại chỗ").
  final EntryEvent? event;
  final Waiver waiver;

  /// "≈ {x}" for one person.
  int? get unitPrice => entryUnitPrice(event, spot.access);

  /// Tickets can be bought with the booking for [day].
  bool sellsOn(String day) => event != null && event!.isOpenDay(day);
}

typedef BookingEntryKey = ({String spotId, String providerId, String day});

/// Null while loading, for an open spot, or a spot without any price.
final bookingEntryInfoProvider = Provider.autoDispose
    .family<BookingEntryInfo?, BookingEntryKey>((ref, k) {
      final spot = ref.watch(spotProvider(k.spotId)).value;
      if (spot == null || !spot.isTicketed) return null;
      final event = ref.watch(entryEventProvider(k.spotId));
      final residents = ref.watch(spotResidentsProvider(k.spotId));
      if (!event.hasValue || !residents.hasValue) return null;
      final mine = residents.value!
          .where((r) => r.providerId == k.providerId)
          .firstOrNull;
      return BookingEntryInfo(
        spot: spot,
        event: event.value,
        waiver:
            mine?.waiverFor(k.day) ??
            (provider: false, guests: false, maxGuests: null),
      );
    });

/// The customer's ticket picks (one of the first type by default).
Map<String, int> entryPicksOf(BookingFlowState s, EntryEvent e) =>
    s.entryPicks ??
    {
      if (e.visibleTicketTypes.firstOrNull case final t?) t.id: 1,
    };

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

  /// Today (`yyyy-MM-dd`), as of the last build.
  String _today = '';

  @override
  BookingFlowState build() {
    ref.onDispose(() {
      _outcomesController.close();
    });

    // Listened, not watched: a rebuild would reset the whole flow (step,
    // picks, draft id) whenever the contact stream emits, e.g. on its first
    // load or when submit() saves a new phone. Only the phone follows it,
    // and only while the customer has not typed another number.
    ref.listen(currentContactProvider, (prev, next) {
      final phone = next.value?.phone;
      if (phone == null) return;
      if (state.phone == null || state.phone == prev?.value?.phone) {
        state = state.copyWith(phone: phone);
      }
    });
    final initialPhone = ref.read(currentContactProvider).value?.phone;

    final today = ref.watch(calendarTodayProvider);
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    _today = todayStr;

    String? initialDay;
    if (args.day != null && args.day!.compareTo(todayStr) >= 0) {
      initialDay = args.day;
    }

    // Booking from a spot: listened, not watched, like the contact above.
    SpotBookingContext? readyContext;
    if (args.scheduleId != null) {
      final contextProvider = bookingSpotContextProvider(args);
      ref.listen(contextProvider, (prev, next) {
        if (next.isLoading) return;
        final ctx = next.value;
        if (ctx != null) {
          applySpotContext(ctx);
        } else if (next.hasValue && state.spot != null) {
          // A reload found the schedule (or the slot's day) gone.
          _scheduleGone();
        }
      });
      final now = ref.read(contextProvider);
      if (!now.isLoading) readyContext = now.value;
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

    final initial = BookingFlowState(
      step: initialStep,
      serviceId: serviceId,
      priceVnd: priceVnd,
      durationMinutes: durationMinutes,
      serviceName: serviceName,
      day: initialDay,
      phone: initialPhone,
      addons: addons ?? const [],
    );
    return readyContext == null ? initial : _withSpot(initial, readyContext);
  }

  /// Applies the spot context: the place is the spot (Decision 9), the day one
  /// of the schedule's, and on the slot path the offer is the package and the
  /// flow opens on S04.03 without add-ons (T6). A second call (after
  /// `outside_schedule`) keeps the customer's choices that still fit.
  void applySpotContext(SpotBookingContext ctx) {
    state = _withSpot(state, ctx);
  }

  BookingFlowState _withSpot(BookingFlowState s, SpotBookingContext ctx) {
    final first = s.spot == null;
    final days = ctx.daysFrom(_today);
    final offer = ctx.offer;
    final String? day;
    if (first) {
      final want = args.day;
      day = want != null && days.contains(want)
          ? want
          // A slot is for its own day only (the provider checks it too).
          : (days.isEmpty || offer != null ? null : days.first);
    } else {
      day = days.contains(s.day) ? s.day : null;
    }
    var next = s.copyWith(
      spot: ctx,
      placeName: ctx.spotName,
      day: day,
      clearDay: day == null,
      clearStart: day != s.day,
      error: ctx.archived
          ? BookingErrorCode.spotArchived
          : (offer != null && day == null
                ? BookingErrorCode.outsideSchedule
                : null),
    );
    if (offer != null) {
      next = next.copyWith(
        serviceId: offer.id,
        priceVnd: offer.price,
        durationMinutes: offer.slotMinutes,
        serviceName: offer.name,
        start: first && day != null ? args.start : null,
        step: first && day != null ? BookingStep.review : null,
        priceChanged: !first && offer.price != s.priceVnd,
        picks: const {},
        pickupName: '',
      );
    } else {
      final packages = ref
          .read(profilePackagesProvider(args.photographerId))
          .value;
      if (packages != null) next = _fitPackage(next, ctx.packagesOf(packages));
    }
    if (day case final d?) {
      // After the current build or state change: it writes the state.
      Future.microtask(() => _loadSpotDay(d));
    }
    return next;
  }

  /// The spot schedule is no longer bookable: the slot path's sheet closes,
  /// the package path goes back to S04.02.
  void _scheduleGone() {
    final slot = state.isSlot;
    state = state.copyWith(
      step: slot ? null : BookingStep.datetime,
      clearDay: !slot,
      clearStart: !slot,
      clearBookingId: true,
      phase: SubmitPhase.idle,
      error: BookingErrorCode.outsideSchedule,
    );
  }

  /// Keeps the chosen package only when the spot schedule takes it; picks
  /// the schedule's only package for the customer.
  BookingFlowState _fitPackage(
    BookingFlowState s,
    List<ServiceSummary> allowed,
  ) {
    final id = s.serviceId;
    if (id != null && allowed.any((p) => p.id == id)) return s;
    if (allowed.length == 1) {
      final p = allowed.single;
      return s.copyWith(
        serviceId: p.id,
        priceVnd: p.priceVnd,
        durationMinutes: p.durationMinutes,
        serviceName: p.name,
        clearStart: p.durationMinutes != s.durationMinutes,
        picks: _fit(s.picks, s.addons, p.id).picks,
      );
    }
    if (id == null) return s;
    return s.copyWith(
      clearServiceId: true,
      clearStart: true,
      picks: const {},
      pickupName: '',
    );
  }

  /// Reads `spot_days/{scheduleId}_{day}` again (after `slot_taken`, or the
  /// S04.02 retry) and has S29.02/S29.06 read it again too.
  Future<void> refreshSpotDay(String day) => _loadSpotDay(day, fresh: true);

  /// Reads `spot_days/{scheduleId}_{day}` into the context; S04.02 shows the
  /// day's times once it is back.
  Future<void> _loadSpotDay(String day, {bool fresh = false}) async {
    if (!ref.mounted) return;
    final ctx = state.spot;
    if (ctx == null) return;
    final scheduleId = ctx.schedule.id;
    state = state.copyWith(
      spot: ctx.copyWith(
        takenByDay: {...ctx.takenByDay}..remove(day),
        failedDays: {...ctx.failedDays}..remove(day),
      ),
    );
    if (fresh) {
      // S29.02 and S29.06 read the same document through this provider.
      ref.invalidate(spotDayProvider((scheduleId: scheduleId, day: day)));
    }
    try {
      final spotDay = await ref
          .read(spotRepositoryProvider)
          .spotDay(scheduleId, day);
      if (!ref.mounted) return;
      final cur = state.spot;
      if (cur == null || cur.schedule.id != scheduleId) return;
      state = state.copyWith(
        spot: cur.copyWith(
          takenByDay: {...cur.takenByDay, day: spotDay?.taken ?? const []},
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      final cur = state.spot;
      if (cur == null) return;
      state = state.copyWith(
        spot: cur.copyWith(failedDays: {...cur.failedDays, day}),
      );
    }
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

  void applyPackages(List<ServiceSummary> all) {
    final list = state.spot?.packagesOf(all) ?? all;
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
    final ctx = state.spot;
    if (ctx != null && !ctx.takenByDay.containsKey(day)) {
      _loadSpotDay(day);
    }
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
    if (state.spot != null) return; // Decision 9: the place is the spot
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

  /// The S04.03-entry info of the current spot and day, if any.
  BookingEntryInfo? entryInfo() {
    final spotId = state.spot?.schedule.spotId;
    final day = state.day;
    if (spotId == null || day == null) return null;
    return ref.read(
      bookingEntryInfoProvider((
        spotId: spotId,
        providerId: args.photographerId,
        day: day,
      )),
    );
  }

  /// "Vé vào cửa" switch (S04.03-entry).
  void setEntryOn(bool on) {
    if (state.busy) return;
    state = state.copyWith(entryOn: on);
  }

  /// The customer's count of [typeId]; the order (with the provider's
  /// ticket) stays within [entryTicketsPerOrder].
  void setEntryCount(EntryEvent e, String typeId, int count, {
    required bool providerTicket,
  }) {
    if (state.busy || count < 0) return;
    final picks = Map<String, int>.of(entryPicksOf(state, e));
    final others = picks.entries
        .where((x) => x.key != typeId)
        .fold(0, (n, x) => n + x.value);
    if (others + count + (providerTicket ? 1 : 0) > entryTicketsPerOrder) {
      return;
    }
    if (count == 0) {
      picks.remove(typeId);
    } else {
      picks[typeId] = count;
    }
    state = state.copyWith(entryPicks: picks);
  }

  /// What `createBooking.entry` carries: the customer's picks for the
  /// booking day when the switch is on and something is to be paid.
  BookingEntryRequest? _entryRequest(BookingFlowState s) {
    final info = entryInfo();
    final day = s.day;
    final e = info?.event;
    if (!s.entryOn || info == null || e == null || day == null) return null;
    if (!info.sellsOn(day)) return null;
    final picks = entryPicksOf(s, e);
    final quote = quoteBookingEntry(
      event: e,
      picks: picks,
      waiver: info.waiver,
    );
    if (quote.amount <= 0) return null;
    return BookingEntryRequest(
      eventId: e.id,
      visitDay: day,
      items: [
        for (final t in e.visibleTicketTypes)
          if ((picks[t.id] ?? 0) > 0)
            EntryItem(ticketTypeId: t.id, qty: picks[t.id]!),
      ],
    );
  }

  void next() {
    if (!state.canContinue) return;
    _userActed = true;
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
    _userActed = true;
    switch (state.step) {
      case BookingStep.review:
        if (state.isSlot) return false; // S29.06 opened S04.03 directly
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
      final spot = s.spot;
      final bookingId = s.bookingId ??
          (await repo.createBooking(
            photographerId: args.photographerId,
            serviceId: s.serviceId!,
            day: s.day!,
            start: s.start!,
            place: BookingPlace(
              name: s.placeName.trim(),
              lat: spot?.lat,
              lng: spot?.lng,
            ),
            note: s.note.trim().isEmpty ? null : s.note.trim(),
            expectedPrice: s.priceVnd!,
            addons: picks,
            pickup: s.needsPickup
                ? BookingPlace(name: s.pickupName.trim())
                : null,
            expectedTotal: picks.isEmpty ? null : s.totalVnd,
            spotScheduleId: spot?.schedule.id,
            slotOfferId: spot?.offer?.id,
            entry: _entryRequest(s),
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
      case BookingErrorCode.priceChanged when state.isSlot:
        // The offer's price changed: reload it, stay on S04.03.
        state = state.copyWith(
          clearBookingId: true,
          phase: SubmitPhase.idle,
          error: BookingErrorCode.priceChanged,
        );
        ref.invalidate(bookingSpotContextProvider(args));
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
      // S30: the ticket day closed or sold out (S04.03-entry copy: Task 9).
      case BookingErrorCode.dayClosed:
      case BookingErrorCode.soldOutDay:
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
      case BookingErrorCode.slotTaken:
      case BookingErrorCode.outsideSchedule:
        // Package path: back to S04.02 with fresh times; the slot path's
        // sheet closes (S29.06 shows the fresh grid).
        final slot = state.isSlot;
        final day = state.day;
        state = state.copyWith(
          step: slot ? null : BookingStep.datetime,
          clearStart: !slot,
          clearBookingId: true,
          phase: SubmitPhase.idle,
          error: err,
        );
        if (err == BookingErrorCode.outsideSchedule) {
          ref.invalidate(bookingSpotContextProvider(args));
        } else if (day != null) {
          refreshSpotDay(day);
        }
      case BookingErrorCode.spotArchived:
        state = state.copyWith(
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

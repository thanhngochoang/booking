// test/support/fake_spot_repository.dart
import 'dart:async';

import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_repository.dart';

class FakeSpotRepository implements SpotRepository {
  final Map<String, Spot> spots = {};
  final Map<String, List<SpotEntry>> rankings = {};
  List<SpotEntry> directoryEntries = [];
  final Map<String, SpotSchedule> schedules = {};
  final Map<String, SlotOffer> offers = {};
  final Map<String, SpotDay> spotDays = {};
  final Map<String, List<PostSummary>> posts = {};
  final Map<String, List<EventSummary>> events = {};

  /// The signed-in provider that saves schedules and offers.
  String ownerId = 'provider_1';

  /// Thrown by the four writes while set (a refused callable).
  Object? saveScheduleError;
  Object? cancelScheduleError;
  Object? saveOfferError;
  Object? closeOfferError;

  final List<SpotScheduleInput> saveScheduleCalls = [];
  final List<String> cancelScheduleCalls = [];
  final List<SlotOfferInput> saveOfferCalls = [];
  final List<String> closeOfferCalls = [];

  final _scheduleChanges = StreamController<String>.broadcast();
  final _offerChanges = StreamController<String>.broadcast();

  int _nextScheduleId = 1;
  int _nextOfferId = 1;

  void seedSpot(Spot s) => spots[s.id] = s;
  void seedRanking(String key, List<SpotEntry> entries) => rankings[key] = entries;
  void seedDirectory(List<SpotEntry> entries) => directoryEntries = entries;
  void seedSchedule(SpotSchedule s) {
    schedules[s.id] = s;
    _scheduleChanges.add(s.providerId);
  }
  void seedOffer(SlotOffer o) {
    offers[o.id] = o;
    _offerChanges.add(o.providerId);
  }
  void seedSpotDay(SpotDay d) => spotDays['${d.scheduleId}_${d.day}'] = d;
  void seedPosts(String spotId, List<PostSummary> list) => posts[spotId] = list;
  void seedEvents(String spotId, List<EventSummary> list) => events[spotId] = list;

  @override
  Future<List<SpotEntry>> hot(String key) async {
    return rankings[key] ?? rankings['all'] ?? const [];
  }

  @override
  Future<List<SpotEntry>> directory() async {
    return directoryEntries;
  }

  @override
  Future<Spot?> spot(String spotId) async {
    return spots[spotId];
  }

  /// Thrown by the S29.02 section reads while set (a failed read).
  Object? openSchedulesError;
  Object? openOffersError;
  Object? eventsError;
  Object? postsError;

  @override
  Future<List<SpotSchedule>> openSchedulesAt(String spotId) async {
    if (openSchedulesError case final e?) throw e;
    return schedules.values
        .where((s) => s.spotId == spotId && s.open)
        .toList();
  }

  @override
  Future<List<SlotOffer>> openOffersAt(String spotId) async {
    if (openOffersError case final e?) throw e;
    return offers.values
        .where((o) => o.spotId == spotId && o.open)
        .toList();
  }

  /// Thrown by [spotDay] while set (a failed `spot_days` read).
  Object? spotDayError;

  /// Every `spot_days` read, as `{scheduleId}_{day}`.
  final List<String> spotDayReads = [];

  @override
  Future<SpotDay?> spotDay(String scheduleId, String day) async {
    spotDayReads.add('${scheduleId}_$day');
    if (spotDayError case final e?) throw e;
    return spotDays['${scheduleId}_$day'];
  }

  @override
  Future<SpotSchedule?> schedule(String scheduleId) async {
    return schedules[scheduleId];
  }

  @override
  Future<SlotOffer?> offer(String offerId) async {
    return offers[offerId];
  }

  @override
  Future<List<PostSummary>> postsAt(
    String spotId, {
    DateTime? before,
    int limit = 20,
  }) async {
    if (postsError case final e?) throw e;
    var list = posts[spotId] ?? const [];
    if (before != null) {
      list = list.where((p) => p.createdAt.isBefore(before)).toList();
    }
    return list.take(limit).toList();
  }

  @override
  Future<List<EventSummary>> eventsAt(String spotId, {int limit = 10}) async {
    if (eventsError case final e?) throw e;
    final now = DateTime.now();
    final list = events[spotId] ?? const [];
    return list
        .where((e) => !e.startsAt.isBefore(now))
        .take(limit)
        .toList();
  }

  @override
  Stream<List<SpotSchedule>> watchMine(String uid) {
    List<SpotSchedule> mine() =>
        schedules.values.where((s) => s.providerId == uid && s.open).toList();

    return _startWith(mine, _scheduleChanges.stream.where((pId) => pId == uid));
  }

  @override
  Stream<List<SlotOffer>> watchMyOffers(String uid) {
    List<SlotOffer> mine() =>
        offers.values.where((o) => o.providerId == uid && o.open).toList();

    return _startWith(mine, _offerChanges.stream.where((pId) => pId == uid));
  }

  @override
  Future<({String scheduleId, List<String> addedDays})> saveSchedule(
    SpotScheduleInput input,
  ) async {
    saveScheduleCalls.add(input);
    if (saveScheduleError case final e?) throw e;
    final id = input.scheduleId ?? 'schedule_${_nextScheduleId++}';
    final s = SpotSchedule(
      id: id,
      providerId: ownerId,
      spotId: input.spotId,
      assigneeId: input.assigneeId,
      days: input.days,
      window: input.window,
      serviceIds: input.serviceIds,
      priceFrom: 100000,
      open: true,
    );
    schedules[id] = s;
    _scheduleChanges.add(s.providerId);
    return (scheduleId: id, addedDays: input.days);
  }

  @override
  Future<void> cancelSchedule(String scheduleId) async {
    cancelScheduleCalls.add(scheduleId);
    if (cancelScheduleError case final e?) throw e;
    final s = schedules[scheduleId];
    if (s != null) {
      schedules[scheduleId] = SpotSchedule(
        id: s.id,
        providerId: s.providerId,
        spotId: s.spotId,
        assigneeId: s.assigneeId,
        days: s.days,
        window: s.window,
        serviceIds: s.serviceIds,
        priceFrom: s.priceFrom,
        open: false,
      );
      _scheduleChanges.add(s.providerId);
    }
  }

  @override
  Future<String> saveOffer(SlotOfferInput input) async {
    saveOfferCalls.add(input);
    if (saveOfferError case final e?) throw e;
    final id = input.offerId ?? 'offer_${_nextOfferId++}';
    final o = SlotOffer(
      id: id,
      providerId: ownerId,
      scheduleId: input.scheduleId,
      spotId: schedules[input.scheduleId]?.spotId ?? 'spot_1',
      name: input.name,
      price: input.price,
      slotMinutes: input.slotMinutes,
      gapMinutes: input.gapMinutes,
      photoCount: input.photoCount,
      editedCount: input.editedCount,
      deliveryDays: input.deliveryDays,
      open: true,
    );
    offers[id] = o;
    _offerChanges.add(o.providerId);
    return id;
  }

  @override
  Future<void> closeOffer(String offerId) async {
    closeOfferCalls.add(offerId);
    if (closeOfferError case final e?) throw e;
    final o = offers[offerId];
    if (o != null) {
      offers[offerId] = SlotOffer(
        id: o.id,
        providerId: o.providerId,
        scheduleId: o.scheduleId,
        spotId: o.spotId,
        name: o.name,
        price: o.price,
        slotMinutes: o.slotMinutes,
        gapMinutes: o.gapMinutes,
        photoCount: o.photoCount,
        editedCount: o.editedCount,
        deliveryDays: o.deliveryDays,
        open: false,
      );
      _offerChanges.add(o.providerId);
    }
  }

  /// The current list now, then again after every change.
  static Stream<List<T>> _startWith<T>(
    List<T> Function() current,
    Stream<String> changes,
  ) async* {
    yield current();
    yield* changes.map((_) => current());
  }
}

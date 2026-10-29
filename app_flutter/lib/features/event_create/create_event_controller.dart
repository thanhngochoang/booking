// lib/features/event_create/create_event_controller.dart
import 'dart:async';

import 'package:flutter/widgets.dart'
    show immutable, StringCharacters, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/features/event_create/event_draft_store.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

/// The fields of the two steps, so an error can sit under its field and the
/// summary can jump to it.
enum EventField {
  cover(1),
  title(1),

  /// S12.01 "Điểm chụp" (S29): a spot, or "Không thuộc điểm chụp nào".
  spot(1),

  /// S12.01-venue "Địa điểm · bắt buộc" (Decision 16): the kind and its
  /// parts (see [EventForm.venueIssue] for the codes).
  venue(1),

  /// S12.01-venue "Tôi đồng ý điều khoản tổ chức sự kiện."
  terms(1),
  type(1),
  description(1),
  day(2),
  start(2),
  end(2),
  capacity(2),
  place(2),
  hashtag(2),
  price(2),
  deadline(2),

  /// Staff only, platform events (owner decision O2).
  faq(2);

  const EventField(this.step);

  /// The step (1 or 2) the field is on.
  final int step;
}

/// Limits the server enforces (domain `validateEventFields`); mirrored here
/// for instant feedback. The server stays the authority.
const eventTitleMax = 80;
const eventDescriptionMax = 1000;
const eventCapacityMax = 500;
const eventPriceMax = 100000000;
const eventPriceStep = 1000;
const eventPublishLead = Duration(hours: 2);

/// Domain `EVENT_FAQ_MAX`, `FAQ_QUESTION_MAX`, `FAQ_ANSWER_MAX`.
const eventFaqMax = 10;
const eventFaqQuestionMax = 120;
const eventFaqAnswerMax = 500;

final _hashtagPattern = RegExp(r'^[A-Za-z0-9]{3,40}$');

/// What is wrong with [d], keyed by field; the value is a code:
/// `required`, `too_long`, `end_before_start`, `same_day`, `start_soon`,
/// `range`, `step`, `after_start`, `format`. (`spot`: `required`.) Pure and total: it checks the
/// draft as the server checks it at publish (complete, start at least 2 hours
/// ahead, one day, deadline not after the start). Empty means publishable.
Map<EventField, String> createEventErrors(
  EventDraft d, {
  required DateTime now,
}) {
  final errors = <EventField, String>{};
  if (d.coverUrl == null) {
    errors[EventField.cover] = 'required';
  }
  final title = d.title?.trim() ?? '';
  if (title.isEmpty) {
    errors[EventField.title] = 'required';
  } else if (title.characters.length > eventTitleMax) {
    errors[EventField.title] = 'too_long';
  }
  if (d.type == null) {
    errors[EventField.type] = 'required';
  }
  if (!d.spotDecided) {
    errors[EventField.spot] = 'required';
  }
  // Events made after `VENUE_REQUIRED_FROM` (in the past) publish with one.
  if (d.venue == null) {
    errors[EventField.venue] = 'required';
  }
  if ((d.description ?? '').trim().characters.length > eventDescriptionMax) {
    errors[EventField.description] = 'too_long';
  }

  final start = d.startsAt;
  final end = d.endsAt;
  if (start == null && end == null) {
    errors[EventField.day] = 'required';
  } else {
    if (start == null) {
      errors[EventField.start] = 'required';
    }
    if (end == null) {
      errors[EventField.end] = 'required';
    }
  }
  if (start != null && end != null) {
    if (vnDateKey(start) != vnDateKey(end)) {
      errors[EventField.end] = 'same_day';
    } else if (!end.isAfter(start)) {
      errors[EventField.end] = 'end_before_start';
    }
  }
  if (start != null && start.isBefore(now.add(eventPublishLead))) {
    errors[EventField.start] = 'start_soon';
  }

  final capacity = d.capacity;
  if (capacity == null) {
    errors[EventField.capacity] = 'required';
  } else if (capacity < 1 || capacity > eventCapacityMax) {
    errors[EventField.capacity] = 'range';
  }

  if (d.place == null) {
    errors[EventField.place] = 'required';
  }

  final price = d.priceVnd;
  if (price == null) {
    errors[EventField.price] = 'required';
  } else if (price < 0 ||
      price > eventPriceMax ||
      price % eventPriceStep != 0) {
    errors[EventField.price] = 'step';
  }

  final deadline = d.registrationDeadline;
  if (deadline != null && start != null && deadline.isAfter(start)) {
    errors[EventField.deadline] = 'after_start';
  }

  final tag = d.hashtag;
  if (tag != null && !_hashtagPattern.hasMatch(tag)) {
    errors[EventField.hashtag] = 'format';
  }
  return errors;
}

/// [createEventErrors] on what the person typed: a day chosen without times,
/// or a place name without a point, are told apart from "nothing entered".
/// [venueSpot] is the venue's spot once read (its manager decides which
/// kinds fit).
Map<EventField, String> eventFormErrors(
  EventForm form, {
  required DateTime now,
  Spot? venueSpot,
}) {
  final errors = createEventErrors(form.toDraft(), now: now)
    ..remove(EventField.venue);
  if (form.venueIssue(spot: venueSpot) case final issue?) {
    errors[EventField.venue] = issue;
  }
  if (!form.termsAccepted) {
    errors[EventField.terms] = 'required';
  }
  if (form.day != null) {
    if (errors[EventField.day] == 'required') {
      errors.remove(EventField.day);
      if (form.startMinute == null) {
        errors[EventField.start] = 'required';
      }
      if (form.endMinute == null) {
        errors[EventField.end] = 'required';
      }
    }
  } else if (form.startMinute != null || form.endMinute != null) {
    errors[EventField.day] = 'required';
  }
  if (form.placeName.trim().isNotEmpty &&
      (form.lat == null || form.lng == null)) {
    errors[EventField.place] = 'point';
  }
  if (form.hasIncompleteFaq) {
    errors[EventField.faq] = 'incomplete';
  }
  return errors;
}

/// What the screen opens with: a server draft to resume (from the list), or
/// nothing for a new event. The local copy of the form wins when it is of the
/// same draft, because it holds edits not yet sent.
@immutable
class CreateEventArgs {
  const CreateEventArgs({this.resumeId, this.seed});

  final String? resumeId;
  final EventDraft? seed;

  @override
  bool operator ==(Object other) =>
      other is CreateEventArgs &&
      other.resumeId == resumeId &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(resumeId, seed);
}

/// Why the last save or publish did not finish, for the screen to word.
enum CreateEventFailure { none, network, save, cover, publish }

@immutable
class CreateEventState {
  const CreateEventState({
    required this.form,
    this.step = 1,
    this.pendingCover,
    this.touched = const {},
    this.serverErrors = const {},
    this.summary = false,
    this.busy = false,
    this.failure = CreateEventFailure.none,
    this.venueSpot,
    this.awaitingVenue = false,
  });

  final EventForm form;
  final int step;

  /// A cover picked but not uploaded yet (it goes up at "Tiếp tục").
  final PickedImage? pendingCover;

  /// Fields whose error may show: edited, or every field after a failed
  /// publish.
  final Set<EventField> touched;

  /// Codes the server refused with: `taken` (hashtag), `day_taken` (day).
  final Map<EventField, String> serverErrors;

  /// True after a failed publish: the error summary is shown at the top.
  final bool summary;
  final bool busy;
  final CreateEventFailure failure;

  /// The chosen spot as read from `spots/{id}` (its manager and reference
  /// fees); null until read, or without a spot.
  final Spot? venueSpot;

  /// The last publish only asked the venue's manager (Decision 16): the
  /// event stays a draft "Chờ địa điểm đồng ý".
  final bool awaitingVenue;

  bool get hasCover => pendingCover != null || form.coverUrl != null;

  /// "Tiếp tục" needs the cover, a title and a type.
  bool get stepOneReady =>
      hasCover && form.title.trim().isNotEmpty && form.type != null;

  CreateEventState copyWith({
    EventForm? form,
    int? step,
    Object? pendingCover = _keep,
    Set<EventField>? touched,
    Map<EventField, String>? serverErrors,
    bool? summary,
    bool? busy,
    CreateEventFailure? failure,
    Object? venueSpot = _keep,
    bool? awaitingVenue,
  }) => CreateEventState(
    form: form ?? this.form,
    step: step ?? this.step,
    pendingCover: identical(pendingCover, _keep)
        ? this.pendingCover
        : pendingCover as PickedImage?,
    touched: touched ?? this.touched,
    serverErrors: serverErrors ?? this.serverErrors,
    summary: summary ?? this.summary,
    busy: busy ?? this.busy,
    failure: failure ?? this.failure,
    venueSpot: identical(venueSpot, _keep)
        ? this.venueSpot
        : venueSpot as Spot?,
    awaitingVenue: awaitingVenue ?? this.awaitingVenue,
  );
}

const _keep = Object();

final eventDraftStoreProvider = Provider<EventDraftStore>(
  (ref) => EventDraftStore(ref.watch(sharedPreferencesProvider)),
);

final createEventControllerProvider = NotifierProvider.autoDispose
    .family<CreateEventController, CreateEventState, CreateEventArgs>(
      CreateEventController.new,
    );

/// Drives S12.01 and S12.02. Every edit is kept on the device (`eventDraft:`
/// + uid); "Tiếp tục", "Lưu nháp" and "Đăng sự kiện" go through the event
/// repository, which talks to the Cloud Functions.
class CreateEventController extends Notifier<CreateEventState> {
  CreateEventController(this.args);

  final CreateEventArgs args;

  String? get _uid => ref.read(authStateProvider).value?.uid;

  DateTime get _now => ref.read(clockProvider)();

  @override
  CreateEventState build() {
    final uid = _uid;
    final stored = uid == null
        ? null
        : ref.read(eventDraftStoreProvider).load(uid);
    final seed = args.seed;
    EventForm form;
    if (args.resumeId != null) {
      // The local copy wins only when it is of this very draft.
      form = stored != null && stored.eventId == args.resumeId
          ? stored
          : (seed == null ? const EventForm() : EventForm.fromDraft(seed));
    } else {
      form = stored ?? const EventForm();
    }
    final spotId = form.spotId;
    if (spotId != null) {
      Future.microtask(() => _loadVenueSpot(spotId));
    }
    return CreateEventState(form: form);
  }

  /// Reads the chosen spot for the venue part (its manager, its reference
  /// fees). Best effort: an unreadable spot leaves the checks to the server.
  Future<void> _loadVenueSpot(String spotId) async {
    Spot? spot;
    try {
      spot = await ref.read(spotRepositoryProvider).spot(spotId);
    } catch (_) {
      spot = null;
    }
    if (!ref.mounted || state.form.spotId != spotId) {
      return;
    }
    state = state.copyWith(venueSpot: spot);
    _prefillEntryFee();
  }

  /// §7.1: a paid place not included at a spot with reference fees gets the
  /// first one while the host typed none.
  void _prefillEntryFee() {
    final f = state.form;
    final first = state.venueSpot?.access?.fees.firstOrNull;
    if (f.venueKind == VenueKind.paidPlace &&
        f.entryFeeIncluded == false &&
        f.entryFeeVnd == null &&
        first != null &&
        state.venueSpot?.id == f.spotId) {
      state = state.copyWith(form: f.copyWith(entryFeeVnd: first.amountVnd));
      _persist();
    }
  }

  EventRepository get _repo => ref.read(eventRepositoryProvider);

  Map<EventField, String> get fieldErrors =>
      eventFormErrors(state.form, now: _now, venueSpot: state.venueSpot);

  /// Errors the screen shows now: those of touched fields, plus the server's.
  Map<EventField, String> get shownErrors {
    final all = fieldErrors;
    return {
      for (final e in all.entries)
        if (state.touched.contains(e.key)) e.key: e.value,
      ...state.serverErrors,
    };
  }

  // ---- edits --------------------------------------------------------------

  void _edit(
    EventForm form, {
    EventField? field,
    Set<EventField> clearServer = const {},
  }) {
    if (state.busy) {
      return;
    }
    final server = {...state.serverErrors}
      ..removeWhere((k, _) => clearServer.contains(k) || k == field);
    state = state.copyWith(
      form: form,
      touched: field == null ? null : {...state.touched, field},
      serverErrors: server,
      failure: CreateEventFailure.none,
    );
    _persist();
  }

  void _persist() {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    unawaited(ref.read(eventDraftStoreProvider).save(uid, state.form));
  }

  Future<void> pickCover() async {
    if (state.busy) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: 1);
    if (!ref.mounted || picked.isEmpty) {
      return;
    }
    state = state.copyWith(
      pendingCover: picked.first,
      touched: {...state.touched, EventField.cover},
      failure: CreateEventFailure.none,
    );
  }

  void setTitle(String v) =>
      _edit(state.form.copyWith(title: v), field: EventField.title);
  void setType(EventType? v) =>
      _edit(state.form.copyWith(type: v), field: EventField.type);
  void setDescription(String v) =>
      _edit(state.form.copyWith(description: v), field: EventField.description);

  /// [day] is a calendar date in Việt Nam (any time of day is ignored).
  void setDay(DateTime? day) {
    final d = day == null ? null : DateTime.utc(day.year, day.month, day.day);
    _edit(
      state.form.copyWith(day: d),
      field: EventField.day,
      clearServer: {EventField.day},
    );
  }

  /// [minute] is minutes since midnight in Việt Nam.
  void setStart(int? minute) =>
      _edit(state.form.copyWith(startMinute: minute), field: EventField.start);
  void setEnd(int? minute) =>
      _edit(state.form.copyWith(endMinute: minute), field: EventField.end);
  void setCapacity(int? v) =>
      _edit(state.form.copyWith(capacity: v), field: EventField.capacity);
  void setPrice(int? v) =>
      _edit(state.form.copyWith(priceVnd: v), field: EventField.price);
  void setDeadline(DateTime? day) => _edit(
    state.form.copyWith(
      deadlineDay: day == null
          ? null
          : DateTime.utc(day.year, day.month, day.day),
    ),
    field: EventField.deadline,
  );

  /// The FAQ rows as typed (owner decision O2); half-filled rows stay in the
  /// form and are flagged, only complete ones are sent.
  void setFaq(List<EventFaq> rows) => _edit(
    state.form.copyWith(faq: List.unmodifiable(rows)),
    field: EventField.faq,
  );

  /// Without the `#`; empty keeps the generated one.
  void setHashtag(String v) {
    final t = v.replaceAll('#', '').trim();
    _edit(
      state.form.copyWith(hashtag: t.isEmpty ? null : t),
      field: EventField.hashtag,
      clearServer: {EventField.hashtag},
    );
  }

  /// S12.01 "Điểm chụp": [spot] is the chosen spot, null is "Không thuộc điểm
  /// chụp nào". A spot also fills an empty place with itself (the organizer
  /// can edit it inside the spot's radius).
  ///
  /// [previous] is the spot that was chosen before: a place that still equals
  /// its auto-fill moves to the new spot, a place the organizer typed stays.
  void setSpot(SpotEntry? spot, {SpotEntry? previous}) {
    var form = state.form.copyWith(spotId: spot?.spotId);
    final empty =
        form.placeName.trim().isEmpty && form.lat == null && form.lng == null;
    final autoFilled =
        previous != null &&
        form.placeName == previous.name &&
        form.lat == previous.lat &&
        form.lng == previous.lng &&
        form.areaId == null;
    if (spot != null && (empty || autoFilled)) {
      form = form.copyWith(
        placeName: spot.name,
        areaId: null,
        lat: spot.lat,
        lng: spot.lng,
      );
    }
    _edit(
      form,
      field: EventField.spot,
      clearServer: {EventField.spot, EventField.venue},
    );
    final id = spot?.spotId;
    state = state.copyWith(venueSpot: null);
    if (id != null) {
      unawaited(_loadVenueSpot(id));
    }
  }

  // ---- S12.01-venue -------------------------------------------------------

  void _editVenue(EventForm form, {EventField field = EventField.venue}) =>
      _edit(form, field: field, clearServer: {field});

  void setVenueKind(VenueKind kind) {
    _editVenue(state.form.copyWith(venueKind: kind));
    _prefillEntryFee();
  }

  /// A paid place: "Đã gồm phí vào cửa" (true) or "Chưa gồm" (false).
  void setEntryFeeIncluded(bool included) {
    _editVenue(state.form.copyWith(entryFeeIncluded: included));
    _prefillEntryFee();
  }

  /// The reference fee per guest; null when the field is emptied.
  void setEntryFee(int? vnd) =>
      _editVenue(state.form.copyWith(entryFeeVnd: vnd));

  /// A public place: the commitment tick, stamped with the clock.
  void setCommitment(bool ticked) =>
      _editVenue(state.form.copyWith(commitmentAt: ticked ? _now : null));

  void setTerms(bool accepted) => _editVenue(
    state.form.copyWith(termsAccepted: accepted),
    field: EventField.terms,
  );

  /// The place's name and meeting point as typed.
  void setPlaceText({String? name, String? meetingPoint}) => _edit(
    state.form.copyWith(placeName: name, meetingPoint: meetingPoint),
    field: EventField.place,
    clearServer: {EventField.spot},
  );

  /// Picks an area: its centre becomes the point.
  void chooseArea(String areaId, {required double lat, required double lng}) =>
      _edit(
        state.form.copyWith(areaId: areaId, lat: lat, lng: lng),
        field: EventField.place,
        clearServer: {EventField.spot},
      );

  /// "Dùng vị trí hiện tại": the device position replaces the point (the
  /// chosen area, if any, stays).
  void useDevicePoint({required double lat, required double lng}) => _edit(
    state.form.copyWith(lat: lat, lng: lng),
    field: EventField.place,
    clearServer: {EventField.spot},
  );

  void goToStep(int step) {
    if (!state.busy && (step == 1 || step == 2) && step != state.step) {
      state = state.copyWith(step: step);
    }
  }

  /// Test seam: the cover as saved by "Tiếp tục".
  @visibleForTesting
  void debugSetCover(String url, String path) => state = state.copyWith(
    form: state.form.copyWith(coverUrl: url, coverPath: path),
  );

  /// Marks every field as touched, so all their errors show.
  void touchAll() => state = state.copyWith(touched: {...EventField.values});

  // ---- server -------------------------------------------------------------

  /// Sends the form to the server as a draft. A cover not yet uploaded is
  /// uploaded after the first save made the draft id, and saved with a second
  /// call; the cover it replaces is deleted only after that save worked.
  Future<bool> _saveToServer() async {
    final repo = _repo;
    var form = state.form;
    final pending = state.pendingCover;
    String? orphan;
    try {
      if (pending != null) {
        if (form.eventId == null) {
          final first = await repo.saveDraft(form.toDraft(withCover: false));
          form = form.copyWith(
            eventId: first.eventId,
            hashtag: form.hashtag ?? first.hashtag,
          );
          state = state.copyWith(form: form);
          _persist();
        }
        final url = await repo.uploadCover(form.eventId!, pending);
        final path = repo.coverPathOf(url);
        orphan = path;
        final previous = form.coverPath;
        final withCover = form.copyWith(coverUrl: url, coverPath: path);
        final saved = await repo.saveDraft(withCover.toDraft());
        orphan = null;
        form = withCover.copyWith(
          eventId: saved.eventId,
          hashtag: saved.hashtag,
        );
        state = state.copyWith(form: form, pendingCover: null);
        if (previous != null && previous != path) {
          unawaited(repo.deleteCover(previous));
        }
      } else {
        final saved = await repo.saveDraft(form.toDraft());
        form = form.copyWith(eventId: saved.eventId, hashtag: saved.hashtag);
        state = state.copyWith(form: form);
      }
      _persist();
      return true;
    } catch (e) {
      if (orphan != null) {
        unawaited(repo.deleteCover(orphan));
      }
      _fail(e, saving: true);
      return false;
    }
  }

  void _fail(Object error, {required bool saving}) {
    final code = eventErrorCodeOf(error);
    switch (code) {
      case 'day_taken':
        state = state.copyWith(
          serverErrors: {...state.serverErrors, EventField.day: 'day_taken'},
          failure: CreateEventFailure.none,
        );
      case 'conflict':
        state = state.copyWith(
          serverErrors: {...state.serverErrors, EventField.hashtag: 'taken'},
          failure: CreateEventFailure.none,
        );
      case 'spot_archived':
        _spotRefused('archived');
      case 'not_found' when eventErrorFieldOf(error) == 'spotId':
        _spotRefused('gone');
      case 'invalid_argument' when eventErrorFieldOf(error) == 'spotId':
        _spotRefused('far');
      case 'invalid_argument'
          when _venueCodes.containsKey(eventErrorFieldOf(error)):
        final (field, venueCode) = _venueCodes[eventErrorFieldOf(error)]!;
        state = state.copyWith(
          serverErrors: {...state.serverErrors, field: venueCode},
          failure: CreateEventFailure.none,
        );
      case 'network':
        state = state.copyWith(failure: CreateEventFailure.network);
      default:
        state = state.copyWith(
          failure: saving
              ? CreateEventFailure.save
              : CreateEventFailure.publish,
        );
    }
  }

  /// `invalid_argument` fields of the venue block → where they show.
  static const _venueCodes = {
    'venue': (EventField.venue, 'required'),
    'kind': (EventField.venue, 'managed'),
    'entryFee': (EventField.venue, 'fee'),
    'commitmentAt': (EventField.venue, 'commitment'),
    'termsVersion': (EventField.terms, 'required'),
  };

  void _spotRefused(String code) => state = state.copyWith(
    serverErrors: {...state.serverErrors, EventField.spot: code},
    failure: CreateEventFailure.none,
  );

  /// S12.01 "Tiếp tục": saves the draft (and the cover), then step 2.
  Future<bool> next() async {
    if (state.busy || !state.stepOneReady) {
      return false;
    }
    final errors = fieldErrors;
    final venueOk =
        !errors.containsKey(EventField.venue) &&
        !errors.containsKey(EventField.terms);
    if (!state.form.spotDecided || !venueOk) {
      // The choices are required: their errors show under the fields.
      state = state.copyWith(
        touched: {
          ...state.touched,
          EventField.spot,
          EventField.venue,
          EventField.terms,
        },
        failure: CreateEventFailure.none,
      );
      return false;
    }
    state = state.copyWith(busy: true, failure: CreateEventFailure.none);
    final ok = await _saveToServer();
    if (!ref.mounted) {
      return ok;
    }
    state = state.copyWith(busy: false, step: ok ? 2 : null);
    return ok;
  }

  /// S12.02 "Lưu nháp" (and "Lưu" in the leave prompt). Without a title and a
  /// type there is nothing the server accepts yet: the local copy is kept and
  /// this reports success.
  Future<bool> saveDraft() async {
    if (state.busy) {
      return false;
    }
    final f = state.form;
    if (f.title.trim().isEmpty || f.type == null) {
      _persist();
      return true;
    }
    state = state.copyWith(busy: true, failure: CreateEventFailure.none);
    final ok = await _saveToServer();
    if (!ref.mounted) {
      return ok;
    }
    state = state.copyWith(busy: false);
    return ok;
  }

  /// S12.02 "Đăng sự kiện": checks every field, saves, publishes. Returns the
  /// event id, or null with the reason in the state (field errors, the
  /// summary, or a failure).
  Future<String?> publish() async {
    if (state.busy) {
      return null;
    }
    final errors = fieldErrors;
    if (errors.isNotEmpty) {
      state = state.copyWith(
        touched: {...EventField.values},
        summary: true,
        failure: CreateEventFailure.none,
      );
      return null;
    }
    state = state.copyWith(
      busy: true,
      summary: false,
      serverErrors: const {},
      failure: CreateEventFailure.none,
    );
    final saved = await _saveToServer();
    if (!ref.mounted) {
      return null;
    }
    final id = state.form.eventId;
    if (!saved || id == null) {
      state = state.copyWith(
        busy: false,
        summary: state.serverErrors.isNotEmpty,
      );
      return null;
    }
    var awaiting = false;
    try {
      await _repo.publish(id);
      // `publishEvent` also answers ok when it only asked the venue's
      // manager: the event is then still a draft (Decision 16).
      awaiting = _waitsForVenue();
    } catch (e) {
      if (!ref.mounted) {
        return null;
      }
      if (eventErrorCodeOf(e) == 'venue_consent_required') {
        // Asked before and not answered yet: still "Chờ địa điểm đồng ý".
        awaiting = true;
      } else {
        _fail(e, saving: false);
        state = state.copyWith(
          busy: false,
          summary: state.serverErrors.isNotEmpty,
        );
        return null;
      }
    }
    if (ref.mounted) {
      state = state.copyWith(awaitingVenue: awaiting);
    }
    final uid = _uid;
    if (uid != null) {
      await ref.read(eventDraftStoreProvider).clear(uid);
    }
    if (ref.mounted) {
      state = state.copyWith(busy: false);
    }
    return id;
  }

  /// `publishEvent` answers ok also when it only asked the venue's manager
  /// (Decision 16: a managed spot whose manager is not the host); the event
  /// then stays a draft. Known from the form and the spot read for it; the
  /// manage page (S12.03) re-reads the event and shows "chờ đồng ý".
  bool _waitsForVenue() {
    final spot = state.venueSpot;
    return state.form.venueKind == VenueKind.managedSpot &&
        spot != null &&
        spot.id == state.form.spotId &&
        spot.managedBy != null &&
        spot.managedBy != _uid;
  }

  /// "Bỏ" in the leave prompt: forgets the local copy (a server draft stays).
  Future<void> discard() async {
    final uid = _uid;
    if (uid != null) {
      await ref.read(eventDraftStoreProvider).clear(uid);
    }
  }
}

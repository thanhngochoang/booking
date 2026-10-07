import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_draft.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/event_create/create_event_controller.dart';
import 'package:photobooking/features/event_create/event_draft_store.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/event_world.dart';

/// Refuses `publishEvent` with a domain code; saves work.
class _PublishRefuses extends FakeEventRepository {
  _PublishRefuses(this.code) : super(uid: 'u1');
  final String code;

  @override
  Future<void> publish(String eventId) async => throw EventError(code);
}

EventDraft _complete({int priceVnd = 250000}) => EventDraft(
  title: 'Photo walk',
  type: EventType.photoWalk,
  coverUrl: 'https://storage.test/eventCovers/u1/e/c.jpg',
  coverPath: 'eventCovers/u1/e/c.jpg',
  startsAt: DateTime.utc(2026, 10, 13, 2),
  endsAt: DateTime.utc(2026, 10, 13, 5),
  place: const EventPlace(name: 'Hồ', lat: 21, lng: 105),
  capacity: 20,
  priceVnd: priceVnd,
);

Future<(ProviderContainer, FakeEventRepository)> _container({
  FakeEventRepository? repo,
  Map<String, Object> prefs = const {},
  List<List<PickedImage>> covers = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final r = repo ?? FakeEventRepository(uid: 'u1');
  final c = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(const AuthUser(uid: 'u1')),
      ),
      sharedPreferencesProvider.overrideWithValue(sp),
      eventRepositoryProvider.overrideWithValue(r),
      imagePickerProvider.overrideWithValue(FakeImagePicker(covers)),
      clockProvider.overrideWithValue(() => eventNow),
    ],
  );
  addTearDown(c.dispose);
  // The controller is autoDispose: a listener keeps it alive across awaits.
  c.listen(createEventControllerProvider(const CreateEventArgs()), (_, _) {});
  c.listen(authStateProvider, (_, _) {});
  await c.read(authStateProvider.future);
  return (c, r);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = eventNow; // 10 Oct 2026 10:00 in Việt Nam

  group('createEventErrors', () {
    test('a complete draft has no errors', () {
      expect(createEventErrors(_complete(), now: now), isEmpty);
    });

    test('an empty draft lists what step 1 and 2 need', () {
      final e = createEventErrors(const EventDraft(), now: now);
      expect(
        e.keys,
        containsAll([
          EventField.cover,
          EventField.title,
          EventField.type,
          EventField.day,
          EventField.capacity,
          EventField.place,
          EventField.price,
        ]),
      );
      expect(e[EventField.title], 'required');
    });

    test('title and description limits', () {
      final long = EventDraft(title: 'a' * 81, description: 'b' * 1001);
      final e = createEventErrors(long, now: now);
      expect(e[EventField.title], 'too_long');
      expect(e[EventField.description], 'too_long');
      expect(
        createEventErrors(
          EventDraft(title: 'a' * 80),
          now: now,
        )[EventField.title],
        isNull,
      );
    });

    test('the end must be after the start and on the same day', () {
      var d = EventDraft(
        startsAt: DateTime.utc(2026, 10, 13, 2),
        endsAt: DateTime.utc(2026, 10, 13, 1),
      );
      expect(
        createEventErrors(d, now: now)[EventField.end],
        'end_before_start',
      );
      d = EventDraft(
        startsAt: DateTime.utc(2026, 10, 13, 12), // 19:00 VN
        endsAt: DateTime.utc(2026, 10, 13, 18), // 01:00 next day VN
      );
      expect(createEventErrors(d, now: now)[EventField.end], 'same_day');
    });

    test('the start must be 2 hours ahead', () {
      final soon = EventDraft(
        startsAt: now.add(const Duration(hours: 1, minutes: 59)),
        endsAt: now.add(const Duration(hours: 4)),
      );
      expect(createEventErrors(soon, now: now)[EventField.start], 'start_soon');
      final ok = EventDraft(
        startsAt: now.add(const Duration(hours: 2)),
        endsAt: now.add(const Duration(hours: 3)),
      );
      expect(createEventErrors(ok, now: now)[EventField.start], isNull);
    });

    test('capacity 1–500', () {
      for (final bad in [0, 501, -1]) {
        expect(
          createEventErrors(
            EventDraft(capacity: bad),
            now: now,
          )[EventField.capacity],
          'range',
        );
      }
      expect(
        createEventErrors(
          const EventDraft(capacity: 500),
          now: now,
        )[EventField.capacity],
        isNull,
      );
    });

    test('price is a multiple of 1.000 up to 100.000.000, 0 is free', () {
      EventDraft p(int v) => EventDraft(priceVnd: v);
      expect(createEventErrors(p(0), now: now)[EventField.price], isNull);
      expect(createEventErrors(p(250000), now: now)[EventField.price], isNull);
      expect(createEventErrors(p(250500), now: now)[EventField.price], 'step');
      expect(
        createEventErrors(p(100001000), now: now)[EventField.price],
        'step',
      );
      expect(createEventErrors(p(-1000), now: now)[EventField.price], 'step');
    });

    test('the deadline may not be after the start', () {
      final start = DateTime.utc(2026, 10, 13, 2);
      final late = EventDraft(
        startsAt: start,
        endsAt: start.add(const Duration(hours: 2)),
        registrationDeadline: start.add(const Duration(minutes: 1)),
      );
      expect(
        createEventErrors(late, now: now)[EventField.deadline],
        'after_start',
      );
      final onTime = EventDraft(
        startsAt: start,
        endsAt: start.add(const Duration(hours: 2)),
        registrationDeadline: start,
      );
      expect(createEventErrors(onTime, now: now)[EventField.deadline], isNull);
    });

    test('hashtag is 3–40 letters or digits without accents', () {
      EventDraft h(String v) => EventDraft(hashtag: v);
      expect(
        createEventErrors(h('PhotoWalk1020'), now: now)[EventField.hashtag],
        isNull,
      );
      for (final bad in ['ab', 'có dấu', 'with space', 'x' * 41, 'a-b-c']) {
        expect(
          createEventErrors(h(bad), now: now)[EventField.hashtag],
          'format',
          reason: bad,
        );
      }
    });
  });

  group('EventForm', () {
    test('composes Việt Nam time into UTC instants', () {
      final f = EventForm(
        day: DateTime.utc(2026, 10, 20),
        startMinute: 6 * 60,
        endMinute: 9 * 60,
      );
      expect(f.startsAt, DateTime.utc(2026, 10, 19, 23));
      expect(f.endsAt, DateTime.utc(2026, 10, 20, 2));
    });

    test('a half-filled schedule is not sent', () {
      final f = EventForm(
        eventId: 'e1',
        day: DateTime.utc(2026, 10, 20),
        startMinute: 6 * 60,
      );
      final d = f.toDraft();
      expect(d.startsAt, isNull);
      expect(d.toCallable()['startAt'], isNull);
      expect(
        d.toCallable().containsKey('startAt'),
        isTrue,
        reason: 'explicit null clears',
      );
    });

    test('the deadline on the event day is the start itself', () {
      final f = EventForm(
        day: DateTime.utc(2026, 10, 20),
        startMinute: 6 * 60,
        endMinute: 9 * 60,
        deadlineDay: DateTime.utc(2026, 10, 20),
      );
      expect(f.registrationDeadline, f.startsAt);
      final earlier = f.copyWith(deadlineDay: DateTime.utc(2026, 10, 19));
      expect(earlier.registrationDeadline, DateTime.utc(2026, 10, 19, 16, 59));
    });

    test('survives JSON', () {
      final f = EventForm(
        eventId: 'e1',
        title: 'Photo walk',
        type: EventType.workshop,
        coverUrl: 'u',
        coverPath: 'p',
        day: DateTime.utc(2026, 10, 20),
        startMinute: 360,
        endMinute: 540,
        capacity: 20,
        priceVnd: 0,
        placeName: 'Hồ',
        meetingPoint: 'Cổng',
        areaId: 'hn-hoan-kiem',
        lat: 21.0,
        lng: 105.8,
        deadlineDay: DateTime.utc(2026, 10, 19),
        hashtag: 'PhotoWalk1020',
      );
      expect(EventForm.fromJson(f.toJson()), f);
    });
  });

  group('CreateEventController', () {
    test('publish saves then publishes and clears the local draft', () async {
      final (c, repo) = await _container();
      final p = createEventControllerProvider(const CreateEventArgs());
      final ctl = c.read(p.notifier);
      ctl.setTitle('Photo walk');
      ctl.setType(EventType.photoWalk);
      ctl.setDay(DateTime.utc(2026, 10, 13));
      ctl.setStart(9 * 60);
      ctl.setEnd(12 * 60);
      ctl.setCapacity(20);
      ctl.setPrice(0);
      ctl.setPlaceText(name: 'Hồ');
      ctl.chooseArea('hn-hoan-kiem', lat: 21, lng: 105);
      // The cover is already saved on the server in this scenario.
      final id = await _publishWithCover(c, repo);
      expect(id, isNotNull);
      expect(repo.published, [id]);
      expect(c.read(eventDraftStoreProvider).load('u1'), isNull);
    });

    test('a day_taken refusal at publish lands under Ngày', () async {
      final (c, repo) = await _container(repo: _PublishRefuses('day_taken'));
      final id = await _publishWithCover(c, repo);
      expect(id, isNull);
      final s = c.read(createEventControllerProvider(const CreateEventArgs()));
      expect(s.serverErrors[EventField.day], 'day_taken');
      expect(s.summary, isTrue);
      expect(s.busy, isFalse);
      // Moving the day clears it.
      c
          .read(createEventControllerProvider(const CreateEventArgs()).notifier)
          .setDay(DateTime.utc(2026, 10, 14));
      expect(
        c
            .read(createEventControllerProvider(const CreateEventArgs()))
            .serverErrors,
        isEmpty,
      );
    });

    test(
      'a network failure at publish is reported, not a field error',
      () async {
        final (c, repo) = await _container(repo: _PublishRefuses('network'));
        final id = await _publishWithCover(c, repo);
        expect(id, isNull);
        final s = c.read(
          createEventControllerProvider(const CreateEventArgs()),
        );
        expect(s.failure, CreateEventFailure.network);
        expect(s.serverErrors, isEmpty);
      },
    );

    test('publish with errors does not call the server', () async {
      final (c, repo) = await _container();
      final ctl = c.read(
        createEventControllerProvider(const CreateEventArgs()).notifier,
      );
      ctl.setTitle('x');
      expect(await ctl.publish(), isNull);
      expect(repo.savedDrafts, isEmpty);
      expect(repo.published, isEmpty);
      final s = c.read(createEventControllerProvider(const CreateEventArgs()));
      expect(s.summary, isTrue);
      expect(s.touched, containsAll(EventField.values));
    });

    test(
      'the local draft wins over the server copy of the same draft',
      () async {
        final local = const EventForm(eventId: 'ev9', title: 'Edited locally');
        final (c, _) = await _container(
          prefs: {EventDraftStore.key('u1'): _json(local)},
        );
        const args = CreateEventArgs(
          resumeId: 'ev9',
          seed: EventDraft(eventId: 'ev9', title: 'On the server'),
        );
        expect(
          c.read(createEventControllerProvider(args)).form.title,
          'Edited locally',
        );
        // Another draft's local copy is ignored.
        const other = CreateEventArgs(
          resumeId: 'ev8',
          seed: EventDraft(eventId: 'ev8', title: 'Eight'),
        );
        expect(
          c.read(createEventControllerProvider(other)).form.title,
          'Eight',
        );
      },
    );
  });
}

String _json(EventForm f) => EventDraftStoreJson.encode(f);

/// Fills a publishable form (cover already uploaded) and publishes.
Future<String?> _publishWithCover(
  ProviderContainer c,
  FakeEventRepository repo,
) async {
  final p = createEventControllerProvider(const CreateEventArgs());
  final ctl = c.read(p.notifier);
  final cover = await repo.uploadCover(
    'x' * 20,
    const PickedImage(path: '/c.jpg', name: 'c.jpg'),
  );
  ctl
    ..setTitle('Photo walk')
    ..setType(EventType.photoWalk)
    ..setDay(DateTime.utc(2026, 10, 13))
    ..setStart(9 * 60)
    ..setEnd(12 * 60)
    ..setCapacity(20)
    ..setPrice(250000)
    ..setPlaceText(name: 'Hồ')
    ..chooseArea('hn-hoan-kiem', lat: 21, lng: 105);
  // The cover is part of the saved form (as after "Tiếp tục").
  c.read(p.notifier);
  final state = c.read(p);
  _forceCover(c, cover, repo.coverPathOf(cover)!, state);
  final r = await ctl.publish();
  return r;
}

void _forceCover(
  ProviderContainer c,
  String url,
  String path,
  CreateEventState s,
) {
  // setTitle etc. rebuilt the form; set the cover through the store the way a
  // resumed draft would carry it.
  final ctl = c.read(
    createEventControllerProvider(const CreateEventArgs()).notifier,
  );
  ctl.debugSetCover(url, path);
}

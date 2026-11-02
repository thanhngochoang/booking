// test/features/event_create/create_event_spot_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/staff_role.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/event_create/create_event_controller.dart';
import 'package:photobooking/features/event_create/create_event_screen.dart';

import '../../support/event_world.dart';
import '../../support/spot_entry_fixture.dart';

const _size = Size(390, 900);
const _args = CreateEventArgs();
const _cover = PickedImage(path: '/tmp/cover.jpg', name: 'cover.jpg');

EventsWorld _world({StaffRole? staff}) {
  final w = EventsWorld(
    role: staff == null ? UserRole.photographer : UserRole.customer,
    onboardingComplete: true,
    staff: staff,
    pickerAnswers: const [
      [_cover],
    ],
  );
  w.spots.seedDirectory([
    spotEntryFixture(
      id: 'cau-dat',
      name: 'Đồi chè Cầu Đất',
      city: 'Đà Lạt',
      lat: 11.85,
      lng: 108.55,
      inSeason: true,
      seasonMonths: const [10, 11, 12],
    ),
    spotEntryFixture(id: 'ho-tay', name: 'Hồ Tây'),
  ]);
  return w;
}

Future<void> _open(
  WidgetTester tester,
  EventsWorld w, {
  String path = '/events/new',
}) => w.pump(tester, path: path, organizer: true, size: _size);

CreateEventController _ctl(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CreateEventScreen)))
        .read(createEventControllerProvider(_args).notifier);

CreateEventState _state(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CreateEventScreen)))
        .read(createEventControllerProvider(_args));

/// Cover, title and type, without the spot.
Future<void> _stepOneWithoutSpot(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-event-cover')));
  await settle(tester);
  await tester.enterText(
    find.byKey(const Key('create-event-title')),
    'Săn sương sớm',
  );
  await tester.scrollUntilVisible(
    find.byKey(const Key('create-event-type-photo_walk')),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(
    find.byKey(const Key('create-event-type-photo_walk')),
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('create-event-type-photo_walk')));
  await settle(tester);
  // S12.01-venue: a public place, committed, terms ticked (own tests).
  _ctl(tester)
    ..setVenueKind(VenueKind.publicPlace)
    ..setCommitment(true)
    ..setTerms(true);
  await settle(tester);
}

Future<void> _pickSpot(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(const Key('spot-field')));
  await tester.tap(find.byKey(const Key('spot-field')));
  await settle(tester);
  await tester.tap(find.byKey(Key(key)));
  await settle(tester);
  await tester.tap(find.byKey(const Key('spot-sheet-pick')));
  await settle(tester);
}

Future<void> _tapNext(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('create-event-next')));
  await settle(tester);
}

const _required = 'Chọn một điểm chụp, hoặc “Không thuộc điểm chụp nào”';

void main() {
  testWidgets('step 1 has the Điểm chụp field under the name', (tester) async {
    final w = _world();
    await _open(tester, w);
    expect(find.text('Điểm chụp · bắt buộc'), findsOneWidget);
    expect(find.text('Chọn điểm chụp'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('spot-field'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('create-event-title'))).dy,
      ),
    );
  });

  testWidgets(
    'Tiếp tục without a decision shows eventSpotRequired and calls nothing',
    (tester) async {
      final w = _world();
      await _open(tester, w);
      await _stepOneWithoutSpot(tester);
      expect(find.text(_required), findsNothing, reason: 'not before Tiếp tục');
      await _tapNext(tester);
      expect(find.text(_required), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(w.repo.savedDrafts, isEmpty);
      expect(w.repo.published, isEmpty);
    },
  );

  testWidgets('publish without a decision lists the spot and calls nothing', (
    tester,
  ) async {
    final w = _world();
    await _open(tester, w);
    await _stepOneWithoutSpot(tester);
    final c = _ctl(tester)
      ..debugSetCover('https://storage.test/c.jpg', 'eventCovers/u1/e/c.jpg')
      ..setDay(DateTime.utc(2026, 10, 13))
      ..setStart(9 * 60)
      ..setEnd(12 * 60)
      ..setCapacity(20)
      ..setPrice(0)
      ..setPlaceText(name: 'Hồ')
      ..chooseArea('hn-hoan-kiem', lat: 21, lng: 105);
    expect(c.fieldErrors.keys, [EventField.spot]);
    expect(await c.publish(), isNull);
    expect(_state(tester).summary, isTrue);
    expect(_state(tester).touched, contains(EventField.spot));
    expect(w.repo.savedDrafts, isEmpty);
    expect(w.repo.published, isEmpty);
  });

  testWidgets('"Không thuộc điểm chụp nào" is saved as spotId null', (
    tester,
  ) async {
    final w = _world();
    await _open(tester, w);
    await _stepOneWithoutSpot(tester);
    await _pickSpot(tester, 'spot-option-none');
    expect(find.text(_required), findsNothing);
    await _tapNext(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    final payload = w.repo.savedDrafts.last.toCallable();
    expect(payload.containsKey('spotId'), isTrue);
    expect(payload['spotId'], isNull);
  });

  testWidgets('a chosen spot is sent and fills an empty place', (tester) async {
    final w = _world();
    await _open(tester, w);
    await _stepOneWithoutSpot(tester);
    await _pickSpot(tester, 'spot-option-cau-dat');
    expect(
      find.descendant(
        of: find.byKey(const Key('spot-field')),
        matching: find.text('Đồi chè Cầu Đất'),
      ),
      findsOneWidget,
    );
    await _tapNext(tester);
    final draft = w.repo.savedDrafts.last;
    expect(draft.toCallable()['spotId'], 'cau-dat');
    expect(_state(tester).form.placeName, 'Đồi chè Cầu Đất');
    expect(_state(tester).form.lat, 11.85);
    // Step 2 shows the place the spot filled in.
    expect(find.text('Đồi chè Cầu Đất'), findsWidgets);
  });

  testWidgets('a place already typed is kept when a spot is chosen', (
    tester,
  ) async {
    final w = _world();
    await _open(tester, w);
    _ctl(tester)
      ..setPlaceText(name: 'Bãi giữ xe')
      ..chooseArea('hn-hoan-kiem', lat: 21, lng: 105);
    await settle(tester);
    await _stepOneWithoutSpot(tester);
    await _pickSpot(tester, 'spot-option-ho-tay');
    expect(_state(tester).form.placeName, 'Bãi giữ xe');
    expect(_state(tester).form.spotId, 'ho-tay');
  });

  testWidgets('switching spot A → B moves the auto-filled place', (
    tester,
  ) async {
    final w = _world();
    await _open(tester, w);
    await _stepOneWithoutSpot(tester);
    await _pickSpot(tester, 'spot-option-cau-dat');
    expect(_state(tester).form.placeName, 'Đồi chè Cầu Đất');
    await _pickSpot(tester, 'spot-option-ho-tay');
    expect(_state(tester).form.spotId, 'ho-tay');
    expect(_state(tester).form.placeName, 'Hồ Tây');
    expect(_state(tester).form.lat, 21.05);
    // "Không thuộc điểm chụp nào" leaves the place alone.
    await _pickSpot(tester, 'spot-option-none');
    expect(_state(tester).form.placeName, 'Hồ Tây');
  });

  testWidgets('a place the organizer typed is kept when the spot changes', (
    tester,
  ) async {
    final w = _world();
    await _open(tester, w);
    await _stepOneWithoutSpot(tester);
    await _pickSpot(tester, 'spot-option-cau-dat');
    _ctl(tester).setPlaceText(name: 'Đồi chè Cầu Đất, cổng phụ');
    await settle(tester);
    await _pickSpot(tester, 'spot-option-ho-tay');
    expect(_state(tester).form.placeName, 'Đồi chè Cầu Đất, cổng phụ');
    expect(_state(tester).form.lat, 11.85);
  });

  testWidgets('editing the place clears a stale "far" error', (tester) async {
    final w = _world();
    await _open(tester, w);
    await _stepOneWithoutSpot(tester);
    await _pickSpot(tester, 'spot-option-ho-tay');
    w.repo
      ..failWith = const EventError('invalid_argument', field: 'spotId')
      ..failOnce = true;
    await _tapNext(tester);
    expect(_state(tester).serverErrors, contains(EventField.spot));
    _ctl(tester).setPlaceText(name: 'Nơi khác');
    expect(_state(tester).serverErrors, isNot(contains(EventField.spot)));
  });

  testWidgets('a draft saved with "none" resumes as decided', (tester) async {
    final w = _world();
    w.repo.putEvent(
      detailOf(
        'ev7',
        status: EventStatus.draft,
        createdBy: 'u1',
        hostId: 'u1',
        spotDecided: true,
      ),
    );
    await _open(tester, w, path: '/events/new?draft=ev7');
    expect(
      find.descendant(
        of: find.byKey(const Key('spot-field')),
        matching: find.text('Không thuộc điểm chụp nào'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('editing shows the saved choice', (tester) async {
    final w = _world();
    w.repo.putEvent(
      detailOf(
        'ev9',
        status: EventStatus.draft,
        createdBy: 'u1',
        hostId: 'u1',
        spotId: 'ho-tay',
      ),
    );
    await _open(tester, w, path: '/events/new?draft=ev9');
    expect(
      find.descendant(
        of: find.byKey(const Key('spot-field')),
        matching: find.text('Hồ Tây'),
      ),
      findsOneWidget,
    );
    expect(find.text(_required), findsNothing);
    // The saved choice can be changed.
    await _pickSpot(tester, 'spot-option-none');
    expect(_state(tester).form.spotId, isNull);
    expect(_state(tester).form.spotDecided, isTrue);
  });

  testWidgets('a draft saved before the choice asks again', (tester) async {
    final w = _world();
    w.repo.putEvent(
      detailOf('ev8', status: EventStatus.draft, createdBy: 'u1', hostId: 'u1'),
    );
    await _open(tester, w, path: '/events/new?draft=ev8');
    expect(find.text('Chọn điểm chụp'), findsOneWidget);
    expect(_state(tester).form.spotDecided, isFalse);
  });

  group('server refusals land under the field', () {
    for (final (code, field, text) in [
      (
        'spot_archived',
        null,
        'Điểm chụp này không còn nhận lịch mới. Chọn điểm khác.',
      ),
      ('not_found', 'spotId', 'Không tìm thấy điểm chụp này. Chọn điểm khác.'),
      (
        'invalid_argument',
        'spotId',
        'Địa điểm nằm ngoài điểm chụp đã chọn. Sửa địa điểm hoặc chọn điểm khác.',
      ),
    ]) {
      testWidgets(code, (tester) async {
        final w = _world();
        await _open(tester, w);
        await _stepOneWithoutSpot(tester);
        await _pickSpot(tester, 'spot-option-ho-tay');
        w.repo
          ..failWith = EventError(code, field: field)
          ..failOnce = true;
        await _tapNext(tester);
        // Refused: still on step 1, the reason under the field.
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.text(text), findsOneWidget);
        // Choosing again clears it.
        await _pickSpot(tester, 'spot-option-none');
        expect(find.text(text), findsNothing);
      });
    }
  });

  testWidgets('fits 320 dp at 1.3× with the error showing', (tester) async {
    final w = _world();
    await w.pump(
      tester,
      path: '/events/new',
      organizer: true,
      size: const Size(320, 640),
      textScale: 1.3,
    );
    await _stepOneWithoutSpot(tester);
    await _tapNext(tester);
    expect(find.text(_required), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

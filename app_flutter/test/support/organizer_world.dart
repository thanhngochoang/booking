// test/support/organizer_world.dart
//
// Hosts the S30 organizer screens (S30.01–S30.04, S30.06, S12.03-entry) on
// the fakes: organizer, spots, events, photographers, the gallery. Screens of
// other tasks and plans (S21.01, S21.04, S06.06, S29.02, S30.07) are stubs
// that print `stub <uri>`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/event_manage/manage_event_screen.dart';
import 'package:photobooking/features/organizer/entry_tickets_edit_screen.dart';
import 'package:photobooking/features/organizer/gate_staff_screen.dart';
import 'package:photobooking/features/organizer/managed_spot_screen.dart';
import 'package:photobooking/features/organizer/organizer_apply_screen.dart';
import 'package:photobooking/features/organizer/spot_claim_screen.dart';

import 'fake_organizer_repository.dart';
import 'fake_spot_repository.dart';
import 'screen_host.dart';

/// 10/11/2026 10:00 in Việt Nam.
final organizerNow = DateTime.utc(2026, 11, 10, 3);
const organizerToday = '2026-11-10';

Spot makeSpot({
  String id = 'bd',
  String name = 'Bãi đá sông Hồng',
  String? managedBy,
  SpotAccess? access,
  OpenHours? openHours = const OpenHours(start: '06:00', end: '22:00'),
  String description = 'Vườn hoa ven sông',
  List<String> tips = const ['Đi sớm'],
}) => Spot(
  id: id,
  name: name,
  city: 'Hà Nội',
  areaCode: 'hn',
  lat: 21.07,
  lng: 105.84,
  radiusM: 500,
  cover: null,
  description: description,
  tips: tips,
  seasonMonths: const [11, 12],
  pinned: false,
  hidden: false,
  archived: false,
  stats: const SpotStats(
    posts14d: 0,
    events: 0,
    bookings14d: 0,
    openSchedules: 0,
    providersWeek: 0,
    providersWeekend: 0,
  ),
  managedBy: managedBy,
  access: access,
  openHours: openHours,
);

SpotEntry makeSpotEntry(Spot s) => SpotEntry(
  spotId: s.id,
  name: s.name,
  city: s.city,
  areaCode: s.areaCode,
  cardUrl: null,
  lat: s.lat,
  lng: s.lng,
  radiusM: s.radiusM,
  seasonMonths: s.seasonMonths,
  inSeason: false,
  pinned: false,
  hidden: false,
  hotScore: 0,
  openSchedules: 0,
  providersWeek: 0,
  providersWeekend: 0,
  upcomingEvents: 0,
);

Organizer makeOrganizer({
  String id = 'org1',
  String name = 'Vườn hoa Bãi đá',
  OrganizerStatus status = OrganizerStatus.active,
  bool businessVerified = true,
  bool payoutAccountOk = true,
  List<String> managedSpotIds = const ['bd'],
}) => Organizer(
  id: id,
  name: name,
  status: status,
  phoneVerified: true,
  businessVerified: businessVerified,
  payoutAccountOk: payoutAccountOk,
  managedSpotIds: managedSpotIds,
  createdAt: organizerNow.subtract(const Duration(days: 30)),
  updatedAt: organizerNow.subtract(const Duration(days: 30)),
);

const adultType = EntryTicketType(id: 't1', name: 'Người lớn', price: 70000);
const childType = EntryTicketType(id: 't2', name: 'Trẻ em', price: 50000);

EntryEvent makeEntryEvent({
  String id = 'ent1',
  String spotId = 'bd',
  String title = 'Vé vào cửa mùa cúc hoạ mi',
  String startDay = '2026-11-01',
  String endDay = '2026-12-31',
  List<EntryTicketType> types = const [adultType, childType],
  int? dailyCapacity = 500,
  List<int> closedWeekdays = const [],
  List<String> closedDays = const [],
}) => EntryEvent(
  id: id,
  title: title,
  spotId: spotId,
  organizerId: 'org1',
  organizerName: 'Vườn hoa Bãi đá',
  status: EventStatus.open,
  startDay: startDay,
  endDay: endDay,
  closedWeekdays: closedWeekdays,
  closedDays: closedDays,
  openHours: const OpenHours(start: '06:00', end: '22:00'),
  ticketTypes: types,
  dailyCapacity: dailyCapacity,
);

/// The `events/{id}` detail of [entry] (S12.03-entry reads it).
EventDetail entryDetailOf(EntryEvent entry) {
  final start = DateTime.utc(2026, 10, 31, 17);
  final end = DateTime.utc(2026, 12, 31, 17);
  final summary = EventSummary(
    id: entry.id,
    title: entry.title,
    hostName: entry.organizerName,
    hostVerified: true,
    hostType: HostType.organizer,
    hostId: entry.organizerId,
    createdBy: entry.organizerId,
    type: EventType.entry,
    startsAt: start,
    hasSchedule: true,
    endsAt: end,
    locationName: 'Bãi đá sông Hồng',
    geohash: 'w7er',
    lat: 21.07,
    lng: 105.84,
    priceVnd: 0,
    capacity: 0,
    registeredCount: 0,
    heldCount: 0,
    status: entry.status,
    createdAt: start.subtract(const Duration(days: 5)),
  );
  return EventDetail(
    summary: summary,
    description: '',
    hashtag: '',
    endsAt: end,
    registrationDeadline: end,
    createdBy: entry.organizerId,
    spotId: entry.spotId,
    entry: entry,
  );
}

/// A paid entry registration for [day] with [lines] `(type, qty)`.
EventRegistration entryRegistration(
  String id, {
  String eventId = 'ent1',
  String day = organizerToday,
  List<(EntryTicketType, int)> lines = const [(adultType, 2)],
  RegistrationStatus status = RegistrationStatus.paid,
}) {
  final items = [
    for (final (t, q) in lines)
      EntryLine(ticketTypeId: t.id, name: t.name, price: t.price, qty: q),
  ];
  final qty = items.fold<int>(0, (s, i) => s + i.qty);
  final amount = items.fold<int>(0, (s, i) => s + i.amount);
  return EventRegistration(
    id: id,
    eventId: eventId,
    userId: 'c-$id',
    userName: 'Khách $id',
    ticketCode: '',
    quantity: qty,
    amount: amount,
    status: status,
    event: EventTicketSnapshot(
      title: 'Vé vào cửa',
      type: EventType.entry,
      startsAt: DateTime.utc(2026, 11, 9, 23),
      endsAt: DateTime.utc(2026, 11, 10, 15),
    ),
    createdAt: organizerNow.subtract(const Duration(days: 1)),
    visitDay: day,
    items: items,
  );
}

PhotographerSummary makeProvider(
  String id,
  String name, {
  bool accepting = true,
}) => PhotographerSummary(
  id: id,
  displayName: name,
  verified: true,
  acceptingOrders: accepting,
);

class OrganizerWorld {
  OrganizerWorld({this.uid = 'org1', DateTime? now})
    : now = now ?? organizerNow,
      organizers = FakeOrganizerRepository(
        uid: uid,
        clock: () => now ?? organizerNow,
      ),
      events = FakeEventRepository(uid: uid, clock: () => now ?? organizerNow);

  final String uid;
  final DateTime now;
  final FakeOrganizerRepository organizers;
  final FakeEventRepository events;
  final spots = FakeSpotRepository();
  final photographers = FakePhotographerRepository();

  /// The signed-in user's private contact (S30.01 reads `phoneVerified`).
  UserContact? contact = const UserContact(
    phone: '+84912345678',
    phoneVerified: true,
  );

  /// Gallery answers, in order.
  FakeImagePicker picker = FakeImagePicker();

  /// Public names of other users (gate staff rows).
  final Map<String, String> names = {};

  late GoRouter router;

  String get location => router.state.uri.toString();

  void seedSpot(Spot s) {
    spots.seedSpot(s);
    spots.seedDirectory([
      ...spots.directoryEntries.where((e) => e.spotId != s.id),
      makeSpotEntry(s),
    ]);
  }

  List<Override> get overrides => [
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    clockProvider.overrideWithValue(() => now),
    organizerRepositoryProvider.overrideWithValue(organizers),
    spotRepositoryProvider.overrideWithValue(spots),
    eventRepositoryProvider.overrideWithValue(events),
    photographerRepositoryProvider.overrideWithValue(photographers),
    imagePickerProvider.overrideWithValue(picker),
    currentContactProvider.overrideWithValue(AsyncData(contact)),
    partyProfileProvider.overrideWith(
      (ref, id) => Stream.value(
        UserProfile(
          uid: id,
          role: UserRole.customer,
          displayName: names[id] ?? id,
        ),
      ),
    ),
  ];

  Widget app({
    required String location,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/organizer/apply',
          builder: (_, _) => const OrganizerApplyScreen(),
        ),
        GoRoute(
          path: '/organizer/spots/claim',
          builder: (_, _) => const SpotClaimScreen(),
        ),
        GoRoute(
          path: '/organizer/spots/:spotId',
          builder: (_, s) =>
              ManagedSpotScreen(spotId: s.pathParameters['spotId']!),
        ),
        GoRoute(
          path: '/organizer/entry/new',
          builder: (_, s) =>
              EntryTicketsEditScreen(spotId: s.uri.queryParameters['spot']),
        ),
        GoRoute(
          path: '/organizer/entry/:eventId/edit',
          builder: (_, s) =>
              EntryTicketsEditScreen(eventId: s.pathParameters['eventId']),
        ),
        GoRoute(
          path: '/organizer/gate-staff',
          builder: (_, _) => const GateStaffScreen(),
        ),
        GoRoute(
          path: '/events/:eventId/manage',
          builder: (_, s) =>
              ManageEventScreen(eventId: s.pathParameters['eventId']!),
        ),
        for (final p in [
          '/verify/phone',
          '/verify/business',
          '/organizer/payout-account',
          '/scan',
          '/spots/:spotId',
          '/e/:eventId',
          '/u/:uid',
        ])
          GoRoute(path: p, builder: stub),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required String location,
    double width = 390,
    double height = 900,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(location: location, brightness: brightness, textScale: textScale),
    );
    await settleOrganizer(tester);
  }
}

/// Bounded pumps: fake streams emit at once, loaders animate forever.
Future<void> settleOrganizer(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Scrolls [f] into view, taps it and settles.
Future<void> tapOrganizer(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    // Not built yet: further down a lazy list.
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settleOrganizer(tester);
}

/// The confirm button labelled [label] is the red (danger) one, never the
/// gradient (Global constraints §10).
void expectRedButton(WidgetTester tester, String label) {
  final button = tester.widget<FilledButton>(
    find.descendant(
      of: find.widgetWithText(AppButton, label),
      matching: find.byType(FilledButton),
    ),
  );
  expect(
    button.style?.backgroundColor?.resolve(const {}),
    anyOf(AppColors.error, AppColorsDark.error),
  );
}

/// The organizer fake got exactly one call, [call] (name and payload).
void expectOnlyCall(OrganizerWorld w, (String, Map<String, Object?>) call) {
  final c = w.organizers.calls.single;
  expect(c.$1, call.$1);
  expect(c.$2, call.$2);
}

// test/support/entry_world.dart
//
// Hosts S30.05 (`/spots/:spotId/tickets`) and S04.04 for a ticket on fakes:
// the spot with its entry event (organizer_world fixtures), the day
// counters, the event repository's `registerEntry`. Other screens are stubs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/entry/entry_buy_screen.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/payment/payment_screen.dart';

import 'fake_organizer_repository.dart';
import 'fake_spot_repository.dart';
import 'organizer_world.dart';
import 'screen_host.dart';

class EntryWorld {
  EntryWorld({this.uid = 'c1', DateTime? now})
    : now = now ?? organizerNow,
      organizers = FakeOrganizerRepository(
        uid: uid,
        clock: () => now ?? organizerNow,
      ),
      events = FakeEventRepository(
        uid: uid,
        clock: () => now ?? organizerNow,
        events: [entryDetailOf(makeEntryEvent())],
      ) {
    spots
      ..seedSpot(makeSpot(managedBy: 'org1'))
      ..seedEntryEvent('bd', makeEntryEvent());
  }

  final String uid;
  final DateTime now;
  final FakeOrganizerRepository organizers;
  final FakeEventRepository events;
  final spots = FakeSpotRepository();

  /// The signed-in user's contact; null = no phone yet (S04.05).
  UserContact? contact = const UserContact(phone: '+84912345678');

  /// When set, the contact arrives this late (a slow first read).
  Duration? contactDelay;

  late GoRouter router;

  String get location => router.state.uri.toString();

  List<Override> get overrides => [
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    currentProfileProvider.overrideWith(
      (ref) => Stream.value(
        UserProfile(uid: uid, role: UserRole.customer, displayName: 'Lan Anh'),
      ),
    ),
    clockProvider.overrideWithValue(() => now),
    organizerRepositoryProvider.overrideWithValue(organizers),
    spotRepositoryProvider.overrideWithValue(spots),
    eventRepositoryProvider.overrideWithValue(events),
    if (contactDelay case final d?)
      currentContactProvider.overrideWith((ref) async* {
        await Future<void>.delayed(d);
        yield contact;
      })
    else
      currentContactProvider.overrideWithValue(AsyncData(contact)),
  ];

  Future<void> pump(
    WidgetTester tester, {
    String location = '/spots/bd/tickets',
    double width = 390,
    double height = 1000,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/spots/:spotId/tickets',
          builder: (_, s) =>
              EntryBuyScreen(spotId: s.pathParameters['spotId']!),
        ),
        GoRoute(
          path: '/e/:eventId/pay/:regId',
          builder: (_, s) => PaymentScreen(
            subject: TicketPay(
              s.pathParameters['eventId']!,
              s.pathParameters['regId']!,
            ),
            initial: s.extra as PaymentInstructions?,
          ),
        ),
        for (final p in ['/profile/phone', '/bookings', '/spots/:spotId'])
          GoRoute(path: p, builder: stub),
      ],
    );
    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: overrides,
        brightness: brightness,
        textScale: textScale,
      ),
    );
    await settleOrganizer(tester);
  }
}

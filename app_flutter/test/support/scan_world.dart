// test/support/scan_world.dart
//
// Hosts S30.07 (`/scan`) on fakes: a camera-less scanner, a scripted
// `scanPass`, the organizer/gate rows, spots and bookings. Haptics are
// recorded from the platform channel.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncData;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/organizer/organizer_providers.dart';
import 'package:photobooking/data/passes/pass_providers.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/features/scan/scan_screen.dart';

import 'fake_booking_repository.dart';
import 'fake_organizer_repository.dart';
import 'fake_pass_repository.dart';
import 'fake_pass_scanner.dart';
import 'fake_spot_repository.dart';
import 'organizer_world.dart' show organizerNow;
import 'screen_host.dart';

class ScanWorld {
  ScanWorld({this.uid = 'org1', DateTime? now})
    : now = now ?? organizerNow,
      organizers = FakeOrganizerRepository(
        uid: uid,
        clock: () => now ?? organizerNow,
      ),
      bookings = FakeBookingRepository(
        customerId: 'c1',
        clock: () => now ?? organizerNow,
      );

  final String uid;
  final DateTime now;
  final FakeOrganizerRepository organizers;
  final FakeBookingRepository bookings;
  final spots = FakeSpotRepository();
  final passes = FakePassRepository();
  final scanner = FakePassScanner();

  /// `HapticFeedback` calls: `light` (short) or `vibrate` (long).
  final List<String> haptics = [];

  late GoRouter router;

  String get location => router.state.uri.toString();

  List<Override> get overrides => [
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    clockProvider.overrideWithValue(() => now),
    organizerRepositoryProvider.overrideWithValue(organizers),
    spotRepositoryProvider.overrideWithValue(spots),
    bookingRepositoryProvider.overrideWithValue(bookings),
    passRepositoryProvider.overrideWithValue(passes),
    passScannerFactoryProvider.overrideWithValue(() => scanner),
    currentContactProvider.overrideWithValue(
      const AsyncData(UserContact(phone: '+84912345678', phoneVerified: true)),
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    String location = '/scan',
    double width = 390,
    double height = 844,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(
            call.arguments == 'HapticFeedbackType.lightImpact'
                ? 'light'
                : call.arguments == null
                ? 'vibrate'
                : '${call.arguments}',
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/', builder: stub),
        GoRoute(
          path: '/scan',
          builder: (_, s) => ScanScreen(
            bookingId: s.uri.queryParameters['booking'],
            eventId: s.uri.queryParameters['event'],
          ),
        ),
        GoRoute(path: '/b/:id', builder: stub),
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
    await settleScan(tester);
  }
}

/// Bounded pumps (a loader animates forever while a scan is on its way).
Future<void> settleScan(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// Test world for the customer side of Chụp ngay (S13.01, the S02.01 and
// S02.06 entries): [InstantWorld]'s fakes plus the customer's profile and
// contact, and a router with stub pages for where the screens go.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/instant/instant_request_screen.dart';

import 'fake_instant_repository.dart';
import 'instant_work_world.dart';
import 'screen_host.dart';

export 'instant_work_world.dart'
    show instantNow, settleInstant, taoDan, taoDanNorth;

const customerPhone = UserContact(phone: '+84903123456');

class InstantCustomerWorld {
  InstantCustomerWorld({
    FakeInstantRepository? repo,
    FakeLocationRepository? location,
    this.contact = customerPhone,
    DateTime? now,
    bool flag = true,
    this.role = UserRole.customer,
  }) : base = InstantWorld(
         repo: repo,
         location: location,
         clock: InstantClock(now),
         enabled: flag,
       );

  final InstantWorld base;
  final UserRole role;

  FakeInstantRepository get repo => base.repo;
  FakeLocationRepository get location => base.location;

  /// The customer's saved number; null = none yet.
  UserContact? contact;
  final _contactChanges = StreamController<UserContact?>.broadcast();

  /// The customer saves a number (S04.05).
  void setContact(UserContact? c) {
    contact = c;
    _contactChanges.add(c);
  }

  Stream<UserContact?> _watchContact() async* {
    yield contact;
    yield* _contactChanges.stream;
  }

  List<Override> get overrides => [
    ...base.overrides,
    currentContactProvider.overrideWith((ref) => _watchContact()),
    currentProfileProvider.overrideWith(
      (ref) => Stream.value(
        UserProfile(uid: 'cus1', role: role, displayName: 'Lan Anh'),
      ),
    ),
  ];
}

Widget _stub(BuildContext _, GoRouterState s) =>
    Scaffold(body: Text('stub ${s.uri}'));

/// `/home`, `/action`, `/instant` (S13.01), `/instant/:id` (stub until Task 3),
/// `/profile/phone` (a stub whose "save-phone" saves a number and goes to
/// `returnTo`, like S04.05).
GoRouter instantCustomerRouter(
  InstantCustomerWorld world, {
  String initial = '/home',
  Widget? home,
  Widget? action,
}) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/home',
      builder: home == null ? _stub : (_, _) => Scaffold(body: home),
    ),
    GoRoute(
      path: '/action',
      builder: action == null ? _stub : (_, _) => Scaffold(body: action),
    ),
    GoRoute(path: '/instant', builder: (_, _) => const InstantRequestScreen()),
    GoRoute(path: '/instant/:id', builder: _stub),
    GoRoute(
      path: '/profile/phone',
      builder: (context, s) => Scaffold(
        body: Column(
          children: [
            Text('stub ${s.uri}'),
            TextButton(
              key: const Key('save-phone'),
              onPressed: () {
                world.setContact(customerPhone);
                context.go(s.uri.queryParameters['returnTo']!);
              },
              child: const Text('save'),
            ),
          ],
        ),
      ),
    ),
  ],
);

/// Pumps [router] on a phone of [viewSize]; [push] is pushed over the
/// initial page (so back pops to it).
Future<GoRouter> pumpInstantCustomer(
  WidgetTester tester,
  InstantCustomerWorld world, {
  GoRouter? router,
  String? push = '/instant',
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final r = router ?? instantCustomerRouter(world);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    screenRouterApp(
      router: r,
      overrides: world.overrides,
      brightness: brightness,
      textScale: textScale,
    ),
  );
  if (push != null) r.push(push);
  await settleInstant(tester);
  return r;
}

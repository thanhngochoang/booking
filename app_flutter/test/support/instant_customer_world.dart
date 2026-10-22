// Test world for the customer side of Chụp ngay (S13.01–S13.08, the S02.01
// and S02.06 entries): [InstantWorld]'s fakes plus the customer's profile and
// contact, request fixtures (mock values), and a router with stub pages for
// where the screens go.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/instant/instant_flow_screen.dart';
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
    List<Override> extra = const [],
  }) : base = InstantWorld(
         repo: repo,
         location: location,
         clock: InstantClock(now),
         enabled: flag,
         extra: extra,
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

  /// The signed-in account; null = signed out.
  String? uid = 'cus1';
  final _authChanges = StreamController<AuthUser?>.broadcast();

  /// Another account signs in (or [id] null: signs out).
  void signInAs(String? id) {
    uid = id;
    _authChanges.add(id == null ? null : AuthUser(uid: id));
  }

  Stream<AuthUser?> _watchAuth() async* {
    final id = uid;
    yield id == null ? null : AuthUser(uid: id);
    yield* _authChanges.stream;
  }

  Stream<UserContact?> _watchContact() async* {
    yield contact;
    yield* _contactChanges.stream;
  }

  List<Override> get overrides => [
    ...base.overrides,
    authStateProvider.overrideWith((ref) => _watchAuth()),
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

/// `/home`, `/action`, `/instant` (S13.01), `/instant/:id` (the request's
/// status switch), `/profile/phone` (a stub whose "save-phone" saves a number and goes to
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
    GoRoute(
      path: '/instant/:id',
      builder: (_, s) => InstantFlowScreen(requestId: s.pathParameters['id']!),
    ),
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
  bool disableAnimations = false,
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
      disableAnimations: disableAnimations,
    ),
  );
  if (push != null) r.push(push);
  await settleInstant(tester);
  return r;
}

/// The five suggestions of a round (mock `#S13.02`): Minh Trí first; Thu Hà
/// has 3 reviews ("Mới · 3 đánh giá").
const instantCandidates = [
  InstantCandidate(
    photographerId: 'p1',
    name: 'Minh Trí',
    verified: true,
    tomatoPct: 97,
    reviewCount: 58,
    completedCount: 112,
    distanceKm: 1.2,
    etaMinutes: 9,
    photos: ['https://img/p1a', 'https://img/p1b', 'https://img/p1c'],
    reasons: ['Chuyên chân dung', 'Cách 1,2 km'],
  ),
  InstantCandidate(
    photographerId: 'p2',
    name: 'Hồng Nhung',
    verified: true,
    tomatoPct: 91,
    reviewCount: 40,
    completedCount: 80,
    distanceKm: 2.4,
    etaMinutes: 14,
    photos: ['https://img/p2a'],
    reasons: ['Hợp kiểu Chân dung'],
  ),
  InstantCandidate(
    photographerId: 'p3',
    name: 'Quốc Bảo',
    tomatoPct: 95,
    reviewCount: 22,
    completedCount: 41,
    distanceKm: 1.8,
    etaMinutes: 11,
    reasons: ['Cách 1,8 km'],
  ),
  InstantCandidate(
    photographerId: 'p4',
    name: 'Thu Hà',
    tomatoPct: 100,
    reviewCount: 3,
    completedCount: 4,
    distanceKm: 2.0,
    etaMinutes: 12,
  ),
  InstantCandidate(
    photographerId: 'p5',
    name: 'Gia Huy',
    tomatoPct: 89,
    reviewCount: 30,
    completedCount: 52,
    distanceKm: 3.1,
    etaMinutes: 16,
  ),
];

/// The customer's request `req1` (mock: Chân dung · 1 giờ · 690.000₫ at
/// Tao Đàn), in [status] with the round's [candidates].
InstantRequest customerRequestOf({
  String id = 'req1',
  InstantStatus status = InstantStatus.choosing,
  List<InstantCandidate> candidates = instantCandidates,
  bool committed = false,
  bool roundEnded = false,
  int round = 1,
  int amountVnd = 690000,
}) => InstantRequest(
  id: id,
  customerId: 'cus1',
  customerName: 'Lan Anh',
  status: status,
  packageCode: 'p60',
  durationMin: 60,
  photos: 30,
  genre: InstantGenre.portrait,
  meetPoint: InstantMeetPoint(
    lat: taoDan.lat,
    lng: taoDan.lng,
    name: 'Cổng Trương Định',
  ),
  areaLabel: 'Phường Bến Thành, Quận 1',
  amountVnd: amountVnd,
  earningVnd: amountVnd,
  committed: committed,
  round: round,
  candidates: candidates,
  roundEnded: roundEnded,
);

/// Pumps `/instant/[id]` with [request] already in the fake listener.
Future<GoRouter> pumpInstantFlow(
  WidgetTester tester,
  InstantCustomerWorld world, {
  InstantRequest? request,
  String id = 'req1',
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
  Brightness brightness = Brightness.dark,
  bool disableAnimations = true,
}) {
  world.repo.emitRequest(id, request ?? customerRequestOf(id: id));
  return pumpInstantCustomer(
    tester,
    world,
    push: '/instant/$id',
    textScale: textScale,
    viewSize: viewSize,
    brightness: brightness,
    disableAnimations: disableAnimations,
  );
}

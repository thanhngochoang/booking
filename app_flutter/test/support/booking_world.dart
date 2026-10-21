// test/support/booking_world.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/addons/addon_providers.dart';
import 'package:photobooking/data/addons/service_addon.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'fake_payments_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/booking/booking_detail_screen.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/booking_sheet_page.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/payment/payment_screen.dart';
import 'package:photobooking/features/chat/chat_list_screen.dart';
import 'package:photobooking/features/chat/chat_screen.dart';
import 'package:photobooking/features/chat/inquiry_entry.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import 'fake_addon_repository.dart';
import 'fake_push.dart';

import 'content_fixtures.dart';
import 'fake_booking_repository.dart';
import 'fake_chat_repository.dart';
import 'fake_review_repository.dart';
import 'screen_host.dart';

final worldBookingToday = DateTime.utc(2026, 10, 3, 10, 0);

const bookingPackage1 = ServiceSummary(
  id: 's1',
  photographerId: 'p1',
  name: 'Gói Chân Dung',
  priceVnd: 1500000,
  durationMinutes: 120,
  photoCount: 50,
  editedCount: 10,
  deliveryDays: 3,
  active: true,
);

const bookingPackage2 = ServiceSummary(
  id: 's2',
  photographerId: 'p1',
  name: 'Gói Ngoại Cảnh',
  priceVnd: 2500000,
  durationMinutes: 240,
  photoCount: 100,
  editedCount: 20,
  deliveryDays: 5,
  active: true,
);

const bookingProfileSummary = PhotographerSummary(
  id: 'p1',
  displayName: 'Minh Trí',
  avatarUrl: 'https://images.unsplash.com/avatar1.jpg',
  reviewCount: 25,
  tomatoCount: 24,
  brickCount: 1,
  tomatoPct: 96,
  score: 0.92,
  areaLabel: 'Quận 3',
  startingPriceVnd: 1500000,
  acceptingOrders: true,
);

const bookingProfile = PhotographerProfile(
  summary: bookingProfileSummary,
  intro: PhotographerIntro(
    bio: 'Chuyên chân dung ngoại cảnh.',
    onboardingComplete: true,
  ),
);

/// The mock's package for the add-on frames (`#S04.01-addons`, `#S04.03-addons`).
const bookingPortrait2h = ServiceSummary(
  id: 's1',
  photographerId: 'p1',
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  photoCount: 40,
  active: true,
);

/// An active add-on of photographer `p1`.
ServiceAddon bookingAddon(
  String id, {
  required AddonKind kind,
  required String name,
  String? description,
  required AddonUnit unit,
  required int price,
  int maxQty = 1,
  List<String> serviceIds = const [],
}) => ServiceAddon(
  id: id,
  providerId: 'p1',
  kind: kind,
  name: name,
  description: description,
  price: price,
  unit: unit,
  maxQty: maxQty,
  serviceIds: serviceIds,
  active: true,
  createdAt: DateTime.utc(2026, 10),
  updatedAt: DateTime.utc(2026, 10),
);

/// Mock `#S04.01-addons`: makeup per person (≤ 4), retouch per photo (≤ 10),
/// and a car that only applies to package `s1`.
final addonMakeup = bookingAddon(
  'a_makeup',
  kind: AddonKind.makeup,
  name: 'Trang điểm',
  description: 'Trang điểm tự nhiên, làm tóc cơ bản',
  unit: AddonUnit.perPerson,
  price: 800000,
  maxQty: 4,
);
final addonRetouch = bookingAddon(
  'a_retouch',
  kind: AddonKind.retouch,
  name: 'Chỉnh thêm ảnh',
  description: 'Hậu kỳ thêm ngoài 40 ảnh của gói',
  unit: AddonUnit.perItem,
  price: 20000,
  maxQty: 10,
);
final addonTransport = bookingAddon(
  'a_car',
  kind: AddonKind.transport,
  name: 'Xe đón trong nội thành',
  description: 'Đón đi và đưa về, xe 4 chỗ',
  unit: AddonUnit.perBooking,
  price: 300000,
  serviceIds: ['s1'],
);

class BookingWorldHandles {
  const BookingWorldHandles({
    required this.router,
    required this.bookings,
    required this.availRepo,
    required this.contactRepo,
    required this.externalLauncher,
    required this.addonRepo,
    this.reviewRepo,
  });

  final GoRouter router;
  final FakeAddonRepository addonRepo;
  final FakeBookingRepository bookings;
  final FakeAvailabilityRepository availRepo;
  final FakeUserContactRepository contactRepo;
  final FakeExternalLauncher externalLauncher;
  final FakeReviewRepository? reviewRepo;

  String get location => router.state.uri.toString();
}

Future<BookingWorldHandles> pumpBookingRoute(
  WidgetTester tester, {
  String path = '/u/p1/book',
  FakeBookingRepository? bookings,
  FakeReviewRepository? reviews,
  List<ServiceSummary>? packages,
  Map<DateTime, AvailabilityDay> days = const {},
  UserContact? contact = const UserContact(phone: '+84903123456'),
  DateTime? now,

  /// A clock the test moves by hand; read on every call, so it wins over
  /// [now] for [clockProvider] (the countdown on S04.04 follows it).
  TestClock? clock,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  bool failPackages = false,
  bool emptyPackages = false,
  bool failProfile = false,
  bool realPayments = false,
  bool disableAnimations = false,
  Size viewSize = const Size(390, 844),

  /// Height of the on-screen keyboard (bottom view inset), in dp.
  double keyboardInset = 0,
  List<Override> extraOverrides = const [],

  /// Signs in as this uid instead of the registered fake user (S05.02 shows
  /// a booking only to its two parties; the world's customer is `c1`).
  String? signedInUid,

  /// Active add-ons of `p1` (S04.01); none by default.
  List<ServiceAddon> addons = const [],
}) async {
  final effectiveNow = now ?? worldBookingToday;
  final effectiveBookings = bookings ?? FakeBookingRepository();
  final effectivePackages = failPackages
      ? null
      : (emptyPackages
            ? <ServiceSummary>[]
            : (packages ?? [bookingPackage1, bookingPackage2]));
  final availRepo = FakeAvailabilityRepository();
  for (final d in days.values) {
    availRepo.seed('p1', d);
  }
  final contactRepo = FakeUserContactRepository();
  if (contact != null) {
    await contactRepo.save(
      'c1',
      phone: contact.phone,
      allowZalo: true,
      allowWhatsApp: false,
    );
  }
  final externalLauncher = FakeExternalLauncher();
  final paymentsRepo = FakePaymentsRepository();
  paymentsRepo.onConfirm = (paymentId, kind) async {
    await effectiveBookings.confirmFakePayment(
      paymentId: paymentId,
      kind: kind,
    );
  };
  final addonRepo = FakeAddonRepository();
  for (final a in addons) {
    addonRepo.seed(a);
  }

  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final authRepo = FakeAuthRepository();
  final user = await authRepo.registerWithEmail(
    'c1@test.vn',
    'pass1234',
    'Khách hàng',
  );
  final userRepo = FakeUserRepository();
  await userRepo.ensureProfile(user);

  Widget stub(BuildContext _, GoRouterState s) => Text('stub ${s.uri}');

  final router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/u/:uid/book',
        pageBuilder: (_, state) => BookingSheetPage(
          args: BookingFlowArgs(
            photographerId: state.pathParameters['uid']!,
            serviceId: state.uri.queryParameters['serviceId'],
            day:
                state.uri.queryParameters['day'] ??
                state.uri.queryParameters['date'],
            area: state.uri.queryParameters['area'],
          ),
        ),
      ),
      GoRoute(
        path: '/u/:uid/ask',
        builder: (_, state) => InquiryEntry(
          photographerId: state.pathParameters['uid']!,
          serviceId: state.uri.queryParameters['serviceId'],
        ),
      ),
      GoRoute(
        path: '/u/:uid',
        builder: (_, s) => PhotographerProfileScreen(
          uid: s.pathParameters['uid']!,
          initialSection: profileSectionFromQuery(s.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(
        path: '/action', // S02.06; its providers come from extraOverrides
        builder: (_, s) => FindPhotographerScreen(
          initialSpecialty: s.uri.queryParameters['specialty'],
          initialArea: s.uri.queryParameters['area'],
        ),
      ),
      GoRoute(
        path: '/b/:id/pay',
        builder: (_, s) => PaymentScreen(
          subject: BookingPay(s.pathParameters['id']!),
          initial: s.extra as PaymentInstructions?,
        ),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, s) => ChatScreen(
          chatId: s.pathParameters['chatId']!,
          serviceId: s.uri.queryParameters['serviceId'],
          initialReschedule: s.uri.queryParameters['reschedule'] == '1',
        ),
      ),
      GoRoute(path: '/chats', builder: (_, _) => const ChatListScreen()),
      ...bookingDetailRoutes(),
      for (final p in ['/home', '/profile/phone', '/bookings'])
        GoRoute(path: p, builder: stub),
    ],
  );

  final hasCustomPackages = extraOverrides.any((o) {
    try {
      final origin = (o as dynamic).origin;
      return origin == profilePackagesProvider('p1') ||
          origin?.toString() == profilePackagesProvider('p1').toString();
    } catch (_) {
      return false;
    }
  });
  final hasCustomProfile = extraOverrides.any((o) {
    try {
      final origin = (o as dynamic).origin;
      return origin == photographerProfileProvider('p1') ||
          origin?.toString() == photographerProfileProvider('p1').toString();
    } catch (_) {
      return false;
    }
  });
  final hasCustomChat = extraOverrides.any((o) {
    try {
      final origin = (o as dynamic).origin;
      return origin == chatRepositoryProvider ||
          origin?.toString() == chatRepositoryProvider.toString();
    } catch (_) {
      return false;
    }
  });

  final effectiveReviews =
      reviews ?? FakeReviewRepository(currentUserId: signedInUid ?? 'c1');
  effectiveReviews.bookingRepository ??= effectiveBookings;
  effectiveReviews.bookingPhotographerIds['b1'] ??= 'p1';

  final hasCustomReview = extraOverrides.any((o) {
    try {
      final origin = (o as dynamic).origin;
      return origin == reviewRepositoryProvider ||
          origin?.toString() == reviewRepositoryProvider.toString();
    } catch (_) {
      return false;
    }
  });

  final overrides = <Override>[
    authRepositoryProvider.overrideWithValue(authRepo),
    if (signedInUid != null)
      authStateProvider.overrideWith(
        (ref) => Stream.value(AuthUser(uid: signedInUid)),
      ),
    userRepositoryProvider.overrideWithValue(userRepo),
    clockProvider.overrideWithValue(() => clock?.now ?? effectiveNow),
    calendarTodayProvider.overrideWithValue(effectiveNow),
    bookingRepositoryProvider.overrideWithValue(effectiveBookings),
    availabilityRepositoryProvider.overrideWithValue(availRepo),
    userContactRepositoryProvider.overrideWithValue(contactRepo),
    if (!hasCustomChat)
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    if (!hasCustomReview)
      reviewRepositoryProvider.overrideWithValue(effectiveReviews),
    currentContactProvider.overrideWithValue(
      contact != null ? AsyncData(contact) : const AsyncData(null),
    ),
    if (failPackages)
      profilePackagesProvider('p1').overrideWith(
        (ref) => Future.error(Exception('Failed to load packages')),
      )
    else if (!hasCustomPackages)
      profilePackagesProvider('p1')
          .overrideWithValue(AsyncData(effectivePackages!)),
    if (failProfile)
      photographerProfileProvider(
        'p1',
      ).overrideWith((ref) => Future.error(Exception('Failed to load profile')))
    else if (!hasCustomProfile)
      photographerProfileProvider('p1')
          .overrideWithValue(const AsyncData(bookingProfile)),
    externalLauncherProvider.overrideWithValue(externalLauncher),
    contactLinkRepositoryProvider.overrideWithValue(
      FakeContactLinkRepository(),
    ),
    photographerContactRepositoryProvider.overrideWithValue(
      FakePhotographerContactRepository(),
    ),
    skillsRepositoryProvider.overrideWithValue(FakeSkillsRepository()),
    publicProfileRepositoryProvider.overrideWithValue(
      FakePublicProfileRepository([bookingProfile]),
    ),
    photographerPoolCacheProvider.overrideWithValue(FakePhotographerRepository()),
    realPaymentsProvider.overrideWithValue(realPayments),
    paymentsRepositoryProvider.overrideWithValue(paymentsRepo),
    addonRepositoryProvider.overrideWithValue(addonRepo),
    ...extraOverrides,
  ];

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
        size: viewSize,
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
      ),
      child: screenRouterApp(
        router: router,
        overrides: overrides,
        brightness: brightness,
        textScale: textScale,
      ),
    ),
  );
  await tester.pump();

  return BookingWorldHandles(
    router: router,
    bookings: effectiveBookings,
    availRepo: availRepo,
    contactRepo: contactRepo,
    externalLauncher: externalLauncher,
    addonRepo: addonRepo,
    reviewRepo: effectiveReviews,
  );
}

/// A clock tests move by hand; [clockProvider] reads [now] on every call.
class TestClock {
  TestClock(this.now);
  DateTime now;
  void advance(Duration d) => now = now.add(d);
}

typedef TransitionCall = ({String bookingId, String action, String? reason});

/// [FakeBookingRepository] that records `transitionBooking` calls and can
/// hold them in flight with [gate].
class RecordingBookingRepository extends FakeBookingRepository {
  RecordingBookingRepository({super.customerId, super.clock});

  final transitions = <TransitionCall>[];

  /// When set, every transition waits for it before answering.
  Completer<void>? gate;

  @override
  Future<Booking> transitionBooking({
    required String bookingId,
    required String action,
    String? reason,
  }) async {
    transitions.add((bookingId: bookingId, action: action, reason: reason));
    final g = gate;
    if (g != null) await g.future;
    return super.transitionBooking(
      bookingId: bookingId,
      action: action,
      reason: reason,
    );
  }
}

class BookingDetailHandles {
  const BookingDetailHandles({
    required this.router,
    required this.bookings,
    required this.launcher,
    required this.links,
    required this.clock,
  });

  final GoRouter router;
  final RecordingBookingRepository bookings;
  final FakeExternalLauncher launcher;
  final FakeContactLinkRepository links;
  final TestClock clock;

  /// Location of the top-most route, pushed ones included.
  String get location => router.state.uri.toString();
}

/// Customer of the detail world (the booking fixtures use `c1`/`p1`).
const detailCustomerUid = 'c1';
const detailPhotographerUid = 'p1';

/// Hosts S05.02 (and its sheets) signed in as [uid], with stub routes for
/// every place it can lead to.
Future<BookingDetailHandles> pumpBookingDetail(
  WidgetTester tester, {
  required String uid,
  required RecordingBookingRepository bookings,
  String path = '/b/b1',
  DateTime? now,
  TestClock? clock,
  BookingFeatures features = const BookingFeatures(
    chat: false,
    reschedule: false,
    review: false,
  ),
  ContactChannels photographerChannels = const ContactChannels(
    call: true,
    zalo: true,
  ),
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
  List<Override> extraOverrides = const [],

  /// More public profiles by uid (a studio and its member); each also gets
  /// [photographerChannels].
  Map<String, PhotographerProfile> profiles = const {},
}) async {
  final effectiveClock = clock ?? TestClock(now ?? worldBookingToday);
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final launcher = FakeExternalLauncher();
  final links = FakeContactLinkRepository();
  final photographerContacts = FakePhotographerContactRepository()
    ..seed('p1', channels: photographerChannels);
  for (final uid in profiles.keys) {
    photographerContacts.seed(uid, channels: photographerChannels);
  }
  final userRepo = FakeUserRepository();
  await userRepo.ensureProfile(
    const AuthUser(uid: 'c1', displayName: 'Lan Anh'),
  );

  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));

  final router = GoRouter(
    initialLocation: path,
    routes: [
      ...bookingDetailRoutes(),
      for (final p in [
        '/home',
        '/bookings',
        '/u/:uid/book',
        '/u/:uid',
        '/chat/:id',
        '/b/:id/review',
      ])
        GoRoute(path: p, builder: stub),
    ],
  );

  final hasCustomChat = extraOverrides.any((o) {
    try {
      final origin = (o as dynamic).origin;
      return origin == chatRepositoryProvider ||
          origin?.toString() == chatRepositoryProvider.toString();
    } catch (_) {
      return false;
    }
  });

  final overrides = <Override>[
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    userRepositoryProvider.overrideWithValue(userRepo),
    clockProvider.overrideWithValue(() => effectiveClock.now),
    calendarTodayProvider.overrideWithValue(effectiveClock.now),
    bookingRepositoryProvider.overrideWithValue(bookings),
    bookingFeaturesProvider.overrideWithValue(features),
    if (!profiles.containsKey('p1'))
      photographerProfileProvider('p1')
          .overrideWithValue(const AsyncData(bookingProfile)),
    for (final e in profiles.entries)
      photographerProfileProvider(e.key).overrideWithValue(AsyncData(e.value)),
    externalLauncherProvider.overrideWithValue(launcher),
    contactLinkRepositoryProvider.overrideWithValue(links),
    photographerContactRepositoryProvider.overrideWithValue(
      photographerContacts,
    ),
    photographerPoolCacheProvider.overrideWithValue(FakePhotographerRepository()),
    if (!hasCustomChat)
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    ...grantedNotificationPermissionUnless(extraOverrides),
    ...extraOverrides,
  ];

  // A fresh ProviderScope each time: a test may pump several worlds.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    ),
  );
  await tester.pump();

  return BookingDetailHandles(
    router: router,
    bookings: bookings,
    launcher: launcher,
    links: links,
    clock: effectiveClock,
  );
}

class BookingsTabHandles {
  const BookingsTabHandles({
    required this.router,
    required this.clock,
    required this.launcher,
  });

  final GoRouter router;
  final TestClock clock;
  final FakeExternalLauncher launcher;

  /// Location of the top-most route, pushed ones included.
  String get location => router.state.uri.toString();
}

/// An active package of the signed-in photographer (S06.02 inputs).
const workPackage = ServicePackage(
  id: 's1',
  name: 'Chân dung 2h',
  priceVnd: 1500000,
  durationMinutes: 120,
);

/// Hosts the `/bookings` tab (S05.01 for customers, S06.01/S06.02 for
/// photographers) signed in as [uid] with [role], with stub routes for
/// every place it can lead to.
///
/// S06.02 reads [portfolioPhotos] (one image per post), [packages] and the
/// server's skills [completeness] (null = not scored yet).
Future<BookingsTabHandles> pumpBookingsTab(
  WidgetTester tester, {
  String uid = detailCustomerUid,
  UserRole role = UserRole.customer,
  FakeBookingRepository? bookings,
  DateTime? now,
  TestClock? clock,
  BookingFeatures features = const BookingFeatures(
    chat: false,
    reschedule: false,
    review: false,
  ),
  int portfolioPhotos = 0,
  List<ServicePackage> packages = const [],
  int? completeness,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
  List<Override> extraOverrides = const [],

  /// Events the signed-in user created (S06.01 "Sự kiện của tôi").
  List<EventDetail> events = const [],

  /// The signed-in photographer's own `photographers/{uid}` intro (S06.02
  /// reads `acceptingOrders`). Defaults to accepting, the old empty state.
  PhotographerIntro intro = const PhotographerIntro(acceptingOrders: true),

  /// Other users' public profiles (e.g. the studio that assigned a booking).
  List<AuthUser> otherUsers = const [],
}) async {
  final effectiveClock = clock ?? TestClock(now ?? worldBookingToday);
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final userRepo = FakeUserRepository();
  await userRepo.ensureProfile(AuthUser(uid: uid, displayName: 'Lan Anh'));
  await userRepo.setRole(uid, role);
  if (uid != detailCustomerUid) {
    await userRepo.ensureProfile(
      const AuthUser(uid: detailCustomerUid, displayName: 'Lan Anh'),
    );
  }
  for (final other in otherUsers) {
    await userRepo.ensureProfile(other);
  }
  final launcher = FakeExternalLauncher();
  final skills = FakeSkillsRepository()
    ..seedServer(uid, SkillsServerInfo(completeness: completeness));
  final posts = FakePostRepository([
    for (var i = 0; i < portfolioPhotos; i++)
      fixturePost('w$i', photographerId: uid),
  ]);

  Widget stub(BuildContext _, GoRouterState s) =>
      Scaffold(body: Text('stub ${s.uri}'));

  final router = GoRouter(
    initialLocation: '/bookings',
    routes: [
      GoRoute(path: '/bookings', builder: (_, _) => const BookingsTab()),
      for (final p in [
        '/action',
        '/chats',
        '/chat/:id',
        '/b/:id',
        '/b/:id/review',
        '/work/calendar',
        '/work/earnings',
        '/verify/start',
        '/setup/2',
        '/profile/skills',
        '/u/:uid',
        '/events/mine',
        '/events/new',
        '/events/:id/manage',
      ])
        GoRoute(path: p, builder: stub),
    ],
  );

  final overrides = <Override>[
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    userRepositoryProvider.overrideWithValue(userRepo),
    clockProvider.overrideWithValue(() => effectiveClock.now),
    calendarTodayProvider.overrideWithValue(effectiveClock.now),
    bookingRepositoryProvider.overrideWithValue(
      bookings ?? FakeBookingRepository(),
    ),
    bookingFeaturesProvider.overrideWithValue(features),
    publicProfileRepositoryProvider.overrideWithValue(
      FakePublicProfileRepository([bookingProfile]),
    ),
    externalLauncherProvider.overrideWithValue(launcher),
    postRepositoryProvider.overrideWithValue(posts),
    myPackagesProvider.overrideWith((ref) => Stream.value(packages)),
    skillsRepositoryProvider.overrideWithValue(skills),
    myIntroProvider.overrideWith((ref) => Stream.value(intro)),
    eventRepositoryProvider.overrideWithValue(
      FakeEventRepository(
        uid: uid,
        events: events,
        clock: () => effectiveClock.now,
      ),
    ),
    photographerPoolCacheProvider.overrideWithValue(FakePhotographerRepository()),
    ...grantedNotificationPermissionUnless(extraOverrides),
    ...extraOverrides,
  ];

  // A fresh ProviderScope each time: a test may pump several worlds.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    ),
  );
  await tester.pump();

  return BookingsTabHandles(
    router: router,
    clock: effectiveClock,
    launcher: launcher,
  );
}

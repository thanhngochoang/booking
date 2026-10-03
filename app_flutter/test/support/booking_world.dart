// test/support/booking_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/payments_mode.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/booking_sheet_page.dart';
import 'package:photobooking/features/booking/payment_pending_screen.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';

import 'fake_booking_repository.dart';
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
  ratingAvg: 4.9,
  reviewCount: 25,
  areaLabel: 'Quận 3',
  startingPriceVnd: 1500000,
);

const bookingProfile = PhotographerProfile(
  summary: bookingProfileSummary,
  intro: PhotographerIntro(
    bio: 'Chuyên chân dung ngoại cảnh.',
    onboardingComplete: true,
  ),
);

class BookingWorldHandles {
  const BookingWorldHandles({
    required this.router,
    required this.bookings,
    required this.availRepo,
    required this.contactRepo,
    required this.externalLauncher,
  });

  final GoRouter router;
  final FakeBookingRepository bookings;
  final FakeAvailabilityRepository availRepo;
  final FakeUserContactRepository contactRepo;
  final FakeExternalLauncher externalLauncher;
}

Future<BookingWorldHandles> pumpBookingRoute(
  WidgetTester tester, {
  String path = '/u/p1/book',
  FakeBookingRepository? bookings,
  List<ServiceSummary>? packages,
  Map<DateTime, AvailabilityDay> days = const {},
  UserContact? contact = const UserContact(phone: '+84903123456'),
  DateTime? now,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  bool failPackages = false,
  bool emptyPackages = false,
  bool failProfile = false,
  bool realPayments = false,
  bool disableAnimations = false,
  Size viewSize = const Size(390, 844),
  List<Override> extraOverrides = const [],
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
        builder: (_, s) =>
            PaymentPendingScreen(bookingId: s.pathParameters['id']!),
      ),
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

  final overrides = <Override>[
    authRepositoryProvider.overrideWithValue(authRepo),
    userRepositoryProvider.overrideWithValue(userRepo),
    clockProvider.overrideWithValue(() => effectiveNow),
    calendarTodayProvider.overrideWithValue(effectiveNow),
    bookingRepositoryProvider.overrideWithValue(effectiveBookings),
    availabilityRepositoryProvider.overrideWithValue(availRepo),
    userContactRepositoryProvider.overrideWithValue(contactRepo),
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
    realPaymentsProvider.overrideWithValue(realPayments),
    ...extraOverrides,
  ];

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
        size: viewSize,
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
  );
}

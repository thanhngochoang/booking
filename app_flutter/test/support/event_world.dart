// test/support/event_world.dart
//
// Fixtures for the events data layer: Firestore documents in the shape the
// Functions write, and the matching app models.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/events/event_chat_repository.dart';
import 'package:photobooking/data/events/event_providers.dart';
import 'package:photobooking/data/events/event_social_providers.dart';
import 'package:photobooking/data/events/event_timeline.dart';
import 'package:photobooking/data/events/event_timeline_repository.dart';
import 'package:photobooking/features/event_chat/event_chat_screen.dart';
import 'package:photobooking/features/events/event_share_composer.dart';
import 'package:photobooking/data/events/event_repository.dart';
import 'package:photobooking/data/payments/payment_instructions.dart';
import 'package:photobooking/data/payments/payments_repository.dart';
import 'package:photobooking/features/payment/pay_subject.dart';
import 'package:photobooking/features/payment/payment_screen.dart';
import 'fake_payments_repository.dart';
import 'fake_spot_repository.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/event_create/create_event_screen.dart';
import 'package:photobooking/features/event_manage/manage_event_screen.dart';
import 'package:photobooking/features/event_manage/my_events_screen.dart';
import 'package:photobooking/features/event_manage/ticket_scanner.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/features/events/event_screen.dart';
import 'package:photobooking/features/events/events_list_screen.dart';
import 'package:photobooking/features/explore/location_controller.dart';

import 'fake_push.dart';
import 'fake_ticket_scanner.dart';
import 'screen_host.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/events/event_summary.dart';

/// "Now" for event tests: 10 Oct 2026, 03:00 UTC (10:00 in Việt Nam).
final eventNow = DateTime.utc(2026, 10, 10, 3);

Timestamp ts(DateTime d) => Timestamp.fromDate(d);

/// `events/{id}` as the server writes it. Defaults: an open, paid,
/// photographer-hosted photo walk three days ahead.
Map<String, dynamic> eventDoc({
  String title = 'Photo walk phố cổ',
  String status = 'open',
  String type = 'photo_walk',
  int? price = 250000,
  int? capacity = 20,
  int registered = 5,
  int held = 0,
  String hostType = 'photographer',
  String? hostId = 'p1',
  String hostName = 'Quốc Bảo',
  String createdBy = 'p1',
  String? createdByRole,
  DateTime? startAt,
  DateTime? endAt,
  DateTime? createdAt,
  bool schedule = true,
  double lat = 10.78,
  double lng = 106.70,
  String hashtag = 'PhotoWalkPhoCo1013',
  String hostConsent = 'not_required',
  DateTime? hostConsentExpiresAt,
  List<Map<String, String>> faq = const [],
  DateTime? publishedAt,
}) {
  final start = startAt ?? eventNow.add(const Duration(days: 3));
  return {
    'host': {
      'type': hostType,
      'id': hostType == 'platform' ? null : hostId,
      'name': hostType == 'platform' ? null : hostName,
      'avatarUrl': null,
      'verified': hostType != 'platform',
    },
    'hostId': hostType == 'platform' ? null : hostId,
    'createdBy': createdBy,
    'createdByRole': createdByRole ?? 'photographer',
    'hostConsent': hostConsent,
    'hostConsentExpiresAt': hostConsentExpiresAt == null
        ? null
        : ts(hostConsentExpiresAt),
    'title': title,
    'description': 'Đi bộ chụp ảnh khu phố cổ',
    'type': type,
    'coverUrl': 'https://img.test/cover.jpg',
    'coverPath': 'eventCovers/p1/e/cover.jpg',
    'startAt': schedule ? ts(start) : null,
    'endAt': schedule ? ts(endAt ?? start.add(const Duration(hours: 2))) : null,
    'dayKey': '2026-10-13',
    'location': {
      'name': 'Công viên Bạch Đằng',
      'meetingPoint': 'Cổng chính',
      'lat': lat,
      'lng': lng,
      'geohash': encodeGeohash(lat, lng),
      'areaId': null,
    },
    'capacity': capacity,
    'price': price,
    'registrationDeadline': schedule
        ? ts(start.subtract(const Duration(hours: 12)))
        : null,
    'faq': faq,
    'hashtag': hashtag,
    'hashtagKey': hashtag.toLowerCase(),
    'hashtagLocked': false,
    'status': status,
    'registeredCount': registered,
    'heldCount': held,
    'chatId': status == 'draft' ? null : 'event_x',
    'postCount': 2,
    'publishedAt': publishedAt == null ? null : ts(publishedAt),
    'completedAt': null,
    'createdAt': ts(createdAt ?? eventNow.subtract(const Duration(days: 1))),
    'updatedAt': ts(eventNow),
  };
}

/// `events/{id}/registrations/{id}`.
Map<String, dynamic> registrationDoc({
  String eventId = 'ev1',
  String userId = 'u1',
  String userName = 'Lan',
  int quantity = 1,
  int amount = 0,
  String status = 'paid',
  bool contactEligible = false,
  String ticketCode = 'VE-AB2C-1013',
  DateTime? createdAt,
  DateTime? checkedInAt,
}) => {
  'id': 'r-$userId',
  'eventId': eventId,
  'userId': userId,
  'userName': userName,
  'userAvatarUrl': null,
  'quantity': quantity,
  'amount': amount,
  'status': status,
  'holdExpiresAt': null,
  'ticketCode': ticketCode,
  'paymentId': amount > 0 ? 'pay1' : null,
  'contactEligible': contactEligible,
  'checkedInAt': checkedInAt == null ? null : ts(checkedInAt),
  'cancelledAt': null,
  'refundPercent': null,
  'event': {
    'title': 'Photo walk phố cổ',
    'type': 'photo_walk',
    'startAt': ts(eventNow.add(const Duration(days: 3))),
    'endAt': ts(eventNow.add(const Duration(days: 3, hours: 2))),
    'locationName': 'Công viên Bạch Đằng',
    'lat': 10.78,
    'lng': 106.70,
    'coverUrl': 'https://img.test/cover.jpg',
  },
  'createdAt': ts(createdAt ?? eventNow),
  'updatedAt': ts(eventNow),
};

EventSummary summaryOf(
  String id, {
  String title = 'Photo walk',
  HostType hostType = HostType.photographer,
  String? hostId = 'p1',
  String createdBy = 'p1',
  int priceVnd = 250000,
  int capacity = 20,
  int registered = 5,
  int held = 0,
  EventStatus status = EventStatus.open,
  EventType type = EventType.photoWalk,
  Duration startsIn = const Duration(days: 3),

  /// False: a draft saved before its day was chosen (`startAt` null; the
  /// mapping falls back to `createdAt`).
  bool schedule = true,
}) => EventSummary(
  id: id,
  title: title,
  hostName: hostType == HostType.platform ? '' : 'Quốc Bảo',
  hostVerified: hostType == HostType.photographer,
  hostType: hostType,
  hostId: hostType == HostType.platform ? null : hostId,
  createdBy: createdBy,
  type: type,
  startsAt: schedule
      ? eventNow.add(startsIn)
      : eventNow.subtract(const Duration(days: 1)),
  hasSchedule: schedule,
  endsAt: eventNow.add(startsIn + const Duration(hours: 2)),
  locationName: 'Công viên Bạch Đằng',
  geohash: encodeGeohash(10.78, 106.70),
  lat: 10.78,
  lng: 106.70,
  priceVnd: priceVnd,
  capacity: capacity,
  registeredCount: registered,
  heldCount: held,
  status: status,
  createdAt: eventNow.subtract(const Duration(days: 1)),
  coverUrl: 'https://img.test/cover.jpg',
);

EventDetail detailOf(
  String id, {
  HostType hostType = HostType.photographer,
  String? hostId = 'p1',
  String createdBy = 'p1',
  int priceVnd = 250000,
  int capacity = 20,
  int registered = 5,
  EventStatus status = EventStatus.open,
  HostConsent hostConsent = HostConsent.notRequired,
  DateTime? hostConsentExpiresAt,
  List<EventFaq> faq = const [],
  Duration startsIn = const Duration(days: 3),
  bool schedule = true,
  String? hashtag,
  int postCount = 0,
  DateTime? completedAt,
  String? spotId,
  bool spotDecided = false,
}) {
  final s = summaryOf(
    id,
    hostType: hostType,
    hostId: hostId,
    createdBy: createdBy,
    priceVnd: priceVnd,
    capacity: capacity,
    registered: registered,
    status: status,
    startsIn: startsIn,
    schedule: schedule,
  );
  return EventDetail(
    summary: s,
    description: 'Đi bộ chụp ảnh',
    hashtag: hashtag ?? 'PhotoWalk$id',
    postCount: postCount,
    completedAt: completedAt,
    endsAt: s.endsAt!,
    registrationDeadline: s.startsAt.subtract(const Duration(hours: 12)),
    createdBy: createdBy,
    chatId: 'event_$id',
    faq: faq,
    hostConsent: hostConsent,
    hostConsentExpiresAt: hostConsentExpiresAt,
    spotId: spotId,
    spotDecided: spotDecided || spotId != null,
  );
}

EventRegistration registrationOf(
  String id,
  String eventId, {
  String userId = 'u1',
  RegistrationStatus status = RegistrationStatus.paid,
  int quantity = 1,
  int amount = 0,
  bool contactEligible = false,
  DateTime? createdAt,
  String userName = 'Lan',
  String? ticketCode,
  DateTime? checkedInAt,
}) => EventRegistration(
  id: id,
  eventId: eventId,
  userId: userId,
  userName: userName,
  ticketCode:
      ticketCode ?? (status == RegistrationStatus.paid ? 'VE-AB2C-1013' : ''),
  checkedInAt: checkedInAt,
  quantity: quantity,
  amount: amount,
  status: status,
  contactEligible: contactEligible,
  event: EventTicketSnapshot(
    title: 'Photo walk',
    type: EventType.photoWalk,
    startsAt: eventNow.add(const Duration(days: 3)),
    endsAt: eventNow.add(const Duration(days: 3, hours: 2)),
  ),
  createdAt: createdAt ?? eventNow,
);

// ---------------------------------------------------------------------------
// Screen tests (S11.01–S11.04): fakes, overrides and a router with stubs.
// ---------------------------------------------------------------------------

/// What a screen test of the events needs, wired the way the app does.
class EventsWorld {
  EventsWorld({
    List<EventDetail> events = const [],
    List<EventRegistration> registrations = const [],
    this.uid = 'u1',
    this.role = UserRole.customer,
    this.staff,
    this.contact = const UserContact(phone: '+84903123456'),
    this.hostTomatoCount = 11,
    this.hostChannels = const ContactChannels(call: true),
    this.onboardingComplete = false,
    this.now,
    this.clock,
    this.nearbyEvents,
    this.areaOrigin,
    this.prefsValues = const {},
    List<List<PickedImage>> pickerAnswers = const [],
    Map<String, List<TimelineItem>> timelineItems = const {},
  }) : picker = FakeImagePicker(pickerAnswers),
       timeline = FakeEventTimelineRepository(
         items: timelineItems,
         clock: clock ?? () => now ?? eventNow,
       ),
       chat = FakeEventChatRepository(uid: uid),
       repo = FakeEventRepository(
         uid: uid,
         events: events,
         registrations: registrations,
         clock: clock ?? () => now ?? eventNow,
       ),
       nearby = FakeNearbyEventsRepository(
         nearbyEvents ?? [for (final e in events) e.summary],
       ) {
    payments.onConfirm = (paymentId, kind) async {
      repo.maybeFailForTest();
      repo.fakeConfirmed.add(paymentId);
      final r = repo.registrations
          .where((x) => x.paymentId == paymentId)
          .firstOrNull;
      if (r != null) {
        repo.applyPaymentForTest(paymentId);
      }
    };
  }

  final String uid;
  final UserRole role;
  final StaffRole? staff;
  final UserContact? contact;
  final int hostTomatoCount;
  final ContactChannels hostChannels;
  final bool onboardingComplete;
  final DateTime? now;

  /// A moving clock (countdowns); overrides [now] when set.
  final DateTime Function()? clock;
  final List<EventSummary>? nearbyEvents;

  /// A saved area for "Gần tôi": `(lat, lng)`; none when null.
  final ({double lat, double lng})? areaOrigin;

  /// SharedPreferences contents at the start (`eventDraft:<uid>` …).
  final Map<String, Object> prefsValues;
  SharedPreferences? prefs;

  final FakeImagePicker picker;
  final scanner = FakeTicketScanner();
  final locationRepo = FakeLocationRepository(
    status: LocationPermissionStatus.granted,
    position: (lat: 10.8, lng: 106.7),
  );

  final FakeEventRepository repo;
  final FakeEventTimelineRepository timeline;
  final FakeEventChatRepository chat;
  final FakeNearbyEventsRepository nearby;
  final launcher = FakeExternalLauncher();

  /// The spot directory S12.01 "Điểm chụp" reads; empty unless seeded.
  final spots = FakeSpotRepository();
  final payments = FakePaymentsRepository();
  final contactRepo = FakePhotographerContactRepository();
  final contactLinks = FakeContactLinkRepository();
  late GoRouter router;

  String get location => router.state.uri.toString();

  List<Override> get overrides => [
    clockProvider.overrideWithValue(clock ?? () => now ?? eventNow),
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    currentProfileProvider.overrideWith(
      (ref) => Stream.value(
        UserProfile(uid: uid, role: role, displayName: 'Lan Anh'),
      ),
    ),
    staffRoleProvider.overrideWith((ref) => staff),
    myIntroProvider.overrideWith(
      (ref) => Stream.value(
        PhotographerIntro(onboardingComplete: onboardingComplete),
      ),
    ),
    currentContactProvider.overrideWithValue(AsyncData(contact)),
    paymentsRepositoryProvider.overrideWithValue(payments),
    eventRepositoryProvider.overrideWithValue(repo),
    spotRepositoryProvider.overrideWithValue(spots),
    eventTimelineRepositoryProvider.overrideWithValue(timeline),
    eventChatRepositoryProvider.overrideWithValue(chat),
    if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs!),
    imagePickerProvider.overrideWithValue(picker),
    ticketScannerProvider.overrideWithValue(scanner),
    locationRepositoryProvider.overrideWithValue(locationRepo),
    nearbyEventsRepositoryProvider.overrideWithValue(nearby),
    externalLauncherProvider.overrideWithValue(launcher),
    photographerContactRepositoryProvider.overrideWithValue(contactRepo),
    contactLinkRepositoryProvider.overrideWithValue(contactLinks),
    photographerProfileProvider('p1').overrideWithValue(
      AsyncData(
        PhotographerProfile(
          summary: PhotographerSummary(
            id: 'p1',
            displayName: 'Quốc Bảo',
            reviewCount: hostTomatoCount + 1,
            tomatoCount: hostTomatoCount,
            brickCount: 1,
            tomatoPct: (100 * hostTomatoCount / (hostTomatoCount + 1)).round(),
            verified: true,
            acceptingOrders: true,
          ),
        ),
      ),
    ),
    if (areaOrigin != null)
      exploreResolutionProvider.overrideWithValue(
        ExploreResolution(
          ExploreMode.nearby,
          ExploreOrigin(
            lat: areaOrigin!.lat,
            lng: areaOrigin!.lng,
            fromDevice: false,
            areaName: 'Quận 1',
          ),
        ),
      )
    else
      exploreResolutionProvider.overrideWithValue(
        const ExploreResolution(ExploreMode.chooseArea),
      ),
  ];

  /// Opens [path] in a router with the event routes and stubs for the rest.
  Future<void> pump(
    WidgetTester tester, {
    String path = '/events',
    Size size = const Size(390, 844),
    double textScale = 1,
    Widget Function(GoRouterState)? bookings,
    List<Override> extra = const [],

    /// The real S12 screens (create, manage, mine) instead of stubs.
    bool organizer = false,
  }) async {
    if (prefs == null) {
      SharedPreferences.setMockInitialValues(prefsValues);
      prefs = await SharedPreferences.getInstance();
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    contactRepo.seed('p1', channels: hostChannels);
    Widget stub(BuildContext _, GoRouterState s) =>
        Scaffold(body: Text('stub ${s.uri}'));
    router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(path: '/events', builder: (_, _) => const EventsListScreen()),
        GoRoute(
          path: '/events/mine',
          builder: organizer ? (_, _) => const MyEventsScreen() : stub,
        ),
        GoRoute(
          path: '/events/new',
          builder: organizer
              ? (_, s) =>
                    CreateEventScreen(draftId: s.uri.queryParameters['draft'])
              : stub,
        ),
        GoRoute(
          path: '/events/:id/manage',
          builder: organizer
              ? (_, s) => ManageEventScreen(eventId: s.pathParameters['id']!)
              : stub,
        ),
        GoRoute(
          path: '/e/:eventId',
          builder: (_, s) => EventScreen(eventId: s.pathParameters['eventId']!),
          routes: [
            GoRoute(
              path: 'join',
              builder: (_, s) => EventScreen(
                eventId: s.pathParameters['eventId']!,
                openRegister: true,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/e/:eventId/timeline',
          builder: (_, s) => EventScreen(
            eventId: s.pathParameters['eventId']!,
            initialTab: EventTab.timeline,
            initialReview: s.uri.queryParameters['review'] == '1',
          ),
        ),
        GoRoute(
          path: '/e/:eventId/share',
          builder: (_, s) =>
              EventShareComposer(eventId: s.pathParameters['eventId']!),
        ),
        GoRoute(
          path: '/e/:eventId/chat',
          builder: (_, s) =>
              EventChatScreen(eventId: s.pathParameters['eventId']!),
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
        GoRoute(
          path: '/bookings',
          builder: bookings == null ? stub : (_, s) => bookings(s),
        ),
        for (final p in [
          '/home',
          '/action',
          '/p/:postId',
          '/profile/phone',
          '/u/:uid',
          '/u/:uid/ask',
          '/setup',
        ])
          GoRoute(path: p, builder: stub),
      ],
    );
    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        // Granted, so no screen under test shows the S17.03 primer unless a
        // test passes its own permission in [extra].
        overrides: [
          ...overrides,
          ...grantedNotificationPermissionUnless(extra),
          ...extra,
        ],
        textScale: textScale,
      ),
    );
    await settle(tester);
  }
}

/// Lets streams and short animations finish without waiting for timers that
/// never end.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A timeline row for tests.
TimelineItem timelineItemOf(
  String id,
  String author, {
  TimelineStatus status = TimelineStatus.visible,
  bool host = false,
  int minutesAgo = 0,
  int imageCount = 1,
}) => TimelineItem(
  postId: id,
  authorId: 'a-$id',
  authorName: author,
  imageUrl: 'https://img.test/$id.jpg',
  imageW: 800,
  imageH: 1000,
  imageCount: imageCount,
  isHost: host,
  status: status,
  addedAt: eventNow.subtract(Duration(minutes: minutesAgo)),
);

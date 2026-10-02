// test/support/discovery_world.dart
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/local_recommender.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// p1 free Sat 3 Oct, p2 free Fri 2 Oct, p3 free Sun 4 Oct, p4 no free day.
List<PhotographerSummary> discoveryPhotographers() => [
  fixturePhotographer(
    'p1',
    name: 'Minh Trí',
    verified: true,
    specialties: const ['portrait', 'wedding'],
    styles: const ['natural_light'],
    nextFreeDate: '2026-10-03',
    areaLabel: 'Quận 3',
    startingPrice: 1500000,
  ),
  fixturePhotographer(
    'p2',
    name: 'Hồng Nhung',
    specialties: const ['wedding'],
    rating: 4.7,
    reviews: 64,
    completed: 80,
    nextFreeDate: '2026-10-02',
    areaLabel: 'Quận 1',
    startingPrice: 8000000,
    lat: 10.80,
    lng: 106.70,
  ),
  fixturePhotographer(
    'p3',
    name: 'Quốc Bảo',
    specialties: const ['family'],
    styles: const ['film'],
    rating: 4.5,
    reviews: 20,
    completed: 40,
    nextFreeDate: '2026-10-04',
    areaLabel: 'Thủ Đức',
    startingPrice: 1200000,
    lat: 10.85,
    lng: 106.75,
  ),
  fixturePhotographer(
    'p4',
    name: 'Thu Hà',
    specialties: const ['graduation'],
    rating: 4.2,
    reviews: 9,
    completed: 20,
    areaLabel: 'Quận 7',
    startingPrice: 3000000,
    lat: 10.73,
    lng: 106.72,
  ),
];

/// Newest first: a, b, c, d, e work posts; two real-shoot posts by customers.
List<PostSummary> discoveryPosts() => [
  fixturePost(
    'a',
    photographerId: 'p1',
    serviceId: 's1',
    specialtyId: 'portrait',
    age: const Duration(hours: 1),
    likes: 214,
    saves: 37,
  ),
  fixturePost(
    'b',
    photographerId: 'p2',
    serviceId: 't1',
    specialtyId: 'wedding',
    age: const Duration(hours: 2),
  ),
  fixturePost(
    'c',
    photographerId: 'p3',
    serviceId: 'u1',
    specialtyId: 'family',
    age: const Duration(hours: 3),
  ),
  fixturePost(
    'd',
    photographerId: 'p4',
    serviceId: 'v1',
    specialtyId: 'graduation',
    age: const Duration(hours: 4),
  ),
  fixturePost(
    'e',
    photographerId: 'p1',
    serviceId: 's1',
    specialtyId: 'portrait',
    age: const Duration(hours: 5),
    images: 2,
  ),
  fixturePost(
    'r1',
    kind: PostKind.realShoot,
    authorId: 'cu1',
    photographerId: 'p1',
    serviceId: 's1',
    age: const Duration(minutes: 30),
    caption: 'Cảm ơn Minh Trí',
  ),
  fixturePost(
    'r2',
    kind: PostKind.realShoot,
    authorId: 'cu2',
    photographerId: 'p2',
    serviceId: 't1',
    age: const Duration(minutes: 40),
  ),
];

List<ServiceSummary> discoveryServices() => [
  fixtureService('s1'),
  fixtureService(
    's2',
    name: 'Cặp đôi nửa ngày',
    price: 3200000,
    specialtyId: 'couple',
  ),
  fixtureService('sOld', name: 'Gói cũ', active: false),
  fixtureService(
    't1',
    photographerId: 'p2',
    name: 'Cưới cả ngày',
    price: 8000000,
    specialtyId: 'wedding',
  ),
  fixtureService(
    'u1',
    photographerId: 'p3',
    name: 'Gia đình 1 giờ',
    price: 1200000,
    specialtyId: 'family',
    durationMinutes: 60,
  ),
  fixtureService(
    'v1',
    photographerId: 'p4',
    name: 'Kỷ yếu',
    price: 3000000,
    specialtyId: 'graduation',
  ),
];

/// Fakes and provider overrides for a signed-in user using the discovery
/// screens. Location defaults to "denied forever": no prompt, no fix.
class DiscoveryWorld {
  DiscoveryWorld({
    List<PostSummary>? posts,
    List<PhotographerSummary>? photographers,
    List<ServiceSummary>? services,
    this.role = UserRole.customer,
    this.hasPhone = true,
    LocationPermissionStatus status = LocationPermissionStatus.deniedForever,
    this.prefsValues = const {},
    this.recommenderFactory,
  }) : posts = FakePostRepository(posts ?? discoveryPosts()),
       photographers = FakePhotographerRepository(
         photographers ?? discoveryPhotographers(),
       ),
       services = FakeServiceRepository(services ?? discoveryServices()),
       engagement = FakePostEngagementRepository(),
       availability = FakeAvailabilityLookup(),
       location = FakeLocationRepository(status: status),
       contacts = FakeUserContactRepository();

  final FakePostRepository posts;
  final FakePhotographerRepository photographers;
  final FakeServiceRepository services;
  final FakePostEngagementRepository engagement;
  final FakeAvailabilityLookup availability;
  final FakeLocationRepository location;
  final FakeUserContactRepository contacts;
  final UserRole role;
  final bool hasPhone;
  final Map<String, Object> prefsValues;

  /// Builds the recommender used by the screens; defaults to a
  /// [LocalRecommender] over the fakes above.
  final RecommendationRepository Function(DiscoveryWorld world)?
  recommenderFactory;

  late SharedPreferences prefs;
  late FakeAuthRepository auth;
  late String uid;
  late RecommendationRepository recommender;
  late List<Override> overrides;

  LocalRecommender localRecommender() => LocalRecommender(
    posts: posts,
    photographers: photographers,
    availability: availability,
    clock: () => fixtureNow,
  );

  Future<void> init() async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Lan Anh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    uid = u.uid;
    if (hasPhone) {
      contacts.seed(u.uid, const UserContact(phone: '+84903123456'));
    }
    recommender = recommenderFactory?.call(this) ?? localRecommender();
    overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => fixtureNow),
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      userContactRepositoryProvider.overrideWithValue(contacts),
      locationRepositoryProvider.overrideWithValue(location),
      nearbyEventsRepositoryProvider.overrideWithValue(
        FakeNearbyEventsRepository(),
      ),
      postRepositoryProvider.overrideWithValue(posts),
      postEngagementRepositoryProvider.overrideWithValue(engagement),
      photographerRepositoryProvider.overrideWithValue(photographers),
      serviceRepositoryProvider.overrideWithValue(services),
      availabilityLookupProvider.overrideWithValue(availability),
      recommendationRepositoryProvider.overrideWithValue(recommender),
    ];
  }
}

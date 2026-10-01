// test/support/explore_world.dart
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/event_routes.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/events/nearby_events_repository_test.dart' show event;

/// Thursday 1 Oct 2026, 12:00 in Vietnam.
final exploreNow = DateTime.utc(2026, 10, 1, 5);

/// Device position used by the tests: central Ho Chi Minh City.
const exploreFix = (lat: 10.7769, lng: 106.7009);

/// 1,1 km, 6,7 km, 24,8 km and 47 km from [exploreFix].
final exploreEvents = [
  event('near', title: 'Photo walk phố cổ', lat: 10.7869, lng: 106.7009),
  event(
    'mid',
    title: 'Mini session mùa thu',
    lat: 10.8369,
    lng: 106.7009,
    priceVnd: 600000,
    startsIn: const Duration(days: 10),
  ),
  event(
    'free',
    title: 'Workshop ánh sáng',
    lat: 11.0,
    lng: 106.7,
    priceVnd: 0,
    startsIn: const Duration(days: 5),
  ),
  event(
    'out',
    title: 'Sự kiện xa',
    lat: 11.2,
    lng: 106.7,
    startsIn: const Duration(days: 2),
  ),
];

/// Fakes and overrides for a signed-in user looking at Explore.
class ExploreWorld {
  ExploreWorld({
    LocationPermissionStatus status = LocationPermissionStatus.notAsked,
    LocationPermissionStatus afterRequest = LocationPermissionStatus.granted,
    List<EventSummary>? events,
    this.role = UserRole.customer,
    this.routesReady = false,
    this.prefsValues = const {},
  }) : location = FakeLocationRepository(
         status: status,
         statusAfterRequest: afterRequest,
         location: ApproxLocation(
           lat: exploreFix.lat,
           lng: exploreFix.lng,
           capturedAt: exploreNow,
         ),
       ),
       repo = FakeNearbyEventsRepository(events ?? exploreEvents);

  final FakeLocationRepository location;
  final FakeNearbyEventsRepository repo;
  final UserRole role;
  final bool routesReady;
  final Map<String, Object> prefsValues;
  late SharedPreferences prefs;
  late List<Override> overrides;

  Future<void> init() async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => exploreNow),
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      locationRepositoryProvider.overrideWithValue(location),
      nearbyEventsRepositoryProvider.overrideWithValue(repo),
      eventRoutesReadyProvider.overrideWithValue(routesReady),
    ];
  }
}

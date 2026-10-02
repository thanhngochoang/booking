import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screen_host.dart';

/// Thursday 1 Oct 2026 on the Vietnamese calendar.
final worldToday = DateTime.utc(2026, 10, 1);

/// A signed-in photographer with in-memory repositories, for the screens of
/// plan 2d1.
class PhotographerWorld {
  PhotographerWorld({
    this.role = UserRole.photographer,
    this.prefsValues = const {},
  });

  final UserRole role;
  final Map<String, Object> prefsValues;
  final intro = FakePhotographerIntroRepository();
  final packages = FakeServicePackageRepository();
  final availability = FakeAvailabilityRepository();
  final users = FakeUserRepository();
  final auth = FakeAuthRepository();
  final picker = FakeImagePicker();
  final uploader = FakeMediaUploader();
  DateTime today = worldToday;
  late SharedPreferences prefs;
  late String uid;
  late GoRouter router;

  Future<void> init() async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    final u = await auth.registerWithEmail('tri@b.vn', 'password1', 'Minh Trí');
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    uid = u.uid;
  }

  List<Override> get overrides => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(users),
    photographerIntroRepositoryProvider.overrideWithValue(intro),
    servicePackageRepositoryProvider.overrideWithValue(packages),
    availabilityRepositoryProvider.overrideWithValue(availability),
    calendarTodayProvider.overrideWithValue(today),
    imagePickerProvider.overrideWithValue(picker),
    mediaUploaderProvider.overrideWithValue(uploader),
  ];

  /// Destinations the screens of this plan link to, shown as their path.
  static const stubPaths = [
    '/home',
    '/setup/3',
    '/setup/4',
    '/settings/profile',
    '/b/:id',
    '/events/:id/manage',
  ];

  Widget app({
    required String location,
    required List<RouteBase> routes,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    final taken = routes.whereType<GoRoute>().map((r) => r.path).toSet();
    router = GoRouter(
      initialLocation: location,
      routes: [
        ...routes,
        for (final p in stubPaths)
          if (!taken.contains(p))
            GoRoute(path: p, builder: (_, s) => Text('stub ${s.uri}')),
      ],
    );
    return screenRouterApp(
      router: router,
      overrides: overrides,
      brightness: brightness,
      textScale: textScale,
    );
  }
}

/// Sets the test window to a phone [width] logical pixels wide.
void usePhone(WidgetTester tester, {double width = 390, double height = 800}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

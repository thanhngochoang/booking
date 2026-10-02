// test/support/create_post_world.dart
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A signed-in user (a photographer by default) with in-memory packages and
/// posts, for the S10.01 Create post screen and the tab that mounts it.
class CreatePostWorld {
  CreatePostWorld({
    this.role = UserRole.photographer,
    this.prefsValues = const {},
  });

  final UserRole role;
  final Map<String, Object> prefsValues;
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final services = FakeServiceRepository();
  final posts = FakePostRepository();
  late SharedPreferences prefs;
  late String uid;

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
    serviceRepositoryProvider.overrideWithValue(services),
    postRepositoryProvider.overrideWithValue(posts),
  ];
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/features/skills/skills_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fakes for every skills test: a signed-in photographer, their saved
/// skills, their posts, device storage and an analytics log.
class SkillsWorld {
  SkillsWorld._(this.auth, this.uid, this.skills, this.posts, this.prefs);

  static Future<SkillsWorld> create({
    PhotographerSkills? saved,
    List<PostSummary> Function(String uid)? posts,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final store = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();
    final user = await auth.registerWithEmail(
      'p@b.vn',
      'password1',
      'Minh Thư',
    );
    final skills = FakeSkillsRepository();
    if (saved != null) skills.seed(user.uid, saved);
    return SkillsWorld._(
      auth,
      user.uid,
      skills,
      FakePostRepository(posts?.call(user.uid) ?? const []),
      store,
    );
  }

  final FakeAuthRepository auth;
  final String uid;
  final FakeSkillsRepository skills;
  final FakePostRepository posts;
  final SharedPreferences prefs;
  final events = <(String, Map<String, Object>)>[];

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    skillsRepositoryProvider.overrideWithValue(skills),
    postRepositoryProvider.overrideWithValue(posts),
    sharedPreferencesProvider.overrideWithValue(prefs),
    skillsAnalyticsProvider.overrideWithValue(
      (name, params) => events.add((name, params)),
    ),
  ];

  ProviderContainer container() =>
      ProviderContainer(overrides: overrides, retry: (_, _) => null);

  /// Parameters of the only event called [name].
  Map<String, Object> event(String name) =>
      events.where((e) => e.$1 == name).single.$2;
}

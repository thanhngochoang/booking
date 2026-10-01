import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/skills/firestore_skills_repository.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_repository.dart';

final skillsRepositoryProvider = Provider<SkillsRepository>(
  (ref) => FirestoreSkillsRepository(),
);

/// The skills catalogue. Built in today; a remote `taxonomy/skills` reader
/// (with this list as fallback) can override it without touching screens.
final skillCatalogProvider = Provider<TaxonomyCatalog>(
  (ref) => builtInSkillCatalog,
);

/// Any photographer's skills, read once while a screen shows them (S03).
final photographerSkillsProvider = FutureProvider.autoDispose
    .family<PhotographerSkills, String>(
      (ref, uid) => ref.watch(skillsRepositoryProvider).load(uid),
      retry: (_, _) => null,
    );

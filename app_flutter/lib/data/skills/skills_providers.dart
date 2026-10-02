import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/skills/firestore_skills_repository.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';

final skillsRepositoryProvider = Provider<SkillsRepository>(
  (ref) => FirestoreSkillsRepository(),
);

/// The skills catalogue. Built in today; a remote `taxonomy/skills` reader
/// (with this list as fallback) can override it without touching screens.
final skillCatalogProvider = Provider<TaxonomyCatalog>(
  (ref) => builtInSkillCatalog,
);

/// A photographer's skills and the server's score of them, read once while
/// a screen shows them. Invalidate this one after a save.
final photographerSkillsSnapshotProvider = FutureProvider.autoDispose
    .family<SkillsSnapshot, String>(
      (ref, uid) => ref.watch(skillsRepositoryProvider).load(uid),
      retry: (_, _) => null,
    );

/// Any photographer's skills (S03.01); the same single read as
/// [photographerSkillsSnapshotProvider].
final photographerSkillsProvider = FutureProvider.autoDispose
    .family<PhotographerSkills, String>(
      (ref, uid) async =>
          (await ref.watch(photographerSkillsSnapshotProvider(uid).future))
              .skills,
      retry: (_, _) => null,
    );

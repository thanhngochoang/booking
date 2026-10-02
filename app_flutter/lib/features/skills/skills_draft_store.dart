// lib/features/skills/skills_draft_store.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

/// The unsaved S38 draft, kept on this device so leaving the screen (or the
/// app) loses nothing. It may be incomplete; Firestore only ever gets valid
/// skills.
class SkillsDraftStore {
  SkillsDraftStore(this._prefs);
  final SharedPreferences _prefs;

  static String keyFor(String uid) => 'skillsDraft.$uid';

  PhotographerSkills? read(String uid) {
    final raw = _prefs.getString(keyFor(uid));
    if (raw == null) return null;
    try {
      return skillsFromMap(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String uid, PhotographerSkills skills) async {
    await _prefs.setString(keyFor(uid), jsonEncode(skillsToMap(skills)));
  }

  Future<void> clear(String uid) async {
    await _prefs.remove(keyFor(uid));
  }
}

final skillsDraftStoreProvider = Provider<SkillsDraftStore>(
  (ref) => SkillsDraftStore(ref.watch(sharedPreferencesProvider)),
);

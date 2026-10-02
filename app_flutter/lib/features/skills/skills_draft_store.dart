// lib/features/skills/skills_draft_store.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

/// The unsaved S08.02 draft, kept on this device so leaving the screen (or the
/// app) loses nothing. It may be incomplete; Firestore only ever gets valid
/// skills. Also remembers which evidence removal S08.02 already announced.
class SkillsDraftStore {
  SkillsDraftStore(this._prefs);
  final SharedPreferences _prefs;

  static String keyFor(String uid) => 'skillsDraft.$uid';

  static String evidenceSeenKeyFor(String uid) => 'skillsEvidenceSeen.$uid';

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

  /// The last `skills.evidenceRemovedAt` this device told the photographer
  /// about (UTC), or null.
  DateTime? evidenceRemovedSeen(String uid) {
    final ms = _prefs.getInt(evidenceSeenKeyFor(uid));
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> markEvidenceRemovedSeen(String uid, DateTime at) async {
    await _prefs.setInt(evidenceSeenKeyFor(uid), at.millisecondsSinceEpoch);
  }
}

final skillsDraftStoreProvider = Provider<SkillsDraftStore>(
  (ref) => SkillsDraftStore(ref.watch(sharedPreferencesProvider)),
);

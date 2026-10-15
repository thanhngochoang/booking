import 'package:shared_preferences/shared_preferences.dart';

/// When this device last showed the user's own badges (S03.02 "Mới" dot),
/// per uid, in UTC milliseconds.
class BadgesSeenStore {
  BadgesSeenStore(this._prefs);

  final SharedPreferences _prefs;

  String _key(String uid) => 'badgesSeenAt:$uid';

  DateTime? seenAt(String uid) {
    final ms = _prefs.getInt(_key(uid));
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  Future<void> markSeen(String uid, DateTime at) async {
    await _prefs.setInt(_key(uid), at.toUtc().millisecondsSinceEpoch);
  }
}

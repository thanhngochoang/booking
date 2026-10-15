import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';

const _key = 'notifPrimerLaterAt';

/// Remembers the last "Để sau" on this device (UTC milliseconds).
class PrefsPrimerStore implements PrimerStore {
  PrefsPrimerStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  DateTime? get lastSnoozed {
    final ms = _prefs.getInt(_key);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  Future<void> snooze(DateTime at) async {
    await _prefs.setInt(_key, at.toUtc().millisecondsSinceEpoch);
  }
}

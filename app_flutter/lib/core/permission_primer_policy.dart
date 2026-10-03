abstract interface class PrimerStore {
  DateTime? get lastSnoozed;
  Future<void> snooze(DateTime at);
}

class PermissionPrimerPolicy {
  const PermissionPrimerPolicy({
    required this.store,
    required this.now,
    this.snoozeFor = const Duration(days: 7),
  });

  final PrimerStore store;
  final DateTime Function() now;
  final Duration snoozeFor;

  /// False on app start (`atAppStart: true`) and within [snoozeFor] of the last "Để sau".
  bool shouldAsk({required bool atAppStart}) {
    if (atAppStart) {
      return false;
    }
    final last = store.lastSnoozed;
    if (last == null) {
      return true;
    }
    return now().difference(last) >= snoozeFor;
  }

  Future<void> later() => store.snooze(now());
}

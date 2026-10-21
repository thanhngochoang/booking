import 'dart:async';

import 'package:photobooking/data/account/account_repository.dart';

class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    List<DeletionBlocker>? blockers,
    DateTime? restoreUntil,
    AccountLock? lock,
    DataExport? export,
    this.reauthRequiredOnDeletion = false,
    this.conflictOnDeletion = false,
    this.deadlinePassedOnRestore = false,
    this.notFoundOnRestore = false,
    this.limitExceededOnExport = false,
    this.notEligibleOnExport = false,
  })  : blockers = blockers ?? [],
        restoreUntil = restoreUntil ?? DateTime(2026, 11, 20, 10),
        _lockController = StreamController<AccountLock?>.broadcast(sync: true),
        _exportController = StreamController<DataExport?>.broadcast(sync: true) {
    if (lock != null) _currentLock = lock;
    if (export != null) _currentExport = export;
  }

  final List<DeletionBlocker> blockers;
  final DateTime restoreUntil;
  bool reauthRequiredOnDeletion;
  bool conflictOnDeletion;
  bool deadlinePassedOnRestore;
  bool notFoundOnRestore;
  bool limitExceededOnExport;
  bool notEligibleOnExport;

  AccountLock? _currentLock;
  DataExport? _currentExport;
  final StreamController<AccountLock?> _lockController;
  final StreamController<DataExport?> _exportController;

  final List<String> calls = [];
  bool? lastHiddenSet;

  void emitLock(AccountLock? lock) {
    _currentLock = lock;
    _lockController.add(lock);
  }

  void emitExport(DataExport? export) {
    _currentExport = export;
    _exportController.add(export);
  }

  @override
  Future<List<DeletionBlocker>> deletionBlockers() async {
    calls.add('deletionBlockers');
    return blockers;
  }

  @override
  Future<DateTime> requestDeletion() async {
    calls.add('requestDeletion');
    if (reauthRequiredOnDeletion) throw const AccountException('reauth_required');
    if (conflictOnDeletion) throw const AccountException('conflict');
    emitLock(AccountLock(restoreUntil));
    return restoreUntil;
  }

  @override
  Future<void> restore() async {
    calls.add('restore');
    if (notFoundOnRestore) throw const AccountException('not_found');
    if (deadlinePassedOnRestore) throw const AccountException('deadline_passed');
    emitLock(null);
  }

  @override
  Stream<AccountLock?> watchLock(String uid) async* {
    yield _currentLock;
    yield* _lockController.stream;
  }

  @override
  Future<DataExport> requestExport() async {
    calls.add('requestExport');
    if (notEligibleOnExport) throw const AccountException('not_eligible');
    if (limitExceededOnExport) throw const AccountException('limit_exceeded');
    final exp = DataExport(
      path: 'exports/$uid/fake.json',
      sizeBytes: 1024,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
    emitExport(exp);
    return exp;
  }

  String uid = 'test-uid';

  @override
  Stream<DataExport?> watchExport(String uid) async* {
    yield _currentExport;
    yield* _exportController.stream;
  }

  @override
  Future<Uri> exportDownloadUrl(String path) async {
    calls.add('exportDownloadUrl:$path');
    return Uri.parse('https://storage.test/$path');
  }

  @override
  Future<void> setHiddenFromDiscovery(String uid, bool hidden) async {
    calls.add('setHiddenFromDiscovery:$hidden');
    lastHiddenSet = hidden;
  }

  void dispose() {
    _lockController.close();
    _exportController.close();
  }
}

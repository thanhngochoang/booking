import 'dart:async';

import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_repository.dart';

class FakeSafetyRepository implements SafetyRepository {
  FakeSafetyRepository({
    BlockIndex initialIndex = const BlockIndex(),
    List<BlockedUser>? initialBlocked,
  })  : _currentIndex = initialIndex,
        _blockedList = List.of(initialBlocked ?? []);

  BlockIndex _currentIndex;
  final List<BlockedUser> _blockedList;
  final StreamController<BlockIndex> _indexController =
      StreamController<BlockIndex>.broadcast();

  final List<String> blockCalls = [];
  final List<String> unblockCalls = [];
  final List<ReportDraft> reportCalls = [];

  SafetyError? nextError;

  void emitIndex(BlockIndex index) {
    _currentIndex = index;
    _indexController.add(index);
  }

  void seedBlocked(List<BlockedUser> list) {
    _blockedList
      ..clear()
      ..addAll(list);
  }

  @override
  Stream<BlockIndex> watchIndex() async* {
    yield _currentIndex;
    yield* _indexController.stream;
  }

  @override
  Future<List<BlockedUser>> blocked({int limit = 50}) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    return _blockedList.take(limit).toList();
  }

  @override
  Future<void> block(String userId, {String source = 'menu'}) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    blockCalls.add(userId);
    final newBlocked = {..._currentIndex.blockedIds, userId};
    emitIndex(BlockIndex(
      blockedIds: newBlocked,
      blockedByIds: _currentIndex.blockedByIds,
    ));
    if (!_blockedList.any((u) => u.userId == userId)) {
      _blockedList.insert(
        0,
        BlockedUser(
          userId: userId,
          displayName: userId,
          blockedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> unblock(String userId) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    unblockCalls.add(userId);
    final newBlocked = Set<String>.from(_currentIndex.blockedIds)..remove(userId);
    emitIndex(BlockIndex(
      blockedIds: newBlocked,
      blockedByIds: _currentIndex.blockedByIds,
    ));
    _blockedList.removeWhere((u) => u.userId == userId);
  }

  @override
  Future<ReportResult> report(ReportDraft draft) async {
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    reportCalls.add(draft);
    if (draft.block && draft.target.ownerId != null) {
      await block(draft.target.ownerId!, source: 'report');
    }
    return ReportResult(
      reportId: 'rep_${reportCalls.length}',
      duplicate: false,
      blocked: draft.block,
    );
  }

  void dispose() {
    _indexController.close();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/data/safety/safety.dart';
import 'package:photobooking/data/safety/safety_repository.dart';

class FirestoreSafetyRepository implements SafetyRepository {
  FirestoreSafetyRepository({
    required this.uid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final String? uid;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @visibleForTesting
  static SafetyError mapFunctionsError(dynamic e) {
    if (e is FirebaseFunctionsException) {
      final detailsCode = e.details is Map
          ? (e.details as Map)['code'] as String?
          : null;
      for (final candidate in [detailsCode, e.code, e.message]) {
        if (candidate == null) continue;
        final mapped = switch (candidate) {
          'limit_exceeded' ||
          'resource-exhausted' => const SafetyError('limit_exceeded'),
          'not_found' || 'not-found' => const SafetyError('not_found'),
          'permission_denied' ||
          'permission-denied' => const SafetyError('permission_denied'),
          'unauthenticated' => const SafetyError('unauthenticated'),
          'invalid_argument' ||
          'invalid-argument' => const SafetyError('invalid_argument'),
          'failed-precondition' => const SafetyError('failed_precondition'),
          'unavailable' ||
          'deadline-exceeded' => const SafetyError('network'),
          _ => null,
        };
        if (mapped != null) return mapped;
      }
      return SafetyError(e.code, e.message);
    }
    return SafetyError('network', e.toString());
  }

  @override
  Stream<BlockIndex> watchIndex() {
    final currentUid = uid;
    if (currentUid == null || currentUid.isEmpty) {
      return Stream.value(const BlockIndex());
    }

    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('private')
        .doc('blocks')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return const BlockIndex();
      final data = snap.data();
      if (data == null) return const BlockIndex();
      final rawBlocked = data['blockedIds'] as List<dynamic>? ?? const [];
      final rawBlockedBy = data['blockedByIds'] as List<dynamic>? ?? const [];
      return BlockIndex(
        blockedIds: rawBlocked.whereType<String>().toSet(),
        blockedByIds: rawBlockedBy.whereType<String>().toSet(),
      );
    });
  }

  @override
  Future<List<BlockedUser>> blocked({int limit = 50}) async {
    final currentUid = uid;
    if (currentUid == null || currentUid.isEmpty) return const [];

    final snap = await _firestore
        .collection('blocks')
        .where('blockerId', isEqualTo: currentUid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      final blockedId = data['blockedId'] as String? ?? '';
      final blockedName = data['blockedName'] as String? ?? '';
      final avatarUrl = data['blockedAvatarUrl'] as String?;
      final createdAtRaw = data['createdAt'];
      DateTime blockedAt = DateTime.now();
      if (createdAtRaw is Timestamp) {
        blockedAt = createdAtRaw.toDate();
      } else if (createdAtRaw is String) {
        blockedAt = DateTime.tryParse(createdAtRaw) ?? blockedAt;
      }

      return BlockedUser(
        userId: blockedId,
        displayName: blockedName,
        avatarUrl: avatarUrl,
        blockedAt: blockedAt,
      );
    }).toList();
  }

  @override
  Future<void> block(String userId, {String source = 'menu'}) async {
    try {
      await _functions.httpsCallable('blockUser').call<dynamic>({
        'userId': userId,
        'source': source,
      });
    } catch (e) {
      throw mapFunctionsError(e);
    }
  }

  @override
  Future<void> unblock(String userId) async {
    try {
      await _functions.httpsCallable('unblockUser').call<dynamic>({
        'userId': userId,
      });
    } catch (e) {
      throw mapFunctionsError(e);
    }
  }

  @override
  Future<ReportResult> report(ReportDraft draft) async {
    try {
      final payload = <String, dynamic>{
        'targetType': draft.target.type.name,
        'targetId': draft.target.id,
        'reason': draft.reason.code,
      };
      if (draft.target.chatId != null) {
        payload['chatId'] = draft.target.chatId;
      }
      final trimmed = draft.text?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        payload['text'] = trimmed;
      }
      if (draft.block) {
        payload['block'] = true;
      }

      final res = await _functions
          .httpsCallable('submitReport')
          .call<Map<String, dynamic>>(payload);

      final data = res.data;
      return ReportResult(
        reportId: data['reportId'] as String? ?? '',
        duplicate: data['duplicate'] as bool? ?? false,
        blocked: data['blocked'] as bool? ?? false,
      );
    } catch (e) {
      throw mapFunctionsError(e);
    }
  }
}

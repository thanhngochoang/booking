import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:photobooking/data/account/account_repository.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class FirebaseAccountRepository implements AccountRepository {
  FirebaseAccountRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
    MediaUrlResolver? urlResolver,
  })  : _db = db ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
        _urlResolver = urlResolver ?? FakeMediaUrlResolver();

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final MediaUrlResolver _urlResolver;

  AccountException _mapError(Object e) {
    if (e is FirebaseFunctionsException) {
      final detailsCode = e.details is Map ? (e.details as Map)['code'] as String? : null;
      return AccountException(detailsCode ?? e.code);
    }
    return AccountException(e.toString());
  }

  @override
  Future<List<DeletionBlocker>> deletionBlockers() async {
    try {
      final res = await _functions.httpsCallable('getAccountDeletionBlockers').call<Map<String, dynamic>>({});
      final list = (res.data['blockers'] as List?) ?? [];
      return [
        for (final item in list)
          if (item is Map) DeletionBlocker.fromJson(Map<String, dynamic>.from(item))
      ].whereType<DeletionBlocker>().toList();
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<DateTime> requestDeletion() async {
    try {
      final res = await _functions.httpsCallable('requestAccountDeletion').call<Map<String, dynamic>>({});
      final rawDate = res.data['restoreUntil'] as String?;
      if (rawDate == null) throw const AccountException('invalid_response');
      final date = DateTime.tryParse(rawDate);
      if (date == null) throw const AccountException('invalid_date');
      return date;
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> restore() async {
    try {
      await _functions.httpsCallable('restoreAccount').call<Map<String, dynamic>>({});
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Stream<AccountLock?> watchLock(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final d = snap.data();
      if (d == null) return null;
      if (d['accountStatus'] == 'deletion_pending') {
        final rawUntil = d['restoreUntil'];
        DateTime? date;
        if (rawUntil is Timestamp) {
          date = rawUntil.toDate();
        } else if (rawUntil is String) {
          date = DateTime.tryParse(rawUntil);
        }
        if (date != null) return AccountLock(date);
      }
      return null;
    });
  }

  @override
  Future<DataExport> requestExport() async {
    try {
      final res = await _functions.httpsCallable('requestDataExport').call<Map<String, dynamic>>({});
      final exp = DataExport.fromJson(res.data);
      if (exp == null) throw const AccountException('invalid_export_response');
      return exp;
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Stream<DataExport?> watchExport(String uid) {
    return _db.collection('exports').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final d = snap.data();
      if (d == null) return null;
      final path = d['lastPath'] as String?;
      final size = (d['lastSizeBytes'] as num?)?.toInt();
      final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
      final expiresAt = (d['expiresAt'] as Timestamp?)?.toDate();
      if (path != null && size != null && createdAt != null && expiresAt != null) {
        return DataExport(
          path: path,
          sizeBytes: size,
          createdAt: createdAt,
          expiresAt: expiresAt,
        );
      }
      return null;
    });
  }

  @override
  Future<Uri> exportDownloadUrl(String path) async {
    final urlStr = await _urlResolver.downloadUrl(path);
    return Uri.parse(urlStr);
  }

  @override
  Future<void> setHiddenFromDiscovery(String uid, bool hidden) async {
    try {
      await _db.collection('photographers').doc(uid).set(
        {'hiddenFromDiscovery': hidden},
        SetOptions(merge: true),
      );
    } catch (e) {
      throw AccountException(e.toString());
    }
  }
}

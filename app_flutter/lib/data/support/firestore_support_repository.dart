import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/support/support_repository.dart';
import 'package:photobooking/data/support/support_thread.dart';

class FirestoreSupportRepository implements SupportRepository {
  FirestoreSupportRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestoreOverride = firestore,
       _functionsOverride = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  @override
  String helpThreadIdFor(String uid) => 'help_$uid';

  @override
  Stream<SupportThread?> watchThread(String threadId) {
    return _firestore
        .collection('support_threads')
        .doc(threadId)
        .snapshots()
        .map((doc) => doc.exists ? SupportThread.fromFirestore(doc) : null);
  }

  @override
  Stream<List<SupportMessage>> watchMessages(
    String threadId, {
    int limit = 30,
  }) {
    return _firestore
        .collection('support_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => SupportMessage.fromFirestore(d))
              .toList();
          return list.reversed.toList();
        });
  }

  @override
  Future<String> send({
    String? threadId,
    required String text,
    required String clientId,
  }) async {
    try {
      final res = await _functions
          .httpsCallable(
            'sendSupportMessage',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Map<String, dynamic>>({
            'threadId': threadId,
            'text': text,
            'clientId': clientId,
          });

      final data = res.data;
      final returnedThreadId = data['threadId'] as String?;
      return returnedThreadId ?? threadId ?? '';
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (details is Map && details['code'] is String) {
        throw SupportError(details['code'] as String);
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const SupportError('network');
      }
      throw SupportError(e.message ?? e.code);
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/safety/firestore_safety_repository.dart';
import 'package:photobooking/data/safety/safety.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Map<String, dynamic>> {}

void main() {
  group('FirestoreSafetyRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFunctions mockFunctions;
    late _MockCallable mockCallable;
    late _MockResult mockResult;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockFunctions = _MockFunctions();
      mockCallable = _MockCallable();
      mockResult = _MockResult();

      when(() => mockFunctions.httpsCallable(any())).thenReturn(mockCallable);
    });

    test('watchIndex emits an empty index for a missing document and for signed-out', () async {
      final signedOutRepo = FirestoreSafetyRepository(
        uid: null,
        firestore: fakeFirestore,
        functions: mockFunctions,
      );
      final initialSignedOut = await signedOutRepo.watchIndex().first;
      expect(initialSignedOut.hidden, isEmpty);

      final signedInRepo = FirestoreSafetyRepository(
        uid: 'user_1',
        firestore: fakeFirestore,
        functions: mockFunctions,
      );
      final initialMissing = await signedInRepo.watchIndex().first;
      expect(initialMissing.hidden, isEmpty);

      // Now create doc and verify stream emission
      await fakeFirestore
          .collection('users')
          .doc('user_1')
          .collection('private')
          .doc('blocks')
          .set({
        'blockedIds': ['user_2'],
        'blockedByIds': ['user_3'],
      });

      final updated = await signedInRepo.watchIndex().firstWhere((i) => i.hidden.isNotEmpty);
      expect(updated.blockedIds, {'user_2'});
      expect(updated.blockedByIds, {'user_3'});
      expect(updated.hidden, {'user_2', 'user_3'});
    });

    test('blocked() maps name, avatar and blockedAt', () async {
      final now = DateTime(2026, 10, 7, 10, 0);
      await fakeFirestore.collection('blocks').doc('user_1_user_2').set({
        'blockerId': 'user_1',
        'blockedId': 'user_2',
        'blockedName': 'Minh Trí',
        'blockedAvatarUrl': 'https://seed.test/avatar.jpg',
        'source': 'menu',
        'createdAt': Timestamp.fromDate(now),
      });

      final repo = FirestoreSafetyRepository(
        uid: 'user_1',
        firestore: fakeFirestore,
        functions: mockFunctions,
      );

      final list = await repo.blocked();
      expect(list.length, 1);
      final user = list.first;
      expect(user.userId, 'user_2');
      expect(user.displayName, 'Minh Trí');
      expect(user.avatarUrl, 'https://seed.test/avatar.jpg');
      expect(user.blockedAt, now);
    });

    test('report() sends targetType, targetId, chatId, reason code, trimmed text and block', () async {
      when(() => mockCallable.call<Map<String, dynamic>>(any())).thenAnswer((inv) async {
        final Map<dynamic, dynamic> args = inv.positionalArguments.first as Map<dynamic, dynamic>;
        expect(args['targetType'], 'message');
        expect(args['targetId'], 'msg_1');
        expect(args['chatId'], 'chat_1');
        expect(args['reason'], 'inappropriate');
        expect(args['text'], 'Nội dung bậy');
        expect(args['block'], isTrue);

        when(() => mockResult.data).thenReturn({
          'reportId': 'rep_123',
          'duplicate': false,
          'blocked': true,
        });
        return mockResult;
      });

      final repo = FirestoreSafetyRepository(
        uid: 'user_1',
        firestore: fakeFirestore,
        functions: mockFunctions,
      );

      final res = await repo.report(const ReportDraft(
        target: ReportTarget(
          type: ReportTargetType.message,
          id: 'msg_1',
          chatId: 'chat_1',
          ownerId: 'user_2',
        ),
        reason: ReportReason.inappropriate,
        text: '  Nội dung bậy  ',
        block: true,
      ));

      expect(res.reportId, 'rep_123');
      expect(res.duplicate, isFalse);
      expect(res.blocked, isTrue);
    });

    test('report() maps limit_exceeded to SafetyError(limit_exceeded)', () async {
      when(() => mockCallable.call<Map<String, dynamic>>(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'quota exceeded',
          details: {'code': 'limit_exceeded'},
        ),
      );

      final repo = FirestoreSafetyRepository(
        uid: 'user_1',
        firestore: fakeFirestore,
        functions: mockFunctions,
      );

      expect(
        () => repo.report(const ReportDraft(
          target: ReportTarget(
            type: ReportTargetType.user,
            id: 'user_2',
          ),
          reason: ReportReason.spam,
        )),
        throwsA(isA<SafetyError>().having((e) => e.code, 'code', 'limit_exceeded')),
      );
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/collab/collaboration.dart';
import 'package:photobooking/data/collab/firestore_collab_repository.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';

import 'collab_mapping_test.dart' show collabJobDoc, collaborationDoc;

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreCollabRepository repo;

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreCollabRepository(firestore: db, functions: functions);
  });

  void answer(Object? data) {
    final res = _MockResult();
    when(() => res.data).thenReturn(data);
    when(() => callable.call<Object?>(any())).thenAnswer((_) async => res);
  }

  Map<dynamic, dynamic> sent(String name) {
    verify(() => functions.httpsCallable(name, options: any(named: 'options')))
        .called(1);
    return verify(() => callable.call<Object?>(captureAny())).captured.last
        as Map;
  }

  test(
    'watchAsStudio / watchAsCollaborator list invited and active only',
    () async {
      final col = db.collection('studio_collaborations');
      await col.doc('cuc_dung').set(collaborationDoc());
      await col.doc('cuc_hoa').set({
        ...collaborationDoc(status: 'invited'),
        'collaboratorId': 'hoa',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 12)),
      });
      await col.doc('cuc_an').set({
        ...collaborationDoc(status: 'ended'),
        'collaboratorId': 'an',
      });
      final studio = await repo.watchAsStudio('cuc').first;
      expect(studio.map((c) => c.id), ['cuc_hoa', 'cuc_dung']);
      final mine = await repo.watchAsCollaborator('dung').first;
      expect(mine.map((c) => c.id), ['cuc_dung']);
    },
  );

  test('pairsOf returns the studio\'s latest relationship with each id, '
      'whatever its status (S26.02-collab)', () async {
    final col = db.collection('studio_collaborations');
    await col.doc('cuc_dung').set(collaborationDoc());
    await col.doc('cuc_an').set({
      ...collaborationDoc(status: 'ended'),
      'collaboratorId': 'an',
    });
    await col.doc('gio_hoa').set({
      ...collaborationDoc(),
      'studioId': 'gio',
      'collaboratorId': 'hoa',
    });
    final pairs = await repo.pairsOf('cuc', ['an', 'dung', 'hoa', 'zz']);
    expect({for (final p in pairs) p.id: p.status}, {
      'cuc_dung': CollabStatus.active,
      'cuc_an': CollabStatus.ended,
    });
  });

  test('watchJobs lists a party\'s jobs newest first', () async {
    final col = db.collection('collab_jobs');
    await col.doc('b1_dung').set(collabJobDoc());
    await col.doc('b2_dung').set({
      ...collabJobDoc(bookingId: 'b2'),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20)),
    });
    expect((await repo.watchJobsAsStudio('cuc').first).map((j) => j.id), [
      'b2_dung',
      'b1_dung',
    ]);
    expect((await repo.watchJobsAsCollaborator('dung').first).length, 2);
    expect(await repo.watchJobsAsCollaborator('hoa').first, isEmpty);
  });

  test('jobsDueInMonth takes pay.dueAt within the VN month', () async {
    final col = db.collection('collab_jobs');
    // 30/9 23:30 in Vietnam: September.
    await col
        .doc('sep_dung')
        .set(
          collabJobDoc(
            bookingId: 'sep',
            dueAt: Timestamp.fromDate(DateTime.utc(2026, 9, 30, 16, 30)),
          ),
        );
    // 1/10 00:30 in Vietnam: October.
    await col
        .doc('oct1_dung')
        .set(
          collabJobDoc(
            bookingId: 'oct1',
            dueAt: Timestamp.fromDate(DateTime.utc(2026, 9, 30, 17, 30)),
          ),
        );
    await col
        .doc('oct2_dung')
        .set(
          collabJobDoc(
            bookingId: 'oct2',
            dueAt: Timestamp.fromDate(DateTime.utc(2026, 10, 31, 16, 59)),
          ),
        );
    // 1/11 00:00 in Vietnam: November.
    await col
        .doc('nov_dung')
        .set(
          collabJobDoc(
            bookingId: 'nov',
            dueAt: Timestamp.fromDate(DateTime.utc(2026, 10, 31, 17)),
          ),
        );
    final oct = await repo.jobsDueInMonth('cuc', 2026, 10);
    expect(oct.map((j) => j.bookingId), ['oct1', 'oct2']);
  });

  group('callables', () {
    test('invite, cancel, respond, end and default fee', () async {
      answer({});
      await repo.invite('hoa', defaultFee: 500000);
      expect(sent('inviteCollaborator'), {
        'collaboratorId': 'hoa',
        'defaultFee': 500000,
      });
      await repo.invite('an');
      expect(sent('inviteCollaborator'), {'collaboratorId': 'an'});
      await repo.cancelInvite('hoa');
      expect(sent('cancelCollabInvite'), {'collaboratorId': 'hoa'});
      answer({'status': 'active'});
      await repo.respondInvite('cuc', accept: true, acceptTerms: true);
      expect(sent('respondCollabInvite'), {
        'studioId': 'cuc',
        'accept': true,
        'acceptTerms': true,
      });
      answer({});
      await repo.end(collaboratorId: 'dung');
      expect(sent('endCollaboration'), {'collaboratorId': 'dung'});
      await repo.end(studioId: 'cuc');
      expect(sent('endCollaboration'), {'studioId': 'cuc'});
      await repo.setDefaultFee('dung', null);
      expect(sent('setCollabDefaultFee'), {
        'collaboratorId': 'dung',
        'defaultFee': null,
      });
    });

    test('respondOffer returns the offer status', () async {
      answer({'offerStatus': 'declined'});
      expect(
        await repo.respondOffer('b1', accept: false),
        OfferStatus.declined,
      );
      expect(sent('respondCollabOffer'), {'bookingId': 'b1', 'accept': false});
    });

    test('reportPaid sends the VN calendar day and the method code', () async {
      answer({});
      await repo.reportPaid(
        'b1',
        'dung',
        paidOn: DateTime(2026, 10, 9),
        method: CollabPayMethod.cash,
      );
      expect(sent('reportCollabPaid'), {
        'bookingId': 'b1',
        'collaboratorId': 'dung',
        'paidOn': '2026-10-09',
        'method': 'cash',
      });
      await repo.confirmPay('b1', received: true);
      expect(sent('confirmCollabPay'), {'bookingId': 'b1', 'received': true});
    });

    test('openChat returns the chat id', () async {
      answer({'chatId': 'collab_cuc_dung'});
      expect(await repo.openChat(collaboratorId: 'dung'), 'collab_cuc_dung');
      expect(sent('openCollabChat'), {'collaboratorId': 'dung'});
    });

    test('a refusal becomes RecruitError', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'x',
          code: 'failed-precondition',
          details: {'code': 'member_busy'},
        ),
      );
      await expectLater(
        repo.end(collaboratorId: 'dung'),
        throwsA(
          isA<RecruitError>().having(
            (e) => e.code,
            'code',
            RecruitErrorCode.memberBusy,
          ),
        ),
      );
    });
  });
}

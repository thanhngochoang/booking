import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/award/firestore_award_repository.dart';
import 'package:photobooking/data/content/provider_type.dart';

import '../../support/content_fixtures.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> awardDoc({
  String photographerId = 'p1',
  String competition = 'Sony World Photography Awards',
  int year = 2025,
  String? category,
  Object? result = 'gold',
  Object? status = 'approved',
  String? reviewNote,
  DateTime? createdAt,
}) => {
  'photographerId': photographerId,
  'competition': competition,
  'year': year,
  'category': ?category,
  'result': result,
  'status': status,
  'reviewNote': ?reviewNote,
  'createdAt': Timestamp.fromDate(createdAt ?? fixtureNow),
  'updatedAt': Timestamp.fromDate(createdAt ?? fixtureNow),
};

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreAwardRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreAwardRepository(db: db, functions: functions);
  });

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  test('an award doc parses its status and result', () async {
    await db
        .collection('awards')
        .doc('a1')
        .set(
          awardDoc(
            category: 'Open',
            result: 'finalist',
            status: 'needs_info',
            reviewNote: 'Thiếu minh chứng',
          ),
        );
    final list = await repo.watchMine('p1').first;
    final a = list.single;
    expect(a.id, 'a1');
    expect(a.result, AwardResult.finalist);
    expect(a.status, AwardStatus.needsInfo);
    expect(a.category, 'Open');
    expect(a.reviewNote, 'Thiếu minh chứng');
    expect(a.year, 2025);
    expect(a.createdAt, fixtureNow);
    expect(
      a,
      fixtureAward(
        'a1',
        category: 'Open',
        result: AwardResult.finalist,
        status: AwardStatus.needsInfo,
        reviewNote: 'Thiếu minh chứng',
      ),
    );
  });

  test('an unknown status reads as pending', () async {
    await db.collection('awards').doc('a1').set(awardDoc(status: 'weird'));
    final a = (await repo.watchMine('p1').first).single;
    expect(a.status, AwardStatus.pending);
  });

  test('an unknown result skips the doc', () async {
    await db.collection('awards').doc('a1').set(awardDoc(result: 'platinum'));
    await db.collection('awards').doc('a2').set(awardDoc());
    final list = await repo.watchMine('p1').first;
    expect(list.map((a) => a.id), ['a2']);
  });

  test('watchApproved asks only approved awards newest year first', () async {
    await db.collection('awards').doc('old').set(awardDoc(year: 2023));
    await db
        .collection('awards')
        .doc('new')
        .set(awardDoc(year: 2025, createdAt: DateTime.utc(2026, 1, 1)));
    await db
        .collection('awards')
        .doc('new2')
        .set(awardDoc(year: 2025, createdAt: DateTime.utc(2026, 2, 1)));
    await db
        .collection('awards')
        .doc('pend')
        .set(awardDoc(year: 2026, status: 'pending'));
    await db
        .collection('awards')
        .doc('other')
        .set(awardDoc(year: 2026, photographerId: 'p2'));
    final list = await repo.watchApproved('p1').first;
    expect(list.map((a) => a.id), ['new2', 'new', 'old']);
  });

  test('watchMine lists every status newest first', () async {
    await db.collection('awards').doc('a').set(awardDoc());
    await db
        .collection('awards')
        .doc('b')
        .set(
          awardDoc(status: 'rejected', createdAt: DateTime.utc(2026, 11, 1)),
        );
    final list = await repo.watchMine('p1').first;
    expect(list.map((a) => a.id), ['b', 'a']);
  });

  test('proofPath builds the storage path', () {
    expect(repo.proofPath('u1', 'a1', '01HZX'), 'awardProofs/u1/a1/01HZX.jpg');
  });

  test('loadDraft joins the award and its proof doc', () async {
    await db.collection('awards').doc('a1').set(awardDoc(category: 'Open'));
    await db.collection('awardProofs').doc('a1').set({
      'photographerId': 'p1',
      'files': [
        {'storagePath': 'awardProofs/p1/a1/0.jpg'},
      ],
      'links': ['https://x.test/a'],
    });
    final d = (await repo.loadDraft('a1'))!;
    expect(d.awardId, 'a1');
    expect(d.competition, 'Sony World Photography Awards');
    expect(d.category, 'Open');
    expect(d.proofPaths, ['awardProofs/p1/a1/0.jpg']);
    expect(d.proofLinks, ['https://x.test/a']);
    expect(await repo.loadDraft('missing'), isNull);
  });

  group('callables', () {
    test('create sends paths and links', () async {
      final res = _MockResult();
      when(() => res.data).thenReturn({'awardId': 'a1'});
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => res);
      await repo.create(
        const AwardDraft(
          awardId: 'a1',
          competition: 'Sony',
          year: 2025,
          category: 'Open',
          result: AwardResult.silver,
          workPostId: 'w1',
          proofPaths: ['awardProofs/p1/a1/0.jpg'],
          proofLinks: ['https://x.test/a'],
        ),
      );
      verify(
        () => functions.httpsCallable(
          'createAward',
          options: any(named: 'options'),
        ),
      ).called(1);
      final sent =
          verify(() => callable.call<Object?>(captureAny())).captured.single
              as Map;
      expect(sent, {
        'awardId': 'a1',
        'competition': 'Sony',
        'year': 2025,
        'category': 'Open',
        'result': 'silver',
        'workPostId': 'w1',
        'proofFiles': ['awardProofs/p1/a1/0.jpg'],
        'proofLinks': ['https://x.test/a'],
      });
    });

    test('update and delete call their callables', () async {
      final res = _MockResult();
      when(() => res.data).thenReturn({});
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => res);
      await repo.update(
        const AwardDraft(
          awardId: 'a1',
          competition: 'Sony',
          year: 2025,
          result: AwardResult.gold,
        ),
      );
      await repo.delete('a1');
      verify(
        () => functions.httpsCallable(
          'updateAward',
          options: any(named: 'options'),
        ),
      ).called(1);
      verify(
        () => functions.httpsCallable(
          'deleteAward',
          options: any(named: 'options'),
        ),
      ).called(1);
    });

    test('limit_exceeded becomes AwardError', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'x',
          code: 'resource-exhausted',
          details: {'code': 'limit_exceeded'},
        ),
      );
      await expectLater(
        repo.delete('a1'),
        throwsA(
          isA<AwardError>().having((e) => e.code, 'code', 'limit_exceeded'),
        ),
      );
    });
  });

  test('watchTier reads the tier fields of photographers/{uid}', () async {
    await db.collection('photographers').doc('p1').set({
      'providerType': 'artist',
      'approvedAwardCount': 3,
      'artistSince': Timestamp.fromDate(DateTime.utc(2026, 10, 5)),
    });
    final t = (await repo.watchTier('p1').first)!;
    expect(t.providerType, ProviderType.artist);
    expect(t.approvedCount, 3);
    expect(t.artistSince, DateTime.utc(2026, 10, 5));
    expect(await repo.watchTier('nobody').first, isNull);
    await db.collection('photographers').doc('p2').set({});
    final plain = (await repo.watchTier('p2').first)!;
    expect(plain.providerType, ProviderType.individual);
    expect(plain.approvedCount, 0);
    expect(plain.artistSince, isNull);
  });

  test('the fake tier follows the approved awards until it is set', () async {
    final fake = FakeAwardRepository(
      awards: [
        for (final id in ['a', 'b', 'c']) fixtureAward(id),
      ],
    );
    final t = (await fake.watchTier('p1').first)!;
    expect(t.providerType, ProviderType.artist);
    expect(t.approvedCount, 3);
    fake.setTier(const AwardTier(approvedCount: 1));
    expect(
      (await fake.watchTier('p1').first)!.providerType,
      ProviderType.individual,
    );
  });

  test('the fake repository filters by owner', () async {
    final fake = FakeAwardRepository(
      awards: [
        fixtureAward('a'),
        fixtureAward('b', status: AwardStatus.pending),
        fixtureAward('c', photographerId: 'p2'),
      ],
    );
    expect((await fake.watchMine('p1').first).map((a) => a.id), ['a', 'b']);
    expect((await fake.watchApproved('p1').first).map((a) => a.id), ['a']);
  });

  group('FakeAwardRepository', () {
    const draft = AwardDraft(
      awardId: 'n1',
      competition: 'Giải mới',
      year: 2025,
      result: AwardResult.gold,
    );

    test('a created award appears first in watchMine for its owner', () async {
      final fake = FakeAwardRepository(uid: 'p1', awards: [fixtureAward('a')]);
      await fake.create(draft);
      final list = await fake.watchMine('p1').first;
      expect(list.first.id, 'n1');
      expect(list.first.photographerId, 'p1');
      expect(list.first.status, AwardStatus.pending);
    });

    test('update replaces the fields and re-queues the award', () async {
      final fake = FakeAwardRepository(awards: [fixtureAward('a')]);
      await fake.update(
        const AwardDraft(
          awardId: 'a',
          competition: 'Đổi tên',
          year: 2024,
          result: AwardResult.silver,
        ),
      );
      final a = (await fake.watchMine('p1').first).single;
      expect(a.competition, 'Đổi tên');
      expect(a.result, AwardResult.silver);
      expect(a.status, AwardStatus.pending);
    });
  });
}

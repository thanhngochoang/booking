import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/recruit/firestore_recruit_repository.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';

import 'recruit_mapping_test.dart' show applicationDoc, postDoc;

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Future<void> _post(
  FakeFirebaseFirestore db,
  String id, {
  String studioId = 'cuc',
  String status = 'open',
  List<String> filterKeys = const ['k=collaborator', 'a=hcm-q1'],
  required DateTime createdAt,
}) => db.collection('recruitPosts').doc(id).set({
  ...postDoc(status: status),
  'studioId': studioId,
  'filterKeys': filterKeys,
  'createdAt': Timestamp.fromDate(createdAt),
});

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreRecruitRepository repo;

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
    repo = FirestoreRecruitRepository(firestore: db, functions: functions);
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

  group('list', () {
    test('open posts newest first; pages with the last document', () async {
      for (var i = 0; i < 3; i++) {
        await _post(db, 'p$i', createdAt: DateTime.utc(2026, 10, 10 + i));
      }
      await _post(
        db,
        'closed',
        status: 'closed',
        createdAt: DateTime.utc(2026, 10, 20),
      );
      final first = await repo.list(const RecruitFilter(), limit: 2);
      expect(first.items.map((p) => p.id), ['p2', 'p1']);
      expect(first.next, isNotNull);
      final second = await repo.list(
        const RecruitFilter(),
        after: first.next,
        limit: 2,
      );
      expect(second.items.map((p) => p.id), ['p0']);
      expect(second.next, isNull, reason: 'fewer than the limit: last page');
    });

    test('a filter is one array-contains on filterKeys', () async {
      await _post(
        db,
        'match',
        filterKeys: ['k=member|a=hue'],
        createdAt: DateTime.utc(2026, 10, 10),
      );
      await _post(
        db,
        'other',
        filterKeys: ['k=member'],
        createdAt: DateTime.utc(2026, 10, 11),
      );
      final page = await repo.list(
        const RecruitFilter(kind: RecruitKind.member, area: 'hue'),
      );
      expect(page.items.map((p) => p.id), ['match']);
    });

    test('studioId lists that studio\'s open posts', () async {
      await _post(db, 'a', createdAt: DateTime.utc(2026, 10, 10));
      await _post(
        db,
        'b',
        studioId: 'other',
        createdAt: DateTime.utc(2026, 10, 11),
      );
      final page = await repo.list(const RecruitFilter(studioId: 'cuc'));
      expect(page.items.map((p) => p.id), ['a']);
    });
  });

  test('get returns the post or null', () async {
    await _post(db, 'a', createdAt: DateTime.utc(2026, 10, 10));
    expect((await repo.get('a'))!.id, 'a');
    expect(await repo.get('missing'), isNull);
  });

  test('openCountOf counts the studio\'s open posts', () async {
    await _post(db, 'a', createdAt: DateTime.utc(2026, 10, 10));
    await _post(db, 'b', createdAt: DateTime.utc(2026, 10, 11));
    await _post(
      db,
      'c',
      status: 'expired',
      createdAt: DateTime.utc(2026, 10, 12),
    );
    expect(await repo.openCountOf('cuc'), 2);
    expect(await repo.openCountOf('nobody'), 0);
  });

  test('watchStudioPosts lists every status newest first', () async {
    await _post(db, 'a', createdAt: DateTime.utc(2026, 10, 10));
    await _post(
      db,
      'b',
      status: 'closed',
      createdAt: DateTime.utc(2026, 10, 11),
    );
    final list = await repo.watchStudioPosts('cuc').first;
    expect(list.map((p) => p.id), ['b', 'a']);
  });

  test('applicantsOf lists applied applications of one post', () async {
    final apps = db.collection('recruitApplications');
    await apps.doc('post1_hoa').set(applicationDoc());
    await apps.doc('post1_an').set({
      ...applicationDoc(status: 'declined'),
      'applicantId': 'an',
    });
    await apps.doc('post2_x').set({
      ...applicationDoc(),
      'postId': 'post2',
      'applicantId': 'x',
    });
    final list = await repo.applicantsOf('cuc', 'post1');
    expect(list.map((a) => a.id), ['post1_hoa']);
  });

  test('watchMyApplication finds the caller\'s application or null', () async {
    expect(await repo.watchMyApplication('post1', 'hoa').first, isNull);
    await db
        .collection('recruitApplications')
        .doc('post1_hoa')
        .set(applicationDoc());
    final a = await repo.watchMyApplication('post1', 'hoa').first;
    expect(a!.status, ApplicationStatus.applied);
  });

  test('watchCounters reads private/recruit; missing is zeros', () async {
    expect((await repo.watchCounters('cuc').first).openPostCount, 0);
    await db.doc('photographers/cuc/private/recruit').set({'openPostCount': 2});
    expect((await repo.watchCounters('cuc').first).openPostCount, 2);
  });

  test('watchMyProviderFacts joins users.role and photographers', () async {
    expect(await repo.watchMyProviderFacts('cuc').first, isNull);
    await db.doc('users/cuc').set({'role': 'photographer'});
    await db.doc('photographers/cuc').set({
      'providerType': 'studio',
      'acceptingOrders': true,
      'recruitMatchKeys': <String>[],
    });
    final f = (await repo
        .watchMyProviderFacts('cuc')
        .firstWhere((f) => f != null))!;
    expect(f.isProviderAccount, isTrue);
    expect(f.isStudio, isTrue);
    expect(f.acceptingOrders, isTrue);
  });

  group('callables', () {
    test('create sends the draft and returns postId', () async {
      answer({'postId': 'new1'});
      final id = await repo.create(
        const RecruitDraft(
          kind: RecruitKind.collaborator,
          title: 'Tuyển CTV chụp cưới',
          specialties: ['wedding'],
          areas: ['hcm-q1'],
          frequency: RecruitFrequency.weekly,
          fee: PerShootFee(800000),
          requirements: 'Có máy',
        ),
      );
      expect(id, 'new1');
      expect(sent('createRecruitPost'), {
        'kind': 'collaborator',
        'title': 'Tuyển CTV chụp cưới',
        'specialties': ['wedding'],
        'areas': ['hcm-q1'],
        'frequency': 'weekly',
        'feeHint': {'type': 'per_shoot', 'amount': 800000},
        'requirements': 'Có máy',
      });
    });

    test('update leaves kind out; negotiable fee has no amount', () async {
      answer({});
      await repo.update(
        'p1',
        const RecruitDraft(
          kind: RecruitKind.member,
          title: 'Tuyển thợ vào studio',
          specialties: ['portrait'],
          areas: ['hue'],
          frequency: RecruitFrequency.seasonal,
          fee: NegotiableFee(),
          requirements: '',
        ),
      );
      expect(sent('updateRecruitPost'), {
        'postId': 'p1',
        'title': 'Tuyển thợ vào studio',
        'specialties': ['portrait'],
        'areas': ['hue'],
        'frequency': 'seasonal',
        'feeHint': {'type': 'negotiable'},
        'requirements': '',
      });
    });

    test('close, withdraw, apply and respond send their inputs', () async {
      answer({});
      await repo.close('p1');
      expect(sent('closeRecruitPost'), {'postId': 'p1'});
      await repo.withdraw('p1');
      expect(sent('withdrawRecruitApplication'), {'postId': 'p1'});
      answer({'applicationId': 'p1_hoa'});
      await repo.apply(
        'p1',
        message: 'Xin chào',
        samplePostIds: ['s1'],
        acceptTerms: true,
      );
      expect(sent('applyToRecruitPost'), {
        'postId': 'p1',
        'message': 'Xin chào',
        'samplePostIds': ['s1'],
        'acceptTerms': true,
      });
      answer({'status': 'accepted'});
      await repo.respond('p1', 'hoa', accept: true);
      expect(sent('respondRecruitApplication'), {
        'postId': 'p1',
        'applicantId': 'hoa',
        'accept': true,
      });
    });

    test('renew returns the new expiry', () async {
      answer({'expiresAt': '2026-12-19T03:00:00.000Z'});
      expect(await repo.renew('p1'), DateTime.utc(2026, 12, 19, 3));
    });

    test('a refusal becomes RecruitError with the field', () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'x',
          code: 'invalid-argument',
          details: {'code': 'invalid_argument', 'field': 'title.contact'},
        ),
      );
      await expectLater(
        repo.close('p1'),
        throwsA(
          isA<RecruitError>()
              .having((e) => e.code, 'code', RecruitErrorCode.invalidArgument)
              .having((e) => e.field, 'field', 'title.contact'),
        ),
      );
    });
  });
}

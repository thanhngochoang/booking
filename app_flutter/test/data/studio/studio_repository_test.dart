import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/studio/firestore_studio_repository.dart';
import 'package:photobooking/data/studio/studio_repository.dart';

import '../../support/studio_world.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Map<String, dynamic> _relation(
  String studioId,
  String memberId,
  String status,
  DateTime createdAt,
) => {
  'studioId': studioId,
  'memberId': memberId,
  'status': status,
  'initiatedBy': 'studio',
  'createdAt': Timestamp.fromDate(createdAt),
  'expiresAt': Timestamp.fromDate(createdAt.add(const Duration(days: 7))),
  'studioName': 'Studio Cúc',
  'memberName': memberId,
};

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FirestoreStudioRepository repo;
  late List<(String, Object?)> calls;
  Object? answer;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    calls = [];
    answer = const <String, dynamic>{};
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenAnswer((inv) {
      final name = inv.positionalArguments.single as String;
      final c = _MockCallable();
      when(() => c.call<Object?>(any())).thenAnswer((call) async {
        calls.add((name, call.positionalArguments.single));
        final r = _MockResult();
        when(() => r.data).thenReturn(answer);
        return r;
      });
      return c;
    });
    repo = FirestoreStudioRepository(
      firestore: db,
      functions: functions,
      clock: () => DateTime.utc(2026, 10, 21, 3),
    );
  });

  group('listeners', () {
    test('studio relations: open ones of this studio, newest first', () async {
      final col = db.collection('studio_members');
      await col
          .doc('a')
          .set(_relation('cuc', 'an', 'active', DateTime.utc(2026, 9, 1)));
      await col
          .doc('b')
          .set(_relation('cuc', 'binh', 'invited', DateTime.utc(2026, 10, 18)));
      await col
          .doc('c')
          .set(_relation('cuc', 'dung', 'requested', DateTime.utc(2026, 10, 19)));
      await col
          .doc('d')
          .set(_relation('cuc', 'em', 'left', DateTime.utc(2026, 10, 20)));
      await col
          .doc('e')
          .set(_relation('may', 'an', 'invited', DateTime.utc(2026, 10, 20)));

      final list = await repo.watchStudioRelations('cuc').first;
      expect(list.map((r) => r.id), ['c', 'b', 'a']);
    });

    test('member relations: open ones of this member', () async {
      final col = db.collection('studio_members');
      await col
          .doc('a')
          .set(_relation('cuc', 'an', 'active', DateTime.utc(2026, 9, 1)));
      await col
          .doc('b')
          .set(_relation('may', 'an', 'invited', DateTime.utc(2026, 10, 18)));
      await col
          .doc('c')
          .set(_relation('lan', 'an', 'declined', DateTime.utc(2026, 10, 19)));
      final list = await repo.watchMemberRelations('an').first;
      expect(list.map((r) => r.id), ['b', 'a']);
    });

    test('quota reads studio_quota/{uid} for the side asked', () async {
      await db.collection('studio_quota').doc('cuc').set({
        'dayKey': '2026-10-21',
        'studioActions': 2,
        'memberActions': 0,
      });
      expect(
        await repo.watchQuota('cuc', studio: true).first,
        const StudioQuota(left: 3, max: 5),
      );
      expect(
        await repo.watchQuota('nobody', studio: false).first,
        const StudioQuota(left: 3, max: 3),
      );
    });
  });

  group('callables', () {
    test('membership callables send the documented payloads', () async {
      answer = {'relationId': 'r1'};
      expect(await repo.invite('binh'), 'r1');
      expect(await repo.requestToJoin('cuc'), 'r1');
      answer = {'status': 'active'};
      await repo.cancelInvite('r1');
      await repo.cancelJoinRequest('r2');
      await repo.respondInvite('r3', accept: true);
      await repo.respondJoinRequest('r4', accept: false);
      await repo.leave();
      await repo.remove('an');
      expect(calls.map((c) => c.$1), [
        'inviteMember',
        'requestToJoin',
        'cancelInvite',
        'cancelJoinRequest',
        'respondInvite',
        'respondJoinRequest',
        'leaveStudio',
        'removeMember',
      ]);
      expect(calls.map((c) => c.$2), [
        {'memberId': 'binh'},
        {'studioId': 'cuc'},
        {'relationId': 'r1'},
        {'relationId': 'r2'},
        {'relationId': 'r3', 'accept': true},
        {'relationId': 'r4', 'accept': false},
        <String, dynamic>{},
        {'memberId': 'an'},
      ]);
    });

    test('search sends the query and maps the rows', () async {
      answer = {
        'rows': [
          {'uid': 'binh', 'name': 'Bình', 'verified': true, 'state': 'invitable'},
          {'uid': 'x', 'state': 'weird'},
        ],
      };
      final rows = await repo.search('bi');
      expect(calls.single.$1, 'searchPhotographersToInvite');
      expect(calls.single.$2, {'query': 'bi'});
      expect(rows.map((r) => (r.uid, r.state)), [
        ('binh', InviteState.invitable),
      ]);
    });

    test('assignment options carry the deadline and the members', () async {
      answer = {
        'deadline': '2026-10-23T08:00:00.000Z',
        'options': [
          {'uid': 'an', 'name': 'An', 'state': 'free', 'reviewCount': 0},
          {
            'uid': 'binh',
            'name': 'Bình',
            'state': 'busy',
            'busyStart': '15:00',
            'busyEnd': '18:00',
          },
        ],
      };
      final r = await repo.assignmentOptions('b1');
      expect(calls.single.$1, 'assignmentOptions');
      expect(calls.single.$2, {'bookingId': 'b1'});
      expect(r.deadline, DateTime.utc(2026, 10, 23, 8));
      expect(r.options.map((o) => o.state), [AssignState.free, AssignState.busy]);
    });

    test('StudioError carries the server code', () async {
      when(
        () => functions.httpsCallable(any(), options: any(named: 'options')),
      ).thenReturn(callable);
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'studio_full',
          details: {'code': 'studio_full'},
        ),
      );
      await expectLater(
        repo.invite('binh'),
        throwsA(isA<StudioError>().having((e) => e.code, 'code', 'studio_full')),
      );

      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(code: 'unavailable', message: 'down'),
      );
      await expectLater(
        repo.leave(),
        throwsA(isA<StudioError>().having((e) => e.code, 'code', 'unavailable')),
      );
    });
  });

  group('FakeStudioRepository', () {
    test('records calls, emits relations and throws the next error', () async {
      final fake = FakeStudioRepository()
        ..seedRelation(
          makeRelation(id: 'r1', status: RelationStatus.invited),
        );
      final seen = <List<StudioRelation>>[];
      final sub = fake.watchMemberRelations('an').listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.map((r) => r.id), ['r1']);

      await fake.respondInvite('r1', accept: true);
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls.last.$1, 'respondInvite');
      expect(fake.calls.last.$2, {'relationId': 'r1', 'accept': true});
      expect(seen.last.single.status, RelationStatus.active);

      fake.nextError = 'rate_limited';
      await expectLater(
        fake.invite('binh'),
        throwsA(isA<StudioError>().having((e) => e.code, 'code', 'rate_limited')),
      );
      await sub.cancel();
    });
  });
}

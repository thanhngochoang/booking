import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/organizer/firestore_organizer_repository.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_repository.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

Timestamp _ts(String iso) => Timestamp.fromDate(DateTime.parse(iso));

void main() {
  late FakeFirebaseFirestore db;
  late _MockFunctions functions;
  late _MockCallable callable;
  late FakeMediaUploader uploader;
  late FirestoreOrganizerRepository repo;
  final calls = <(String, Object?)>[];

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    calls.clear();
    db = FakeFirebaseFirestore();
    functions = _MockFunctions();
    callable = _MockCallable();
    uploader = FakeMediaUploader();
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenAnswer((inv) {
          final name = inv.positionalArguments.first as String;
          when(() => callable.call<Object?>(any())).thenAnswer((c) async {
            calls.add((name, c.positionalArguments.first));
            final r = _MockResult();
            when(() => r.data).thenReturn(<String, Object?>{'claimId': 'c1'});
            return r;
          });
          return callable;
        });
    repo = FirestoreOrganizerRepository(
      uid: 'org1',
      uploader: uploader,
      db: db,
      functions: functions,
    );
  });

  void refuse(String code, {String? field}) {
    when(() => callable.call<Object?>(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'failed-precondition',
        message: code,
        details: {'code': code, 'field': ?field},
      ),
    );
    when(() => functions.httpsCallable(any(), options: any(named: 'options')))
        .thenReturn(callable);
  }

  test(
    'becomeOrganizer uploads the avatar and sends name, bio, avatarUrl',
    () async {
      await repo.becomeOrganizer(
        name: 'Bãi đá',
        bio: 'BQL',
        avatar: const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg'),
      );
      expect(uploader.uploaded.single, startsWith('avatars/org1/'));
      expect(calls.single.$1, 'becomeOrganizer');
      final payload = calls.single.$2! as Map;
      expect(payload['name'], 'Bãi đá');
      expect(payload['bio'], 'BQL');
      expect(payload['avatarUrl'], startsWith('https://'));
    },
  );

  test(
    'claimSpot uploads proofs under spot_claims/{uid}/ and sends paths',
    () async {
      final id = await repo.claimSpot(
        spotId: 's1',
        proofs: const [
          PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
          PickedImage(path: '/tmp/2.jpg', name: '2.jpg'),
        ],
        note: 'Hợp đồng',
      );
      expect(id, 'c1');
      expect(uploader.uploaded, hasLength(2));
      final payload = calls.single.$2! as Map;
      expect(calls.single.$1, 'claimSpot');
      expect(payload['spotId'], 's1');
      expect(payload['note'], 'Hợp đồng');
      final paths = (payload['proofPaths'] as List).cast<String>();
      expect(paths, uploader.uploaded);
      expect(paths.every((p) => p.startsWith('spot_claims/org1/')), isTrue);
      // One folder per claim attempt.
      expect(paths.map((p) => p.split('/')[2]).toSet(), hasLength(1));
    },
  );

  test('a proposal claim sends proposal and no spotId', () async {
    await repo.claimSpot(
      proposal: const SpotProposal(name: 'Vườn', address: 'Long Biên'),
      proofs: const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
    );
    final payload = calls.single.$2! as Map;
    expect(payload.containsKey('spotId'), isFalse);
    expect(payload['proposal'], {'name': 'Vườn', 'address': 'Long Biên'});
  });

  test(
    'refusals become OrganizerError with the domain code and field',
    () async {
      refuse('spot_managed');
      await expectLater(
        repo.claimSpot(
          spotId: 's1',
          proofs: const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
        ),
        throwsA(
          isA<OrganizerError>().having((e) => e.code, 'code', 'spot_managed'),
        ),
      );
      refuse('invalid_argument', field: 'name');
      await expectLater(
        repo.becomeOrganizer(name: 'A', bio: ''),
        throwsA(isA<OrganizerError>().having((e) => e.field, 'field', 'name')),
      );
    },
  );

  test(
    'updateManagedSpot uploads a cover under spots/{id}/ with its URL',
    () async {
      await repo.updateManagedSpot(
        's1',
        description: 'Mới',
        cover: const PickedImage(path: '/tmp/c.jpg', name: 'c.jpg'),
        openHours: const OpenHours(start: '07:00', end: '18:00'),
        access: const SpotAccess(
          type: SpotAccessType.ticket,
          fees: [AccessFee(label: 'Người lớn', amountVnd: 70000)],
          note: '',
        ),
      );
      final payload = calls.single.$2! as Map;
      expect(calls.single.$1, 'updateManagedSpot');
      expect(payload['spotId'], 's1');
      expect(payload['description'], 'Mới');
      expect(payload['coverPath'], startsWith('spots/s1/'));
      expect(payload['coverUrl'], contains(payload['coverPath']));
      expect(payload['openHours'], {'start': '07:00', 'end': '18:00'});
      expect((payload['access'] as Map)['type'], 'ticket');
      expect(payload.containsKey('tips'), isFalse);
    },
  );

  test(
    'resident, gate staff and close-day callables send their shapes',
    () async {
      await repo.saveResident(
        's1',
        const Resident(
          providerId: 'p1',
          waivesProvider: true,
          waivesGuests: false,
        ),
      );
      await repo.removeResident('s1', 'p1');
      await repo.inviteGateStaff('+84901234567');
      await repo.respondGateStaff('org2', accept: true);
      await repo.removeGateStaff('u9');
      await repo.closeEntryDay('e1', '2026-11-21');
      expect(calls.map((c) => c.$1), [
        'saveResident',
        'removeResident',
        'inviteGateStaff',
        'respondGateStaff',
        'removeGateStaff',
        'closeEntryDay',
      ]);
      expect(calls[0].$2, {
        'spotId': 's1',
        'providerId': 'p1',
        'waivesProvider': true,
        'waivesGuests': false,
        'maxGuests': null,
        'validUntil': null,
      });
      expect(calls[1].$2, {'spotId': 's1', 'providerId': 'p1'});
      expect(calls[2].$2, {'target': '+84901234567'});
      expect(calls[3].$2, {'organizerId': 'org2', 'accept': true});
      expect(calls[4].$2, {'staffUid': 'u9'});
      expect(calls[5].$2, {'eventId': 'e1', 'day': '2026-11-21'});
    },
  );

  test('watchMine reads organizers/{uid}', () async {
    await db.collection('organizers').doc('org1').set({
      'name': 'Bãi đá',
      'status': 'active',
      'createdAt': _ts('2026-10-20T00:00:00Z'),
    });
    final o = await repo.watchMine().first;
    expect(o!.name, 'Bãi đá');
    expect(await repo.watch('nobody').first, isNull);
  });

  test('watchMyClaims lists my claims, newest first', () async {
    for (final (id, at, org) in [
      ('c1', '2026-10-20T00:00:00Z', 'org1'),
      ('c2', '2026-10-21T00:00:00Z', 'org1'),
      ('c3', '2026-10-22T00:00:00Z', 'other'),
    ]) {
      await db.collection('spot_claims').doc(id).set({
        'spotId': 's1',
        'organizerId': org,
        'status': 'pending',
        'proofPaths': <String>[],
        'createdAt': _ts(at),
      });
    }
    final claims = await repo.watchMyClaims().first;
    expect(claims.map((c) => c.id), ['c2', 'c1']);
  });

  test(
    'watchGateStaff lists my staff; watchMyGateInvites what names me',
    () async {
      await db
          .collection('organizers')
          .doc('org1')
          .collection('gate_staff')
          .doc('u9')
          .set({
            'staffUid': 'u9',
            'organizerId': 'org1',
            'status': 'active',
            'invitedAt': _ts('2026-10-20T00:00:00Z'),
          });
      await db
          .collection('organizers')
          .doc('org2')
          .collection('gate_staff')
          .doc('org1')
          .set({
            'staffUid': 'org1',
            'organizerId': 'org2',
            'status': 'invited',
            'invitedAt': _ts('2026-10-21T00:00:00Z'),
          });
      final staff = await repo.watchGateStaff().first;
      expect(staff.single.staffUid, 'u9');
      final invites = await repo.watchMyGateInvites().first;
      expect(invites.single.organizerId, 'org2');
    },
  );

  test('watchEntryDay reads entry_days/{eventId}_{day}', () async {
    await db.collection('entry_days').doc('e1_2026-11-21').set({
      'eventId': 'e1',
      'day': '2026-11-21',
      'sold': 3,
      'held': 1,
      'checkedIn': 0,
      'closed': true,
    });
    final d = await repo.watchEntryDay('e1', '2026-11-21').first;
    expect(d!.sold, 3);
    expect(d.closed, isTrue);
    expect(await repo.watchEntryDay('e1', '2026-11-22').first, isNull);
  });

  test('signed out: own streams are empty', () async {
    final out = FirestoreOrganizerRepository(
      uid: null,
      uploader: uploader,
      db: db,
      functions: functions,
    );
    expect(await out.watchMine().first, isNull);
    expect(await out.watchMyClaims().first, isEmpty);
    expect(await out.watchGateStaff().first, isEmpty);
    expect(await out.watchMyGateInvites().first, isEmpty);
  });
}

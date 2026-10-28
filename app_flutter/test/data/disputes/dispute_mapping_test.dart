import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/firestore_dispute_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<Object?> {}

final _opened = DateTime.utc(2026, 10, 20, 3);
final _decided = DateTime.utc(2026, 10, 21, 8, 30);

Map<String, dynamic> disputeDoc({
  String id = '01JDISPUTEAAAAAAAAAAAAK7Q2',
  String reason = 'photos_missing',
  String status = 'open',
  Map<String, dynamic>? outcome,
  DateTime? createdAt,
  DateTime? resolvedAt,
  String customerId = 'c1',
}) => {
  'id': id,
  'subjectType': 'booking',
  'subjectId': 'b1',
  'eventId': null,
  'paymentId': 'pay1',
  'customerId': customerId,
  'providerId': 'p1',
  'parties': [customerId, 'p1'],
  'openedBy': 'customer',
  'reason': reason,
  'description': 'Thiếu 20 ảnh so với gói đã chọn',
  'evidencePaths': ['disputeEvidence/c1/$id/f1.jpg'],
  'snapshot': {
    'title': 'Minh Trí · Chân dung',
    'subtitle': 'T2 19/10 · 15:30–17:30',
    'providerName': 'Minh Trí',
    'thumbUrl': null,
  },
  'amountHeld': 1500000,
  'status': status,
  'outcome': outcome,
  'threadId': 'dispute_$id',
  'createdAt': Timestamp.fromDate(createdAt ?? _opened),
  'updatedAt': Timestamp.fromDate(createdAt ?? _opened),
  'resolvedAt': resolvedAt == null ? null : Timestamp.fromDate(resolvedAt),
  'version': 1,
};

void main() {
  group('Dispute mapping', () {
    test(
      'Dispute.fromFirestore maps status, outcome and Timestamps; unknown reason → other',
      () {
        final open = Dispute.fromFirestore('d1', disputeDoc());
        expect(open.id, 'd1');
        expect(open.subjectType, DisputeSubjectType.booking);
        expect(open.subjectId, 'b1');
        expect(open.eventId, isNull);
        expect(open.customerId, 'c1');
        expect(open.providerId, 'p1');
        expect(open.reason, DisputeReason.photosMissing);
        expect(open.description, 'Thiếu 20 ảnh so với gói đã chọn');
        expect(open.evidencePaths, [
          'disputeEvidence/c1/01JDISPUTEAAAAAAAAAAAAK7Q2/f1.jpg',
        ]);
        expect(open.title, 'Minh Trí · Chân dung');
        expect(open.subtitle, 'T2 19/10 · 15:30–17:30');
        expect(open.providerName, 'Minh Trí');
        expect(open.thumbUrl, isNull);
        expect(open.amountHeld, 1500000);
        expect(open.status, DisputeStatus.open);
        expect(open.outcome, isNull);
        expect(open.threadId, 'dispute_01JDISPUTEAAAAAAAAAAAAK7Q2');
        expect(open.createdAt, _opened);
        expect(open.createdAt.isUtc, isTrue);
        expect(open.resolvedAt, isNull);
        expect(open.isCustomer('c1'), isTrue);
        expect(open.isCustomer('p1'), isFalse);

        final resolved = Dispute.fromFirestore(
          'd2',
          disputeDoc(
            reason: 'something_new',
            status: 'resolved',
            resolvedAt: _decided,
            outcome: {
              'kind': 'split',
              'refundPercent': 40,
              'refundAmount': 600000,
              'releaseAmount': 900000,
              'note': 'Thiếu ảnh một phần',
              'decidedBy': 'staff1',
              'decidedAt': Timestamp.fromDate(_decided),
              'refundId': 'rf1',
            },
          ),
        );
        expect(resolved.reason, DisputeReason.other);
        expect(resolved.status, DisputeStatus.resolved);
        expect(resolved.resolvedAt, _decided);
        final o = resolved.outcome!;
        expect(o.kind, DisputeOutcomeKind.split);
        expect(o.refundPercent, 40);
        expect(o.refundAmount, 600000);
        expect(o.releaseAmount, 900000);
        expect(o.note, 'Thiếu ảnh một phần');
        expect(o.decidedAt, _decided);
      },
    );

    test('a ticket dispute keeps its event id and a platform provider', () {
      final d = Dispute.fromFirestore('d3', {
        ...disputeDoc(reason: 'event_not_held'),
        'subjectType': 'ticket',
        'subjectId': 'r1',
        'eventId': 'ev1',
        'providerId': 'platform',
      });
      expect(d.subjectType, DisputeSubjectType.ticket);
      expect(d.eventId, 'ev1');
      expect(d.providerId, 'platform');
      expect(d.reason, DisputeReason.eventNotHeld);
    });

    test('disputeCode takes the last 4 characters upper-cased', () {
      expect(disputeCode('01jdisputeaaaaaaaaaaaak7q2'), 'K7Q2');
      expect(disputeCode('ab'), 'AB');
    });

    test(
      'DisputeReason.offeredFor(deliveryCheck) is photos_missing, not_as_sample, link_broken, other',
      () {
        String codes(DisputeOrigin o) =>
            DisputeReason.offeredFor(o).map((r) => r.code).join(',');
        expect(
          codes(DisputeOrigin.deliveryCheck),
          'photos_missing,not_as_sample,link_broken,other',
        );
        expect(
          codes(DisputeOrigin.booking),
          'no_show,not_as_agreed,photos_missing,not_as_sample,link_broken,other',
        );
        expect(
          codes(DisputeOrigin.ticket),
          'event_not_held,not_as_described,other',
        );
        expect(DisputeReason.fromCode(null), DisputeReason.other);
        expect(DisputeReason.fromCode('link_broken'), DisputeReason.linkBroken);
      },
    );
  });

  group('FirestoreDisputeRepository', () {
    late FakeFirebaseFirestore db;
    late _MockFunctions functions;
    late _MockCallable callable;
    late FakeMediaUploader uploader;
    late FirestoreDisputeRepository repo;

    setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

    setUp(() {
      db = FakeFirebaseFirestore();
      functions = _MockFunctions();
      callable = _MockCallable();
      uploader = FakeMediaUploader();
      when(
        () => functions.httpsCallable(any(), options: any(named: 'options')),
      ).thenReturn(callable);
      repo = FirestoreDisputeRepository(
        uid: 'c1',
        uploader: uploader,
        urls: FakeMediaUrlResolver(),
        db: db,
        functions: functions,
      );
    });

    const draft = DisputeDraft(
      disputeId: '01JDISPUTEAAAAAAAAAAAAK7Q2',
      subjectType: DisputeSubjectType.booking,
      subjectId: 'b1',
      reason: DisputeReason.linkBroken,
      description: 'Link Drive báo không có quyền truy cập',
      evidencePaths: [
        'disputeEvidence/c1/01JDISPUTEAAAAAAAAAAAAK7Q2/f1.jpg',
      ],
    );

    test('open() sends the draft fields and returns disputeId', () async {
      final result = _MockResult();
      when(() => result.data).thenReturn({
        'disputeId': '01JDISPUTEAAAAAAAAAAAAK7Q2',
      });
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);

      final id = await repo.open(draft);

      expect(id, '01JDISPUTEAAAAAAAAAAAAK7Q2');
      final options =
          verify(
                () => functions.httpsCallable(
                  'openDispute',
                  options: captureAny(named: 'options'),
                ),
              ).captured.single
              as HttpsCallableOptions;
      // The callable runs with the 30 s payment options.
      expect(options.timeout, greaterThan(const Duration(seconds: 30)));
      final sent =
          verify(() => callable.call<Object?>(captureAny())).captured.single
              as Map;
      expect(sent, {
        'disputeId': '01JDISPUTEAAAAAAAAAAAAK7Q2',
        'subjectType': 'booking',
        'subjectId': 'b1',
        'reason': 'link_broken',
        'description': 'Link Drive báo không có quyền truy cập',
        'evidencePaths': [
          'disputeEvidence/c1/01JDISPUTEAAAAAAAAAAAAK7Q2/f1.jpg',
        ],
      });
    });

    test('a ticket draft also sends its event id', () async {
      final result = _MockResult();
      when(() => result.data).thenReturn({'disputeId': 'd9'});
      when(() => callable.call<Object?>(any())).thenAnswer((_) async => result);

      await repo.open(
        const DisputeDraft(
          disputeId: 'd9',
          subjectType: DisputeSubjectType.ticket,
          subjectId: 'r1',
          eventId: 'ev1',
          reason: DisputeReason.eventNotHeld,
          description: 'Sự kiện bị huỷ mà không báo trước',
        ),
      );
      final sent =
          verify(() => callable.call<Object?>(captureAny())).captured.single
              as Map;
      expect(sent['subjectType'], 'ticket');
      expect(sent['eventId'], 'ev1');
      expect(sent['evidencePaths'], isEmpty);
    });

    test("open() maps details.code conflict to DisputeError('conflict')",
        () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(
          message: 'aborted',
          code: 'aborted',
          details: {'code': 'conflict'},
        ),
      );
      await expectLater(
        repo.open(draft),
        throwsA(
          isA<DisputeError>().having((e) => e.code, 'code', 'conflict'),
        ),
      );
    });

    test("an unreachable backend is DisputeError('network')", () async {
      when(() => callable.call<Object?>(any())).thenThrow(
        FirebaseFunctionsException(message: 'x', code: 'unavailable'),
      );
      await expectLater(
        repo.open(draft),
        throwsA(isA<DisputeError>().having((e) => e.code, 'code', 'network')),
      );
    });

    test('mine() lists my disputes, newest first, at most the limit', () async {
      for (var i = 0; i < 3; i++) {
        await db
            .collection('disputes')
            .doc('d$i')
            .set(
              disputeDoc(
                id: 'd$i',
                createdAt: _opened.add(Duration(hours: i)),
              ),
            );
      }
      await db
          .collection('disputes')
          .doc('other')
          .set(disputeDoc(id: 'other', customerId: 'c9'));

      final list = await repo.mine(limit: 2);
      expect(list.map((d) => d.id), ['d2', 'd1']);
    });

    test('watch() emits the dispute, and null when it does not exist', () async {
      await db.collection('disputes').doc('d1').set(disputeDoc(id: 'd1'));
      expect((await repo.watch('d1').first)?.id, 'd1');
      expect(await repo.watch('missing').first, isNull);
    });

    test('watch() maps a permission-denied stream error to null', () async {
      final denied = disputeSnapshots(
        Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
        ),
      );
      expect(await denied.toList(), [null]);

      final other = disputeSnapshots(
        Stream.error(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        ),
      );
      await expectLater(other, emitsError(isA<FirebaseException>()));
    });

    test('evidence goes to disputeEvidence/uid/disputeId as a document image',
        () async {
      final path = repo.evidencePath('d1', 'f1');
      expect(path, 'disputeEvidence/c1/d1/f1.jpg');

      final events = await repo
          .uploadEvidence(const PickedImage(path: '/tmp/a.jpg', name: 'a.jpg'), path)
          .toList();
      expect(events.last.isDone, isTrue);
      expect(uploader.purposes[path], ImagePurpose.document);

      await repo.deleteEvidence(path);
      expect(uploader.deleted, [path]);
      expect(
        await repo.evidenceUrl(path),
        'https://storage.test/disputeEvidence/c1/d1/f1.jpg',
      );
    });
  });
}

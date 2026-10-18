import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';

import '../../support/fake_delivery_repository.dart';

void main() {
  group('FakeDeliveryRepository', () {
    late FakeDeliveryRepository repo;

    setUp(() {
      repo = FakeDeliveryRepository();
    });

    test('watchRounds emits seeded rounds and updates', () async {
      final round = DeliveryRound(
        bookingId: 'b1',
        round: 1,
        submittedAt: DateTime.utc(2026, 10, 20, 10, 0),
        submittedBy: 'p1',
        samples: const [
          DeliverySampleRef(
            fileId: 'f1',
            path: 'deliveries/b1/f1.jpg',
            thumbPath: 'deliveries/b1/f1_t.jpg',
            width: 1600,
            height: 1200,
          ),
        ],
        linkHost: 'drive.google.com',
        photoCount: 30,
      );

      final events = <List<DeliveryRound>>[];
      final sub = repo.watchRounds('b1').listen(events.add);
      await Future<void>.delayed(Duration.zero);

      repo.seedRound('b1', round);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[0], isEmpty);
      expect(events[1], [round]);
      await sub.cancel();
    });

    test('watchLink emits seeded link', () async {
      const link = DeliveryLink(link: 'https://drive.google.com/test', round: 1);
      final events = <DeliveryLink?>[];
      final sub = repo.watchLink('b1').listen(events.add);
      await Future<void>.delayed(Duration.zero);

      repo.seedLink('b1', link);
      await Future<void>.delayed(Duration.zero);

      expect(events, [null, link]);
      await sub.cancel();
    });

    test('watchStagedSamples emits staged samples', () async {
      const sample = StagedSample(
        fileId: 's1',
        status: SampleStatus.ready,
        path: 'deliveries/b1/s1.jpg',
      );
      final events = <List<StagedSample>>[];
      final sub = repo.watchStagedSamples('b1').listen(events.add);
      await Future<void>.delayed(Duration.zero);

      repo.seedStagedSample('b1', sample);
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(2));
      expect(events[0], isEmpty);
      expect(events[1], [sample]);
      await sub.cancel();
    });

    test('submit records call and returns next round', () async {
      final res = await repo.submit(
        bookingId: 'b1',
        sampleIds: ['f1', 'f2', 'f3'],
        link: 'https://drive.google.com/test',
        photoCount: 25,
        note: 'Ghi chú',
      );
      expect(res, 1);
      expect(repo.submitCalls, hasLength(1));
      expect(repo.submitCalls[0].bookingId, 'b1');
      expect(repo.submitCalls[0].sampleIds, ['f1', 'f2', 'f3']);
      expect(repo.submitCalls[0].link, 'https://drive.google.com/test');
      expect(repo.submitCalls[0].photoCount, 25);
      expect(repo.submitCalls[0].note, 'Ghi chú');
    });

    test('approve records call', () async {
      await repo.approve('b1');
      expect(repo.approveCalls, ['b1']);
    });

    test('requestRevision records call', () async {
      await repo.requestRevision(
        bookingId: 'b1',
        note: 'Sửa ảnh',
        photoNotes: [const DeliveryPhotoNote(sampleIndex: 0, note: 'Sáng hơn')],
        extra: false,
      );
      expect(repo.revisionCalls, hasLength(1));
      expect(repo.revisionCalls[0].bookingId, 'b1');
      expect(repo.revisionCalls[0].note, 'Sửa ảnh');
      expect(repo.revisionCalls[0].photoNotes[0].sampleIndex, 0);
      expect(repo.revisionCalls[0].extra, isFalse);
    });

    test('answerExtraRound records call', () async {
      await repo.answerExtraRound(bookingId: 'b1', grant: true);
      expect(repo.extraRoundCalls, hasLength(1));
      expect(repo.extraRoundCalls[0].bookingId, 'b1');
      expect(repo.extraRoundCalls[0].grant, isTrue);
    });

    test('uploadSample streams progress and done, records call', () async {
      const picked = PickedImage(
        path: '/tmp/test.jpg',
        name: 'test.jpg',
      );
      final events = await repo
          .uploadSample(
            bookingId: 'b1',
            uploaderId: 'p1',
            fileId: 'f1',
            image: picked,
          )
          .toList();

      expect(events, hasLength(2));
      expect(repo.uploadCalls, hasLength(1));
      expect(repo.uploadCalls[0].fileId, 'f1');
    });

    test('nextError causes methods to throw DeliveryException', () async {
      repo.nextError = DeliveryErrorCode.conflict;
      expect(
        () => repo.approve('b1'),
        throwsA(isA<DeliveryException>()),
      );
    });
  });
}

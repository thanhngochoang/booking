import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/delivery/submit_delivery_controller.dart';

import '../../support/booking_fixtures.dart';
import '../../support/fake_delivery_repository.dart';

void main() {
  late FakeDeliveryRepository fakeRepo;
  late Booking testB;

  setUp(() {
    fakeRepo = FakeDeliveryRepository();
    testB = makeTestBooking(
      id: 'b-deliver-1',
      status: BookingStatus.shot,
      photographerId: 'p1',
      customerId: 'c1',
    );
  });

  FakeImagePicker defaultPicker() => FakeImagePicker([
        [
          const PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
          const PickedImage(path: '/tmp/2.jpg', name: '2.jpg'),
          const PickedImage(path: '/tmp/3.jpg', name: '3.jpg'),
          const PickedImage(path: '/tmp/4.jpg', name: '4.jpg'),
          const PickedImage(path: '/tmp/5.jpg', name: '5.jpg'),
        ],
      ]);

  ProviderContainer makeContainer({FakeImagePicker? picker}) {
    return ProviderContainer(
      overrides: [
        deliveryRepositoryProvider.overrideWithValue(fakeRepo),
        imagePickerProvider.overrideWithValue(picker ?? defaultPicker()),
        authStateProvider.overrideWith(
          (ref) => Stream.value(const AuthUser(uid: 'p1')),
        ),
      ],
    );
  }

  test('picking 5 photos starts 5 uploads with ULID file ids', () async {
    final container = makeContainer();
    final sub = container.listen(
      submitDeliveryControllerProvider(testB),
      (_, _) {},
    );
    final notifier =
        container.read(submitDeliveryControllerProvider(testB).notifier);

    await notifier.pickPhotos();

    final state = container.read(submitDeliveryControllerProvider(testB));
    expect(state.tiles.length, 5);
    expect(fakeRepo.uploadCalls.length, 5);
    for (final call in fakeRepo.uploadCalls) {
      expect(call.bookingId, 'b-deliver-1');
      expect(call.uploaderId, 'p1');
      expect(call.fileId, isNotEmpty);
    }

    sub.close();
  });

  test('a tile moves uploading -> processing -> ready from the staged-sample stream',
      () async {
    final container = makeContainer();
    final sub = container.listen(
      submitDeliveryControllerProvider(testB),
      (_, _) {},
    );
    final notifier =
        container.read(submitDeliveryControllerProvider(testB).notifier);

    await notifier.pickPhotos();
    final fileId =
        container.read(submitDeliveryControllerProvider(testB)).tiles.first.fileId;

    // Simulate staged sample became ready in firestore
    fakeRepo.seedStagedSample(
      testB.id,
      StagedSample(
        fileId: fileId,
        status: SampleStatus.ready,
        thumbPath: 'deliveries/${testB.id}/${fileId}_t.jpg',
      ),
    );
    // Pump stream
    await pumpEventQueue();

    final tile = container
        .read(submitDeliveryControllerProvider(testB))
        .tiles
        .firstWhere((t) => t.fileId == fileId);
    expect(tile.phase, SampleTilePhase.ready);
    expect(tile.thumbPath, 'deliveries/${testB.id}/${fileId}_t.jpg');

    sub.close();
  });

  test('a failed staged sample marks the tile failed and retry uploads a new file id',
      () async {
    final container = makeContainer();
    final sub = container.listen(
      submitDeliveryControllerProvider(testB),
      (_, _) {},
    );
    final notifier =
        container.read(submitDeliveryControllerProvider(testB).notifier);

    await notifier.pickPhotos();
    final oldFileId =
        container.read(submitDeliveryControllerProvider(testB)).tiles.first.fileId;

    fakeRepo.seedStagedSample(
      testB.id,
      StagedSample(
        fileId: oldFileId,
        status: SampleStatus.failed,
        failure: 'too_large',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    var tile = container
        .read(submitDeliveryControllerProvider(testB))
        .tiles
        .firstWhere((t) => t.fileId == oldFileId);
    expect(tile.phase, SampleTilePhase.failed);

    notifier.retryTile(oldFileId);

    final state = container.read(submitDeliveryControllerProvider(testB));
    expect(state.tiles.any((t) => t.fileId == oldFileId), isFalse);
    expect(fakeRepo.uploadCalls.length, 6); // 5 initial + 1 retry

    sub.close();
  });

  test('removing a tile discards its upload', () async {
    final container = makeContainer();
    final sub = container.listen(
      submitDeliveryControllerProvider(testB),
      (_, _) {},
    );
    final notifier =
        container.read(submitDeliveryControllerProvider(testB).notifier);

    await notifier.pickPhotos();
    final toRemove =
        container.read(submitDeliveryControllerProvider(testB)).tiles.first.fileId;

    notifier.removeTile(toRemove);

    final state = container.read(submitDeliveryControllerProvider(testB));
    expect(state.tiles.length, 4);
    expect(state.tiles.any((t) => t.fileId == toRemove), isFalse);

    sub.close();
  });

  test('blocked checks: needSamples, waitProcessing, invalidLink, invalidCount',
      () async {
    final container = makeContainer();
    final sub = container.listen(
      submitDeliveryControllerProvider(testB),
      (_, _) {},
    );
    final notifier =
        container.read(submitDeliveryControllerProvider(testB).notifier);

    // Initial state: no samples
    var state = container.read(submitDeliveryControllerProvider(testB));
    expect(state.blocked, SubmitBlock.needSamples);

    await notifier.pickPhotos();
    // 5 photos uploading -> waitProcessing
    state = container.read(submitDeliveryControllerProvider(testB));
    expect(state.blocked, SubmitBlock.waitProcessing);

    // Make 3 samples ready
    for (var i = 0; i < 3; i++) {
      fakeRepo.seedStagedSample(
        testB.id,
        StagedSample(
          fileId: state.tiles[i].fileId,
          status: SampleStatus.ready,
          thumbPath: 'thumb_$i',
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);
    state = container.read(submitDeliveryControllerProvider(testB));
    // Remaining 2 are still processing
    expect(state.blocked, SubmitBlock.waitProcessing);

    // Remove the 2 still processing
    notifier.removeTile(state.tiles[3].fileId);
    notifier.removeTile(state.tiles[4].fileId);

    state = container.read(submitDeliveryControllerProvider(testB));
    // 3 ready, but no link
    expect(state.blocked, SubmitBlock.invalidLink);

    notifier.setLink('https://drive.google.com/drive/folders/photos');
    state = container.read(submitDeliveryControllerProvider(testB));
    // link ok, but no count
    expect(state.blocked, SubmitBlock.invalidCount);

    notifier.setCount('45');
    state = container.read(submitDeliveryControllerProvider(testB));
    expect(state.blocked, isNull);

    sub.close();
  });

  test('submit sends only ready ids in tile order', () async {
    final container = makeContainer();
    final sub = container.listen(
      submitDeliveryControllerProvider(testB),
      (_, _) {},
    );
    final notifier =
        container.read(submitDeliveryControllerProvider(testB).notifier);

    await notifier.pickPhotos();
    var state = container.read(submitDeliveryControllerProvider(testB));

    for (var i = 0; i < 3; i++) {
      fakeRepo.seedStagedSample(
        testB.id,
        StagedSample(
          fileId: state.tiles[i].fileId,
          status: SampleStatus.ready,
          thumbPath: 'thumb_$i',
        ),
      );
    }
    // Remove last 2
    notifier.removeTile(state.tiles[3].fileId);
    notifier.removeTile(state.tiles[4].fileId);
    await Future<void>.delayed(Duration.zero);

    notifier.setLink('https://drive.google.com/test');
    notifier.setCount('50');
    notifier.setNote('Enjoy your photos!');

    final round = await notifier.submit();
    expect(round, 1);
    expect(fakeRepo.submitCalls.length, 1);
    final call = fakeRepo.submitCalls.first;
    expect(call.bookingId, testB.id);
    expect(call.sampleIds.length, 3);
    expect(call.link, 'https://drive.google.com/test');
    expect(call.photoCount, 50);
    expect(call.note, 'Enjoy your photos!');

    sub.close();
  });

  test('not_ready error from the server keeps state and sets error', () async {
    fakeRepo.nextError = DeliveryErrorCode.notReady;
    final container = makeContainer();
    final sub = container.listen(
      submitDeliveryControllerProvider(testB),
      (_, _) {},
    );
    final notifier =
        container.read(submitDeliveryControllerProvider(testB).notifier);

    await notifier.pickPhotos();
    var state = container.read(submitDeliveryControllerProvider(testB));
    for (var i = 0; i < 3; i++) {
      fakeRepo.seedStagedSample(
        testB.id,
        StagedSample(
          fileId: state.tiles[i].fileId,
          status: SampleStatus.ready,
          thumbPath: 'thumb_$i',
        ),
      );
    }
    notifier.removeTile(state.tiles[3].fileId);
    notifier.removeTile(state.tiles[4].fileId);
    await Future<void>.delayed(Duration.zero);

    notifier.setLink('https://drive.google.com/test');
    notifier.setCount('50');

    final res = await notifier.submit();
    expect(res, isNull);
    state = container.read(submitDeliveryControllerProvider(testB));
    expect(state.error, isNotNull);
    expect(deliveryErrorOf(state.error!), DeliveryErrorCode.notReady);

    sub.close();
  });
}

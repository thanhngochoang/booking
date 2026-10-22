import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';

import '../../support/fake_instant_repository.dart';

InstantRequest _request(InstantStatus status) => InstantRequest(
  id: 'req1',
  customerId: 'cus1',
  status: status,
  packageCode: 'p60',
  genre: InstantGenre.portrait,
  meetPoint: const InstantMeetPoint(lat: 10.7769, lng: 106.6923, name: 'X'),
  photographerId: 'ph1',
);

void main() {
  test('a track subscribed during assigned shows after the request is en_route', () async {
    final repo = FakeInstantRepository();
    final container = ProviderContainer(
      overrides: [instantRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    repo.emitRequest('req1', _request(InstantStatus.assigned));
    final seen = <InstantTrack?>[];
    container.listen(
      instantTrackProvider('req1'),
      (_, next) => seen.add(next.value),
      fireImmediately: true,
    );
    await pumpEventQueue();

    // A point exists already, but while assigned the track is not listened to.
    final point = InstantTrack(
      lat: 10.78,
      lng: 106.70,
      accuracyM: 10,
      at: DateTime.utc(2026, 10, 22, 8, 5),
    );
    repo.emitTrack('req1', point);
    await pumpEventQueue();
    expect(container.read(instantTrackProvider('req1')).value, isNull);

    repo.emitRequest('req1', _request(InstantStatus.enRoute));
    await pumpEventQueue();
    expect(container.read(instantTrackProvider('req1')).value, point);

    repo.emitRequest('req1', _request(InstantStatus.arrived));
    await pumpEventQueue();
    expect(container.read(instantTrackProvider('req1')).value, isNull);
    expect(seen, contains(point));
  });
}

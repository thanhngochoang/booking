import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';

import '../../support/fake_instant_repository.dart';

void main() {
  test('records calls and failNext throws once', () async {
    final repo = FakeInstantRepository();
    repo.failNext('answerOffer', 'offer_expired');
    await expectLater(
      repo.answerOffer('of1', accept: true),
      throwsA(const InstantError('offer_expired')),
    );
    expect(await repo.answerOffer('of1', accept: true), 'req1');
    expect(repo.callsOf('answerOffer').map((c) => c.args['accept']), [
      true,
      true,
    ]);
    await repo.dispose();
  });

  test('streams replay the last value and surface failures', () async {
    final repo = FakeInstantRepository();
    repo.emitPresence(const LiveShutterState(online: true));
    expect((await repo.watchPresence().first)!.online, isTrue);

    final seen = <InstantRequest?>[];
    final sub = repo.watchRequest('req1').listen(seen.add);
    await pumpEventQueue();
    repo.emitRequest(
      'req1',
      const InstantRequest(
        id: 'req1',
        customerId: 'cus1',
        status: InstantStatus.searching,
        packageCode: 'p60',
        genre: InstantGenre.portrait,
        meetPoint: InstantMeetPoint(lat: 10.7, lng: 106.7, name: 'X'),
      ),
    );
    await pumpEventQueue();
    expect(seen.map((r) => r?.status), [null, InstantStatus.searching]);
    await sub.cancel();

    repo.failOffers(const InstantError('permission_denied'));
    await expectLater(
      repo.watchPendingOffers().first,
      throwsA(const InstantError('permission_denied')),
    );
    await repo.dispose();
  });
}

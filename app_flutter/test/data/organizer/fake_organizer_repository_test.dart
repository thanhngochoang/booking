import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/organizer/organizer_repository.dart';

import '../../support/fake_organizer_repository.dart';

void main() {
  final now = DateTime.parse('2026-10-20T00:00:00Z');
  const proof = PickedImage(path: '/tmp/1.jpg', name: '1.jpg');

  test('apply, claim once per spot, and list the claim', () async {
    final repo = FakeOrganizerRepository(clock: () => now);
    await repo.becomeOrganizer(name: 'Bãi đá', bio: '');
    expect((await repo.watchMine().first)!.isActive, isTrue);
    await repo.claimSpot(spotId: 's1', proofs: const [proof]);
    await expectLater(
      repo.claimSpot(spotId: 's1', proofs: const [proof]),
      throwsA(
        isA<OrganizerError>().having((e) => e.code, 'code', 'limit_exceeded'),
      ),
    );
    expect((await repo.watchMyClaims().first).single.spotId, 's1');
  });

  test('no verified phone → phone_required', () async {
    final repo = FakeOrganizerRepository()..phoneVerified = false;
    await expectLater(
      repo.becomeOrganizer(name: 'Bãi đá', bio: ''),
      throwsA(
        isA<OrganizerError>().having((e) => e.code, 'code', 'phone_required'),
      ),
    );
  });

  test('invite by phone, the invitee accepts within 72 h', () async {
    var t = now;
    final org = FakeOrganizerRepository(clock: () => t)
      ..accounts['+84901234567'] = 'u9';
    await org.inviteGateStaff('+84901234567');
    await expectLater(
      org.inviteGateStaff('+84900000000'),
      throwsA(isA<OrganizerError>().having((e) => e.code, 'code', 'not_found')),
    );
    org.uid = 'u9';
    expect((await org.watchMyGateInvites().first).single.organizerId, 'org1');
    t = now.add(const Duration(hours: 73));
    await expectLater(
      org.respondGateStaff('org1', accept: true),
      throwsA(
        isA<OrganizerError>().having((e) => e.code, 'code', 'deadline_passed'),
      ),
    );
    t = now.add(const Duration(hours: 1));
    await org.respondGateStaff('org1', accept: true);
    org.uid = 'org1';
    expect(
      (await org.watchGateStaff().first).single.status,
      GateStaffStatus.active,
    );
  });

  test('closeEntryDay marks the day closed', () async {
    final repo = FakeOrganizerRepository();
    await repo.closeEntryDay('e1', '2026-11-21');
    expect(
      (await repo.watchEntryDay('e1', '2026-11-21').first)!.closed,
      isTrue,
    );
  });
}

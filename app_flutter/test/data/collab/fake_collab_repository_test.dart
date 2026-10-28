import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';

import '../../support/recruit_world.dart';

void main() {
  late FakeCollabRepository repo;

  setUp(() {
    repo = FakeCollabRepository(uid: 'cuc', clock: () => recruitNow);
  });

  test(
    'FakeCollabRepository records calls with the callable payload',
    () async {
      repo.seedCollaboration(makeCollaboration(collaboratorId: 'dung'));
      await repo.setDefaultFee('dung', 700000);
      await repo.end(collaboratorId: 'dung');
      expect(repo.calls.map((c) => [c.$1, c.$2]), [
        [
          'setCollabDefaultFee',
          {'collaboratorId': 'dung', 'defaultFee': 700000},
        ],
        [
          'endCollaboration',
          {'collaboratorId': 'dung'},
        ],
      ]);
      expect(await repo.watchAsStudio('cuc').first, isEmpty, reason: 'ended');
    },
  );

  test('failWith makes every write throw it and records nothing', () async {
    repo.failWith = const RecruitError(RecruitErrorCode.memberBusy);
    await expectLater(
      repo.end(collaboratorId: 'dung'),
      throwsA(isA<RecruitError>()),
    );
    expect(repo.calls, isEmpty);
  });

  test('respondOffer and the pay record change the job', () async {
    repo
      ..seedJob(makeCollabJob(offerStatus: OfferStatus.pending))
      ..uid = 'dung';
    expect(await repo.respondOffer('b1', accept: true), OfferStatus.accepted);
    var job = (await repo.watchJobsAsCollaborator('dung').first).single;
    expect(job.offerStatus, OfferStatus.accepted);
    repo.uid = 'cuc';
    await repo.reportPaid(
      'b1',
      'dung',
      paidOn: DateTime(2026, 10, 21),
      method: CollabPayMethod.bank,
    );
    job = (await repo.watchJobsAsStudio('cuc').first).single;
    expect(job.payStatus, PayStatus.paidReported);
    expect(job.paidOn, '2026-10-21');
    expect(repo.calls.last.$2['paidOn'], '2026-10-21');
    repo.uid = 'dung';
    await repo.confirmPay('b1', received: false);
    job = (await repo.watchJobsAsStudio('cuc').first).single;
    expect(job.payStatus, PayStatus.disputed);
  });

  test('jobsDueInMonth filters by pay.dueAt in the VN month', () async {
    repo
      ..seedJob(
        makeCollabJob(
          bookingId: 'oct',
          payStatus: PayStatus.due,
          payDueAt: DateTime.utc(2026, 9, 30, 17, 30),
        ),
      )
      ..seedJob(
        makeCollabJob(
          bookingId: 'sep',
          payStatus: PayStatus.due,
          payDueAt: DateTime.utc(2026, 9, 30, 16, 30),
        ),
      );
    final oct = await repo.jobsDueInMonth('cuc', 2026, 10);
    expect(oct.map((j) => j.bookingId), ['oct']);
  });

  test('openChat answers collab_{studioId}_{collaboratorId}', () async {
    expect(await repo.openChat(collaboratorId: 'dung'), 'collab_cuc_dung');
    repo.uid = 'dung';
    expect(await repo.openChat(studioId: 'cuc'), 'collab_cuc_dung');
  });
}

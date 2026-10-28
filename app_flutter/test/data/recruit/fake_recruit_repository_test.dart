import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';

import '../../support/recruit_world.dart';

void main() {
  late FakeRecruitRepository repo;

  setUp(() {
    repo = FakeRecruitRepository(uid: 'hoa', clock: () => recruitNow);
  });

  test(
    'FakeRecruitRepository records calls with the callable payload',
    () async {
      repo.seedPost(makeRecruitPost(id: 'p1'));
      await repo.apply(
        'p1',
        message: 'Xin chào',
        samplePostIds: const ['s1'],
        acceptTerms: true,
      );
      await repo.withdraw('p1');
      expect(repo.calls.map((c) => [c.$1, c.$2]), [
        [
          'applyToRecruitPost',
          {
            'postId': 'p1',
            'message': 'Xin chào',
            'samplePostIds': ['s1'],
            'acceptTerms': true,
          },
        ],
        [
          'withdrawRecruitApplication',
          {'postId': 'p1'},
        ],
      ]);
      final mine = await repo.watchMyApplication('p1', 'hoa').first;
      expect(mine!.status, ApplicationStatus.withdrawn);
    },
  );

  test('failWith makes every write throw it and records nothing', () async {
    repo.failWith = const RecruitError(RecruitErrorCode.rateLimited);
    await expectLater(
      repo.close('p1'),
      throwsA(
        isA<RecruitError>().having(
          (e) => e.code,
          'code',
          RecruitErrorCode.rateLimited,
        ),
      ),
    );
    expect(repo.calls, isEmpty);
    repo.failWith = null;
    await repo.close('p1');
    expect(repo.calls.single.$1, 'closeRecruitPost');
  });

  test(
    'list filters open posts by key or studio, newest first, paged',
    () async {
      repo
        ..seedPost(
          makeRecruitPost(
            id: 'old',
            areas: const ['hue'],
            createdAt: recruitNow.subtract(const Duration(days: 3)),
          ),
        )
        ..seedPost(
          makeRecruitPost(
            id: 'new',
            createdAt: recruitNow.subtract(const Duration(days: 1)),
          ),
        )
        ..seedPost(
          makeRecruitPost(id: 'closed', status: RecruitPostStatus.closed),
        );
      final page1 = await repo.list(const RecruitFilter(), limit: 1);
      expect(page1.items.map((p) => p.id), ['new']);
      final page2 = await repo.list(
        const RecruitFilter(),
        after: page1.next,
        limit: 1,
      );
      expect(page2.items.map((p) => p.id), ['old']);
      final hue = await repo.list(const RecruitFilter(area: 'hue'));
      expect(hue.items.map((p) => p.id), ['old']);
      expect(repo.listedKeys, ['', '', 'a=hue']);
      expect(await repo.openCountOf('cuc'), 2);
    },
  );

  test('create adds an open post of the signed-in studio', () async {
    repo.uid = 'cuc';
    final id = await repo.create(
      const RecruitDraft(
        kind: RecruitKind.member,
        title: 'Tuyển thợ vào studio',
        specialties: ['portrait'],
        areas: ['hue'],
        frequency: RecruitFrequency.weekly,
        fee: NegotiableFee(),
        requirements: '',
      ),
    );
    final post = (await repo.get(id))!;
    expect(post.studioId, 'cuc');
    expect(post.status, RecruitPostStatus.open);
    expect(post.kind, RecruitKind.member);
    expect(repo.drafts.single.title, 'Tuyển thợ vào studio');
  });

  test('respond moves the applicant out of applicantsOf', () async {
    repo
      ..uid = 'cuc'
      ..seedPost(makeRecruitPost(id: 'p1'))
      ..seedApplication(makeRecruitApplication(postId: 'p1'));
    expect(await repo.applicantsOf('cuc', 'p1'), hasLength(1));
    await repo.respond('p1', 'hoa', accept: false);
    expect(await repo.applicantsOf('cuc', 'p1'), isEmpty);
  });
}

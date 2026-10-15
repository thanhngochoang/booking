import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/firestore_skills_repository.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';

const skills = PhotographerSkills(
  specialties: [
    SpecialtySkill(id: 'portrait', level: 3, evidencePostIds: ['p1']),
  ],
  styles: ['film'],
  languages: ['vi'],
  yearsExperience: 4,
);

void contract(String name, Future<SkillsRepository> Function() create) {
  group('$name contract', () {
    test('a photographer without skills loads as empty, not scored', () async {
      final snap = await (await create()).load('nobody');
      expect(snap.skills, PhotographerSkills.empty);
      expect(snap.server, SkillsServerInfo.none);
    });

    test('save then load returns the same skills', () async {
      final repo = await create();
      await repo.save('u1', skills);
      expect((await repo.load('u1')).skills, skills);
    });

    test('a second save replaces lists and clears years', () async {
      final repo = await create();
      await repo.save('u1', skills);
      const next = PhotographerSkills(
        specialties: [SpecialtySkill(id: 'wedding')],
        styles: ['minimal'],
        languages: ['en'],
      );
      await repo.save('u1', next);
      expect((await repo.load('u1')).skills, next);
    });

    test('photographers are kept apart', () async {
      final repo = await create();
      await repo.save('u1', skills);
      expect((await repo.load('u2')).skills, PhotographerSkills.empty);
    });
  });
}

void main() {
  contract('fake', () async => FakeSkillsRepository());
  contract(
    'firestore',
    () async => FirestoreSkillsRepository(db: FakeFirebaseFirestore()),
  );

  test('the fake counts calls, seeds and fails on demand', () async {
    final repo = FakeSkillsRepository()..seed('u1', skills);
    expect((await repo.load('u1')).skills, skills);
    expect(repo.loadCalls, 1);
    repo.failSaveWith = StateError('offline');
    await expectLater(
      repo.save('u1', PhotographerSkills.empty),
      throwsStateError,
    );
    expect(repo.stored('u1'), skills);
    expect(repo.saveCalls, 1);
    repo.failLoadWith = StateError('offline');
    await expectLater(repo.load('u1'), throwsStateError);
  });

  test(
    'the fake returns the seeded server info and keeps it across saves',
    () async {
      const info = SkillsServerInfo(
        completeness: 75,
        next: CompletenessStepCode.styles,
      );
      final repo = FakeSkillsRepository()
        ..seed('u1', skills)
        ..seedServer('u1', info);
      expect((await repo.load('u1')).server, info);
      await repo.save('u1', PhotographerSkills.initial);
      expect((await repo.load('u1')).server, info);
    },
  );

  group('Firestore adapter', () {
    test('writes photographers/{uid}.skills in the spec shape and keeps other fields', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('u1').set({
        'bio': 'Chân dung',
        'onboardingComplete': false,
        'skills': {
          'completeness': 40,
          'completenessNext': 'styles',
          'styles': ['editorial'],
        },
      });
      await FirestoreSkillsRepository(db: db).save('u1', skills);
      final data = (await db.collection('photographers').doc('u1').get())
          .data()!;
      expect(data['bio'], 'Chân dung');
      expect(data['updatedAt'], isA<Timestamp>());
      final stored = Map<String, dynamic>.from(data['skills'] as Map);
      expect(
        stored['completeness'],
        40,
        reason: 'server-owned, never written by the client',
      );
      expect(stored['completenessNext'], 'styles');
      expect(stored['schemaVersion'], 1);
      expect(stored['styles'], ['film']);
      expect(stored['specialties'], [
        {
          'id': 'portrait',
          'level': 3,
          'evidencePostIds': ['p1'],
        },
      ]);
      expect(stored['yearsExperience'], 4);
    });

    test(
      'a document with only the old flat specialties list has no skills yet',
      () async {
        final db = FakeFirebaseFirestore();
        await db.collection('photographers').doc('u1').set({
          'specialties': ['wedding'],
        });
        final snap = await FirestoreSkillsRepository(db: db).load('u1');
        expect(snap.skills, PhotographerSkills.empty);
        expect(snap.server, SkillsServerInfo.none);
      },
    );

    test(
      'reads the server fields of onPhotographerWrite; times as UTC',
      () async {
        final db = FakeFirebaseFirestore();
        await db.collection('photographers').doc('u1').set({
          'skills': {
            ...skillsToMap(skills),
            'completeness': 85,
            'completenessNext': 'audiences',
            'completenessNextAfter': 95,
            'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 2, 8)),
            'evidenceRemovedAt': Timestamp.fromDate(
              DateTime.utc(2026, 10, 2, 8, 30),
            ),
          },
        });
        final snap = await FirestoreSkillsRepository(db: db).load('u1');
        expect(snap.skills, skills);
        expect(
          snap.server,
          SkillsServerInfo(
            completeness: 85,
            next: CompletenessStepCode.audiences,
            nextAfter: 95,
            evidenceRemovedAt: DateTime.utc(2026, 10, 2, 8, 30),
          ),
        );
        expect(snap.server.evidenceRemovedAt!.isUtc, isTrue);
      },
    );

    test('not scored yet, or malformed server fields, read as null', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('u1').set({
        'skills': skillsToMap(skills),
      });
      await db.collection('photographers').doc('u2').set({
        'skills': {
          ...skillsToMap(skills),
          'completeness': 140,
          'completenessNext': 'bogus',
          'completenessNextAfter': 140,
          'evidenceRemovedAt': '2026-10-02',
        },
      });
      await db.collection('photographers').doc('u3').set({
        'skills': {
          ...skillsToMap(skills),
          'completeness': '85',
          'completenessNextAfter': '95',
        },
      });
      final repo = FirestoreSkillsRepository(db: db);
      for (final uid in ['u1', 'u2', 'u3']) {
        expect(
          (await repo.load(uid)).server,
          SkillsServerInfo.none,
          reason: uid,
        );
      }
    });
  });

  test('providers: built-in catalogue and one read per photographer', () async {
    final repo = FakeSkillsRepository()
      ..seed('u1', skills)
      ..seedServer('u1', const SkillsServerInfo(completeness: 90));
    final container = ProviderContainer(
      overrides: [skillsRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    expect(
      container.read(skillCatalogProvider).ids(SkillGroup.language),
      hasLength(5),
    );
    final a = container.listen(photographerSkillsProvider('u1'), (_, _) {});
    final b = container.listen(
      photographerSkillsSnapshotProvider('u1'),
      (_, _) {},
    );
    addTearDown(a.close);
    addTearDown(b.close);
    expect(
      await container.read(photographerSkillsProvider('u1').future),
      skills,
    );
    expect(
      (await container.read(photographerSkillsSnapshotProvider('u1').future))
          .server
          .completeness,
      90,
    );
    expect(repo.loadCalls, 1);
  });
}

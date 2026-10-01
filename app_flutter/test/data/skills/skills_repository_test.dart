import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/skills/firestore_skills_repository.dart';
import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skill_taxonomy.dart';
import 'package:photobooking/data/skills/skills_providers.dart';
import 'package:photobooking/data/skills/skills_repository.dart';

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
    test('a photographer without skills loads as empty', () async {
      expect(await (await create()).load('nobody'), PhotographerSkills.empty);
    });

    test('save then load returns the same skills', () async {
      final repo = await create();
      await repo.save('u1', skills);
      expect(await repo.load('u1'), skills);
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
      expect(await repo.load('u1'), next);
    });

    test('photographers are kept apart', () async {
      final repo = await create();
      await repo.save('u1', skills);
      expect(await repo.load('u2'), PhotographerSkills.empty);
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
    expect(await repo.load('u1'), skills);
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

  group('Firestore adapter', () {
    test('writes photographers/{uid}.skills in the spec shape and keeps other fields', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('u1').set({
        'bio': 'Chân dung',
        'onboardingComplete': false,
        'skills': {
          'completeness': 40,
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
        expect(
          await FirestoreSkillsRepository(db: db).load('u1'),
          PhotographerSkills.empty,
        );
      },
    );
  });

  test('providers: built-in catalogue and a per-photographer read', () async {
    final repo = FakeSkillsRepository()..seed('u1', skills);
    final container = ProviderContainer(
      overrides: [skillsRepositoryProvider.overrideWithValue(repo)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    expect(
      container.read(skillCatalogProvider).ids(SkillGroup.language),
      hasLength(5),
    );
    final sub = container.listen(photographerSkillsProvider('u1'), (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(photographerSkillsProvider('u1').future),
      skills,
    );
    expect(repo.loadCalls, 1);
  });
}

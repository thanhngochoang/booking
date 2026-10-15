// test/data/contracts/user_repository_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';

typedef Create<R> = Future<({R repo, String uid})> Function();

AuthUser _user(String uid, String name) =>
    AuthUser(uid: uid, email: '$uid@example.com', displayName: name);

/// Behaviour every UserRepository adapter must share (data-model README §7.3).
void userRepositoryContract(String label, Create<UserRepository> create) {
  group('$label UserRepository contract', () {
    test('watch of a missing profile emits null', () async {
      final h = await create();
      expect(await h.repo.watch(h.uid).first, isNull);
    });

    test(
      'ensureProfile creates a role-less profile and never overwrites it',
      () async {
        final h = await create();
        final p = await h.repo.ensureProfile(_user(h.uid, 'Lan'));
        expect((p.uid, p.displayName, p.role), (h.uid, 'Lan', null));
        final again = await h.repo.ensureProfile(_user(h.uid, 'Someone else'));
        expect(again.displayName, 'Lan');
      },
    );

    test('setDisplayName works before and after ensureProfile', () async {
      final h = await create();
      await h.repo.setDisplayName(h.uid, 'Minh');
      expect((await h.repo.watch(h.uid).first)?.displayName, 'Minh');
      await h.repo.ensureProfile(_user(h.uid, 'Lan'));
      expect((await h.repo.watch(h.uid).first)?.displayName, 'Minh');
    });

    test('setRole shows in watch and survives ensureProfile', () async {
      final h = await create();
      await h.repo.ensureProfile(_user(h.uid, 'Lan'));
      await h.repo.setRole(h.uid, UserRole.photographer);
      expect((await h.repo.watch(h.uid).first)?.role, UserRole.photographer);
      expect(
        (await h.repo.ensureProfile(_user(h.uid, 'Lan'))).role,
        UserRole.photographer,
      );
    });

    test("a live watch sees the adapter's own writes", () async {
      final h = await create();
      await h.repo.ensureProfile(_user(h.uid, 'Lan'));
      final seen = expectLater(
        h.repo.watch(h.uid).map((p) => p?.displayName),
        emitsThrough('Minh'),
      );
      await h.repo.setDisplayName(h.uid, 'Minh');
      await seen;
    });
  });
}

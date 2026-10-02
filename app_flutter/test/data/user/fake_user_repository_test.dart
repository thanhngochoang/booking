import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';

void main() {
  test('ensureProfile creates a role-less profile once', () async {
    final repo = FakeUserRepository();
    const user = AuthUser(uid: 'u1', email: 'a@b.vn', displayName: 'Lan');
    final p1 = await repo.ensureProfile(user);
    expect(p1.needsRole, isTrue);
    await repo.setRole('u1', UserRole.photographer);
    final p2 = await repo.ensureProfile(user);
    expect(
      p2.role,
      UserRole.photographer,
      reason: 'existing profile is not overwritten',
    );
    expect(repo.photographerDocs, contains('u1'));
  });
  test('watch emits null for unknown uid then the profile', () async {
    final repo = FakeUserRepository();
    final first = await repo.watch('u9').first;
    expect(first, isNull);
  });

  test('setAvatar stores url and path and returns the previous path', () async {
    final users = FakeUserRepository();
    await users.ensureProfile(const AuthUser(uid: 'u1', displayName: 'Lan'));
    expect(
      await users.setAvatar(
        'u1',
        url: 'https://s/a.jpg',
        storagePath: 'avatars/u1/A.jpg',
      ),
      isNull,
    );
    expect(
      await users.setAvatar(
        'u1',
        url: 'https://s/b.jpg',
        storagePath: 'avatars/u1/B.jpg',
      ),
      'avatars/u1/A.jpg',
    );
    expect((await users.watch('u1').first)!.avatarUrl, 'https://s/b.jpg');
    expect(users.avatarPaths['u1'], 'avatars/u1/B.jpg');
    users.failSetAvatar = true;
    await expectLater(
      users.setAvatar('u1', url: 'x', storagePath: 'y'),
      throwsStateError,
    );
  });
}

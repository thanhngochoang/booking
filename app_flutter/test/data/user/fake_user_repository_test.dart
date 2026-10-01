import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';
import 'package:nhiep_anh_gia/data/user/user_repository.dart';

void main() {
  test('ensureProfile creates a role-less profile once', () async {
    final repo = FakeUserRepository();
    const user = AuthUser(uid: 'u1', email: 'a@b.vn', displayName: 'Lan');
    final p1 = await repo.ensureProfile(user);
    expect(p1.needsRole, isTrue);
    await repo.setRole('u1', UserRole.photographer);
    final p2 = await repo.ensureProfile(user);
    expect(p2.role, UserRole.photographer, reason: 'existing profile is not overwritten');
    expect(repo.photographerDocs, contains('u1'));
  });
  test('watch emits null for unknown uid then the profile', () async {
    final repo = FakeUserRepository();
    final first = await repo.watch('u9').first;
    expect(first, isNull);
  });
}

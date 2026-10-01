import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_providers.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';
import 'package:nhiep_anh_gia/data/user/user_repository.dart';
import 'package:nhiep_anh_gia/features/onboarding/role_controller.dart';

void main() {
  test('choose sets the role for the signed-in user', () async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    await container.read(roleControllerProvider.notifier).choose(UserRole.photographer);
    final p = await users.watch(u.uid).first;
    expect(p!.role, UserRole.photographer);
    expect(container.read(roleControllerProvider).hasError, isFalse);
  });
}

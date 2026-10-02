import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/auth/auth_controller.dart';

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test('a users doc deleted mid-session is recreated without a role', () async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(c.dispose);
    final seen = <UserProfile?>[];
    c.listen(
      currentProfileProvider,
      (_, n) => seen.add(n.value),
      fireImmediately: true,
    );
    await _settle();
    await users.setRole(u.uid, UserRole.customer);
    await _settle();
    expect(c.read(currentProfileProvider).value?.role, UserRole.customer);
    users.deleteProfile(u.uid);
    await _settle();
    final p = c.read(currentProfileProvider).value;
    expect(p, isNotNull);
    expect(p!.needsRole, isTrue);
  });

  test(
    'email registration stores the entered name, not the email prefix',
    () async {
      final auth = FakeAuthRepository(emitBeforeName: true);
      final users = FakeUserRepository();
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
        ],
      );
      addTearDown(c.dispose);
      c.listen(currentProfileProvider, (_, _) {}, fireImmediately: true);
      await c
          .read(authControllerProvider.notifier)
          .register('minh.tran@x.vn', 'password1', 'Minh');
      await _settle();
      expect(c.read(currentProfileProvider).value?.displayName, 'Minh');
    },
  );

  test(
    'profile load failure surfaces as an error, not a silent wait',
    () async {
      final auth = FakeAuthRepository();
      final users = FakeUserRepository(failEnsure: true);
      await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
        ],
      );
      addTearDown(c.dispose);
      c.listen(currentProfileProvider, (_, _) {}, fireImmediately: true);
      await _settle();
      expect(c.read(currentProfileProvider).hasError, isTrue);
    },
  );
}

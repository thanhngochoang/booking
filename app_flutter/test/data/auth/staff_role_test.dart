import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';

class _Auth extends Mock implements fb.FirebaseAuth {}

class _User extends Mock implements fb.User {}

class _Token extends Mock implements fb.IdTokenResult {}

FirebaseAuthRepository _repoWithClaims(Map<String, dynamic>? claims) {
  final auth = _Auth();
  final user = _User();
  final token = _Token();
  when(() => token.claims).thenReturn(claims);
  when(() => user.getIdTokenResult()).thenAnswer((_) async => token);
  when(() => auth.currentUser).thenReturn(user);
  return FirebaseAuthRepository(auth: auth);
}

void main() {
  group('FirebaseAuthRepository.staffRole', () {
    test('staffRole reads the admin claim', () async {
      expect(
        await _repoWithClaims({'staffRole': 'admin'}).staffRole(),
        StaffRole.admin,
      );
      expect(
        await _repoWithClaims({'staffRole': 'sales'}).staffRole(),
        StaffRole.sales,
      );
    });

    test('a missing or unknown claim is null', () async {
      expect(await _repoWithClaims({}).staffRole(), isNull);
      expect(await _repoWithClaims(null).staffRole(), isNull);
      expect(await _repoWithClaims({'staffRole': 'root'}).staffRole(), isNull);
      expect(await _repoWithClaims({'staffRole': true}).staffRole(), isNull);
    });

    test('signed out or an unreadable token is null', () async {
      final auth = _Auth();
      when(() => auth.currentUser).thenReturn(null);
      expect(await FirebaseAuthRepository(auth: auth).staffRole(), isNull);

      final user = _User();
      when(() => user.getIdTokenResult()).thenThrow(StateError('offline'));
      when(() => auth.currentUser).thenReturn(user);
      expect(await FirebaseAuthRepository(auth: auth).staffRole(), isNull);
    });
  });

  group('staffRoleProvider', () {
    test('follows the signed-in user and is null when signed out', () async {
      final repo = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(staffRoleProvider, (_, _) {}, fireImmediately: true);
      await settle();
      expect(container.read(staffRoleProvider).value, isNull);

      repo.staff = StaffRole.sales;
      await repo.registerWithEmail('a@b.vn', 'password1', 'An');
      await settle();
      expect(container.read(staffRoleProvider).value, StaffRole.sales);

      await repo.signOut();
      await settle();
      expect(container.read(staffRoleProvider).value, isNull);
    });
  });
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

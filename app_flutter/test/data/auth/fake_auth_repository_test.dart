import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_error.dart';
import 'package:photobooking/data/auth/auth_repository.dart';

void main() {
  test(
    'register then sign in, stream emits user, sign out emits null',
    () async {
      final repo = FakeAuthRepository();
      final events = <String?>[];
      final sub = repo.authStateChanges().listen((u) => events.add(u?.uid));
      await Future<void>.delayed(Duration.zero);
      final u = await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
      expect(u.displayName, 'Lan');
      await repo.signOut();
      final again = await repo.signInWithEmail('a@b.vn', 'password1');
      expect(again.uid, u.uid);
      await repo.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(events, [null, u.uid, null, u.uid, null]);
      await sub.cancel();
    },
  );
  test('wrong password and unknown email throw typed errors', () async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
    await repo.signOut();
    expect(
      () => repo.signInWithEmail('a@b.vn', 'nope'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.error,
          'error',
          AuthError.wrongPassword,
        ),
      ),
    );
    expect(
      () => repo.signInWithEmail('x@b.vn', 'nope'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.error,
          'error',
          AuthError.userNotFound,
        ),
      ),
    );
  });
  test('google cancel throws cancelled', () async {
    final repo = FakeAuthRepository(cancelSocial: true);
    expect(
      repo.signInWithGoogle,
      throwsA(
        isA<AuthException>().having(
          (e) => e.error,
          'error',
          AuthError.cancelled,
        ),
      ),
    );
  });
}

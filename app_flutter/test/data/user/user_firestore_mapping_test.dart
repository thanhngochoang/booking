import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';

void main() {
  test(
    'users/{uid} never stores email or uid (readable by every signed-in user)',
    () {
      const p = UserProfile(
        uid: 'u1',
        displayName: 'Minh',
        email: 'minh@x.vn',
        avatarUrl: 'https://a/b.jpg',
      );
      final m = profileToFirestore(p);
      expect(m.containsKey('email'), isFalse);
      expect(m.containsKey('uid'), isFalse);
      expect(m['displayName'], 'Minh');
      expect(m['avatarUrl'], 'https://a/b.jpg');
    },
  );
}

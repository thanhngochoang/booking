import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/user/user_profile.dart';

void main() {
  test('round-trips JSON with role as snake string', () {
    const p = UserProfile(
      uid: 'u1',
      role: UserRole.photographer,
      displayName: 'Minh Trí',
    );
    final json = p.toJson();
    expect(json['role'], 'photographer');
    expect(UserProfile.fromJson(json), p);
  });
  test('needsRole is true when role missing', () {
    expect(
      UserProfile.fromJson({'uid': 'u', 'displayName': 'x'}).needsRole,
      isTrue,
    );
  });
}

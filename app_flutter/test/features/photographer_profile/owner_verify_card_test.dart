// test/features/photographer_profile/owner_verify_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/photographer_profile/widgets/profile_header.dart';

import '../../support/content_fixtures.dart';
import '../../support/profile_world.dart';

Finder get _card => find.byKey(const Key('profile-owner-verify'));

Finder _inCard(String text) =>
    find.descendant(of: _card, matching: find.text(text));

Map<String, dynamic> _doc(String status) => {
  'uid': 'u',
  'status': status,
  'steps': {
    'identity': {
      'method': 'vneid',
      'result': 'passed',
      'maskedName': 'NGUYỄN M** T**',
    },
  },
  'freeResubmitsLeft': 1,
};

/// S03.01 of the signed-in provider (owner) or of p1 (visitor), with the
/// signed-in user's verification record [doc] (null: none yet).
Future<ProfileWorld> _open(
  WidgetTester tester, {
  bool owner = true,
  Map<String, dynamic>? doc,
  bool verified = false,
}) async {
  usePhoneFor(tester);
  final w = ProfileWorld(role: UserRole.photographer);
  await w.init();
  w.profiles.add(
    PhotographerProfile(
      summary: fixturePhotographer(
        w.uid,
        name: 'Bảo Ngọc',
        verified: verified,
        acceptingOrders: verified,
      ),
      intro: const PhotographerIntro(onboardingComplete: true),
    ),
  );
  if (doc != null) {
    w.verifications.seed(w.uid, doc);
  }
  await tester.pumpWidget(w.app(owner ? '/u/${w.uid}' : '/u/p1'));
  await tester.pumpAndSettle();
  return w;
}

void main() {
  testWidgets('the owner card on S03.01 shows Còn {n} bước để nhận đơn and '
      'Tiếp tục', (tester) async {
    final w = await _open(tester);

    expect(find.byType(OwnerVerifyCard), findsOneWidget);
    expect(_inCard('Còn 3 bước để nhận đơn'), findsOneWidget);
    expect(
      _inCard('Khách chưa đặt được bạn cho tới khi xác minh xong.'),
      findsOneWidget,
    );
    expect(_inCard('Tiếp tục'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-owner-verify-open')));
    await tester.pumpAndSettle();
    expect(w.router.state.uri.path, '/verify/start');
  });

  testWidgets('pending and rejected variants open S21.02 with Xem', (
    tester,
  ) async {
    await _open(tester, doc: _doc('submitted'));
    expect(_inCard('Đang chờ duyệt · trong 24 giờ'), findsOneWidget);
    expect(
      _inCard('Hồ sơ vẫn hiện "Chưa nhận đơn" với khách tới khi được duyệt.'),
      findsOneWidget,
    );
    expect(_inCard('Xem'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    await _open(tester, doc: _doc('rejected'));
    expect(_inCard('Hồ sơ chưa được duyệt'), findsOneWidget);
    expect(_inCard('Xem lý do và gửi lại.'), findsOneWidget);
    expect(_inCard('Xem'), findsOneWidget);
  });

  testWidgets('the owner card hides once approved', (tester) async {
    await _open(tester, doc: _doc('approved'), verified: true);
    expect(_card, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    await _open(tester, doc: _doc('approved'));
    expect(_card, findsNothing, reason: 'the record alone hides it too');
  });

  testWidgets('visitors never see the owner card', (tester) async {
    await _open(tester, owner: false);
    expect(find.byType(OwnerVerifyCard), findsNothing);
    expect(_card, findsNothing);
  });
}

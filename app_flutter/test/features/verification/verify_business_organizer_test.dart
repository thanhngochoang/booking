// test/features/verification/verify_business_organizer_test.dart
//
// Task 1b (app half): an organizer reaches S21.04 business verification and
// S06.06 "Tài khoản nhận tiền" from S30.03 (Decision 3).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/organizer/organizer.dart';

import '../../support/organizer_world.dart';
import '../../support/verification_world.dart';

Finder _key(String k) => find.byKey(Key(k));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<VerificationWorld> _verification(
  WidgetTester tester, {
  OrganizerStatus? organizer,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = VerificationWorld(startScreen: true);
  await w.init();
  // A customer: no S21 record, no photographer intro.
  w.seedDoc(null);
  if (organizer != null) {
    w.organizers.putOrganizer(
      makeOrganizer(
        id: w.uid,
        status: organizer,
        businessVerified: false,
        payoutAccountOk: false,
      ),
    );
  }
  await tester.pumpWidget(w.app(location: '/verify/business'));
  await _settle(tester);
  return w;
}

void main() {
  testWidgets('an active organizer (not a provider) sees the S21.04 form', (
    tester,
  ) async {
    await _verification(tester, organizer: OrganizerStatus.active);

    expect(_key('verify-biz-tax-code'), findsOneWidget);
    expect(_key('verify-biz-needs-identity'), findsNothing);
    expect(
      find.text(
        'Cần để bán vé có thu phí và nhận tiền vé vào tài khoản đứng tên doanh nghiệp.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a suspended organizer or a plain customer cannot start it', (
    tester,
  ) async {
    await _verification(tester, organizer: OrganizerStatus.suspended);
    expect(_key('verify-biz-tax-code'), findsNothing);
    expect(_key('verify-biz-needs-identity'), findsOneWidget);
  });

  testWidgets('a customer who is not an organizer sees the alert as today', (
    tester,
  ) async {
    await _verification(tester);
    expect(_key('verify-biz-tax-code'), findsNothing);
    expect(_key('verify-biz-needs-identity'), findsOneWidget);
  });

  group('S30.03 entries', () {
    OrganizerWorld world({required bool business, required bool payout}) {
      final w = OrganizerWorld();
      w.organizers.putOrganizer(
        makeOrganizer(businessVerified: business, payoutAccountOk: payout),
      );
      w.seedSpot(makeSpot(managedBy: 'org1'));
      return w;
    }

    testWidgets('"Xác minh doanh nghiệp để bán vé" opens S21.04', (
      tester,
    ) async {
      final w = world(business: false, payout: false);
      await w.pump(tester, location: '/organizer/spots/bd');
      final primary = tester.widget<AppButton>(_key('managed-primary'));
      expect(primary.label, 'Xác minh doanh nghiệp để bán vé');
      await tapOrganizer(tester, _key('managed-primary'));
      expect(w.location, '/verify/business');
    });

    testWidgets(
      'a verified business without a payout account: "Tài khoản nhận tiền" → S06.06',
      (tester) async {
        final w = world(business: true, payout: false);
        await w.pump(tester, location: '/organizer/spots/bd');
        final primary = tester.widget<AppButton>(_key('managed-primary'));
        expect(primary.label, 'Tài khoản nhận tiền');
        await tapOrganizer(tester, _key('managed-primary'));
        expect(w.location, '/organizer/payout-account');
      },
    );

    testWidgets('the payout row stays reachable once selling', (tester) async {
      final w = world(business: true, payout: true);
      await w.pump(tester, location: '/organizer/spots/bd');
      expect(find.text('Tài khoản nhận tiền'), findsOneWidget);
      await tapOrganizer(tester, _key('managed-payout'));
      expect(w.location, '/organizer/payout-account');
    });
  });
}

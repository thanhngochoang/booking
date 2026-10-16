// test/features/work/work_empty_closed_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/booking_world.dart';

/// S06.02 with #135's route in place: no flag override, the shipped value.
Future<BookingsTabHandles> _pump(
  WidgetTester tester,
  PhotographerIntro intro,
) async {
  final handles = await pumpBookingsTab(
    tester,
    uid: detailPhotographerUid,
    role: UserRole.photographer,
    now: DateTime.utc(2026, 10, 15, 2),
    portfolioPhotos: 8,
    packages: const [workPackage],
    completeness: 90,
    intro: intro,
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return handles;
}

List<String> _primaryLabels(WidgetTester tester) => [
  for (final b in tester.widgetList<AppButton>(
    find.ancestor(
      of: find.byType(CtaSurface),
      matching: find.byType(AppButton),
    ),
  ))
    b.label,
];

void main() {
  testWidgets('S06.02 shows the closed state with Bắt đầu nhận đơn for an '
      'unverified provider and opens /verify/start', (tester) async {
    final handles = await _pump(
      tester,
      const PhotographerIntro(onboardingComplete: true),
    );

    expect(find.text('Mở nhận đơn để khách đặt được bạn'), findsOneWidget);
    expect(
      find.text('Staff duyệt trong 24 giờ sau khi bạn gửi'),
      findsOneWidget,
    );
    expect(_primaryLabels(tester), ['Bắt đầu nhận đơn']);
    await tester.tap(find.widgetWithText(AppButton, 'Bắt đầu nhận đơn'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(handles.location, '/verify/start');
  });

  testWidgets("a verified provider keeps today's S06.02", (tester) async {
    await _pump(
      tester,
      const PhotographerIntro(
        onboardingComplete: true,
        verified: true,
        acceptingOrders: true,
      ),
    );

    expect(find.text('Buổi chụp tiếp theo bắt đầu từ đây'), findsOneWidget);
    expect(find.text('Mở nhận đơn để khách đặt được bạn'), findsNothing);
    expect(find.text('Bắt đầu nhận đơn'), findsNothing);
    expect(_primaryLabels(tester), ['Chia sẻ hồ sơ']);
  });
}

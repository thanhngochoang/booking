import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/settings/settings_links.dart';
import 'package:photobooking/features/work/work_empty.dart';

import '../../support/booking_world.dart';

/// Thursday 08/10 09:00 in Vietnam.
final _now = DateTime.utc(2026, 10, 8, 2);

Future<BookingsTabHandles> _pump(
  WidgetTester tester, {
  required int photos,
  bool package = true,
  int? completeness = 90,
  PhotographerIntro intro = const PhotographerIntro(acceptingOrders: true),
  List<Override> extraOverrides = const [],
  double textScale = 1.0,
  Size viewSize = const Size(390, 844),
}) async {
  final handles = await pumpBookingsTab(
    tester,
    uid: detailPhotographerUid,
    role: UserRole.photographer,
    now: _now,
    portfolioPhotos: photos,
    packages: package ? const [workPackage] : const [],
    completeness: completeness,
    intro: intro,
    extraOverrides: extraOverrides,
    textScale: textScale,
    viewSize: viewSize,
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return handles;
}

/// Labels of the primary (gradient) buttons on screen.
List<String> _primaryLabels(WidgetTester tester) => [
  for (final b in tester.widgetList<AppButton>(
    find.ancestor(
      of: find.byType(CtaSurface),
      matching: find.byType(AppButton),
    ),
  ))
    b.label,
];

Future<void> _tapPrimary(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(AppButton, label));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('the rule picks photos, then package, then skills, then share', () {
    expect(
      workEmptyStep(photos: 2, activePackages: 0, completeness: null),
      WorkEmptyStep.addPhotos,
    );
    expect(
      workEmptyStep(photos: 6, activePackages: 0, completeness: 90),
      WorkEmptyStep.addPackage,
    );
    expect(
      workEmptyStep(photos: 6, activePackages: 1, completeness: 69),
      WorkEmptyStep.skills,
    );
    expect(
      workEmptyStep(photos: 6, activePackages: 1, completeness: null),
      WorkEmptyStep.skills,
      reason: 'not scored yet counts as under 70',
    );
    expect(
      workEmptyStep(photos: 6, activePackages: 1, completeness: 70),
      WorkEmptyStep.share,
    );
  });

  testWidgets('2 photos: the portfolio sentence with n=2 and Thêm ảnh', (
    tester,
  ) async {
    final handles = await _pump(tester, photos: 2, package: false);

    expect(find.byType(WorkEmptyState), findsOneWidget);
    expect(find.text('Buổi chụp tiếp theo bắt đầu từ đây'), findsOneWidget);
    expect(
      find.text(
        'Hồ sơ có 6 ảnh và 1 gói được đặt nhiều gấp 3 lần. '
        'Bạn đang có 2 ảnh.',
      ),
      findsOneWidget,
    );
    expect(_primaryLabels(tester), ['Thêm ảnh vào portfolio']);
    await _tapPrimary(tester, 'Thêm ảnh vào portfolio');
    expect(handles.location, '/action');
  });

  testWidgets('8 photos and no package: Thêm gói', (tester) async {
    final handles = await _pump(tester, photos: 8, package: false);

    expect(_primaryLabels(tester), ['Thêm gói']);
    await _tapPrimary(tester, 'Thêm gói');
    expect(handles.location, '/setup/2');
  });

  testWidgets('8 photos, a package, completeness 50: Hoàn thiện kỹ năng', (
    tester,
  ) async {
    final handles = await _pump(tester, photos: 8, completeness: 50);

    expect(_primaryLabels(tester), ['Hoàn thiện kỹ năng']);
    await _tapPrimary(tester, 'Hoàn thiện kỹ năng');
    expect(handles.location, '/profile/skills');
  });

  testWidgets('all fine: Chia sẻ hồ sơ opens the public profile', (
    tester,
  ) async {
    final handles = await _pump(tester, photos: 8);

    expect(_primaryLabels(tester), ['Chia sẻ hồ sơ']);
    await _tapPrimary(tester, 'Chia sẻ hồ sơ');
    expect(handles.location, '/u/$detailPhotographerUid');
  });

  testWidgets('exactly one primary button', (tester) async {
    for (final photos in [0, 8]) {
      await _pump(tester, photos: photos, completeness: 40);
      expect(_primaryLabels(tester), hasLength(1));
    }
  });

  testWidgets('the calendar stays reachable from the empty state', (
    tester,
  ) async {
    final handles = await _pump(tester, photos: 8);
    await tester.tap(find.byKey(const Key('open-calendar')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(handles.location, '/work/calendar');
  });

  group('S06.02 closed variant (Decision 17)', () {
    const closed = PhotographerIntro(onboardingComplete: true);

    testWidgets('a photographer not accepting orders sees "Mở nhận đơn để '
        'khách đặt được bạn", the body and the note', (tester) async {
      await _pump(tester, photos: 8, intro: closed);

      expect(find.text('Mở nhận đơn để khách đặt được bạn'), findsOneWidget);
      expect(
        find.text(
          'Bạn vẫn đăng portfolio, tạo gói và trò chuyện. Khách chỉ đặt lịch '
          'và xin báo giá sau khi bạn xác minh: số điện thoại, phí xác minh, '
          'danh tính và quy định nhận việc.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Staff duyệt trong 24 giờ sau khi bạn gửi'),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.verifiedUser), findsOneWidget);
      expect(find.text('Buổi chụp tiếp theo bắt đầu từ đây'), findsNothing);
    });

    testWidgets('"Bắt đầu nhận đơn" is hidden while verifyStartReadyProvider '
        'is false', (tester) async {
      await _pump(
        tester,
        photos: 8,
        intro: closed,
        extraOverrides: [verifyStartReadyProvider.overrideWithValue(false)],
      );

      expect(find.text('Bắt đầu nhận đơn'), findsNothing);
      expect(find.text('Mở nhận đơn để khách đặt được bạn'), findsOneWidget);
      expect(_primaryLabels(tester), isEmpty);
    });

    testWidgets('with the flag overridden to true it pushes /verify/start', (
      tester,
    ) async {
      final handles = await _pump(
        tester,
        photos: 8,
        intro: closed,
        extraOverrides: [verifyStartReadyProvider.overrideWithValue(true)],
      );

      expect(_primaryLabels(tester), ['Bắt đầu nhận đơn']);
      await _tapPrimary(tester, 'Bắt đầu nhận đơn');
      expect(handles.location, '/verify/start');
    });

    testWidgets('an accepting photographer keeps the old empty state '
        '("Buổi chụp tiếp theo bắt đầu từ đây")', (tester) async {
      await _pump(
        tester,
        photos: 8,
        intro: const PhotographerIntro(acceptingOrders: true),
        extraOverrides: [verifyStartReadyProvider.overrideWithValue(true)],
      );

      expect(find.text('Buổi chụp tiếp theo bắt đầu từ đây'), findsOneWidget);
      expect(find.text('Bắt đầu nhận đơn'), findsNothing);
      expect(_primaryLabels(tester), ['Chia sẻ hồ sơ']);
    });

    testWidgets('closed variant fits 320 dp at 1.3× text', (tester) async {
      await _pump(
        tester,
        photos: 8,
        intro: closed,
        extraOverrides: [verifyStartReadyProvider.overrideWithValue(true)],
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Bắt đầu nhận đơn'), findsOneWidget);
    });
  });
}

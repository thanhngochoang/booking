import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/work/work_empty.dart';

import '../../support/booking_world.dart';

/// Thursday 08/10 09:00 in Vietnam.
final _now = DateTime.utc(2026, 10, 8, 2);

Future<BookingsTabHandles> _pump(
  WidgetTester tester, {
  required int photos,
  bool package = true,
  int? completeness = 90,
}) async {
  final handles = await pumpBookingsTab(
    tester,
    uid: detailPhotographerUid,
    role: UserRole.photographer,
    now: _now,
    portfolioPhotos: photos,
    packages: package ? const [workPackage] : const [],
    completeness: completeness,
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
}

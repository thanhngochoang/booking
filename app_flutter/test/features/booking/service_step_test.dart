// test/features/booking/service_step_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/features/booking/booking_flow_controller.dart';
import 'package:photobooking/features/booking/steps/service_step.dart';
import 'package:photobooking/features/photographer_profile/profile_providers.dart';

import '../../support/booking_world.dart';

void main() {
  testWidgets('lists active packages cheapest first with name and price', (
    tester,
  ) async {
    const pExpensive = ServiceSummary(
      id: 's_exp',
      photographerId: 'p1',
      name: 'Gói VIP',
      priceVnd: 5000000,
      durationMinutes: 180,
      active: true,
    );
    const pCheap = ServiceSummary(
      id: 's_cheap',
      photographerId: 'p1',
      name: 'Gói Tiết Kiệm',
      priceVnd: 800000,
      durationMinutes: 60,
      active: true,
    );

    await pumpBookingRoute(
      tester,
      packages: [pExpensive, pCheap],
    );
    await tester.pumpAndSettle();

    expect(find.byType(ScreenCode), findsWidgets);
    expect(find.text('Chọn gói'), findsOneWidget);
    expect(find.text('Gói Tiết Kiệm'), findsOneWidget);
    expect(find.text('Gói VIP'), findsOneWidget);
    expect(find.text('800.000₫'), findsOneWidget);
    expect(find.text('5.000.000₫'), findsOneWidget);
  });

  testWidgets('the button shows the total and is disabled until a package is chosen', (
    tester,
  ) async {
    await pumpBookingRoute(tester);
    await tester.pumpAndSettle();

    final buttonFinder = find.byType(AppButton);
    expect(buttonFinder, findsOneWidget);

    final appButton = tester.widget<AppButton>(buttonFinder);
    expect(appButton.onPressed, isNull);
    expect(find.text('Tiếp tục · 0₫'), findsOneWidget);

    await tester.tap(find.text('Gói Chân Dung'));
    await tester.pumpAndSettle();

    final appButtonActive = tester.widget<AppButton>(buttonFinder);
    expect(appButtonActive.onPressed, isNotNull);
    expect(find.text('Tiếp tục · 1.500.000₫'), findsOneWidget);
  });

  testWidgets('a single package is preselected and the button is enabled', (
    tester,
  ) async {
    await pumpBookingRoute(
      tester,
      packages: [bookingPackage1],
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.byType(AppButton);
    final appButton = tester.widget<AppButton>(buttonFinder);
    expect(appButton.onPressed, isNotNull);
    expect(find.text('Tiếp tục · 1.500.000₫'), findsOneWidget);
  });

  testWidgets('no packages shows Nhiếp ảnh gia chưa đăng gói and Đóng closes', (
    tester,
  ) async {
    await pumpBookingRoute(
      tester,
      emptyPackages: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhiếp ảnh gia chưa đăng gói'), findsOneWidget);
    expect(find.text('Đóng'), findsOneWidget);

    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-sheet')), findsNothing);
  });

  testWidgets('first load shows AppOptionTile.skeleton', (tester) async {
    final completer = Completer<List<ServiceSummary>>();
    await pumpBookingRoute(
      tester,
      extraOverrides: [
        profilePackagesProvider('p1').overrideWith(
          (ref) => completer.future,
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(AsyncView<List<ServiceSummary>>), findsOneWidget);
    expect(find.byType(AppSkeleton), findsWidgets);
  });

  testWidgets('load error shows retry; retry reloads', (tester) async {
    var shouldFail = true;
    await pumpBookingRoute(
      tester,
      extraOverrides: [
        profilePackagesProvider('p1').overrideWith((ref) async {
          if (shouldFail) {
            throw Exception('Network error');
          }
          return [bookingPackage1];
        }),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Gói Chân Dung'), findsOneWidget);
  });

  testWidgets('Giá gói đã đổi banner appears when priceChanged', (tester) async {
    await pumpBookingRoute(tester);
    await tester.pumpAndSettle();

    // Select package 1
    await tester.tap(find.text('Gói Chân Dung'));
    await tester.pumpAndSettle();

    // Trigger price change on controller
    final container = ProviderScope.containerOf(tester.element(find.byType(ServiceStep)));
    const args = BookingFlowArgs(photographerId: 'p1');
    final updatedPackage1 = ServiceSummary(
      id: bookingPackage1.id,
      photographerId: bookingPackage1.photographerId,
      name: bookingPackage1.name,
      priceVnd: 1800000,
      durationMinutes: bookingPackage1.durationMinutes,
      active: true,
    );
    container.read(bookingFlowControllerProvider(args).notifier).applyPackages([
      updatedPackage1,
      bookingPackage2,
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Giá gói đã đổi'), findsOneWidget);
    expect(find.text('Tiếp tục · 1.800.000₫'), findsOneWidget);
  });

  testWidgets('320 dp and 1.3× text, light and dark: no overflow; the button stays on screen', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;

      await pumpBookingRoute(
        tester,
        brightness: brightness,
        textScale: 1.3,
      );
      await tester.pumpAndSettle();

      final err = tester.takeException();
      expect(err, isNull);
      expect(find.byType(AppButton), findsOneWidget);
    }
  });
}

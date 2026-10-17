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

    await pumpBookingRoute(tester, packages: [pExpensive, pCheap]);
    await tester.pumpAndSettle();

    expect(find.byType(ScreenCode), findsWidgets);
    expect(find.text('Chọn gói'), findsOneWidget);
    expect(find.text('Gói Tiết Kiệm'), findsOneWidget);
    expect(find.text('Gói VIP'), findsOneWidget);
    expect(find.text('800.000₫'), findsOneWidget);
    expect(find.text('5.000.000₫'), findsOneWidget);
  });

  testWidgets(
    'the button shows the total and is disabled until a package is chosen',
    (tester) async {
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
    },
  );

  testWidgets('a single package is preselected and the button is enabled', (
    tester,
  ) async {
    await pumpBookingRoute(tester, packages: [bookingPackage1]);
    await tester.pumpAndSettle();

    final buttonFinder = find.byType(AppButton);
    final appButton = tester.widget<AppButton>(buttonFinder);
    expect(appButton.onPressed, isNotNull);
    expect(find.text('Tiếp tục · 1.500.000₫'), findsOneWidget);
  });

  testWidgets('no packages shows Nhiếp ảnh gia chưa đăng gói and Đóng closes', (
    tester,
  ) async {
    await pumpBookingRoute(tester, emptyPackages: true);
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
        profilePackagesProvider('p1').overrideWith((ref) => completer.future),
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

  testWidgets('Giá gói đã đổi banner appears when priceChanged', (
    tester,
  ) async {
    await pumpBookingRoute(tester);
    await tester.pumpAndSettle();

    // Select package 1
    await tester.tap(find.text('Gói Chân Dung'));
    await tester.pumpAndSettle();

    // Trigger price change on controller
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServiceStep)),
    );
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

  testWidgets(
    '320 dp and 1.3× text, light and dark: no overflow; the button stays on screen',
    (tester) async {
      const size = Size(320, 640);
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          const SizedBox(),
        ); // fresh ProviderScope per pass
        await pumpBookingRoute(
          tester,
          brightness: brightness,
          textScale: 1.3,
          viewSize: size,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(const Key('app-sheet'))).width, 320);
        expect(find.byType(ServiceStep), findsOneWidget);
        final button = find.byType(AppButton);
        expect(button, findsOneWidget);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
      }
    },
  );

  group('S04.01 "Thêm dịch vụ"', () {
    const couple = ServiceSummary(
      id: 's2',
      photographerId: 'p1',
      name: 'Cặp đôi nửa ngày',
      priceVnd: 3200000,
      durationMinutes: 240,
      active: true,
    );

    Future<void> pumpAddons(WidgetTester tester) async {
      await pumpBookingRoute(
        tester,
        packages: [bookingPortrait2h, couple],
        addons: [addonMakeup, addonRetouch, addonTransport],
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('the block shows under the chosen package and the button carries the total', (
      tester,
    ) async {
      await pumpAddons(tester);
      expect(find.text('Thêm dịch vụ'), findsNothing);

      await tester.tap(find.text('Chân dung 2 giờ'));
      await tester.pump();
      expect(find.text('Thêm dịch vụ'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('addon-a_makeup-plus')));
      await tester.tap(find.byKey(const Key('addon-a_makeup-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('addon-a_makeup-plus')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('addon-a_car-check')));
      await tester.tap(find.byKey(const Key('addon-a_car-check')));
      await tester.pump();

      expect(find.text('Tiếp tục · 3.400.000₫'), findsOneWidget);
    });

    testWidgets('the dropped bar text is "Đã bỏ Xe đón trong nội thành vì không áp dụng cho gói này"', (
      tester,
    ) async {
      await pumpAddons(tester);
      await tester.tap(find.text('Chân dung 2 giờ'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('addon-a_car-check')));
      await tester.tap(find.byKey(const Key('addon-a_car-check')));
      await tester.pump();

      await tester.ensureVisible(find.text('Cặp đôi nửa ngày'));
      await tester.tap(find.text('Cặp đôi nửa ngày'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Đã bỏ Xe đón trong nội thành vì không áp dụng cho gói này'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('addon-a_car-check')), findsNothing);
      expect(find.text('Tiếp tục · 3.200.000₫'), findsOneWidget);
    });

    testWidgets('one AppButton.primary', (tester) async {
      await pumpAddons(tester);
      await tester.tap(find.text('Chân dung 2 giờ'));
      await tester.pump();
      expect(find.byType(CtaSurface), findsOneWidget);
    });

    testWidgets('320 dp and 1.3× text with add-ons: no overflow', (tester) async {
      await pumpBookingRoute(
        tester,
        packages: [bookingPortrait2h, couple],
        addons: [addonMakeup, addonRetouch, addonTransport],
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Chân dung 2 giờ'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Thêm dịch vụ'), findsOneWidget);
    });
  });
}

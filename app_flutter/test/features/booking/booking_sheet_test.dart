// test/features/booking/booking_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';

import '../../support/booking_world.dart';

void main() {
  testWidgets('the previous screen stays visible under the dimmed sheet', (
    tester,
  ) async {
    final handles = await pumpBookingRoute(tester, path: '/u/p1');
    await tester.pumpAndSettle();

    expect(find.byType(PhotographerProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('app-sheet')), findsNothing);

    handles.router.push('/u/p1/book');
    await tester.pumpAndSettle();

    expect(find.byType(PhotographerProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('app-sheet')), findsOneWidget);
  });

  testWidgets(
    'a customer without a phone is replaced by S04.05 with returnTo of the flow',
    (tester) async {
      final handles = await pumpBookingRoute(
        tester,
        path: '/u/p1/book',
        contact: null,
      );
      await tester.pumpAndSettle();

      expect(
        handles.router.state.uri.toString(),
        contains('/profile/phone?returnTo=%2Fu%2Fp1%2Fbook'),
      );
    },
  );

  testWidgets(
    'Back on step 1 without choices closes the sheet; the barrier tap does not close',
    (tester) async {
      final handles = await pumpBookingRoute(tester, path: '/u/p1');
      await tester.pumpAndSettle();

      handles.router.push('/u/p1/book');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app-sheet')), findsOneWidget);

      // Barrier tap does not close
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-sheet')), findsOneWidget);

      // Back without choices closes immediately
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-sheet')), findsNothing);
    },
  );

  testWidgets(
    'Back on step 1 after choosing asks Bỏ yêu cầu đặt lịch? (Tiếp tục đặt keeps it, Bỏ closes)',
    (tester) async {
      final handles = await pumpBookingRoute(tester, path: '/u/p1');
      await tester.pumpAndSettle();

      handles.router.push('/u/p1/book');
      await tester.pumpAndSettle();

      // Make a choice
      await tester.tap(find.text('Gói Chân Dung'));
      await tester.pumpAndSettle();

      // Trigger back
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Confirm sheet appears
      expect(find.text('Bỏ yêu cầu đặt lịch?'), findsOneWidget);
      expect(find.text('Tiếp tục đặt'), findsOneWidget);
      expect(find.text('Bỏ'), findsOneWidget);

      // Tap "Tiếp tục đặt" -> stays
      await tester.tap(find.text('Tiếp tục đặt'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-sheet')), findsOneWidget);
      expect(find.text('Bỏ yêu cầu đặt lịch?'), findsNothing);

      // Trigger back again -> tap "Bỏ" -> closes
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Bỏ yêu cầu đặt lịch?'), findsOneWidget);

      await tester.tap(find.text('Bỏ'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-sheet')), findsNothing);
    },
  );

  testWidgets(
    'Back on step 2 goes to step 1 with the package still selected',
    (tester) async {
      await pumpBookingRoute(tester, path: '/u/p1/book');
      await tester.pumpAndSettle();

      // Select package
      await tester.tap(find.text('Gói Chân Dung'));
      await tester.pumpAndSettle();

      // Tap next (step 1 -> step 2)
      await tester.tap(find.text('Tiếp tục · 1.500.000₫'));
      await tester.pumpAndSettle();

      expect(find.text('DateTimeStep'), findsOneWidget);

      // Back from step 2
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Chọn gói'), findsOneWidget);
      expect(find.text('Tiếp tục · 1.500.000₫'), findsOneWidget);
    },
  );

  testWidgets('reduced motion shows the sheet without the slide', (
    tester,
  ) async {
    await pumpBookingRoute(
      tester,
      path: '/u/p1/book',
      disableAnimations: true,
    );
    await tester.pump();

    expect(find.byKey(const Key('app-sheet')), findsOneWidget);
    expect(find.byType(SlideTransition), findsNothing);
  });
}

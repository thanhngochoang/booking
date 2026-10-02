// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('first load shows the given skeleton', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        AsyncView<String>(
          value: const AsyncValue<String>.loading(),
          skeleton: (_) => const Text('Custom Skeleton'),
          data: (context, val) => Text(val),
        ),
      ),
    );

    // Initial render within 150ms: nothing shown due to anti-flash delay
    expect(find.text('Custom Skeleton'), findsNothing);

    // Advance 150ms
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Custom Skeleton'), findsOneWidget);
  });

  testWidgets('first load without skeleton shows the screen loader with ripple waves', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        AsyncView<String>(
          value: const AsyncValue<String>.loading(),
          data: (context, val) => Text(val),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(SignatureLoader), findsOneWidget);
    final loader = tester.widget<SignatureLoader>(find.byType(SignatureLoader));
    expect(loader.size, LoaderSize.screen);
    expect(loader.wave, LoaderWave.ripple);
  });

  testWidgets('reload keeps data and shows the inline loader', (tester) async {
    final valueNotifier = ValueNotifier<AsyncValue<String>>(
      const AsyncValue<String>.data('initial data'),
    );

    await tester.pumpWidget(
      hostWidget(
        ValueListenableBuilder<AsyncValue<String>>(
          valueListenable: valueNotifier,
          builder: (context, val, _) => AsyncView<String>(
            value: val,
            data: (context, data) => Text('DATA: $data'),
          ),
        ),
      ),
    );

    expect(find.text('DATA: initial data'), findsOneWidget);
    expect(find.byType(SignatureLoader), findsNothing);

    // Transition to loading with previous value preserved
    valueNotifier.value = const AsyncLoading<String>().copyWithPrevious(
      const AsyncData('initial data'),
    );
    await tester.pump();

    // Still shows the data
    expect(find.text('DATA: initial data'), findsOneWidget);

    // Shows the inline loader
    final loaderFinder = find.byWidgetPredicate(
      (w) => w is SignatureLoader && w.size == LoaderSize.inline,
    );
    expect(loaderFinder, findsOneWidget);
  });

  testWidgets(
    'no flash: data within 150 ms shows no skeleton/loader at all; once shown, the skeleton stays at least 400 ms',
    (tester) async {
      final valueNotifier = ValueNotifier<AsyncValue<String>>(
        const AsyncValue<String>.loading(),
      );

      await tester.pumpWidget(
        hostWidget(
          ValueListenableBuilder<AsyncValue<String>>(
            valueListenable: valueNotifier,
            builder: (context, val, _) => AsyncView<String>(
              value: val,
              skeleton: (_) => const Text('MY_SKELETON'),
              data: (context, data) => Text('DATA: $data'),
            ),
          ),
        ),
      );

      // Part 1: Fast data arriving before 150ms -> no skeleton ever shown
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('MY_SKELETON'), findsNothing);
      expect(find.text('DATA: fast data'), findsNothing);

      valueNotifier.value = const AsyncValue<String>.data('fast data');
      await tester.pump();
      expect(find.text('MY_SKELETON'), findsNothing);
      expect(find.text('DATA: fast data'), findsOneWidget);

      // Part 2: Now transition to a fresh load (no previous value)
      valueNotifier.value = const AsyncLoading<String>();
      await tester.pump();

      // Wait 160ms: skeleton should now be shown
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.text('MY_SKELETON'), findsOneWidget);

      // Data arrives now (skeleton shown at ~160ms)
      valueNotifier.value = const AsyncValue<String>.data('slow data');
      await tester.pump();

      // Even though data arrived, skeleton must stay for at least 400ms!
      expect(find.text('MY_SKELETON'), findsOneWidget);
      expect(find.text('DATA: slow data'), findsNothing);

      // Advance 200ms
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('MY_SKELETON'), findsOneWidget);
      expect(find.text('DATA: slow data'), findsNothing);

      // Advance remaining time (e.g. 210ms -> total > 400ms)
      await tester.pump(const Duration(milliseconds: 210));
      expect(find.text('MY_SKELETON'), findsNothing);
      expect(find.text('DATA: slow data'), findsOneWidget);
    },
  );

  testWidgets('error shows ErrorState with retry calling onRetry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      hostWidget(
        AsyncView<String>(
          value: AsyncValue<String>.error(
            Exception('network error'),
            StackTrace.empty,
          ),
          onRetry: () => retried = true,
          data: (context, val) => Text(val),
        ),
      ),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    await tester.tap(find.byKey(const Key('error-retry')));
    expect(retried, isTrue);
  });

  testWidgets('error with old data keeps the data and shows one SnackBar', (
    tester,
  ) async {
    final valueNotifier = ValueNotifier<AsyncValue<String>>(
      const AsyncValue<String>.data('old data'),
    );

    await tester.pumpWidget(
      hostWidget(
        ValueListenableBuilder<AsyncValue<String>>(
          valueListenable: valueNotifier,
          builder: (context, val, _) => AsyncView<String>(
            value: val,
            data: (context, data) => Text('DATA: $data'),
          ),
        ),
      ),
    );

    expect(find.text('DATA: old data'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    // Update to error with previous value preserved
    valueNotifier.value = AsyncError<String>(
      Exception('network disconnected'),
      StackTrace.empty,
    ).copyWithPrevious(const AsyncData('old data'));

    await tester.pump();
    await tester.pump(); // allow post-frame callback to show snackbar

    expect(find.text('DATA: old data'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('empty shows the empty builder', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        AsyncView<List<String>>(
          value: const AsyncValue<List<String>>.data([]),
          isEmpty: (list) => list.isEmpty,
          empty: (_) => const Text('DANH SÁCH TRỐNG'),
          data: (context, val) => Text('Count: ${val.length}'),
        ),
      ),
    );

    expect(find.text('DANH SÁCH TRỐNG'), findsOneWidget);
    expect(find.text('Count: 0'), findsNothing);
  });
}

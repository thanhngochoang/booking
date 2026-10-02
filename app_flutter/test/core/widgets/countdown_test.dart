// test/core/widgets/countdown_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/countdown.dart';

import 'widget_host.dart';

void main() {
  group('CountdownRing & CountdownText', () {
    testWidgets('ticks every minute above an hour and every second below', (
      tester,
    ) async {
      var currentTime = DateTime(2026, 10, 2, 10, 0, 0);
      final deadline = DateTime(2026, 10, 2, 12, 0, 0); // 2 hours left

      Duration? reportedLeft;
      await tester.pumpWidget(
        hostWidget(
          CountdownText(
            deadline: deadline,
            now: () => currentTime,
            builder: (context, left) {
              reportedLeft = left;
              return Text('Left: ${left.inSeconds}s');
            },
          ),
        ),
      );

      expect(reportedLeft?.inHours, 2);

      // Above 1h: advance 10s should not trigger a tick
      currentTime = currentTime.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(reportedLeft?.inHours, 2);

      // Advance 1 minute: triggers a tick
      currentTime = currentTime.add(const Duration(seconds: 50));
      await tester.pump(const Duration(seconds: 50));
      expect(reportedLeft?.inMinutes, 119);

      // Advance to 50 minutes left (< 1h)
      currentTime = DateTime(2026, 10, 2, 11, 10, 0);
      await tester.pump(const Duration(minutes: 1));
      expect(reportedLeft?.inMinutes, 50);

      // Below 1h: ticks every second
      currentTime = currentTime.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(reportedLeft?.inSeconds, 50 * 60 - 1);
    });

    testWidgets('stops at zero and calls onExpired once', (tester) async {
      var currentTime = DateTime(2026, 10, 2, 10, 0, 0);
      final deadline = DateTime(2026, 10, 2, 10, 0, 3); // 3 seconds left

      var expiredCount = 0;
      await tester.pumpWidget(
        hostWidget(
          CountdownRing(
            deadline: deadline,
            total: const Duration(seconds: 10),
            now: () => currentTime,
            onExpired: () => expiredCount++,
          ),
        ),
      );

      expect(expiredCount, 0);

      // Advance 3 seconds -> reaches 0
      currentTime = currentTime.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(expiredCount, 1);

      // Advance further -> no additional calls
      currentTime = currentTime.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(expiredCount, 1);
    });

    testWidgets(
      'semantics timer reads label on focus and announces only at thresholds',
      (tester) async {
        final handle = tester.ensureSemantics();
        var currentTime = DateTime(2026, 10, 2, 10, 0, 0);
        // Deadline in 47 seconds
        var deadline = DateTime(2026, 10, 2, 10, 0, 47);

        await tester.pumpWidget(
          hostWidget(
            CountdownRing(
              deadline: deadline,
              total: const Duration(minutes: 1),
              now: () => currentTime,
            ),
          ),
        );

        // Semantics label readable on focus
        expect(find.bySemanticsLabel('Còn 47 giây'), findsOneWidget);

        // At 47s, liveRegion is false
        var semantics = tester.widget<Semantics>(
          find
              .ancestor(of: find.text('47'), matching: find.byType(Semantics))
              .first,
        );
        expect(semantics.properties.liveRegion, isFalse);

        // At 10s threshold, liveRegion is true
        currentTime = DateTime(2026, 10, 2, 10, 0, 37); // left = 10s
        await tester.pump(const Duration(seconds: 1));
        semantics = tester.widget<Semantics>(
          find
              .ancestor(of: find.text('10'), matching: find.byType(Semantics))
              .first,
        );
        expect(semantics.properties.liveRegion, isTrue);

        // At 0s threshold, liveRegion is true
        currentTime = DateTime(2026, 10, 2, 10, 0, 47); // left = 0s
        await tester.pump(const Duration(seconds: 1));
        semantics = tester.widget<Semantics>(
          find
              .ancestor(of: find.text('0'), matching: find.byType(Semantics))
              .first,
        );
        expect(semantics.properties.liveRegion, isTrue);

        handle.dispose();
      },
    );

    testWidgets('reduced motion: no ticker or smooth interpolation', (
      tester,
    ) async {
      final currentTime = DateTime(2026, 10, 2, 10, 0, 0);
      final deadline = DateTime(2026, 10, 2, 10, 1, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: CountdownRing(
              deadline: deadline,
              total: const Duration(minutes: 1),
              now: () => currentTime,
            ),
          ),
        ),
      );

      // Rendered cleanly without throwing
      expect(tester.takeException(), isNull);
    });

    testWidgets('no ticker after expiry', (tester) async {
      var currentTime = DateTime(2026, 10, 2, 10, 0, 0);
      final deadline = DateTime(2026, 10, 2, 10, 0, 1);

      await tester.pumpWidget(
        hostWidget(
          CountdownRing(
            deadline: deadline,
            total: const Duration(seconds: 5),
            now: () => currentTime,
          ),
        ),
      );

      // Reach zero
      currentTime = currentTime.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));

      // Pumping frames should not have active periodic tickers
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('UploadProgressRing', () {
    testWidgets('draws fraction 0..1 clamped, semantics value "{n}%"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        hostWidget(const UploadProgressRing(fraction: 0.45)),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '45%',
        ),
        findsOneWidget,
      );

      // Clamped > 1
      await tester.pumpWidget(
        hostWidget(const UploadProgressRing(fraction: 1.5)),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.value == '100%',
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}

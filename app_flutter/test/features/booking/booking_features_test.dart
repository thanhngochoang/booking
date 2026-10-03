import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/features/booking/booking_features.dart';

void main() {
  group('BookingFeatures & nowTickerProvider', () {
    test('all flags are off by default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final features = container.read(bookingFeaturesProvider);
      expect(features.chat, isFalse);
      expect(features.reschedule, isFalse);
      expect(features.review, isFalse);
    });

    testWidgets(
      'nowTickerProvider emits the clock now and again after each period',
      (tester) async {
        var currentTime = DateTime.utc(2026, 10, 10, 10, 0);
        final container = ProviderContainer(
          overrides: [
            clockProvider.overrideWithValue(() => currentTime),
          ],
        );

        final emissions = <DateTime>[];
        final sub = container.listen(
          nowTickerProvider(const Duration(milliseconds: 50)),
          (_, next) {
            if (next.hasValue) {
              emissions.add(next.value!);
            }
          },
        );

        // Initial emission
        await tester.pump(Duration.zero);
        expect(emissions.length, 1);
        expect(emissions.first, currentTime);

        // Advance period
        currentTime = currentTime.add(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        expect(emissions.length, 2);
        expect(emissions.last, currentTime);

        // Advance another period
        currentTime = currentTime.add(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        expect(emissions.length, 3);
        expect(emissions.last, currentTime);

        // Clean up before test finishes to ensure no pending timer
        sub.close();
        container.dispose();
        await tester.pump(Duration.zero);
      },
    );
  });
}

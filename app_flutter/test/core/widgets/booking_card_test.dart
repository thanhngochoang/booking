// test/core/widgets/booking_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/booking_card.dart';
import 'package:photobooking/data/booking/booking_status.dart';

import 'widget_host.dart';

const _sampleSummary = BookingSummary(
  photographerName: 'Minh Trí',
  serviceName: 'Chân dung 2 giờ',
  day: '2026-10-12',
  start: '15:30',
  end: '17:30',
  placeName: 'Bến Bạch Đằng',
  status: BookingStatus.requested,
);

void main() {
  testWidgets(
    'renders normal and compact size, status badge and label override',
    (tester) async {
      // Normal size with default status badge
      await tester.pumpWidget(
        hostWidget(const BookingCard(data: _sampleSummary)),
      );

      expect(find.text('Minh Trí · Chân dung 2 giờ'), findsOneWidget);
      expect(find.text('Bến Bạch Đằng'), findsOneWidget);
      expect(find.text('ĐÃ GỬI'), findsOneWidget);

      // Compact size with statusLabel override
      const compactSummary = BookingSummary(
        photographerName: 'Minh Trí',
        serviceName: 'Chân dung 2 giờ',
        day: '2026-10-12',
        start: '15:30',
        end: '17:30',
        placeName: 'Bến Bạch Đằng',
        status: BookingStatus.requested,
        statusLabel: 'Chờ cọc',
      );

      await tester.pumpWidget(
        hostWidget(
          const BookingCard(
            data: compactSummary,
            size: BookingCardSize.compact,
          ),
        ),
      );

      expect(find.text('Chờ cọc'), findsOneWidget);
    },
  );

  testWidgets('tap and actions row work', (tester) async {
    var tapped = false;
    var actionTapped = false;

    await tester.pumpWidget(
      hostWidget(
        BookingCard(
          data: _sampleSummary,
          onTap: () => tapped = true,
          actions: TextButton(
            onPressed: () => actionTapped = true,
            child: const Text('Nhắn tin'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Nhắn tin'));
    expect(actionTapped, isTrue);

    await tester.tap(find.text('Minh Trí · Chân dung 2 giờ'));
    expect(tapped, isTrue);
  });

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          const BookingCard(data: _sampleSummary),
          width: 320,
          textScale: 1.3,
          brightness: brightness,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('skeleton has same size as real widget at 390 and 320 dp', (
    tester,
  ) async {
    for (final width in [390.0, 320.0]) {
      for (final size in [BookingCardSize.normal, BookingCardSize.compact]) {
        await tester.pumpWidget(
          hostWidget(
            BookingCard(data: _sampleSummary, size: size),
            width: width,
          ),
        );
        final realSize = tester.getSize(find.byType(BookingCard));

        await tester.pumpWidget(
          hostWidget(
            AppSkeletonScope(child: BookingCard.skeleton(size: size)),
            width: width,
          ),
        );
        final skeletonSize = tester.getSize(
          find.byWidgetPredicate(
            (w) => w.key == const ValueKey('booking_card_skeleton'),
          ),
        );

        expect(skeletonSize.width, realSize.width);
        expect(skeletonSize.height, realSize.height);
      }
    }
  });
}

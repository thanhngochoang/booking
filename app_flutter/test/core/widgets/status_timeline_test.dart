// test/core/widgets/status_timeline_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/status_timeline.dart';

import 'widget_host.dart';

const _sampleSteps = [
  TimelineStep(
    title: 'Đã gửi & đặt cọc',
    subtitle: 'Hôm nay 9:41 · 450.000₫',
    state: TimelineStepState.done,
  ),
  TimelineStep(
    title: 'Chờ Minh Trí nhận',
    subtitle: 'Thường trong 1 giờ',
    state: TimelineStepState.current,
  ),
  TimelineStep(title: 'Đã xác nhận', state: TimelineStepState.upcoming),
];

void main() {
  testWidgets('renders all states and semantics reads step progress', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      hostWidget(const StatusTimeline(steps: _sampleSteps)),
    );

    expect(find.text('Đã gửi & đặt cọc'), findsOneWidget);
    expect(find.text('Hôm nay 9:41 · 450.000₫'), findsOneWidget);
    expect(find.text('Chờ Minh Trí nhận'), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsOneWidget);

    // Semantics reads "Bước {n} trong {total}, {state}"
    expect(
      find.bySemanticsLabel(RegExp(r'Bước 1 trong 3.*đã xong')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Bước 2 trong 3.*đang diễn ra')),
      findsOneWidget,
    );

    handle.dispose();
  });

  testWidgets('stopped state uses danger/destructive styling', (tester) async {
    const stoppedSteps = [
      TimelineStep(title: 'Yêu cầu', state: TimelineStepState.done),
      TimelineStep(
        title: 'Đã huỷ',
        subtitle: 'Khách huỷ',
        state: TimelineStepState.stopped,
      ),
    ];

    await tester.pumpWidget(
      hostWidget(const StatusTimeline(steps: stoppedSteps)),
    );

    expect(find.text('Đã huỷ'), findsOneWidget);

    final dot = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('timeline_dot_1')),
    );
    final boxDecoration = dot.decoration as BoxDecoration;
    expect(
      boxDecoration.color,
      anyOf(AppColors.destructive, AppColorsDark.destructive),
    );
  });

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          const StatusTimeline(steps: _sampleSteps),
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
      await tester.pumpWidget(
        hostWidget(const StatusTimeline(steps: _sampleSteps), width: width),
      );
      final realSize = tester.getSize(find.byType(StatusTimeline));

      await tester.pumpWidget(
        hostWidget(
          AppSkeletonScope(child: StatusTimeline.skeleton(steps: 3)),
          width: width,
        ),
      );
      final skeletonSize = tester.getSize(
        find.byWidgetPredicate(
          (w) => w.key == const ValueKey('status_timeline_skeleton'),
        ),
      );

      expect(skeletonSize.width, realSize.width);
      expect(skeletonSize.height, realSize.height);
    }
  });
}

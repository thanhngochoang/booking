// test/core/widgets/escrow_notice_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/widgets/app_skeleton.dart';
import 'package:photobooking/core/widgets/escrow_notice.dart';

import 'widget_host.dart';

const _defaultText =
    'Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành.';

void main() {
  testWidgets('lock icon and text read as one container', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const EscrowNotice(text: _defaultText)));

    // Semantics container exists and includes the text
    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.container == true),
      findsWidgets,
    );
    expect(find.text(_defaultText), findsOneWidget);
    handle.dispose();
  });

  testWidgets('renders cleanly at 320dp and 1.3x text in dark and light', (
    tester,
  ) async {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        hostWidget(
          const EscrowNotice(text: _defaultText),
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
        hostWidget(const EscrowNotice(text: _defaultText), width: width),
      );
      final realSize = tester.getSize(find.byType(EscrowNotice));

      await tester.pumpWidget(
        hostWidget(
          AppSkeletonScope(child: EscrowNotice.skeleton()),
          width: width,
        ),
      );
      final skeletonSize = tester.getSize(
        find.byWidgetPredicate(
          (w) => w.key == const ValueKey('escrow_notice_skeleton'),
        ),
      );

      expect(skeletonSize.width, realSize.width);
      expect(skeletonSize.height, realSize.height);
    }
  });
}

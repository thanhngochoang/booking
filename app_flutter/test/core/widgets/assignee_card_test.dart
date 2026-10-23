import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/screen_host.dart';

const _minh = AssigneeSummary(
  id: 'minh',
  name: 'Minh Trí',
  verified: true,
  tomatoPct: 97,
  shoots: 112,
);

Future<void> _pump(
  WidgetTester tester, {
  AssigneeSummary summary = _minh,
  String studioName = 'Studio Mây',
  String? changeLabel = 'Xin đổi thợ (1 lần)',
  VoidCallback? onChange,
  VoidCallback? onViewProfile,
  double width = 390,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    screenApp(
      textScale: textScale,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AssigneeCard(
            summary: summary,
            studioName: studioName,
            changeLabel: changeLabel,
            onChange: onChange,
            onViewProfile: onViewProfile ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the name, tick, %, shoots and studio, and both buttons', (
    tester,
  ) async {
    var viewed = 0;
    var changed = 0;
    await _pump(
      tester,
      onViewProfile: () => viewed++,
      onChange: () => changed++,
    );

    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.byType(ProviderMark), findsOneWidget);
    expect(find.textContaining('97%'), findsOneWidget);
    expect(
      find.textContaining('112 buổi · thợ của Studio Mây'),
      findsOneWidget,
    );

    await tester.tap(find.text('Xem hồ sơ'));
    await tester.tap(find.text('Xin đổi thợ (1 lần)'));
    expect((viewed, changed), (1, 1));
  });

  testWidgets('semantics read name, %, studio; buttons ≥ 48 dp', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, onChange: () {});

    expect(
      find.bySemanticsLabel(
        'Minh Trí, Đã xác minh, 97% cà chua · 112 buổi · thợ của Studio Mây',
      ),
      findsOneWidget,
    );
    for (final key in ['assignee-view-profile', 'assignee-change']) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48), reason: key);
      expect(size.width, greaterThanOrEqualTo(48), reason: key);
    }
    handle.dispose();
  });

  testWidgets('a pending change is disabled; no label, no button', (
    tester,
  ) async {
    await _pump(tester, changeLabel: 'Đã xin đổi · chờ studio');
    expect(
      tester
          .widget<AppButton>(find.byKey(const Key('assignee-change')))
          .onPressed,
      isNull,
    );

    await _pump(tester, changeLabel: null);
    expect(find.byKey(const Key('assignee-change')), findsNothing);
  });

  testWidgets('no studio name and too few reviews leave those parts out', (
    tester,
  ) async {
    await _pump(
      tester,
      summary: const AssigneeSummary(id: 'an', name: 'An', shoots: 3),
      studioName: '',
    );
    expect(find.text('3 buổi'), findsOneWidget);
    expect(find.textContaining('thợ của'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(ProviderMark), findsNothing);
  });

  testWidgets('the skeleton has the card shape', (tester) async {
    await tester.pumpWidget(
      screenApp(home: Scaffold(body: AssigneeCard.skeleton())),
    );
    expect(find.byType(AppSkeleton), findsWidgets);
  });

  testWidgets('fits 320dp at 1.3x text', (tester) async {
    await _pump(
      tester,
      summary: const AssigneeSummary(
        id: 'x',
        name: 'Nguyễn Hoàng Minh Trí Phương',
        verified: true,
        tomatoPct: 97,
        shoots: 1120,
      ),
      studioName: 'Studio Mây Trắng Sài Gòn',
      onChange: () {},
      width: 320,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}

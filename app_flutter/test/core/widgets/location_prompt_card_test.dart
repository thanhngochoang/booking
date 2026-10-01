import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _card(
  LocationPromptState state, {
  VoidCallback? onAllow,
  VoidCallback? onLater,
  VoidCallback? onChoose,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) => hostWidget(
  LocationPromptCard(
    state: state,
    onAllow: onAllow ?? () {},
    onLater: onLater ?? () {},
    onChooseArea: onChoose,
  ),
  width: width,
  textScale: textScale,
  brightness: brightness,
);

void main() {
  testWidgets('ask shows the explanation and both buttons', (tester) async {
    var allow = 0, later = 0;
    await tester.pumpWidget(
      _card(
        LocationPromptState.ask,
        onAllow: () => allow++,
        onLater: () => later++,
      ),
    );
    expect(find.text('Sự kiện gần bạn'), findsOneWidget);
    expect(
      find.text(
        'Cho phép dùng vị trí để gợi ý sự kiện trong bán kính 25 km. Vị trí chỉ xử lý trên máy.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('location-allow')));
    await tester.tap(find.byKey(const Key('location-later')));
    expect((allow, later), (1, 1));
  });

  testWidgets('only the ask state has the spectrum border', (tester) async {
    await tester.pumpWidget(_card(LocationPromptState.ask));
    expect(tester.widget<GlassCard>(find.byType(GlassCard)).highlight, isTrue);
    await tester.pumpWidget(_card(LocationPromptState.requesting));
    expect(tester.widget<GlassCard>(find.byType(GlassCard)).highlight, isFalse);
  });

  testWidgets('requesting disables both buttons and shows progress', (
    tester,
  ) async {
    var allow = 0;
    await tester.pumpWidget(
      _card(LocationPromptState.requesting, onAllow: () => allow++),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final handle = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel('Cho phép'), findsOneWidget);
    handle.dispose();
    await tester.tap(
      find.byKey(const Key('location-allow')),
      warnIfMissed: false,
    );
    expect(allow, 0);
  });

  testWidgets('denied collapses to a "Chọn khu vực" chip', (tester) async {
    var chosen = 0;
    await tester.pumpWidget(
      _card(LocationPromptState.denied, onChoose: () => chosen++),
    );
    expect(find.byType(GlassCard), findsNothing);
    expect(find.text('Cho phép'), findsNothing);
    await tester.tap(find.byKey(const Key('location-choose-area')));
    expect(chosen, 1);
  });

  testWidgets('denied without a handler is a programming error', (
    tester,
  ) async {
    expect(
      () => LocationPromptCard(
        state: LocationPromptState.denied,
        onAllow: () {},
        onLater: () {},
      ),
      throwsAssertionError,
    );
  });

  for (final b in Brightness.values) {
    testWidgets('ask fits 320dp at 1.3x on ${b.name}', (tester) async {
      await tester.pumpWidget(
        _card(
          LocationPromptState.ask,
          width: 320,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
      final allow = tester.getSize(find.byKey(const Key('location-allow')));
      final later = tester.getSize(find.byKey(const Key('location-later')));
      expect(allow.height, 52);
      expect(later.height, 52);
    });
  }
}

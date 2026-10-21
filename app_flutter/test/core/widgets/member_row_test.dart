import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/meta_finders.dart';
import '../../support/screen_host.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  double width = 390,
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = Size(width, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    screenApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: row),
      ),
      textScale: textScale,
      brightness: brightness,
    ),
  );
}

void main() {
  testWidgets('renders avatar, name, meta and trailing', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      MemberRow(
        name: 'Minh Trí',
        mark: ProviderMarkKind.verified,
        meta: const [MetaPart.tomato(97), MetaPart.text('2 việc đang giao')],
        trailing: const Text('…', key: Key('trailing')),
        onTap: () => taps++,
      ),
    );
    expect(find.byType(AppAvatar), findsOneWidget);
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.byType(VerifiedMark), findsOneWidget);
    expect(findMeta('97% · 2 việc đang giao'), findsOneWidget);
    expect(tomatoIconIn(findMeta('97% · 2 việc đang giao')), findsOneWidget);
    expect(find.byKey(const Key('trailing')), findsOneWidget);
    await tester.tap(find.text('Minh Trí'));
    expect(taps, 1);
  });

  testWidgets('disabled is dimmed and not tappable', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      MemberRow(
        name: 'Đức Anh',
        meta: const [MetaPart.text('Đang ở Studio Nắng')],
        enabled: false,
        onTap: () => taps++,
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Đức Anh'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, lessThan(1));
    await tester.tap(find.text('Đức Anh'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('semantics: one label with the mark and the spoken tomato; '
      'disabled rows say so', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Column(
        children: [
          MemberRow(
            name: 'Lan Phương',
            mark: ProviderMarkKind.verified,
            meta: const [MetaPart.tomato(95), MetaPart.text('Quận 3')],
            onTap: () {},
          ),
          const MemberRow(
            name: 'Bảo Ngọc',
            meta: [MetaPart.text('Mời được từ 14/10')],
            enabled: false,
          ),
        ],
      ),
    );
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Lan Phương, Đã xác minh, 95% cà chua · Quận 3'),
      ),
      matchesSemantics(
        label: 'Lan Phương, Đã xác minh, 95% cà chua · Quận 3',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Bảo Ngọc, Mời được từ 14/10')),
      matchesSemantics(
        label: 'Bảo Ngọc, Mời được từ 14/10',
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('a long name with two buttons fits 320dp at 1.3x '
        '($brightness)', (tester) async {
      await _pump(
        tester,
        MemberRow(
          name: 'Nguyễn Thị Hồng Nhung Phương Thảo',
          meta: const [MetaPart.text('Xin gia nhập · 2 giờ trước')],
          trailing: Wrap(
            alignment: WrapAlignment.end,
            children: [
              AppButton.outline(
                'Từ chối',
                size: AppButtonSize.xsmall,
                onPressed: () {},
              ),
              AppButton.outline(
                'Duyệt',
                size: AppButtonSize.xsmall,
                onPressed: () {},
              ),
            ],
          ),
        ),
        width: 320,
        textScale: 1.3,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('skeleton draws an avatar and two lines', (tester) async {
    await _pump(tester, MemberRow.skeleton());
    expect(find.byType(AppSkeleton), findsNWidgets(3));
  });
}

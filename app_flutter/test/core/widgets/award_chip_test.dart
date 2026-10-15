import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _wrap(Widget child, {double width = 390}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('vi'),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('chip shows the result and the competition line', (t) async {
    await t.pumpWidget(
      _wrap(
        const AwardChip(
          resultLabel: 'Huy chương Vàng',
          subtitle: 'VIPA 2024 · Phong cảnh',
        ),
      ),
    );
    expect(find.text('Huy chương Vàng'), findsOneWidget);
    expect(find.text('VIPA 2024 · Phong cảnh'), findsOneWidget);
    expect(t.getSize(find.byType(AwardChip)).width, 178);
  });

  testWidgets('chip skeleton matches its size', (t) async {
    await t.pumpWidget(_wrap(const AwardChip.skeleton()));
    expect(t.getSize(find.byType(AwardChip)).width, 178);
    final box = find.byKey(const ValueKey('award_chip_box'));
    await t.pumpWidget(
      _wrap(
        const AwardChip(resultLabel: 'Huy chương Vàng', subtitle: 'VIPA 2024'),
      ),
    );
    final h = t.getSize(box).height;
    await t.pumpWidget(_wrap(const AwardChip.skeleton()));
    expect(t.getSize(box).height, h);
  });

  testWidgets('result titles come from the localisation', (t) async {
    late AppLocalizations l;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Builder(
          builder: (c) {
            l = AppLocalizations.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(awardResultTitle(l, AwardResult.gold), 'Huy chương Vàng');
    expect(awardResultShortLabel(l, AwardResult.gold), 'Vàng / Nhất');
    expect(awardResultTitle(l, AwardResult.exhibited), 'Chọn triển lãm');
  });
}

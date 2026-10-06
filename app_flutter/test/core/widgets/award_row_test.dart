import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('vi'),
  home: Scaffold(body: SizedBox(width: 390, child: child)),
);

void main() {
  testWidgets('row shows the status badge with text', (t) async {
    await t.pumpWidget(
      _wrap(
        const AwardRow(
          title: 'Huy chương Vàng · VIPA 2024',
          subtitle: 'Phong cảnh',
          status: AwardStatus.pending,
        ),
      ),
    );
    expect(find.text('Huy chương Vàng · VIPA 2024'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.text('Phong cảnh'), findsOneWidget);
  });

  testWidgets('an approved row has the gold disc', (t) async {
    await t.pumpWidget(
      _wrap(
        const AwardRow(title: 'a', subtitle: 'b', status: AwardStatus.approved),
      ),
    );
    expect(find.byKey(const ValueKey('award_disc_gold')), findsOneWidget);
    expect(find.text('Đã duyệt'), findsOneWidget);
    await t.pumpWidget(
      _wrap(
        const AwardRow(title: 'a', subtitle: 'b', status: AwardStatus.rejected),
      ),
    );
    expect(find.byKey(const ValueKey('award_disc_gold')), findsNothing);
    expect(find.byKey(const ValueKey('award_disc_mute')), findsOneWidget);
  });

  testWidgets('a read-only row has no badge', (t) async {
    await t.pumpWidget(_wrap(const AwardRow(title: 'a', subtitle: 'b')));
    expect(find.byKey(const ValueKey('award_status_badge')), findsNothing);
    expect(find.byKey(const ValueKey('award_disc_gold')), findsOneWidget);
  });

  testWidgets('tap and long press reach the callbacks', (t) async {
    var tap = 0, long = 0;
    await t.pumpWidget(
      _wrap(
        AwardRow(
          title: 'a',
          subtitle: 'b',
          status: AwardStatus.pending,
          onTap: () => tap++,
          onLongPress: () => long++,
        ),
      ),
    );
    await t.tap(find.byType(AwardRow));
    await t.longPress(find.byType(AwardRow));
    expect([tap, long], [1, 1]);
  });
}

// test/features/event_create/spot_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_rules.dart';
import 'package:photobooking/features/event_create/spot_field.dart';

import '../../support/screen_host.dart';
import '../../support/spot_entry_fixture.dart';

final _hoTay = spotEntryFixture(
  id: 'ho-tay',
  name: 'Hồ Tây',
  hotScore: 5,
  inSeason: true,
  seasonMonths: const [10, 11],
);
final _hoGuom = spotEntryFixture(
  id: 'ho-guom',
  name: 'Hồ Gươm',
  lat: 21.0285,
  lng: 105.8542,
  radiusM: 500,
);
final _cauDat = spotEntryFixture(
  id: 'cau-dat',
  name: 'Đồi chè Cầu Đất',
  city: 'Đà Lạt',
  lat: 11.85,
  lng: 108.55,
);

Widget _host({
  required List<SpotEntry> suggestions,
  String? value,
  bool decided = false,
  ValueChanged<String?>? onChanged,
  String? error,
  double textScale = 1,
}) => screenApp(
  textScale: textScale,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SpotField(
        suggestions: suggestions,
        value: value,
        decided: decided,
        onChanged: onChanged ?? (_) {},
        error: error,
      ),
    ),
  ),
);

void main() {
  group('spotsForEvent', () {
    test('spots that reach the point come first, nearest first', () {
      // The point sits on Hồ Gươm; Hồ Tây is ~4 km away, Cầu Đất far.
      final ordered = spotsForEvent(
        [_cauDat, _hoTay, _hoGuom],
        lat: 21.0285,
        lng: 105.8542,
      );
      expect(ordered.map((s) => s.spotId), ['ho-guom', 'ho-tay', 'cau-dat']);
    });

    test('a spot within radius plus 500 m still counts as reaching', () {
      final near = spotEntryFixture(
        id: 'near',
        name: 'Gần',
        lat: 21.0348, // ~700 m north of the point, radius 500
        lng: 105.8542,
        radiusM: 500,
      );
      final ordered = spotsForEvent(
        [_cauDat, near],
        lat: 21.0285,
        lng: 105.8542,
      );
      expect(ordered.first.spotId, 'near');
    });

    test('without a point the hottest comes first', () {
      expect(spotsForEvent([_hoGuom, _hoTay]).map((s) => s.spotId), [
        'ho-tay',
        'ho-guom',
      ]);
    });
  });

  group('SpotField', () {
    testWidgets('shows the label and the placeholder before a choice', (
      tester,
    ) async {
      await tester.pumpWidget(_host(suggestions: [_hoTay]));
      expect(find.text('Điểm chụp · bắt buộc'), findsOneWidget);
      expect(find.text('Chọn điểm chụp'), findsOneWidget);
    });

    testWidgets(
      'lists covering spots nearest first plus "Không thuộc điểm chụp nào"',
      (tester) async {
        final ordered = spotsForEvent(
          [_cauDat, _hoTay, _hoGuom],
          lat: 21.0285,
          lng: 105.8542,
        );
        await tester.pumpWidget(_host(suggestions: ordered));
        await tester.tap(find.byKey(const Key('spot-field')));
        await tester.pumpAndSettle();
        expect(find.text('Điểm chụp'), findsOneWidget); // the sheet title
        final tops = [
          for (final k in ['ho-guom', 'ho-tay', 'cau-dat'])
            tester.getTopLeft(find.byKey(Key('spot-option-$k'))).dy,
        ];
        expect(tops, [...tops]..sort());
        expect(find.text('Không thuộc điểm chụp nào'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(const Key('spot-option-none'))).dy,
          greaterThan(tops.last),
        );
        expect(find.text('Hà Nội · Đang vào mùa'), findsOneWidget); // Hồ Tây
        expect(find.text('Hà Nội · Đẹp quanh năm'), findsOneWidget); // Hồ Gươm
      },
    );

    testWidgets('selecting calls onChanged with the spot id', (tester) async {
      final seen = <String?>[];
      await tester.pumpWidget(
        _host(suggestions: [_hoGuom, _hoTay], onChanged: seen.add),
      );
      await tester.tap(find.byKey(const Key('spot-field')));
      await tester.pumpAndSettle();
      // Nothing chosen: the button is off.
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const Key('spot-sheet-pick')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('spot-option-ho-tay')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn Hồ Tây'), findsOneWidget);
      await tester.tap(find.byKey(const Key('spot-sheet-pick')));
      await tester.pumpAndSettle();
      expect(seen, ['ho-tay']);
    });

    testWidgets('"Không thuộc điểm chụp nào" calls onChanged with null', (
      tester,
    ) async {
      final seen = <String?>[];
      await tester.pumpWidget(
        _host(suggestions: [_hoTay], value: 'ho-tay', onChanged: seen.add),
      );
      expect(find.text('Hồ Tây'), findsOneWidget);
      await tester.tap(find.byKey(const Key('spot-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spot-option-none')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spot-sheet-pick')));
      await tester.pumpAndSettle();
      expect(seen, [null]);
    });

    testWidgets('a decided "none" reads as "Không thuộc điểm chụp nào"', (
      tester,
    ) async {
      await tester.pumpWidget(_host(suggestions: [_hoTay], decided: true));
      expect(
        find.descendant(
          of: find.byKey(const Key('spot-field')),
          matching: find.text('Không thuộc điểm chụp nào'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('closing the sheet changes nothing', (tester) async {
      final seen = <String?>[];
      await tester.pumpWidget(
        _host(suggestions: [_hoTay], onChanged: seen.add),
      );
      await tester.tap(find.byKey(const Key('spot-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spot-sheet-close')));
      await tester.pumpAndSettle();
      expect(seen, isEmpty);
      expect(find.byKey(const Key('spot-sheet-pick')), findsNothing);
    });

    testWidgets('search ignores accents and says when nothing matches', (
      tester,
    ) async {
      await tester.pumpWidget(_host(suggestions: [_hoGuom, _hoTay, _cauDat]));
      await tester.tap(find.byKey(const Key('spot-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('spot-search')), 'cau dat');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('spot-option-cau-dat')), findsOneWidget);
      expect(find.byKey(const Key('spot-option-ho-tay')), findsNothing);
      await tester.enterText(find.byKey(const Key('spot-search')), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('spot-no-match')), findsOneWidget);
      expect(find.byKey(const Key('spot-option-none')), findsOneWidget);
    });

    testWidgets('error text shows under the field', (tester) async {
      await tester.pumpWidget(
        _host(
          suggestions: [_hoTay],
          error: 'Chọn một điểm chụp, hoặc “Không thuộc điểm chụp nào”',
        ),
      );
      expect(find.byKey(const Key('spot-field-error')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('spot-field-error'))).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const Key('spot-field'))).dy - 1,
        ),
      );
    });

    for (final dark in [true, false]) {
      testWidgets(
        '320 dp, 1.3×, ${dark ? 'dark' : 'light'}: field and sheet fit',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            screenApp(
              textScale: 1.3,
              brightness: dark ? Brightness.dark : Brightness.light,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SpotField(
                    suggestions: [_hoGuom, _hoTay, _cauDat],
                    value: 'cau-dat',
                    decided: true,
                    onChanged: (_) {},
                    error:
                        'Chọn một điểm chụp, hoặc “Không thuộc điểm chụp nào”',
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const Key('spot-field')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('spot-sheet-pick')), findsOneWidget);
        },
      );
    }
  });
}

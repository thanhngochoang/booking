// test/features/event_create/venue_field_test.dart
//
// S12.01-venue (mock #S12.01-venue): "Địa điểm · bắt buộc", three required
// options, the paid-place fee choice, the public-place commitment, the terms
// tick and their errors under the field.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/features/event_create/venue_field.dart';

import '../../support/screen_host.dart';

class _Calls {
  final kinds = <VenueKind>[];
  final names = <String>[];
  final included = <bool>[];
  final fees = <int?>[];
  final commitments = <bool>[];
  final terms = <bool>[];
}

Widget _host({
  VenueKind? kind,
  String placeName = '',
  bool? feeIncluded,
  int? feeVnd,
  bool committed = false,
  bool termsAccepted = false,
  bool consentNote = false,
  String? error,
  bool termsError = false,
  _Calls? calls,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) {
  final c = calls ?? _Calls();
  return screenApp(
    textScale: textScale,
    brightness: brightness,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: VenueField(
          kind: kind,
          placeName: placeName,
          feeIncluded: feeIncluded,
          feeVnd: feeVnd,
          committed: committed,
          termsAccepted: termsAccepted,
          consentNote: consentNote,
          error: error,
          termsError: termsError,
          spotTile: const SizedBox(key: Key('slot-spot'), height: 56),
          onKind: c.kinds.add,
          onPlaceName: c.names.add,
          onFeeIncluded: c.included.add,
          onFee: c.fees.add,
          onCommitment: c.commitments.add,
          onTerms: c.terms.add,
        ),
      ),
    ),
  );
}

Finder _key(String k) => find.byKey(Key(k));

void main() {
  testWidgets('three required options with their hints and the terms tick', (
    tester,
  ) async {
    final c = _Calls();
    await tester.pumpWidget(_host(calls: c));
    expect(find.text('Địa điểm · bắt buộc'), findsOneWidget);
    for (final t in [
      'Điểm có chủ quản lý',
      'Cần chủ điểm đồng ý',
      'Nơi có thu phí vào cửa',
      'Khu du lịch, công viên',
      'Nơi công cộng',
      'Không thu phí',
      'Tôi đồng ý điều khoản tổ chức sự kiện.',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // Nothing chosen yet: no kind-specific parts.
    expect(_key('venue-fee-included'), findsNothing);
    expect(_key('venue-commitment'), findsNothing);
    expect(_key('slot-spot'), findsOneWidget);

    await tester.tap(_key('venue-kind-paid_place'));
    await tester.tap(_key('venue-kind-managed_spot'));
    await tester.tap(_key('venue-kind-public'));
    expect(c.kinds, [
      VenueKind.paidPlace,
      VenueKind.managedSpot,
      VenueKind.publicPlace,
    ]);
    await tester.tap(_key('venue-terms'));
    expect(c.terms, [true]);
  });

  testWidgets(
    'a paid place asks Đã gồm / Chưa gồm, and an amount only when not included',
    (tester) async {
      final c = _Calls();
      await tester.pumpWidget(_host(kind: VenueKind.paidPlace, calls: c));
      expect(find.text('Tên nơi tổ chức'), findsOneWidget);
      expect(find.text('Đã gồm phí vào cửa'), findsOneWidget);
      expect(find.text('Chưa gồm'), findsOneWidget);
      expect(_key('venue-fee-amount'), findsNothing);
      await tester.tap(find.text('Chưa gồm'));
      await tester.tap(find.text('Đã gồm phí vào cửa'));
      expect(c.included, [false, true]);

      await tester.enterText(_key('venue-place-name'), 'Công viên Yên Sở');
      expect(c.names.last, 'Công viên Yên Sở');

      await tester.pumpWidget(
        _host(
          kind: VenueKind.paidPlace,
          feeIncluded: false,
          feeVnd: 20000,
          calls: c,
        ),
      );
      expect(find.text('Giá tham khảo (₫)'), findsOneWidget);
      // Prefilled (from the spot's access) values show grouped.
      expect(find.text('20.000'), findsOneWidget);
      await tester.enterText(_key('venue-fee-amount'), '30000');
      expect(c.fees.last, 30000);
    },
  );

  testWidgets('a public place needs the commitment tick', (tester) async {
    final c = _Calls();
    await tester.pumpWidget(_host(kind: VenueKind.publicPlace, calls: c));
    expect(
      find.text('Tôi tự chịu trách nhiệm xin phép theo quy định địa phương'),
      findsOneWidget,
    );
    expect(_key('venue-fee-included'), findsNothing);
    await tester.tap(_key('venue-commitment'));
    expect(c.commitments, [true]);
  });

  testWidgets('each error shows under its part', (tester) async {
    await tester.pumpWidget(_host(error: 'required', termsError: true));
    expect(find.text('Chọn loại địa điểm'), findsOneWidget);
    expect(find.text('Đồng ý điều khoản để đăng'), findsOneWidget);

    await tester.pumpWidget(_host(kind: VenueKind.paidPlace, error: 'fee'));
    expect(find.text('Chọn đã gồm hay chưa gồm phí vào cửa'), findsOneWidget);
    final feeErr = tester.getTopLeft(
      find.text('Chọn đã gồm hay chưa gồm phí vào cửa'),
    );
    expect(
      feeErr.dy,
      greaterThan(tester.getTopLeft(_key('venue-fee-included')).dy),
    );

    await tester.pumpWidget(
      _host(kind: VenueKind.paidPlace, feeIncluded: false, error: 'amount'),
    );
    expect(find.text('Nhập giá vé vào cửa tham khảo'), findsOneWidget);

    await tester.pumpWidget(
      _host(kind: VenueKind.publicPlace, error: 'commitment'),
    );
    expect(find.text('Tick cam kết để đăng ở nơi công cộng'), findsOneWidget);

    await tester.pumpWidget(_host(kind: VenueKind.managedSpot, error: 'spot'));
    expect(find.text('Chọn một điểm có chủ quản lý'), findsOneWidget);
  });

  testWidgets('the consent note for a managed spot of someone else', (
    tester,
  ) async {
    await tester.pumpWidget(_host(kind: VenueKind.managedSpot));
    const note =
        'Chủ điểm cần đồng ý trong 72 giờ. Sự kiện ở trạng thái nháp tới lúc đó.';
    expect(find.text(note), findsNothing);
    await tester.pumpWidget(
      _host(kind: VenueKind.managedSpot, consentNote: true),
    );
    expect(find.text(note), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text ($b)', (tester) async {
      tester.view.physicalSize = const Size(320, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final k in VenueKind.values) {
        await tester.pumpWidget(
          _host(
            kind: k,
            feeIncluded: false,
            consentNote: true,
            error: k == VenueKind.publicPlace ? 'commitment' : 'amount',
            termsError: true,
            textScale: 1.3,
            brightness: b,
          ),
        );
        expect(tester.takeException(), isNull, reason: '$k');
      }
    });
  }
}

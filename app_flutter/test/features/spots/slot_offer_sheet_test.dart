// test/features/spots/slot_offer_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/spots/spot.dart';
import 'package:photobooking/data/spots/spot_providers.dart';
import 'package:photobooking/data/spots/spot_repository.dart';
import 'package:photobooking/features/spots/slot_offer_sheet.dart';

import '../../support/fake_spot_repository.dart';
import '../../support/screen_host.dart';
import '../../support/spot_entry_fixture.dart';

const _schedule = SpotSchedule(
  id: 's1',
  providerId: 'provider_1',
  spotId: 'spot_1',
  assigneeId: null,
  days: ['2026-10-10', '2026-10-11', '2026-10-17'],
  window: SpotWindow(start: '06:00', end: '11:00'),
  serviceIds: [],
  priceFrom: 900000,
  open: true,
);

const _offer = SlotOffer(
  id: 'o1',
  providerId: 'provider_1',
  scheduleId: 's1',
  spotId: 'spot_1',
  name: 'Chụp sương sớm 30 phút',
  price: 490000,
  slotMinutes: 30,
  gapMinutes: 10,
  photoCount: 30,
  editedCount: 15,
  deliveryDays: 3,
  open: true,
);

FakeSpotRepository _repo() => FakeSpotRepository()
  ..seedDirectory([
    spotEntryFixture(id: 'spot_1', name: 'Đồi chè Cầu Đất', city: 'Đà Lạt'),
  ])
  ..seedSchedule(_schedule)
  ..seedOffer(_offer);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(
  WidgetTester tester,
  FakeSpotRepository repo, {
  SpotSchedule schedule = _schedule,
  SlotOffer? offer,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    screenApp(
      overrides: [
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 8, 2)),
        spotRepositoryProvider.overrideWithValue(repo),
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  showSlotOfferSheet(context, schedule: schedule, offer: offer),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
}

Future<void> _fill(
  WidgetTester tester, {
  String name = 'Chụp sương sớm 30 phút',
  String price = '490000',
}) async {
  await tester.enterText(find.byKey(const Key('slot-offer-name')), name);
  await tester.enterText(find.byKey(const Key('slot-offer-price')), price);
  await tester.pump();
}

/// Taps a stepper button [times] times, one frame each.
Future<void> _step(WidgetTester tester, String key, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    final button = find.byKey(Key(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }
}

Future<void> _save(WidgetTester tester) async {
  final save = find.byKey(const Key('slot-offer-save'));
  await tester.ensureVisible(save);
  await tester.tap(save);
  await _settle(tester);
}

void main() {
  testWidgets('preview "7 suất/ngày: 06:00, 06:40, …" for 06:00–11:00, 30/10', (
    tester,
  ) async {
    await _open(tester, _repo());
    expect(find.text('Gói chia suất'), findsOneWidget);
    expect(find.text('Đồi chè Cầu Đất · T7, CN · 06:00–11:00'), findsOneWidget);
    expect(find.text('30 phút'), findsOneWidget);
    expect(find.text('10 phút'), findsOneWidget);
    expect(
      find.text('7 suất/ngày: 06:00, 06:40, 07:20, 08:00 … 10:00'),
      findsOneWidget,
    );

    // 30/0 → 10 slots; the preview follows the steppers.
    await _step(tester, 'slot-gap-minus', times: 2);
    expect(
      find.text('10 suất/ngày: 06:00, 06:30, 07:00, 07:30 … 10:30'),
      findsOneWidget,
    );
  });

  testWidgets('an offer that fits no slot shows "Khung giờ không đủ cho một '
      'suất" and Lưu is disabled', (tester) async {
    const short = SpotSchedule(
      id: 's1',
      providerId: 'provider_1',
      spotId: 'spot_1',
      assigneeId: null,
      days: ['2026-10-10'],
      window: SpotWindow(start: '06:00', end: '07:00'),
      serviceIds: [],
      priceFrom: null,
      open: true,
    );
    await _open(tester, _repo(), schedule: short);
    await _step(tester, 'slot-minutes-plus', times: 7);
    expect(find.text('65 phút'), findsOneWidget);
    expect(find.text('Khung giờ không đủ cho một suất'), findsOneWidget);
    final save = tester.widget<AppButton>(
      find.byKey(const Key('slot-offer-save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('price 5.000 shows the price error', (tester) async {
    final repo = _repo();
    await _open(tester, repo);
    await _fill(tester, price: '5000');
    expect(find.text('5.000'), findsOneWidget);
    await _save(tester);
    expect(find.text('Giá từ 10.000₫ tới 100.000.000₫'), findsOneWidget);
    expect(repo.saveOfferCalls, isEmpty);
  });

  testWidgets('server contact_leak shows the contact message under Tên gói', (
    tester,
  ) async {
    final repo = _repo()
      ..saveOfferError = const SpotError(
        SpotErrorCode.contactLeak,
        field: 'name',
      );
    await _open(tester, repo);
    await _fill(tester, name: 'Gọi 0903 123 456');
    await _save(tester);
    expect(
      find.text('Bỏ số điện thoại, Zalo hoặc link ra khỏi tên gói'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('slot-offer-save')), findsOneWidget);
  });

  testWidgets('limit_exceeded shows "Mỗi lịch tối đa 2 gói chia suất"', (
    tester,
  ) async {
    final repo = _repo()
      ..saveOfferError = const SpotError(SpotErrorCode.limitExceeded);
    await _open(tester, repo);
    await _fill(tester);
    await _save(tester);
    expect(find.text('Mỗi lịch tối đa 2 gói chia suất'), findsOneWidget);
  });

  testWidgets('Lưu sends every field and closes with "Đã lưu gói chia suất"', (
    tester,
  ) async {
    final repo = _repo();
    await _open(tester, repo);
    await _fill(tester, name: '  Bình minh 20 phút ', price: '350000');
    await tester.enterText(find.byKey(const Key('slot-offer-delivery')), '5');
    await tester.enterText(find.byKey(const Key('slot-offer-photos')), '25');
    await tester.enterText(find.byKey(const Key('slot-offer-edited')), '12');
    await _step(tester, 'slot-minutes-minus', times: 2);
    await _step(tester, 'slot-gap-plus');
    await _save(tester);

    final input = repo.saveOfferCalls.single;
    expect(input.offerId, isNull);
    expect(input.scheduleId, 's1');
    expect(input.name, 'Bình minh 20 phút');
    expect(input.price, 350000);
    expect(input.slotMinutes, 20);
    expect(input.gapMinutes, 15);
    expect(input.photoCount, 25);
    expect(input.editedCount, 12);
    expect(input.deliveryDays, 5);
    expect(find.byKey(const Key('slot-offer-save')), findsNothing);
    expect(find.text('Đã lưu gói chia suất'), findsOneWidget);
  });

  testWidgets('editing sends the offer id', (tester) async {
    final repo = _repo();
    await _open(tester, repo, offer: _offer);
    expect(find.text('490.000'), findsOneWidget);
    await _save(tester);
    expect(repo.saveOfferCalls.single.offerId, 'o1');
    expect(repo.saveOfferCalls.single.price, 490000);
  });

  testWidgets('"Đóng gói" confirms then calls closeOffer', (tester) async {
    final repo = _repo();
    await _open(tester, repo, offer: _offer);
    final close = find.byKey(const Key('slot-offer-close'));
    await tester.ensureVisible(close);
    await tester.tap(close);
    await _settle(tester);
    expect(find.text('Đóng gói Chụp sương sớm 30 phút?'), findsOneWidget);
    expect(repo.closeOfferCalls, isEmpty);

    await tester.tap(find.widgetWithText(AppButton, 'Đóng gói').last);
    await _settle(tester);
    expect(repo.closeOfferCalls, ['o1']);
    expect(find.text('Đã đóng gói chia suất'), findsOneWidget);
  });
}

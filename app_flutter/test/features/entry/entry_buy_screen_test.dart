// S30.05 `/spots/:spotId/tickets`: day chips, counters, the total, the
// refund cutoff, registerEntry and S04.04, the sold-out refusal, and the
// toast that leads to S11.04-entry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/features/entry/entry_rules.dart';

import '../../support/entry_world.dart';
import '../../support/organizer_world.dart';

Finder _chip(String day) => find.byKey(Key('entry-day-$day'));

AppButton _pay(WidgetTester tester) =>
    tester.widget<AppButton>(find.byKey(const Key('entry-pay')));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settleOrganizer(tester);
}

void main() {
  test('entry rules: 14 days from today, cutoff label, unit price', () {
    final e = makeEntryEvent(closedWeekdays: const [1]); // Mondays closed
    final days = entryDaysFrom(e, organizerToday);
    expect(days.first, organizerToday);
    expect(days.contains('2026-11-16'), isFalse); // a Monday
    expect(days.last.compareTo('2026-11-23') <= 0, isTrue);
    expect(entryCutoffLabel('2026-11-14', 48), '00:00 T5 12/11');
    expect(entryUnitPrice(e, null), 70000);
  });

  testWidgets('14 day chips + Chọn ngày; today first', (tester) async {
    final w = EntryWorld();
    await w.pump(tester);
    expect(find.text('Vé vào cửa'), findsWidgets);
    expect(find.text('Bãi đá sông Hồng'), findsOneWidget);
    expect(find.textContaining('Mở cửa 06:00–22:00'), findsOneWidget);
    for (final d in entryDaysFrom(makeEntryEvent(), organizerToday)) {
      expect(_chip(d), findsOneWidget, reason: d);
    }
    expect(entryDaysFrom(makeEntryEvent(), organizerToday), hasLength(14));
    expect(find.byKey(const Key('entry-day-pick')), findsOneWidget);
    expect(
      find.descendant(
        of: _chip(organizerToday),
        matching: find.text('Hôm nay'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a sold-out day is dimmed with Hết vé and cannot be picked', (
    tester,
  ) async {
    final w = EntryWorld();
    w.organizers.putEntryDay(
      const EntryDay(eventId: 'ent1', day: '2026-11-11', sold: 500),
    );
    await w.pump(tester);
    expect(
      find.descendant(
        of: _chip('2026-11-11'),
        matching: find.text('T4 11/11 · Hết vé'),
      ),
      findsOneWidget,
    );
    expect(tester.widget<AppChip>(_chip('2026-11-11')).enabled, isFalse);
  });

  testWidgets('counters per type; the total stops at 10 with the limit line', (
    tester,
  ) async {
    final w = EntryWorld();
    await w.pump(tester);
    // One adult by default.
    expect(find.text('1 vé · Hôm nay'), findsOneWidget);
    expect(find.text('70.000₫'), findsWidgets);
    await _tap(tester, find.byKey(const Key('entry-t2-plus')));
    expect(find.text('2 vé · Hôm nay'), findsOneWidget);
    expect(find.text('120.000₫'), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await _tap(tester, find.byKey(const Key('entry-t1-plus')));
    }
    expect(find.text('10 vé · Hôm nay'), findsOneWidget);
    expect(find.text('Tối đa 10 vé mỗi đơn'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('entry-t1-plus')))
          .onPressed,
      isNull,
    );
    expect(_pay(tester).label, 'Thanh toán 680.000₫');
  });

  testWidgets('a total of 0 disables the primary', (tester) async {
    final w = EntryWorld();
    await w.pump(tester);
    await _tap(tester, find.byKey(const Key('entry-t1-minus')));
    expect(_pay(tester).onPressed, isNull);
  });

  testWidgets('the refund note names the cutoff of the chosen day', (
    tester,
  ) async {
    final w = EntryWorld();
    await w.pump(tester);
    await _tap(tester, _chip('2026-11-14'));
    expect(
      find.text(
        'Một mã QR cho cả nhóm, đưa ở cổng. Huỷ trước 48 giờ (trước 00:00 T5 12/11) hoàn 100%, sau đó không hoàn.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('no phone → S04.05 and nothing is held', (tester) async {
    final w = EntryWorld()..contact = null;
    await w.pump(tester);
    await _tap(tester, find.byKey(const Key('entry-pay')));
    expect(w.location, startsWith('/profile/phone?returnTo='));
    expect(Uri.decodeComponent(w.location), contains('/spots/bd/tickets'));
    expect(w.events.entryRegistrations, isEmpty);
  });

  testWidgets('a slow contact read with a phone still holds the tickets', (
    tester,
  ) async {
    final w = EntryWorld()..contactDelay = const Duration(seconds: 2);
    await w.pump(tester);
    await tester.tap(find.byKey(const Key('entry-pay')));
    await tester.pump(const Duration(seconds: 3));
    await settleOrganizer(tester);
    expect(w.location, isNot(startsWith('/profile/phone')));
    expect(w.events.entryRegistrations, hasLength(1));
    expect(w.location, startsWith('/e/ent1/pay/'));
  });

  testWidgets('pay → registerEntry for the day and types, then S04.04', (
    tester,
  ) async {
    final w = EntryWorld();
    await w.pump(tester);
    await _tap(tester, _chip('2026-11-14'));
    await _tap(tester, find.byKey(const Key('entry-t1-plus')));
    await _tap(tester, find.byKey(const Key('entry-t2-plus')));
    await _tap(tester, find.byKey(const Key('entry-pay')));
    final call = w.events.entryRegistrations.single;
    expect(call.eventId, 'ent1');
    expect(call.visitDay, '2026-11-14');
    expect(
      {for (final i in call.items) i.ticketTypeId: i.qty},
      {'t1': 2, 't2': 1},
    );
    expect(w.location, startsWith('/e/ent1/pay/'));
  });

  testWidgets('sold_out_day → the error line and the chips read again', (
    tester,
  ) async {
    final w = EntryWorld();
    await w.pump(tester);
    await _tap(tester, _chip('2026-11-14'));
    w.events.nextEntryRefusal = 'sold_out_day';
    w.organizers.putEntryDay(
      const EntryDay(eventId: 'ent1', day: '2026-11-14', sold: 500),
    );
    await _tap(tester, find.byKey(const Key('entry-pay')));
    expect(find.text('Ngày này vừa hết vé. Chọn ngày khác.'), findsOneWidget);
    expect(
      find.descendant(
        of: _chip('2026-11-14'),
        matching: find.text('T7 14/11 · Hết vé'),
      ),
      findsOneWidget,
    );
    // The sold-out day is no longer the chosen one.
    expect(tester.widget<AppChip>(_chip('2026-11-14')).selected, isFalse);
    expect(w.location, '/spots/bd/tickets');
  });

  testWidgets('day_closed shows Ngày này đóng cửa.', (tester) async {
    final w = EntryWorld();
    await w.pump(tester);
    w.events.nextEntryRefusal = 'day_closed';
    await _tap(tester, find.byKey(const Key('entry-pay')));
    expect(find.text('Ngày này đóng cửa.'), findsOneWidget);
  });

  testWidgets('after payment: toast "Đã mua 3 vé" and S11.04-entry', (
    tester,
  ) async {
    final w = EntryWorld();
    await w.pump(tester);
    await _tap(tester, find.byKey(const Key('entry-t1-plus')));
    await _tap(tester, find.byKey(const Key('entry-t2-plus')));
    await _tap(tester, find.byKey(const Key('entry-pay')));
    expect(w.location, startsWith('/e/ent1/pay/'));
    final reg = (await tester.runAsync(() => w.events.watchMyTickets().first))!
        .first;
    w.events.putRegistration(
      EventRegistration(
        id: reg.id,
        eventId: reg.eventId,
        userId: reg.userId,
        userName: reg.userName,
        ticketCode: '',
        quantity: reg.quantity,
        amount: reg.amount,
        status: RegistrationStatus.paid,
        event: reg.event,
        createdAt: reg.createdAt,
        paymentId: reg.paymentId,
        visitDay: reg.visitDay,
        items: reg.items,
      ),
    );
    await settleOrganizer(tester);
    expect(find.text('Đã mua 3 vé'), findsOneWidget);
    expect(find.text('Vào nhóm chat'), findsNothing);
    expect(w.location, '/bookings?tab=events&highlight=${reg.id}');
  });

  testWidgets('a spot without tickets on sale says so, no primary', (
    tester,
  ) async {
    final w = EntryWorld();
    w.spots.seedEntryEvent('bd', null);
    await w.pump(tester);
    expect(find.text('Điểm này chưa bán vé qua app'), findsOneWidget);
    expect(find.byKey(const Key('entry-pay')), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text (${b.name})', (tester) async {
      final w = EntryWorld();
      await w.pump(
        tester,
        width: 320,
        height: 1400,
        brightness: b,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('entry-pay')), findsOneWidget);
    });
  }
}

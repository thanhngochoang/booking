// test/features/event_manage/entry_days_tab_test.dart
//
// S12.03-entry (mock #S12.03-entry): an entry event is managed per day.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/events/event_registration.dart';
import 'package:photobooking/data/organizer/organizer.dart';

import '../../support/organizer_world.dart';

Finder _key(String k) => find.byKey(Key(k));

const _path = '/events/ent1/manage';

OrganizerWorld _world() {
  final w = OrganizerWorld();
  w.organizers.putOrganizer(makeOrganizer());
  w.events.putEvent(entryDetailOf(makeEntryEvent(closedWeekdays: const [3])));
  w.organizers
    ..putEntryDay(
      const EntryDay(
        eventId: 'ent1',
        day: organizerToday,
        sold: 5,
        held: 1,
        checkedIn: 2,
      ),
    )
    ..closeAnswer = (refunded: 2, left: 0);
  w.events
    ..putRegistration(
      entryRegistration('r1', lines: [(adultType, 2), (childType, 1)]),
    )
    ..putRegistration(entryRegistration('r2', lines: [(adultType, 2)]))
    // Another day and a held one are not counted.
    ..putRegistration(entryRegistration('r3', day: '2026-11-12'))
    ..putRegistration(entryRegistration('r4', status: RegistrationStatus.held));
  return w;
}

void main() {
  testWidgets('day chips, KPI and the per-type table', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);

    expect(find.text('Vé vào cửa mùa cúc hoạ mi'), findsOneWidget);
    expect(find.text('01/11–31/12 · 2 loại vé'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    // 11/11 is a Wednesday (closed): the next chips skip it.
    expect(_key('entry-day-2026-11-11'), findsNothing);
    expect(find.text('T5 12/11'), findsOneWidget);
    expect(
      find.text('Đã bán 5/500 · đã vào 2 · doanh thu 330.000₫'),
      findsOneWidget,
    );
    expect(find.text('Theo loại vé'), findsOneWidget);
    expect(find.text('4 · 280.000₫'), findsOneWidget);
    expect(find.text('1 · 50.000₫'), findsOneWidget);
    expect(_key('entry-scan'), findsOneWidget);
    expect(_key('entry-edit'), findsOneWidget);
  });

  testWidgets('another day chip reads that day', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await tapOrganizer(tester, _key('entry-day-2026-11-12'));
    expect(
      find.text('Đã bán 0/500 · đã vào 0 · doanh thu 140.000₫'),
      findsOneWidget,
    );
    // Each chip reads its own visit day, never the whole season (A-I4).
    expect(
      w.events.entryQueries.map((q) => q.day).toSet(),
      {organizerToday, '2026-11-12'},
    );
    expect(w.events.entryQueries.every((q) => q.fromDay == null), isTrue);
  });

  testWidgets(
    '"Đóng ngày này" red text → ConfirmSheet with count and amount → closeEntryDay',
    (tester) async {
      final w = _world();
      await w.pump(tester, location: _path);
      await tapOrganizer(tester, _key('entry-close-day'));

      expect(find.text('Đóng ngày 10/11?'), findsOneWidget);
      expect(
        find.text('5 vé · hoàn 330.000₫ cho khách. Khách nhận thông báo ngay.'),
        findsOneWidget,
      );
      expectRedButton(tester, 'Đóng ngày');
      await tapOrganizer(tester, find.text('Đóng ngày'));

      expectOnlyCall(w, (
        'closeEntryDay',
        {'eventId': 'ent1', 'day': organizerToday},
      ));
      expect(
        find.text('Ngày này đã đóng · vé đã bán được hoàn 100%'),
        findsOneWidget,
      );
      expect(_key('entry-close-day'), findsNothing);
    },
  );

  testWidgets('"Quét mã" opens /scan, "Sửa" opens S30.04', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await tapOrganizer(tester, _key('entry-scan'));
    expect(w.location, '/scan');
    w.router.go(_path);
    await settleOrganizer(tester);
    await tapOrganizer(tester, _key('entry-edit'));
    expect(w.location, '/organizer/entry/ent1/edit');
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text ($b)', (tester) async {
      final w = _world();
      await w.pump(
        tester,
        location: _path,
        width: 320,
        height: 700,
        textScale: 1.3,
        brightness: b,
      );
      expect(tester.takeException(), isNull);
      expect(_key('entry-scan'), findsOneWidget);
    });
  }
}

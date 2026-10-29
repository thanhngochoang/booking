// test/features/organizer/entry_tickets_edit_screen_test.dart
//
// S30.04 "Vé vào cửa" (mock #S30.04): create and edit an entry event.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/features/organizer/organizer_controller.dart';

import '../../support/organizer_world.dart';

Finder _key(String k) => find.byKey(Key(k));

const _newPath = '/organizer/entry/new?spot=bd';
const _editPath = '/organizer/entry/ent1/edit';

OrganizerWorld _world({List<EntryTicketType>? types}) {
  final w = OrganizerWorld();
  w.organizers.putOrganizer(makeOrganizer());
  w.seedSpot(makeSpot(managedBy: 'org1'));
  final entry = types == null ? makeEntryEvent() : makeEntryEvent(types: types);
  w.events.putEvent(entryDetailOf(entry));
  return w;
}

AppButton _submit(WidgetTester tester) =>
    tester.widget<AppButton>(_key('entry-submit'));

Future<void> _addType(WidgetTester tester, String name, String price) async {
  await tapOrganizer(tester, _key('entry-add-type'));
  await tester.enterText(_key('type-name'), name);
  await tester.enterText(_key('type-price'), price);
  await tapOrganizer(tester, _key('type-save'));
}

void main() {
  group('entryFormErrors (validation per rule)', () {
    EntryForm form({
      String start = organizerToday,
      String end = '2026-12-31',
      String open = '06:00',
      String close = '22:00',
      String capacity = '',
      List<EntryTicketType> types = const [adultType],
    }) => EntryForm(
      name: 'Vé mùa cúc',
      startDay: start,
      endDay: end,
      open: open,
      close: close,
      capacity: capacity,
      types: types,
    );

    test('a valid form has no error', () {
      expect(entryFormErrors(form(), today: organizerToday), isEmpty);
    });
    test('range ≤ 180 days', () {
      expect(entryFormErrors(form(end: '2027-05-09'), today: organizerToday), {
        EntryField.range: EntryRule.rangeTooLong,
      });
      expect(
        entryFormErrors(form(end: '2027-05-08'), today: organizerToday),
        isEmpty,
      );
    });
    test('start not in the past, only when creating', () {
      expect(
        entryFormErrors(form(start: '2026-11-09'), today: organizerToday),
        {EntryField.range: EntryRule.startPast},
      );
      expect(
        entryFormErrors(
          form(start: '2026-11-01'),
          today: organizerToday,
          editing: true,
        ),
        isEmpty,
      );
    });
    test('end before start', () {
      expect(entryFormErrors(form(end: '2026-11-09'), today: organizerToday), {
        EntryField.range: EntryRule.endBeforeStart,
      });
    });
    test('closing after opening, HH:mm', () {
      expect(
        entryFormErrors(
          form(open: '22:00', close: '06:00'),
          today: organizerToday,
        ),
        {EntryField.hours: EntryRule.hoursInvalid},
      );
      expect(entryFormErrors(form(open: '6h'), today: organizerToday), {
        EntryField.hours: EntryRule.timeFormat,
      });
    });
    test('capacity empty or a whole number > 0', () {
      expect(entryFormErrors(form(capacity: '0'), today: organizerToday), {
        EntryField.capacity: EntryRule.capacityInvalid,
      });
      expect(
        entryFormErrors(form(capacity: '500'), today: organizerToday),
        isEmpty,
      );
    });
    test('1–6 types', () {
      expect(entryFormErrors(form(types: const []), today: organizerToday), {
        EntryField.types: EntryRule.typesEmpty,
      });
    });
    test('capacity under a day sold', () {
      expect(
        entryFormErrors(
          form(capacity: '2'),
          today: organizerToday,
          editing: true,
          soldPerDay: const {'2026-11-15': 3, '2026-11-12': 1},
        ),
        {EntryField.capacity: EntryRule.capacityBelowSold},
      );
    });
    test('type names 3–40, prices > 0', () {
      expect(ticketTypeNameOk('AB'), isFalse);
      expect(ticketTypeNameOk('Người lớn'), isTrue);
      expect(ticketTypeNameOk('x' * 41), isFalse);
      expect(ticketTypePriceOf('0'), isNull);
      expect(ticketTypePriceOf('70.000'), 70000);
    });
  });

  testWidgets('create → "Mở bán" saves the draft and publishes it', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: _newPath);

    expect(find.text('Vé vào cửa'), findsOneWidget);
    expect(_submit(tester).label, 'Mở bán');
    expect(find.text('Loại vé · 0 / 6'), findsOneWidget);
    expect(
      find.text('Khung giờ chỉ là tên loại vé, app không kiểm giờ vào.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Khách huỷ trước 48 giờ hoàn 100%. Tiền vé chuyển cho bạn sau ngày tham quan 1 ngày + 48 giờ.',
      ),
      findsOneWidget,
    );

    await _addType(tester, 'Người lớn', '70000');
    expect(find.text('Loại vé · 1 / 6'), findsOneWidget);
    expect(find.text('70.000₫'), findsOneWidget);
    await tester.enterText(_key('entry-capacity'), '500');
    await tapOrganizer(tester, _key('entry-weekday-1'));
    await tapOrganizer(tester, _key('entry-submit'));

    final draft = w.events.savedEntryDrafts.single;
    expect(draft.spotId, 'bd');
    expect(draft.title, 'Bãi đá sông Hồng');
    expect(draft.startDay, organizerToday);
    expect(draft.endDay, '2026-12-09');
    expect(draft.openHours, const OpenHours(start: '06:00', end: '22:00'));
    expect(draft.dailyCapacity, 500);
    expect(draft.closedWeekdays, [1]);
    expect(draft.ticketTypes, [
      const EntryTicketType(id: '', name: 'Người lớn', price: 70000),
    ]);
    expect(w.events.published, hasLength(1));
    expect(w.location, '/organizer/spots/bd');
  });

  testWidgets('validation messages on the form', (tester) async {
    final w = _world();
    await w.pump(tester, location: _newPath);

    await tapOrganizer(tester, _key('entry-submit'));
    expect(find.text('Thêm ít nhất một loại vé'), findsOneWidget);

    await tester.enterText(_key('entry-open'), '22:00');
    await tester.enterText(_key('entry-close'), '06:00');
    await tapOrganizer(tester, _key('entry-submit'));
    expect(find.text('Giờ đóng cửa phải sau giờ mở cửa'), findsOneWidget);

    await tester.enterText(_key('entry-open'), '6h');
    await tapOrganizer(tester, _key('entry-submit'));
    expect(find.text('Giờ dạng 06:00'), findsOneWidget);

    await tester.enterText(_key('entry-capacity'), '0');
    await tapOrganizer(tester, _key('entry-submit'));
    expect(find.text('Số nguyên lớn hơn 0'), findsOneWidget);

    await tapOrganizer(tester, _key('entry-add-type'));
    await tester.enterText(_key('type-name'), 'AB');
    await tester.enterText(_key('type-price'), '0');
    await tapOrganizer(tester, _key('type-save'));
    expect(find.text('Tên 3–40 ký tự'), findsOneWidget);
    expect(find.text('Giá là số nguyên lớn hơn 0'), findsOneWidget);
    expect(w.events.savedEntryDrafts, isEmpty);
  });

  testWidgets('a 7th type is blocked', (tester) async {
    final w = _world(
      types: [
        for (var i = 1; i <= 6; i++)
          EntryTicketType(id: 't$i', name: 'Loại $i', price: 10000 * i),
      ],
    );
    await w.pump(tester, location: _editPath);

    expect(find.text('Loại vé · 6 / 6'), findsOneWidget);
    expect(find.text('Tối đa 6 loại vé'), findsOneWidget);
    expect(tester.widget<AppButton>(_key('entry-add-type')).onPressed, isNull);
  });

  testWidgets('a sold type shows "Ẩn loại vé" instead of delete', (
    tester,
  ) async {
    final w = _world();
    w.events.putRegistration(entryRegistration('r1', day: '2026-11-15'));
    await w.pump(tester, location: _editPath);

    await tapOrganizer(tester, _key('entry-type-0'));
    expect(find.text('Ẩn loại vé'), findsOneWidget);
    expect(_key('type-delete'), findsNothing);
    await tapOrganizer(tester, _key('type-hide'));
    await tapOrganizer(tester, _key('type-save'));
    expect(find.text('đang ẩn'), findsOneWidget);

    await tapOrganizer(tester, _key('entry-type-1'));
    expect(_key('type-delete'), findsOneWidget);
    expect(_key('type-hide'), findsNothing);
  });

  testWidgets('capacity under sold → s3004_capacityBelowSold', (tester) async {
    final w = _world();
    w.events.putRegistration(
      entryRegistration('r1', day: '2026-11-15', lines: [(adultType, 3)]),
    );
    await w.pump(tester, location: _editPath);

    await tester.enterText(_key('entry-capacity'), '2');
    await tapOrganizer(tester, _key('entry-submit'));
    expect(
      find.text('Ngày 15/11 đã bán 3 vé, không giảm dưới số đó'),
      findsOneWidget,
    );
    expect(w.events.updatedEntryEvents, isEmpty);
  });

  testWidgets('edit → "Lưu thay đổi" calls updateEntryEvent', (tester) async {
    final w = _world();
    await w.pump(tester, location: _editPath);

    expect(_submit(tester).label, 'Lưu thay đổi');
    expect(find.text('Vé vào cửa mùa cúc hoạ mi'), findsOneWidget);
    await tester.enterText(_key('entry-capacity'), '400');
    await tapOrganizer(tester, _key('entry-submit'));

    final u = w.events.updatedEntryEvents.single;
    expect(u.eventId, 'ent1');
    expect(u.draft.dailyCapacity, 400);
    expect(u.draft.ticketTypes, const [adultType, childType]);
    expect(u.draft.startDay, '2026-11-01');
    expect(w.events.published, isEmpty);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320 dp at 1.3× text ($b)', (tester) async {
      final w = _world();
      await w.pump(
        tester,
        location: _editPath,
        width: 320,
        height: 700,
        textScale: 1.3,
        brightness: b,
      );
      expect(tester.takeException(), isNull);
      await tapOrganizer(tester, _key('entry-type-0'));
      expect(tester.takeException(), isNull);
      expect(_key('type-save'), findsOneWidget);
    });
  }
}

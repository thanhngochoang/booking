// test/features/organizer/managed_spot_screen_test.dart
//
// S30.03 "Quản lý điểm" and S30.03-residents (mock #S30.03,
// #S30.03-residents).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/organizer/organizer.dart';

import 'package:photobooking/data/events/event_detail.dart';
import 'package:photobooking/data/events/event_summary.dart';

import '../../support/event_world.dart' show detailOf;
import '../../support/organizer_world.dart';

Finder _key(String k) => find.byKey(Key(k));

const _path = '/organizer/spots/bd';

OrganizerWorld _world({
  bool business = true,
  bool payout = true,
  bool onSale = true,
}) {
  final w = OrganizerWorld();
  w.organizers.putOrganizer(
    makeOrganizer(businessVerified: business, payoutAccountOk: payout),
  );
  w.seedSpot(
    makeSpot(
      managedBy: 'org1',
      access: const SpotAccess(
        type: SpotAccessType.ticket,
        fees: [AccessFee(label: 'Người lớn', amountVnd: 70000)],
        note: 'Trẻ dưới 80 cm miễn vé',
      ),
    ),
  );
  if (onSale) {
    w.spots.seedEntryEvent('bd', makeEntryEvent());
    w.organizers.putEntryDay(
      const EntryDay(
        eventId: 'ent1',
        day: organizerToday,
        sold: 182,
        held: 12,
        checkedIn: 96,
      ),
    );
  }
  w.spots.seedResidents('bd', const [
    Resident(
      providerId: 'tri',
      waivesProvider: true,
      waivesGuests: true,
      maxGuests: 4,
      validUntil: '2026-12-31',
    ),
    Resident(providerId: 'may', waivesProvider: true, waivesGuests: false),
  ]);
  w.photographers
    ..add(makeProvider('tri', 'Minh Trí'))
    ..add(makeProvider('may', 'Studio Mây'))
    ..add(makeProvider('nhung', 'Hồng Nhung'))
    ..add(makeProvider('off', 'Hồng Hà', accepting: false));
  return w;
}

AppButton _primary(WidgetTester tester) =>
    tester.widget<AppButton>(_key('managed-primary'));

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await settleOrganizer(tester);
}

void main() {
  testWidgets('three tabs; the ticket card, KPI line and "Sửa vé vào cửa"', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: _path);

    expect(find.text('Bãi đá sông Hồng'), findsOneWidget);
    expect(find.text('Vào cửa'), findsOneWidget);
    expect(find.text('Thợ tại điểm · 2'), findsOneWidget);
    expect(find.text('Thông tin'), findsOneWidget);

    expect(find.text('Vé vào cửa mùa cúc hoạ mi'), findsOneWidget);
    expect(find.text('ĐANG BÁN'), findsOneWidget);
    expect(find.text('01/11–31/12 · 06:00–22:00'), findsOneWidget);
    expect(find.text('500 khách/ngày'), findsOneWidget);
    expect(find.text('Người lớn · 70.000₫'), findsOneWidget);
    expect(find.text('Trẻ em · 50.000₫'), findsOneWidget);
    expect(find.text('Hôm nay: bán 182 · vào 96 · giữ 12'), findsOneWidget);
    expect(_primary(tester).label, 'Sửa vé vào cửa');

    await tapOrganizer(tester, _key('managed-primary'));
    expect(w.location, '/organizer/entry/ent1/edit');
  });

  testWidgets('the ticket card opens S12.03-entry', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await tapOrganizer(tester, _key('managed-ticket-card'));
    expect(w.location, '/events/ent1/manage');
  });

  testWidgets('empty ticket card copy and "Tạo vé vào cửa"', (tester) async {
    final w = _world(onSale: false);
    await w.pump(tester, location: _path);

    expect(
      find.text('Chưa bán vé qua app · Khách đang thấy giá tham khảo'),
      findsOneWidget,
    );
    expect(_primary(tester).label, 'Tạo vé vào cửa');
    await tapOrganizer(tester, _key('managed-primary'));
    expect(w.location, '/organizer/entry/new?spot=bd');
  });

  testWidgets(
    'without business the primary is "Xác minh doanh nghiệp để bán vé" → S21.04',
    (tester) async {
      final w = _world(business: false, payout: false, onSale: false);
      await w.pump(tester, location: _path);

      expect(_primary(tester).label, 'Xác minh doanh nghiệp để bán vé');
      await tapOrganizer(tester, _key('managed-primary'));
      expect(w.location, '/verify/business');
    },
  );

  testWidgets('"Nhân viên soát vé" → S30.06, "Quét mã" → /scan', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await tapOrganizer(tester, _key('managed-gate-staff'));
    expect(w.location, '/organizer/gate-staff');

    w.router.go(_path);
    await settleOrganizer(tester);
    await tapOrganizer(tester, _key('managed-scan'));
    expect(w.location, '/scan');
  });

  testWidgets('"Xem trang điểm" opens S29.02', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await tapOrganizer(tester, _key('managed-view-spot'));
    expect(w.location, '/spots/bd');
  });

  testWidgets('residents tab lists the residents with their waivers', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await _tab(tester, 'Thợ tại điểm · 2');

    expect(find.text('Thêm thợ'), findsOneWidget);
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.text('Miễn vé thợ và khách · tối đa 4 khách'), findsOneWidget);
    expect(find.text('tới 31/12'), findsOneWidget);
    expect(find.text('Studio Mây'), findsOneWidget);
    expect(find.text('Miễn vé thợ'), findsOneWidget);
    expect(find.text('không hết hạn'), findsOneWidget);
  });

  testWidgets('an empty residents tab invites to add', (tester) async {
    final w = _world();
    w.spots.seedResidents('bd', const []);
    await w.pump(tester, location: _path);
    await _tab(tester, 'Thợ tại điểm · 0');
    expect(
      find.text(
        'Thêm thợ chụp thường xuyên ở đây để khách biết họ được miễn vé',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'add sheet with two switches, maxGuests and validUntil calls saveResident',
    (tester) async {
      final w = _world();
      await w.pump(tester, location: _path);
      await _tab(tester, 'Thợ tại điểm · 2');
      await tapOrganizer(tester, _key('resident-add'));

      expect(find.text('Thêm thợ tại điểm'), findsOneWidget);
      await tester.enterText(_key('resident-search'), 'hồng');
      await settleOrganizer(tester);
      // Only providers taking orders are offered.
      expect(find.text('Hồng Hà'), findsNothing);
      await tapOrganizer(tester, _key('resident-pick-nhung'));

      expect(find.text('Miễn vé cho thợ'), findsOneWidget);
      expect(find.text('Miễn vé cho khách của thợ'), findsOneWidget);
      await tapOrganizer(tester, _key('resident-waive-guests'));
      await tester.enterText(_key('resident-max-guests'), '4');
      await tester.pump();
      expect(find.text('Tối đa 4 khách mỗi buổi'), findsOneWidget);

      await tapOrganizer(tester, _key('resident-valid-until'));
      await tapOrganizer(tester, find.text('OK'));
      expect(find.textContaining('Thoả thuận giữa bạn và thợ'), findsOneWidget);

      await tapOrganizer(tester, _key('resident-save'));
      expectOnlyCall(w, (
        'saveResident',
        {
          'spotId': 'bd',
          'providerId': 'nhung',
          'waivesProvider': true,
          'waivesGuests': true,
          'maxGuests': 4,
          'validUntil': '2026-12-10',
        },
      ));
    },
  );

  testWidgets('remove via the red ConfirmSheet', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await _tab(tester, 'Thợ tại điểm · 2');
    await tapOrganizer(tester, _key('resident-tri'));
    await tapOrganizer(tester, _key('resident-remove'));

    expect(find.text('Gỡ Minh Trí khỏi thợ tại điểm?'), findsOneWidget);
    expectRedButton(tester, 'Gỡ thợ');
    await tapOrganizer(tester, find.widgetWithText(AppButton, 'Gỡ thợ'));
    expectOnlyCall(w, (
      'removeResident',
      {'spotId': 'bd', 'providerId': 'tri'},
    ));
  });

  testWidgets('info tab edits access (≤ 6 fees) and saves', (tester) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await _tab(tester, 'Thông tin');

    expect(_primary(tester).label, 'Lưu');
    expect(find.text('Giá tham khảo'), findsOneWidget);
    for (var i = 1; i < 6; i++) {
      await tapOrganizer(tester, _key('access-add'));
    }
    expect(find.byKey(const Key('access-label-5')), findsOneWidget);
    expect(find.text('Tối đa 6 dòng giá'), findsOneWidget);
    expect(tester.widget<AppButton>(_key('access-add')).onPressed, isNull);
    for (var i = 5; i > 1; i--) {
      await tapOrganizer(tester, _key('access-remove-$i'));
    }
    await tester.enterText(_key('access-label-1'), 'Trẻ em');
    await tester.enterText(_key('access-amount-1'), '50000');
    await tester.enterText(_key('info-description'), 'Vườn cúc ven sông');
    await tapOrganizer(tester, _key('managed-primary'));

    final (name, payload) = w.organizers.calls.single;
    expect(name, 'updateManagedSpot');
    expect(payload['spotId'], 'bd');
    expect(payload['description'], 'Vườn cúc ven sông');
    expect(payload['openHours'], {'start': '06:00', 'end': '22:00'});
    expect(payload['access'], {
      'type': 'ticket',
      'fees': [
        {'label': 'Người lớn', 'amountVnd': 70000},
        {'label': 'Trẻ em', 'amountVnd': 50000},
      ],
      'note': 'Trẻ dưới 80 cm miễn vé',
    });
    expect(find.text('Đã lưu'), findsOneWidget);
  });

  testWidgets('a fee line without a price is refused before saving', (
    tester,
  ) async {
    final w = _world();
    await w.pump(tester, location: _path);
    await _tab(tester, 'Thông tin');
    await tapOrganizer(tester, _key('access-add'));
    await tester.enterText(_key('access-label-1'), 'Trẻ em');
    await tapOrganizer(tester, _key('managed-primary'));
    expect(find.text('Nhập nhãn và giá lớn hơn 0'), findsOneWidget);
    expect(w.organizers.calls, isEmpty);
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
      await _tab(tester, 'Thợ tại điểm · 2');
      expect(tester.takeException(), isNull);
      await _tab(tester, 'Thông tin');
      expect(tester.takeException(), isNull);
      expect(_key('managed-primary'), findsOneWidget);
    });
  }

  group('"Sự kiện ở đây chờ bạn đồng ý"', () {
    void seedPending(OrganizerWorld w) => w.events.putEvent(
      detailOf(
        'ev1',
        title: 'Photo walk cúc hoạ mi',
        capacity: 30,
        status: EventStatus.draft,
        venue: const EventVenue(
          kind: VenueKind.managedSpot,
          spotId: 'bd',
          termsVersion: organizerTermsVersion,
        ),
        venueConsent: HostConsent.pending,
        venueConsentExpiresAt: organizerNow.add(
          const Duration(days: 2, hours: 5),
        ),
      ),
    );

    testWidgets(
      'lists the events waiting at this spot; a tap opens S11.02-venue-consent',
      (tester) async {
        final w = _world();
        seedPending(w);
        // Another spot's request and an answered one are not listed.
        w.events.putEvent(
          detailOf(
            'ev2',
            status: EventStatus.draft,
            venue: const EventVenue(
              kind: VenueKind.managedSpot,
              spotId: 'other',
              termsVersion: organizerTermsVersion,
            ),
            venueConsent: HostConsent.pending,
          ),
        );
        await w.pump(tester, location: _path);
        expect(find.text('Sự kiện ở đây chờ bạn đồng ý'), findsOneWidget);
        expect(find.text('Photo walk cúc hoạ mi'), findsOneWidget);
        expect(
          find.text('Quốc Bảo · 30 khách · hết hạn sau 2 ngày'),
          findsOneWidget,
        );
        expect(_key('managed-venue-request-ev2'), findsNothing);
        await tapOrganizer(tester, _key('managed-venue-request-ev1'));
        expect(find.text('Tổ chức tại Bãi đá sông Hồng?'), findsOneWidget);
        await tester.tap(_key('venue-consent-accept'));
        await settleOrganizer(tester);
        expect(w.events.venueAnswers.single.eventId, 'ev1');
      },
    );

    testWidgets('no section while nothing waits', (tester) async {
      final w = _world();
      await w.pump(tester, location: _path);
      expect(find.text('Sự kiện ở đây chờ bạn đồng ý'), findsNothing);
    });

    for (final b in Brightness.values) {
      testWidgets('fits 320 dp at 1.3× text with a request ($b)', (
        tester,
      ) async {
        final w = _world();
        seedPending(w);
        await w.pump(
          tester,
          location: _path,
          width: 320,
          height: 700,
          textScale: 1.3,
          brightness: b,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/organizer/organizer.dart';
import 'package:photobooking/data/spots/spot.dart';

/// The app reads these documents and never writes them, so a "round trip" is
/// the server's stored shape (mirrors `infra/organizer_firestore.ts`,
/// `event_firestore.ts`, `spot_firestore.ts`) → model → the callable payload
/// the app sends back where there is one.
Timestamp _ts(String iso) => Timestamp.fromDate(DateTime.parse(iso));

void main() {
  group('Organizer', () {
    test('maps organizers/{uid} and canSell needs all three flags', () {
      final o = organizerFromFirestore('org1', {
        'name': 'Bãi đá sông Hồng',
        'bio': 'Ban quản lý',
        'avatarUrl': null,
        'status': 'active',
        'phoneVerified': true,
        'businessVerified': true,
        'payoutAccountOk': false,
        'managedSpotIds': ['s1', 7, 's2'],
        'createdAt': _ts('2026-10-20T01:00:00Z'),
        'updatedAt': _ts('2026-10-21T01:00:00Z'),
      })!;
      expect(o.id, 'org1');
      expect(o.name, 'Bãi đá sông Hồng');
      expect(o.avatarUrl, isNull);
      expect(o.status, OrganizerStatus.active);
      expect(o.managedSpotIds, ['s1', 's2']);
      expect(o.createdAt, DateTime.parse('2026-10-20T01:00:00Z'));
      expect(o.canSell, isFalse);
      expect(o.copyWith(payoutAccountOk: true).canSell, isTrue);
      expect(
        o
            .copyWith(payoutAccountOk: true, status: OrganizerStatus.suspended)
            .canSell,
        isFalse,
      );
    });

    test('an unknown status reads as suspended; a missing doc is null', () {
      expect(organizerFromFirestore('x', null), isNull);
      expect(
        organizerFromFirestore('x', {'name': 'A', 'status': 'weird'})!.status,
        OrganizerStatus.suspended,
      );
    });
  });

  group('Resident', () {
    test('maps residents/{providerId} and sends the saveResident payload', () {
      final r = residentFromFirestore('p1', {
        'waivesProvider': true,
        'waivesGuests': true,
        'maxGuests': 3,
        'validUntil': '2026-12-31',
        'addedAt': _ts('2026-10-20T01:00:00Z'),
        'addedBy': 'org1',
      })!;
      expect(r.providerId, 'p1');
      expect(r.maxGuests, 3);
      expect(r.validUntil, '2026-12-31');
      expect(r.toCallable('s1'), {
        'spotId': 's1',
        'providerId': 'p1',
        'waivesProvider': true,
        'waivesGuests': true,
        'maxGuests': 3,
        'validUntil': '2026-12-31',
      });
    });

    test('waiverFor: nothing after validUntil (the domain predicate)', () {
      const r = Resident(
        providerId: 'p1',
        waivesProvider: true,
        waivesGuests: true,
        maxGuests: 2,
        validUntil: '2026-10-31',
      );
      expect(r.waiverFor('2026-10-31'), (
        provider: true,
        guests: true,
        maxGuests: 2,
      ));
      expect(r.waiverFor('2026-11-01'), (
        provider: false,
        guests: false,
        maxGuests: null,
      ));
    });
  });

  group('GateStaff', () {
    test('maps gate_staff rows, scans of today only, invite open 72 h', () {
      final g = gateStaffFromFirestore('org1', 'u9', {
        'staffUid': 'u9',
        'organizerId': 'org1',
        'status': 'invited',
        'invitedAt': _ts('2026-10-20T00:00:00Z'),
        'respondedAt': null,
        'scansToday': {'day': '2026-10-20', 'count': 12},
      })!;
      expect(g.organizerId, 'org1');
      expect(g.staffUid, 'u9');
      expect(g.status, GateStaffStatus.invited);
      expect(g.scansOn('2026-10-20'), 12);
      expect(g.scansOn('2026-10-21'), 0);
      expect(g.inviteOpen(DateTime.parse('2026-10-22T23:59:00Z')), isTrue);
      expect(g.inviteOpen(DateTime.parse('2026-10-23T00:00:00Z')), isFalse);
    });

    test('an unknown status reads as removed', () {
      expect(
        gateStaffFromFirestore('o', 'u', {'status': '?'})!.status,
        GateStaffStatus.removed,
      );
    });
  });

  group('SpotClaim', () {
    test('maps a claim and a proposal', () {
      final c = spotClaimFromFirestore('c1', {
        'spotId': null,
        'proposal': {'name': 'Vườn hoa', 'address': 'Long Biên'},
        'organizerId': 'org1',
        'status': 'rejected',
        'proofPaths': ['spot_claims/org1/x/a.jpg'],
        'note': '',
        'reason': 'Thiếu giấy tờ',
        'createdAt': _ts('2026-10-20T00:00:00Z'),
        'reviewedAt': _ts('2026-10-21T00:00:00Z'),
        'reviewedBy': 'staff1',
      })!;
      expect(c.spotId, isNull);
      expect(
        c.proposal,
        const SpotProposal(name: 'Vườn hoa', address: 'Long Biên'),
      );
      expect(c.status, SpotClaimStatus.rejected);
      expect(c.reason, 'Thiếu giấy tờ');
      expect(c.reviewedAt, DateTime.parse('2026-10-21T00:00:00Z'));
    });
  });

  group('EntryEvent and EntryDay', () {
    Map<String, dynamic> entryDoc() => {
      'title': 'Vé vào cửa Bãi đá',
      'type': 'entry',
      'status': 'open',
      'spotId': 's1',
      'host': {'type': 'organizer', 'id': 'org1', 'name': 'Bãi đá'},
      // sale range 2026-11-01 … 2026-11-30 (VN), stored as instants
      'startAt': _ts('2026-10-31T17:00:00Z'),
      'endAt': _ts('2026-11-30T17:00:00Z'),
      'closedWeekdays': [1],
      'closedDays': ['2026-11-20'],
      'openHours': {'start': '07:00', 'end': '18:00'},
      'ticketTypes': [
        {'id': 't1', 'name': 'Người lớn', 'price': 70000, 'hidden': false},
        {'id': 't2', 'name': 'Trẻ em', 'price': 30000, 'hidden': true},
      ],
      'dailyCapacity': 200,
      'refundCutoffHours': 48,
    };

    test('maps an entry event with sale days in Vietnam time', () {
      final e = entryEventFromFirestore('e1', entryDoc())!;
      expect(e.spotId, 's1');
      expect(e.organizerId, 'org1');
      expect(e.organizerName, 'Bãi đá');
      expect(e.status, EventStatus.open);
      expect(e.startDay, '2026-11-01');
      expect(e.endDay, '2026-11-30');
      expect(e.openHours, const OpenHours(start: '07:00', end: '18:00'));
      expect(e.ticketTypes.map((t) => t.id), ['t1', 't2']);
      expect(e.visibleTicketTypes.map((t) => t.id), ['t1']);
      expect(e.dailyCapacity, 200);
      expect(e.isOpenDay('2026-11-02'), isFalse, reason: 'Monday closed');
      expect(e.isOpenDay('2026-11-20'), isFalse, reason: 'closed day');
      expect(e.isOpenDay('2026-11-21'), isTrue);
      expect(e.isOpenDay('2026-12-01'), isFalse, reason: 'after the range');
      expect(e.openDays('2026-11-01', 3), [
        '2026-11-01',
        '2026-11-03',
        '2026-11-04',
      ]);
    });

    test('another event type is not an entry event', () {
      expect(
        entryEventFromFirestore('e2', {...entryDoc(), 'type': 'workshop'}),
        isNull,
      );
    });

    test('EntryDay maps entry_days and counts what is left', () {
      final d = entryDayFromFirestore({
        'eventId': 'e1',
        'day': '2026-11-21',
        'sold': 150,
        'held': 10,
        'checkedIn': 40,
        'closed': false,
      })!;
      expect(d.sold, 150);
      expect(d.left(200), 40);
      expect(d.left(null), isNull);
      expect(d.closed, isFalse);
    });

    test('EntryItem payload', () {
      expect(const EntryItem(ticketTypeId: 't1', qty: 2).toCallable(), {
        'ticketTypeId': 't1',
        'qty': 2,
      });
    });
  });

  group('Spot (#194) gains managedBy, access and openHours', () {
    Map<String, dynamic> spotDoc() => {
      'status': 'active',
      'name': 'Bãi đá sông Hồng',
      'managedBy': 'org1',
      'access': {
        'type': 'ticket',
        'fees': [
          {'label': 'Người lớn', 'amountVnd': 70000},
          {'label': 'bad'},
        ],
        'note': 'Gửi xe 10k',
        'updatedAt': _ts('2026-10-20T00:00:00Z'),
        'source': 'organizer',
      },
      'openHours': {'start': '07:00', 'end': '18:00'},
    };

    test('maps the three fields', () {
      final s = spotFromMap('s1', spotDoc())!;
      expect(s.managedBy, 'org1');
      expect(s.access!.type, SpotAccessType.ticket);
      expect(s.access!.fees, [
        const AccessFee(label: 'Người lớn', amountVnd: 70000),
      ]);
      expect(s.access!.source, SpotAccessSource.organizer);
      expect(s.access!.updatedAt, DateTime.parse('2026-10-20T00:00:00Z'));
      expect(s.openHours, const OpenHours(start: '07:00', end: '18:00'));
    });

    test('old spots read null; access goes back as the callable shape', () {
      final s = spotFromMap('s1', {'status': 'active', 'name': 'Hồ Tây'})!;
      expect(s.managedBy, isNull);
      expect(s.access, isNull);
      expect(s.openHours, isNull);
      final a = spotFromMap('s1', spotDoc())!.access!;
      expect(a.toCallable(), {
        'type': 'ticket',
        'fees': [
          {'label': 'Người lớn', 'amountVnd': 70000},
        ],
        'note': 'Gửi xe 10k',
      });
    });
  });
}

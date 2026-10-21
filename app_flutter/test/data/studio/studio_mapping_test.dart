import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/studio/studio_relation.dart';

Timestamp _ts(DateTime d) => Timestamp.fromDate(d);

void main() {
  group('studioRelationFrom', () {
    test('relation statuses and snapshots map', () {
      final r = studioRelationFrom('cuc_an_1', {
        'studioId': 'cuc',
        'memberId': 'an',
        'status': 'active',
        'initiatedBy': 'member',
        'createdAt': _ts(DateTime.utc(2026, 9, 20, 3)),
        'expiresAt': _ts(DateTime.utc(2026, 9, 27, 3)),
        'joinedAt': _ts(DateTime.utc(2026, 9, 21, 3)),
        'studioName': 'Studio Cúc',
        'studioAvatarUrl': 'https://img/cuc.jpg',
        'memberName': 'An',
        'memberAvatarUrl': '',
      })!;
      expect(r.id, 'cuc_an_1');
      expect(r.studioId, 'cuc');
      expect(r.memberId, 'an');
      expect(r.status, RelationStatus.active);
      expect(r.initiatedBy, RelationInitiator.member);
      expect(r.createdAt, DateTime.utc(2026, 9, 20, 3));
      expect(r.expiresAt, DateTime.utc(2026, 9, 27, 3));
      expect(r.joinedAt, DateTime.utc(2026, 9, 21, 3));
      expect(r.studioName, 'Studio Cúc');
      expect(r.studioAvatarUrl, 'https://img/cuc.jpg');
      expect(r.memberName, 'An');
      expect(r.memberAvatarUrl, isNull, reason: "'' is no avatar");
      expect(r.isOpen, isTrue);

      for (final s in RelationStatus.values) {
        expect(
          studioRelationFrom('x', {
            'studioId': 'cuc',
            'memberId': 'an',
            'status': s.name,
            'createdAt': '2026-09-20T03:00:00.000Z',
            'expiresAt': '2026-09-27T03:00:00.000Z',
          })!.status,
          s,
        );
      }
    });

    test('defaults: invited by the studio, no join date, empty names', () {
      final r = studioRelationFrom('x', {
        'studioId': 'cuc',
        'memberId': 'binh',
        'status': 'invited',
        'createdAt': '2026-09-20T03:00:00.000Z',
        'expiresAt': '2026-09-27T03:00:00.000Z',
      })!;
      expect(r.initiatedBy, RelationInitiator.studio);
      expect(r.joinedAt, isNull);
      expect(r.studioName, '');
      expect(r.memberName, '');
      expect(r.isOpen, isTrue);
    });

    test('an unknown status or missing party is skipped', () {
      expect(
        studioRelationFrom('x', {
          'studioId': 'cuc',
          'memberId': 'an',
          'status': 'weird',
        }),
        isNull,
      );
      expect(
        studioRelationFrom('x', {'studioId': 'cuc', 'status': 'active'}),
        isNull,
      );
    });

    test('closed statuses are not open', () {
      for (final s in [
        RelationStatus.declined,
        RelationStatus.cancelled,
        RelationStatus.expired,
        RelationStatus.left,
        RelationStatus.removed,
      ]) {
        expect(s.isOpen, isFalse, reason: s.name);
      }
    });
  });

  group('studioQuotaFrom', () {
    // 2026-10-21 10:00 in Vietnam.
    final now = DateTime.utc(2026, 10, 21, 3);

    test('counts the actions used today on each side', () {
      final doc = {
        'dayKey': '2026-10-21',
        'studioActions': 1,
        'memberActions': 2,
      };
      expect(
        studioQuotaFrom(doc, studio: true, now: now),
        const StudioQuota(left: 4, max: 5),
      );
      expect(
        studioQuotaFrom(doc, studio: false, now: now),
        const StudioQuota(left: 1, max: 3),
      );
    });

    test('quota left resets on another VN day', () {
      final doc = {
        'dayKey': '2026-10-20',
        'studioActions': 5,
        'memberActions': 3,
      };
      expect(studioQuotaFrom(doc, studio: true, now: now).left, 5);
      expect(studioQuotaFrom(doc, studio: false, now: now).left, 3);
      // 23:30 UTC on the 20th is already the 21st in Vietnam.
      expect(
        studioQuotaFrom(
          {'dayKey': '2026-10-21', 'studioActions': 5},
          studio: true,
          now: DateTime.utc(2026, 10, 20, 23, 30),
        ).left,
        0,
      );
    });

    test('no document or overspent never goes below zero', () {
      expect(
        studioQuotaFrom(null, studio: true, now: now),
        const StudioQuota(left: 5, max: 5),
      );
      expect(
        studioQuotaFrom(
          {'dayKey': '2026-10-21', 'memberActions': 9},
          studio: false,
          now: now,
        ).left,
        0,
      );
    });
  });

  group('callable rows', () {
    test('invite candidates map every state', () {
      final c = inviteCandidateFrom({
        'uid': 'binh',
        'name': 'Bình',
        'avatarUrl': null,
        'verified': true,
        'tomatoPct': 92,
        'areaLabel': 'Hà Nội',
        'state': 'cooldown',
        'availableFrom': '2026-10-25T03:00:00.000Z',
      })!;
      expect(c.uid, 'binh');
      expect(c.name, 'Bình');
      expect(c.verified, isTrue);
      expect(c.tomatoPct, 92);
      expect(c.areaLabel, 'Hà Nội');
      expect(c.state, InviteState.cooldown);
      expect(c.availableFrom, DateTime.utc(2026, 10, 25, 3));

      const codes = {
        'invitable': InviteState.invitable,
        'in_studio': InviteState.inStudio,
        'cooldown': InviteState.cooldown,
        'invited': InviteState.invited,
        'member': InviteState.member,
      };
      for (final e in codes.entries) {
        expect(
          inviteCandidateFrom({'uid': 'u', 'state': e.key})!.state,
          e.value,
        );
      }
      final other = inviteCandidateFrom({
        'uid': 'dung',
        'state': 'in_studio',
        'studioName': 'Studio Mây',
      })!;
      expect(other.studioName, 'Studio Mây');
      expect(inviteCandidateFrom({'uid': 'u', 'state': 'weird'}), isNull);
      expect(inviteCandidateFrom({'state': 'invitable'}), isNull);
    });

    test('assignment options map states and busy times', () {
      final o = assignmentOptionFrom({
        'uid': 'an',
        'name': 'An',
        'avatarUrl': 'https://img/an.jpg',
        'tomatoPct': 88,
        'reviewCount': 12,
        'state': 'busy',
        'busyStart': '15:00',
        'busyEnd': '18:00',
      })!;
      expect(o.uid, 'an');
      expect(o.state, AssignState.busy);
      expect((o.busyStart, o.busyEnd), ('15:00', '18:00'));
      expect(o.tomatoPct, 88);
      expect(o.reviewCount, 12);
      expect(o.selectable, isFalse);
      for (final s in AssignState.values) {
        expect(assignmentOptionFrom({'uid': 'u', 'state': s.name})!.state, s);
      }
      expect(
        assignmentOptionFrom({'uid': 'u', 'state': 'free'})!.selectable,
        isTrue,
      );
      expect(assignmentOptionFrom({'uid': 'u', 'state': 'x'}), isNull);
    });
  });
}

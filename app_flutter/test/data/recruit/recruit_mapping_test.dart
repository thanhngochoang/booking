import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recruit/firestore_recruit_repository.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';

final _created = DateTime.utc(2026, 10, 20, 3);
final _expires = DateTime.utc(2026, 11, 19, 3);

/// A `recruitPosts/{id}` document as Task 5's `recruitPostToDoc` writes it.
Map<String, dynamic> postDoc({
  Object? kind = 'collaborator',
  Object? status = 'open',
  Object? feeHint = const {'type': 'per_shoot', 'amount': 800000},
  Object? frequency = 'weekly',
}) => {
  'studioId': 'cuc',
  'studio': {
    'name': 'Studio Cúc',
    'avatarUrl': 'https://x.test/cuc.jpg',
    'businessVerified': true,
  },
  'kind': kind,
  'title': 'Tuyển CTV chụp cưới cuối tuần',
  'specialties': ['wedding', 'family'],
  'areas': ['hcm-q1', 'hcm-q3'],
  'frequency': frequency,
  'feeHint': feeHint,
  'requirements': 'Có máy full-frame.',
  'status': status,
  'renewed': true,
  'applicationCount': 2,
  'matchKeys': ['a=hcm-q1|s=wedding', 'a=hcm-q1|s=family'],
  'filterKeys': ['k=collaborator', 'a=hcm-q1'],
  'createdAt': Timestamp.fromDate(_created),
  'updatedAt': Timestamp.fromDate(_created),
  'expiresAt': Timestamp.fromDate(_expires),
  'closedAt': null,
};

Map<String, dynamic> applicationDoc({Object? status = 'applied'}) => {
  'postId': 'post1',
  'studioId': 'cuc',
  'applicantId': 'hoa',
  'kind': 'member',
  'postTitle': 'Tuyển thợ vào studio',
  'applicant': {'name': 'Hòa', 'avatarUrl': null},
  'status': status,
  'message': 'Em chụp cưới 2 năm.',
  'samplePostIds': ['s1', 's2'],
  'termsAcceptedAt': null,
  'createdAt': Timestamp.fromDate(_created),
  'expiresAt': Timestamp.fromDate(_created.add(const Duration(days: 7))),
  'respondedAt': Timestamp.fromDate(_created.add(const Duration(hours: 2))),
};

void main() {
  group('recruitPostFrom', () {
    test('recruitPostFrom parses every field', () {
      final p = recruitPostFrom('post1', postDoc())!;
      expect(p.id, 'post1');
      expect(p.studioId, 'cuc');
      expect(p.studioName, 'Studio Cúc');
      expect(p.studioAvatarUrl, 'https://x.test/cuc.jpg');
      expect(p.studioBusinessVerified, isTrue);
      expect(p.kind, RecruitKind.collaborator);
      expect(p.title, 'Tuyển CTV chụp cưới cuối tuần');
      expect(p.specialties, ['wedding', 'family']);
      expect(p.areas, ['hcm-q1', 'hcm-q3']);
      expect(p.frequency, RecruitFrequency.weekly);
      expect(p.fee, const PerShootFee(800000));
      expect(p.requirements, 'Có máy full-frame.');
      expect(p.status, RecruitPostStatus.open);
      expect(p.renewed, isTrue);
      expect(p.applicationCount, 2);
      expect(p.matchKeys, ['a=hcm-q1|s=wedding', 'a=hcm-q1|s=family']);
      expect(p.createdAt, _created);
      expect(p.expiresAt, _expires);
      expect(p.createdAt.isUtc, isTrue);
    });

    test('an unknown kind or status drops the row (null)', () {
      expect(recruitPostFrom('p', postDoc(kind: 'employee')), isNull);
      expect(recruitPostFrom('p', postDoc(status: 'draft')), isNull);
      expect(recruitPostFrom('p', postDoc(kind: null)), isNull);
      expect(recruitPostFrom('p', {...postDoc(), 'studioId': null}), isNull);
      expect(recruitPostFrom('p', {...postDoc(), 'createdAt': null}), isNull);
      // An unknown frequency reads as occasional, like the server mapping.
      expect(
        recruitPostFrom('p', postDoc(frequency: 'daily'))!.frequency,
        RecruitFrequency.occasional,
      );
    });

    test('feeHint per_shoot and negotiable', () {
      expect(
        recruitPostFrom(
          'p',
          postDoc(feeHint: {'type': 'per_shoot', 'amount': 1500000}),
        )!.fee,
        const PerShootFee(1500000),
      );
      expect(
        recruitPostFrom('p', postDoc(feeHint: {'type': 'negotiable'}))!.fee,
        const NegotiableFee(),
      );
      // A per-shoot hint without an amount, or garbage, is negotiable.
      expect(
        recruitPostFrom('p', postDoc(feeHint: {'type': 'per_shoot'}))!.fee,
        const NegotiableFee(),
      );
      expect(
        recruitPostFrom('p', postDoc(feeHint: 'x'))!.fee,
        const NegotiableFee(),
      );
    });

    test('ISO strings (callable answers) parse like Timestamps', () {
      final p = recruitPostFrom('p', {
        ...postDoc(),
        'createdAt': _created.toIso8601String(),
        'expiresAt': _expires.toIso8601String(),
      })!;
      expect(p.createdAt, _created);
      expect(p.expiresAt, _expires);
    });
  });

  group('recruitApplicationFrom', () {
    test('applicationFrom parses every field', () {
      final a = recruitApplicationFrom('post1_hoa', applicationDoc())!;
      expect(a.id, 'post1_hoa');
      expect(a.postId, 'post1');
      expect(a.studioId, 'cuc');
      expect(a.applicantId, 'hoa');
      expect(a.kind, RecruitKind.member);
      expect(a.postTitle, 'Tuyển thợ vào studio');
      expect(a.applicantName, 'Hòa');
      expect(a.applicantAvatarUrl, isNull);
      expect(a.status, ApplicationStatus.applied);
      expect(a.message, 'Em chụp cưới 2 năm.');
      expect(a.samplePostIds, ['s1', 's2']);
      expect(a.createdAt, _created);
      expect(a.expiresAt, _created.add(const Duration(days: 7)));
      expect(a.respondedAt, _created.add(const Duration(hours: 2)));
    });

    test('an unknown status or missing parties drop the row', () {
      expect(
        recruitApplicationFrom('x', applicationDoc(status: 'weird')),
        isNull,
      );
      expect(
        recruitApplicationFrom('x', {...applicationDoc(), 'applicantId': 1}),
        isNull,
      );
      for (final s in ApplicationStatus.values) {
        expect(
          recruitApplicationFrom('x', applicationDoc(status: s.code))!.status,
          s,
        );
      }
    });
  });

  group('recruitCountersFrom', () {
    // Tuesday 21/10/2026 10:00 in Vietnam.
    final now = DateTime.utc(2026, 10, 21, 3);

    test('countersFrom: a missing doc is zeros and full quotas', () {
      final c = recruitCountersFrom(null);
      expect(c.openPostCount, 0);
      expect(c.activeCollabCount, 0);
      expect(c.pendingInviteCount, 0);
      expect(c.openApplicationCount, 0);
      expect(c.recruitBlockedUntil, isNull);
      expect(c.postActionsLeft(now), kRecruitPostDailyActions);
      expect(c.collabActionsLeft(now), kRecruitCollabDailyActions);
      expect(c.applyActionsLeft(now), kRecruitApplyDaily);
      expect(c.isBlocked(now), isFalse);
    });

    test('countersFrom: postActionsLeft is 5 on a new VN day', () {
      final c = recruitCountersFrom({
        'openPostCount': 2,
        'postActions': {'day': '2026-10-21', 'count': 3},
        'activeCollabCount': 4,
        'pendingInviteCount': 1,
        'collabActions': {'day': '2026-10-21', 'count': 12},
        'openApplicationCount': 7,
        'applyActions': {'day': '2026-10-20', 'count': 3},
        'recruitBlockedUntil': Timestamp.fromDate(DateTime.utc(2026, 11, 1)),
      });
      expect(c.openPostCount, 2);
      expect(c.activeCollabCount, 4);
      expect(c.pendingInviteCount, 1);
      expect(c.openApplicationCount, 7);
      expect(c.postActionsLeft(now), 2);
      expect(c.collabActionsLeft(now), 0, reason: 'never negative');
      expect(c.applyActionsLeft(now), 3, reason: 'counted yesterday');
      expect(c.recruitBlockedUntil, DateTime.utc(2026, 11, 1));
      expect(c.isBlocked(now), isTrue);
      // 17:00Z is midnight in Vietnam: a new day restores the quota.
      final tomorrow = DateTime.utc(2026, 10, 21, 17);
      expect(c.postActionsLeft(tomorrow), kRecruitPostDailyActions);
      expect(kRecruitPostDailyActions, 5);
    });
  });

  group('providerFactsFrom', () {
    test('reads role and the photographer fields; no doc is null', () {
      final f = providerFactsFrom(
        role: 'photographer',
        photographer: {
          'providerType': 'studio',
          'acceptingOrders': true,
          'businessVerified': true,
          'recruitMatchKeys': ['a=hue|s=wedding'],
        },
      )!;
      expect(f.isProviderAccount, isTrue);
      expect(f.isStudio, isTrue);
      expect(f.acceptingOrders, isTrue);
      expect(f.businessVerified, isTrue);
      expect(f.recruitMatchKeys, ['a=hue|s=wedding']);
      expect(
        providerFactsFrom(role: 'photographer', photographer: null),
        isNull,
      );
      final customerMode = providerFactsFrom(
        role: 'customer',
        photographer: {},
      )!;
      expect(customerMode.isProviderAccount, isFalse);
      expect(customerMode.acceptingOrders, isFalse);
      expect(customerMode.businessVerified, isFalse);
      expect(customerMode.recruitMatchKeys, isEmpty);
      expect(customerMode.studioId, isNull);
    });

    test('reads the studio a provider is a member of (S27.02 member line)', () {
      final f = providerFactsFrom(
        role: 'photographer',
        photographer: {'providerType': 'individual', 'studioId': 'cuc'},
      )!;
      expect(f.studioId, 'cuc');
      expect(
        providerFactsFrom(
          role: 'photographer',
          photographer: {'studioId': ''},
        )!.studioId,
        isNull,
      );
    });
  });
}

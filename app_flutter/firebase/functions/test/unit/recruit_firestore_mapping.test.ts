import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import {
  EMPTY_COUNTERS,
  type CollabJob,
  type Collaboration,
  type RecruitApplication,
  type RecruitCounters,
  type RecruitPost,
} from '@photobooking/domain';
import {
  applicationFromDoc,
  applicationToDoc,
  collabJobFromDoc,
  collabJobToDoc,
  collaborationFromDoc,
  collaborationToDoc,
  countersFromDoc,
  countersToDoc,
  recruitPostFromDoc,
  recruitPostToDoc,
} from '../../src/infra/recruit_mapping.js';

const T0 = new Date('2026-10-10T03:00:00.000Z');
const at = (h: number): Date => new Date(T0.getTime() + h * 3_600_000);

const POST: RecruitPost = {
  id: 'post_1',
  studioId: 'studio_cuc',
  studio: { name: 'Cúc Studio', avatarUrl: null, businessVerified: true },
  kind: 'collaborator',
  title: 'Tuyển CTV chụp cưới cuối tuần',
  specialties: ['wedding', 'family'],
  areas: ['hcm-q1'],
  frequency: 'weekly',
  feeHint: { type: 'per_shoot', amount: 800_000 },
  requirements: '',
  status: 'open',
  renewed: false,
  applicationCount: 2,
  matchKeys: ['a=hcm-q1|s=wedding', 'a=hcm-q1|s=family'],
  filterKeys: ['k=collaborator', 'a=hcm-q1'],
  createdAt: T0,
  updatedAt: at(1),
  expiresAt: at(720),
  closedAt: null,
};

const APPLICATION: RecruitApplication = {
  id: 'post_1_an',
  postId: 'post_1',
  studioId: 'studio_cuc',
  applicantId: 'an',
  kind: 'collaborator',
  postTitle: POST.title,
  applicant: { name: 'An', avatarUrl: 'https://img.test/an.jpg' },
  status: 'applied',
  message: 'Em chụp cưới 3 năm.',
  samplePostIds: ['p1', 'p2'],
  termsAcceptedAt: T0,
  createdAt: T0,
  expiresAt: at(168),
  respondedAt: null,
};

const COLLAB: Collaboration = {
  id: 'studio_cuc_dung',
  studioId: 'studio_cuc',
  collaboratorId: 'dung',
  studio: { name: 'Cúc Studio', avatarUrl: null },
  collaborator: { name: 'Dũng', avatarUrl: 'https://img.test/dung.jpg' },
  status: 'active',
  initiatedBy: 'application',
  applicationId: 'post_1_dung',
  defaultFee: 600_000,
  termsAcceptedAt: T0,
  createdAt: T0,
  expiresAt: at(168),
  activeAt: at(2),
  endedAt: null,
  endedBy: null,
  updatedAt: at(2),
};

const JOB: CollabJob = {
  id: 'bk_1_dung',
  bookingId: 'bk_1',
  studioId: 'studio_cuc',
  collaboratorId: 'dung',
  customerId: 'lan',
  studioName: 'Cúc Studio',
  collaboratorName: 'Dũng',
  shoot: { day: '2026-10-14', start: '09:00', end: '13:00', serviceName: 'Cưới 4 giờ', placeName: 'Nhà thờ Đức Bà' },
  shootEndsAt: at(100),
  agreedFee: 600_000,
  offerStatus: 'accepted',
  offerAt: T0,
  offerExpiresAt: at(6),
  acceptedAt: at(1),
  declinedAt: null,
  closedAt: null,
  payStatus: 'paid_reported',
  pay: {
    amount: 600_000,
    dueAt: at(110),
    paidOn: '2026-10-15',
    method: 'bank',
    reportedAt: at(120),
    receivedAt: null,
    disputedAt: null,
    overdueFlaggedAt: null,
    disputeFlaggedAt: null,
    checkAfter: null,
  },
  createdAt: T0,
  updatedAt: at(120),
};

const COUNTERS: RecruitCounters = {
  openPostCount: 1,
  postActions: { day: '2026-10-10', count: 2 },
  activeCollabCount: 3,
  pendingInviteCount: 1,
  collabActions: null,
  openApplicationCount: 4,
  applyActions: { day: '2026-10-09', count: 3 },
  notices: { day: '2026-10-10', count: 2, postIds: ['post_1', 'post_2'] },
  unpaidFlags: [at(-48), at(-24)],
  recruitBlockedUntil: at(720),
};

describe('S27 Firestore mapping', () => {
  it('round-trips every S27 doc, including null fields and nested pay', () => {
    const postDoc = recruitPostToDoc(POST);
    assert.ok(postDoc.createdAt instanceof Timestamp);
    assert.equal(postDoc.closedAt, null);
    assert.equal('id' in postDoc, false);
    assert.deepEqual(recruitPostFromDoc(POST.id, postDoc), POST);
    const negotiable: RecruitPost = { ...POST, feeHint: { type: 'negotiable' }, status: 'closed', closedAt: at(3) };
    assert.deepEqual(recruitPostFromDoc(POST.id, recruitPostToDoc(negotiable)), negotiable);

    assert.deepEqual(applicationFromDoc(APPLICATION.id, applicationToDoc(APPLICATION)), APPLICATION);
    const member: RecruitApplication = { ...APPLICATION, kind: 'member', termsAcceptedAt: null, status: 'accepted', respondedAt: at(5) };
    assert.deepEqual(applicationFromDoc(member.id, applicationToDoc(member)), member);

    assert.deepEqual(collaborationFromDoc(COLLAB.id, collaborationToDoc(COLLAB)), COLLAB);
    const ended: Collaboration = { ...COLLAB, status: 'ended', defaultFee: null, applicationId: null, endedAt: at(9), endedBy: 'collaborator' };
    assert.deepEqual(collaborationFromDoc(ended.id, collaborationToDoc(ended)), ended);

    const jobDoc = collabJobToDoc(JOB);
    assert.equal(jobDoc.pay.overdueFlaggedAt, null, 'explicit null so the sweep query matches');
    assert.ok(jobDoc.pay.dueAt instanceof Timestamp);
    assert.deepEqual(collabJobFromDoc(JOB.id, jobDoc), JOB);
    const pending: CollabJob = {
      ...JOB,
      offerStatus: 'pending',
      acceptedAt: null,
      payStatus: 'none',
      pay: { ...JOB.pay, dueAt: null, paidOn: null, method: null, reportedAt: null, checkAfter: at(100) },
    };
    assert.deepEqual(collabJobFromDoc(pending.id, collabJobToDoc(pending)), pending);
  });

  it('counters round-trip notices.postIds, the dailies and the unpaid flags; a missing doc is EMPTY_COUNTERS', () => {
    const doc = countersToDoc(COUNTERS);
    assert.ok(doc.unpaidFlags[0] instanceof Timestamp);
    assert.deepEqual(doc.notices, { day: '2026-10-10', count: 2, postIds: ['post_1', 'post_2'] });
    assert.deepEqual(countersFromDoc(doc), COUNTERS);
    assert.deepEqual(countersFromDoc(undefined), EMPTY_COUNTERS);
    assert.deepEqual(countersFromDoc({ openPostCount: 2 }), { ...EMPTY_COUNTERS, openPostCount: 2 });
    assert.deepEqual(countersFromDoc(countersToDoc(EMPTY_COUNTERS)), EMPTY_COUNTERS);
  });

  it('a doc without its identifying fields reads as null; unknown codes fall back', () => {
    assert.equal(recruitPostFromDoc('x', undefined), null);
    assert.equal(recruitPostFromDoc('x', { ...recruitPostToDoc(POST), kind: 'employee' }), null);
    assert.equal(applicationFromDoc('x', { postId: 'p' }), null);
    assert.equal(collaborationFromDoc('x', { ...collaborationToDoc(COLLAB), status: 'weird' }), null);
    assert.equal(collabJobFromDoc('x', { ...collabJobToDoc(JOB), offerAt: null }), null);
    assert.equal(collabJobFromDoc('x', { ...collabJobToDoc(JOB), payStatus: 'weird' })?.payStatus, 'none');
  });
});

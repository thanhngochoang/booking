import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { beforeEach, describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import {
  applyToRecruitPost,
  assignBooking,
  createBookingDraft,
  createRecruitPost,
  inviteCollaborator,
  memberActivation,
  respondCollabInvite,
  respondCollabOffer,
  respondRecruitApplication,
  type Booking,
  type CollabJob,
  type Collaboration,
  type StudioBookingDeps,
} from '@photobooking/domain';
import { FirestoreBookingStore } from '../../src/infra/booking_firestore.js';
import { FirestoreProviderOrderGate } from '../../src/infra/booking_readers.js';
import { FirestoreShootMilestones } from '../../src/infra/recruit_firestore.js';
import { collabJobToDoc, collaborationToDoc } from '../../src/infra/recruit_mapping.js';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';
import { FirestoreStudioRoster } from '../../src/infra/studio_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';
import { paymentWorld } from './support/payment_world.js';
import { AN, BINH, DUNG, recruitWorld, seedRecruitPeople, type RecruitTestWorld } from './support/recruit_fixtures.js';
import { CUSTOMER, NOW, STUDIO, seedBooking, studioBooking } from './support/studio_fixtures.js';

const POST_INPUT = {
  kind: 'collaborator',
  title: 'Tuyển CTV chụp cưới cuối tuần',
  specialties: ['wedding'],
  areas: ['hcm-q1'],
  frequency: 'weekly',
  feeHint: { type: 'per_shoot', amount: 800_000 },
  requirements: '',
};

const H = 3_600_000;

function collab(over: Partial<Collaboration> = {}): Collaboration {
  return {
    id: `${STUDIO}_${DUNG}`,
    studioId: STUDIO,
    collaboratorId: DUNG,
    studio: { name: 'Cúc Studio', avatarUrl: null },
    collaborator: { name: 'Dũng', avatarUrl: null },
    status: 'active',
    initiatedBy: 'studio',
    applicationId: null,
    defaultFee: 600_000,
    termsAcceptedAt: NOW,
    createdAt: NOW,
    expiresAt: new Date(NOW.getTime() + 168 * H),
    activeAt: NOW,
    endedAt: null,
    endedBy: null,
    updatedAt: NOW,
    ...over,
  };
}

function job(id: string, over: Partial<CollabJob> = {}): CollabJob {
  const base: CollabJob = {
    id: `${id}_${DUNG}`,
    bookingId: id,
    studioId: STUDIO,
    collaboratorId: DUNG,
    customerId: CUSTOMER,
    studioName: 'Cúc Studio',
    collaboratorName: 'Dũng',
    shoot: { day: '2026-10-14', start: '09:00', end: '13:00', serviceName: 'Cưới', placeName: 'Q1' },
    shootEndsAt: new Date(NOW.getTime() - H),
    agreedFee: 600_000,
    offerStatus: 'accepted',
    offerAt: NOW,
    offerExpiresAt: new Date(NOW.getTime() + 6 * H),
    acceptedAt: NOW,
    declinedAt: null,
    closedAt: null,
    payStatus: 'none',
    pay: {
      amount: 600_000, dueAt: null, paidOn: null, method: null, reportedAt: null, receivedAt: null,
      disputedAt: null, overdueFlaggedAt: null, disputeFlaggedAt: null, checkAfter: null,
    },
    createdAt: NOW,
    updatedAt: NOW,
  };
  return { ...base, ...over, pay: { ...base.pay, ...(over.pay ?? {}) } };
}

describe('FirestoreRecruitStore over the domain use cases', () => {
  let db: MemoryFirestore;
  let w: RecruitTestWorld;

  beforeEach(() => {
    db = new MemoryFirestore();
    seedRecruitPeople(db);
    w = recruitWorld(db);
  });

  it('create, apply and accept a collaborator write the post, the application, the collaboration and both counters', async () => {
    const { postId } = await createRecruitPost(w.deps, STUDIO, POST_INPUT);
    const post = db.data(`recruitPosts/${postId}`);
    assert.equal(post?.studioId, STUDIO);
    assert.equal(post?.status, 'open');
    assert.ok(post?.expiresAt instanceof Timestamp);
    assert.deepEqual(post?.matchKeys, ['a=hcm-q1|s=wedding']);
    assert.equal(db.data(`photographers/${STUDIO}/private/recruit`)?.openPostCount, 1);

    await applyToRecruitPost(w.deps, AN, { postId, message: 'Em chụp cưới.', samplePostIds: [], acceptTerms: true });
    assert.equal(db.data(`recruitApplications/${postId}_${AN}`)?.status, 'applied');
    assert.equal(db.data(`photographers/${AN}/private/recruit`)?.openApplicationCount, 1);

    await respondRecruitApplication(w.deps, STUDIO, { postId, applicantId: AN, accept: true });
    const c = db.data(`studio_collaborations/${STUDIO}_${AN}`);
    assert.equal(c?.status, 'active');
    assert.equal(c?.initiatedBy, 'application');
    assert.equal(db.data(`photographers/${STUDIO}/private/recruit`)?.activeCollabCount, 1);
    assert.equal(db.data(`photographers/${AN}/private/recruit`)?.activeCollabCount, 1);
    assert.equal(db.data(`photographers/${AN}/private/recruit`)?.openApplicationCount, 0);
  });

  it('an unverified applicant is refused not_accepting_orders through the live order gate', async () => {
    const { postId } = await createRecruitPost(w.deps, STUDIO, POST_INPUT);
    await assert.rejects(
      applyToRecruitPost(w.deps, BINH, { postId, message: '', samplePostIds: [], acceptTerms: true }),
      { code: 'not_accepting_orders' },
    );
  });

  it('a new invite after an ended collaboration archives the old one to history in the same transaction', async () => {
    db.seed(`studio_collaborations/${STUDIO}_${DUNG}`, collaborationToDoc(collab({
      status: 'ended', endedAt: new Date(NOW.getTime() - 5 * 24 * H), endedBy: 'collaborator',
    })));
    await inviteCollaborator(w.deps, STUDIO, { collaboratorId: DUNG });
    assert.equal(db.data(`studio_collaborations/${STUDIO}_${DUNG}`)?.status, 'invited');
    const history = [...db.docs.keys()].filter((k) => k.startsWith(`studio_collaborations/${STUDIO}_${DUNG}/history/`));
    assert.equal(history.length, 1);
    assert.equal(db.data(history[0] ?? '')?.status, 'ended');
    assert.equal(db.data(`photographers/${STUDIO}/private/recruit`)?.pendingInviteCount, 1);

    await respondCollabInvite(w.deps, DUNG, { studioId: STUDIO, accept: true, acceptTerms: true });
    assert.equal(db.data(`studio_collaborations/${STUDIO}_${DUNG}`)?.status, 'active');
    assert.equal(db.data(`photographers/${STUDIO}/private/recruit`)?.pendingInviteCount, 0);
  });

  it('getMemberState reads the S26 lock, the studio, its open invites and quota, the collaboration and an open pair', async () => {
    db.seed(`photographers/${AN}`, { ...db.data(`photographers/${AN}`), studioCooldownUntil: Timestamp.fromDate(new Date(NOW.getTime() + H)) });
    db.seed(`photographers/${STUDIO}`, { ...db.data(`photographers/${STUDIO}`), memberCount: 2 });
    db.seed(`studio_members/${STUDIO}_x_1`, { studioId: STUDIO, memberId: 'x', status: 'invited', expiresAt: Timestamp.fromDate(new Date(NOW.getTime() + H)) });
    db.seed(`studio_members/${STUDIO}_y_1`, { studioId: STUDIO, memberId: 'y', status: 'invited', expiresAt: Timestamp.fromDate(new Date(NOW.getTime() - H)) });
    db.seed(`studio_members/${STUDIO}_${AN}_1`, { studioId: STUDIO, memberId: AN, status: 'requested', expiresAt: Timestamp.fromDate(new Date(NOW.getTime() + H)) });
    db.seed(`studio_quota/${STUDIO}`, { dayKey: '2026-10-10', studioActions: 2, memberActions: 0 });
    db.seed(`studio_collaborations/${STUDIO}_${AN}`, collaborationToDoc(collab({ id: `${STUDIO}_${AN}`, collaboratorId: AN })));
    const s = await w.store.runTransaction((tx) => tx.getMemberState(STUDIO, AN));
    assert.deepEqual(s, {
      member: { studioId: null, studioCooldownUntil: new Date(NOW.getTime() + H).toISOString() },
      studio: { memberCount: 2, businessVerified: true },
      openInvites: 1,
      quota: { dayKey: '2026-10-10', studioActions: 2, memberActions: 0 },
      activeCollabWithStudio: true,
      pairOpen: true,
    });
    assert.equal(await w.store.runTransaction((tx) => tx.activeMembershipStudioOf(AN)), null);
  });

  it('putMember writes the S26 relation (+ applicationId), the lock, memberCount + 1 and the studio quota', async () => {
    const m = memberActivation({
      studio: { uid: STUDIO, name: 'Cúc Studio', avatarUrl: null },
      member: { uid: AN, name: 'An', avatarUrl: null },
      applicationId: 'post_1_an',
      quota: null,
      now: NOW,
    });
    await w.store.runTransaction(async (tx) => tx.putMember(m));
    const rel = db.data(`studio_members/${m.relation.id}`);
    assert.equal(rel?.status, 'active');
    assert.equal(rel?.initiatedBy, 'member');
    assert.equal(rel?.applicationId, 'post_1_an');
    assert.equal(db.data(`photographers/${AN}`)?.studioId, STUDIO);
    assert.ok(db.data(`photographers/${AN}`)?.studioJoinedAt instanceof Timestamp);
    assert.equal(db.data(`photographers/${STUDIO}`)?.memberCount, 1);
    assert.deepEqual(db.data(`studio_quota/${STUDIO}`), { dayKey: m.quota.dayKey, studioActions: 1, memberActions: 0 });
    assert.equal(await w.store.runTransaction((tx) => tx.activeMembershipStudioOf(AN)), STUDIO);
  });

  it('the sweep queries find only due items, oldest first, and payPending follows pay.checkAfter', async () => {
    const past = new Date(NOW.getTime() - H);
    const later = new Date(NOW.getTime() + H);
    db.seed('collab_jobs/j_off_1', collabJobToDoc(job('j_off_1', { offerStatus: 'pending', offerExpiresAt: past })));
    db.seed('collab_jobs/j_off_2', collabJobToDoc(job('j_off_2', { offerStatus: 'pending', offerExpiresAt: later })));
    db.seed('collab_jobs/j_pay_1', collabJobToDoc(job('j_pay_1', { pay: { checkAfter: new Date(NOW.getTime() - 2 * H) } as CollabJob['pay'] })));
    db.seed('collab_jobs/j_pay_2', collabJobToDoc(job('j_pay_2', { pay: { checkAfter: past } as CollabJob['pay'] })));
    db.seed('collab_jobs/j_pay_3', collabJobToDoc(job('j_pay_3', { pay: { checkAfter: later } as CollabJob['pay'] })));
    db.seed('collab_jobs/j_due_1', collabJobToDoc(job('j_due_1', { payStatus: 'due', pay: { dueAt: new Date(NOW.getTime() - 8 * 24 * H) } as CollabJob['pay'] })));
    db.seed('collab_jobs/j_due_2', collabJobToDoc(job('j_due_2', {
      payStatus: 'due',
      pay: { dueAt: new Date(NOW.getTime() - 8 * 24 * H), overdueFlaggedAt: past } as CollabJob['pay'],
    })));
    db.seed('collab_jobs/j_dis_1', collabJobToDoc(job('j_dis_1', { payStatus: 'disputed' })));
    db.seed('collab_jobs/j_dis_2', collabJobToDoc(job('j_dis_2', { payStatus: 'disputed', pay: { disputeFlaggedAt: past } as CollabJob['pay'] })));

    assert.deepEqual((await w.store.dueOffers(NOW, 10)).map((j) => j.bookingId), ['j_off_1']);
    assert.deepEqual((await w.store.payPending(NOW, 10)).map((j) => j.bookingId), ['j_pay_1', 'j_pay_2']);
    assert.deepEqual((await w.store.overduePay(new Date(NOW.getTime() - 7 * 24 * H), 10)).map((j) => j.bookingId), ['j_due_1']);
    assert.deepEqual((await w.store.unflaggedDisputes(10)).map((j) => j.bookingId), ['j_dis_1']);
    // open jobs of the pair: accepted with closedAt null (j_pay_*, j_due_*, j_dis_*) and pending ones; disputed counts too
    assert.equal(await w.store.openJobCount(STUDIO, DUNG), 9);
    assert.equal(await w.store.openJobCount(STUDIO, AN), 0);

    db.seed(`studio_collaborations/${STUDIO}_${AN}`, collaborationToDoc(collab({ id: `${STUDIO}_${AN}`, collaboratorId: AN, status: 'invited', expiresAt: past })));
    db.seed(`studio_collaborations/${STUDIO}_${DUNG}`, collaborationToDoc(collab({ status: 'invited', expiresAt: later })));
    assert.deepEqual((await w.store.dueInvites(NOW, 10)).map((c) => c.collaboratorId), [AN]);
  });

  it('due posts and applications, and the applied list of a post, oldest first', async () => {
    const { postId } = await createRecruitPost(w.deps, STUDIO, POST_INPUT);
    await applyToRecruitPost(w.deps, AN, { postId, message: '', samplePostIds: [], acceptTerms: true });
    w.advanceHours(1);
    await applyToRecruitPost(w.deps, DUNG, { postId, message: '', samplePostIds: [], acceptTerms: true });
    assert.deepEqual((await w.store.appliedOf(postId, 10)).map((a) => a.applicantId), [AN, DUNG]);
    assert.deepEqual(await w.store.duePosts(w.now, 10), []);
    const in8Days = new Date(w.now.getTime() + 8 * 24 * H);
    assert.deepEqual((await w.store.dueApplications(in8Days, 10)).map((a) => a.applicantId), [AN, DUNG]);
    assert.deepEqual((await w.store.duePosts(new Date(w.now.getTime() + 31 * 24 * H), 10)).map((p) => p.id), [postId]);
  });

  it('matchingProviders asks recruitMatchKeys with array-contains-any and caps the result', async () => {
    db.seed(`photographers/${AN}`, { ...db.data(`photographers/${AN}`), recruitMatchKeys: ['a=hcm-q1|s=wedding'] });
    db.seed(`photographers/${DUNG}`, { ...db.data(`photographers/${DUNG}`), recruitMatchKeys: ['a=hue|s=portrait'] });
    db.seed(`photographers/${BINH}`, { ...db.data(`photographers/${BINH}`), recruitMatchKeys: ['a=hcm-q3|s=wedding'] });
    const found = await w.store.matchingProviders(['a=hcm-q1|s=wedding', 'a=hcm-q3|s=wedding'], 10);
    assert.deepEqual(found.sort(), [AN, BINH].sort());
    assert.equal((await w.store.matchingProviders(['a=hcm-q1|s=wedding', 'a=hcm-q3|s=wedding'], 1)).length, 1);
    assert.deepEqual(await w.store.matchingProviders([], 10), []);
  });
});

describe('S27 readers', () => {
  let db: MemoryFirestore;
  let w: RecruitTestWorld;

  beforeEach(() => {
    db = new MemoryFirestore();
    seedRecruitPeople(db);
    w = recruitWorld(db);
  });

  it('people reads role, provider type, order gate, business verification, name and avatar; no photographer doc → null', async () => {
    assert.deepEqual(await w.deps.people.provider(STUDIO), {
      uid: STUDIO,
      role: 'photographer',
      providerType: 'studio',
      acceptsOrders: true,
      businessVerified: true,
      name: 'Cúc Studio',
      avatarUrl: `https://img.test/${STUDIO}.jpg`,
    });
    assert.equal((await w.deps.people.provider(BINH))?.acceptsOrders, false);
    assert.equal(await w.deps.people.provider(CUSTOMER), null);
    db.seed(`photographers/${AN}`, { ...db.data(`photographers/${AN}`), deletionPending: true });
    assert.equal((await w.deps.people.provider(AN))?.acceptsOrders, false);
  });

  it('owned posts: every id must be a post of the uid; an empty list is true', async () => {
    db.seed('posts/p1', { authorId: AN });
    db.seed('posts/p2', { authorId: DUNG });
    assert.equal(await w.deps.posts.ownedBy(AN, []), true);
    assert.equal(await w.deps.posts.ownedBy(AN, ['p1']), true);
    assert.equal(await w.deps.posts.ownedBy(AN, ['p1', 'p2']), false);
    assert.equal(await w.deps.posts.ownedBy(AN, ['missing']), false);
  });

  it('shoot milestone reads the booking payments through shootMilestoneState', async () => {
    const payments = new Map<string, unknown[]>([
      ['b_rel', [{ milestones: [{ kind: 'shoot', status: 'released' }] }]],
      ['b_ref', [{ milestones: [{ kind: 'shoot', status: 'refunded' }] }]],
    ]);
    const m = new FirestoreShootMilestones({ getPaymentsForBooking: async (id) => (payments.get(id) ?? []) as never });
    assert.equal(await m.shootMilestone('b_rel'), 'released');
    assert.equal(await m.shootMilestone('b_ref'), 'refunded');
    assert.equal(await m.shootMilestone('b_none'), 'waiting');
  });
});

describe('collaborator offers in the Firestore assignment transaction (Decision 26 capacity)', () => {
  const DAY = '2026-10-14';
  let db: MemoryFirestore;
  let deps: StudioBookingDeps;
  let now: Date;

  beforeEach(() => {
    db = new MemoryFirestore();
    seedRecruitPeople(db);
    now = NOW;
    const firestore = db.asFirestore();
    const pw = paymentWorld(NOW);
    deps = {
      ...pw.deps,
      clock: { now: () => now },
      store: new FirestoreBookingStore(firestore),
      providers: new FirestoreProviderOrderGate(firestore),
      blocks: new FirestoreBlockGate(firestore),
      roster: new FirestoreStudioRoster(firestore),
    };
    db.seed(`studio_collaborations/${STUDIO}_${DUNG}`, collaborationToDoc(collab()));
  });

  const load = () => db.data(`studio_day_load/${STUDIO}_${DAY}`);

  it('a pending collaborator offer leaves the booking in unassignedIds; acceptance moves it to assignedIds and books the collaborator\'s day', async () => {
    seedBooking(db, studioBooking());
    db.seed(`studio_day_load/${STUDIO}_${DAY}`, { studioId: STUDIO, day: DAY, unassignedIds: ['bk_studio_1'], assignedIds: [] });
    const offered: Booking = await assignBooking(deps, STUDIO, {
      bookingId: 'bk_studio_1', assigneeId: DUNG, assigneeKind: 'collaborator', agreedFee: 600_000,
    });
    assert.equal(offered.assigneeAccepted, false);
    const stored = db.data('bookings/bk_studio_1');
    assert.equal(stored?.assigneeKind, 'collaborator');
    assert.equal(stored?.assigneeAccepted, false);
    assert.equal('agreedFee' in (stored ?? {}), false);
    assert.equal(db.data(`collab_jobs/bk_studio_1_${DUNG}`)?.agreedFee, 600_000);
    assert.equal(db.data(`collab_jobs/bk_studio_1_${DUNG}`)?.offerStatus, 'pending');
    assert.deepEqual(load()?.unassignedIds, ['bk_studio_1']);
    assert.equal(db.data(`availability/${DUNG}/days/${DAY}`), undefined);

    now = new Date(NOW.getTime() + H);
    await respondCollabOffer(deps, DUNG, { bookingId: 'bk_studio_1', accept: true });
    assert.deepEqual(load()?.unassignedIds, []);
    assert.deepEqual(load()?.assignedIds, ['bk_studio_1']);
    assert.equal(db.data(`availability/${DUNG}/days/${DAY}`)?.bookingId, 'bk_studio_1');
    assert.equal(db.data('bookings/bk_studio_1')?.assigneeAccepted, true);
    assert.equal(db.data(`collab_jobs/bk_studio_1_${DUNG}`)?.offerStatus, 'accepted');
  });

  it('a recruit-blocked studio cannot offer: the counters are read in the assignment transaction', async () => {
    seedBooking(db, studioBooking());
    db.seed(`photographers/${STUDIO}/private/recruit`, { recruitBlockedUntil: Timestamp.fromDate(new Date(NOW.getTime() + 24 * H)) });
    await assert.rejects(
      assignBooking(deps, STUDIO, { bookingId: 'bk_studio_1', assigneeId: DUNG, assigneeKind: 'collaborator', agreedFee: 600_000 }),
      { code: 'recruit_blocked' },
    );
  });

  it('an active collaborator adds no capacity: a studio whose members are all busy refuses a new booking (day_taken)', async () => {
    // One member, busy that day; the active collaborator Dũng is free but is not capacity.
    db.seed(`photographers/m1`, { onboardingComplete: true, verified: true, providerType: 'individual', studioId: STUDIO });
    db.seed(`availability/m1/days/${DAY}`, { state: 'booked', bookingId: 'personal' });
    deps = {
      ...deps,
      providers: {
        acceptsOrders: async () => true,
        orderProfile: async (uid) => ({ acceptsOrders: true, providerType: uid === STUDIO ? 'studio' : 'individual', studioId: null }),
      },
    };
    await assert.rejects(
      createBookingDraft(deps, { customerId: 'c1', photographerId: STUDIO, serviceId: 'svc1', day: DAY, start: '09:00', place: { name: 'Nhà thờ Đức Bà' } }),
      { code: 'day_taken' },
    );
    // Control: once the member is free the same request is bookable.
    db.docs.delete(`availability/m1/days/${DAY}`);
    const draft = await createBookingDraft(deps, {
      customerId: 'c1', photographerId: STUDIO, serviceId: 'svc1', day: DAY, start: '09:00', place: { name: 'Nhà thờ Đức Bà' },
    });
    assert.equal(draft.isStudio, true);
  });
});

describe('S27 indexes', () => {
  it('every S27 adapter query has its composite index', () => {
    const indexes = JSON.parse(readFileSync(new URL('../../../firestore.indexes.json', import.meta.url), 'utf8')) as {
      indexes: { collectionGroup: string; fields: { fieldPath: string; order?: string; arrayConfig?: string }[] }[];
    };
    const has = (group: string, fields: string[]) =>
      indexes.indexes.some((i) => i.collectionGroup === group && i.fields.map((f) => f.fieldPath).join(',') === fields.join(','));
    for (const [group, fields] of [
      ['recruitPosts', ['status', 'expiresAt']],
      ['recruitApplications', ['status', 'expiresAt']],
      ['recruitApplications', ['postId', 'status', 'createdAt']],
      ['studio_collaborations', ['status', 'expiresAt']],
      ['collab_jobs', ['offerStatus', 'offerExpiresAt']],
      ['collab_jobs', ['offerStatus', 'payStatus', 'pay.checkAfter']],
      ['collab_jobs', ['payStatus', 'pay.overdueFlaggedAt', 'pay.dueAt']],
      // app queries of the Contract
      ['recruitPosts', ['status', 'createdAt']],
      ['recruitPosts', ['status', 'filterKeys', 'createdAt']],
      ['recruitPosts', ['studioId', 'status', 'createdAt']],
      ['recruitPosts', ['studioId', 'createdAt']],
      ['recruitApplications', ['studioId', 'postId', 'status', 'createdAt']],
      ['recruitApplications', ['applicantId', 'createdAt']],
      ['studio_collaborations', ['studioId', 'status', 'updatedAt']],
      ['studio_collaborations', ['collaboratorId', 'status', 'updatedAt']],
      ['collab_jobs', ['studioId', 'updatedAt']],
      ['collab_jobs', ['collaboratorId', 'updatedAt']],
      ['collab_jobs', ['studioId', 'collaboratorId', 'offerStatus']],
      ['collab_jobs', ['studioId', 'pay.dueAt']],
      ['collab_jobs', ['collaboratorId', 'customerId', 'acceptedAt']],
    ] as const) {
      assert.ok(has(group, [...fields]), `${group}(${fields.join(', ')})`);
    }
  });
});


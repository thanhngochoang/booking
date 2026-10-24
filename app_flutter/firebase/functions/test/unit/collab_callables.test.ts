import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { Timestamp } from 'firebase-admin/firestore';
import type { CollabChatDeps, CollabJob, Collaboration, StudioBookingDeps } from '@photobooking/domain';
import {
  handleCancelCollabInvite,
  handleConfirmCollabPay,
  handleEndCollaboration,
  handleInviteCollaborator,
  handleOpenCollabChat,
  handleReportCollabPaid,
  handleRespondCollabInvite,
  handleRespondCollabOffer,
  handleSetCollabDefaultFee,
} from '../../src/callables/collab.js';
import { handleAssignBooking } from '../../src/callables/studio.js';
import { FirestoreBookingStore } from '../../src/infra/booking_firestore.js';
import { FirestoreProviderOrderGate } from '../../src/infra/booking_readers.js';
import { FirestoreChatStore, FirestorePhotographerInquiryReader } from '../../src/infra/chat_firestore.js';
import { collabJobToDoc, collaborationToDoc } from '../../src/infra/recruit_mapping.js';
import { FirestoreBlockGate } from '../../src/infra/safety_firestore.js';
import { FirestoreStudioRoster } from '../../src/infra/studio_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';
import { paymentWorld } from './support/payment_world.js';
import { AN, BINH, DUNG, recruitWorld, seedRecruitPeople, type RecruitTestWorld } from './support/recruit_fixtures.js';
import { CUSTOMER, NOW, STUDIO, seedBooking, studioBooking } from './support/studio_fixtures.js';

const H = 3_600_000;
const asCaller = (uid: string, data: unknown = {}) => ({ auth: { uid }, data });
const refused = (code: string, detail?: string, field?: string) => (e: unknown) =>
  e instanceof HttpsError &&
  e.code === code &&
  (detail === undefined || (e.details as { code?: string })?.code === detail) &&
  (field === undefined || (e.details as { field?: string })?.field === field);

function collab(uid: string, over: Partial<Collaboration> = {}): Collaboration {
  return {
    id: `${STUDIO}_${uid}`,
    studioId: STUDIO,
    collaboratorId: uid,
    studio: { name: 'Cúc Studio', avatarUrl: null },
    collaborator: { name: uid, avatarUrl: null },
    status: 'active',
    initiatedBy: 'studio',
    applicationId: null,
    defaultFee: null,
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

function dueJob(over: Partial<CollabJob> = {}): CollabJob {
  return {
    id: `bk_1_${DUNG}`,
    bookingId: 'bk_1',
    studioId: STUDIO,
    collaboratorId: DUNG,
    customerId: CUSTOMER,
    studioName: 'Cúc Studio',
    collaboratorName: 'Dũng',
    shoot: { day: '2026-10-08', start: '09:00', end: '13:00', serviceName: 'Cưới', placeName: 'Q1' },
    shootEndsAt: new Date(NOW.getTime() - 48 * H),
    agreedFee: 600_000,
    offerStatus: 'accepted',
    offerAt: new Date(NOW.getTime() - 96 * H),
    offerExpiresAt: new Date(NOW.getTime() - 90 * H),
    acceptedAt: new Date(NOW.getTime() - 95 * H),
    declinedAt: null,
    closedAt: null,
    payStatus: 'due',
    pay: {
      amount: 600_000, dueAt: new Date(NOW.getTime() - 24 * H), paidOn: null, method: null, reportedAt: null,
      receivedAt: null, disputedAt: null, overdueFlaggedAt: null, disputeFlaggedAt: null, checkAfter: null,
    },
    createdAt: new Date(NOW.getTime() - 96 * H),
    updatedAt: new Date(NOW.getTime() - 24 * H),
    ...over,
  };
}

describe('collab callables (S27.06–S27.07)', () => {
  let db: MemoryFirestore;
  let w: RecruitTestWorld;
  let chats: FirestoreChatStore;
  let chatDeps: CollabChatDeps;
  let bookingDeps: StudioBookingDeps;

  beforeEach(() => {
    db = new MemoryFirestore();
    seedRecruitPeople(db);
    w = recruitWorld(db);
    const firestore = db.asFirestore();
    chats = new FirestoreChatStore(firestore);
    chatDeps = {
      chats,
      photographers: new FirestorePhotographerInquiryReader(firestore),
      blocks: new FirestoreBlockGate(firestore),
      clock: w.deps.clock,
      ids: w.deps.ids,
      recruit: w.store,
    };
    bookingDeps = {
      ...paymentWorld(NOW).deps,
      clock: w.deps.clock,
      store: new FirestoreBookingStore(firestore),
      providers: new FirestoreProviderOrderGate(firestore),
      blocks: new FirestoreBlockGate(firestore),
      roster: new FirestoreStudioRoster(firestore),
      notify: w.notify,
    };
  });

  it('unauthenticated is refused by all 9 collab callables', async () => {
    const noAuth = { auth: undefined, data: {} };
    for (const call of [
      () => handleInviteCollaborator(noAuth, w.deps),
      () => handleCancelCollabInvite(noAuth, w.deps),
      () => handleRespondCollabInvite(noAuth, w.deps, chats),
      () => handleEndCollaboration(noAuth, w.deps, chats),
      () => handleSetCollabDefaultFee(noAuth, w.deps),
      () => handleRespondCollabOffer(noAuth, bookingDeps),
      () => handleReportCollabPaid(noAuth, w.deps),
      () => handleConfirmCollabPay(noAuth, w.deps),
      () => handleOpenCollabChat(noAuth, chatDeps),
    ]) {
      await assert.rejects(call(), refused('unauthenticated', 'permission_denied'));
    }
    assert.equal(db.log.length, 0);
  });

  it('inviteCollaborator invites as the studio; an unverified photographer is not_accepting_orders', async () => {
    assert.deepEqual(await handleInviteCollaborator(asCaller(STUDIO, { collaboratorId: DUNG, defaultFee: 600_000 }), w.deps), {});
    const c = db.data(`studio_collaborations/${STUDIO}_${DUNG}`);
    assert.equal(c?.status, 'invited');
    assert.equal(c?.defaultFee, 600_000);
    await assert.rejects(
      handleInviteCollaborator(asCaller(STUDIO, { collaboratorId: BINH }), w.deps),
      refused('failed-precondition', 'not_accepting_orders'),
    );
  });

  it('cancelCollabInvite cancels the caller\'s invite; none is not_found', async () => {
    await handleInviteCollaborator(asCaller(STUDIO, { collaboratorId: DUNG }), w.deps);
    assert.deepEqual(await handleCancelCollabInvite(asCaller(STUDIO, { collaboratorId: DUNG }), w.deps), {});
    assert.equal(db.data(`studio_collaborations/${STUDIO}_${DUNG}`)?.status, 'cancelled');
    await assert.rejects(handleCancelCollabInvite(asCaller(STUDIO, { collaboratorId: AN }), w.deps), refused('not-found', 'not_found'));
  });

  it('respondCollabInvite answers as the invited photographer, needs the terms, and reopens the collab chat', async () => {
    await handleInviteCollaborator(asCaller(STUDIO, { collaboratorId: DUNG }), w.deps);
    db.seed(`chats/collab_${STUDIO}_${DUNG}`, { kind: 'collab', customerId: STUDIO, photographerId: DUNG, readOnlyAt: Timestamp.fromDate(NOW) });
    await assert.rejects(
      handleRespondCollabInvite(asCaller(DUNG, { studioId: STUDIO, accept: true }), w.deps, chats),
      refused('invalid-argument', 'invalid_argument', 'acceptTerms'),
    );
    assert.deepEqual(
      await handleRespondCollabInvite(asCaller(DUNG, { studioId: STUDIO, accept: true, acceptTerms: true }), w.deps, chats),
      { status: 'active' },
    );
    assert.equal(db.data(`studio_collaborations/${STUDIO}_${DUNG}`)?.status, 'active');
    assert.equal(db.data(`chats/collab_${STUDIO}_${DUNG}`)?.readOnlyAt, null);
  });

  it('endCollaboration ends as either side and makes the chat read-only after the commit; none is not_found', async () => {
    db.seed(`studio_collaborations/${STUDIO}_${DUNG}`, collaborationToDoc(collab(DUNG)));
    db.seed(`chats/collab_${STUDIO}_${DUNG}`, { kind: 'collab', customerId: STUDIO, photographerId: DUNG, readOnlyAt: null });
    assert.deepEqual(await handleEndCollaboration(asCaller(DUNG, { studioId: STUDIO }), w.deps, chats), {});
    assert.equal(db.data(`studio_collaborations/${STUDIO}_${DUNG}`)?.endedBy, 'collaborator');
    assert.equal((db.data(`chats/collab_${STUDIO}_${DUNG}`)?.readOnlyAt as Timestamp).toMillis(), NOW.getTime());
    await assert.rejects(handleEndCollaboration(asCaller(STUDIO, { collaboratorId: AN }), w.deps, chats), refused('not-found', 'not_found'));
  });

  it('setCollabDefaultFee sets the fee as the studio; a fee off the 1.000 step is invalid_argument', async () => {
    db.seed(`studio_collaborations/${STUDIO}_${DUNG}`, collaborationToDoc(collab(DUNG)));
    assert.deepEqual(await handleSetCollabDefaultFee(asCaller(STUDIO, { collaboratorId: DUNG, defaultFee: 700_000 }), w.deps), {});
    assert.equal(db.data(`studio_collaborations/${STUDIO}_${DUNG}`)?.defaultFee, 700_000);
    await assert.rejects(
      handleSetCollabDefaultFee(asCaller(STUDIO, { collaboratorId: DUNG, defaultFee: 700_500 }), w.deps),
      refused('invalid-argument', 'invalid_argument'),
    );
  });

  it('assignBooking passes assigneeKind and agreedFee through; respondCollabOffer answers as the named collaborator', async () => {
    db.seed(`studio_collaborations/${STUDIO}_${DUNG}`, collaborationToDoc(collab(DUNG)));
    seedBooking(db, studioBooking());
    const offered = await handleAssignBooking(
      asCaller(STUDIO, { bookingId: 'bk_studio_1', assigneeId: DUNG, assigneeKind: 'collaborator', agreedFee: 650_000 }),
      bookingDeps,
    );
    assert.equal(offered.assigneeKind, 'collaborator');
    assert.equal(offered.assigneeAccepted, false);
    assert.equal(db.data(`collab_jobs/bk_studio_1_${DUNG}`)?.agreedFee, 650_000);

    await assert.rejects(
      handleRespondCollabOffer(asCaller(AN, { bookingId: 'bk_studio_1', accept: true }), bookingDeps),
      refused('permission-denied', 'permission_denied'),
    );
    assert.deepEqual(
      await handleRespondCollabOffer(asCaller(DUNG, { bookingId: 'bk_studio_1', accept: true }), bookingDeps),
      { offerStatus: 'accepted' },
    );
    assert.equal(db.data('bookings/bk_studio_1')?.assigneeAccepted, true);
  });

  it('reportCollabPaid is the studio\'s (the collaborator is permission_denied); confirmCollabPay the collaborator\'s', async () => {
    db.seed(`collab_jobs/bk_1_${DUNG}`, collabJobToDoc(dueJob()));
    await assert.rejects(
      handleReportCollabPaid(asCaller(DUNG, { bookingId: 'bk_1', collaboratorId: DUNG, paidOn: '2026-10-09', method: 'bank' }), w.deps),
      refused('permission-denied', 'permission_denied'),
    );
    await assert.rejects(handleConfirmCollabPay(asCaller(DUNG, { bookingId: 'bk_1', received: true }), w.deps), refused('aborted', 'conflict'));
    assert.deepEqual(
      await handleReportCollabPaid(asCaller(STUDIO, { bookingId: 'bk_1', collaboratorId: DUNG, paidOn: '2026-10-09', method: 'bank' }), w.deps),
      {},
    );
    assert.equal(db.data(`collab_jobs/bk_1_${DUNG}`)?.payStatus, 'paid_reported');
    assert.deepEqual(await handleConfirmCollabPay(asCaller(DUNG, { bookingId: 'bk_1', received: true }), w.deps), { payStatus: 'received' });
    assert.equal(db.data(`collab_jobs/bk_1_${DUNG}`)?.payStatus, 'received');
  });

  it('openCollabChat opens the pair\'s chat for either side; without a collaboration it is not_eligible', async () => {
    await assert.rejects(handleOpenCollabChat(asCaller(STUDIO, { collaboratorId: DUNG }), chatDeps), refused('failed-precondition', 'not_eligible'));
    db.seed(`studio_collaborations/${STUDIO}_${DUNG}`, collaborationToDoc(collab(DUNG)));
    assert.deepEqual(await handleOpenCollabChat(asCaller(DUNG, { studioId: STUDIO }), chatDeps), { chatId: `collab_${STUDIO}_${DUNG}` });
    const chat = db.data(`chats/collab_${STUDIO}_${DUNG}`);
    assert.equal(chat?.kind, 'collab');
    assert.deepEqual(chat?.members, [STUDIO, DUNG]);
  });
});

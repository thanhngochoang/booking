import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import type { Booking, CollabJob } from '@photobooking/domain';
import { bookingToFirestore } from '../../src/infra/booking_firestore.js';
import { FirestoreCollabBookingSync } from '../../src/infra/recruit_firestore.js';
import { collabJobToDoc } from '../../src/infra/recruit_mapping.js';
import { flagPoaching, syncCollabJob } from '../../src/triggers/booking_write.js';
import { MemoryFirestore } from './support/memory_firestore.js';
import { CUSTOMER, NOW, STUDIO, studioBooking } from './support/studio_fixtures.js';

const H = 3_600_000;
const DUNG = 'dung_artist';

function job(over: Partial<CollabJob> = {}): CollabJob {
  return {
    id: `bk_studio_1_${DUNG}`,
    bookingId: 'bk_studio_1',
    studioId: STUDIO,
    collaboratorId: DUNG,
    customerId: CUSTOMER,
    studioName: 'Cúc Studio',
    collaboratorName: 'Dũng',
    shoot: { day: '2026-10-14', start: '09:00', end: '13:00', serviceName: 'Cưới 4 giờ', placeName: 'Nhà thờ Đức Bà' },
    shootEndsAt: new Date('2026-10-14T06:00:00.000Z'),
    agreedFee: 600_000,
    offerStatus: 'pending',
    offerAt: NOW,
    offerExpiresAt: new Date(NOW.getTime() + 6 * H),
    acceptedAt: null,
    declinedAt: null,
    closedAt: null,
    payStatus: 'none',
    pay: {
      amount: 600_000, dueAt: null, paidOn: null, method: null, reportedAt: null, receivedAt: null,
      disputedAt: null, overdueFlaggedAt: null, disputeFlaggedAt: null, checkAfter: new Date('2026-10-14T06:00:00.000Z'),
    },
    createdAt: NOW,
    updatedAt: NOW,
    ...over,
  };
}

/** A personal (non-studio) booking of Dũng with the same customer. */
function personal(id: string, createdAt: Date): Booking {
  return {
    ...studioBooking({ id, photographerId: DUNG, createdAt: createdAt.toISOString(), updatedAt: createdAt.toISOString() }),
    isStudio: undefined,
    assigneeId: undefined,
    assigneeKind: undefined,
    assignStatus: undefined,
    assignDeadline: undefined,
    assignOverdue: undefined,
    assignedAt: undefined,
    assignments: undefined,
    assignRemindersSent: undefined,
    changeRequest: undefined,
    studioFault: undefined,
    assignmentReturned: undefined,
    status: 'draft',
  };
}

describe('onBookingWrite: collab jobs follow the booking (S27)', () => {
  let db: MemoryFirestore;
  let sync: FirestoreCollabBookingSync;

  beforeEach(() => {
    db = new MemoryFirestore();
    sync = new FirestoreCollabBookingSync(db.asFirestore());
  });

  it('a cancelled studio booking cancels its pending collab job', async () => {
    db.seed(`collab_jobs/${job().id}`, collabJobToDoc(job()));
    db.seed(`collab_jobs/bk_studio_1_old`, collabJobToDoc(job({ id: 'bk_studio_1_old', collaboratorId: 'old', offerStatus: 'declined' })));
    const before = studioBooking();
    const at = '2026-10-11T03:00:00.000Z';
    const after = studioBooking({ status: 'cancelled', cancel: { by: 'customer', at, refundPercent: 100 }, updatedAt: at });
    assert.equal(await syncCollabJob(before, after, sync), 1);
    const stored = db.data(`collab_jobs/${job().id}`);
    assert.equal(stored?.offerStatus, 'cancelled');
    assert.equal((stored?.closedAt as Timestamp).toDate().toISOString(), at);
    assert.equal(db.data('collab_jobs/bk_studio_1_old')?.offerStatus, 'declined');
    // the re-fired event changes nothing
    assert.equal(await syncCollabJob(before, after, sync), 0);
  });

  it('a completed booking sets closedAt and keeps the accepted job and its pay record going', async () => {
    db.seed(`collab_jobs/${job().id}`, collabJobToDoc(job({ offerStatus: 'accepted', acceptedAt: NOW })));
    const completedAt = '2026-10-16T03:00:00.000Z';
    const after = studioBooking({ status: 'completed', completedAt, updatedAt: completedAt });
    assert.equal(await syncCollabJob(studioBooking({ status: 'delivered' }), after, sync), 1);
    const stored = db.data(`collab_jobs/${job().id}`);
    assert.equal(stored?.offerStatus, 'accepted');
    assert.equal((stored?.closedAt as Timestamp).toDate().toISOString(), completedAt);
    assert.equal(stored?.payStatus, 'none');
  });

  it('a write that does not change the status, or a non-studio booking, reads no job', async () => {
    db.seed(`collab_jobs/${job().id}`, collabJobToDoc(job()));
    const reads = db.reads;
    assert.equal(await syncCollabJob(studioBooking(), studioBooking({ version: 2 }), sync), 0);
    assert.equal(await syncCollabJob(null, personal('p_1', NOW), sync), 0);
    assert.equal(db.reads, reads);
  });

  it('a second personal booking with a customer the collaborator served for a studio writes one staff flag; a third writes nothing new', async () => {
    db.seed(`collab_jobs/${job().id}`, collabJobToDoc(job({ offerStatus: 'accepted', acceptedAt: new Date(NOW.getTime() - 30 * 24 * H) })));
    const now = NOW;
    const first = personal('p_1', new Date(NOW.getTime() - 10 * 24 * H));
    db.seed('bookings/p_1', bookingToFirestore(first));
    assert.equal(await flagPoaching(null, first, sync, now), 'none');
    assert.equal(db.data(`staff_flags/poach_${DUNG}_${CUSTOMER}`), undefined);

    const second = personal('p_2', NOW);
    db.seed('bookings/p_2', bookingToFirestore(second));
    assert.equal(await flagPoaching(null, second, sync, now), 'flagged');
    const flag = db.data(`staff_flags/poach_${DUNG}_${CUSTOMER}`);
    assert.equal(flag?.kind, 'collab_poaching');
    assert.equal(flag?.photographerId, DUNG);
    assert.equal(flag?.customerId, CUSTOMER);
    assert.equal(flag?.studioId, STUDIO);
    assert.deepEqual(flag?.jobIds, [job().id]);
    assert.ok(flag?.createdAt instanceof Timestamp);

    const writes = db.log.length;
    const third = personal('p_3', new Date(NOW.getTime() + H));
    db.seed('bookings/p_3', bookingToFirestore(third));
    assert.equal(await flagPoaching(null, third, sync, new Date(NOW.getTime() + H)), 'exists');
    assert.equal(db.log.length, writes);
  });

  it('flagPoaching looks only at a new non-studio booking', async () => {
    const reads = db.reads;
    assert.equal(await flagPoaching(personal('p_1', NOW), { ...personal('p_1', NOW), status: 'requested' }, sync, NOW), 'none');
    assert.equal(await flagPoaching(null, studioBooking(), sync, NOW), 'none');
    assert.equal(db.reads, reads);
  });
});

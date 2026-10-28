import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { FieldValue, Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  FakePaymentGateway,
  dispatchDisputeRefund,
  openDispute,
  resolveDispute,
  type Booking,
  type Dispute,
  type DisputeDeps,
  type EventRecord,
  type Payment,
  type Refund,
  type RegistrationDoc,
} from '@photobooking/domain';
import { bookingToFirestore, paymentToFirestore, refundToFirestore } from '../../src/infra/booking_firestore.js';
import {
  FirestoreDisputeStore,
  disputeFromFirestore,
  disputeToFirestore,
  ticketDisputeView,
} from '../../src/infra/dispute_firestore.js';
import { eventToFirestore, registrationToFirestore } from '../../src/infra/event_firestore.js';
import { FirestoreSupportStore } from '../../src/infra/support_firestore.js';
import { TEST_CIPHER } from '../../../../../packages/domain/test/support/test_cipher.js';

// ---- A small in-memory Firestore: documents by path, one transaction that records its writes. ----

type Filter = [string, string, unknown];
interface FakeQuery { readonly coll: string; readonly filters: Filter[]; readonly order: string[]; where(f: string, op: string, v: unknown): FakeQuery; orderBy(f: string, dir?: string): FakeQuery; limit(n: number): FakeQuery; get(): Promise<FakeQuerySnap> }
interface FakeQuerySnap { readonly empty: boolean; readonly docs: { id: string; data(): DocumentData }[] }
interface Write { readonly op: 'set' | 'update'; readonly path: string; readonly data: DocumentData; readonly merge?: true }

function fakeFirestore(docs: Record<string, DocumentData>) {
  const writes: Write[] = [];
  const queries: { coll: string; filters: Filter[]; order: string[] }[] = [];
  const snapOf = (path: string) => {
    const data = docs[path];
    return { id: path.split('/').pop() ?? '', exists: data !== undefined, data: () => data };
  };
  const run = (q: { coll: string; filters: Filter[] }): FakeQuerySnap => {
    const found = Object.entries(docs)
      .filter(([path]) => path.startsWith(`${q.coll}/`) && !path.slice(q.coll.length + 1).includes('/'))
      .filter(([, d]) => q.filters.every(([f, op, v]) => (op === '==' ? d[f] === v : true)))
      .map(([path, d]) => ({ id: path.split('/').pop() ?? '', data: () => d }));
    return { empty: found.length === 0, docs: found };
  };
  const query = (coll: string, filters: Filter[], order: string[]): FakeQuery => ({
    coll,
    filters,
    order,
    where: (f, op, v) => query(coll, [...filters, [f, op, v]], order),
    orderBy: (f, dir = 'asc') => query(coll, filters, [...order, `${f} ${dir}`]),
    limit: () => query(coll, filters, order),
    get: async () => {
      queries.push({ coll, filters, order });
      return run({ coll, filters });
    },
  });
  const collection = (path: string): unknown => ({
    ...query(path, [], []),
    doc: (id: string) => docRef(`${path}/${id}`),
  });
  const docRef = (path: string): unknown => ({ path, id: path.split('/').pop(), collection: (c: string) => collection(`${path}/${c}`) });
  // One transaction: like the Admin SDK, a read after the first write throws; the writes reach the
  // documents only when the transaction function resolves (commit).
  const newTx = () => {
    let wrote = false;
    const pending: Write[] = [];
    const write = (w: Write) => {
      wrote = true;
      pending.push(w);
      writes.push(w);
    };
    const tx = {
      get: async (x: { path?: string; coll?: string; filters?: Filter[] }) => {
        if (wrote) throw new Error(`read after write: ${x.path ?? x.coll ?? '?'}`);
        if (x.filters !== undefined && x.coll !== undefined) {
          queries.push({ coll: x.coll, filters: x.filters, order: [] });
          return run({ coll: x.coll, filters: x.filters });
        }
        return snapOf(String(x.path));
      },
      set: (ref: { path: string }, data: DocumentData, opts?: { merge?: boolean }) =>
        write({ op: 'set', path: ref.path, data, ...(opts?.merge === true ? { merge: true as const } : {}) }),
      update: (ref: { path: string }, data: DocumentData) => write({ op: 'update', path: ref.path, data }),
    };
    const commit = () => {
      for (const w of pending) {
        const base: DocumentData = w.op === 'set' && w.merge !== true ? {} : { ...(docs[w.path] ?? {}) };
        for (const [k, v] of Object.entries(w.data)) {
          if (!(v instanceof FieldValue)) {
            base[k] = v;
            continue;
          }
          // FieldValue.increment(n) is the only sentinel these adapters write. Its amount sits in the SDK's
          // private `operand` field (firebase-admin NumericIncrementTransform): if an SDK upgrade renames
          // it, fail here loudly instead of silently storing the sentinel and passing for the wrong reason.
          const operand = (v as unknown as { operand?: unknown }).operand;
          assert.equal(
            typeof operand,
            'number',
            `fake Firestore: ${w.path}.${k} is a FieldValue without a numeric 'operand' (not an increment, or the SDK changed); teach the fake to apply it`,
          );
          base[k] = (typeof base[k] === 'number' ? base[k] : 0) + (operand as number);
        }
        docs[w.path] = base;
      }
    };
    return { tx, commit };
  };
  const firestore = {
    collection,
    runTransaction: async <T>(fn: (t: ReturnType<typeof newTx>['tx']) => Promise<T>) => {
      const { tx, commit } = newTx();
      const result = await fn(tx);
      commit();
      return result;
    },
  } as unknown as Firestore;
  return { firestore, writes, queries };
}

// ---- Fixtures ----

const NOW = new Date('2026-10-20T10:00:00.000Z');

const dispute = (over: Partial<Dispute> = {}): Dispute => ({
  id: 'dsp_1',
  subjectType: 'booking',
  subjectId: 'b1',
  eventId: null,
  paymentId: 'pay_paid',
  customerId: 'c1',
  providerId: 'p1',
  parties: ['c1', 'p1'],
  openedBy: 'customer',
  reason: 'photos_missing',
  description: 'Thiếu 20 ảnh so với gói đã đặt.',
  evidencePaths: ['disputeEvidence/c1/dsp_1/01J0.jpg'],
  snapshot: { title: 'Minh Trí · Chân dung', subtitle: 'T2 19/10 · 15:30–17:30', providerName: 'Minh Trí', thumbUrl: null },
  amountHeld: 1_000_000,
  status: 'open',
  outcome: null,
  threadId: 'dispute_dsp_1',
  createdAt: '2026-10-20T08:00:00.000Z',
  updatedAt: '2026-10-20T08:00:00.000Z',
  resolvedAt: null,
  version: 1,
  ...over,
});

const payment = (id: string, over: Partial<Payment> = {}): Payment => ({
  id, subjectType: 'booking', subjectId: 'b1', payerId: 'c1', payeeId: 'p1', provider: 'fake', amount: 1_000_000,
  status: 'paid', escrowStatus: 'held', idempotencyKey: `k_${id}`, createdAt: '2026-10-10T00:00:00.000Z', updatedAt: '2026-10-10T00:00:00.000Z',
  ...over,
});

const booking: Booking = {
  id: 'b1', customerId: 'c1', photographerId: 'p1', serviceId: 's1',
  serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
  day: '2026-10-19', start: '15:30', end: '17:30', place: { name: 'Hồ Gươm' },
  status: 'completed', deposit: 1_000_000, remaining: 0, escrowStatus: 'held',
  completedAt: '2026-10-20T08:00:00.000Z', version: 4,
  createdAt: '2026-10-10T00:00:00.000Z', updatedAt: '2026-10-20T08:00:00.000Z',
};

const event = (over: Partial<EventRecord> = {}): EventRecord => ({
  id: 'e1',
  host: { type: 'photographer', id: 'h1', name: 'Hà Host', avatarUrl: null, verified: true },
  createdBy: 'h1', createdByRole: 'photographer', hostConsent: 'not_required', hostConsentExpiresAt: null,
  title: 'Chụp phố đêm', description: 'x', type: 'photo_walk', coverUrl: 'https://cdn.test/c.jpg', coverPath: null,
  startAt: new Date('2026-10-19T23:00:00.000Z'), endAt: new Date('2026-10-20T02:00:00.000Z'), dayKey: '2026-10-20',
  location: null, capacity: 10, price: 300_000, registrationDeadline: null, faq: [], hashtag: 'x', hashtagKey: 'x',
  hashtagLocked: false, spotId: null, spotDecided: true, status: 'completed', registeredCount: 1, heldCount: 0, chatId: null,
  postCount: 0, version: 1, publishedAt: null, completedAt: null, cancelledAt: null, soonNoticeAt: null, soonNotifiedRegIds: [],
  createdAt: new Date('2026-10-01T00:00:00.000Z'), updatedAt: new Date('2026-10-01T00:00:00.000Z'),
  ...over,
});

const registration = (over: Partial<RegistrationDoc> = {}): RegistrationDoc => ({
  id: 'r1', eventId: 'e1', userId: 'c1', userName: 'An', userAvatarUrl: null, quantity: 1, amount: 300_000,
  status: 'paid', holdExpiresAt: null, ticketCode: 'VE-ABCD-0001', paymentId: 'pay_r1', contactEligible: true,
  checkedInAt: null, cancelledAt: null, refundPercent: null,
  event: { title: 'Chụp phố đêm', type: 'photo_walk', startAt: new Date('2026-10-19T23:00:00.000Z'), endAt: new Date('2026-10-20T02:00:00.000Z'), locationName: 'Hồ Gươm', lat: 0, lng: 0, coverUrl: null },
  version: 2, createdAt: new Date('2026-10-01T00:00:00.000Z'), updatedAt: new Date('2026-10-01T00:00:00.000Z'),
  ...over,
});

const refund = (over: Partial<Refund> = {}): Refund => ({
  id: 'rf1', paymentId: 'pay_paid', subjectType: 'booking', amount: 400_000, percent: 40, status: 'pending', manual: false,
  fromEscrow: true, method: 'gateway', attempts: 0, reason: 'dispute:dsp_1',
  createdAt: NOW.toISOString(), updatedAt: NOW.toISOString(),
  ...over,
});

const bookingSubject = { ...{ type: 'booking' as const, id: 'b1', eventId: null }, customerId: 'c1', providerId: 'p1', state: 'completed',
  windowStart: null, shotAt: null, checkUntil: null, amount: 1_000_000, paymentId: null, disputeId: null,
  snapshot: { title: '', subtitle: '', providerName: null, thumbUrl: null } };

describe('dispute Firestore adapter', () => {
  it('dispute document round-trips (Timestamps ↔ ISO, outcome null and set)', () => {
    const open = dispute();
    const doc = disputeToFirestore(open);
    assert.ok(doc.createdAt instanceof Timestamp);
    assert.ok(doc.updatedAt instanceof Timestamp);
    assert.equal(doc.resolvedAt, null);
    assert.equal(doc.outcome, null);
    assert.deepEqual(doc.parties, ['c1', 'p1']);
    assert.deepEqual(disputeFromFirestore(doc), open);

    const resolved = dispute({
      status: 'resolved',
      resolvedAt: '2026-10-21T08:00:00.000Z',
      updatedAt: '2026-10-21T08:00:00.000Z',
      version: 2,
      outcome: {
        kind: 'split', refundPercent: 40, refundAmount: 400_000, releaseAmount: 600_000, note: 'Thiếu một phần ảnh.',
        decidedBy: 'staff1', decidedAt: '2026-10-21T08:00:00.000Z', refundId: 'rf1',
      },
    });
    const rdoc = disputeToFirestore(resolved);
    assert.ok(rdoc.resolvedAt instanceof Timestamp);
    assert.ok(rdoc.outcome.decidedAt instanceof Timestamp);
    assert.deepEqual(disputeFromFirestore(rdoc), resolved);
    const ticket = dispute({ subjectType: 'ticket', subjectId: 'r1', eventId: 'e1', providerId: 'platform', parties: ['c1'] });
    assert.deepEqual(disputeFromFirestore(disputeToFirestore(ticket)), ticket);
    assert.equal(disputeFromFirestore(undefined), null);
  });

  it('a ticket of an organizer-hosted event names the organizer as provider (S30)', () => {
    const ev = event({ host: { type: 'organizer', id: 'org1', name: 'Bãi đá sông Hồng', avatarUrl: null, verified: true } });
    const view = ticketDisputeView(registration(), ev);
    assert.equal(view.providerId, 'org1');
    assert.equal(view.snapshot.providerName, 'Bãi đá sông Hồng');
  });

  it('findSubjectPayment for a booking picks the held payment', async () => {
    const { firestore, queries } = fakeFirestore({
      'payments/pay_created': paymentToFirestore(payment('pay_created', { status: 'created' })),
      'payments/pay_expired': paymentToFirestore(payment('pay_expired', { status: 'expired', escrowStatus: 'refunded' })),
      'payments/pay_paid': paymentToFirestore(payment('pay_paid')),
      'payments/pay_other': paymentToFirestore(payment('pay_other', { subjectId: 'b2' })),
    });
    const found = await new FirestoreDisputeStore(firestore).runTransaction((tx) => tx.findSubjectPayment(bookingSubject));
    assert.equal(found?.id, 'pay_paid');
    assert.deepEqual(queries[0]?.filters, [['subjectType', '==', 'booking'], ['subjectId', '==', 'b1']]);

    // A ticket reads its registration's payment.
    const t = fakeFirestore({ 'payments/pay_r1': paymentToFirestore(payment('pay_r1', { subjectType: 'event_registration', subjectId: 'r1', eventId: 'e1' })) });
    const ticketPayment = await new FirestoreDisputeStore(t.firestore).runTransaction((tx) =>
      tx.findSubjectPayment({ ...bookingSubject, type: 'ticket', id: 'r1', eventId: 'e1', paymentId: 'pay_r1' }));
    assert.equal(ticketPayment?.id, 'pay_r1');
    const none = await new FirestoreDisputeStore(t.firestore).runTransaction((tx) =>
      tx.findSubjectPayment({ ...bookingSubject, type: 'ticket', id: 'r1', eventId: 'e1', paymentId: null }));
    assert.equal(none, null);
  });

  it('getSubject builds the booking view (provider name, window fields, snapshot) and the ticket view', async () => {
    const { firestore } = fakeFirestore({
      'bookings/b1': { ...bookingToFirestore({ ...booking, disputeId: 'dsp_0' }) },
      'users/p1': { displayName: 'Minh Trí', avatarUrl: 'https://cdn.test/p1.jpg' },
      'events/e1': eventToFirestore(event()),
      'events/e1/registrations/r1': registrationToFirestore(registration()),
      'events/e2': eventToFirestore(event({ id: 'e2', host: { type: 'platform', id: null, name: 'Ứng dụng', avatarUrl: null, verified: true } })),
      'events/e2/registrations/r2': registrationToFirestore(registration({ id: 'r2', eventId: 'e2', disputeId: 'dsp_9' })),
    });
    const store = new FirestoreDisputeStore(firestore);
    const view = await store.runTransaction((tx) => tx.getSubject('booking', 'b1', null));
    assert.deepEqual(view, {
      type: 'booking', id: 'b1', eventId: null, customerId: 'c1', providerId: 'p1', state: 'completed',
      windowStart: new Date('2026-10-20T08:00:00.000Z'), shotAt: null, checkUntil: null, shootDeniedAt: null, amount: 1_000_000,
      paymentId: null, disputeId: 'dsp_0',
      snapshot: { title: 'Minh Trí · Chân dung', subtitle: 'T2 19/10 · 15:30–17:30', providerName: 'Minh Trí', thumbUrl: 'https://cdn.test/p1.jpg' },
    });
    assert.equal(await store.runTransaction((tx) => tx.getSubject('booking', 'missing', null)), null);

    const ticket = await store.runTransaction((tx) => tx.getSubject('ticket', 'r1', 'e1'));
    assert.deepEqual(ticket, {
      type: 'ticket', id: 'r1', eventId: 'e1', customerId: 'c1', providerId: 'h1', state: 'paid',
      windowStart: new Date('2026-10-20T02:00:00.000Z'), shotAt: null, checkUntil: null, amount: 300_000,
      paymentId: 'pay_r1', disputeId: null,
      snapshot: { title: 'Chụp phố đêm', subtitle: 'T3 20/10 · 06:00–09:00', providerName: 'Hà Host', thumbUrl: 'https://cdn.test/c.jpg' },
    });
    const platform = await store.runTransaction((tx) => tx.getSubject('ticket', 'r2', 'e2'));
    assert.equal(platform?.providerId, 'platform');
    assert.equal(platform?.snapshot.providerName, null);
    assert.equal(platform?.disputeId, 'dsp_9');
  });

  it('linkSubject writes the booking mirror once; a refund in the same transaction adds to depositRefunded', async () => {
    const { firestore, writes } = fakeFirestore({});
    await new FirestoreDisputeStore(firestore).runTransaction(async (tx) => {
      tx.addRefund(refund());
      tx.linkSubject(bookingSubject, { disputeId: 'dsp_1', escrowStatus: 'released' });
    });
    const mirror = writes.filter((w) => w.path === 'bookings/b1');
    assert.equal(mirror.length, 1);
    assert.equal(mirror[0]?.op, 'update');
    const { depositRefunded, ...rest } = mirror[0]?.data ?? {};
    assert.deepEqual(rest, { disputeId: 'dsp_1', escrowStatus: 'released' });
    assert.ok((depositRefunded as FieldValue).isEqual(FieldValue.increment(400_000)));
    assert.ok(writes.some((w) => w.path === 'refunds/rf1' && w.op === 'set'));

    // Opening links without a refund: only the dispute id and the escrow mirror.
    const open = fakeFirestore({});
    await new FirestoreDisputeStore(open.firestore).runTransaction(async (tx) => {
      tx.linkSubject(bookingSubject, { disputeId: 'dsp_1', escrowStatus: 'disputed' });
    });
    assert.deepEqual(open.writes, [{ op: 'update', path: 'bookings/b1', data: { disputeId: 'dsp_1', escrowStatus: 'disputed' } }]);
  });

  it('linkSubject on a ticket writes disputeId, and the refund id and status of a refund in the same transaction', async () => {
    const ticket = { ...bookingSubject, type: 'ticket' as const, id: 'r1', eventId: 'e1', paymentId: 'pay_r1' };
    const { firestore, writes } = fakeFirestore({});
    await new FirestoreDisputeStore(firestore).runTransaction(async (tx) => {
      tx.linkSubject(ticket, { disputeId: 'dsp_1', escrowStatus: 'disputed' });
    });
    assert.deepEqual(writes, [{ op: 'update', path: 'events/e1/registrations/r1', data: { disputeId: 'dsp_1' } }]);

    const resolved = fakeFirestore({});
    await new FirestoreDisputeStore(resolved.firestore).runTransaction(async (tx) => {
      tx.addRefund(refund({ paymentId: 'pay_r1', subjectType: 'event_registration' }));
      tx.linkSubject(ticket, { disputeId: 'dsp_1', escrowStatus: 'partially_refunded' });
    });
    assert.deepEqual(resolved.writes.find((w) => w.path === 'events/e1/registrations/r1'), {
      op: 'update', path: 'events/e1/registrations/r1', data: { disputeId: 'dsp_1', refundId: 'rf1', refundStatus: 'pending' },
    });
  });

  it('a dispute refund that turns done stamps depositRefundedAt once; a ticket refund mirrors its status', async () => {
    const pending = refund();
    const { firestore, writes } = fakeFirestore({
      'refunds/rf1': refundToFirestore(pending),
      'payments/pay_paid': paymentToFirestore(payment('pay_paid')),
      'bookings/b1': bookingToFirestore(booking),
    });
    await new FirestoreDisputeStore(firestore).runTransaction(async (tx) => {
      const stored = await tx.getRefund('rf1');
      assert.equal(stored?.status, 'pending');
      tx.addRefund({ ...pending, status: 'done', updatedAt: '2026-10-20T10:05:00.000Z' });
    });
    const stamp = writes.find((w) => w.path === 'bookings/b1');
    assert.equal(stamp?.op, 'update');
    assert.equal((stamp?.data.depositRefundedAt as Timestamp).toDate().toISOString(), '2026-10-20T10:05:00.000Z');

    // Already stamped by an earlier refund: left alone.
    const again = fakeFirestore({
      'refunds/rf1': refundToFirestore(pending),
      'payments/pay_paid': paymentToFirestore(payment('pay_paid')),
      'bookings/b1': bookingToFirestore({ ...booking, depositRefundedAt: '2026-10-15T00:00:00.000Z' }),
    });
    await new FirestoreDisputeStore(again.firestore).runTransaction(async (tx) => {
      await tx.getRefund('rf1');
      tx.addRefund({ ...pending, status: 'done' });
    });
    assert.equal(again.writes.some((w) => w.path === 'bookings/b1'), false);

    const ticketRefund = refund({ paymentId: 'pay_r1', subjectType: 'event_registration' });
    const t = fakeFirestore({
      'refunds/rf1': refundToFirestore(ticketRefund),
      'payments/pay_r1': paymentToFirestore(payment('pay_r1', { subjectType: 'event_registration', subjectId: 'r1', eventId: 'e1' })),
      'events/e1/registrations/r1': registrationToFirestore(registration({ refundId: 'rf1', refundStatus: 'pending' })),
    });
    await new FirestoreDisputeStore(t.firestore).runTransaction(async (tx) => {
      await tx.getRefund('rf1');
      tx.addRefund({ ...ticketRefund, status: 'done' });
    });
    assert.deepEqual(t.writes.find((w) => w.path === 'events/e1/registrations/r1'), {
      op: 'update', path: 'events/e1/registrations/r1', data: { refundStatus: 'done' },
    });
  });

  it('a support transaction reads the dispute of a dispute thread (no more stub)', async () => {
    const { firestore } = fakeFirestore({ 'disputes/dsp_1': disputeToFirestore(dispute()) });
    const found = await new FirestoreSupportStore(firestore).runTransaction((tx) => tx.getDispute('dsp_1'));
    assert.deepEqual(found, dispute());
    assert.equal(await new FirestoreSupportStore(firestore).runTransaction((tx) => tx.getDispute('nope')), null);
  });

  it('setDispute, setPayment and the ledger write their documents; listByStatus is status + createdAt, oldest first', async () => {
    const { firestore, writes, queries } = fakeFirestore({ 'disputes/dsp_1': disputeToFirestore(dispute()) });
    const store = new FirestoreDisputeStore(firestore);
    await store.runTransaction(async (tx) => {
      tx.setDispute(dispute());
      tx.setPayment(payment('pay_paid'));
      tx.addLedgerEntry({ id: 'le1', type: 'escrow_released', paymentId: 'pay_paid', accountOwnerId: 'p1', amount: 600_000, at: NOW.toISOString() });
    });
    assert.deepEqual(writes.map((w) => `${w.op} ${w.path}`), ['set disputes/dsp_1', 'set payments/pay_paid', 'set ledger_entries/le1']);
    const open = await store.listByStatus('open', 20);
    assert.deepEqual(open.map((d) => d.id), ['dsp_1']);
    assert.deepEqual(queries.at(-1), { coll: 'disputes', filters: [['status', '==', 'open']], order: ['createdAt asc'] });
  });
});

// ---- The real use cases through FirestoreDisputeStore over the strict fake (every read before the first write). ----

describe('dispute use cases on the Firestore adapter (read before write)', () => {
  function world() {
    const docs: Record<string, DocumentData> = {
      'bookings/b1': bookingToFirestore(booking),
      'users/p1': { displayName: 'Minh Trí', avatarUrl: null },
      'payments/pay_paid': paymentToFirestore(payment('pay_paid', { paidAt: '2026-10-10T00:00:00.000Z' })),
    };
    const fake = fakeFirestore(docs);
    let n = 0;
    const gateway = new FakePaymentGateway();
    const deps: DisputeDeps = {
      store: new FirestoreDisputeStore(fake.firestore),
      gateway,
      cipher: TEST_CIPHER,
      names: { displayName: async (uid) => ({ c1: 'An', p1: 'Minh Trí', staff1: 'Hỗ trợ' })[uid] ?? '' },
      clock: { now: () => NOW },
      ids: { newId: () => `id_${(n += 1)}` },
    };
    return { docs, fake, deps, gateway };
  }
  const open = (deps: DisputeDeps) =>
    openDispute(deps, 'c1', {
      disputeId: 'dsp_1', subjectType: 'booking', subjectId: 'b1', eventId: null, reason: 'photos_missing',
      description: 'Thiếu 20 ảnh so với gói đã đặt.', evidencePaths: ['disputeEvidence/c1/dsp_1/01J0.jpg'],
    });

  it('the fake refuses a read after a write, like the Admin SDK', async () => {
    const { fake } = world();
    await assert.rejects(
      new FirestoreDisputeStore(fake.firestore).runTransaction(async (tx) => {
        tx.setPayment(payment('pay_paid'));
        await tx.getPayment('pay_paid');
      }),
      /read after write/,
    );
  });

  it('openDispute freezes the payment, links the booking and writes the dispute and its thread', async () => {
    const { docs, deps } = world();
    const d = await open(deps);
    assert.equal(d.status, 'open');
    assert.equal(docs['disputes/dsp_1']?.status, 'open');
    assert.equal(docs['payments/pay_paid']?.escrowStatus, 'disputed');
    assert.equal(docs['payments/pay_paid']?.dispute?.disputeId, 'dsp_1');
    assert.equal(docs['bookings/b1']?.disputeId, 'dsp_1');
    assert.equal(docs['bookings/b1']?.escrowStatus, 'disputed');
    assert.equal(docs['support_threads/dispute_dsp_1']?.kind, 'dispute');
    assert.equal(Object.keys(docs).filter((k) => k.startsWith('support_threads/dispute_dsp_1/messages/')).length, 2);
    // The same id again returns it unchanged.
    assert.deepEqual(await open(deps), d);
  });

  it('resolveDispute split refunds and releases in one transaction, then dispatchDisputeRefund sends it once', async () => {
    const { docs, deps, gateway } = world();
    await open(deps);
    const { dispute: resolved, refund } = await resolveDispute(deps, 'staff1', {
      disputeId: 'dsp_1', outcome: 'split', refundPercent: 40, note: 'Thiếu một phần ảnh.',
    });
    assert.equal(resolved.status, 'resolved');
    assert.equal(resolved.outcome?.refundAmount, 400_000);
    assert.equal(resolved.outcome?.releaseAmount, 600_000);
    assert.ok(refund);
    assert.equal(docs['disputes/dsp_1']?.status, 'resolved');
    assert.equal(docs[`refunds/${refund.id}`]?.status, 'pending');
    assert.equal(docs['bookings/b1']?.depositRefunded, 400_000);
    assert.equal(docs['support_threads/dispute_dsp_1']?.status, 'closed');
    const ledger = Object.entries(docs).filter(([k]) => k.startsWith('ledger_entries/')).map(([, v]) => [v.type, v.amount]);
    assert.deepEqual(ledger.sort(), [['escrow_released', 600_000], ['refund_issued', -400_000]]);

    const payment = await deps.store.runTransaction((tx) => tx.getPayment('pay_paid'));
    assert.ok(payment);
    const sent = await dispatchDisputeRefund(deps, payment, refund);
    assert.equal(sent.status, 'done');
    assert.equal(docs[`refunds/${refund.id}`]?.status, 'done');
    assert.ok(docs['bookings/b1']?.depositRefundedAt instanceof Timestamp);
    // A second dispatch of the settled refund sends nothing.
    await dispatchDisputeRefund(deps, payment, refund);
    assert.deepEqual(gateway.refundCalls, [refund.id]);
  });
});

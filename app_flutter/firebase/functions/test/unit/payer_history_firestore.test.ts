import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import { payerRowOf, refreshPayerHistory, type Payment, type PayerPaymentRow, type Refund } from '@photobooking/domain';
import { paymentToFirestore, refundToFirestore } from '../../src/infra/booking_firestore.js';
import {
  FirestorePayerHistoryStore,
  payerRowFromFirestore,
  payerRowToFirestore,
} from '../../src/infra/payer_history_firestore.js';

// ---- A strict in-memory Firestore: like the Admin SDK, a transaction refuses a read after its first write. ----

type Filter = [string, string, unknown];
interface Write { readonly op: 'set' | 'delete'; readonly path: string; readonly data?: DocumentData }

function strictFirestore(docs: Record<string, DocumentData>) {
  const writes: Write[] = [];
  const reads: string[] = [];
  const snapOf = (path: string) => {
    const data = docs[path];
    return { id: path.split('/').pop() ?? '', exists: data !== undefined, data: () => data, ref: docRef(path) };
  };
  const run = (coll: string, filters: Filter[]) => {
    const found = Object.entries(docs)
      .filter(([path]) => path.startsWith(`${coll}/`) && !path.slice(coll.length + 1).includes('/'))
      .filter(([, d]) => filters.every(([f, op, v]) => (op === '==' ? d[f] === v : true)))
      .map(([path, d]) => ({ id: path.split('/').pop() ?? '', data: () => d }));
    return { empty: found.length === 0, docs: found };
  };
  const query = (coll: string, filters: Filter[]): unknown => ({
    coll,
    filters,
    where: (f: string, op: string, v: unknown) => query(coll, [...filters, [f, op, v]]),
    orderBy: () => query(coll, filters),
    limit: () => query(coll, filters),
  });
  const collection = (path: string): unknown => ({ ...(query(path, []) as object), doc: (id: string) => docRef(`${path}/${id}`) });
  const docRef = (path: string): unknown => ({ path, id: path.split('/').pop(), collection: (c: string) => collection(`${path}/${c}`) });
  const firestore = {
    collection,
    doc: (path: string) => docRef(path),
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>) => {
      let wrote = false;
      const pending: Write[] = [];
      const write = (w: Write) => {
        wrote = true;
        pending.push(w);
      };
      const tx = {
        get: async (x: { path?: string; coll?: string; filters?: Filter[] }) => {
          if (wrote) throw new Error(`read after write: ${x.path ?? x.coll ?? '?'}`);
          reads.push(x.path ?? `${x.coll}?${JSON.stringify(x.filters)}`);
          return x.coll !== undefined && x.filters !== undefined ? run(x.coll, x.filters) : snapOf(String(x.path));
        },
        set: (ref: { path: string }, data: DocumentData) => write({ op: 'set', path: ref.path, data }),
        delete: (ref: { path: string }) => write({ op: 'delete', path: ref.path }),
      };
      const result = await fn(tx);
      for (const w of pending) {
        writes.push(w);
        if (w.op === 'delete') Reflect.deleteProperty(docs, w.path);
        else docs[w.path] = w.data ?? {};
      }
      return result;
    },
  } as unknown as Firestore;
  return { firestore, writes, reads };
}

// ---- Fixtures ----

const T = '2026-10-10T08:00:00.000Z';
const NOW = new Date('2026-10-20T10:00:00.000Z');
const VCB = { bankCode: 'VCB', bankName: 'Vietcombank', accountNumberEnc: 'enc:0123456789', accountLast4: '6789', holderName: 'NGUYEN THANH HA' };

const payment = (over: Partial<Payment> = {}): Payment => ({
  id: 'pay1', subjectType: 'booking', subjectId: 'b1', payerId: 'c1', payeeId: 'p1', provider: 'fake',
  amount: 1_500_000, status: 'paid', escrowStatus: 'held', idempotencyKey: 'k1', method: 'bank_qr',
  receivedAmount: 1_500_000, paidAt: T, payer: VCB, providerRef: 'prov_pay_1', createdAt: T, updatedAt: T, ...over,
});
const refund = (over: Partial<Refund> = {}): Refund => ({
  id: 'r1', paymentId: 'pay1', subjectType: 'booking', amount: 750_000, percent: 50, status: 'done', manual: false,
  fromEscrow: true, method: 'bank_transfer', destination: { ...VCB, source: 'payer' }, attempts: 1, providerRef: 'prov_ref_1',
  createdAt: '2026-10-12T08:00:00.000Z', updatedAt: '2026-10-12T09:00:00.000Z', ...over,
});

function world(extra: Record<string, DocumentData> = {}) {
  const docs: Record<string, DocumentData> = {
    'payments/pay1': paymentToFirestore(payment()),
    'bookings/b1': { photographerId: 'p1', customerId: 'c1', serviceSnapshot: { name: 'Chân dung 2 giờ' }, day: '2026-10-12', status: 'accepted' },
    'users/p1': { displayName: 'Minh Trí' },
    ...extra,
  };
  const fake = strictFirestore(docs);
  const deps = { store: new FirestorePayerHistoryStore(fake.firestore), clock: { now: () => NOW } };
  return { docs, fake, deps };
}

describe('payer history rows in Firestore', () => {
  it('row round-trips Timestamps and never contains payer, candidate or accountNumberEnc', async () => {
    const row = payerRowOf(
      payment({ status: 'partially_refunded', escrowStatus: 'released', refundedAmount: 750_000 }),
      [refund(), refund({ id: 'r2', amount: 1, status: 'pending' })],
      { title: 'Minh Trí · Chân dung 2 giờ', day: '2026-10-12', eventId: null, searching: false, cancelled: true },
      NOW,
    ) as PayerPaymentRow;
    const doc = payerRowToFirestore(row);
    assert.ok(doc.createdAt instanceof Timestamp);
    assert.ok(doc.paidAt instanceof Timestamp);
    assert.ok(doc.updatedAt instanceof Timestamp);
    assert.ok(doc.refunds[0].createdAt instanceof Timestamp);
    assert.ok(doc.refunds[0].doneAt instanceof Timestamp);
    assert.equal(doc.refunds[1].doneAt, null);
    assert.deepEqual(payerRowFromFirestore('pay1', doc), row);

    // Through the trigger path: the payment holds the payer's account, the refund a candidate; the row has neither.
    const { docs, deps } = world({
      'payments/pay1': paymentToFirestore(payment({ status: 'refunded', escrowStatus: 'refunded', refundedAmount: 1_500_000 })),
      'refunds/r1': { ...refundToFirestore(refund({ amount: 1_500_000, percent: 100, status: 'awaiting_account' })), candidate: { ...VCB, accountNumberEnc: 'enc:9999' } },
    });
    assert.equal(await refreshPayerHistory(deps, 'pay1'), 'written');
    const stored = docs['users/c1/payments/pay1'];
    assert.ok(stored);
    assert.equal(stored.status, 'refund_account_needed');
    const json = JSON.stringify(stored);
    for (const secret of ['accountNumberEnc', 'enc:', 'candidate', 'payer"', 'holderName', 'prov_', 'instructions', 'NGUYEN']) {
      assert.equal(json.includes(secret), false, secret);
    }
    assert.deepEqual(docs['users/c1/private/paymentTotals'], { held: 0, refunding: 1_500_000, updatedAt: Timestamp.fromDate(NOW) });
  });

  it('subjectOf a booking reads the photographer\'s display name', async () => {
    const { docs, deps } = world();
    assert.equal(await refreshPayerHistory(deps, 'pay1'), 'written');
    const row = payerRowFromFirestore('pay1', docs['users/c1/payments/pay1']);
    assert.deepEqual([row?.title, row?.day, row?.cancelled, row?.status], ['Minh Trí · Chân dung 2 giờ', '2026-10-12', false, 'held']);
    // A declined booking reads as cancelled.
    docs['bookings/b1'] = { ...docs['bookings/b1'], status: 'declined' };
    await refreshPayerHistory(deps, 'pay1');
    assert.equal(docs['users/c1/payments/pay1']?.cancelled, true);
  });

  it('a ticket reads the event title, the number of tickets and the Vietnam day of the event', async () => {
    const { docs, deps } = world({
      'payments/pay1': paymentToFirestore(payment({ subjectType: 'event_registration', subjectId: 'reg1', eventId: 'ev1', payeeId: 'platform', method: 'zalopay' })),
      'events/ev1/registrations/reg1': {
        quantity: 2, status: 'paid',
        // 20/10 00:30 in Vietnam is still 19/10 in UTC.
        event: { title: 'Photo walk phố cổ', startAt: Timestamp.fromDate(new Date('2026-10-19T17:30:00.000Z')) },
      },
    });
    await refreshPayerHistory(deps, 'pay1');
    const row = payerRowFromFirestore('pay1', docs['users/c1/payments/pay1']);
    assert.deepEqual([row?.title, row?.day, row?.eventId, row?.toPlatform, row?.method], ['Photo walk phố cổ · 2 vé', '2026-10-20', 'ev1', true, 'zalopay']);
  });

  it('a Chụp ngay request shows its area and searching; a missing request keeps the stored title', async () => {
    const { docs, deps } = world({
      'payments/pay1': paymentToFirestore(payment({ subjectType: 'instant_request', subjectId: 'ir1', payeeId: '', method: 'momo' })),
      'instant_requests/ir1': { status: 'searching', areaLabel: 'Quận 1' },
    });
    await refreshPayerHistory(deps, 'pay1');
    let row = payerRowFromFirestore('pay1', docs['users/c1/payments/pay1']);
    assert.deepEqual([row?.title, row?.searching, row?.cancelled, row?.day], ['Chụp ngay · Quận 1', true, false, null]);
    docs['instant_requests/ir1'] = { status: 'no_match', areaLabel: 'Quận 1' };
    await refreshPayerHistory(deps, 'pay1');
    row = payerRowFromFirestore('pay1', docs['users/c1/payments/pay1']);
    assert.deepEqual([row?.searching, row?.cancelled], [false, true]);
    delete docs['instant_requests/ir1'];
    await refreshPayerHistory(deps, 'pay1');
    assert.equal(docs['users/c1/payments/pay1']?.title, 'Chụp ngay · Quận 1');
  });

  it('the S21 verification fee reads "Phí xác minh"', async () => {
    const { docs, deps } = world({
      'payments/pay1': paymentToFirestore(payment({ subjectType: 'verification_fee', subjectId: 'p9', payerId: 'p9', payeeId: 'platform', escrowStatus: 'released' })),
    });
    await refreshPayerHistory(deps, 'pay1');
    assert.deepEqual(
      [docs['users/p9/payments/pay1']?.title, docs['users/p9/payments/pay1']?.status, docs['users/p9/payments/pay1']?.open],
      ['Phí xác minh', 'released', false],
    );
  });

  it('totals come from the open rows of the payer; a row without money is deleted', async () => {
    const other = payerRowOf(payment({ id: 'pay0', subjectId: 'b0', amount: 800_000 }), [], { title: 'x', day: null, eventId: null, searching: false, cancelled: false }, NOW) as PayerPaymentRow;
    const { docs, deps } = world({ 'users/c1/payments/pay0': payerRowToFirestore(other) });
    await refreshPayerHistory(deps, 'pay1');
    assert.equal(docs['users/c1/private/paymentTotals']?.held, 1_500_000 + 800_000);
    docs['payments/pay1'] = paymentToFirestore(payment({ status: 'created', receivedAmount: 0, paidAt: undefined }));
    assert.equal(await refreshPayerHistory(deps, 'pay1'), 'deleted');
    assert.equal(docs['users/c1/payments/pay1'], undefined);
    assert.equal(docs['users/c1/private/paymentTotals']?.held, 800_000);
  });

  it('every read comes before the first write (the strict fake refuses a read after a write)', async () => {
    const { fake, deps } = world({ 'refunds/r1': refundToFirestore(refund({ status: 'pending' })) });
    await assert.rejects(
      new FirestorePayerHistoryStore(fake.firestore).runTransaction(async (tx) => {
        tx.deleteRow('c1', 'pay1');
        await tx.payment('pay1');
      }),
      /read after write/,
    );
    assert.equal(await refreshPayerHistory(deps, 'pay1'), 'written');
    assert.deepEqual(fake.writes.map((w) => `${w.op} ${w.path}`), ['set users/c1/payments/pay1', 'set users/c1/private/paymentTotals']);
  });
});

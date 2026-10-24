import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  InstantPaymentSettler,
  answerInstantOffer,
  cancelInstantRequest,
  confirmInstantComplete,
  createInstantRequest,
  fakeTransferFor,
  instantRefundHandler,
  inviteInstant,
  updateInstantJob,
  type InstantDeps,
  type InstantOffer,
  type Payment,
} from '@photobooking/domain';
import { paymentFromFirestore, paymentToFirestore, refundFromFirestore } from '../../src/infra/booking_firestore.js';
import {
  FirestoreInstantStore,
  FirestoreInstantTx,
  instantCustomerLockPath,
  instantDispatchPath,
  instantOfferFromFirestore,
  instantOfferToFirestore,
  instantPresenceFromFirestore,
  instantPresenceToFirestore,
  instantRequestFromFirestore,
  instantRequestPath,
  instantRequestToFirestore,
} from '../../src/infra/instant_firestore.js';
import {
  FirestoreInstantConfigReader,
  FirestoreInstantDayReader,
  instantProfileOf,
} from '../../src/infra/instant_readers.js';
import { LAN, MEET, createInstantWorld } from '../../../../../packages/domain/test/support/instant_world.js';
import { T0, aConfig, aPresence, aRequest } from '../../../../../packages/domain/test/support/instant_fixtures.js';

const at = (s: number): Date => new Date(T0.getTime() + s * 1000);

/** Every leaf of a stored document; `undefined` would fail a real Firestore write. */
function undefinedPaths(v: unknown, path = ''): string[] {
  if (v === undefined) return [path];
  if (v instanceof Timestamp || v === null || typeof v !== 'object') return [];
  return Object.entries(v as Record<string, unknown>).flatMap(([k, x]) => undefinedPaths(x, `${path}.${k}`));
}

/**
 * A small in-memory Firestore: `doc(path)`, `getAll`, equality queries (`collection().where()`),
 * `runTransaction` (writes applied at the end, no retries). Records every transaction's reads and
 * writes by path. Like the Admin SDK, a transaction refuses a read after its first write.
 */
class FakeFirestore {
  readonly docs = new Map<string, DocumentData>();
  readonly getAllCalls: string[][] = [];
  readonly txLog: Array<{ reads: string[]; writes: string[] }> = [];

  collection(path: string) {
    const query = (filters: Array<[string, unknown]>) => ({
      kind: 'query' as const,
      path,
      filters,
      where: (field: string, op: string, value: unknown) => {
        assert.equal(op, '==', 'the fake answers equality filters only');
        return query([...filters, [field, value]]);
      },
    });
    return query([]);
  }

  private run(q: { path: string; filters: Array<[string, unknown]> }) {
    const depth = q.path.split('/').length + 1;
    const docs = [...this.docs.entries()]
      .filter(([k, d]) => k.startsWith(`${q.path}/`) && k.split('/').length === depth && q.filters.every(([f, v]) => d[f] === v))
      .map(([k, d]) => ({ id: k.split('/').pop() ?? '', data: () => d }));
    return { docs, empty: docs.length === 0, size: docs.length };
  }

  private snap(path: string) {
    const data = this.docs.get(path);
    return { exists: data !== undefined, id: path.split('/').pop() ?? '', data: () => data };
  }

  doc(path: string) {
    return { path, id: path.split('/').pop() ?? '', get: async () => this.snap(path) };
  }

  async getAll(...refs: Array<{ path: string }>) {
    this.getAllCalls.push(refs.map((r) => r.path));
    return refs.map((r) => this.snap(r.path));
  }

  async runTransaction<T>(fn: (tx: unknown) => Promise<T>): Promise<T> {
    const log = { reads: [] as string[], writes: [] as string[] };
    const staged: Array<() => void> = [];
    const noWriteYet = (what: string) => {
      if (log.writes.length > 0) throw new Error(`read after write: ${what}`);
    };
    const tx = {
      getAll: async (...refs: Array<{ path: string }>) => {
        noWriteYet(refs.map((r) => r.path).join(','));
        log.reads.push(...refs.map((r) => r.path));
        return refs.map((r) => this.snap(r.path));
      },
      get: async (q: { kind: 'query'; path: string; filters: Array<[string, unknown]> }) => {
        noWriteYet(q.path);
        log.reads.push(`${q.path}?${q.filters.map(([f, v]) => `${f}=${String(v)}`).join('&')}`);
        return this.run(q);
      },
      set: (ref: { path: string }, data: DocumentData) => {
        log.writes.push(ref.path);
        staged.push(() => this.docs.set(ref.path, data));
      },
      delete: (ref: { path: string }) => {
        log.writes.push(ref.path);
        staged.push(() => this.docs.delete(ref.path));
      },
    };
    const out = await fn(tx);
    for (const apply of staged) apply();
    this.txLog.push(log);
    return out;
  }

  get firestore(): Firestore {
    return this as unknown as Firestore;
  }
}

/** A request with every optional field set, nested rows and arrays. */
function fullRequest() {
  return aRequest({
    id: 'ir_full',
    customerAvatarUrl: 'https://img.test/lan.jpg',
    status: 'en_route',
    note: 'Áo trắng',
    committedAt: at(1),
    payMethod: 'bank_qr',
    provider: 'fake',
    paymentId: 'pay_1',
    paidAt: at(2),
    paymentDeadlineAt: at(3),
    refundId: 'rf_1',
    refundStatus: 'pending',
    round: 2,
    invitedTotal: 3,
    roundsWithInvites: 1,
    candidates: [{
      photographerId: 'p1', name: 'An', avatarUrl: null, verified: true, providerType: 'individual', tomatoPct: 96,
      reviewCount: 12, completedCount: 30, distanceKm: 0.5, etaMinutes: 3, photos: ['https://img.test/1.jpg'],
      reasons: [{ code: 'genre', text: 'Chụp chân dung' }], tier: 'priority', score: 0.8,
    }],
    offers: [
      { offerId: 'of_1', photographerId: 'p1', name: 'An', avatarUrl: null, tomatoPct: 96, reviewCount: 12, etaMinutes: 3, outcome: 'accepted', expiresAt: at(60) },
      { offerId: null, photographerId: 'p2', name: 'Bình', avatarUrl: 'https://img.test/b.jpg', tomatoPct: 0, reviewCount: 0, etaMinutes: 5, outcome: 'unavailable', expiresAt: null },
    ],
    excludedIds: ['p3', 'p4'],
    pendingInviteIds: ['p5'],
    roundEnded: true,
    photographerId: 'p1',
    photographer: { id: 'p1', name: 'An', avatarUrl: null, verified: true, tomatoPct: 96, reviewCount: 12, completedCount: 30 },
    chatId: 'c-lan_p1',
    etaMinutes: 3,
    assignedAt: at(10), freeCancelUntil: at(130), lateDeadlineAt: at(1090), startedRouteAt: at(20), arrivedAt: at(30),
    forcedArrivalAccuracyM: 150, startedAt: at(40), shootEndsAt: at(3640), finishedAt: at(50), completedAt: at(60),
    cancelledAt: at(70), cancelledBy: 'photographer', cancelRule: 'en_route', refundPercent: 80, feeVnd: 138_000,
    searchDeadlineAt: at(600), lastActivityAt: at(5), nextDeadlineAt: at(1090), createdAt: T0, updatedAt: at(80), version: 7,
  });
}

describe('instant Firestore mapping', () => {
  it('request round trip: every Timestamp, nested arrays and nulls', () => {
    for (const r of [aRequest(), fullRequest()]) {
      const stored = instantRequestToFirestore(r);
      assert.ok(stored.createdAt instanceof Timestamp);
      assert.equal(stored.excludedIds, undefined, 'excludedIds never on the public document');
      const back = instantRequestFromFirestore(r.id, stored, { excludedIds: [...r.excludedIds] });
      assert.deepEqual(back, r);
    }
    const full = instantRequestToFirestore(fullRequest());
    assert.ok((full.offers as Array<{ expiresAt: unknown }>)[0]?.expiresAt instanceof Timestamp);
    assert.equal((full.offers as Array<{ expiresAt: unknown }>)[1]?.expiresAt, null);
    assert.equal(full.active, true);
  });

  it('request mapping never writes undefined', () => {
    assert.deepEqual(undefinedPaths(instantRequestToFirestore(aRequest())), []);
    assert.deepEqual(undefinedPaths(instantRequestToFirestore(fullRequest())), []);
    assert.deepEqual(undefinedPaths(instantPresenceToFirestore(aPresence('p1', { heartbeatAt: null, lat: null, lng: null }))), []);
  });

  it('unknown status in a stored doc reads as not found', () => {
    const stored = instantRequestToFirestore(aRequest());
    assert.equal(instantRequestFromFirestore('ir_01', { ...stored, status: 'teleported' }), null);
    assert.equal(instantRequestFromFirestore('ir_01', { ...stored, genre: 'underwater' }), null);
    assert.equal(instantRequestFromFirestore('ir_01', undefined), null);
    // Without a dispatch document the request has no exclusions.
    assert.deepEqual(instantRequestFromFirestore('ir_01', stored)?.excludedIds, []);
  });

  it('offer round trip', () => {
    const offer: InstantOffer = {
      id: 'of_1', requestId: 'ir_01', photographerId: 'p1', round: 2, offeredAt: T0, expiresAt: at(60), outcome: 'pending',
      decidedAt: null, packageCode: 'p60', durationMin: 60, photos: 30, genre: 'couple', areaLabel: 'Quận 1, TP.HCM',
      distanceKm: 0.5, etaMinutes: 3, earningVnd: 690_000, note: '', invitedCount: 3,
    };
    const stored = instantOfferToFirestore(offer);
    assert.deepEqual(undefinedPaths(stored), []);
    assert.deepEqual(instantOfferFromFirestore('of_1', stored), offer);
    const decided = { ...offer, outcome: 'declined' as const, decidedAt: at(10) };
    assert.deepEqual(instantOfferFromFirestore('of_1', instantOfferToFirestore(decided)), decided);
    assert.equal(instantOfferFromFirestore('of_1', { ...stored, outcome: 'lost' }), null);
  });

  it('presence round trip', () => {
    const p = aPresence('p1', {
      helpReady: true, activeRequestId: 'ir_01',
      pendingOffers: [{ offerId: 'of_1', requestId: 'ir_01', expiresAt: at(60) }],
      profile: { specialties: ['portrait', 'family'], photos: ['https://img.test/1.jpg'], tomatoPct: 92, reviewCount: 8 },
      reliability: { offers: 10, accepted: 6, declined: 2, expired: 1, cancelled: 1, late: 0, noShow: 0 },
    });
    assert.deepEqual(instantPresenceFromFirestore('p1', instantPresenceToFirestore(p)), p);
    const offline = aPresence('p2', { online: false, lat: null, lng: null, accuracyM: null, heartbeatAt: null, priceListVersion: null, cityId: null });
    assert.deepEqual(instantPresenceFromFirestore('p2', instantPresenceToFirestore(offline)), offline);
  });
});

describe('instant transaction adapter', () => {
  function adapterWorld() {
    const w = createInstantWorld();
    const db = new FakeFirestore();
    for (const p of w.store.presences.values()) db.docs.set(`instant_presence/${p.uid}`, instantPresenceToFirestore(p));
    const deps: InstantDeps = { ...w.deps, store: new FirestoreInstantStore(db.firestore) };
    return { w, db, deps };
  }

  it('excludedIds live only in private/dispatch, and the customer lock follows the active request', async () => {
    const { db, deps } = adapterWorld();
    const { requestId } = await createInstantRequest(deps, LAN, { packageCode: 'p60', genre: 'portrait', meetPoint: MEET });
    assert.deepEqual(db.docs.get(instantCustomerLockPath(LAN.uid))?.activeRequestId, requestId);
    assert.equal(db.docs.get(instantRequestPath(requestId))?.excludedIds, undefined);
    assert.deepEqual(db.docs.get(instantDispatchPath(requestId))?.excludedIds, []);
    // The create read the lock: two concurrent creates conflict on it.
    assert.ok(db.txLog.at(-1)?.reads.includes(instantCustomerLockPath(LAN.uid)));

    // A second create finds the active request through the lock.
    await assert.rejects(
      createInstantRequest(deps, LAN, { packageCode: 'p60', genre: 'portrait', meetPoint: MEET }),
      (e: unknown) => (e as { code?: string }).code === 'conflict',
    );

    const { nextInstantCandidates } = await import('@photobooking/domain');
    await nextInstantCandidates(deps, LAN, { requestId, skipped: ['p1', 'p2'] });
    assert.deepEqual(db.docs.get(instantDispatchPath(requestId))?.excludedIds, ['p1', 'p2']);
    assert.equal(db.docs.get(instantRequestPath(requestId))?.excludedIds, undefined);
    const store = new FirestoreInstantStore(db.firestore);
    const read = await store.runTransaction((tx) => tx.getRequest(requestId));
    assert.deepEqual(read?.excludedIds, ['p1', 'p2']);

    await cancelInstantRequest(deps, LAN, { requestId, dryRun: false });
    assert.equal(db.docs.get(instantRequestPath(requestId))?.active, false);
    assert.equal(db.docs.get(instantCustomerLockPath(LAN.uid))?.activeRequestId, null);
    // Free again: a new request is allowed and takes the lock.
    const next = await createInstantRequest(deps, LAN, { packageCode: 'p30', genre: 'portrait', meetPoint: MEET });
    assert.equal(db.docs.get(instantCustomerLockPath(LAN.uid))?.activeRequestId, next.requestId);
  });

  it('every request write stores nextDeadlineAt as a Timestamp for the clock query', async () => {
    const { db, deps } = adapterWorld();
    const { requestId } = await createInstantRequest(deps, LAN, { packageCode: 'p60', genre: 'portrait', meetPoint: MEET });
    const stored = db.docs.get(instantRequestPath(requestId));
    assert.ok(stored !== undefined && 'nextDeadlineAt' in stored);
    assert.ok(stored.nextDeadlineAt instanceof Timestamp, 'a choosing request is abandoned after 30 min');
  });

  it('a lock left on an ended request is stale, not a conflict', async () => {
    const db = new FakeFirestore();
    db.docs.set(instantRequestPath('ir_old'), instantRequestToFirestore(aRequest({ id: 'ir_old', status: 'completed', active: false })));
    db.docs.set(instantCustomerLockPath('c-lan'), { activeRequestId: 'ir_old' });
    const store = new FirestoreInstantStore(db.firestore);
    assert.equal(await store.runTransaction((tx) => tx.findActiveRequestOfCustomer('c-lan')), null);
  });

  it('refuses a read after the first write', async () => {
    const db = new FakeFirestore();
    await assert.rejects(
      db.runTransaction(async (fTx) => {
        const tx = new FirestoreInstantTx(db.firestore, fTx as never);
        tx.putPresence(aPresence('p1'));
        await tx.getPresence('p1');
      }),
      /read after write/,
    );
  });

  it('buffers writes by path: the last one wins, deletes included', async () => {
    const db = new FakeFirestore();
    db.docs.set('instant_tracks/ir_01', { lat: 1 });
    await db.runTransaction(async (fTx) => {
      const tx = new FirestoreInstantTx(db.firestore, fTx as never);
      tx.putTrack('ir_01', { customerId: 'c', photographerId: 'p', active: true, lat: 2, lng: 3, accuracyM: 10, heading: null, at: T0 });
      tx.deleteTrack('ir_01');
      tx.commit();
    });
    assert.equal(db.docs.has('instant_tracks/ir_01'), false);
    assert.deepEqual(db.txLog.at(-1)?.writes, ['instant_tracks/ir_01']);
  });
});

describe('instant money over the Firestore adapter (#202; strict: every read before the first write)', () => {
  function moneyWorld() {
    const w = createInstantWorld();
    const db = new FakeFirestore();
    for (const p of w.store.presences.values()) db.docs.set(`instant_presence/${p.uid}`, instantPresenceToFirestore(p));
    const deps: InstantDeps = { ...w.deps, store: new FirestoreInstantStore(db.firestore) };
    const paymentDoc = (id: string): Payment => {
      const p = paymentFromFirestore(id, db.docs.get(`payments/${id}`));
      assert.ok(p, `payments/${id}`);
      return p;
    };
    return { w, db, deps, paymentDoc };
  }

  it('invite, fake payment, accept and a paid cancel write payments, refunds, ledger and the transfer record', async () => {
    const { w, db, deps, paymentDoc } = moneyWorld();
    const { requestId } = await createInstantRequest(deps, LAN, { packageCode: 'p60', genre: 'portrait', meetPoint: MEET });
    const res = await inviteInstant(deps, LAN, {
      requestId, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr',
    });
    assert.equal(res.kind, 'payment');
    if (res.kind !== 'payment') return;
    const created = paymentDoc(res.instructions.paymentId);
    assert.deepEqual([created.status, created.subjectType, created.subjectId], ['created', 'instant_request', requestId]);
    assert.ok(created.instructions?.qrPayload, 'the gateway answer is saved on the open payment');
    assert.equal(db.docs.get(instantRequestPath(requestId))?.status, 'pending_payment');

    const transfer = fakeTransferFor(created as Payment & { transferCode: string }, 'exact', w.clock.now());
    assert.equal(await new InstantPaymentSettler(deps).settle(created.id, transfer), 'paid');
    assert.equal(paymentDoc(created.id).status, 'paid');
    assert.equal(db.docs.get(`payment_notifications/fake_${transfer.txnId}`)?.outcome, 'paid');
    assert.equal(db.docs.get(instantRequestPath(requestId))?.status, 'searching');
    const offerPath = [...db.docs.keys()].find((k) => k.startsWith('instant_offers/p1/offers/'));
    assert.ok(offerPath !== undefined);

    await answerInstantOffer(deps, { uid: 'p1' }, { offerId: offerPath.split('/').pop(), action: 'accept' });
    assert.equal(paymentDoc(created.id).payeeId, 'p1');
    assert.equal(db.docs.get(`instant_requests/${requestId}/private/contact`)?.phone, '+84901234567');

    w.clock.advance(5 * 60_000); // past the free window, before the late deadline: 80% back
    const q = await cancelInstantRequest(deps, LAN, { requestId, dryRun: false });
    assert.deepEqual([q.rule, q.refundVnd, q.feeVnd], ['en_route', 552_000, 138_000]);
    const after = paymentDoc(created.id);
    assert.deepEqual([after.status, after.escrowStatus], ['partially_refunded', 'partially_refunded']);
    assert.ok(after.releaseAfter !== undefined);
    const refunds = [...db.docs.entries()].filter(([k]) => k.startsWith('refunds/'));
    assert.deepEqual(refunds.map(([, d]) => [d.amount, d.reason, d.status, d.subjectType]), [[552_000, 'en_route', 'done', 'instant_request']]);
    const ledger = [...db.docs.entries()].filter(([k]) => k.startsWith('ledger_entries/')).map(([, d]) => d.amount as number);
    assert.equal(ledger.reduce((a, b) => a + b, 0), 138_000);
    assert.equal(db.docs.get(instantRequestPath(requestId))?.refundStatus, 'done');
    // Every transaction read before it wrote (the fake throws otherwise) and some did both.
    assert.ok(db.txLog.some((t) => t.reads.length > 0 && t.writes.length > 0));
  });

  /** Lan's request through the adapter: paid with a fake transfer, p1 assigned (unless `assign` is false). */
  async function paidRequest(assign = true) {
    const m = moneyWorld();
    const { requestId } = await createInstantRequest(m.deps, LAN, { packageCode: 'p60', genre: 'portrait', meetPoint: MEET });
    const res = await inviteInstant(m.deps, LAN, {
      requestId, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr',
    });
    assert.equal(res.kind, 'payment');
    const paymentId = res.kind === 'payment' ? res.instructions.paymentId : '';
    if (assign) {
      const created = m.paymentDoc(paymentId);
      await new InstantPaymentSettler(m.deps).settle(paymentId, fakeTransferFor(created as Payment & { transferCode: string }, 'exact', m.w.clock.now()));
      const offerPath = [...m.db.docs.keys()].find((k) => k.startsWith('instant_offers/p1/offers/'));
      assert.ok(offerPath !== undefined);
      await answerInstantOffer(m.deps, { uid: 'p1' }, { offerId: offerPath.split('/').pop(), action: 'accept' });
    }
    return { ...m, requestId, paymentId };
  }
  const HERE = { lat: MEET.lat, lng: MEET.lng, accuracyM: 10 };
  const refundDocs = (db: FakeFirestore) =>
    [...db.docs.entries()].filter(([k]) => k.startsWith('refunds/')).map(([k, d]) => refundFromFirestore(k.split('/')[1] ?? '', d));

  it('no-show (dry run and real), photographer cancel and confirm read before they write', async () => {
    const noShow = await paidRequest();
    for (const action of ['start_route', 'arrive']) {
      await updateInstantJob(noShow.deps, { uid: 'p1' }, { requestId: noShow.requestId, action, location: HERE });
    }
    noShow.w.clock.advance(15 * 60_000);
    const quote = await updateInstantJob(noShow.deps, { uid: 'p1' }, { requestId: noShow.requestId, action: 'no_show', dryRun: true });
    assert.equal((quote as { feeVnd?: number }).feeVnd, 345_000);
    await updateInstantJob(noShow.deps, { uid: 'p1' }, { requestId: noShow.requestId, action: 'no_show' });
    assert.deepEqual(refundDocs(noShow.db).map((r) => [r?.amount, r?.reason, r?.status]), [[345_000, 'no_show', 'done']]);
    assert.ok(noShow.paymentDoc(noShow.paymentId).releaseAfter !== undefined);

    const dropped = await paidRequest();
    await cancelInstantRequest(dropped.deps, { uid: 'p1' }, { requestId: dropped.requestId, dryRun: false });
    const held = dropped.paymentDoc(dropped.paymentId);
    assert.deepEqual([held.payeeId, held.escrowStatus], ['', 'held']);
    assert.equal(dropped.db.docs.has(`instant_requests/${dropped.requestId}/private/contact`), false);

    const done = await paidRequest();
    for (const action of ['start_route', 'arrive', 'start']) {
      await updateInstantJob(done.deps, { uid: 'p1' }, { requestId: done.requestId, action, location: HERE });
    }
    await confirmInstantComplete(done.deps, LAN, { requestId: done.requestId });
    const kept = done.paymentDoc(done.paymentId);
    assert.deepEqual([kept.status, kept.payeeId], ['paid', 'p1']);
    assert.equal(kept.releaseAfter, new Date(done.w.clock.now().getTime() + 24 * 3_600_000).toISOString());
  });

  it("expire and V2's record/resend read before they write", async () => {
    const open = await paidRequest(false);
    open.w.clock.advance(16 * 60_000);
    assert.equal(await new InstantPaymentSettler(open.deps).expire(open.paymentId, open.w.clock.now()), 'expired');
    assert.equal(open.paymentDoc(open.paymentId).status, 'expired');

    const m = await paidRequest();
    m.w.gateway.refundThrowCount = 1;
    m.w.clock.advance(5 * 60_000);
    await cancelInstantRequest(m.deps, LAN, { requestId: m.requestId, dryRun: false });
    const [pending] = refundDocs(m.db);
    assert.ok(pending);
    assert.equal(pending.status, 'pending');
    const resent = await instantRefundHandler(m.deps).resend(pending);
    assert.equal(resent.status, 'done');
    assert.equal(refundDocs(m.db)[0]?.status, 'done');
    assert.equal(m.db.docs.get(instantRequestPath(m.requestId))?.refundStatus, 'done');
  });

  it('paymentsOfRequest is a transactional equality query on subjectType and subjectId', async () => {
    const db = new FakeFirestore();
    const base: Payment = {
      id: 'pay_a', subjectType: 'instant_request', subjectId: 'ir_1', payerId: 'c-lan', payeeId: '', provider: 'fake',
      amount: 690_000, status: 'created', escrowStatus: 'held', idempotencyKey: 'inst_ir_1_1',
      createdAt: T0.toISOString(), updatedAt: T0.toISOString(),
    };
    db.docs.set('payments/pay_a', paymentToFirestore(base));
    db.docs.set('payments/pay_b', paymentToFirestore({ ...base, id: 'pay_b', subjectType: 'booking' }));
    db.docs.set('payments/pay_c', paymentToFirestore({ ...base, id: 'pay_c', subjectId: 'ir_2' }));
    const store = new FirestoreInstantStore(db.firestore);
    const found = await store.runTransaction((tx) => tx.paymentsOfRequest('ir_1'));
    assert.deepEqual(found.map((p) => p.id), ['pay_a']);
    assert.deepEqual(db.txLog.at(-1)?.reads, ['payments?subjectType=instant_request&subjectId=ir_1']);
    await assert.rejects(
      db.runTransaction(async (fTx) => {
        const tx = new FirestoreInstantTx(db.firestore, fTx as never);
        tx.putPayment(base);
        await tx.paymentsOfRequest('ir_1');
      }),
      /read after write/,
    );
  });
});

describe('instant readers', () => {
  it('config is parsed and cached for 60 s', async () => {
    const db = new FakeFirestore();
    db.docs.set('instant_config/current', { ...aConfig() });
    let now = 0;
    const reader = new FirestoreInstantConfigReader(db.firestore, () => now);
    assert.equal((await reader.get()).priceListVersion, 1);
    db.docs.set('instant_config/current', { ...aConfig({ priceListVersion: 2 }) });
    now = 59_999;
    assert.equal((await reader.get()).priceListVersion, 1);
    now = 60_000;
    assert.equal((await reader.get()).priceListVersion, 2);
    db.docs.delete('instant_config/current');
    now = 200_000;
    await assert.rejects(reader.get(), (e: unknown) => (e as { code?: string }).code === 'not_eligible');
  });

  it('day states of a round are read with one getAll; unknown states read as no record', async () => {
    const db = new FakeFirestore();
    db.docs.set('availability/p1/days/2026-10-22', { state: 'spot' });
    db.docs.set('availability/p2/days/2026-10-22', { state: 'weird' });
    const reader = new FirestoreInstantDayReader(db.firestore);
    const states = await Promise.all(['p1', 'p2', 'p3'].map((uid) => reader.stateOf(uid, '2026-10-22')));
    assert.deepEqual(states, ['spot', null, null]);
    assert.equal(db.getAllCalls.length, 1);
    assert.equal(db.getAllCalls[0]?.length, 3);
  });

  it('profile snapshot: names, stats and the first image of the first three work posts', () => {
    const profile = instantProfileOf(
      { displayName: 'An', avatarUrl: 'https://img.test/an.jpg' },
      { verified: true, providerType: 'studio', specialties: ['portrait', 3], stats: { tomatoPct: 95, score: 0.9, reviewCount: 6, completedCount: 20 } },
      [
        { kind: 'work', imageUrls: ['https://img.test/w1.jpg', 'x'] },
        { kind: 'real_shoot', imageUrls: ['https://img.test/r.jpg'] },
        { kind: 'work', images: [{ url: 'https://img.test/w2.jpg' }] },
        { kind: 'work', imageUrls: [] },
        { kind: 'work', imageUrls: ['https://img.test/w3.jpg'] },
        { kind: 'work', imageUrls: ['https://img.test/w4.jpg'] },
      ],
    );
    assert.deepEqual(profile, {
      name: 'An', avatarUrl: 'https://img.test/an.jpg', verified: true, providerType: 'studio', tomatoPct: 95, score: 0.9,
      reviewCount: 6, completedCount: 20, specialties: ['portrait'],
      photos: ['https://img.test/w1.jpg', 'https://img.test/w2.jpg', 'https://img.test/w3.jpg'],
    });
    assert.equal(instantProfileOf({ displayName: 'Lan' }, undefined, []), null);
  });
});

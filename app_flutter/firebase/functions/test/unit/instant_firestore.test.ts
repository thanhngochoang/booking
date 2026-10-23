import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import { cancelInstantRequest, createInstantRequest, type InstantDeps, type InstantOffer } from '@photobooking/domain';
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
 * A small in-memory Firestore: `doc(path)`, `getAll`, `runTransaction` (writes applied at the end,
 * no retries). Records every transaction's reads and writes by path.
 */
class FakeFirestore {
  readonly docs = new Map<string, DocumentData>();
  readonly getAllCalls: string[][] = [];
  readonly txLog: Array<{ reads: string[]; writes: string[] }> = [];

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
    const tx = {
      getAll: async (...refs: Array<{ path: string }>) => {
        log.reads.push(...refs.map((r) => r.path));
        return refs.map((r) => this.snap(r.path));
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

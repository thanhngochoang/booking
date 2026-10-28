import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import {
  ANY_ORGANIZER,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  claimSpot,
  expireResidents,
  reviewSpotClaim,
  type GateStaff,
  type Organizer,
  type OrganizerDeps,
  type Resident,
  type Spot,
  type SpotClaim,
} from '@photobooking/domain';
import {
  FirestoreOrganizerStore,
  claimFromFirestore,
  claimToFirestore,
  firestoreOrganizerPeople,
  gateStaffFromFirestore,
  gateStaffToFirestore,
  organizerFromFirestore,
  organizerToFirestore,
  residentFromFirestore,
  residentToFirestore,
} from '../../src/infra/organizer_firestore.js';
import { spotToFirestore } from '../../src/infra/spot_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';

const NOW = '2026-10-18T03:00:00.000Z';

const organizer = (over: Partial<Organizer> = {}): Organizer => ({
  id: 'org1', name: 'Bãi đá sông Hồng', bio: 'Bãi đá ven sông', avatarUrl: null, status: 'active',
  phoneVerified: true, businessVerified: true, payoutAccountOk: false, managedSpotIds: ['s1'],
  createdAt: NOW, updatedAt: NOW, ...over,
});

const spot = (over: Partial<Spot> = {}): Spot => ({
  id: 's1', name: 'Bãi đá sông Hồng', city: 'Hà Nội', areaCode: 'hn', point: { lat: 21.05, lng: 105.85 },
  geohash: 'w7er8u0', radiusM: 500, cover: null, description: '', tips: [], seasonMonths: [], pinned: false,
  hidden: false, status: 'active', hotScore: 0,
  stats: { posts14d: 0, events: 0, bookings14d: 0, openSchedules: 0, providersWeek: 0, providersWeekend: 0 },
  createdAt: NOW, updatedAt: NOW, rankedAt: null, managedBy: null, access: null, openHours: null, updatedBy: 'seed', ...over,
});

const claim = (over: Partial<SpotClaim> = {}): SpotClaim => ({
  id: 'c1', spotId: 's1', proposal: null, organizerId: 'org1', status: 'pending', proofPaths: ['spot_claims/org1/c1/hd.pdf'],
  note: 'Hợp đồng thuê', reason: null, createdAt: NOW, reviewedAt: null, reviewedBy: null, ...over,
});

describe('organizer Firestore mapping', () => {
  it('organizer/claim/resident/gateStaff to/from Firestore round-trip', () => {
    const o = organizer();
    assert.deepEqual(organizerFromFirestore(o.id, organizerToFirestore(o)), o);
    assert.equal(organizerToFirestore(o).createdAt instanceof Timestamp, true);

    for (const c of [
      claim(),
      claim({ id: 'c2', spotId: null, proposal: { name: 'Bãi đá mới', address: 'Long Biên' }, status: 'rejected', reason: 'Thiếu giấy tờ', reviewedAt: NOW, reviewedBy: 'admin1' }),
    ]) {
      assert.deepEqual(claimFromFirestore(c.id, claimToFirestore(c)), c);
    }

    const r: Resident = { providerId: 'p1', waivesProvider: true, waivesGuests: true, maxGuests: 4, validUntil: '2026-12-31', addedAt: NOW, addedBy: 'org1' };
    assert.deepEqual(residentFromFirestore('p1', residentToFirestore(r)), r);
    assert.equal(residentToFirestore(r).validUntil, '2026-12-31');
    const open: Resident = { ...r, maxGuests: null, validUntil: null };
    assert.deepEqual(residentFromFirestore('p1', residentToFirestore(open)), open);

    const invited: GateStaff = { staffUid: 'g1', status: 'invited', invitedAt: NOW, respondedAt: null };
    assert.deepEqual(gateStaffFromFirestore('g1', gateStaffToFirestore(invited)), invited);
    const active: GateStaff = { ...invited, status: 'active', respondedAt: NOW, scansToday: { day: '2026-10-18', count: 3 } };
    assert.deepEqual(gateStaffFromFirestore('g1', gateStaffToFirestore(active)), active);

    for (const read of [organizerFromFirestore, residentFromFirestore, gateStaffFromFirestore, claimFromFirestore]) {
      assert.equal(read('x', undefined), null);
    }
  });
});

describe('FirestoreOrganizerStore', () => {
  const people = (staff: readonly string[] = ['admin1']): OrganizerDeps['people'] => ({
    phoneVerified: async () => true,
    businessVerified: async () => false,
    payoutAccountOk: async () => false,
    lookup: async () => null,
    isStaff: async (uid) => staff.includes(uid),
  });
  const deps = (db: MemoryFirestore): OrganizerDeps => {
    let n = 0;
    return {
      organizers: new FirestoreOrganizerStore(db.asFirestore()),
      people: people(),
      providers: { acceptsOrders: async () => true, orderProfile: async () => ({ acceptsOrders: true, providerType: 'individual' }) },
      notify: { store: new MemoryNotificationStore(), push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now: () => new Date(NOW) } },
      clock: { now: () => new Date(NOW) },
      ids: { newId: () => `01ARZ3NDEKTSV4RRFFQ69G5F${String(++n).padStart(2, '0')}` },
    };
  };

  it('runs claimSpot and reviewSpotClaim: managedBy, managedSpotIds and the other pending claim rejected', async () => {
    const db = new MemoryFirestore();
    db.seed('organizers/org1', organizerToFirestore(organizer({ managedSpotIds: [] })));
    db.seed('organizers/org2', organizerToFirestore(organizer({ id: 'org2', managedSpotIds: [] })));
    db.seed('spots/s1', spotToFirestore(spot()));
    const d = deps(db);
    const { claimId } = await claimSpot(d, 'org1', { spotId: 's1', proofPaths: ['spot_claims/org1/x/hd.pdf'] });
    const other = await claimSpot(d, 'org2', { spotId: 's1', proofPaths: ['spot_claims/org2/x/hd.pdf'] });
    await assert.rejects(claimSpot(d, 'org1', { spotId: 's1', proofPaths: ['spot_claims/org1/y/hd.pdf'] }), { code: 'limit_exceeded' });

    const reviewed = await reviewSpotClaim(d, 'admin1', { claimId, approve: true });
    assert.equal(reviewed.status, 'approved');
    assert.equal(db.data('spots/s1')?.managedBy, 'org1');
    assert.deepEqual(db.data('organizers/org1')?.managedSpotIds, ['s1']);
    assert.equal(db.data(`spot_claims/${other.claimId}`)?.status, 'rejected');
    assert.equal(db.data(`spot_claims/${other.claimId}`)?.reason, 'spot_managed');
    // The second approval re-reads managedBy and writes nothing.
    db.seed('spot_claims/c9', claimToFirestore(claim({ id: 'c9', organizerId: 'org2' })));
    const before = db.log.length;
    await assert.rejects(reviewSpotClaim(d, 'admin1', { claimId: 'c9', approve: true }), { code: 'spot_managed' });
    assert.equal(db.log.length, before);
  });

  it('pendingClaimsOf filters spot, organizer and proposals; residents, gate staff and open events', async () => {
    const db = new MemoryFirestore();
    db.seed('spot_claims/c1', claimToFirestore(claim()));
    db.seed('spot_claims/c2', claimToFirestore(claim({ id: 'c2', organizerId: 'org2' })));
    db.seed('spot_claims/c3', claimToFirestore(claim({ id: 'c3', spotId: null, proposal: { name: 'Mới', address: 'HN' } })));
    db.seed('spot_claims/c4', claimToFirestore(claim({ id: 'c4', status: 'approved' })));
    db.seed('spots/s1/residents/p1', residentToFirestore({ providerId: 'p1', waivesProvider: true, waivesGuests: false, maxGuests: null, validUntil: null, addedAt: NOW, addedBy: 'org1' }));
    db.seed('organizers/org1/gate_staff/g1', gateStaffToFirestore({ staffUid: 'g1', status: 'active', invitedAt: NOW, respondedAt: NOW }));
    db.seed('events/e1', { hostId: 'org1', host: { type: 'organizer', id: 'org1' }, status: 'open', type: 'entry', title: 'Vé vào cửa' });
    db.seed('events/e2', { hostId: 'org1', host: { type: 'organizer', id: 'org1' }, status: 'cancelled', type: 'entry' });
    db.seed('events/e3', { hostId: 'org1', host: { type: 'photographer', id: 'org1' }, status: 'open', type: 'photo_walk' });
    const store = new FirestoreOrganizerStore(db.asFirestore());
    const out = await store.runTransaction(async (tx) => ({
      mine: (await tx.pendingClaimsOf('s1', 'org1')).map((c) => c.id),
      any: (await tx.pendingClaimsOf('s1', ANY_ORGANIZER)).map((c) => c.id).sort(),
      proposals: (await tx.pendingClaimsOf(null, 'org1')).map((c) => c.id),
      residents: (await tx.residentsOf('s1')).map((r) => r.providerId),
      resident: await tx.getResident('s1', 'nobody'),
      staff: (await tx.gateStaffOf('org1')).map((g) => `${g.staffUid}:${g.status}`),
      events: (await tx.openEventsOf('org1')).map((e) => e.id),
    }));
    assert.deepEqual(out, {
      mine: ['c1'], any: ['c1', 'c2'], proposals: ['c3'], residents: ['p1'], resident: null, staff: ['g1:active'], events: ['e1'],
    });
    await store.runTransaction(async (tx) => {
      tx.deleteResident('s1', 'p1');
    });
    assert.equal(db.data('spots/s1/residents/p1'), undefined);
    assert.deepEqual((await store.listClaims('pending')).map((c) => c.id), ['c1', 'c2', 'c3']);
  });

  it('expiredResidents is a collection-group query on validUntil (rows without a date stay); expireResidents deletes them', async () => {
    const db = new MemoryFirestore();
    const row = (validUntil: string | null): Resident => ({
      providerId: 'x', waivesProvider: true, waivesGuests: true, maxGuests: null, validUntil, addedAt: NOW, addedBy: 'org1',
    });
    db.seed('spots/s1/residents/p1', residentToFirestore(row('2026-10-17')));
    db.seed('spots/s1/residents/p2', residentToFirestore(row('2026-10-18')));
    db.seed('spots/s2/residents/p3', residentToFirestore(row(null)));
    db.seed('spots/s2/residents/p4', residentToFirestore(row('2026-01-01')));
    const store = new FirestoreOrganizerStore(db.asFirestore());
    const due = await store.expiredResidents('2026-10-18', 10);
    assert.deepEqual(due.map((r) => `${r.spotId}/${r.providerId}`).sort(), ['s1/p1', 's2/p4']);
    assert.equal(await expireResidents(deps(db), '2026-10-18'), 2);
    assert.equal(db.data('spots/s1/residents/p1'), undefined);
    assert.notEqual(db.data('spots/s1/residents/p2'), undefined);
    assert.notEqual(db.data('spots/s2/residents/p3'), undefined);
  });
});

describe('firestoreOrganizerPeople', () => {
  const world = (): MemoryFirestore => {
    const db = new MemoryFirestore();
    db.seed('users/u1', { displayName: 'Dũng' });
    db.seed('users/u1/private/contact', { phone: '+84903123456', phoneVerified: true });
    // The same number in a booking's contact copy and a provider's contact must not resolve.
    db.seed('bookings/b1/private/contact', { phone: '+84903123456', name: 'Dũng' });
    db.seed('photographers/u9/private/contact', { phone: '+84903999999' });
    db.seed('users/u2/private/contact', { phone: '+84903222222', phoneVerified: false });
    return db;
  };

  it('lookup finds a user by 0903 123 456 and by +84903123456', async () => {
    const people = firestoreOrganizerPeople(world().asFirestore(), async () => false);
    assert.deepEqual(await people.lookup('0903 123 456'), { uid: 'u1', name: 'Dũng' });
    assert.deepEqual(await people.lookup('+84903123456'), { uid: 'u1', name: 'Dũng' });
    assert.equal(await people.lookup('0903 999 999'), null);
    assert.equal(await people.lookup('0903 000 000'), null);
    // No account carries a username: `@` targets resolve to nobody (phone only, ledgered).
    assert.equal(await people.lookup('@dung'), null);
    assert.equal(await people.lookup('not a phone'), null);
  });

  it('phoneVerified, businessVerified, payoutAccountOk and isStaff', async () => {
    const db = world();
    db.seed('verifications/u1', { business: { status: 'approved', name: 'CÔNG TY BÃI ĐÁ', subject: 'organizer' } });
    db.seed('payoutAccounts/u1', { holderName: 'Cong ty Bai Da' });
    db.seed('organizers/u2', { payoutAccountOk: true, businessVerified: true });
    const people = firestoreOrganizerPeople(db.asFirestore(), async (uid) => uid === 'admin1');
    assert.equal(await people.phoneVerified('u1'), true);
    assert.equal(await people.phoneVerified('u2'), false);
    assert.equal(await people.phoneVerified('nobody'), false);
    assert.equal(await people.businessVerified('u1'), true);
    assert.equal(await people.businessVerified('u2'), true);
    assert.equal(await people.businessVerified('nobody'), false);
    assert.equal(await people.payoutAccountOk('u1'), true);
    assert.equal(await people.payoutAccountOk('u2'), true);
    db.seed('payoutAccounts/u1', { holderName: 'Nguyen Van Khac' });
    assert.equal(await people.payoutAccountOk('u1'), false);
    assert.equal(await people.isStaff('admin1'), true);
    assert.equal(await people.isStaff('u1'), false);
  });
});

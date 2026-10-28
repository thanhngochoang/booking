import { beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { MAX_GATE_STAFF, MAX_RESIDENTS } from '../src/organizer.js';
import {
  becomeOrganizer,
  claimSpot,
  expireResidents,
  inviteGateStaff,
  removeGateStaff,
  removeResident,
  respondGateStaff,
  reviewSpotClaim,
  saveResident,
  setSpotAccess,
  suspendOrganizer,
  updateManagedSpot,
} from '../src/organizer_use_cases.js';
import { registerEvent } from '../src/event_registration.js';
import {
  ADMIN,
  HOUR,
  ORG_NOW,
  createOrganizerWorld,
  organizerOf,
  spotOf,
  withManager,
  type OrganizerWorld,
} from './support/organizer_world.js';
import { cu1, eventRecord, must, ph1, publishedEvent } from './support/event_world.js';

const rejects = (code: ErrorCode, field?: string) => (e: unknown) =>
  e instanceof DomainError && e.code === code && (field === undefined || e.field === field);

const PROOF = (n: number, uid = 'org1') => `spot_claims/${uid}/c1/proof${n}.pdf`;
const proofs = (count: number, uid = 'org1') => Array.from({ length: count }, (_, i) => PROOF(i + 1, uid));

const typesOf = (w: OrganizerWorld, uid: string) => w.notify.store.rowsOf(uid).map((r) => r.type);

describe('becomeOrganizer', () => {
  let w: OrganizerWorld;
  beforeEach(() => {
    w = createOrganizerWorld();
  });

  test('creates organizers/{uid} active with the name and bio; a second call updates name and bio', async () => {
    w.people.business.add('org1');
    const o = await becomeOrganizer(w.deps, 'org1', { name: ' Bãi đá sông Hồng ', bio: 'Vườn hoa ven sông', avatarUrl: null });
    assert.deepEqual(
      [o.id, o.name, o.bio, o.status, o.phoneVerified, o.businessVerified, o.payoutAccountOk, o.managedSpotIds],
      ['org1', 'Bãi đá sông Hồng', 'Vườn hoa ven sông', 'active', true, true, false, []],
    );
    assert.equal(o.createdAt, ORG_NOW.toISOString());
    assert.deepEqual(w.store.organizers.get('org1'), o);

    w.setNow(new Date(ORG_NOW.getTime() + HOUR));
    const again = await becomeOrganizer(w.deps, 'org1', { name: 'Bãi đá', bio: 'Mới' });
    assert.deepEqual([again.name, again.bio, again.createdAt], ['Bãi đá', 'Mới', ORG_NOW.toISOString()]);
    assert.equal(again.updatedAt, new Date(ORG_NOW.getTime() + HOUR).toISOString());
    assert.equal(w.store.organizers.size, 2); // org2 (seeded) and org1
  });

  test('without a verified phone it is phone_required', async () => {
    await assert.rejects(becomeOrganizer(w.deps, 'nophone', { name: 'Bãi đá', bio: '' }), rejects('phone_required'));
    assert.equal(w.store.organizers.has('nophone'), false);
  });

  test('a suspended organizer is conflict', async () => {
    w.store.seedOrganizer(organizerOf('org1', { status: 'suspended' }));
    await assert.rejects(becomeOrganizer(w.deps, 'org1', { name: 'Bãi đá', bio: '' }), rejects('conflict'));
  });

  test('name of 2 or 61 graphemes → invalid_argument name; bio 301 → bio', async () => {
    await assert.rejects(becomeOrganizer(w.deps, 'org1', { name: 'Bã', bio: '' }), rejects('invalid_argument', 'name'));
    await assert.rejects(becomeOrganizer(w.deps, 'org1', { name: 'a'.repeat(61), bio: '' }), rejects('invalid_argument', 'name'));
    await assert.rejects(becomeOrganizer(w.deps, 'org1', { name: 'Bãi đá', bio: 'a'.repeat(301) }), rejects('invalid_argument', 'bio'));
    // 60 graphemes with combining marks is still fine.
    await becomeOrganizer(w.deps, 'org1', { name: 'ố'.repeat(60), bio: 'a'.repeat(300) });
  });
});

describe('claimSpot', () => {
  let w: OrganizerWorld;
  beforeEach(() => {
    w = createOrganizerWorld();
    w.store.seedOrganizer(organizerOf('org1'));
  });

  test('on a free spot creates a pending claim with 1–3 proofs', async () => {
    const { claimId } = await claimSpot(w.deps, 'org1', { spotId: 's1', proofPaths: proofs(3), note: 'Hợp đồng thuê 2026' });
    const c = must(w.store.claims.get(claimId));
    assert.deepEqual(
      [c.spotId, c.proposal, c.organizerId, c.status, c.proofPaths, c.note, c.reason, c.createdAt, c.reviewedAt, c.reviewedBy],
      ['s1', null, 'org1', 'pending', proofs(3), 'Hợp đồng thuê 2026', null, ORG_NOW.toISOString(), null, null],
    );
    const one = await claimSpot(w.deps, 'org2', { spotId: 's1', proofPaths: proofs(1, 'org2') });
    assert.equal(must(w.store.claims.get(one.claimId)).note, '');
  });

  test('without proofs → invalid_argument proofPaths; 4 proofs → proofPaths', async () => {
    await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 's1', proofPaths: [] }), rejects('invalid_argument', 'proofPaths'));
    await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 's1' }), rejects('invalid_argument', 'proofPaths'));
    await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 's1', proofPaths: proofs(4) }), rejects('invalid_argument', 'proofPaths'));
  });

  test("a proof outside the claimant's own folder → proofPaths", async () => {
    for (const p of ['spot_claims/org2/c1/x.pdf', 'avatars/org1/x.jpg', 'spot_claims/org1/../org2/x.pdf']) {
      await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 's1', proofPaths: [p] }), rejects('invalid_argument', 'proofPaths'), p);
    }
  });

  test('on a managed spot is spot_managed; on an archived spot spot_archived; unknown spot not_found', async () => {
    await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 's2', proofPaths: proofs(1) }), rejects('spot_managed'));
    await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 's3', proofPaths: proofs(1) }), rejects('spot_archived'));
    await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 'nope', proofPaths: proofs(1) }), rejects('not_found'));
  });

  test('a second pending claim by the same organizer on the same spot is limit_exceeded; another organizer may also claim', async () => {
    await claimSpot(w.deps, 'org1', { spotId: 's1', proofPaths: proofs(1) });
    await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 's1', proofPaths: proofs(1) }), rejects('limit_exceeded'));
    await claimSpot(w.deps, 'org2', { spotId: 's1', proofPaths: proofs(1, 'org2') });
    assert.equal([...w.store.claims.values()].filter((c) => c.spotId === 's1' && c.status === 'pending').length, 2);
  });

  test('a proposal (spotId null) needs name and address', async () => {
    await assert.rejects(
      claimSpot(w.deps, 'org1', { spotId: null, proposal: { name: 'Vườn hoa', address: '' }, proofPaths: proofs(1) }),
      rejects('invalid_argument', 'proposal'),
    );
    await assert.rejects(
      claimSpot(w.deps, 'org1', { proposal: { name: '', address: '1 Âu Cơ' }, proofPaths: proofs(1) }),
      rejects('invalid_argument', 'proposal'),
    );
    await assert.rejects(claimSpot(w.deps, 'org1', { proofPaths: proofs(1) }), rejects('invalid_argument', 'proposal'));
    const { claimId } = await claimSpot(w.deps, 'org1', {
      spotId: null, proposal: { name: ' Vườn hoa Nhật Tân ', address: ' Phú Thượng, Tây Hồ ' }, proofPaths: proofs(2),
    });
    const c = must(w.store.claims.get(claimId));
    assert.deepEqual([c.spotId, c.proposal], [null, { name: 'Vườn hoa Nhật Tân', address: 'Phú Thượng, Tây Hồ' }]);
  });

  test('a non-organizer is permission_denied; so is a suspended one', async () => {
    await assert.rejects(claimSpot(w.deps, 'cust', { spotId: 's1', proofPaths: proofs(1, 'cust') }), rejects('permission_denied'));
    w.store.seedOrganizer(organizerOf('org1', { status: 'suspended' }));
    await assert.rejects(claimSpot(w.deps, 'org1', { spotId: 's1', proofPaths: proofs(1) }), rejects('permission_denied'));
  });
});

describe('reviewSpotClaim', () => {
  let w: OrganizerWorld;
  let mine: string;
  let theirs: string;
  beforeEach(async () => {
    w = createOrganizerWorld();
    w.store.seedOrganizer(organizerOf('org1'));
    w.store.seedOrganizer(organizerOf('org3'));
    mine = (await claimSpot(w.deps, 'org1', { spotId: 's1', proofPaths: proofs(1) })).claimId;
    theirs = (await claimSpot(w.deps, 'org3', { spotId: 's1', proofPaths: proofs(1, 'org3') })).claimId;
  });

  test("approve by staff: claim approved, spot.managedBy = organizer, organizer.managedSpotIds contains the spot, other pending claims on that spot rejected with reason 'spot_managed', notification spot_claim_approved", async () => {
    const out = await reviewSpotClaim(w.deps, ADMIN, { claimId: mine, approve: true });
    assert.deepEqual([out.status, out.reviewedBy, out.reviewedAt], ['approved', ADMIN, ORG_NOW.toISOString()]);
    assert.equal(must(w.store.claims.get(mine)).status, 'approved');
    const spot = must(w.store.spots.get('s1'));
    assert.deepEqual([spot.managedBy, spot.updatedBy], ['org1', ADMIN]);
    assert.deepEqual(must(w.store.organizers.get('org1')).managedSpotIds, ['s1']);
    const other = must(w.store.claims.get(theirs));
    assert.deepEqual([other.status, other.reason, other.reviewedBy], ['rejected', 'spot_managed', ADMIN]);
    const row = w.notify.store.rowsOf('org1')[0];
    assert.deepEqual([row?.type, row?.target], ['spot_claim_approved', '/organizer/spots/s1']);
    assert.deepEqual(typesOf(w, 'org3'), ['spot_claim_rejected']);
  });

  test('approving when the spot got a manager meanwhile is spot_managed and writes nothing', async () => {
    w.store.seedSpot(spotOf('s1', { managedBy: 'org9' }));
    const writes = w.store.writes;
    await assert.rejects(reviewSpotClaim(w.deps, ADMIN, { claimId: mine, approve: true }), rejects('spot_managed'));
    assert.equal(w.store.writes, writes);
    assert.equal(must(w.store.claims.get(mine)).status, 'pending');
    assert.equal(must(w.store.claims.get(theirs)).status, 'pending');
    assert.deepEqual(must(w.store.organizers.get('org1')).managedSpotIds, []);
    assert.equal(w.notify.store.rows.size, 0);
  });

  test('two approvals of one spot at once: the first wins, the second finds its claim rejected and writes nothing (Review Focus 5)', async () => {
    // Two staff approve the two claims of s1 at once; the transactions run one after the other.
    const [a, b] = await Promise.allSettled([
      reviewSpotClaim(w.deps, ADMIN, { claimId: mine, approve: true }),
      reviewSpotClaim(w.deps, ADMIN, { claimId: theirs, approve: true }),
    ]);
    assert.equal(a.status, 'fulfilled');
    assert.equal(b.status === 'rejected' && rejects('not_found')(b.reason), true);
    assert.equal(must(w.store.spots.get('s1')).managedBy, 'org1');
    assert.deepEqual(must(w.store.organizers.get('org3')).managedSpotIds, []);
    assert.deepEqual([must(w.store.claims.get(theirs)).status, must(w.store.claims.get(theirs)).reason], ['rejected', 'spot_managed']);
  });

  test('reject records the reason and notifies spot_claim_rejected', async () => {
    const out = await reviewSpotClaim(w.deps, ADMIN, { claimId: mine, approve: false, reason: 'Thiếu hợp đồng thuê' });
    assert.deepEqual([out.status, out.reason, out.reviewedBy], ['rejected', 'Thiếu hợp đồng thuê', ADMIN]);
    assert.equal(must(w.store.spots.get('s1')).managedBy, null);
    assert.equal(must(w.store.claims.get(theirs)).status, 'pending');
    const row = w.notify.store.rowsOf('org1')[0];
    assert.deepEqual([row?.type, row?.target], ['spot_claim_rejected', '/organizer/spots/claim']);
    assert.match(row?.body ?? '', /Thiếu hợp đồng thuê/);
  });

  test('a reviewed claim cannot be reviewed again (not_found)', async () => {
    await reviewSpotClaim(w.deps, ADMIN, { claimId: mine, approve: false, reason: 'x' });
    await assert.rejects(reviewSpotClaim(w.deps, ADMIN, { claimId: mine, approve: true }), rejects('not_found'));
  });

  test('a proposal is approved only once staff set its spotId', async () => {
    const { claimId } = await claimSpot(w.deps, 'org1', { proposal: { name: 'Vườn mới', address: 'Tây Hồ' }, proofPaths: proofs(1) });
    await assert.rejects(reviewSpotClaim(w.deps, ADMIN, { claimId, approve: true }), rejects('invalid_argument', 'spotId'));
  });

  test('a non-staff actor is permission_denied', async () => {
    await assert.rejects(reviewSpotClaim(w.deps, 'org1', { claimId: mine, approve: true }), rejects('permission_denied'));
  });
});

describe('updateManagedSpot', () => {
  let w: OrganizerWorld;
  beforeEach(() => {
    w = createOrganizerWorld();
    withManager(w);
  });

  test('by the manager updates description, tips, openHours, access (source organizer, updatedAt now)', async () => {
    const s = await updateManagedSpot(w.deps, 'org1', {
      spotId: 's1',
      description: 'Vườn hoa ven sông Hồng',
      tips: ['Đi sáng sớm'],
      openHours: { start: '07:00', end: '18:00' },
      access: { type: 'ticket', fees: [{ label: 'Người lớn', amountVnd: 70_000 }], note: 'Gửi xe 5.000₫' },
    });
    assert.deepEqual([s.description, s.tips, s.openHours], ['Vườn hoa ven sông Hồng', ['Đi sáng sớm'], { start: '07:00', end: '18:00' }]);
    assert.deepEqual(s.access, {
      type: 'ticket', fees: [{ label: 'Người lớn', amountVnd: 70_000 }], note: 'Gửi xe 5.000₫',
      updatedAt: ORG_NOW.toISOString(), source: 'organizer',
    });
    assert.deepEqual([s.updatedAt, s.updatedBy, s.name], [ORG_NOW.toISOString(), 'org1', 'Điểm s1']);
    assert.deepEqual(w.store.spots.get('s1'), s);
  });

  test('only the given fields change', async () => {
    await updateManagedSpot(w.deps, 'org1', { spotId: 's1', description: 'Một', tips: ['Mẹo'] });
    const s = await updateManagedSpot(w.deps, 'org1', { spotId: 's1', openHours: { start: '06:00', end: '17:30' } });
    assert.deepEqual([s.description, s.tips, s.access], ['Một', ['Mẹo'], null]);
  });

  test('name/point/radius/season in the input are invalid_argument', async () => {
    for (const [k, v] of [['name', 'Tên mới'], ['point', { lat: 1, lng: 1 }], ['radiusM', 900], ['seasonMonths', [1]]] as const) {
      await assert.rejects(updateManagedSpot(w.deps, 'org1', { spotId: 's1', [k]: v }), rejects('invalid_argument', k), k);
    }
  });

  test('openHours closing before opening → openHours; a cover outside the spot folder → cover', async () => {
    await assert.rejects(
      updateManagedSpot(w.deps, 'org1', { spotId: 's1', openHours: { start: '18:00', end: '07:00' } }),
      rejects('invalid_argument', 'openHours'),
    );
    await assert.rejects(
      updateManagedSpot(w.deps, 'org1', { spotId: 's1', cover: { url: 'https://x/a.jpg', cardUrl: 'https://x/b.jpg', path: 'spots/s2/a.jpg' } }),
      rejects('invalid_argument', 'cover'),
    );
    const s = await updateManagedSpot(w.deps, 'org1', {
      spotId: 's1', cover: { url: 'https://x/a.jpg', cardUrl: 'https://x/b.jpg', path: 'spots/s1/a.jpg' },
    });
    assert.equal(s.cover?.path, 'spots/s1/a.jpg');
  });

  test('by a stranger is not_spot_manager', async () => {
    await assert.rejects(updateManagedSpot(w.deps, 'org2', { spotId: 's1', description: 'x' }), rejects('not_spot_manager'));
    await assert.rejects(updateManagedSpot(w.deps, 'cust', { spotId: 's1', description: 'x' }), rejects('not_spot_manager'));
  });

  test('an archived spot is spot_archived', async () => {
    await assert.rejects(updateManagedSpot(w.deps, 'org1', { spotId: 's3', description: 'x' }), rejects('spot_archived'));
  });
});

describe('residents', () => {
  let w: OrganizerWorld;
  beforeEach(() => {
    w = createOrganizerWorld();
    withManager(w);
  });

  const add = (providerId: string, over: Record<string, unknown> = {}) =>
    saveResident(w.deps, 'org1', { spotId: 's1', providerId, waivesProvider: true, waivesGuests: true, maxGuests: 3, ...over });

  test('saveResident adds p1 with both waivers and maxGuests 3', async () => {
    const r = await add('p1', { validUntil: '2026-12-31' });
    assert.deepEqual(r, {
      providerId: 'p1', waivesProvider: true, waivesGuests: true, maxGuests: 3, validUntil: '2026-12-31',
      addedAt: ORG_NOW.toISOString(), addedBy: 'org1',
    });
    assert.deepEqual(w.store.residentsOfSync('s1'), [r]);
  });

  test('p2 (not accepting orders) is not_accepting_orders; a customer is not_found', async () => {
    await assert.rejects(add('p2'), rejects('not_accepting_orders'));
    await assert.rejects(add('cust'), rejects('not_found'));
  });

  test('maxGuests 0 or a past validUntil → invalid_argument', async () => {
    await assert.rejects(add('p1', { maxGuests: 0 }), rejects('invalid_argument', 'maxGuests'));
    await assert.rejects(add('p1', { validUntil: '2026-10-17' }), rejects('invalid_argument', 'validUntil'));
    await assert.rejects(add('p1', { validUntil: '18/10/2026' }), rejects('invalid_argument', 'validUntil'));
  });

  test('blocked provider ↔ organizer is blocked', async () => {
    w.blocks.block('p1', 'org1');
    await assert.rejects(add('p1'), rejects('blocked'));
  });

  test(`the ${MAX_RESIDENTS + 1}st is limit_exceeded`, async () => {
    for (let i = 1; i <= MAX_RESIDENTS; i += 1) await add(`q${i}`);
    await assert.rejects(add('p1'), rejects('limit_exceeded'));
    // Editing someone already on the list is not an add.
    await add('q1', { maxGuests: 5 });
  });

  test('notification spot_resident_added once per add', async () => {
    await add('p1');
    await add('p1', { maxGuests: 4 });
    assert.deepEqual(typesOf(w, 'p1'), ['spot_resident_added']);
    assert.equal(w.notify.store.rowsOf('p1')[0]?.target, '/spots/s1');
    await removeResident(w.deps, 'org1', { spotId: 's1', providerId: 'p1' });
    w.setNow(new Date(ORG_NOW.getTime() + HOUR));
    await add('p1');
    assert.deepEqual(typesOf(w, 'p1'), ['spot_resident_added', 'spot_resident_added']);
  });

  test('saveResident on a spot one does not manage is not_spot_manager', async () => {
    await assert.rejects(
      saveResident(w.deps, 'org2', { spotId: 's1', providerId: 'p1', waivesProvider: true, waivesGuests: false }),
      rejects('not_spot_manager'),
    );
  });

  test('removeResident by the manager or by the provider themself works; by a stranger is not_spot_manager', async () => {
    await add('p1');
    await add('q1');
    await removeResident(w.deps, 'org1', { spotId: 's1', providerId: 'p1' });
    await removeResident(w.deps, 'q1', { spotId: 's1', providerId: 'q1' });
    assert.deepEqual(w.store.residentsOfSync('s1'), []);
    await add('p1');
    await assert.rejects(removeResident(w.deps, 'org2', { spotId: 's1', providerId: 'p1' }), rejects('not_spot_manager'));
    await assert.rejects(removeResident(w.deps, 'q1', { spotId: 's1', providerId: 'p1' }), rejects('not_spot_manager'));
  });

  test('expireResidents deletes residents with validUntil before today and returns the count', async () => {
    await add('p1', { validUntil: '2026-10-20' });
    await add('q1', { validUntil: '2026-10-18' });
    await add('q2');
    await add('q3', { validUntil: '2026-10-19' });
    const n = await expireResidents(w.deps, '2026-10-20');
    assert.equal(n, 2);
    assert.deepEqual(w.store.residentsOfSync('s1').map((r) => r.providerId).sort(), ['p1', 'q2']);
    assert.equal(await expireResidents(w.deps, '2026-10-20'), 0);
  });
});

describe('gate staff', () => {
  let w: OrganizerWorld;
  beforeEach(() => {
    w = createOrganizerWorld();
    w.store.seedOrganizer(organizerOf('org1'));
  });

  const staffOf = (uid: string) => w.store.gateStaffOfSync('org1').find((g) => g.staffUid === uid);

  test('inviteGateStaff by phone and by @username resolves through lookup', async () => {
    const a = await inviteGateStaff(w.deps, 'org1', { target: '0912 000 001' });
    const b = await inviteGateStaff(w.deps, 'org1', { target: '@gac2' });
    assert.deepEqual([a.staffUid, a.status, a.invitedAt, a.respondedAt], ['g1', 'invited', ORG_NOW.toISOString(), null]);
    assert.equal(b.staffUid, 'g2');
    assert.deepEqual(w.people.lookups, ['0912 000 001', '@gac2']);
    const row = w.notify.store.rowsOf('g1')[0];
    assert.deepEqual([row?.type, row?.target, row?.title], ['gate_staff_invited', '/organizer/gate-staff', 'Tổ chức org1 mời bạn soát vé']);
  });

  test('unknown target not_found; an empty target invalid_argument; a non-organizer permission_denied', async () => {
    await assert.rejects(inviteGateStaff(w.deps, 'org1', { target: '@nobody' }), rejects('not_found'));
    await assert.rejects(inviteGateStaff(w.deps, 'org1', { target: ' ' }), rejects('invalid_argument', 'target'));
    await assert.rejects(inviteGateStaff(w.deps, 'cust', { target: '@gac1' }), rejects('permission_denied'));
  });

  test(`the ${MAX_GATE_STAFF + 1}th invite limit_exceeded`, async () => {
    for (let i = 1; i <= MAX_GATE_STAFF; i += 1) await inviteGateStaff(w.deps, 'org1', { target: `@gac${i}` });
    await assert.rejects(inviteGateStaff(w.deps, 'org1', { target: '@gac11' }), rejects('limit_exceeded'));
    // A removed staff frees the seat.
    await removeGateStaff(w.deps, 'org1', { staffUid: 'g3' });
    await inviteGateStaff(w.deps, 'org1', { target: '@gac11' });
  });

  test('inviting an active staff is a no-op', async () => {
    await inviteGateStaff(w.deps, 'org1', { target: '@gac1' });
    await respondGateStaff(w.deps, 'g1', { organizerId: 'org1', accept: true });
    const before = staffOf('g1');
    w.setNow(new Date(ORG_NOW.getTime() + HOUR));
    const again = await inviteGateStaff(w.deps, 'org1', { target: '@gac1' });
    assert.deepEqual(again, before);
    assert.deepEqual(staffOf('g1'), before);
    assert.equal(w.notify.store.rowsOf('g1').length, 1);
  });

  test('respondGateStaff accept within 72 h → active', async () => {
    await inviteGateStaff(w.deps, 'org1', { target: '@gac1' });
    w.setNow(new Date(ORG_NOW.getTime() + 71 * HOUR));
    const g = await respondGateStaff(w.deps, 'g1', { organizerId: 'org1', accept: true });
    assert.deepEqual([g.status, g.respondedAt], ['active', new Date(ORG_NOW.getTime() + 71 * HOUR).toISOString()]);
    assert.deepEqual(staffOf('g1'), g);
  });

  test('after 72 h deadline_passed', async () => {
    await inviteGateStaff(w.deps, 'org1', { target: '@gac1' });
    w.setNow(new Date(ORG_NOW.getTime() + 73 * HOUR));
    await assert.rejects(respondGateStaff(w.deps, 'g1', { organizerId: 'org1', accept: true }), rejects('deadline_passed'));
    assert.equal(staffOf('g1')?.status, 'invited');
    // An expired invite can be sent again and no longer counts towards the cap.
    const again = await inviteGateStaff(w.deps, 'org1', { target: '@gac1' });
    assert.equal(again.invitedAt, new Date(ORG_NOW.getTime() + 73 * HOUR).toISOString());
  });

  test('decline → removed; responding without an invite is not_found', async () => {
    await inviteGateStaff(w.deps, 'org1', { target: '@gac1' });
    const g = await respondGateStaff(w.deps, 'g1', { organizerId: 'org1', accept: false });
    assert.equal(g.status, 'removed');
    await assert.rejects(respondGateStaff(w.deps, 'g1', { organizerId: 'org1', accept: true }), rejects('not_found'));
    await assert.rejects(respondGateStaff(w.deps, 'g2', { organizerId: 'org1', accept: true }), rejects('not_found'));
  });

  test('removeGateStaff → removed', async () => {
    await inviteGateStaff(w.deps, 'org1', { target: '@gac1' });
    await respondGateStaff(w.deps, 'g1', { organizerId: 'org1', accept: true });
    await removeGateStaff(w.deps, 'org1', { staffUid: 'g1' });
    assert.equal(staffOf('g1')?.status, 'removed');
    await assert.rejects(removeGateStaff(w.deps, 'org1', { staffUid: 'g9' }), rejects('not_found'));
  });
});

describe('staff tools', () => {
  let w: OrganizerWorld;
  beforeEach(() => {
    w = createOrganizerWorld();
  });

  test('setSpotAccess by staff writes access with source staff', async () => {
    const s = await setSpotAccess(w.deps, ADMIN, {
      spotId: 's1', access: { type: 'ticket', fees: [{ label: 'Người lớn', amountVnd: 70_000 }], note: '' },
    });
    assert.deepEqual(s.access, {
      type: 'ticket', fees: [{ label: 'Người lớn', amountVnd: 70_000 }], note: '', updatedAt: ORG_NOW.toISOString(), source: 'staff',
    });
    assert.deepEqual([s.updatedBy, w.store.spots.get('s1')?.access?.source], [ADMIN, 'staff']);
    await assert.rejects(setSpotAccess(w.deps, 'org2', { spotId: 's2', access: { type: 'open', fees: [] } }), rejects('permission_denied'));
    await assert.rejects(setSpotAccess(w.deps, ADMIN, { spotId: 'nope', access: { type: 'open', fees: [] } }), rejects('not_found'));
  });

  test('suspendOrganizer cancels every open event with refunds (count returned) and sets status suspended', async () => {
    w.store.seedOrganizer(organizerOf('org1'));
    const ev = w.events.store;
    // A priced event with one paid ticket, hosted by org1 (built through the photographer flow, then re-hosted).
    const id = await publishedEvent(w.events, {
      price: 150_000, startAt: '2026-10-25T02:00:00.000Z', endAt: '2026-10-25T05:00:00.000Z',
    }, ph1);
    const r = await registerEvent(w.events.deps, cu1, { eventId: id, quantity: 1, name: 'Nguyễn An', method: 'momo' });
    await w.events.payTicket(must(r.paymentId), 'exact', cu1);
    const organizerHost = { type: 'organizer', id: 'org1', name: 'Tổ chức org1', avatarUrl: null, verified: false } as const;
    ev.events.set(id, { ...must(ev.events.get(id)), host: organizerHost });
    const later = { startAt: new Date('2026-10-26T02:00:00.000Z'), endAt: new Date('2026-10-26T05:00:00.000Z'), dayKey: '2026-10-26' };
    ev.seedEvent(eventRecord({ id: 'evFree', host: organizerHost, chatId: null, hashtagKey: '', ...later }));
    ev.seedEvent(eventRecord({ id: 'evDone', host: organizerHost, status: 'completed', hashtagKey: '' }));
    ev.seedEvent(eventRecord({ id: 'evPast', host: organizerHost, status: 'closed', hashtagKey: '' })); // ended 2026-10-04
    ev.seedEvent(eventRecord({ id: 'evPhoto', host: { ...organizerHost, type: 'photographer' }, hashtagKey: '', ...later }));

    const out = await suspendOrganizer(w.deps, ADMIN, { organizerId: 'org1' });
    assert.deepEqual(out, { cancelledEvents: 2 });
    assert.equal(must(w.store.organizers.get('org1')).status, 'suspended');
    assert.deepEqual(
      ['evFree', 'evDone', 'evPast', 'evPhoto'].map((x) => must(ev.events.get(x)).status),
      ['cancelled', 'completed', 'closed', 'open'],
    );
    assert.equal(must(ev.events.get(id)).status, 'cancelled');
    const reg = must(ev.registrations.get(`${id}/${r.registrationId}`));
    assert.deepEqual([reg.status, reg.refundPercent], ['refunded', 100]);
  });

  test('suspendOrganizer by a non-staff actor is permission_denied; an unknown organizer not_found', async () => {
    await assert.rejects(suspendOrganizer(w.deps, 'org1', { organizerId: 'org2' }), rejects('permission_denied'));
    await assert.rejects(suspendOrganizer(w.deps, ADMIN, { organizerId: 'nope' }), rejects('not_found'));
  });
});

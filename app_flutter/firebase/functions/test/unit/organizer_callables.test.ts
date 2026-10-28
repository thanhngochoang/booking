import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import type { OrganizerDeps } from '@photobooking/domain';
import {
  handleBecomeOrganizer,
  handleClaimSpot,
  handleInviteGateStaff,
  handleRemoveGateStaff,
  handleRemoveResident,
  handleRespondGateStaff,
  handleReviewSpotClaim,
  handleSaveResident,
  handleUpdateManagedSpot,
  spotCoverOf,
  type OrganizerCallableDeps,
} from '../../src/callables/organizer.js';

const ow = await import('../../../../../packages/domain/test/support/organizer_world.js');

const PREFIX = 'https://firebasestorage.googleapis.com/v0/b/demo.appspot.com/o/';
const as = (uid: string, data: unknown, staffRole?: string) => ({ auth: { uid, ...(staffRole ? { token: { staffRole } } : {}) }, data });

/** Every handler, called with valid-looking data, for the auth and transport checks. */
const HANDLERS: Array<[string, (req: { auth?: { uid: string }; data: unknown }, deps: OrganizerCallableDeps) => Promise<unknown>]> = [
  ['becomeOrganizer', handleBecomeOrganizer],
  ['claimSpot', handleClaimSpot],
  ['reviewSpotClaim', handleReviewSpotClaim],
  ['updateManagedSpot', handleUpdateManagedSpot],
  ['saveResident', handleSaveResident],
  ['removeResident', handleRemoveResident],
  ['inviteGateStaff', handleInviteGateStaff],
  ['respondGateStaff', handleRespondGateStaff],
  ['removeGateStaff', handleRemoveGateStaff],
];

async function refused(p: Promise<unknown>, transport: string, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => {
    assert.ok(e instanceof HttpsError, String(e));
    assert.equal(e.code, transport);
    assert.equal((e.details as { code?: string }).code, code);
    return true;
  });
}

describe('organizer callables', () => {
  let w: ReturnType<typeof ow.createOrganizerWorld>;
  let deps: OrganizerCallableDeps;

  beforeEach(() => {
    w = ow.createOrganizerWorld();
    deps = { ...(w.deps as OrganizerDeps), spotCoverPrefixes: [PREFIX] };
  });

  it('every handler is unauthenticated without auth', async () => {
    for (const [name, handle] of HANDLERS) {
      await assert.rejects(handle({ data: {} }, deps), (e: unknown) => {
        assert.ok(e instanceof HttpsError, name);
        assert.equal(e.code, 'unauthenticated', name);
        return true;
      });
    }
  });

  it('becomeOrganizer creates the caller\'s organizer; phone_required without a verified phone', async () => {
    const out = await handleBecomeOrganizer(as('org1', { name: 'Bãi đá sông Hồng', bio: 'Ven sông' }), deps);
    assert.equal(out.organizer.id, 'org1');
    assert.equal(w.store.organizers.get('org1')?.status, 'active');
    await refused(handleBecomeOrganizer(as('nophone', { name: 'Bãi đá sông Hồng', bio: '' }), deps), 'failed-precondition', 'phone_required');
    await refused(handleBecomeOrganizer(as('org1', { name: 'x' }), deps), 'invalid-argument', 'invalid_argument');
  });

  it('claimSpot passes the caller as the organizer and maps spot_managed and limit_exceeded', async () => {
    ow.withManager(w, 's9', 'org9');
    w.store.seedOrganizer(ow.organizerOf('org1'));
    const { claimId } = await handleClaimSpot(as('org1', { spotId: 's1', proofPaths: ['spot_claims/org1/c/hd.pdf'] }), deps);
    assert.equal(w.store.claims.get(claimId)?.organizerId, 'org1');
    await refused(handleClaimSpot(as('org1', { spotId: 's1', proofPaths: ['spot_claims/org1/c/hd2.pdf'] }), deps), 'resource-exhausted', 'limit_exceeded');
    await refused(handleClaimSpot(as('org1', { spotId: 's2', proofPaths: ['spot_claims/org1/c/hd.pdf'] }), deps), 'failed-precondition', 'spot_managed');
    // Another user's folder is not the caller's proof.
    await refused(handleClaimSpot(as('org1', { spotId: 's9', proofPaths: ['spot_claims/org2/c/hd.pdf'] }), deps), 'invalid-argument', 'invalid_argument');
  });

  it('reviewSpotClaim is refused for non-admins', async () => {
    w.store.seedOrganizer(ow.organizerOf('org1'));
    const { claimId } = await handleClaimSpot(as('org1', { spotId: 's1', proofPaths: ['spot_claims/org1/c/hd.pdf'] }), deps);
    // The staff decision is the caller's token claim, never a lookup of another uid.
    await refused(handleReviewSpotClaim(as(ow.ADMIN, { claimId, approve: true }), deps), 'permission-denied', 'permission_denied');
    await refused(handleReviewSpotClaim(as('org1', { claimId, approve: true }, 'sales'), deps), 'permission-denied', 'permission_denied');
    const out = await handleReviewSpotClaim(as('staff1', { claimId, approve: true }, 'admin'), deps);
    assert.equal(out.claim.status, 'approved');
    assert.equal(out.claim.reviewedBy, 'staff1');
    assert.equal(w.store.spots.get('s1')?.managedBy, 'org1');
  });

  it('updateManagedSpot converts the uploaded cover path; not_spot_manager for anyone else', async () => {
    ow.withManager(w);
    const path = 'spots/s1/01JCOVER.jpg';
    const url = `${PREFIX}${encodeURIComponent(path)}?alt=media&token=t`;
    assert.deepEqual(await handleUpdateManagedSpot(as('org1', { spotId: 's1', description: 'Bãi đá ven sông', coverPath: path, coverUrl: url }), deps), {});
    assert.deepEqual(w.store.spots.get('s1')?.cover, { url, cardUrl: url, path });
    assert.equal(w.store.spots.get('s1')?.description, 'Bãi đá ven sông');
    await refused(handleUpdateManagedSpot(as('org2', { spotId: 's1', description: 'x' }), deps), 'failed-precondition', 'not_spot_manager');
    await refused(handleUpdateManagedSpot(as('org1', { spotId: 's1', coverPath: path, coverUrl: 'https://evil.test/x.jpg' }), deps), 'invalid-argument', 'invalid_argument');
    await refused(handleUpdateManagedSpot(as('org1', { spotId: 's1', name: 'Đổi tên' }), deps), 'invalid-argument', 'invalid_argument');
  });

  it('spotCoverOf: the manager\'s own upload under spots/{spotId}/ only; null clears', () => {
    const path = 'spots/s1/a.jpg';
    const url = `${PREFIX}${encodeURIComponent(path)}?alt=media`;
    assert.deepEqual(spotCoverOf('s1', { coverPath: path, coverUrl: url }, [PREFIX]), { cover: { url, cardUrl: url, path } });
    assert.deepEqual(spotCoverOf('s1', { coverPath: null }, [PREFIX]), { cover: null });
    assert.deepEqual(spotCoverOf('s1', {}, [PREFIX]), {});
    assert.throws(() => spotCoverOf('s1', { coverPath: 'spots/s2/a.jpg', coverUrl: `${PREFIX}${encodeURIComponent('spots/s2/a.jpg')}` }, [PREFIX]), { code: 'invalid_argument' });
    assert.throws(() => spotCoverOf('s1', { coverPath: path, coverUrl: `${PREFIX}${encodeURIComponent('spots/s1/b.jpg')}` }, [PREFIX]), { code: 'invalid_argument' });
  });

  it('residents: saveResident and removeResident map not_accepting_orders, limit and the manager check', async () => {
    ow.withManager(w);
    assert.deepEqual(await handleSaveResident(as('org1', { spotId: 's1', providerId: 'p1', waivesProvider: true, waivesGuests: false }), deps), {});
    assert.equal(w.store.residents.get('s1')?.get('p1')?.addedBy, 'org1');
    await refused(handleSaveResident(as('org1', { spotId: 's1', providerId: 'p2', waivesProvider: true, waivesGuests: false }), deps), 'failed-precondition', 'not_accepting_orders');
    await refused(handleSaveResident(as('org2', { spotId: 's1', providerId: 'p1', waivesProvider: true, waivesGuests: false }), deps), 'failed-precondition', 'not_spot_manager');
    await refused(handleRemoveResident(as('org2', { spotId: 's1', providerId: 'p1' }), deps), 'failed-precondition', 'not_spot_manager');
    assert.deepEqual(await handleRemoveResident(as('p1', { spotId: 's1', providerId: 'p1' }), deps), {});
    assert.equal(w.store.residents.get('s1')?.get('p1'), undefined);
  });

  it('gate staff: invite, respond, remove; not_found and deadline_passed', async () => {
    ow.withManager(w);
    assert.deepEqual(await handleInviteGateStaff(as('org1', { target: '0912 0000 01' }), deps), {});
    assert.equal(w.store.gateStaff.get('org1')?.get('g1')?.status, 'invited');
    await refused(handleInviteGateStaff(as('org1', { target: '0999 999 999' }), deps), 'not-found', 'not_found');
    assert.deepEqual(await handleRespondGateStaff(as('g1', { organizerId: 'org1', accept: true }), deps), {});
    assert.equal(w.store.gateStaff.get('org1')?.get('g1')?.status, 'active');
    await handleInviteGateStaff(as('org1', { target: '@gac2' }), deps);
    w.setNow(new Date(ow.ORG_NOW.getTime() + 73 * ow.HOUR));
    await refused(handleRespondGateStaff(as('g2', { organizerId: 'org1', accept: true }), deps), 'failed-precondition', 'deadline_passed');
    assert.deepEqual(await handleRemoveGateStaff(as('org1', { staffUid: 'g1' }), deps), {});
    assert.equal(w.store.gateStaff.get('org1')?.get('g1')?.status, 'removed');
  });
});

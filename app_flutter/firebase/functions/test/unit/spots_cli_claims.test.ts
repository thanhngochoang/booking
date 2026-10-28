import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { MemorySpotCounter, MemorySpotRankStore, type SpotClaim, type SpotClaimStatus } from '@photobooking/domain';
import { HELP, parseStaffArgs, runCli, type SpotCliDeps, type SpotCliIo } from '../../tools/spots.js';

const ow = await import('../../../../../packages/domain/test/support/organizer_world.js');
const evw = await import('../../../../../packages/domain/test/support/event_world.js');

const NOW = '2026-10-18T03:00:00.000Z';
const claim = (over: Partial<SpotClaim>): SpotClaim => ({
  id: 'c1', spotId: 's1', proposal: null, organizerId: 'org1', status: 'pending', proofPaths: ['spot_claims/org1/c1/hd.pdf'],
  note: '', reason: null, createdAt: NOW, reviewedAt: null, reviewedBy: null, ...over,
});

describe('spots CLI: claims, access, organizers (S30)', () => {
  let w: ReturnType<typeof ow.createOrganizerWorld>;
  let out: string[];
  let deps: SpotCliDeps;
  const io: SpotCliIo = {
    print: (s) => void out.push(s),
    now: () => new Date(NOW),
    isAdmin: async (uid) => uid === ow.ADMIN,
  };

  beforeEach(() => {
    w = ow.createOrganizerWorld();
    out = [];
    w.store.seedOrganizer(ow.organizerOf('org1'));
    w.store.seedClaim(claim({}));
    w.store.seedClaim(claim({ id: 'c2', spotId: null, proposal: { name: 'Bãi đá mới', address: 'Long Biên, Hà Nội' }, organizerId: 'org2' }));
    w.store.seedClaim(claim({ id: 'c3', status: 'rejected', reason: 'Thiếu giấy tờ' }));
    deps = {
      spots: new MemorySpotRankStore() as never,
      counter: new MemorySpotCounter(),
      clock: { now: () => new Date(NOW) },
      ids: { newId: () => 'id1' },
      staff: { isAdmin: io.isAdmin },
      staffTools: {
        organizer: w.deps,
        claims: {
          list: async (status: SpotClaimStatus) => [...w.store.claims.values()].filter((c) => c.status === status),
          setSpot: async (claimId: string, spotId: string) => {
            const c = w.store.claims.get(claimId);
            if (c === undefined || c.spotId !== null) return null;
            const next = { ...c, spotId };
            w.store.claims.set(claimId, next);
            return next;
          },
        },
      },
    };
  });

  it('claims list prints pending claims', async () => {
    await runCli(['claims', 'list'], deps, io);
    assert.equal(out.length, 2);
    assert.match(out[0] ?? '', /^c1 {2}spot s1 {2}organizer org1 {2}2026-10-18T03:00:00.000Z {2}proofs: spot_claims\/org1\/c1\/hd.pdf$/);
    assert.match(out[1] ?? '', /^c2 {2}proposal "Bãi đá mới" \(Long Biên, Hà Nội\) {2}organizer org2/);
    out = [];
    await runCli(['claims', 'list', '--status', 'rejected'], deps, io);
    assert.deepEqual(out.map((l) => l.split('  ')[0]), ['c3']);
    // Listing needs no actor; an unknown status is refused.
    await assert.rejects(runCli(['claims', 'list', '--status', 'done'], deps, io), /status/);
  });

  it('approve calls reviewSpotClaim with the actor', async () => {
    await runCli(['claims', 'approve', 'c1', '--actor', ow.ADMIN], deps, io);
    const c = w.store.claims.get('c1');
    assert.deepEqual([c?.status, c?.reviewedBy], ['approved', ow.ADMIN]);
    assert.equal(w.store.spots.get('s1')?.managedBy, 'org1');
    assert.deepEqual(out, ['Claim c1 approved: spot s1 is managed by org1']);
    await assert.rejects(runCli(['claims', 'approve', 'c1'], deps, io), /--actor/);
    await assert.rejects(runCli(['claims', 'approve', 'c2', '--actor', 'org1'], deps, io), /admin/);
  });

  it('a proposal is approved with the spot staff added for it (--spot)', async () => {
    w.store.seedOrganizer(ow.organizerOf('org2'));
    w.store.seedSpot(ow.spotOf('s9'));
    await assert.rejects(runCli(['claims', 'approve', 'c2', '--actor', ow.ADMIN], deps, io), /invalid_argument/);
    await runCli(['claims', 'approve', 'c2', '--spot', 's9', '--actor', ow.ADMIN], deps, io);
    assert.equal(w.store.spots.get('s9')?.managedBy, 'org2');
    assert.equal(w.store.claims.get('c2')?.status, 'approved');
  });

  it('reject needs --reason', async () => {
    assert.throws(() => parseStaffArgs(['claims', 'reject', 'c1', '--actor', ow.ADMIN]), /--reason/);
    await runCli(['claims', 'reject', 'c1', '--reason', 'Giấy tờ không khớp tên', '--actor', ow.ADMIN], deps, io);
    const c = w.store.claims.get('c1');
    assert.deepEqual([c?.status, c?.reason, c?.reviewedBy], ['rejected', 'Giấy tờ không khớp tên', ow.ADMIN]);
    assert.equal(w.store.spots.get('s1')?.managedBy, null);
    assert.deepEqual(out, ['Claim c1 rejected: Giấy tờ không khớp tên']);
  });

  it('access parses --fee "Người lớn=70000" twice', async () => {
    const args = parseStaffArgs(['access', 's1', '--type', 'ticket', '--fee', 'Người lớn=70000', '--fee', 'Trẻ em = 40.000', '--note', 'Trẻ dưới 1 m miễn vé', '--actor', ow.ADMIN]);
    assert.deepEqual(args.access, {
      type: 'ticket',
      fees: [{ label: 'Người lớn', amountVnd: 70_000 }, { label: 'Trẻ em', amountVnd: 40_000 }],
      note: 'Trẻ dưới 1 m miễn vé',
    });
    await runCli(['access', 's1', '--type', 'ticket', '--fee', 'Người lớn=70000', '--fee', 'Trẻ em=40000', '--actor', ow.ADMIN], deps, io);
    const access = w.store.spots.get('s1')?.access;
    assert.deepEqual([access?.type, access?.source, access?.fees.map((f) => f.amountVnd)], ['ticket', 'staff', [70_000, 40_000]]);
    assert.deepEqual(out, ['Spot s1 access: ticket · Người lớn 70000, Trẻ em 40000']);
    assert.throws(() => parseStaffArgs(['access', 's1', '--type', 'ticket', '--fee', 'Người lớn', '--actor', ow.ADMIN]), /--fee/);
    assert.throws(() => parseStaffArgs(['access', 's1', '--type', 'free', '--actor', ow.ADMIN]), /--type/);
    // --type none clears the block.
    await runCli(['access', 's1', '--type', 'none', '--actor', ow.ADMIN], deps, io);
    assert.equal(w.store.spots.get('s1')?.access, null);
  });

  it('organizers suspend cancels the open events with refunds and prints failures', async () => {
    ow.withManager(w);
    w.events.store.seedEvent(evw.eventRecord({
      id: 'en1', type: 'entry', host: { type: 'organizer', id: 'org1', name: 'Tổ chức org1', avatarUrl: null, verified: true },
      createdBy: 'org1', startAt: new Date('2026-10-20T00:00:00.000Z'), endAt: new Date('2026-12-31T00:00:00.000Z'),
    }));
    await runCli(['organizers', 'suspend', 'org1', '--actor', ow.ADMIN], deps, io);
    assert.equal(w.store.organizers.get('org1')?.status, 'suspended');
    assert.equal(w.events.store.events.get('en1')?.status, 'cancelled');
    assert.deepEqual(out, ['Organizer org1 suspended: 1 open event(s) cancelled']);

    // A failing cancel is printed and fails the run (the suspension stands; run it again).
    w.store.seedOrganizer(ow.organizerOf('org3'));
    w.events.store.seedEvent(evw.eventRecord({
      id: 'en3', host: { type: 'organizer', id: 'org3', name: 'org3', avatarUrl: null, verified: true }, createdBy: 'org3',
      startAt: new Date('2026-10-20T00:00:00.000Z'), endAt: new Date('2026-10-20T03:00:00.000Z'),
    }));
    w.events.store.failNext = { error: new Error('down'), times: 50 };
    out = [];
    await assert.rejects(runCli(['organizers', 'suspend', 'org3', '--actor', ow.ADMIN], deps, io), /1 event/);
    w.events.store.failNext = null;
    assert.ok(out.some((l) => l.startsWith('cancel failed: en3')), out.join('\n'));
  });

  it('organizers sync recomputes the selling flags', async () => {
    w.people.business.add('org1');
    w.people.payout.add('org1');
    await runCli(['organizers', 'sync', 'org1', '--actor', ow.ADMIN], deps, io);
    const o = w.store.organizers.get('org1');
    assert.deepEqual([o?.businessVerified, o?.payoutAccountOk], [true, true]);
    assert.deepEqual(out, ['Organizer org1: businessVerified true, payoutAccountOk true']);
  });

  it('the help lists the S30 commands', () => {
    for (const line of ['claims list', 'claims approve', 'claims reject', 'access <spotId>', 'organizers suspend']) assert.ok(HELP.includes(line), line);
  });
});

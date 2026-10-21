import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { createJobWorld } from './support/job_world.js';
import {
  closeJob,
  createJob,
  extendJob,
  inviteToJob,
  updateJob,
} from '../src/job_use_cases.js';
import { DomainError } from '../src/errors.js';

describe('job use cases', () => {
  const validRaw = {
    specialtyId: 'portrait',
    title: 'Kỷ yếu lớp 12A1, 42 bạn',
    description: 'Chụp kỷ yếu tại trường',
    references: [{ url: 'https://storage/jobRefs/cust_lan/d1/1.jpg', path: 'jobRefs/cust_lan/d1/1.jpg' }],
    schedule: { kind: 'fixed', day: '2026-10-20', start: '07:00', end: '11:00' },
    area: { areaId: 'q1', name: 'Quận 1, TP.HCM', lat: 10.7769, lng: 106.7009 },
    budget: { min: 3000000, max: 5000000 },
    wants: { editedCount: 40, deliveryDays: 7 },
    allowedProviders: 'all',
    deadlineDays: 3,
  };

  it('only customers create jobs (photographer -> permission_denied)', async () => {
    const world = createJobWorld();
    await assert.rejects(
      () => createJob(world.deps, 'p_tu', validRaw),
      (e: any) => e instanceof DomainError && e.code === 'permission_denied',
    );
  });

  it('phone_required without a valid phone', async () => {
    const world = createJobWorld();
    world.people.customers.set('cust_no_phone', {
      role: 'customer',
      name: 'No Phone',
      avatarUrl: null,
      phoneVerified: false,
      hireCount: 0,
    });
    await assert.rejects(
      () => createJob(world.deps, 'cust_no_phone', validRaw),
      (e: any) => e instanceof DomainError && e.code === 'phone_required',
    );
  });

  it('a fourth open job is limit_exceeded', async () => {
    const world = createJobWorld();
    await createJob(world.deps, 'cust_lan', validRaw);
    await createJob(world.deps, 'cust_lan', validRaw);
    await createJob(world.deps, 'cust_lan', validRaw);

    await assert.rejects(
      () => createJob(world.deps, 'cust_lan', validRaw),
      (e: any) => e instanceof DomainError && e.code === 'limit_exceeded',
    );
  });

  it('creates an open job with counters at zero and the customer snapshot without phone', async () => {
    const world = createJobWorld();
    const res = await createJob(world.deps, 'cust_lan', validRaw);
    assert.ok(res.jobId);
    assert.ok(res.matched > 0);

    const saved = world.jobs.jobs.get(res.jobId)!;
    assert.equal(saved.status, 'open');
    assert.equal(saved.quoteCount, 0);
    assert.equal(saved.newQuoteCount, 0);
    assert.equal(saved.viewCount, 0);
    assert.equal(saved.inviteCount, 0);
    assert.equal(saved.matchCount, res.matched);
    assert.deepEqual(saved.customer, {
      name: 'Lan',
      avatarUrl: null,
      hireCount: 1,
      phoneVerified: true,
    });
    assert.equal((saved.customer as any).phone, undefined);
  });

  it('matches eligible providers only (closed provider, out of area, wrong type, the customer excluded)', async () => {
    const world = createJobWorld();
    const res = await createJob(world.deps, 'cust_lan', {
      ...validRaw,
      allowedProviders: 'artist', // only artist
    });

    const matches = Array.from(world.jobs.matches.get(res.jobId)?.values() ?? []);
    assert.equal(matches.length, 1);
    assert.equal(matches[0].photographerId, 'p_vu'); // Lê Hoàng Vũ is artist in TP.HCM
  });

  it('keeps at most 30 matches, best fit first', async () => {
    const world = createJobWorld();
    // Add 35 providers
    for (let i = 0; i < 35; i++) {
      world.people.providers.set(`p_extra_${i}`, {
        uid: `p_extra_${i}`,
        role: 'photographer',
        onboardingComplete: true,
        acceptingOrdersFields: { verified: true, onboardingComplete: true },
        providerType: 'individual',
        specialties: ['portrait'],
        serviceArea: { city: 'TP.HCM', radiusKm: 20, center: { lat: 10.7769, lng: 106.7009 } },
        startingPrice: 3000000 + i * 10000,
        tomatoPct: 90,
        score: 0.9,
        reviewCount: 10,
        completedCount: 20,
        approvedAwardCount: 0,
        verified: true,
        name: `Extra ${i}`,
        avatarUrl: null,
        studioDistrict: null,
      });
    }

    const res = await createJob(world.deps, 'cust_lan', validRaw);
    assert.equal(res.matched, 30);
    const matches = Array.from(world.jobs.matches.get(res.jobId)?.values() ?? []);
    assert.equal(matches.length, 30);
    for (let i = 0; i < matches.length - 1; i++) {
      assert.ok(matches[i].fit >= matches[i + 1].fit);
    }
  });

  it('specialty other matches nobody', async () => {
    const world = createJobWorld();
    const res = await createJob(world.deps, 'cust_lan', {
      ...validRaw,
      specialtyId: 'other',
    });
    assert.equal(res.matched, 0);
  });

  it('update is refused once a quote exists (conflict)', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    // simulate a quote
    const job = world.jobs.jobs.get(jobId)!;
    world.jobs.jobs.set(jobId, { ...job, quoteCount: 1 });

    await assert.rejects(
      () => updateJob(world.deps, 'cust_lan', { ...validRaw, jobId, title: 'Tiêu đề đã đổi mới' }),
      (e: any) => e instanceof DomainError && e.code === 'conflict',
    );
  });

  it('update re-validates and keeps matches', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);
    const initialMatches = world.jobs.matches.get(jobId);

    await updateJob(world.deps, 'cust_lan', {
      ...validRaw,
      jobId,
      title: 'Tiêu đề mới hợp lệ 123',
    });

    const updated = world.jobs.jobs.get(jobId)!;
    assert.equal(updated.title, 'Tiêu đề mới hợp lệ 123');
    assert.equal(world.jobs.matches.get(jobId), initialMatches);
  });

  it('update by another user is permission_denied', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    await assert.rejects(
      () => updateJob(world.deps, 'cust_other', { ...validRaw, jobId }),
      (e: any) => e instanceof DomainError && e.code === 'permission_denied',
    );
  });

  it('extend adds 7 days once', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', {
      ...validRaw,
      schedule: { kind: 'fixed', day: '2026-10-25', start: '07:00', end: '11:00' },
    });

    const jobBefore = world.jobs.jobs.get(jobId)!;
    const res = await extendJob(world.deps, 'cust_lan', { jobId });
    const expected = new Date(jobBefore.quoteDeadline.getTime() + 7 * 24 * 60 * 60 * 1000);
    assert.equal(res.quoteDeadline.toISOString(), expected.toISOString());

    const jobAfter = world.jobs.jobs.get(jobId)!;
    assert.equal(jobAfter.extended, true);
    assert.equal(jobAfter.expiringNotifiedAt, null);
  });

  it('extend twice is not_eligible', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', {
      ...validRaw,
      schedule: { kind: 'fixed', day: '2026-10-30', start: '07:00', end: '11:00' },
    });
    await extendJob(world.deps, 'cust_lan', { jobId });

    await assert.rejects(
      () => extendJob(world.deps, 'cust_lan', { jobId }),
      (e: any) => e instanceof DomainError && e.code === 'not_eligible',
    );
  });

  it('extend never reaches the shoot day', async () => {
    const world = createJobWorld();
    // deadline is 2026-10-08; shoot day is 2026-10-12. Adding 7 days gives 2026-10-15 >= 2026-10-12
    const { jobId } = await createJob(world.deps, 'cust_lan', {
      ...validRaw,
      schedule: { kind: 'fixed', day: '2026-10-12', start: '07:00', end: '11:00' },
    });

    await assert.rejects(
      () => extendJob(world.deps, 'cust_lan', { jobId }),
      (e: any) => e instanceof DomainError && e.code === 'not_eligible',
    );
  });

  it('close marks submitted quotes not_selected with reason closed and closes invites and matches', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    // Put a quote and invite
    await world.jobs.runTransaction(async (tx) => {
      tx.putQuote({
        id: 'p_tu',
        jobId,
        photographerId: 'p_tu',
        customerId: 'cust_lan',
        jobTitle: 'Title',
        photographer: {
          name: 'Tú',
          avatarUrl: null,
          providerType: 'individual',
          verified: true,
          tomatoPct: 90,
          score: 1.0,
          reviewCount: 5,
          completedCount: 10,
          approvedAwardCount: 0,
          studioDistrict: null,
        },
        basedOnServiceId: null,
        terms: {
          price: 3000000,
          durationMinutes: 240,
          photoCount: null,
          editedCount: 40,
          deliveryDays: 7,
          revisions: 1,
          milestones: [
            { kind: 'shoot', percent: 50 },
            { kind: 'delivery', percent: 50 },
          ],
        },
        milestoneAmounts: { shoot: 1500000, delivery: 1500000 },
        proposal: { day: '2026-10-20', start: '07:00', end: '11:00' },
        message: 'Báo giá của mình nha',
        albumId: null,
        album: null,
        invited: false,
        fit: 90,
        status: 'submitted',
        notSelectedReason: null,
        autoWithdrawn: false,
        declineReason: null,
        bookingId: null,
        withdrawnAt: null,
        version: 1,
        createdAt: world.clock.now(),
        updatedAt: world.clock.now(),
      });
      tx.putInvite({
        id: 'p_may',
        jobId,
        photographerId: 'p_may',
        customerId: 'cust_lan',
        fit: 85,
        jobStatus: 'open',
        createdAt: world.clock.now(),
        seenAt: null,
      });
    });

    await closeJob(world.deps, 'cust_lan', { jobId });

    const job = world.jobs.jobs.get(jobId)!;
    assert.equal(job.status, 'closed');
    assert.ok(job.closedAt);

    const quote = world.jobs.quotes.get(jobId)!.get('p_tu')!;
    assert.equal(quote.status, 'not_selected');
    assert.equal(quote.notSelectedReason, 'closed');

    const invite = world.jobs.invites.get(jobId)!.get('p_may')!;
    assert.equal(invite.jobStatus, 'closed');

    const matches = Array.from(world.jobs.matches.get(jobId)!.values());
    for (const m of matches) {
      assert.equal(m.jobStatus, 'closed');
    }
  });

  it('close during an active checkout is conflict', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    const job = world.jobs.jobs.get(jobId)!;
    world.jobs.jobs.set(jobId, {
      ...job,
      checkout: {
        quoteId: 'p_tu',
        bookingId: 'b1',
        expiresAt: new Date(world.clock.now().getTime() + 10 * 60 * 1000),
      },
    });

    await assert.rejects(
      () => closeJob(world.deps, 'cust_lan', { jobId }),
      (e: any) => e instanceof DomainError && e.code === 'conflict',
    );
  });

  it('invite refuses a closed provider with not_accepting_orders and writes nothing', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    await assert.rejects(
      () => inviteToJob(world.deps, 'cust_lan', { jobId, photographerIds: ['p_binh'] }),
      (e: any) => e instanceof DomainError && e.code === 'not_accepting_orders',
    );
    assert.equal(world.jobs.invites.get(jobId)?.size ?? 0, 0);
  });

  it('invite refuses a photographer blocked either way with blocked', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);
    world.blocks.block('cust_lan', 'p_tu');

    await assert.rejects(
      () => inviteToJob(world.deps, 'cust_lan', { jobId, photographerIds: ['p_tu'] }),
      (e: any) => e instanceof DomainError && e.code === 'blocked',
    );
  });

  it('matching skips a photographer blocked either way', async () => {
    const world = createJobWorld();
    world.blocks.block('cust_lan', 'p_tu');

    const res = await createJob(world.deps, 'cust_lan', validRaw);
    const matches = Array.from(world.jobs.matches.get(res.jobId)!.values());
    assert.equal(matches.some((m) => m.photographerId === 'p_tu'), false);
  });

  it('invite refuses an out-of-area provider with not_eligible', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    await assert.rejects(
      () => inviteToJob(world.deps, 'cust_lan', { jobId, photographerIds: ['p_ha'] }),
      (e: any) => e instanceof DomainError && e.code === 'not_eligible',
    );
  });

  it('invite skips people already invited or quoted', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    const first = await inviteToJob(world.deps, 'cust_lan', { jobId, photographerIds: ['p_tu'] });
    assert.deepEqual(first.invited, ['p_tu']);

    const second = await inviteToJob(world.deps, 'cust_lan', {
      jobId,
      photographerIds: ['p_tu', 'p_may'],
    });
    assert.deepEqual(second.invited, ['p_may']);

    const job = world.jobs.jobs.get(jobId)!;
    assert.equal(job.inviteCount, 2);
  });

  it('a sixth invitation is limit_exceeded', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    const job = world.jobs.jobs.get(jobId)!;
    world.jobs.jobs.set(jobId, { ...job, inviteCount: 5 });

    await assert.rejects(
      () => inviteToJob(world.deps, 'cust_lan', { jobId, photographerIds: ['p_tu'] }),
      (e: any) => e instanceof DomainError && e.code === 'limit_exceeded',
    );
  });

  it('invite after the deadline is deadline_passed', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    world.clock.set(new Date('2026-10-15T00:00:00.000Z')); // past deadline

    await assert.rejects(
      () => inviteToJob(world.deps, 'cust_lan', { jobId, photographerIds: ['p_tu'] }),
      (e: any) => e instanceof DomainError && e.code === 'deadline_passed',
    );
  });
});

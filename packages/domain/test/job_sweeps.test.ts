import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { createJobWorld } from './support/job_world.js';
import { createJob, extendJob } from '../src/job_use_cases.js';
import { runJobSweeps } from '../src/job_sweeps.js';

describe('job sweeps', () => {
  const validRaw = {
    specialtyId: 'portrait',
    title: 'Kỷ yếu lớp 12A1, 42 bạn',
    description: 'Chụp kỷ yếu tại trường',
    references: [
      { url: 'https://storage/jobRefs/cust_lan/d1/1.jpg', path: 'jobRefs/cust_lan/d1/1.jpg' },
      { url: 'https://storage/jobRefs/cust_lan/d1/2.jpg', path: 'jobRefs/cust_lan/d1/2.jpg' },
    ],
    schedule: { kind: 'fixed', day: '2026-10-20', start: '07:00', end: '11:00' },
    area: { areaId: 'q1', name: 'Quận 1, TP.HCM', lat: 10.7769, lng: 106.7009 },
    budget: { min: 3000000, max: 5000000 },
    wants: { editedCount: 40, deliveryDays: 7 },
    allowedProviders: 'all',
    deadlineDays: 3,
  };

  it('past deadline expires the job and marks quotes not_selected with reason expired', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    // simulate submitted quote
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
    });

    world.clock.set(new Date('2026-10-09T00:00:00.000Z')); // past deadline
    const res = await runJobSweeps(world.deps, world.notifyDeps);
    assert.equal(res.expired, 1);

    const job = world.jobs.jobs.get(jobId)!;
    assert.equal(job.status, 'expired');
    assert.ok(job.closedAt);
    assert.ok(job.referencesPurgeAfter);

    const quote = world.jobs.quotes.get(jobId)!.get('p_tu')!;
    assert.equal(quote.status, 'not_selected');
    assert.equal(quote.notSelectedReason, 'expired');
  });

  it('a job inside an active checkout is skipped', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    const job = world.jobs.jobs.get(jobId)!;
    world.jobs.jobs.set(jobId, {
      ...job,
      checkout: {
        quoteId: 'p_tu',
        bookingId: 'b1',
        expiresAt: new Date('2026-10-09T01:00:00.000Z'),
      },
    });

    world.clock.set(new Date('2026-10-09T00:00:00.000Z')); // past deadline, but checkout active
    const res = await runJobSweeps(world.deps, world.notifyDeps);
    assert.equal(res.expired, 0);

    const jobAfter = world.jobs.jobs.get(jobId)!;
    assert.equal(jobAfter.status, 'open');
  });

  it('expired job sets referencesPurgeAfter 30 days later', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    const expiryTime = new Date('2026-10-09T00:00:00.000Z');
    world.clock.set(expiryTime);
    await runJobSweeps(world.deps, world.notifyDeps);

    const job = world.jobs.jobs.get(jobId)!;
    const expectedPurge = new Date(expiryTime.getTime() + 30 * 24 * 60 * 60 * 1000);
    assert.equal(job.referencesPurgeAfter?.toISOString(), expectedPurge.toISOString());
  });

  it('the expiring notice goes once and only with at least one quote', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    // quoteCount is 0 initially
    // 24 hours before deadline (deadline is 2026-10-08T02:00:00.000Z)
    world.clock.set(new Date('2026-10-07T03:00:00.000Z'));
    const resZero = await runJobSweeps(world.deps, world.notifyDeps);
    assert.equal(resZero.noticed, 0); // no notice sent because quoteCount == 0

    const job = world.jobs.jobs.get(jobId)!;
    assert.ok(job.expiringNotifiedAt !== null); // flag is still set
  });

  it('the expiring notice flag is set even with zero quotes', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    world.clock.set(new Date('2026-10-07T03:00:00.000Z'));
    await runJobSweeps(world.deps, world.notifyDeps);

    const job = world.jobs.jobs.get(jobId)!;
    assert.ok(job.expiringNotifiedAt !== null);
  });

  it('purge deletes the files and empties references', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', validRaw);

    const job = world.jobs.jobs.get(jobId)!;
    world.jobs.jobs.set(jobId, {
      ...job,
      referencesPurgeAfter: new Date('2026-10-06T00:00:00.000Z'),
    });

    world.clock.set(new Date('2026-10-07T00:00:00.000Z'));
    const res = await runJobSweeps(world.deps, world.notifyDeps);
    assert.equal(res.purged, 1);

    assert.equal(world.media.deleted.length, 2);
    assert.equal(world.media.deleted[0], 'jobRefs/cust_lan/d1/1.jpg');
    assert.equal(world.media.deleted[1], 'jobRefs/cust_lan/d1/2.jpg');

    const jobAfter = world.jobs.jobs.get(jobId)!;
    assert.deepEqual(jobAfter.references, []);
    assert.equal(jobAfter.referencesPurgeAfter, null);
  });

  it('a failure on one job does not stop the batch', async () => {
    const world = createJobWorld();
    await createJob(world.deps, 'cust_lan', validRaw);
    await createJob(world.deps, 'cust_lan', validRaw);

    world.clock.set(new Date('2026-10-10T00:00:00.000Z')); // past deadline for both

    const res = await runJobSweeps(world.deps, world.notifyDeps);
    assert.equal(res.expired, 2);
  });

  it('running twice changes nothing more', async () => {
    const world = createJobWorld();
    await createJob(world.deps, 'cust_lan', validRaw);
    world.clock.set(new Date('2026-10-10T00:00:00.000Z'));

    const res1 = await runJobSweeps(world.deps, world.notifyDeps);
    assert.equal(res1.expired, 1);

    const res2 = await runJobSweeps(world.deps, world.notifyDeps);
    assert.equal(res2.expired, 0);
  });

  it('expiry calls notifyJobExpired once', async () => {
    const world = createJobWorld();
    await createJob(world.deps, 'cust_lan', validRaw);

    world.clock.set(new Date('2026-10-10T00:00:00.000Z'));
    await runJobSweeps(world.deps, world.notifyDeps);

    const notices = world.notifyWorld.store.rowsOf('cust_lan');
    assert.equal(notices.length, 1);
    assert.equal(notices[0].type, 'job_expired');
  });

  it('the expiring notice calls notifyJobExpiring with the deadline and is sent again after an extension', async () => {
    const world = createJobWorld();
    const { jobId } = await createJob(world.deps, 'cust_lan', {
      ...validRaw,
      schedule: { kind: 'fixed', day: '2026-10-25', start: '07:00', end: '11:00' },
    });

    // Add a quote so quoteCount >= 1
    const job = world.jobs.jobs.get(jobId)!;
    world.jobs.jobs.set(jobId, { ...job, quoteCount: 1 });

    // Step clock to 24h before deadline
    world.clock.set(new Date('2026-10-07T03:00:00.000Z'));
    await runJobSweeps(world.deps, world.notifyDeps);

    let notices = world.notifyWorld.store.rowsOf('cust_lan').filter((n) => n.type === 'job_expiring');
    assert.equal(notices.length, 1);

    // Now customer extends job
    await extendJob(world.deps, 'cust_lan', { jobId });

    // Step clock to 24h before new deadline (new deadline is 2026-10-15T02:00:00.000Z)
    world.clock.set(new Date('2026-10-14T03:00:00.000Z'));
    await runJobSweeps(world.deps, world.notifyDeps);

    notices = world.notifyWorld.store.rowsOf('cust_lan').filter((n) => n.type === 'job_expiring');
    assert.equal(notices.length, 2);
  });
});

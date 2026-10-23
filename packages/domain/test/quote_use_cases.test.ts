import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createJobWorld } from './support/job_world.js';
import { createJob } from '../src/job_use_cases.js';
import { submitQuote, withdrawQuote, declineQuote } from '../src/quote_use_cases.js';
import { DomainError } from '../src/errors.js';

describe('quote_use_cases', () => {
  async function setupJob(w: ReturnType<typeof createJobWorld>) {
    const res = await createJob(w.deps, 'cust_lan', {
      specialtyId: 'graduation',
      title: 'Chụp kỷ yếu tốt nghiệp cấp 3',
      description: 'Lớp 12A1 gồm 42 bạn chụp tại trường',
      schedule: {
        kind: 'fixed',
        day: '2026-10-20',
        start: '07:00',
        end: '11:00',
      },
      area: {
        name: 'Quận 1, TP.HCM',
        lat: 10.7769,
        lng: 106.7009,
      },
      budget: { min: 3000000, max: 5000000 },
      allowedProviders: 'all',
      deadlineDays: 3,
    });
    return res.jobId;
  }

  it('submit creates a quote with fit, snapshot and milestone amounts', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    const res = await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4200000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình có kinh nghiệm chụp kỷ yếu nhiều năm và rất vui được hợp tác!',
    });

    assert.equal(res.status, 'submitted');
    assert.ok(res.fit >= 0 && res.fit <= 100);

    const job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.quoteCount, 1);
    assert.equal(job?.newQuoteCount, 1);

    const quote = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_tu'));
    assert.ok(quote);
    assert.equal(quote.terms.price, 4200000);
    assert.equal(quote.milestoneAmounts.shoot, 2100000);
    assert.equal(quote.milestoneAmounts.delivery, 2100000);
    assert.equal(quote.photographer.name, 'Tú');
  });

  it('submit refuses a provider that does not accept orders with not_accepting_orders', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await assert.rejects(
      submitQuote(w.deps, 'p_binh', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'not_accepting_orders',
    );
  });

  it('submit refuses a photographer and a job owner blocked either way with blocked', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);
    w.blocks.block('cust_lan', 'p_tu');

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'blocked',
    );
  });

  it('submit refuses an out-of-area or wrong-type provider with not_eligible', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    // p_ha is in Hanoi, job is in HCMC
    await assert.rejects(
      submitQuote(w.deps, 'p_ha', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'not_eligible',
    );
  });

  it('submit refuses the job owner', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    // Lan is customer role
    await assert.rejects(
      submitQuote(w.deps, 'cust_lan', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'not_eligible',
    );
  });

  it('submit on a booked or off day is day_taken', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);
    w.people.dayStates.set('p_tu', new Map([['2026-10-20', 'booked']]));

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'day_taken',
    );
  });

  it('submit on a pending day is allowed', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);
    w.people.dayStates.set('p_tu', new Map([['2026-10-20', 'pending']]));

    const res = await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });
    assert.equal(res.status, 'submitted');
  });

  it('submit after the deadline is deadline_passed even while the job is still open', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    // Fast forward 4 days (deadline was 3 days)
    w.clock.set(new Date('2026-10-10T00:00:00.000Z'));

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'deadline_passed',
    );
  });

  it('the 21st open quote is limit_exceeded', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    // Mock countSubmittedQuotes to 20
    w.jobs.countSubmittedQuotes = async () => 20;

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'limit_exceeded',
    );
  });

  it('editing does not count against the limit', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    // Initial submit
    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    // Mock countSubmittedQuotes to 20
    w.jobs.countSubmittedQuotes = async () => 20;

    // Resubmitting/editing same quote is allowed
    const res = await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4500000,
      editedCount: 35,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình cập nhật lại giá báo cho công việc này nhé.',
    });
    assert.equal(res.status, 'submitted');
  });

  it('a phone number in the message is invalid_argument with field message.contact', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, liên hệ số 0903123456 để trao đổi thêm chi tiết nhé.',
      }),
      (err: DomainError) => err.code === 'invalid_argument' && err.field === 'message.contact',
    );
  });

  it('message shorter than 20 is invalid_argument', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Ngắn quá',
      }),
      (err: DomainError) => err.code === 'invalid_argument' && err.field === 'message',
    );
  });

  it('price 0 is invalid_argument with field price', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 0,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'invalid_argument' && err.field === 'price',
    );
  });

  it('basedOnServiceId copies photoCount from the package', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);
    w.people.services.set('p_tu_svc1', {
      active: true,
      photoCount: 150,
      editedCount: 30,
      deliveryDays: 5,
      price: 4000000,
    });

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      basedOnServiceId: 'svc1',
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    const quote = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_tu'));
    assert.equal(quote?.terms.photoCount, 150);
  });

  it("someone else's package is invalid_argument with field basedOnServiceId", async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);
    // svc1 belongs to p_may, not p_tu
    w.people.services.set('p_may_svc1', {
      active: true,
      photoCount: 150,
      editedCount: 30,
      deliveryDays: 5,
      price: 4000000,
    });

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        basedOnServiceId: 'svc1',
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'invalid_argument' && err.field === 'basedOnServiceId',
    );
  });

  it('an empty album is invalid_argument with field albumId', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);
    w.people.albums.set('alb1', {
      photographerId: 'p_tu',
      title: 'Kỷ yếu',
      coverUrl: null,
      postCount: 0,
    });

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        albumId: 'alb1',
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'invalid_argument' && err.field === 'albumId',
    );
  });

  it('flexible job needs a proposal inside the range', async () => {
    const w = createJobWorld();
    const res = await createJob(w.deps, 'cust_lan', {
      specialtyId: 'graduation',
      title: 'Chụp kỷ yếu tốt nghiệp cấp 3',
      description: 'Lớp 12A1 gồm 42 bạn chụp linh hoạt thời gian',
      schedule: {
        kind: 'flexible',
        from: '2026-10-20',
        to: '2026-10-30',
        durationMinutes: 240,
      },
      area: {
        name: 'Quận 1, TP.HCM',
        lat: 10.7769,
        lng: 106.7009,
      },
      budget: { min: 3000000, max: 5000000 },
      allowedProviders: 'all',
      deadlineDays: 3,
    });
    const jobId = res.jobId;

    // Missing proposal
    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'invalid_argument' && err.field === 'proposal',
    );

    // Proposal outside range
    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4000000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        proposal: { day: '2026-11-01', start: '08:00' },
        message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'invalid_argument' && err.field === 'proposal',
    );

    // Valid proposal inside range
    const qRes = await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      proposal: { day: '2026-10-25', start: '08:00' },
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });
    assert.equal(qRes.status, 'submitted');
    const quote = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_tu'));
    assert.equal(quote?.proposal.day, '2026-10-25');
    assert.equal(quote?.proposal.start, '08:00');
    assert.equal(quote?.proposal.end, '12:00');
  });

  it('fixed job ignores a proposal in the input', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      proposal: { day: '2026-10-25', start: '08:00' }, // different date
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    const quote = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_tu'));
    assert.equal(quote?.proposal.day, '2026-10-20');
    assert.equal(quote?.proposal.start, '07:00');
    assert.equal(quote?.proposal.end, '11:00');
  });

  it('edit keeps quoteCount and newQuoteCount', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    let job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.quoteCount, 1);
    assert.equal(job?.newQuoteCount, 1);

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4500000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn sửa báo giá cho công việc này nhé.',
    });

    job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.quoteCount, 1);
    assert.equal(job?.newQuoteCount, 1);
  });

  it('resubmit after withdraw counts again', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    await withdrawQuote(w.deps, 'p_tu', { jobId });

    let job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.quoteCount, 0);

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4200000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi lại báo giá cho công việc này nhé.',
    });

    job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.quoteCount, 1);
  });

  it('edit or withdraw during an active checkout is conflict', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    // Set checkout lock on job
    await w.jobs.runTransaction(async (tx) => {
      const j = (await tx.getJob(jobId))!;
      tx.putJob({
        ...j,
        checkout: {
          quoteId: 'p_tu',
          bookingId: 'bk_1',
          expiresAt: new Date('2026-10-05T03:00:00.000Z'),
        },
      });
    });

    await assert.rejects(
      submitQuote(w.deps, 'p_tu', {
        jobId,
        price: 4500000,
        editedCount: 30,
        deliveryDays: 5,
        revisions: 2,
        message: 'Chào bạn, mình muốn sửa báo giá cho công việc này nhé.',
      }),
      (err: DomainError) => err.code === 'conflict',
    );

    await assert.rejects(
      withdrawQuote(w.deps, 'p_tu', { jobId }),
      (err: DomainError) => err.code === 'conflict',
    );
  });

  it('withdraw lowers quoteCount and removes the avatar', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    // Give p_tu an avatar
    const p = (await w.people.provider('p_tu'))!;
    w.people.providers.set('p_tu', { ...p, avatarUrl: 'https://cdn/tu.jpg' });

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    let job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.ok(job?.recentQuoters.some((q) => q.avatarUrl === 'https://cdn/tu.jpg'));

    await withdrawQuote(w.deps, 'p_tu', { jobId });

    job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.quoteCount, 0);
    assert.ok(!job?.recentQuoters.some((q) => q.avatarUrl === 'https://cdn/tu.jpg'));
  });

  it('decline sets declined with the reason and only the owner may decline', async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    // Decline by non-owner
    await assert.rejects(
      declineQuote(w.deps, 'cust_other', {
        jobId,
        photographerId: 'p_tu',
        reason: 'Giá hơi cao',
      }),
      (err: DomainError) => err.code === 'permission_denied',
    );

    // Decline by owner
    await declineQuote(w.deps, 'cust_lan', {
      jobId,
      photographerId: 'p_tu',
      reason: 'Giá hơi cao',
    });

    const quote = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_tu'));
    assert.equal(quote?.status, 'declined');
    assert.equal(quote?.declineReason, 'Giá hơi cao');
  });

  it("an invited photographer's quote is marked invited", async () => {
    const w = createJobWorld();
    const jobId = await setupJob(w);

    // Put an invite
    await w.jobs.runTransaction(async (tx) => {
      tx.putInvite({
        id: 'p_tu',
        jobId,
        photographerId: 'p_tu',
        customerId: 'cust_lan',
        fit: 90,
        jobStatus: 'open',
        createdAt: w.clock.now(),
        seenAt: null,
      });
    });

    await submitQuote(w.deps, 'p_tu', {
      jobId,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình muốn gửi báo giá cho công việc này nhé.',
    });

    const quote = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_tu'));
    assert.equal(quote?.invited, true);
  });
});

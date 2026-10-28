import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createJobWorld } from './support/job_world.js';
import { createJob } from '../src/job_use_cases.js';
import { submitQuote, awardJobFromBooking, withdrawQuotesForDay } from '../src/quote_use_cases.js';
import type { Booking } from '../src/booking.js';

describe('award_job', () => {
  async function setupJobWithQuotes(w: ReturnType<typeof createJobWorld>) {
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

    await submitQuote(w.deps, 'p_tu', {
      jobId: res.jobId,
      price: 4200000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình có kinh nghiệm chụp kỷ yếu nhiều năm và rất vui được hợp tác!',
    });

    await submitQuote(w.deps, 'p_may', {
      jobId: res.jobId,
      price: 4500000,
      editedCount: 40,
      deliveryDays: 7,
      revisions: 2,
      message: 'Chào bạn, Studio Mây sẵn sàng phục vụ lớp bạn với chất lượng tốt nhất!',
    });

    return { jobId: res.jobId };
  }

  it('award marks the job awarded and the chosen quote accepted with the booking id', async () => {
    const w = createJobWorld();
    const { jobId } = await setupJobWithQuotes(w);

    const booking: Booking = {
      id: 'bk_quote_1',
      customerId: 'cust_lan',
      photographerId: 'p_tu',
      serviceId: '',
      serviceSnapshot: { name: 'Chụp kỷ yếu tốt nghiệp cấp 3', price: 4200000, durationMinutes: 240 },
      day: '2026-10-20',
      start: '07:00',
      end: '11:00',
      place: { name: 'Trường THPT Lê Hồng Phong' },
      status: 'accepted',
      deposit: 4200000,
      remaining: 0,
      source: 'quote',
      jobId,
      quoteId: 'p_tu',
      version: 2,
      createdAt: w.clock.now().toISOString(),
      updatedAt: w.clock.now().toISOString(),
    };

    const outcome = await awardJobFromBooking(w.deps, booking);
    assert.equal(outcome, 'awarded');

    const job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.status, 'awarded');
    assert.equal(job?.awardedQuoteId, 'p_tu');
    assert.equal(job?.bookingId, 'bk_quote_1');
    assert.equal(job?.awardedTo?.photographerId, 'p_tu');
    assert.equal(job?.awardedTo?.name, 'Tú');
    assert.equal(job?.awardedTo?.price, 4200000);
    assert.equal(job?.checkout, null);

    const quoteTu = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_tu'));
    assert.equal(quoteTu?.status, 'accepted');
    assert.equal(quoteTu?.bookingId, 'bk_quote_1');
  });

  it('other submitted quotes become not_selected with reason awarded', async () => {
    const w = createJobWorld();
    const { jobId } = await setupJobWithQuotes(w);

    const booking: Booking = {
      id: 'bk_quote_1',
      customerId: 'cust_lan',
      photographerId: 'p_tu',
      serviceId: '',
      serviceSnapshot: { name: 'Chụp kỷ yếu tốt nghiệp cấp 3', price: 4200000, durationMinutes: 240 },
      day: '2026-10-20',
      start: '07:00',
      end: '11:00',
      place: { name: 'Trường THPT Lê Hồng Phong' },
      status: 'accepted',
      deposit: 4200000,
      remaining: 0,
      source: 'quote',
      jobId,
      quoteId: 'p_tu',
      version: 2,
      createdAt: w.clock.now().toISOString(),
      updatedAt: w.clock.now().toISOString(),
    };

    await awardJobFromBooking(w.deps, booking);

    const quoteMay = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_may'));
    assert.equal(quoteMay?.status, 'not_selected');
    assert.equal(quoteMay?.notSelectedReason, 'awarded');
  });

  it('invites and matches are closed', async () => {
    const w = createJobWorld();
    const { jobId } = await setupJobWithQuotes(w);

    // Add invite and match
    await w.jobs.runTransaction(async (tx) => {
      tx.putInvite({
        id: 'p_vu',
        jobId,
        photographerId: 'p_vu',
        customerId: 'cust_lan',
        fit: 90,
        jobStatus: 'open',
        createdAt: w.clock.now(),
        seenAt: null,
      });
      tx.putMatch({
        id: 'p_vu',
        jobId,
        photographerId: 'p_vu',
        fit: 90,
        jobStatus: 'open',
        createdAt: w.clock.now(),
      });
    });

    const booking: Booking = {
      id: 'bk_quote_1',
      customerId: 'cust_lan',
      photographerId: 'p_tu',
      serviceId: '',
      serviceSnapshot: { name: 'Chụp kỷ yếu', price: 4200000, durationMinutes: 240 },
      day: '2026-10-20',
      start: '07:00',
      end: '11:00',
      place: { name: 'Trường' },
      status: 'accepted',
      deposit: 4200000,
      remaining: 0,
      source: 'quote',
      jobId,
      quoteId: 'p_tu',
      version: 2,
      createdAt: w.clock.now().toISOString(),
      updatedAt: w.clock.now().toISOString(),
    };

    await awardJobFromBooking(w.deps, booking);

    const invite = await w.jobs.runTransaction((tx) => tx.getInvite(jobId, 'p_vu'));
    assert.equal(invite?.jobStatus, 'closed');

    const matches = await w.jobs.runTransaction((tx) => tx.listMatches(jobId));
    assert.equal(matches[0]?.jobStatus, 'closed');
  });

  it('award is idempotent', async () => {
    const w = createJobWorld();
    const { jobId } = await setupJobWithQuotes(w);

    const booking: Booking = {
      id: 'bk_quote_1',
      customerId: 'cust_lan',
      photographerId: 'p_tu',
      serviceId: '',
      serviceSnapshot: { name: 'Chụp kỷ yếu', price: 4200000, durationMinutes: 240 },
      day: '2026-10-20',
      start: '07:00',
      end: '11:00',
      place: { name: 'Trường' },
      status: 'accepted',
      deposit: 4200000,
      remaining: 0,
      source: 'quote',
      jobId,
      quoteId: 'p_tu',
      version: 2,
      createdAt: w.clock.now().toISOString(),
      updatedAt: w.clock.now().toISOString(),
    };

    const first = await awardJobFromBooking(w.deps, booking);
    assert.equal(first, 'awarded');

    const second = await awardJobFromBooking(w.deps, booking);
    assert.equal(second, 'already');
  });

  it('a package booking is skipped', async () => {
    const w = createJobWorld();
    await setupJobWithQuotes(w);

    const booking: Booking = {
      id: 'bk_package_1',
      customerId: 'cust_lan',
      photographerId: 'p_tu',
      serviceId: 'srv_1',
      serviceSnapshot: { name: 'Gói chụp', price: 4200000, durationMinutes: 240 },
      day: '2026-10-20',
      start: '07:00',
      end: '11:00',
      place: { name: 'Trường' },
      status: 'accepted',
      deposit: 4200000,
      remaining: 0,
      source: 'package',
      version: 2,
      createdAt: w.clock.now().toISOString(),
      updatedAt: w.clock.now().toISOString(),
    };

    const outcome = await awardJobFromBooking(w.deps, booking);
    assert.equal(outcome, 'skipped');
  });

  it('a job that expired between payment and award is still awarded and the chosen quote becomes accepted', async () => {
    const w = createJobWorld();
    const { jobId } = await setupJobWithQuotes(w);

    // Job expires in between
    await w.jobs.runTransaction(async (tx) => {
      const j = (await tx.getJob(jobId))!;
      const qTu = (await tx.getQuote(jobId, 'p_tu'))!;
      tx.putJob({
        ...j,
        status: 'expired',
        closedAt: w.clock.now(),
      });
      tx.putQuote({
        ...qTu,
        status: 'not_selected',
        notSelectedReason: 'expired',
      });
    });

    const booking: Booking = {
      id: 'bk_quote_1',
      customerId: 'cust_lan',
      photographerId: 'p_tu',
      serviceId: '',
      serviceSnapshot: { name: 'Chụp kỷ yếu', price: 4200000, durationMinutes: 240 },
      day: '2026-10-20',
      start: '07:00',
      end: '11:00',
      place: { name: 'Trường' },
      status: 'accepted',
      deposit: 4200000,
      remaining: 0,
      source: 'quote',
      jobId,
      quoteId: 'p_tu',
      version: 2,
      createdAt: w.clock.now().toISOString(),
      updatedAt: w.clock.now().toISOString(),
    };

    const outcome = await awardJobFromBooking(w.deps, booking);
    assert.equal(outcome, 'awarded');

    const job = await w.jobs.runTransaction((tx) => tx.getJob(jobId));
    assert.equal(job?.status, 'awarded');

    const qTu = await w.jobs.runTransaction((tx) => tx.getQuote(jobId, 'p_tu'));
    assert.equal(qTu?.status, 'accepted');
  });

  it('withdrawQuotesForDay withdraws other submitted quotes on that day with autoWithdrawn', async () => {
    const w = createJobWorld();
    const { jobId: job1 } = await setupJobWithQuotes(w);

    // Create a second job on the same day 2026-10-20
    const job2Res = await createJob(w.deps, 'cust_lan', {
      specialtyId: 'graduation',
      title: 'Chụp kỷ yếu lớp 12A2',
      description: 'Lớp 12A2 gồm 35 bạn chụp cùng ngày',
      schedule: {
        kind: 'fixed',
        day: '2026-10-20',
        start: '13:00',
        end: '17:00',
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
    const job2 = job2Res.jobId;

    // p_tu submits quote on job2 as well
    await submitQuote(w.deps, 'p_tu', {
      jobId: job2,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình có thể chụp buổi chiều cho lớp bạn nhé!',
    });

    // Now withdraw quotes for p_tu on 2026-10-20 except job1
    const count = await withdrawQuotesForDay(w.deps, 'p_tu', '2026-10-20', job1);
    assert.equal(count, 1);

    const qJob2 = await w.jobs.runTransaction((tx) => tx.getQuote(job2, 'p_tu'));
    assert.equal(qJob2?.status, 'withdrawn');
    assert.equal(qJob2?.autoWithdrawn, true);
    assert.ok(qJob2?.withdrawnAt);

    // Job1 quote is untouched
    const qJob1 = await w.jobs.runTransaction((tx) => tx.getQuote(job1, 'p_tu'));
    assert.equal(qJob1?.status, 'submitted');
  });

  it('withdrawQuotesForDay leaves the excepted job and other days alone', async () => {
    const w = createJobWorld();
    const { jobId: job1 } = await setupJobWithQuotes(w);

    // Create job on a DIFFERENT day 2026-10-25
    const jobOtherRes = await createJob(w.deps, 'cust_lan', {
      specialtyId: 'graduation',
      title: 'Chụp kỷ yếu lớp 12A3',
      description: 'Lớp 12A3 ngày khác',
      schedule: {
        kind: 'fixed',
        day: '2026-10-25',
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
    const jobOther = jobOtherRes.jobId;

    await submitQuote(w.deps, 'p_tu', {
      jobId: jobOther,
      price: 4000000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình có thể chụp ngày 25 nhé!',
    });

    const count = await withdrawQuotesForDay(w.deps, 'p_tu', '2026-10-20', job1);
    assert.equal(count, 0);

    const qOther = await w.jobs.runTransaction((tx) => tx.getQuote(jobOther, 'p_tu'));
    assert.equal(qOther?.status, 'submitted');
  });
});

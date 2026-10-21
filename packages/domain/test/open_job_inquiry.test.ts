import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createJobWorld } from './support/job_world.js';
import { createChatWorld } from './support/chat_world.js';
import { createJob } from '../src/job_use_cases.js';
import { submitQuote } from '../src/quote_use_cases.js';
import { openJobInquiry } from '../src/open_job_inquiry.js';
import { DomainError } from '../src/errors.js';

describe('open_job_inquiry', () => {
  async function setupWorld() {
    const jWorld = createJobWorld();
    const cWorld = createChatWorld();
    // Synchronize clock and ids
    cWorld.clock.set(jWorld.clock.now());

    const res = await createJob(jWorld.deps, 'cust_lan', {
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

    return { jWorld, cWorld, jobId: res.jobId };
  }

  it('a quoting photographer opens a chat with the owner, kind inquiry, startedBy photographer, jobId set', async () => {
    const { jWorld, cWorld, jobId } = await setupWorld();

    await submitQuote(jWorld.deps, 'p_tu', {
      jobId,
      price: 4200000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình có kinh nghiệm chụp kỷ yếu nhiều năm và rất vui được hợp tác!',
    });

    const res = await openJobInquiry(
      { job: jWorld.deps, chat: cWorld.deps },
      'p_tu',
      { jobId },
    );

    assert.ok(res.chatId);
    const chat = await cWorld.deps.chats.runTransaction((tx) => tx.getChat(res.chatId));
    assert.ok(chat);
    assert.equal(chat.kind, 'inquiry');
    assert.equal(chat.startedBy, 'photographer');
    assert.equal(chat.jobId, jobId);
    assert.equal(chat.customerId, 'cust_lan');
    assert.equal(chat.photographerId, 'p_tu');
  });

  it('the owner opens a chat with an invited photographer', async () => {
    const { jWorld, cWorld, jobId } = await setupWorld();

    await jWorld.jobs.runTransaction(async (tx) => {
      tx.putInvite({
        id: 'p_may',
        jobId,
        photographerId: 'p_may',
        customerId: 'cust_lan',
        fit: 90,
        jobStatus: 'open',
        createdAt: jWorld.clock.now(),
        seenAt: null,
      });
    });

    const res = await openJobInquiry(
      { job: jWorld.deps, chat: cWorld.deps },
      'cust_lan',
      { jobId, photographerId: 'p_may' },
    );

    assert.ok(res.chatId);
    const chat = await cWorld.deps.chats.runTransaction((tx) => tx.getChat(res.chatId));
    assert.ok(chat);
    assert.equal(chat.kind, 'inquiry');
    assert.equal(chat.startedBy, 'customer');
    assert.equal(chat.jobId, jobId);
  });

  it('the owner cannot open a chat with an unrelated photographer', async () => {
    const { jWorld, cWorld, jobId } = await setupWorld();

    // p_ha has no quote, invite or match
    await assert.rejects(
      openJobInquiry(
        { job: jWorld.deps, chat: cWorld.deps },
        'cust_lan',
        { jobId, photographerId: 'p_ha' },
      ),
      (err: DomainError) => err.code === 'permission_denied',
    );
  });

  it('an existing booking chat keeps its kind and gets the jobId', async () => {
    const { jWorld, cWorld, jobId } = await setupWorld();

    // Create an existing booking chat
    await cWorld.deps.chats.runTransaction(async (tx) => {
      tx.setChat({
        id: 'cust_lan_p_tu',
        kind: 'booking',
        customerId: 'cust_lan',
        photographerId: 'p_tu',
        bookingId: 'bk_old_1',
        bookingStatus: 'completed',
        photographerRepliedAt: jWorld.clock.now(),
        customerMessagesBeforeReply: 0,
        lastMessageAt: jWorld.clock.now(),
        lastMessagePreview: 'OK',
        lastSenderId: 'p_tu',
        readOnlyAt: null,
        blockedAt: null,
        rescheduleUsed: false,
        createdAt: jWorld.clock.now(),
        updatedAt: jWorld.clock.now(),
      });
    });

    await submitQuote(jWorld.deps, 'p_tu', {
      jobId,
      price: 4200000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình có kinh nghiệm chụp kỷ yếu nhiều năm và rất vui được hợp tác!',
    });

    const res = await openJobInquiry(
      { job: jWorld.deps, chat: cWorld.deps },
      'p_tu',
      { jobId },
    );

    assert.equal(res.chatId, 'cust_lan_p_tu');
    const chat = await cWorld.deps.chats.runTransaction((tx) => tx.getChat(res.chatId));
    assert.ok(chat);
    assert.equal(chat.kind, 'booking');
    assert.equal(chat.jobId, jobId);
  });

  it('a photographer who refuses inquiries is not_eligible', async () => {
    const { jWorld, cWorld, jobId } = await setupWorld();

    await submitQuote(jWorld.deps, 'p_tu', {
      jobId,
      price: 4200000,
      editedCount: 30,
      deliveryDays: 5,
      revisions: 2,
      message: 'Chào bạn, mình có kinh nghiệm chụp kỷ yếu nhiều năm và rất vui được hợp tác!',
    });

    // Disable inquiries
    cWorld.photographers.disableInquiries('p_tu');

    await assert.rejects(
      openJobInquiry(
        { job: jWorld.deps, chat: cWorld.deps },
        'p_tu',
        { jobId },
      ),
      (err: DomainError) => err.code === 'not_eligible',
    );
  });
});

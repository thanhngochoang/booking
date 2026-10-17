import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { decideReport, submitReport } from '../src/report_use_cases.js';
import { DomainError } from '../src/errors.js';
import { createSafetyWorld } from './support/safety_world.js';
import { REPORTS_PER_DAY } from '../src/report.js';

describe('report_use_cases', () => {
  it('a user report stores the snapshot name', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'user',
      id: 'target_u1',
      chatId: null,
      ownerId: 'target_u1',
      snapshot: { name: 'Minh Trí', excerpt: null, imageUrl: null },
    });

    const res = await submitReport(reportDeps, 'reporter_1', {
      targetType: 'user',
      targetId: 'target_u1',
      reason: 'spam',
    });

    assert.equal(res.duplicate, false);
    assert.equal(res.blocked, false);

    const r = await reportStore.get(res.reportId);
    assert.ok(r);
    assert.equal(r.snapshot.name, 'Minh Trí');
    assert.equal(r.targetOwnerId, 'target_u1');
    assert.equal(r.status, 'open');
  });

  it('a post report stores the caption excerpt (≤ 300) and the first image, owner = authorId', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'post',
      id: 'post_1',
      chatId: null,
      ownerId: 'author_1',
      snapshot: { name: null, excerpt: 'Một bài viết hay', imageUrl: 'https://img.test/p1.jpg' },
    });

    const res = await submitReport(reportDeps, 'reporter_1', {
      targetType: 'post',
      targetId: 'post_1',
      reason: 'inappropriate',
    });

    const r = await reportStore.get(res.reportId);
    assert.ok(r);
    assert.equal(r.snapshot.excerpt, 'Một bài viết hay');
    assert.equal(r.snapshot.imageUrl, 'https://img.test/p1.jpg');
    assert.equal(r.targetOwnerId, 'author_1');
  });

  it('a message report requires chat membership (permission_denied) and refuses system messages', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    // Message target with a real sender
    reportStore.setTarget({
      type: 'message',
      id: 'msg_1',
      chatId: 'chat_1',
      ownerId: 'sender_1',
      snapshot: { name: null, excerpt: 'Chuyển khoản nhé', imageUrl: null },
    });
    // System message target without ownerId
    reportStore.setTarget({
      type: 'message',
      id: 'msg_sys',
      chatId: 'chat_1',
      ownerId: null,
      snapshot: { name: null, excerpt: 'Hệ thống', imageUrl: null },
    });

    // Non-member reporter
    await assert.rejects(
      () => submitReport(reportDeps, 'non_member', {
        targetType: 'message',
        targetId: 'msg_1',
        chatId: 'chat_1',
        reason: 'scam',
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
    );

    // Member reporter
    reportStore.setChatMember('chat_1', 'member_1');
    const res = await submitReport(reportDeps, 'member_1', {
      targetType: 'message',
      targetId: 'msg_1',
      chatId: 'chat_1',
      reason: 'scam',
    });
    assert.equal(res.duplicate, false);

    // System message (ownerId === null) can be reported, but block will not trigger
    const resSys = await submitReport(reportDeps, 'member_1', {
      targetType: 'message',
      targetId: 'msg_sys',
      chatId: 'chat_1',
      reason: 'spam',
      block: true,
    });
    assert.equal(resSys.blocked, false);
  });

  it('an event report on a platform event ignores block: true', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'event',
      id: 'event_platform',
      chatId: null,
      ownerId: null, // platform event
      snapshot: { name: 'Photo Walk SG', excerpt: null, imageUrl: null },
    });

    const res = await submitReport(reportDeps, 'reporter_1', {
      targetType: 'event',
      targetId: 'event_platform',
      reason: 'spam',
      block: true,
    });

    assert.equal(res.duplicate, false);
    assert.equal(res.blocked, false);
  });

  it('reporting your own post → invalid_argument', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'post',
      id: 'post_own',
      chatId: null,
      ownerId: 'user_me',
      snapshot: { name: null, excerpt: 'my post', imageUrl: null },
    });

    await assert.rejects(
      () => submitReport(reportDeps, 'user_me', {
        targetType: 'post',
        targetId: 'post_own',
        reason: 'spam',
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
  });

  it('other without 10 characters → invalid_argument', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'user',
      id: 'user_u2',
      chatId: null,
      ownerId: 'user_u2',
      snapshot: { name: 'U2', excerpt: null, imageUrl: null },
    });

    await assert.rejects(
      () => submitReport(reportDeps, 'reporter_1', {
        targetType: 'user',
        targetId: 'user_u2',
        reason: 'other',
        text: 'ngắn quá',
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );

    // With 10 characters -> succeeds
    const res = await submitReport(reportDeps, 'reporter_1', {
      targetType: 'user',
      targetId: 'user_u2',
      reason: 'other',
      text: 'đủ 10 ký tự rồi nè',
    });
    assert.equal(res.duplicate, false);
  });

  it('same reporter and target twice → duplicate true, one document', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'user',
      id: 'user_u3',
      chatId: null,
      ownerId: 'user_u3',
      snapshot: { name: 'U3', excerpt: null, imageUrl: null },
    });

    const res1 = await submitReport(reportDeps, 'reporter_1', {
      targetType: 'user',
      targetId: 'user_u3',
      reason: 'spam',
    });
    assert.equal(res1.duplicate, false);

    const res2 = await submitReport(reportDeps, 'reporter_1', {
      targetType: 'user',
      targetId: 'user_u3',
      reason: 'harassment',
    });
    assert.equal(res2.duplicate, true);
    assert.equal(res2.reportId, res1.reportId);
    assert.equal(reportStore.reports.size, 1);
  });

  it('the 21st report on one Vietnam day → limit_exceeded; the count restarts the next day', async () => {
    const { reportDeps, reportStore, clock } = createSafetyWorld();

    for (let i = 1; i <= REPORTS_PER_DAY; i++) {
      reportStore.setTarget({
        type: 'user',
        id: `user_${i}`,
        chatId: null,
        ownerId: `user_${i}`,
        snapshot: { name: `U${i}`, excerpt: null, imageUrl: null },
      });
      await submitReport(reportDeps, 'reporter_busy', {
        targetType: 'user',
        targetId: `user_${i}`,
        reason: 'spam',
      });
    }

    // 21st report fails
    reportStore.setTarget({
      type: 'user',
      id: 'user_21',
      chatId: null,
      ownerId: 'user_21',
      snapshot: { name: 'U21', excerpt: null, imageUrl: null },
    });
    await assert.rejects(
      () => submitReport(reportDeps, 'reporter_busy', {
        targetType: 'user',
        targetId: 'user_21',
        reason: 'spam',
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'limit_exceeded',
    );

    // Advance 24 hours to next Vietnam day
    clock.advance(24 * 60 * 60 * 1000);

    const res = await submitReport(reportDeps, 'reporter_busy', {
      targetType: 'user',
      targetId: 'user_21',
      reason: 'spam',
    });
    assert.equal(res.duplicate, false);
  });

  it('block: true blocks the owner with source report and returns blocked true', async () => {
    const { reportDeps, reportStore, profiles, blockStore } = createSafetyWorld();
    profiles.setProfile('bad_user', 'Kẻ Xấu');
    reportStore.setTarget({
      type: 'user',
      id: 'bad_user',
      chatId: null,
      ownerId: 'bad_user',
      snapshot: { name: 'Kẻ Xấu', excerpt: null, imageUrl: null },
    });

    const res = await submitReport(reportDeps, 'reporter_1', {
      targetType: 'user',
      targetId: 'bad_user',
      reason: 'harassment',
      block: true,
    });

    assert.equal(res.blocked, true);
    assert.equal(await blockStore.isBlockedEitherWay('reporter_1', 'bad_user'), true);
  });

  it('decideReport writes status, note, decidedBy, decidedAt; a note under 5 characters → invalid_argument', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'user',
      id: 'user_u4',
      chatId: null,
      ownerId: 'user_u4',
      snapshot: { name: 'U4', excerpt: null, imageUrl: null },
    });

    const { reportId } = await submitReport(reportDeps, 'reporter_1', {
      targetType: 'user',
      targetId: 'user_u4',
      reason: 'spam',
    });

    await assert.rejects(
      () => decideReport(reportDeps, 'staff_1', {
        reportId,
        status: 'dismissed',
        note: 'ngắn',
      }),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );

    const decided = await decideReport(reportDeps, 'staff_1', {
      reportId,
      status: 'actioned',
      note: 'Đã xử lý gỡ nội dung vi phạm',
    });

    assert.equal(decided.status, 'actioned');
    assert.equal(decided.staffNote, 'Đã xử lý gỡ nội dung vi phạm');
    assert.equal(decided.decidedBy, 'staff_1');
    assert.ok(decided.decidedAt);
  });
});

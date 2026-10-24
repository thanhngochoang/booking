import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { CollabJob } from '../src/collab_jobs.js';
import { inviteCollaborator } from '../src/collab_use_cases.js';
import { DomainError } from '../src/errors.js';
import { applyToRecruitPost, createRecruitPost } from '../src/recruit_use_cases.js';
import { runRecruitSweeps } from '../src/recruit_sweeps.js';
import { runStudioBookingSweeps } from '../src/studio_booking_sweeps.js';
import {
  answer,
  COLLAB_DEADLINE,
  createCollabWorld,
  offer,
  seedCollab,
  studioBooking,
  type CollabWorld,
} from './support/collab_world.js';
import { VALID_POST } from './support/recruit_world.js';

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

const sweep = (w: CollabWorld) => runRecruitSweeps({ ...w.deps, assign: w.assignDeps });
const rows = (w: CollabWorld, uid: string, type: string) => w.rowsOf(uid).filter((r) => r.type === type);
const jobOf = (w: CollabWorld, bookingId: string, uid = 'p1') => w.recruit.collabJobs.get(`${bookingId}_${uid}`);

async function rejectsWith(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

/** A post of s1 with p1's application; returns the post id. */
async function postWithApplicant(w: CollabWorld): Promise<string> {
  const { postId } = await createRecruitPost(w.deps, 's1', VALID_POST);
  await applyToRecruitPost(w.deps, 'p1', { postId, message: 'Em chụp cưới 3 năm.', samplePostIds: [], acceptTerms: true });
  return postId;
}

/** s1's booking given to p1, who accepted it. */
async function acceptedJob(w: CollabWorld): Promise<string> {
  seedCollab(w, 'p1');
  const b = await studioBooking(w);
  await offer(w, b.id, 'p1');
  await answer(w, 'p1', b.id, true);
  return b.id;
}

/** After the shoot (2026-10-15 16:00 VN = 09:00Z). */
const AFTER_SHOOT = new Date('2026-10-16T10:00:00.000Z');

describe('runRecruitSweeps', () => {
  it('expires open posts past expiresAt and cascades their applications to expired', async () => {
    const w = createCollabWorld();
    const postId = await postWithApplicant(w);
    w.bw.clock.advanceHours(30 * 24);
    const r = await sweep(w);
    assert.equal(r.postsExpired, 1);
    assert.equal(w.recruit.posts.get(postId)?.status, 'expired');
    assert.equal(w.recruit.applications.get(`${postId}_p1`)?.status, 'expired');
    assert.equal(w.recruit.countersOf('s1').openPostCount, 0);
    assert.equal(w.recruit.countersOf('p1').openApplicationCount, 0);
  });

  it('expires applied applications after 7 d with recruit_application_result expired', async () => {
    const w = createCollabWorld();
    const postId = await postWithApplicant(w);
    w.bw.clock.advanceHours(7 * 24 - 1);
    assert.equal((await sweep(w)).applicationsExpired, 0);
    w.bw.clock.advanceHours(1);
    const r = await sweep(w);
    assert.equal(r.applicationsExpired, 1);
    assert.equal(r.postsExpired, 0);
    assert.equal(w.recruit.applications.get(`${postId}_p1`)?.status, 'expired');
    assert.equal(w.recruit.countersOf('p1').openApplicationCount, 0);
    const results = rows(w, 'p1', 'recruit_application_result');
    assert.equal(results.length, 1);
    assert.equal(results[0]?.title, 'Ứng tuyển đã hết hạn');
  });

  it('expires invites after 7 d with collab_invite_result expired', async () => {
    const w = createCollabWorld();
    await inviteCollaborator(w.deps, 's1', { collaboratorId: 'p1' });
    assert.equal(w.recruit.countersOf('s1').pendingInviteCount, 1);
    w.bw.clock.advanceHours(7 * 24);
    const r = await sweep(w);
    assert.equal(r.invitesExpired, 1);
    assert.equal(w.recruit.collaborations.get('s1_p1')?.status, 'expired');
    assert.equal(w.recruit.countersOf('s1').pendingInviteCount, 0);
    const results = rows(w, 's1', 'collab_invite_result');
    assert.equal(results.length, 1);
    assert.equal(results[0]?.body, 'Lời mời cộng tác gửi Minh Trí đã hết hạn.');
  });

  it('expires pending offers: assignee cleared, collab_assignment_result expired', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    await offer(w, b.id, 'p1');
    w.bw.clock.advanceHours(5);
    assert.equal((await sweep(w)).offersExpired, 0);
    w.bw.clock.advanceHours(1);
    const r = await sweep(w);
    assert.equal(r.offersExpired, 1);
    assert.equal(jobOf(w, b.id)?.offerStatus, 'expired');
    const after = await w.bw.store.getBooking(b.id);
    assert.equal(after?.assigneeId, null);
    assert.equal(after?.assigneeKind, null);
    assert.equal(after?.assigneeAccepted, false);
    assert.equal(after?.assignDeadline, b.assignDeadline);
    const results = rows(w, 's1', 'collab_assignment_result');
    assert.equal(results.length, 1);
    assert.equal(results[0]?.title, 'Minh Trí chưa trả lời');
    assert.equal(results[0]?.body, 'Giao người khác trước 14:00 14/10.');
  });

  it('an offer whose booking was cancelled meanwhile expires quietly (the studio is not asked to reassign)', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    await offer(w, b.id, 'p1');
    const offered = await w.bw.store.getBooking(b.id);
    assert.ok(offered);
    w.bw.store.bookings.set(b.id, { ...offered, status: 'cancelled' });
    w.bw.clock.advanceHours(6);
    assert.equal((await sweep(w)).offersExpired, 1);
    assert.equal(jobOf(w, b.id)?.offerStatus, 'expired');
    assert.equal((await w.bw.store.getBooking(b.id))?.status, 'cancelled');
    assert.equal(rows(w, 's1', 'collab_assignment_result').length, 0);
  });

  it("then S26's sweep marks assignOverdue for that booking when its deadline passed (Review Focus 5)", async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    w.bw.clock.setTime(new Date(COLLAB_DEADLINE.getTime() - 4 * HOUR));
    const pending = await offer(w, b.id, 'p1');
    assert.equal(pending.assignments?.[0]?.offerExpiresAt, COLLAB_DEADLINE.toISOString(), 'never outlives the deadline');
    w.bw.clock.setTime(COLLAB_DEADLINE);
    assert.equal((await sweep(w)).offersExpired, 1);
    const s26 = await runStudioBookingSweeps(w.assignDeps, w.deps.notify);
    assert.equal(s26.overdue, 1);
    const after = await w.bw.store.getBooking(b.id);
    assert.equal(after?.assignOverdue, true);
    assert.deepEqual(after?.studioFault, { kind: 'assign_overdue', at: COLLAB_DEADLINE.toISOString() });
    assert.equal(rows(w, 'c1', 'assign_overdue').length, 1);
  });

  it('sets due once milestone 1 is released, with collab_pay_due', async () => {
    const w = createCollabWorld();
    const bookingId = await acceptedJob(w);
    w.bw.clock.setTime(AFTER_SHOOT);
    assert.equal((await sweep(w)).payDue, 0, 'not released yet');
    assert.equal(jobOf(w, bookingId)?.payStatus, 'none');
    assert.deepEqual(jobOf(w, bookingId)?.pay.checkAfter, new Date(AFTER_SHOOT.getTime() + 6 * HOUR), 'asked again in 6 h');
    w.released.add(bookingId);
    w.bw.clock.advanceHours(6);
    const r = await sweep(w);
    assert.equal(r.payDue, 1);
    const job = jobOf(w, bookingId);
    assert.equal(job?.payStatus, 'due');
    assert.deepEqual(job?.pay.dueAt, w.bw.clock.now());
    assert.equal(job?.pay.checkAfter, null);
    const due = rows(w, 's1', 'collab_pay_due');
    assert.equal(due.length, 1);
    assert.match(due[0]?.body ?? '', /^Trả Minh Trí 800\.000/);
    assert.equal(w.bw.store.payments.size > 0, true, 'the booking payment exists');
    assert.equal(w.bw.store.refunds.size, 0, 'no money moves (R5)');
  });

  it('a job whose shoot milestone was refunded without release leaves the pay check with no pay record', async () => {
    const w = createCollabWorld();
    const bookingId = await acceptedJob(w);
    w.bw.clock.setTime(AFTER_SHOOT);
    w.refunded.add(bookingId);
    assert.equal((await sweep(w)).payDue, 0);
    const job = jobOf(w, bookingId);
    assert.equal(job?.payStatus, 'none');
    assert.equal(job?.pay.checkAfter, null);
    assert.deepEqual(await w.recruit.payPending(new Date('2027-01-01T00:00:00.000Z'), 10), []);
    assert.equal(rows(w, 's1', 'collab_pay_due').length, 0);
  });

  it('jobs stuck behind a held milestone never block newer ones (more than 200 stuck)', async () => {
    const w = createCollabWorld();
    const bookingId = await acceptedJob(w);
    const template = jobOf(w, bookingId) as CollabJob;
    for (let i = 0; i < 250; i++) {
      const id = `stuck${String(i).padStart(3, '0')}`;
      w.recruit.seedCollabJob({
        ...template,
        id: `${id}_p1`,
        bookingId: id,
        pay: { ...template.pay, checkAfter: new Date(template.shootEndsAt.getTime() - (i + 1) * HOUR) },
      });
    }
    w.bw.clock.setTime(AFTER_SHOOT);
    w.released.add(bookingId);
    const first = await sweep(w);
    assert.equal(first.payDue, 0, 'the first page holds 200 older stuck jobs');
    const second = await sweep(w);
    assert.equal(second.payDue, 1, 'the stuck ones were pushed 6 h on, the released job is reached');
    assert.equal(jobOf(w, bookingId)?.payStatus, 'due');
    const stuck = w.recruit.collabJobs.get('stuck000_p1');
    assert.deepEqual(stuck?.pay.checkAfter, new Date(AFTER_SHOOT.getTime() + 6 * HOUR));
    assert.equal(stuck?.payStatus, 'none');
    assert.equal((await sweep(w)).payDue, 0, 'nothing to check again before 6 h');
  });

  it('an offer that lapses after its collaboration ended tells the studio of the end', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    await offer(w, b.id, 'p1');
    seedCollab(w, 'p1', { status: 'ended', endedAt: w.bw.clock.now(), endedBy: 'collaborator' });
    w.bw.clock.advanceHours(6);
    assert.equal((await sweep(w)).offersExpired, 1);
    assert.equal(rows(w, 's1', 'collab_assignment_result')[0]?.title, 'Cộng tác với Minh Trí đã kết thúc');
    assert.equal((await w.bw.store.getBooking(b.id))?.assigneeId, null);
  });

  it('a returned or declined job never becomes due', async () => {
    const w = createCollabWorld();
    seedCollab(w, 'p1');
    const b = await studioBooking(w);
    await offer(w, b.id, 'p1');
    await answer(w, 'p1', b.id, false);
    w.bw.clock.setTime(AFTER_SHOOT);
    w.released.add(b.id);
    assert.equal((await sweep(w)).payDue, 0);
    assert.equal(jobOf(w, b.id)?.payStatus, 'none');
  });

  it('flags a job still due 7 d after dueAt exactly once', async () => {
    const w = createCollabWorld();
    const bookingId = await acceptedJob(w);
    w.bw.clock.setTime(AFTER_SHOOT);
    w.released.add(bookingId);
    await sweep(w);
    w.bw.clock.advanceHours(7 * 24 - 1);
    assert.equal((await sweep(w)).payFlagged, 0);
    w.bw.clock.advanceHours(1);
    const flaggedAt = w.bw.clock.now();
    assert.equal((await sweep(w)).payFlagged, 1);
    assert.deepEqual(jobOf(w, bookingId)?.pay.overdueFlaggedAt, flaggedAt);
    assert.deepEqual(w.recruit.countersOf('s1').unpaidFlags, [flaggedAt]);
    w.bw.clock.advanceHours(1);
    assert.equal((await sweep(w)).payFlagged, 0);
    assert.deepEqual(w.recruit.countersOf('s1').unpaidFlags, [flaggedAt]);
  });

  it('flags a disputed job exactly once', async () => {
    const w = createCollabWorld();
    const bookingId = await acceptedJob(w);
    const job = jobOf(w, bookingId) as CollabJob;
    w.recruit.seedCollabJob({ ...job, payStatus: 'disputed', pay: { ...job.pay, dueAt: w.bw.clock.now(), disputedAt: w.bw.clock.now() } });
    w.bw.clock.advanceHours(1);
    const flaggedAt = w.bw.clock.now();
    assert.equal((await sweep(w)).payFlagged, 1);
    assert.deepEqual(jobOf(w, bookingId)?.pay.disputeFlaggedAt, flaggedAt);
    assert.equal(jobOf(w, bookingId)?.payStatus, 'disputed');
    assert.equal(w.recruit.countersOf('s1').unpaidFlags.length, 1);
    assert.equal((await sweep(w)).payFlagged, 0);
    assert.equal(w.recruit.countersOf('s1').unpaidFlags.length, 1);
  });

  it('the third flag in 90 d sets recruitBlockedUntil: no new post or collaborator offer', async () => {
    const w = createCollabWorld();
    const bookingId = await acceptedJob(w);
    const now = w.bw.clock.now();
    w.recruit.seedCounters('s1', { unpaidFlags: [new Date(now.getTime() - 100 * DAY), new Date(now.getTime() - 50 * DAY), new Date(now.getTime() - DAY)] });
    const job = jobOf(w, bookingId) as CollabJob;
    w.recruit.seedCollabJob({ ...job, payStatus: 'disputed', pay: { ...job.pay, disputedAt: now } });
    await sweep(w);
    const c = w.recruit.countersOf('s1');
    assert.equal(c.unpaidFlags.length, 3, 'the 100-day-old flag is pruned');
    assert.deepEqual(c.recruitBlockedUntil, new Date(now.getTime() + 30 * DAY));
    await rejectsWith(createRecruitPost(w.deps, 's1', VALID_POST), 'recruit_blocked');
    seedCollab(w, 'p2');
    const other = await studioBooking(w, { customerId: 'c2', day: '2026-10-16' });
    await rejectsWith(offer(w, other.id, 'p2'), 'recruit_blocked');
    assert.equal(jobOf(w, bookingId)?.offerStatus, 'accepted', 'accepted jobs continue');
  });

  it('running the sweep twice changes nothing the second time (idempotent)', async () => {
    const w = createCollabWorld();
    await postWithApplicant(w);
    await inviteCollaborator(w.deps, 's1', { collaboratorId: 'p2' });
    const paid = await acceptedJob(w);
    seedCollab(w, 'p3');
    const pending = await studioBooking(w, { customerId: 'c2', day: '2026-10-16' });
    await offer(w, pending.id, 'p3');
    w.released.add(paid);
    w.bw.clock.setTime(new Date('2026-11-20T00:00:00.000Z'));
    const first = await sweep(w);
    assert.deepEqual(
      [first.postsExpired, first.invitesExpired, first.offersExpired, first.payDue],
      [1, 1, 1, 1],
    );
    const snapshot = () => JSON.stringify({
      posts: [...w.recruit.posts.values()],
      apps: [...w.recruit.applications.values()],
      collabs: [...w.recruit.collaborations.values()],
      jobs: [...w.recruit.collabJobs.values()],
      counters: [...w.recruit.counters.entries()],
      bookings: [...w.bw.store.bookings.values()],
      rows: ['s1', 'p1', 'p2', 'p3', 'c1', 'c2'].map((uid) => w.rowsOf(uid).length),
    });
    const before = snapshot();
    const second = await sweep(w);
    assert.deepEqual(second, {
      postsExpired: 0,
      applicationsExpired: 0,
      invitesExpired: 0,
      offersExpired: 0,
      payDue: 0,
      payFlagged: 0,
      failed: 0,
    });
    assert.equal(snapshot(), before);
  });
});

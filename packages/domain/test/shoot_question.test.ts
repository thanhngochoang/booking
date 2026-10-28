import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import type { Booking } from '../src/booking.js';
import { decideTransition } from '../src/booking_machine.js';
import { parseVnDateTime } from '../src/booking_policy.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { openDispute } from '../src/dispute_use_cases.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import {
  SHOOT_DENIED_DESCRIPTION,
  SHOOT_DENIED_DISPUTE_HOURS,
  SHOOT_QUESTION_AFTER_HOURS,
  SHOOT_QUESTION_ANSWER_HOURS,
  answerShootHappened,
  askShootHappened,
  expireShootQuestions,
  openDeniedShootDisputes,
  shootDeniedDisputeId,
} from '../src/shoot_question.js';
import type { BookingStore } from '../src/booking_ports.js';
import { transitionBooking } from '../src/transition_booking.js';
import { createBookingWorld, newDraft, payDraft, type BookingWorld } from './support/booking_world.js';
import { bookingView, createDisputeWorld, openInput, paidPayment } from './support/dispute_world.js';
import { must } from './support/event_world.js';
import { createNotifyWorld } from './support/notify_world.js';

const HOUR = 3_600_000;
const code = (c: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === c;
/** The default draft: 2026-10-15 14:00–16:00 in Vietnam. */
const ENDS = parseVnDateTime('2026-10-15', '16:00');
const STARTS = parseVnDateTime('2026-10-15', '14:00');
const ASK_AT = new Date(ENDS.getTime() + SHOOT_QUESTION_AFTER_HOURS * HOUR);

/** A paid, accepted booking of c1 with p1 that the T-24h sweep moved to `upcoming` (it has a pass). */
async function upcoming(w: BookingWorld): Promise<Booking> {
  const draft = await newDraft(w);
  await payDraft(w, draft.id);
  await transitionBooking(w.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });
  w.clock.setTime(new Date(STARTS.getTime() - 24 * HOUR));
  await runBookingSweeps(w.deps);
  const b = must(await w.store.getBooking(draft.id));
  assert.equal(b.status, 'upcoming');
  return b;
}

const get = async (w: BookingWorld, id: string) => must(await w.store.getBooking(id));

describe('askShootHappened (Decision 10)', () => {
  test('askShootHappened at end + 24 h on an upcoming booking without checkedInAt sets shootQuestionAt/Until and notifies shoot_question; a shooting booking is skipped; run twice sends once', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    const shooting: Booking = { ...b, id: 'b_shooting', status: 'shooting', checkedInAt: STARTS.toISOString() };
    w.store.bookings.set(shooting.id, shooting);
    const n = createNotifyWorld(ASK_AT);

    w.clock.setTime(new Date(ASK_AT.getTime() - 1));
    assert.equal(await askShootHappened(w.deps, n.deps), 0);

    w.clock.setTime(ASK_AT);
    assert.equal(await askShootHappened(w.deps, n.deps), 1);
    const asked = await get(w, b.id);
    assert.equal(asked.status, 'upcoming');
    assert.equal(asked.shootQuestionAt, ASK_AT.toISOString());
    assert.equal(asked.shootQuestionUntil, new Date(ASK_AT.getTime() + SHOOT_QUESTION_ANSWER_HOURS * HOUR).toISOString());
    assert.equal((await get(w, shooting.id)).shootQuestionAt, undefined);
    const rows = n.store.rowsOf('c1');
    assert.deepEqual(rows.map((r) => [r.type, r.target]), [['shoot_question', `/b/${b.id}`]]);

    assert.equal(await askShootHappened(w.deps, n.deps), 0);
    assert.equal(n.store.rowsOf('c1').length, 1);
  });

  test('a booking already checked in is never asked', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.store.bookings.set(b.id, { ...b, checkedInAt: STARTS.toISOString() });
    w.clock.setTime(ASK_AT);
    assert.equal(await askShootHappened(w.deps, createNotifyWorld(ASK_AT).deps), 0);
  });
});

describe('answerShootHappened', () => {
  test('answerShootHappened true → shot with shotAt = endsAt and milestones split', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.clock.setTime(ASK_AT);
    await askShootHappened(w.deps, createNotifyWorld(ASK_AT).deps);
    w.clock.advanceHours(1);
    const out = await answerShootHappened(w.deps, { bookingId: b.id, customerId: 'c1', happened: true });
    assert.equal(out.status, 'shot');
    assert.equal(out.shotAt, ENDS.toISOString());
    const p = must((await w.store.getPaymentsForBooking(b.id)).find((x) => x.status === 'paid'));
    assert.deepEqual(p.milestones?.map((m) => m.kind), ['shoot', 'delivery']);
  });

  test('false → shootDeniedAt set, status upcoming, money held; openDispute from upcoming with shootDeniedAt is allowed', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.clock.setTime(ASK_AT);
    await askShootHappened(w.deps, createNotifyWorld(ASK_AT).deps);
    const out = await answerShootHappened(w.deps, { bookingId: b.id, customerId: 'c1', happened: false });
    assert.equal(out.status, 'upcoming');
    assert.equal(out.shootDeniedAt, ASK_AT.toISOString());
    const p = must((await w.store.getPaymentsForBooking(b.id)).find((x) => x.status === 'paid'));
    assert.equal(p.escrowStatus, 'held');
    assert.equal(p.milestones, undefined);
    // A second answer is refused; the expiry sweep leaves a denied booking for the dispute.
    await assert.rejects(answerShootHappened(w.deps, { bookingId: b.id, customerId: 'c1', happened: true }), code('not_eligible'));
    w.clock.advanceHours(SHOOT_QUESTION_ANSWER_HOURS + 1);
    assert.equal(await expireShootQuestions(w.deps), 0);
    assert.equal((await get(w, b.id)).status, 'upcoming');

    const d = createDisputeWorld();
    d.store.putSubject(bookingView({ state: 'upcoming', shootDeniedAt: new Date(ASK_AT) }));
    d.store.payments.set('pay_b1', paidPayment());
    const dispute = await openDispute(d.deps, 'c1', openInput({ reason: 'no_show' }));
    assert.equal(dispute.status, 'open');
    assert.equal(dispute.amountHeld, 1_000_000);
    assert.equal(d.store.payments.get('pay_b1')?.escrowStatus, 'disputed');
  });

  test('an upcoming booking that was never denied is not disputable', async () => {
    const d = createDisputeWorld();
    d.store.putSubject(bookingView({ state: 'upcoming' }));
    d.store.payments.set('pay_b1', paidPayment());
    await assert.rejects(openDispute(d.deps, 'c1', openInput()), code('not_eligible'));
  });

  test('only the customer answers, only while the question is open', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.clock.setTime(ASK_AT);
    await assert.rejects(answerShootHappened(w.deps, { bookingId: b.id, customerId: 'c1', happened: true }), code('not_eligible'));
    await askShootHappened(w.deps, createNotifyWorld(ASK_AT).deps);
    await assert.rejects(answerShootHappened(w.deps, { bookingId: b.id, customerId: 'c2', happened: true }), code('permission_denied'));
    await assert.rejects(answerShootHappened(w.deps, { bookingId: b.id, customerId: 'p1', happened: true }), code('permission_denied'));
    w.clock.advanceHours(SHOOT_QUESTION_ANSWER_HOURS);
    await assert.rejects(answerShootHappened(w.deps, { bookingId: b.id, customerId: 'c1', happened: false }), code('deadline_passed'));
  });
});

describe('expireShootQuestions', () => {
  test('expireShootQuestions after 48 h → shot (system)', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.clock.setTime(ASK_AT);
    await askShootHappened(w.deps, createNotifyWorld(ASK_AT).deps);
    w.clock.advanceHours(SHOOT_QUESTION_ANSWER_HOURS - 1);
    assert.equal(await expireShootQuestions(w.deps), 0);
    w.clock.advanceHours(1);
    assert.equal(await expireShootQuestions(w.deps), 1);
    const shot = await get(w, b.id);
    assert.equal(shot.status, 'shot');
    assert.equal(shot.shotAt, ENDS.toISOString());
    const last = w.store.events.filter((e) => e.bookingId === b.id).at(-1);
    assert.deepEqual([last?.status, last?.actorId], ['shot', undefined]);
  });

  test('runBookingSweeps expires open shoot questions too', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.clock.setTime(ASK_AT);
    await askShootHappened(w.deps, createNotifyWorld(ASK_AT).deps);
    w.clock.advanceHours(SHOOT_QUESTION_ANSWER_HOURS);
    const sweeps = await runBookingSweeps(w.deps);
    assert.equal(sweeps.shootQuestionsExpired, 1);
    assert.equal((await get(w, b.id)).status, 'shot');
  });
});

describe('mark_shot, cancel and the sweep with shooting (Decisions 10, 14)', () => {
  test('mark_shot by the photographer on an upcoming booking with a pass is not_eligible; on shooting it is shot; on a booking without pass (legacy) it stays allowed after endsAt', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    assert.ok(b.passCode4);
    w.clock.setTime(new Date(ENDS.getTime() + HOUR));
    await assert.rejects(transitionBooking(w.deps, { bookingId: b.id, action: 'mark_shot', actorId: 'p1' }), code('not_eligible'));

    const scanned = await get(w, b.id);
    w.store.bookings.set(b.id, { ...scanned, status: 'shooting', checkedInAt: STARTS.toISOString() });
    assert.equal((await transitionBooking(w.deps, { bookingId: b.id, action: 'mark_shot', actorId: 'p1' })).status, 'shot');

    // Paid before this plan: no pass (Decision 14).
    const legacy: Booking = { ...b, id: 'b_legacy', passCode4: undefined };
    w.store.bookings.set(legacy.id, legacy);
    w.clock.setTime(new Date(ENDS.getTime() - 1));
    await assert.rejects(transitionBooking(w.deps, { bookingId: legacy.id, action: 'mark_shot', actorId: 'p1' }), code('not_eligible'));
    w.clock.setTime(ENDS);
    assert.equal((await transitionBooking(w.deps, { bookingId: legacy.id, action: 'mark_shot', actorId: 'p1' })).status, 'shot');
  });

  test('cancel on shooting is not_eligible', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    const shooting: Booking = { ...b, status: 'shooting', checkedInAt: STARTS.toISOString() };
    for (const role of ['customer', 'photographer'] as const) {
      assert.throws(
        () => decideTransition(shooting, 'cancel', { id: role === 'customer' ? 'c1' : 'p1', role }, new Date(STARTS.getTime() - HOUR)),
        code('not_eligible'),
      );
    }
  });

  test('scan from a client through transitionBooking is invalid_argument', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    await assert.rejects(transitionBooking(w.deps, { bookingId: b.id, action: 'scan', actorId: 'p1' }), code('invalid_argument'));
  });

  test('the old auto mark_shot sweep step no longer exists (the sweep result has no autoShots, or it is 0 with due bookings)', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.clock.setTime(new Date(ASK_AT.getTime() + HOUR));
    const sweeps = await runBookingSweeps(w.deps);
    assert.equal('autoShots' in sweeps, false);
    assert.equal((await get(w, b.id)).status, 'upcoming');
  });

  test('a shooting booking at end + 24 h becomes shot by the sweep', async () => {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.store.bookings.set(b.id, { ...b, status: 'shooting', checkedInAt: STARTS.toISOString() });
    w.clock.setTime(new Date(ASK_AT.getTime() - 1));
    assert.equal((await runBookingSweeps(w.deps)).shootingShots, 0);
    w.clock.setTime(ASK_AT);
    assert.equal((await runBookingSweeps(w.deps)).shootingShots, 1);
    assert.equal((await get(w, b.id)).status, 'shot');
  });
});

describe('a denied shoot has an exit (fix 1)', () => {
  /** b denied ("Không diễn ra") at ASK_AT, and the dispute side's view of it with its held payment. */
  async function denied() {
    const w = createBookingWorld();
    const b = await upcoming(w);
    w.clock.setTime(ASK_AT);
    await askShootHappened(w.deps, createNotifyWorld(ASK_AT).deps);
    await answerShootHappened(w.deps, { bookingId: b.id, customerId: 'c1', happened: false });
    const d = createDisputeWorld();
    d.store.putSubject(bookingView({ id: b.id, state: 'upcoming', shootDeniedAt: new Date(ASK_AT) }));
    d.store.payments.set('pay_b1', paidPayment({ subjectId: b.id }));
    return { w, b, d };
  }
  const at = (h: number) => new Date(ASK_AT.getTime() + h * HOUR);

  test('mark_shot by the photographer is refused after the denial, with and without a pass', async () => {
    const { w, b } = await denied();
    w.clock.setTime(at(1));
    await assert.rejects(transitionBooking(w.deps, { bookingId: b.id, action: 'mark_shot', actorId: 'p1' }), code('not_eligible'));
    const legacy: Booking = { ...(await get(w, b.id)), id: 'b_legacy', passCode4: undefined };
    w.store.bookings.set(legacy.id, legacy);
    await assert.rejects(transitionBooking(w.deps, { bookingId: legacy.id, action: 'mark_shot', actorId: 'p1' }), code('not_eligible'));
    assert.equal((await get(w, b.id)).status, 'upcoming');
  });

  test('the clock opens exactly one dispute 48 h after the denial (system, preset reason), none before; the money stays frozen', async () => {
    const { w, b, d } = await denied();
    w.clock.setTime(at(SHOOT_DENIED_DISPUTE_HOURS - 1));
    assert.equal(await openDeniedShootDisputes(w.deps, d.deps), 0);
    assert.equal(d.store.disputes.size, 0);

    w.clock.setTime(at(SHOOT_DENIED_DISPUTE_HOURS));
    assert.equal(await openDeniedShootDisputes(w.deps, d.deps), 1);
    const dispute = d.store.disputes.get(shootDeniedDisputeId(b.id));
    assert.deepEqual(
      [dispute?.openedBy, dispute?.reason, dispute?.description, dispute?.customerId, dispute?.status, dispute?.amountHeld],
      ['system', 'no_show', SHOOT_DENIED_DESCRIPTION, 'c1', 'open', 1_000_000],
    );
    assert.equal(d.store.payments.get('pay_b1')?.escrowStatus, 'disputed');
    // A retry (the mirror not written yet) finds the same dispute; once mirrored, the booking is not due.
    await openDeniedShootDisputes(w.deps, d.deps);
    assert.equal(d.store.disputes.size, 1);
    w.store.bookings.set(b.id, { ...(await get(w, b.id)), disputeId: shootDeniedDisputeId(b.id), escrowStatus: 'disputed' });
    assert.equal(await openDeniedShootDisputes(w.deps, d.deps), 0);
    assert.equal(d.store.payments.get('pay_b1')?.escrowStatus, 'disputed');
  });

  test('no system dispute when the customer already opened one', async () => {
    const { w, b, d } = await denied();
    d.store.putSubject(bookingView({ id: b.id, state: 'upcoming', shootDeniedAt: new Date(ASK_AT), disputeId: 'd_customer' }));
    w.clock.setTime(at(SHOOT_DENIED_DISPUTE_HOURS));
    assert.equal(await openDeniedShootDisputes(w.deps, d.deps), 0);
    assert.equal(d.store.disputes.size, 0);
    w.store.bookings.set(b.id, { ...(await get(w, b.id)), disputeId: 'd_customer' });
    assert.equal((await w.store.findDeniedShootsDue(at(SHOOT_DENIED_DISPUTE_HOURS))).length, 0);
  });
});

describe('the shoot step never blocks the other sweeps (fix 5)', () => {
  test('a throwing shoot-question query still lets the escrow releases run', async () => {
    const w = createBookingWorld();
    const draft = await newDraft(w);
    const { paymentId } = await payDraft(w, draft.id);
    const p = must(w.store.payments.get(paymentId));
    w.store.payments.set(paymentId, { ...p, releaseAfter: '2026-10-10T00:00:00.000Z' });
    const broken = Object.create(w.store) as BookingStore;
    broken.findExpiredShootQuestions = async () => {
      throw new Error('index missing');
    };
    const sweeps = await runBookingSweeps({ ...w.deps, store: broken });
    assert.equal(sweeps.releasedEscrows, 1);
    assert.match(sweeps.shootStepError ?? '', /index missing/);
    assert.equal(must(w.store.payments.get(paymentId)).escrowStatus, 'released');
  });
});

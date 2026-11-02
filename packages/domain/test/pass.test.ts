import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import type { Booking } from '../src/booking.js';
import { computeDeposit } from '../src/booking_policy.js';
import { DomainError } from '../src/errors.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import {
  PASS_ALPHABET,
  freshPassCode,
  isPassCode,
  newPassCode,
  normalizePassCode,
  passCode4,
  passDisplay,
} from '../src/pass.js';
import { createPayment } from '../src/create_payment.js';
import { makeTestBooking } from './support/booking_fixtures.js';
import { createBookingWorld, newDraft, payDraft, transferOf } from './support/booking_world.js';
import { ENTRY_ID, VISIT, bought, createEntryWorld, publishedEntry } from './support/entry_world.js';
import { cu1, makeRandom, must } from './support/event_world.js';
import {
  childrenOf, createBookingEntryWorld, entryDraft, payEntry, send, transfer,
} from './support/booking_entry_world.js';

const DEPOSIT = computeDeposit(1_000_000).deposit;
const TICKETS = 2 * 70_000;

/** A random source answering `bytes` first (each byte < 30 is that alphabet index), then a fixed stream. */
function scripted(...codes: string[]): (n: number) => Uint8Array {
  const queue = codes.flatMap((c) => [...c].map((ch) => PASS_ALPHABET.indexOf(ch)));
  const rest = makeRandom(3);
  return (n) => {
    const out = rest(n);
    for (let i = 0; i < n && queue.length > 0; i++) out[i] = queue.shift() as number;
    return out;
  };
}

describe('pass codes (Decision 7)', () => {
  test('newPassCode gives 8 chars of PASS_ALPHABET (no 0, 1, I, L, O, U)', () => {
    const random = makeRandom(5);
    for (let i = 0; i < 200; i++) {
      const c = newPassCode(random);
      assert.equal(c.length, 8);
      for (const ch of c) assert.ok(PASS_ALPHABET.includes(ch), ch);
      assert.doesNotMatch(c, /[01ILOU]/);
    }
    assert.equal(PASS_ALPHABET, '23456789ABCDEFGHJKMNPQRSTVWXYZ');
  });

  test('newPassCode skips bytes ≥ 240 (uniform: rejection sampling)', () => {
    let calls = 0;
    const random = (n: number) => {
      calls += 1;
      return Uint8Array.from({ length: n }, (_, i) => (calls === 1 && i < 4 ? 250 + i : 31));
    };
    assert.equal(newPassCode(random), PASS_ALPHABET.charAt(1).repeat(8));
  });

  test("normalizePassCode('ve-7k2q-4m9p') = '7K2Q4M9P'; ('7K2Q4M9P') same; ('VE-7K2Q-1020') null (1 and 0 not in the alphabet)", () => {
    assert.equal(normalizePassCode('ve-7k2q-4m9p'), '7K2Q4M9P');
    assert.equal(normalizePassCode('7K2Q4M9P'), '7K2Q4M9P');
    assert.equal(normalizePassCode(' VE-7K2Q-4M9P '), '7K2Q4M9P');
    assert.equal(normalizePassCode('VE-7K2Q-1020'), null);
    assert.equal(normalizePassCode('7K2Q4M9'), null);
    assert.equal(normalizePassCode('7K2Q4M9PP'), null);
    assert.equal(isPassCode('VE-7K2Q-4M9P'), true);
    assert.equal(isPassCode('VE-ABCD-1018'), false);
  });

  test("passDisplay('7K2Q4M9P') = 'VE-7K2Q-4M9P'", () => {
    assert.equal(passDisplay('7K2Q4M9P'), 'VE-7K2Q-4M9P');
  });

  test('passCode4 is the last 4 random characters, not a date', () => {
    assert.equal(passCode4('7K2Q4M9P'), '4M9P');
    assert.doesNotMatch(passCode4(newPassCode(makeRandom(9))), /^\d{4}$/);
  });

  test('pass codes never collide (passTaken consulted, retried)', async () => {
    const asked: string[] = [];
    const taken = new Set(['AAAA2222', 'BBBB3333']);
    const code = await freshPassCode(scripted('AAAA2222', 'BBBB3333', 'CCCC4444'), async (c) => {
      asked.push(c);
      return taken.has(c);
    });
    assert.equal(code, 'CCCC4444');
    assert.deepEqual(asked, ['AAAA2222', 'BBBB3333', 'CCCC4444']);
    await assert.rejects(
      freshPassCode(makeRandom(1), async () => true),
      (e: unknown) => e instanceof DomainError && e.code === 'conflict',
    );
  });
});

describe('passes created on payment (Decisions 7, 8, 14)', () => {
  test("a paid booking without tickets gets passes/{code8} {customerId, day, bookingId, registrationIds: []} and bookings/{id}/private/pass {code} and passCode4", async () => {
    const w = createBookingWorld();
    w.random.script('7K2Q4M9P');
    const draft = await newDraft(w);
    await payDraft(w, draft.id);
    const b = must(await w.store.getBooking(draft.id));
    assert.equal(b.status, 'requested');
    assert.equal(b.passCode4, '4M9P');
    assert.deepEqual(w.store.passes.get('7K2Q4M9P'), {
      code8: '7K2Q4M9P', customerId: 'c1', day: '2026-10-15', bookingId: draft.id, eventId: null, registrationIds: [],
      createdAt: w.clock.now().toISOString(),
    });
    assert.equal(w.store.privatePasses.get(`booking:${draft.id}`), '7K2Q4M9P');
  });

  test('a pass code already taken is drawn again for a booking', async () => {
    const w = createBookingWorld();
    w.store.passes.set('7K2Q4M9P', {
      code8: '7K2Q4M9P', customerId: 'c9', day: '2026-10-01', bookingId: 'old', eventId: null, registrationIds: [],
      createdAt: '2026-10-01T00:00:00.000Z',
    });
    w.random.script('7K2Q4M9P', 'HXRT5678');
    const draft = await newDraft(w);
    await payDraft(w, draft.id);
    assert.equal(must(await w.store.getBooking(draft.id)).passCode4, '5678');
    assert.equal(w.store.passes.get('7K2Q4M9P')?.bookingId, 'old');
    assert.equal(w.store.passes.get('HXRT5678')?.bookingId, draft.id);
  });

  test('a partial transfer creates no pass', async () => {
    const w = createBookingWorld();
    const draft = await newDraft(w);
    const res = await createPayment(w.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    await handleTransferNotification(w.deps, transferOf(w, { content: res.checkout.transferCode, amount: 1000 }));
    assert.equal(w.store.passes.size, 0);
    assert.equal(must(await w.store.getBooking(draft.id)).passCode4, undefined);
  });

  test('a paid group gets one pass with bookingId and the registration id', async () => {
    const w = await createBookingEntryWorld();
    const draft = await entryDraft(w);
    const res = await payEntry(w, draft.id);
    assert.equal((await send(w, transfer(w, res.checkout.transferCode, DEPOSIT + TICKETS))).outcome, 'paid');
    const ticket = must(childrenOf(w, res.paymentId).find((p) => p.lineKind === 'entry_ticket'));
    const passes = [...w.entry.store.passes.values()];
    assert.equal(passes.length, 1);
    const pass = must(passes[0]);
    assert.deepEqual(
      [pass.customerId, pass.day, pass.bookingId, pass.eventId, pass.registrationIds],
      ['c1', VISIT, draft.id, ENTRY_ID, [ticket.subjectId]],
    );
    const b = must(await w.booking.store.getBooking(draft.id));
    const r = must(w.entry.store.registrations.get(`${ENTRY_ID}/${ticket.subjectId}`));
    assert.equal(b.passCode4, passCode4(pass.code8));
    assert.equal(r.ticketCodeLast4, passCode4(pass.code8));
    assert.equal(r.ticketCode, '');
    assert.equal(w.entry.store.privatePasses.get(`booking:${draft.id}`), pass.code8);
    assert.equal(w.entry.store.privatePasses.get(`reg:${ENTRY_ID}/${ticket.subjectId}`), pass.code8);
  });

  test('a lone paid entry registration gets a pass with bookingId null', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const regId = await bought(w, cu1, [{ ticketTypeId: 'adult', qty: 2 }]);
    const r = must(w.store.registrations.get(`${ENTRY_ID}/${regId}`));
    const passes = [...w.store.passes.values()];
    assert.equal(passes.length, 1);
    const pass = must(passes[0]);
    assert.deepEqual([pass.customerId, pass.day, pass.bookingId, pass.eventId, pass.registrationIds], ['cu1', VISIT, null, ENTRY_ID, [regId]]);
    assert.ok(isPassCode(pass.code8));
    assert.equal(r.ticketCode, '');
    assert.equal(r.ticketCodeLast4, passCode4(pass.code8));
    assert.equal(w.store.privatePasses.get(`reg:${ENTRY_ID}/${regId}`), pass.code8);
    // No public ticket code index for a new entry ticket.
    assert.equal([...w.store.ticketCodes.values()].some((t) => t.registrationId === regId), false);
  });

  test('an instant booking gets no pass (Decision 14)', async () => {
    const w = createBookingWorld();
    const draft = await newDraft(w);
    const instant: Booking = { ...must(await w.store.getBooking(draft.id)), source: 'instant' };
    w.store.bookings.set(draft.id, instant);
    await payDraft(w, draft.id);
    assert.equal(must(await w.store.getBooking(draft.id)).status, 'requested');
    assert.equal(must(await w.store.getBooking(draft.id)).passCode4, undefined);
    assert.equal(w.store.passes.size, 0);
  });

  test('a booking paid before this plan has no pass field (legacy fixture)', () => {
    assert.equal(makeTestBooking().passCode4, undefined);
  });
});

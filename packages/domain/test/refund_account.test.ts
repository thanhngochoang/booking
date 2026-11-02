import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { FakeAccountNameLookup } from '../src/account_lookup.js';
import { createPayment } from '../src/create_payment.js';
import { dispatchDisputeRefund, openDispute, resolveDispute } from '../src/dispute_use_cases.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { needsAccountChoice, type Payment, type Refund } from '../src/escrow.js';
import { cancelRegistration, registerEvent } from '../src/event_registration.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import { normalizeHolderName } from '../src/payout_account.js';
import { payerAccountOf } from '../src/payer_account.js';
import {
  announceRefundAccountNeeded,
  chooseRefundAccount,
  confirmDueRefundAccounts,
  lookupRefundAccount,
  pendingRefundFor,
  type RefundAccountDeps,
} from '../src/refund_account.js';
import { transitionBooking } from '../src/transition_booking.js';
import { createBookingWorld, newDraft, payDraft, transferOf, TEST_PAYER, type BookingWorld } from './support/booking_world.js';
import { createDisputeWorld, openInput, seedApprovedBooking, type DisputeWorld } from './support/dispute_world.js';
import { createTicketPaymentWorld, cu1, must, publishedEvent, START, type TicketPaymentWorld } from './support/event_world.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';
import { TEST_CIPHER } from './support/test_cipher.js';

const PRICE = 1_000_000;
const HOUR = 3_600_000;
const EV = 'ev1_aaaaaaaaaaaaaaaaaaaa';
/** The caller's display name as the adapter passes it to the fake lookup (normalised). */
const ECHO = normalizeHolderName('Nguyễn Thanh Hà');

const code = (c: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === c;

interface World {
  readonly b: BookingWorld;
  readonly t: TicketPaymentWorld;
  readonly d: DisputeWorld;
  readonly n: NotifyWorld;
  readonly deps: RefundAccountDeps;
}

function world(): World {
  const b = createBookingWorld();
  const t = createTicketPaymentWorld();
  const d = createDisputeWorld();
  const n = createNotifyWorld();
  return {
    b,
    t,
    d,
    n,
    deps: { bookings: b.deps, events: t.deps, disputes: d.deps, lookup: new FakeAccountNameLookup(ECHO), clock: b.clock },
  };
}

/** c1 pays a bank-QR booking (payer TEST_PAYER unless `payer: null`) and cancels it 5 days ahead (100%). */
async function cancelled(w: World, o: { readonly payer?: null; readonly action?: 'cancel' | 'decline' } = {}): Promise<{ bookingId: string; paymentId: string; refund: Refund }> {
  const draft = await newDraft(w.b);
  let paymentId: string;
  if (o.payer === null) {
    const p = await createPayment(w.b.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    await handleTransferNotification(w.b.deps, transferOf(w.b, { content: p.checkout.transferCode, amount: p.checkout.amount, payer: null }));
    paymentId = p.paymentId;
  } else {
    paymentId = (await payDraft(w.b, draft.id)).paymentId;
  }
  const action = o.action ?? 'cancel';
  await transitionBooking(w.b.deps, {
    bookingId: draft.id,
    action,
    actorId: action === 'cancel' ? 'c1' : 'p1',
    ...(action === 'cancel' ? { reason: 'Bận việc' } : {}),
  });
  const [refund] = await w.b.store.getRefundsForPayment(paymentId);
  assert.ok(refund);
  return { bookingId: draft.id, paymentId, refund };
}

const stored = async (w: World, id: string): Promise<Refund> => must(await w.b.store.getRefund(id));

describe('policy refunds of bank-QR payments wait for the account (S22.04)', () => {
  test('a customer cancel of a bank_qr booking creates an awaiting_account policy refund prefilled with the payer and confirmBy +24 h, not sent', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    const now = w.b.clock.now();
    assert.equal(refund.status, 'awaiting_account');
    assert.equal(refund.fromEscrow, true);
    assert.equal(refund.method, 'bank_transfer');
    assert.equal(refund.amount, PRICE);
    assert.deepEqual(
      [refund.destination?.source, refund.destination?.bankCode, refund.destination?.accountLast4, refund.destination?.holderName],
      ['payer', 'VCB', '3456', 'NGUYEN THANH HA'],
    );
    assert.equal(refund.confirmBy, new Date(now.getTime() + 24 * HOUR).toISOString());
    assert.equal(refund.lastAttemptAt, undefined);
    assert.equal(needsAccountChoice(refund), true);
    assert.deepEqual(w.b.gateway.refundCalls, []);
  });

  test('a decline of a bank_qr booking does the same and calls notifyRefundAccountNeeded once', async () => {
    const w = world();
    const { refund } = await cancelled(w, { action: 'decline' });
    assert.equal(refund.status, 'awaiting_account');
    assert.ok(refund.confirmBy);
    assert.deepEqual(w.b.gateway.refundCalls, []);

    const notifyDeps = { notify: w.n.deps, payments: w.b.store };
    assert.equal(await announceRefundAccountNeeded(notifyDeps, null, refund), 'notified');
    // A retried trigger calls the hook again with the same refund id; #138's dedupe keeps one row.
    assert.equal(await announceRefundAccountNeeded(notifyDeps, null, refund), 'notified');
    // A later write of the waiting refund (a looked-up candidate) is not a new wait.
    assert.equal(await announceRefundAccountNeeded(notifyDeps, refund, { ...refund, updatedAt: 'x' }), 'skipped');
    const rows = w.n.store.rowsOf('c1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.type, 'refund_account_needed');
    assert.equal(rows[0]?.target, '/me/payments');
    assert.equal(
      rows[0]?.body,
      'Bạn được hoàn 1.000.000₫. Sau 24 giờ tiền tự về tài khoản đã chuyển, hoặc chọn tài khoản khác.',
    );
  });

  test('a momo booking refund is sent at once (no window)', async () => {
    const w = world();
    const draft = await newDraft(w.b);
    const { paymentId } = await createPayment(w.b.deps, { bookingId: draft.id, customerId: 'c1', method: 'momo' });
    const p = must(await w.b.store.getPayment(paymentId));
    const at = w.b.clock.now().toISOString();
    await w.b.store.runTransaction(async (tx) => {
      await tx.setPayment({ ...p, status: 'paid', escrowStatus: 'held', receivedAmount: PRICE, paidAt: at, updatedAt: at });
      await tx.setBooking({ ...draft, status: 'requested', escrowStatus: 'held', depositProvider: 'fake', depositPaidAt: at, updatedAt: at });
    });
    await transitionBooking(w.b.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Đổi ý' });
    const [refund] = await w.b.store.getRefundsForPayment(paymentId);
    assert.deepEqual([refund?.status, refund?.method, refund?.confirmBy ?? null], ['done', 'gateway', null]);
    assert.deepEqual(w.b.gateway.refundCalls, [refund?.id]);
    assert.equal((await w.b.store.getBooking(draft.id))?.refundAccountNeeded ?? false, false);
  });

  test('an excess refund (overpaid) is sent at once to the payer', async () => {
    const w = world();
    const draft = await newDraft(w.b);
    const { paymentId, checkout } = await createPayment(w.b.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    await handleTransferNotification(w.b.deps, transferOf(w.b, { content: checkout.transferCode, amount: checkout.amount + 200_000 }));
    const [refund] = await w.b.store.getRefundsForPayment(paymentId);
    assert.deepEqual(
      [refund?.status, refund?.fromEscrow, refund?.amount, refund?.destination?.source, refund?.confirmBy ?? null],
      ['done', false, 200_000, 'payer', null],
    );
    assert.deepEqual(w.b.gateway.refundCalls, [refund?.id]);
  });

  test('no payer: awaiting_account with no confirmBy and the notification says "Chọn tài khoản để nhận tiền."', async () => {
    const w = world();
    const { refund } = await cancelled(w, { payer: null });
    assert.deepEqual([refund.status, refund.destination ?? null, refund.confirmBy ?? null], ['awaiting_account', null, null]);
    assert.equal(await announceRefundAccountNeeded({ notify: w.n.deps, payments: w.b.store }, null, refund), 'notified');
    assert.equal(w.n.store.rowsOf('c1')[0]?.body, 'Bạn được hoàn 1.000.000₫. Chọn tài khoản để nhận tiền.');
    // The 24-hour default never sends it anywhere.
    w.b.clock.advanceHours(48);
    assert.equal(await confirmDueRefundAccounts(w.deps, w.b.clock.now(), 10), 0);
    assert.equal((await stored(w, refund.id)).status, 'awaiting_account');
    assert.deepEqual(w.b.gateway.refundCalls, []);
  });

  test('booking.refundAccountNeeded is true while waiting and false after the choice', async () => {
    const w = world();
    const { bookingId, refund } = await cancelled(w);
    assert.equal((await w.b.store.getBooking(bookingId))?.refundAccountNeeded, true);
    assert.equal((await w.b.store.getBooking(bookingId))?.depositRefundedAt, undefined);
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' }), { status: 'done' });
    const b = must(await w.b.store.getBooking(bookingId));
    assert.equal(b.refundAccountNeeded, false);
    assert.ok(b.depositRefundedAt);
  });

  test('a ticket refund mirrors refundStatus awaiting_account', async () => {
    const w = world();
    await publishedEvent(w.t, { price: 150_000 });
    const r = await registerEvent(w.t.deps, cu1, { eventId: EV, quantity: 1, name: 'Nguyễn An', method: 'bank_qr' });
    await w.t.payTicket(must(r.paymentId), 'exact', cu1);
    w.t.clock.set(new Date(new Date(START).getTime() - 48 * HOUR));
    await cancelRegistration(w.t.deps, cu1, { eventId: EV, registrationId: r.registrationId });
    const reg = must(w.t.store.registrations.get(`${EV}/${r.registrationId}`));
    const refund = must(w.t.store.refunds.get(must(reg.refundId)));
    assert.deepEqual([reg.status, reg.refundStatus, refund.status, refund.destination?.source], ['refunded', 'awaiting_account', 'awaiting_account', 'payer']);
    assert.ok(refund.confirmBy);
    assert.deepEqual(w.t.gateway.refundCalls, []);

    const view = await pendingRefundFor(w.deps, { uid: 'cu1' }, { eventId: EV, registrationId: r.registrationId });
    assert.equal(view?.refundId, refund.id);
    // Choosing sends it through the ticket path; dispatchTicketRefund's mirror write follows.
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'cu1' }, { refundId: refund.id, use: 'payer' }), { status: 'done' });
    assert.deepEqual(w.t.gateway.refundCalls, [refund.id]);
    assert.equal(w.t.store.registrations.get(`${EV}/${r.registrationId}`)?.refundStatus, 'done');
  });
});

describe('pendingRefundFor', () => {
  test('pendingRefundFor returns amount, masked payer and confirmBy; null when nothing waits; another user → permission_denied', async () => {
    const w = world();
    const { bookingId, refund } = await cancelled(w);
    const view = await pendingRefundFor(w.deps, { uid: 'c1' }, { bookingId });
    assert.deepEqual(view, {
      refundId: refund.id,
      amount: PRICE,
      payer: { bankName: 'Vietcombank', accountLast4: '3456', holderName: 'NGUYEN THANH HA' },
      confirmBy: refund.confirmBy,
    });
    assert.equal(JSON.stringify(view).includes('accountNumberEnc'), false);
    await assert.rejects(pendingRefundFor(w.deps, { uid: 'c2' }, { bookingId }), code('permission_denied'));
    await assert.rejects(pendingRefundFor(w.deps, { uid: 'c1' }, { bookingId: 'nope' }), code('not_found'));
    await assert.rejects(pendingRefundFor(w.deps, { uid: 'c1' }, { bookingId: '../x' }), code('invalid_argument'));
    await assert.rejects(pendingRefundFor(w.deps, { uid: 'c1' }, {}), code('invalid_argument'));

    await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' });
    assert.equal(await pendingRefundFor(w.deps, { uid: 'c1' }, { bookingId }), null);
  });
});

describe('lookupRefundAccount', () => {
  test('lookupRefundAccount stores an encrypted candidate and returns the looked-up name (the caller\'s normalised name echoed by the fake)', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    const out = await lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'TCB', accountNumber: '1903 5555 1234' });
    assert.deepEqual(out, { holderName: 'NGUYEN THANH HA', bankName: 'Techcombank', accountLast4: '1234' });
    const s = await stored(w, refund.id);
    assert.equal(s.status, 'awaiting_account');
    assert.deepEqual(
      [s.candidate?.bankCode, s.candidate?.bankName, s.candidate?.accountLast4, s.candidate?.holderName],
      ['TCB', 'Techcombank', '1234', 'NGUYEN THANH HA'],
    );
    assert.equal(await TEST_CIPHER.decrypt(must(s.candidate).accountNumberEnc), '190355551234');
    assert.equal(JSON.stringify(s).includes('190355551234'), false);
    // The payer stays the prefilled destination until the customer chooses.
    assert.equal(s.destination?.source, 'payer');
    assert.deepEqual(w.b.gateway.refundCalls, []);
  });

  test('number ending 0404 → not_found; ending 4321 → found TRAN VAN B; ending 9999 → not_eligible', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    const ask = (accountNumber: string) => lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'VCB', accountNumber });
    await assert.rejects(ask('0011000404'), code('not_found'));
    assert.equal((await ask('0011004321')).holderName, 'TRAN VAN B');
    await assert.rejects(ask('0011009999'), code('not_eligible'));
    // A refused lookup leaves the last found candidate.
    assert.equal((await stored(w, refund.id)).candidate?.accountLast4, '4321');
  });

  test('a refund whose payment vanishes before the counting transaction → not_found, and the bank is never asked', async () => {
    const w = world();
    const { refund, paymentId } = await cancelled(w);
    let asked = 0;
    const lookup = { lookup: async (...a: Parameters<typeof w.deps.lookup.lookup>) => { asked += 1; return w.deps.lookup.lookup(...a); } };
    const store = w.b.store;
    const original = store.runTransaction.bind(store);
    // findRefund has read the refund and its payment; the payment goes before the first transaction.
    store.runTransaction = ((fn: Parameters<typeof original>[0]) => {
      store.payments.delete(paymentId);
      return original(fn);
    }) as typeof original;
    await assert.rejects(
      lookupRefundAccount({ ...w.deps, lookup }, { uid: 'c1' }, { refundId: refund.id, bankCode: 'VCB', accountNumber: '0011001234' }),
      code('not_found'),
    );
    assert.equal(asked, 0);
  });

  test('unknown bank → invalid_argument; bad number → invalid_argument; another user → permission_denied; refund not awaiting → conflict', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    const ask = (uid: string, raw: Record<string, unknown>) =>
      lookupRefundAccount(w.deps, { uid }, { refundId: refund.id, bankCode: 'VCB', accountNumber: '0011001234', ...raw });
    await assert.rejects(ask('c1', { bankCode: 'XXX' }), code('invalid_argument'));
    await assert.rejects(ask('c1', { accountNumber: '12' }), code('invalid_argument'));
    await assert.rejects(ask('c1', { refundId: 'missing' }), code('not_found'));
    await assert.rejects(ask('c2', {}), code('permission_denied'));
    await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' });
    await assert.rejects(ask('c1', {}), code('conflict'));
  });
});

describe('lookupRefundAccount cap (NAME_LOOKUPS_PER_DAY, like the payout lookup)', () => {
  test('every attempt counts on the refund\'s Vietnam day; the 21st is limit_exceeded and never reaches the bank; the next day starts again', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    let asked = 0;
    const lookup = new FakeAccountNameLookup(ECHO);
    const deps: RefundAccountDeps = { ...w.deps, lookup: { lookup: (r) => { asked += 1; return lookup.lookup(r); } } };
    const ask = (accountNumber: string) =>
      lookupRefundAccount(deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'VCB', accountNumber });
    // Refusals before the charge (bad input, another user) cost nothing.
    await assert.rejects(ask('12'), code('invalid_argument'));
    await assert.rejects(lookupRefundAccount(deps, { uid: 'c2' }, { refundId: refund.id, bankCode: 'VCB', accountNumber: '0011001234' }), code('permission_denied'));
    const numbers = ['0011000404', '0011009999', '0011001234', '0011004321'];
    for (let i = 0; i < 20; i++) {
      await ask(numbers[i % 4] ?? '').catch((e: unknown) => {
        if (!(e instanceof DomainError) || (e.code !== 'not_found' && e.code !== 'not_eligible')) throw e;
      });
    }
    assert.equal(asked, 20);
    assert.deepEqual((await stored(w, refund.id)).accountLookups, { day: '2026-10-10', count: 20 });
    await assert.rejects(ask('0011001234'), code('limit_exceeded'));
    assert.equal(asked, 20);
    // The Vietnam day changes at 17:00 UTC.
    w.b.clock.advanceHours(14);
    assert.equal((await ask('0011001234')).accountLast4, '1234');
    assert.deepEqual((await stored(w, refund.id)).accountLookups, { day: '2026-10-11', count: 1 });
    // The choice is unaffected by the cap.
    assert.deepEqual(
      await chooseRefundAccount(deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'VCB', accountLast4: '1234' }),
      { status: 'done' },
    );
  });
});

describe('chooseRefundAccount', () => {
  test('chooseRefundAccount payer → pending and dispatched to the payer account', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    w.b.gateway.refundThrowCount = 1;
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' }), { status: 'pending' });
    const s = await stored(w, refund.id);
    // Pending with an attempt stamped, so the payment clock's re-send picks it up.
    assert.deepEqual([s.status, s.attempts, s.destination?.source], ['pending', 1, 'payer']);
    assert.ok(s.lastAttemptAt);
    assert.deepEqual(w.b.gateway.refundRequests.get(refund.id)?.destination, {
      bankCode: TEST_PAYER.bankCode,
      accountNumber: TEST_PAYER.accountNumber,
      holderName: 'NGUYEN THANH HA',
    });
  });

  test('candidate → destination source customer', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    await lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'MB', accountNumber: '0011004321' });
    assert.deepEqual(
      await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'MB', accountLast4: '4321' }),
      { status: 'done' },
    );
    const s = await stored(w, refund.id);
    assert.deepEqual(
      [s.destination?.source, s.destination?.bankCode, s.destination?.accountLast4, s.destination?.holderName, s.candidate ?? null],
      ['customer', 'MB', '4321', 'TRAN VAN B', null],
    );
    assert.deepEqual(w.b.gateway.refundRequests.get(refund.id)?.destination, {
      bankCode: 'MB',
      accountNumber: '0011004321',
      holderName: 'TRAN VAN B',
    });
  });

  test('candidate missing → invalid_argument; payer missing → invalid_argument; bad input → invalid_argument; another user → permission_denied', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    await assert.rejects(
      chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'MB', accountLast4: '4321' }),
      code('invalid_argument'),
    );
    // A candidate choice names the account it was shown.
    await assert.rejects(chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate' }), code('invalid_argument'));
    await assert.rejects(
      chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'XXX', accountLast4: '4321' }),
      code('invalid_argument'),
    );
    await assert.rejects(
      chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'MB', accountLast4: '43' }),
      code('invalid_argument'),
    );
    await assert.rejects(chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'other' }), code('invalid_argument'));
    await assert.rejects(chooseRefundAccount(w.deps, { uid: 'c2' }, { refundId: refund.id, use: 'payer' }), code('permission_denied'));
    const none = world();
    const waiting = (await cancelled(none, { payer: null })).refund;
    await assert.rejects(chooseRefundAccount(none.deps, { uid: 'c1' }, { refundId: waiting.id, use: 'payer' }), code('invalid_argument'));
    assert.equal((await stored(w, refund.id)).status, 'awaiting_account');
    assert.deepEqual(w.b.gateway.refundCalls, []);
  });

  test('a second choose returns the current status without a second dispatch', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' }), { status: 'done' });
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' }), { status: 'done' });
    // Another account after the money went to the payer: refused, never reported as used.
    await assert.rejects(
      chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'MB', accountLast4: '4321' }),
      code('conflict'),
    );
    assert.deepEqual(w.b.gateway.refundCalls, [refund.id]);
  });

  test('a repeated candidate choice answers its status; the same refund chosen for another account → conflict', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    await lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'MB', accountNumber: '0011004321' });
    const mb = { refundId: refund.id, use: 'candidate', bankCode: 'MB', accountLast4: '4321' };
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, mb), { status: 'done' });
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, mb), { status: 'done' });
    await assert.rejects(chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' }), code('conflict'));
    assert.deepEqual(w.b.gateway.refundCalls, [refund.id]);
  });

  test('a candidate replaced by a later lookup cannot be committed: the shown account must match the stored one', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    // Lookup A, then lookup B (the account now on screen); A's answer is stale.
    await lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'MB', accountNumber: '0011004321' });
    await lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'VCB', accountNumber: '0011001234' });
    await assert.rejects(
      chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'MB', accountLast4: '4321' }),
      code('conflict'),
    );
    assert.equal((await stored(w, refund.id)).status, 'awaiting_account');
    assert.deepEqual(w.b.gateway.refundCalls, []);
    assert.deepEqual(
      await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'VCB', accountLast4: '1234' }),
      { status: 'done' },
    );
    const s = await stored(w, refund.id);
    assert.deepEqual([s.destination?.bankCode, s.destination?.accountLast4], ['VCB', '1234']);
  });

  test('a candidate choice that lost to the 24-hour default → conflict (the money went to the paying account)', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    await lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'MB', accountNumber: '0011004321' });
    w.b.clock.advanceHours(24);
    assert.equal(await confirmDueRefundAccounts(w.deps, w.b.clock.now(), 10), 1);
    await assert.rejects(
      chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'MB', accountLast4: '4321' }),
      code('conflict'),
    );
    assert.equal((await stored(w, refund.id)).destination?.source, 'payer');
    assert.deepEqual(w.b.gateway.refundCalls, [refund.id]);
  });

  test('a candidate choice racing the 24-hour default dispatches once; when it loses it answers conflict', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    await lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, bankCode: 'MB', accountNumber: '0011004321' });
    w.b.clock.advanceHours(24);
    const [chosen, sent] = await Promise.allSettled([
      chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'candidate', bankCode: 'MB', accountLast4: '4321' }),
      confirmDueRefundAccounts(w.deps, w.b.clock.now(), 10),
    ]);
    assert.equal(w.b.gateway.refundCalls.length, 1);
    const s = await stored(w, refund.id);
    if (s.destination?.source === 'customer') {
      assert.equal(chosen.status, 'fulfilled');
    } else {
      assert.equal(chosen.status, 'rejected');
      assert.equal(chosen.status === 'rejected' && chosen.reason instanceof DomainError ? chosen.reason.code : '', 'conflict');
    }
    assert.equal(sent.status, 'fulfilled');
  });

  test('choose and the 24-hour default racing dispatch once', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    w.b.clock.advanceHours(24);
    const [chosen, sent] = await Promise.all([
      chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' }),
      confirmDueRefundAccounts(w.deps, w.b.clock.now(), 10),
    ]);
    // The loser reads the winner's status: `pending` while its send is in flight, or `done`.
    assert.ok(chosen.status === 'pending' || chosen.status === 'done', chosen.status);
    assert.ok(sent === 0 || sent === 1);
    assert.equal(w.b.gateway.refundCalls.length, 1);
    assert.equal(w.b.gateway.issuedRefunds.get(refund.id), PRICE);
    assert.equal((await stored(w, refund.id)).status, 'done');
  });
});

describe('confirmDueRefundAccounts (payment clock step)', () => {
  test('confirmDueRefundAccounts sends due ones to the payer and leaves no-payer ones waiting', async () => {
    const w = world();
    const { bookingId, refund } = await cancelled(w);
    // A second customer's booking without a payer account.
    const draft = await newDraft(w.b, { customerId: 'c2', day: '2026-10-16' });
    const p = await createPayment(w.b.deps, { bookingId: draft.id, customerId: 'c2', method: 'bank_qr' });
    await handleTransferNotification(w.b.deps, transferOf(w.b, { content: p.checkout.transferCode, amount: p.checkout.amount, payer: null }));
    await transitionBooking(w.b.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c2', reason: 'Bận' });
    const [noPayer] = await w.b.store.getRefundsForPayment(p.paymentId);
    assert.ok(noPayer);

    w.b.clock.advanceHours(23);
    assert.equal(await confirmDueRefundAccounts(w.deps, w.b.clock.now(), 10), 0);
    w.b.clock.advanceHours(1);
    assert.equal(await confirmDueRefundAccounts(w.deps, w.b.clock.now(), 10), 1);
    const s = await stored(w, refund.id);
    assert.deepEqual([s.status, s.destination?.source], ['done', 'payer']);
    assert.equal((await w.b.store.getBooking(bookingId))?.refundAccountNeeded, false);
    assert.equal((await stored(w, noPayer.id)).status, 'awaiting_account');
    assert.deepEqual(w.b.gateway.refundCalls, [refund.id]);
    // Run again: nothing left to send.
    assert.equal(await confirmDueRefundAccounts(w.deps, w.b.clock.now(), 10), 0);
  });
});

describe('confirmDueRefundAccounts never starves on refunds it cannot send', () => {
  test('more than a batch of unsendable due refunds leave the queue (confirmBy cleared, or staff when the payment is gone); the sendable one goes on the next run', async () => {
    const w = world();
    const { refund } = await cancelled(w);
    const old = new Date(w.b.clock.now().getTime() - HOUR).toISOString();
    const at = w.b.clock.now().toISOString();
    await w.b.store.runTransaction(async (tx) => {
      await tx.setPayment({
        id: 'pay_i', subjectType: 'instant_request', subjectId: 'ir1', payerId: 'c1', payeeId: '', provider: 'fake',
        amount: 1_000, status: 'refunded', escrowStatus: 'refunded', idempotencyKey: 'k_i', method: 'bank_qr', createdAt: at, updatedAt: at,
      });
      for (let i = 0; i < 101; i++) {
        // 100 Chụp ngay refunds (not S22.04's), 1 whose payment is gone; all due before the real one.
        await tx.addRefund({
          id: `rf_skip_${String(i).padStart(3, '0')}`, paymentId: i === 100 ? 'pay_gone' : 'pay_i',
          subjectType: i === 100 ? 'booking' : 'instant_request', amount: 1_000, percent: 100, status: 'awaiting_account',
          manual: false, fromEscrow: true, method: 'bank_transfer', destination: null, confirmBy: old, attempts: 0, createdAt: old, updatedAt: old,
        });
      }
    });
    w.b.clock.advanceHours(24);
    assert.equal(await confirmDueRefundAccounts(w.deps, w.b.clock.now(), 100), 0);
    assert.equal(await confirmDueRefundAccounts(w.deps, w.b.clock.now(), 100), 1);
    assert.equal((await stored(w, refund.id)).status, 'done');
    assert.deepEqual(w.b.gateway.refundCalls, [refund.id]);
    const skipped = await stored(w, 'rf_skip_000');
    assert.deepEqual([skipped.status, skipped.confirmBy], ['awaiting_account', null]);
    const gone = await stored(w, 'rf_skip_100');
    assert.deepEqual([gone.status, gone.manual, gone.failureReason], ['failed', true, 'payment_missing']);
    assert.equal((await w.b.store.awaitingRefundsDue(w.b.clock.now(), 500)).length, 0);
  });
});

describe('dispute refunds (#142)', () => {
  async function disputed(w: World): Promise<{ payment: Payment; refund: Refund }> {
    seedApprovedBooking(w.d);
    const p = must(w.d.store.payments.get('pay_b1'));
    const payer = must(await payerAccountOf(TEST_CIPHER, TEST_PAYER));
    w.d.store.payments.set('pay_b1', { ...p, method: 'bank_qr', payer });
    await openDispute(w.d.deps, 'c1', openInput());
    const { refund } = await resolveDispute(w.d.deps, 'staff1', { disputeId: 'd1', outcome: 'refund', note: 'Đã xem bằng chứng' });
    return { payment: must(w.d.store.payments.get('pay_b1')), refund: must(refund) };
  }

  test('a dispute refund of a bank_qr payment waits for the account and is sent once', async () => {
    const w = world();
    const { payment, refund } = await disputed(w);
    assert.deepEqual([refund.status, refund.destination?.source], ['awaiting_account', 'payer']);
    assert.ok(refund.confirmBy);
    assert.equal((await dispatchDisputeRefund(w.d.deps, payment, refund)).status, 'awaiting_account');
    assert.deepEqual(w.d.gateway.refundCalls, []);

    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' }), { status: 'done' });
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: refund.id, use: 'payer' }), { status: 'done' });
    assert.deepEqual(w.d.gateway.refundCalls, [refund.id]);
    assert.equal(w.d.store.refunds.get(refund.id)?.status, 'done');
  });

  test('pendingRefundFor {disputeId} returns the dispute\'s waiting refund', async () => {
    const w = world();
    const { refund } = await disputed(w);
    const view = await pendingRefundFor(w.deps, { uid: 'c1' }, { disputeId: 'd1' });
    assert.deepEqual([view?.refundId, view?.amount, view?.payer?.accountLast4], [refund.id, refund.amount, '3456']);
    await assert.rejects(pendingRefundFor(w.deps, { uid: 'p1' }, { disputeId: 'd1' }), code('permission_denied'));
  });
});

describe('dispute refunds resolved through their booking or ticket (S22.01 rows)', () => {
  /** A waiting dispute-outcome refund of `payment`, in the dispute store (its own memory world here, one collection in Firestore). */
  async function disputeRefundOf(w: World, payment: Payment, over: Partial<Refund> = {}): Promise<Refund> {
    const payer = must(await payerAccountOf(TEST_CIPHER, TEST_PAYER));
    const at = w.b.clock.now().toISOString();
    const refund: Refund = {
      id: 'rf_dispute_a',
      paymentId: payment.id,
      subjectType: payment.subjectType,
      amount: 400_000,
      percent: 40,
      status: 'awaiting_account',
      manual: false,
      fromEscrow: true,
      method: 'bank_transfer',
      destination: { ...payer, source: 'payer' },
      confirmBy: new Date(w.b.clock.now().getTime() + 24 * HOUR).toISOString(),
      reason: 'dispute:d9',
      attempts: 0,
      createdAt: at,
      updatedAt: at,
      ...over,
    };
    w.d.store.payments.set(payment.id, payment);
    w.d.store.refunds.set(refund.id, refund);
    return refund;
  }

  test('pendingRefundFor {bookingId} finds the waiting dispute refund, and the choice commits on it', async () => {
    const w = world();
    const draft = await newDraft(w.b);
    const { paymentId } = await payDraft(w.b, draft.id);
    const refund = await disputeRefundOf(w, must(await w.b.store.getPayment(paymentId)));

    const view = await pendingRefundFor(w.deps, { uid: 'c1' }, { bookingId: draft.id });
    assert.deepEqual([view?.refundId, view?.amount, view?.payer?.accountLast4], [refund.id, 400_000, '3456']);
    await assert.rejects(pendingRefundFor(w.deps, { uid: 'c2' }, { bookingId: draft.id }), code('permission_denied'));

    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: must(view).refundId, use: 'payer' }), { status: 'done' });
    assert.deepEqual(w.d.gateway.refundCalls, [refund.id]);
    assert.equal(await pendingRefundFor(w.deps, { uid: 'c1' }, { bookingId: draft.id }), null);
  });

  test('pendingRefundFor {eventId, registrationId} finds the waiting dispute refund of the ticket payment, and the choice commits on it', async () => {
    const w = world();
    await publishedEvent(w.t, { price: 150_000 });
    const r = await registerEvent(w.t.deps, cu1, { eventId: EV, quantity: 1, name: 'Nguyễn An', method: 'bank_qr' });
    await w.t.payTicket(must(r.paymentId), 'exact', cu1);
    const refund = await disputeRefundOf(w, must(w.t.store.payments.get(must(r.paymentId))));

    const view = await pendingRefundFor(w.deps, { uid: 'cu1' }, { eventId: EV, registrationId: r.registrationId });
    assert.equal(view?.refundId, refund.id);
    await assert.rejects(
      pendingRefundFor(w.deps, { uid: 'c2' }, { eventId: EV, registrationId: r.registrationId }),
      code('permission_denied'),
    );
    assert.deepEqual(await chooseRefundAccount(w.deps, { uid: 'cu1' }, { refundId: refund.id, use: 'payer' }), { status: 'done' });
    assert.deepEqual(w.d.gateway.refundCalls, [refund.id]);
  });

  test('with two waiting refunds on a booking the oldest is shown (the cancellation before a later dispute outcome)', async () => {
    const w = world();
    const { bookingId, paymentId, refund: cancel } = await cancelled(w);
    const later = new Date(w.b.clock.now().getTime() + HOUR).toISOString();
    await disputeRefundOf(w, must(await w.b.store.getPayment(paymentId)), { createdAt: later, updatedAt: later });
    assert.equal((await pendingRefundFor(w.deps, { uid: 'c1' }, { bookingId }))?.refundId, cancel.id);
    // Once the oldest is chosen, the later one is next.
    await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: cancel.id, use: 'payer' });
    assert.equal((await pendingRefundFor(w.deps, { uid: 'c1' }, { bookingId }))?.refundId, 'rf_dispute_a');
  });

  test('chooseRefundAccount on an awaiting_account late_delivery booking refund moves it to pending and dispatches it', async () => {
    const w = world();
    const draft = await newDraft(w.b);
    const p = await createPayment(w.b.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    await handleTransferNotification(w.b.deps, transferOf(w.b, { content: p.checkout.transferCode, amount: p.checkout.amount, payer: null }));
    const at = w.b.clock.now().toISOString();
    const refund: Refund = {
      id: 'rf_late_1',
      paymentId: p.paymentId,
      subjectType: 'booking',
      amount: 500_000,
      percent: 50,
      status: 'awaiting_account',
      manual: false,
      fromEscrow: true,
      method: 'bank_transfer',
      destination: null,
      reason: 'late_delivery',
      attempts: 0,
      createdAt: at,
      updatedAt: at,
    };
    await w.b.store.runTransaction(async (tx) => {
      await tx.addRefund(refund);
    });

    await lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: 'rf_late_1', bankCode: 'TCB', accountNumber: '1903 5555 1234' });
    w.b.gateway.refundPendingIds.add('rf_late_1');
    const out = await chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: 'rf_late_1', use: 'candidate', bankCode: 'TCB', accountLast4: '1234' });
    assert.deepEqual(out, { status: 'pending' });
    assert.deepEqual(w.b.gateway.refundCalls, ['rf_late_1']);
    assert.equal((await stored(w, 'rf_late_1')).status, 'pending');
  });
});

describe('subjects outside S22.04', () => {
  test('a Chụp ngay refund waiting without a payer is not chosen, not confirmed and not announced here (not_eligible)', async () => {
    const w = world();
    const at = w.b.clock.now().toISOString();
    const payment: Payment = {
      id: 'pay_i1', subjectType: 'instant_request', subjectId: 'ir1', payerId: 'c1', payeeId: '', provider: 'fake',
      amount: 500_000, status: 'refunded', escrowStatus: 'refunded', idempotencyKey: 'k_i1', method: 'bank_qr',
      createdAt: at, updatedAt: at,
    };
    const refund: Refund = {
      id: 'rf_i1', paymentId: 'pay_i1', subjectType: 'instant_request', amount: 500_000, percent: 100,
      status: 'awaiting_account', manual: false, fromEscrow: true, method: 'bank_transfer', destination: null,
      confirmBy: at, attempts: 0, createdAt: at, updatedAt: at,
    };
    await w.b.store.runTransaction(async (tx) => {
      await tx.setPayment(payment);
      await tx.addRefund(refund);
    });
    await assert.rejects(chooseRefundAccount(w.deps, { uid: 'c1' }, { refundId: 'rf_i1', use: 'payer' }), code('not_eligible'));
    await assert.rejects(
      lookupRefundAccount(w.deps, { uid: 'c1' }, { refundId: 'rf_i1', bankCode: 'VCB', accountNumber: '0011001234' }),
      code('not_eligible'),
    );
    assert.equal(await confirmDueRefundAccounts(w.deps, w.b.clock.now(), 10), 0);
    assert.equal(await announceRefundAccountNeeded({ notify: w.n.deps, payments: w.b.store }, null, refund), 'skipped');
    assert.equal((await stored(w, 'rf_i1')).status, 'awaiting_account');
    assert.deepEqual(w.b.gateway.refundCalls, []);
  });
});

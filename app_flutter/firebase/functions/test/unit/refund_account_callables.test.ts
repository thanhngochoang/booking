import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { normalizeHolderName, transitionBooking, type RefundAccountDeps } from '@photobooking/domain';
import {
  handleChooseRefundAccount,
  handleLookupRefundAccount,
  handlePendingRefund,
} from '../../src/callables/refund_account.js';
import { captureLogs } from './support/payment_world.js';

const { createBookingWorld, newDraft, payDraft } = await import('../../../../../packages/domain/test/support/booking_world.js');
const { refundAccountDepsOf } = await import('../../../../../packages/domain/test/support/refund_account_world.js');

/** c1 paid a bank-QR booking and cancelled it: its refund waits for the account (S22.04). */
async function waitingRefund(): Promise<{ deps: RefundAccountDeps; bookingId: string; refundId: string; calls: () => number }> {
  const w = createBookingWorld();
  const draft = await newDraft(w);
  const { paymentId } = await payDraft(w, draft.id);
  await transitionBooking(w.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
  const [refund] = await w.store.getRefundsForPayment(paymentId);
  assert.equal(refund?.status, 'awaiting_account');
  return {
    deps: refundAccountDepsOf({ bookings: w.deps, echoName: normalizeHolderName('Nguyễn Thanh Hà') }),
    bookingId: draft.id,
    refundId: refund?.id ?? '',
    calls: () => w.gateway.refundCalls.length,
  };
}

const as = (uid: string | undefined, data: unknown) => ({ auth: uid === undefined ? undefined : { uid }, data });

const rejectsWith = (p: Promise<unknown>, transport: string, code: string) =>
  assert.rejects(p, (e: unknown) => e instanceof HttpsError && e.code === transport && e.message === code);

describe('S22.04 refund account callables (#141)', () => {
  it('pendingRefund, lookupRefundAccount and chooseRefundAccount run for the signed-in payer', async () => {
    const w = await waitingRefund();
    const view = await handlePendingRefund(as('c1', { bookingId: w.bookingId }), w.deps);
    assert.deepEqual([view?.refundId, view?.payer?.accountLast4], [w.refundId, '3456']);
    const found = await handleLookupRefundAccount(
      as('c1', { refundId: w.refundId, bankCode: 'VCB', accountNumber: '0011001234' }),
      w.deps,
    );
    assert.deepEqual(found, { holderName: 'NGUYEN THANH HA', bankName: 'Vietcombank', accountLast4: '1234' });
    assert.deepEqual(
      await handleChooseRefundAccount(as('c1', { refundId: w.refundId, use: 'candidate', bankCode: 'VCB', accountLast4: '1234' }), w.deps),
      { status: 'done' },
    );
    assert.equal(w.calls(), 1);
    assert.equal(await handlePendingRefund(as('c1', { bookingId: w.bookingId }), w.deps), null);
  });

  it('lookupRefundAccount logs only the code, never the number', async (t) => {
    const w = await waitingRefund();
    const lines = await captureLogs(t, async () => {
      await rejectsWith(
        handleLookupRefundAccount(as('c1', { refundId: w.refundId, bankCode: 'VCB', accountNumber: '0011000404' }), w.deps),
        'not-found',
        'not_found',
      );
      await handleLookupRefundAccount(as('c1', { refundId: w.refundId, bankCode: 'VCB', accountNumber: '0011004321' }), w.deps);
    });
    const logged = lines.filter((l) => l.includes('lookupRefundAccount'));
    assert.ok(logged.length >= 1, lines.join(''));
    for (const l of lines) {
      assert.doesNotMatch(l, /0011000404|0011004321|0404|4321|TRAN VAN B|NGUYEN/, l);
    }
    assert.match(logged.join(''), /not_found/);
  });

  it('errors map (not_found → not-found, not_eligible → failed-precondition)', async () => {
    const w = await waitingRefund();
    const lookup = (accountNumber: string, uid = 'c1', bankCode = 'VCB') =>
      handleLookupRefundAccount(as(uid, { refundId: w.refundId, bankCode, accountNumber }), w.deps);
    await rejectsWith(lookup('0011000404'), 'not-found', 'not_found');
    await rejectsWith(lookup('0011009999'), 'failed-precondition', 'not_eligible');
    await rejectsWith(lookup('0011001234', 'c1', 'XXX'), 'invalid-argument', 'invalid_argument');
    await rejectsWith(lookup('0011001234', 'c2'), 'permission-denied', 'permission_denied');
    await rejectsWith(handlePendingRefund(as('c2', { bookingId: w.bookingId }), w.deps), 'permission-denied', 'permission_denied');
    await rejectsWith(
      handleChooseRefundAccount(as('c1', { refundId: w.refundId, use: 'candidate', bankCode: 'VCB', accountLast4: '1234' }), w.deps),
      'invalid-argument',
      'invalid_argument',
    );
    // A stored candidate other than the one shown, or a refund the default already sent: aborted/conflict.
    await handleLookupRefundAccount(as('c1', { refundId: w.refundId, bankCode: 'VCB', accountNumber: '0011004321' }), w.deps);
    await rejectsWith(
      handleChooseRefundAccount(as('c1', { refundId: w.refundId, use: 'candidate', bankCode: 'VCB', accountLast4: '1234' }), w.deps),
      'aborted',
      'conflict',
    );
    await rejectsWith(handlePendingRefund(as(undefined, { bookingId: w.bookingId }), w.deps), 'unauthenticated', 'permission_denied');
    await handleChooseRefundAccount(as('c1', { refundId: w.refundId, use: 'payer' }), w.deps);
    await rejectsWith(lookup('0011001234'), 'aborted', 'conflict');
    await rejectsWith(
      handleChooseRefundAccount(as('c1', { refundId: w.refundId, use: 'candidate', bankCode: 'VCB', accountLast4: '4321' }), w.deps),
      'aborted',
      'conflict',
    );
    assert.equal(w.calls(), 1);
  });
});

describe('S22.04 on FirestoreBookingStore (strict fake: no read after a write in a transaction)', () => {
  it('lookup, choose and the 24-hour default read everything before their first write', async () => {
    const { strictFirestore } = await import('./strict_firestore_support.js');
    const { FirestoreBookingStore, bookingToFirestore, paymentToFirestore, refundToFirestore, refundFromFirestore, bookingFromFirestore } =
      await import('../../src/infra/booking_firestore.js');
    const { lookupRefundAccount, chooseRefundAccount, confirmDueRefundAccounts } = await import('@photobooking/domain');

    // Two cancelled bank-QR bookings of c1 in a memory world, copied into the strict fake.
    const w = createBookingWorld();
    const ids: { bookingId: string; paymentId: string; refundId: string }[] = [];
    for (const day of ['2026-10-15', '2026-10-16']) {
      const draft = await newDraft(w, { day });
      const { paymentId } = await payDraft(w, draft.id);
      await transitionBooking(w.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
      const [refund] = await w.store.getRefundsForPayment(paymentId);
      ids.push({ bookingId: draft.id, paymentId, refundId: refund?.id ?? '' });
    }
    const docs: Record<string, Record<string, unknown>> = {};
    for (const { bookingId, paymentId, refundId } of ids) {
      const [b, p, r] = [await w.store.getBooking(bookingId), await w.store.getPayment(paymentId), await w.store.getRefund(refundId)];
      assert.ok(b && p && r);
      docs[`bookings/${bookingId}`] = bookingToFirestore(b);
      docs[`payments/${paymentId}`] = paymentToFirestore(p);
      docs[`refunds/${refundId}`] = refundToFirestore(r);
    }
    const fake = strictFirestore(docs);
    const bookings = { ...w.deps, store: new FirestoreBookingStore(fake.firestore) };
    const deps = refundAccountDepsOf({ bookings, echoName: 'NGUYEN THANH HA' });
    const [first, second] = ids;
    assert.ok(first && second);

    await lookupRefundAccount(deps, { uid: 'c1' }, { refundId: first.refundId, bankCode: 'MB', accountNumber: '0011004321' });
    assert.equal(refundFromFirestore(first.refundId, docs[`refunds/${first.refundId}`])?.candidate?.accountLast4, '4321');
    assert.deepEqual(
      await chooseRefundAccount(deps, { uid: 'c1' }, { refundId: first.refundId, use: 'candidate', bankCode: 'MB', accountLast4: '4321' }),
      { status: 'done' },
    );
    assert.equal(refundFromFirestore(first.refundId, docs[`refunds/${first.refundId}`])?.destination?.source, 'customer');
    assert.equal(bookingFromFirestore(first.bookingId, docs[`bookings/${first.bookingId}`])?.refundAccountNeeded, false);

    // The fake ignores `confirmBy <=`; the claim re-checks it in its transaction.
    assert.equal(await confirmDueRefundAccounts(deps, w.clock.now(), 10), 0);
    w.clock.advanceHours(24);
    assert.equal(await confirmDueRefundAccounts(deps, w.clock.now(), 10), 1);
    assert.equal(refundFromFirestore(second.refundId, docs[`refunds/${second.refundId}`])?.status, 'done');
    assert.equal(bookingFromFirestore(second.bookingId, docs[`bookings/${second.bookingId}`])?.refundAccountNeeded, false);
    assert.deepEqual(w.gateway.refundCalls, [first.refundId, second.refundId]);
    // Never a plain account number in a stored document.
    assert.equal(JSON.stringify(docs).includes('0011004321'), false);
  });
});

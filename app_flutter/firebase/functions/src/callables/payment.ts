/**
 * Booking payment callables (S04.03 "Thanh toán", S04.04 "Tạo QR mới" / "Kiểm tra lại", #129
 * Decision 13): thin adapters around the domain use cases.
 */

import { HttpsError } from 'firebase-functions/v2/https';
import {
  DomainError,
  assertPaymentPayer,
  checkPayment,
  createPayment,
  type Booking,
  type BookingDeps,
  type CreatePaymentResult,
  type TransferOutcome,
} from '@photobooking/domain';
import { assertFakePaymentsAllowed, checkoutGatewayAvailable } from '../infra/fake_payments.js';
import { FAKE_SIGNATURE_HEADER, fakeWebhookSecret, signFakeWebhook } from '../infra/fake_webhook.js';
import { handlePaymentWebhook } from '../http/payment_webhook.js';
import { handleCallableError } from './booking.js';
import type { CallableInput } from './get_contact_link.js';

type Env = Readonly<Record<string, string | undefined>>;

/** What `confirmFakePayment` simulates: the mis-transfer table of payments spec §3.3. */
export const FAKE_TRANSFER_KINDS = ['exact', 'under', 'over', 'wrong_content'] as const;
export type FakeTransferKind = (typeof FAKE_TRANSFER_KINDS)[number];

/** `over` sends this much above the amount (VND); the excess is refunded. */
export const FAKE_OVERPAY_VND = 50_000;
/** `wrong_content`: a memo without any transfer code (staff review). */
export const FAKE_WRONG_CONTENT = 'CHUYEN TIEN';

const isKind = (v: unknown): v is FakeTransferKind =>
  typeof v === 'string' && (FAKE_TRANSFER_KINDS as readonly string[]).includes(v);

function uidOf(request: CallableInput): string {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  return uid;
}

const dataOf = (request: CallableInput): Record<string, unknown> =>
  (request.data && typeof request.data === 'object' ? request.data : {}) as Record<string, unknown>;

/**
 * `{bookingId, method}` → `{paymentId, checkout}`; the booking's `checkout` mirrors it.
 * Refused with `not_eligible` (the app shows `bookPaymentsOff`) before any read or write wherever
 * no real gateway is wired and fake payments are not allowed (`checkoutGatewayAvailable`).
 */
export async function handleCreatePayment(
  request: CallableInput,
  deps: BookingDeps,
  env: Env = process.env,
): Promise<CreatePaymentResult> {
  const uid = uidOf(request);
  try {
    if (!checkoutGatewayAvailable(env)) throw new DomainError('not_eligible');
    const data = dataOf(request);
    return await createPayment(deps, { bookingId: String(data.bookingId ?? ''), customerId: uid, method: data.method });
  } catch (e) {
    handleCallableError('createPayment', e);
  }
}

/** `{bookingId}` → `{paid, booking}`: asks the provider about the current payment ("Kiểm tra lại"). */
export async function handleCheckPayment(
  request: CallableInput,
  deps: BookingDeps,
): Promise<{ readonly paid: boolean; readonly booking: Booking | null }> {
  const uid = uidOf(request);
  try {
    const data = dataOf(request);
    return await checkPayment(deps, { bookingId: String(data.bookingId ?? ''), customerId: uid });
  } catch (e) {
    handleCallableError('checkPayment', e);
  }
}

/**
 * `{paymentId, kind?}` → `{outcome}`: the payer simulates a bank transfer to their own payment
 * (emulator and dev project only). It builds the fake provider's body for `kind` (default `exact`),
 * signs it with the webhook secret and runs the webhook handler in-process, so it takes exactly
 * the path a real notification takes.
 */
export async function handleConfirmFakePayment(
  request: CallableInput,
  deps: BookingDeps,
  env: Env = process.env,
): Promise<{ readonly outcome: TransferOutcome }> {
  const uid = uidOf(request);
  // Security: a payer may pay their own payment with fake money only on the emulator or the dev
  // project; checked before any read.
  assertFakePaymentsAllowed(env);
  try {
    const data = dataOf(request);
    const kind = data.kind ?? 'exact';
    if (!isKind(kind)) throw new DomainError('invalid_argument');
    const payment = await assertPaymentPayer(deps, String(data.paymentId ?? ''), uid);
    // Only checkout payments (createPayment) have a transfer code; anything else cannot be paid this way.
    if (payment.subjectType !== 'booking' || payment.transferCode === undefined) throw new DomainError('conflict');

    const secret = fakeWebhookSecret(env);
    if (secret === undefined) throw new Error('FAKE_PAYMENT_WEBHOOK_SECRET is not set');

    const now = deps.clock.now();
    const amount =
      kind === 'under' ? Math.floor(payment.amount / 2) : kind === 'over' ? payment.amount + FAKE_OVERPAY_VND : payment.amount;
    const rawBody = JSON.stringify({
      txnId: `fake_${payment.id}_${kind}_${now.getTime()}`,
      amount,
      content: kind === 'wrong_content' ? FAKE_WRONG_CONTENT : payment.transferCode,
      receivedAt: now.toISOString(),
    });
    const res = await handlePaymentWebhook(
      { provider: 'fake', rawBody, headers: { [FAKE_SIGNATURE_HEADER]: signFakeWebhook(rawBody, secret) } },
      deps,
      env,
    );
    const outcome = res.body.outcome;
    if (res.status !== 200 || typeof outcome !== 'string') throw new Error(`fake webhook answered ${res.status}`);
    return { outcome: outcome as TransferOutcome };
  } catch (e) {
    handleCallableError('confirmFakePayment', e);
  }
}

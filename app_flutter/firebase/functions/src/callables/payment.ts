/**
 * Booking payment callables (S04.03 "Thanh toán", S04.04 "Tạo QR mới" / "Kiểm tra lại", #129
 * Decision 13): thin adapters around the domain use cases.
 */

import { HttpsError } from 'firebase-functions/v2/https';
import {
  DomainError,
  asSettlement,
  checkPayment,
  createPayment,
  fakeTransferFor,
  readPaymentInstructions,
  FAKE_OVERPAY_VND,
  FAKE_TRANSFER_KINDS,
  FAKE_WRONG_CONTENT,
  type Booking,
  type BookingDeps,
  type CreatePaymentResult,
  type FakeTransferKind,
  type PaymentInstructions,
  type SettlementDeps,
  type TransferOutcome,
} from '@photobooking/domain';
import { assertFakePaymentsAllowed, checkoutGatewayAvailable } from '../infra/fake_payments.js';
import { FAKE_SIGNATURE_HEADER, fakeWebhookSecret, signFakeWebhook } from '../infra/fake_webhook.js';
import { handlePaymentWebhook } from '../http/payment_webhook.js';
import { handleCallableError } from './booking.js';
import type { CallableInput } from './get_contact_link.js';

type Env = Readonly<Record<string, string | undefined>>;

export { FAKE_TRANSFER_KINDS, FAKE_OVERPAY_VND, FAKE_WRONG_CONTENT, type FakeTransferKind };

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
  deps: SettlementDeps | BookingDeps,
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

    const d = asSettlement(deps);
    const paymentId = String(data.paymentId ?? '');
    const payment = await d.payments.getPayment(paymentId);
    if (!payment) throw new DomainError('not_found');
    if (payment.payerId !== uid) throw new DomainError('permission_denied');
    if (payment.transferCode === undefined) throw new DomainError('conflict');
    if (!d.subjects[payment.subjectType]) throw new DomainError('not_eligible');

    const secret = fakeWebhookSecret(env);
    if (secret === undefined) throw new Error('FAKE_PAYMENT_WEBHOOK_SECRET is not set');

    const now = d.clock.now();
    const fakeTransfer = fakeTransferFor(
      payment as typeof payment & { readonly transferCode: string },
      kind,
      now,
    );
    const rawBody = JSON.stringify({
      txnId: fakeTransfer.txnId,
      amount: fakeTransfer.amount,
      content: fakeTransfer.content,
      receivedAt: fakeTransfer.receivedAt,
      payer: fakeTransfer.payer,
    });
    const res = await handlePaymentWebhook(
      { provider: 'fake', rawBody, headers: { [FAKE_SIGNATURE_HEADER]: signFakeWebhook(rawBody, secret) } },
      d,
      env,
    );
    const outcome = res.body.outcome;
    if (res.status !== 200 || typeof outcome !== 'string') throw new Error(`fake webhook answered ${res.status}`);
    return { outcome: outcome as TransferOutcome };
  } catch (e) {
    handleCallableError('confirmFakePayment', e);
  }
}

/**
 * `{paymentId}` → `{instructions: PaymentInstructions | null}`:
 * payer only; instructions of a `created` payment, else null.
 */
export async function handleGetPaymentInstructions(
  request: CallableInput,
  deps: SettlementDeps,
): Promise<{ readonly instructions: PaymentInstructions | null }> {
  const uid = uidOf(request);
  try {
    const instructions = await readPaymentInstructions(deps, { uid }, dataOf(request));
    return { instructions };
  } catch (e) {
    handleCallableError('getPaymentInstructions', e);
  }
}

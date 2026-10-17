/**
 * `paymentWebhook`: the payment provider reports one incoming transfer (payments spec §3.3,
 * #129 Decision 4), or a refund's final outcome (V2 Decision 9). Thin adapter: authenticate the
 * request (signature), parse it, and hand a `TransferNotification` to the domain (`settleTransfer`,
 * idempotent by `${provider}_${txnId}`, which stores the raw body on `payment_notifications/{id}`)
 * or a `RefundEvent` to `applyRefundEvent` (idempotent by the refund's stored state).
 *
 * Responses: 200 `{ok:true,outcome}` when processed or a duplicate; 401 bad or missing signature;
 * 400 bad body; 404 unknown provider, or the fake provider where fake payments are not allowed;
 * 405 not a POST; 500 missing secret or a transient failure (the provider retries).
 * Logs carry the provider, the txnId and the outcome only, never the body or the payer.
 */

import * as logger from 'firebase-functions/logger';
import {
  applyRefundEvent,
  asSettlement,
  bookingDepsOf,
  isDomainError,
  settleTransfer,
  type BookingDeps,
  type RefundSubjects,
  type SettlementDeps,
} from '@photobooking/domain';
import { fakePaymentsAllowed } from '../infra/fake_payments.js';
import {
  FAKE_SIGNATURE_HEADER,
  fakeWebhookSecret,
  parseFakeWebhook,
  verifyFakeWebhook,
  type FakeWebhookBody,
} from '../infra/fake_webhook.js';

type Env = Readonly<Record<string, string | undefined>>;

export interface WebhookRequest {
  /** `?provider=` of the request. */
  readonly provider: string | undefined;
  /** The request body exactly as received (utf8), never re-serialised: the signature covers these bytes. */
  readonly rawBody: string;
  /** Header names in lower case (as Node gives them). */
  readonly headers: Readonly<Record<string, string | undefined>>;
}

export interface WebhookResponse {
  readonly status: number;
  readonly body: Record<string, unknown>;
}

const refuse = (status: number, error: string): WebhookResponse => ({ status, body: { ok: false, error } });

export async function handlePaymentWebhook(
  req: WebhookRequest,
  deps: SettlementDeps | BookingDeps,
  env: Env = process.env,
  refundSubjects?: RefundSubjects,
): Promise<WebhookResponse> {
  // The fake provider is the only one so far; it does not exist where real money could move.
  if (req.provider !== 'fake' || !fakePaymentsAllowed(env)) return refuse(404, 'unknown_provider');

  const secret = fakeWebhookSecret(env);
  if (secret === undefined) {
    logger.error('paymentWebhook not configured', { provider: req.provider });
    return refuse(500, 'internal');
  }
  if (!verifyFakeWebhook(req.rawBody, req.headers[FAKE_SIGNATURE_HEADER], secret)) {
    logger.warn('paymentWebhook refused', { provider: req.provider, reason: 'bad_signature' });
    return refuse(401, 'bad_signature');
  }

  let parsed: FakeWebhookBody;
  try {
    parsed = parseFakeWebhook(req.rawBody);
  } catch {
    logger.warn('paymentWebhook refused', { provider: req.provider, reason: 'invalid_argument' });
    return refuse(400, 'invalid_argument');
  }

  if (parsed.kind === 'refund') {
    const e = parsed.event;
    try {
      // Refunds of every subject live in the booking store's refunds collection.
      const bookingDeps = bookingDepsOf(deps);
      if (bookingDeps === null) {
        logger.warn('paymentWebhook refund event without a booking settler', { provider: e.provider, refundId: e.refundId });
      }
      const outcome = bookingDeps === null ? 'refund_unknown' : await applyRefundEvent(bookingDeps, e, refundSubjects);
      logger.info('paymentWebhook handled', { provider: e.provider, refundId: e.refundId, outcome });
      return { status: 200, body: { ok: true, outcome } };
    } catch (err) {
      if (isDomainError(err) && err.code === 'invalid_argument') {
        logger.warn('paymentWebhook refused', { provider: e.provider, refundId: e.refundId, reason: 'invalid_argument' });
        return refuse(400, 'invalid_argument');
      }
      logger.error('paymentWebhook failed', { provider: e.provider, refundId: e.refundId, ...(err instanceof Error ? { name: err.name } : {}) });
      return refuse(500, 'internal');
    }
  }

  const n = parsed.transfer;
  try {
    const { outcome } = await settleTransfer(asSettlement(deps), n);
    logger.info('paymentWebhook handled', { provider: n.provider, txnId: n.txnId, outcome });
    return { status: 200, body: { ok: true, outcome } };
  } catch (e) {
    if (isDomainError(e) && e.code === 'invalid_argument') {
      logger.warn('paymentWebhook refused', { provider: n.provider, txnId: n.txnId, reason: 'invalid_argument' });
      return refuse(400, 'invalid_argument');
    }
    logger.error('paymentWebhook failed', { provider: n.provider, txnId: n.txnId, ...(e instanceof Error ? { name: e.name } : {}) });
    return refuse(500, 'internal');
  }
}

/** The parts of an Express request the webhook reads (`onRequest` gives a firebase-functions Request). */
export interface HttpRequestLike {
  readonly method: string;
  readonly query: Readonly<Record<string, unknown>>;
  readonly headers: Readonly<Record<string, string | string[] | undefined>>;
  readonly rawBody: Buffer;
}

export interface HttpResponseLike {
  status(code: number): HttpResponseLike;
  set(name: string, value: string): HttpResponseLike;
  json(body: unknown): unknown;
}

/** HTTP adapter of `paymentWebhook`: POST only, the raw bytes as utf8, `?provider=`. */
export async function servePaymentWebhook(
  req: HttpRequestLike,
  res: HttpResponseLike,
  deps: SettlementDeps | BookingDeps,
  env: Env = process.env,
  refundSubjects?: RefundSubjects,
): Promise<void> {
  if (req.method !== 'POST') {
    res.status(405).set('Allow', 'POST').json({ ok: false, error: 'method_not_allowed' });
    return;
  }
  const headers: Record<string, string | undefined> = {};
  for (const [name, value] of Object.entries(req.headers)) {
    headers[name.toLowerCase()] = Array.isArray(value) ? value[0] : value;
  }
  const provider = typeof req.query.provider === 'string' ? req.query.provider : undefined;
  const rawBody = Buffer.isBuffer(req.rawBody) ? req.rawBody.toString('utf8') : '';
  const out = await handlePaymentWebhook({ provider, rawBody, headers }, deps, env, refundSubjects);
  res.status(out.status).json(out.body);
}

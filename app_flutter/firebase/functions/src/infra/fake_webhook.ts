/**
 * The fake payment provider's webhook scheme (#129 Decisions 3 and 4). It stands in for the licensed
 * intermediary on the emulator and the dev project; the real provider's scheme and secret come with
 * its own unit. HMAC lives here, not in packages/domain (no Node imports there): the domain receives
 * an already verified `TransferNotification`.
 *
 * - Header `x-pb-signature: sha256=<hex>`, the HMAC-SHA256 of the raw request body with
 *   `FAKE_PAYMENT_WEBHOOK_SECRET` (a self-made test value, not a Secret Manager secret).
 * - Body: `{ txnId, amount (integer VND), content, receivedAt (ISO-8601), payer?: { bankCode?,
 *   accountMasked?, name? } }`.
 */

import { createHmac, timingSafeEqual } from 'node:crypto';
import { DomainError, type TransferNotification } from '@photobooking/domain';

type Env = Readonly<Record<string, string | undefined>>;

export const FAKE_SIGNATURE_HEADER = 'x-pb-signature';

const PREFIX = 'sha256=';
/** The txnId becomes part of a document id (`fake_<txnId>`): no `/`, bounded length. */
const TXN_ID = /^[A-Za-z0-9_.:-]{1,128}$/;
const MAX_CONTENT = 512;
const MAX_PAYER_FIELD = 128;

/** `FAKE_PAYMENT_WEBHOOK_SECRET`; an empty value counts as missing. */
export function fakeWebhookSecret(env: Env = process.env): string | undefined {
  const secret = env.FAKE_PAYMENT_WEBHOOK_SECRET;
  return secret !== undefined && secret !== '' ? secret : undefined;
}

/** `sha256=` + the hex HMAC-SHA256 of `rawBody` (utf8) with `secret`. */
export function signFakeWebhook(rawBody: string, secret: string): string {
  return PREFIX + createHmac('sha256', secret).update(rawBody, 'utf8').digest('hex');
}

/** Constant-time check of the signature header; false when it is missing or of another length. */
export function verifyFakeWebhook(rawBody: string, header: string | undefined, secret: string): boolean {
  if (header === undefined) return false;
  const expected = Buffer.from(signFakeWebhook(rawBody, secret), 'utf8');
  const given = Buffer.from(header, 'utf8');
  if (given.length !== expected.length) return false;
  return timingSafeEqual(given, expected);
}

const invalid = (): never => {
  throw new DomainError('invalid_argument');
};

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

function parsePayer(v: unknown): TransferNotification['payer'] {
  if (v === undefined || v === null) return undefined;
  if (!isRecord(v)) return invalid();
  const payer: { bankCode?: string; accountMasked?: string; name?: string } = {};
  for (const key of ['bankCode', 'accountMasked', 'name'] as const) {
    const field = v[key];
    if (field === undefined) continue;
    if (typeof field !== 'string' || field.length > MAX_PAYER_FIELD) return invalid();
    payer[key] = field;
  }
  return payer;
}

/**
 * The verified raw body as a `TransferNotification` of the `fake` provider, `raw` kept as received
 * and `receivedAt` normalised to UTC ISO-8601 (matching compares it with the payment's createdAt).
 * Throws DomainError('invalid_argument') on any other shape.
 */
export function parseFakeTransfer(rawBody: string): TransferNotification {
  let body: unknown;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return invalid();
  }
  if (!isRecord(body)) return invalid();
  const { txnId, amount, content, receivedAt } = body;
  if (typeof txnId !== 'string' || !TXN_ID.test(txnId)) return invalid();
  if (typeof amount !== 'number' || !Number.isSafeInteger(amount) || amount <= 0) return invalid();
  if (typeof content !== 'string' || content.length > MAX_CONTENT) return invalid();
  if (typeof receivedAt !== 'string') return invalid();
  const receivedMs = Date.parse(receivedAt);
  if (Number.isNaN(receivedMs)) return invalid();
  const payer = parsePayer(body.payer);
  return {
    provider: 'fake',
    txnId,
    amount,
    content,
    receivedAt: new Date(receivedMs).toISOString(),
    raw: rawBody,
    ...(payer !== undefined ? { payer } : {}),
  };
}

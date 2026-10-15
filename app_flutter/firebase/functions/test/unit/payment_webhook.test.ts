import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '@photobooking/domain';
import {
  FAKE_SIGNATURE_HEADER,
  fakeWebhookSecret,
  parseFakeTransfer,
  signFakeWebhook,
  verifyFakeWebhook,
} from '../../src/infra/fake_webhook.js';
import { handlePaymentWebhook, servePaymentWebhook } from '../../src/http/payment_webhook.js';
import { PROD_ENV, SECRET, WEBHOOK_ENV, captureLogs, openPayment, paymentWorld, type PaymentWorld } from './support/payment_world.js';

const RECEIVED_AT = '2026-10-01T10:01:00.000Z';

function bodyOf(p: { txnId?: string; amount: number; content: string; receivedAt?: string; payer?: unknown }): string {
  return JSON.stringify({ txnId: p.txnId ?? 'txn_0001', amount: p.amount, content: p.content, receivedAt: p.receivedAt ?? RECEIVED_AT, ...(p.payer ? { payer: p.payer } : {}) });
}

function signed(rawBody: string, provider: string | undefined = 'fake') {
  return { provider, rawBody, headers: { [FAKE_SIGNATURE_HEADER]: signFakeWebhook(rawBody, SECRET) } };
}

const ledgerCount = async (w: PaymentWorld, paymentId: string) => (await w.store.getLedgerEntriesForPayment(paymentId)).length;

describe('fake webhook signature', () => {
  it('signFakeWebhook/verifyFakeWebhook round-trip and reject a one-byte change', () => {
    const raw = bodyOf({ amount: 1_000_000, content: 'PB 7F3K2Q' });
    const sig = signFakeWebhook(raw, SECRET);
    assert.match(sig, /^sha256=[0-9a-f]{64}$/);
    assert.equal(verifyFakeWebhook(raw, sig, SECRET), true);
    assert.equal(verifyFakeWebhook(raw.replace('1000000', '1000001'), sig, SECRET), false);
    const flipped = sig.slice(0, -1) + (sig.endsWith('0') ? '1' : '0');
    assert.equal(verifyFakeWebhook(raw, flipped, SECRET), false);
    assert.equal(verifyFakeWebhook(raw, sig, 'another-secret'), false);
    assert.equal(verifyFakeWebhook(raw, undefined, SECRET), false);
    assert.equal(verifyFakeWebhook(raw, sig.slice(0, 20), SECRET), false, 'a shorter header is false, not a throw');
    assert.equal(verifyFakeWebhook(raw, sig.replace('sha256=', ''), SECRET), false);
  });

  it('the secret comes from FAKE_PAYMENT_WEBHOOK_SECRET; empty is missing', () => {
    assert.equal(fakeWebhookSecret({ FAKE_PAYMENT_WEBHOOK_SECRET: 'x' }), 'x');
    assert.equal(fakeWebhookSecret({ FAKE_PAYMENT_WEBHOOK_SECRET: '' }), undefined);
    assert.equal(fakeWebhookSecret({}), undefined);
  });

  it('parseFakeTransfer keeps the raw body, normalises receivedAt to UTC and refuses bad shapes', () => {
    const raw = bodyOf({ amount: 500_000, content: 'PB 7F3K2Q', receivedAt: '2026-10-01T17:01:00+07:00', payer: { bankCode: 'VCB', name: 'NGUYEN VAN A' } });
    const n = parseFakeTransfer(raw);
    assert.equal(n.provider, 'fake');
    assert.equal(n.txnId, 'txn_0001');
    assert.equal(n.amount, 500_000);
    assert.equal(n.content, 'PB 7F3K2Q');
    assert.equal(n.receivedAt, RECEIVED_AT);
    assert.equal(n.raw, raw);
    assert.deepEqual(n.payer, { bankCode: 'VCB', name: 'NGUYEN VAN A' });

    const bad = (s: string) => assert.throws(() => parseFakeTransfer(s), (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument', s);
    bad('not json');
    bad('[]');
    bad('null');
    bad(JSON.stringify({ amount: 1, content: 'x', receivedAt: RECEIVED_AT }));
    bad(bodyOf({ txnId: '', amount: 1, content: 'x' }));
    bad(bodyOf({ txnId: 'a/b', amount: 1, content: 'x' }));
    bad(bodyOf({ amount: 0, content: 'x' }));
    bad(bodyOf({ amount: 1.5, content: 'x' }));
    bad(bodyOf({ amount: -10, content: 'x' }));
    bad(JSON.stringify({ txnId: 't', amount: '100', content: 'x', receivedAt: RECEIVED_AT }));
    bad(JSON.stringify({ txnId: 't', amount: 100, receivedAt: RECEIVED_AT }));
    bad(bodyOf({ amount: 1, content: 'x', receivedAt: 'yesterday' }));
    bad(JSON.stringify({ txnId: 't', amount: 100, content: 'x', receivedAt: 1_790_000_000_000 }));
    bad(bodyOf({ amount: 1, content: 'x', payer: 'NGUYEN VAN A' }));
    bad(bodyOf({ amount: 1, content: 'x', payer: { name: 42 } }));
  });
});

describe('handlePaymentWebhook (fake provider)', () => {
  it('a valid signed exact transfer returns 200 paid and stores the raw body', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({ amount: p.amount, content: `CK ${p.transferCode} chup anh` });
    const res = await handlePaymentWebhook(signed(raw), w.deps, WEBHOOK_ENV);
    assert.deepEqual(res, { status: 200, body: { ok: true, outcome: 'paid' } });
    assert.equal(w.store.transferRecords.get('fake_txn_0001')?.raw, raw);
    assert.equal(w.store.transferRecords.get('fake_txn_0001')?.paymentId, p.paymentId);
    assert.equal((await w.store.getPayment(p.paymentId))?.status, 'paid');
    assert.equal((await w.store.getBooking(p.bookingId))?.status, 'requested');
  });

  it('a bad signature returns 401 and writes nothing', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({ amount: p.amount, content: p.transferCode });
    const res = await handlePaymentWebhook(
      { provider: 'fake', rawBody: raw, headers: { [FAKE_SIGNATURE_HEADER]: signFakeWebhook(raw, 'wrong-secret') } },
      w.deps,
      WEBHOOK_ENV,
    );
    assert.equal(res.status, 401);
    assert.equal(res.body.ok, false);
    assert.equal(w.store.transferRecords.size, 0);
    assert.equal(await ledgerCount(w, p.paymentId), 0);
    assert.equal((await w.store.getPayment(p.paymentId))?.status, 'created');
  });

  it('a missing signature returns 401', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const res = await handlePaymentWebhook(
      { provider: 'fake', rawBody: bodyOf({ amount: p.amount, content: p.transferCode }), headers: {} },
      w.deps,
      WEBHOOK_ENV,
    );
    assert.equal(res.status, 401);
    assert.equal(w.store.transferRecords.size, 0);
  });

  it('a malformed body returns 400', async () => {
    const w = paymentWorld();
    for (const raw of ['{"txnId":', bodyOf({ amount: 0, content: 'PB' }), bodyOf({ amount: 1, content: 'x', receivedAt: 'soon' })]) {
      const res = await handlePaymentWebhook(signed(raw), w.deps, WEBHOOK_ENV);
      assert.equal(res.status, 400, raw);
      assert.deepEqual(res.body, { ok: false, error: 'invalid_argument' });
    }
    assert.equal(w.store.transferRecords.size, 0);
  });

  it('an unknown provider returns 404', async () => {
    const w = paymentWorld();
    const raw = bodyOf({ amount: 1_000, content: 'x' });
    for (const provider of ['momo', 'vnpay', '', undefined]) {
      // (`signed` defaults an undefined provider to 'fake', so the request is built here.)
      const res = await handlePaymentWebhook({ ...signed(raw), provider }, w.deps, WEBHOOK_ENV);
      assert.equal(res.status, 404, String(provider));
    }
  });

  it('the fake provider on a production project returns 404', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({ amount: p.amount, content: p.transferCode });
    const res = await handlePaymentWebhook(signed(raw), w.deps, PROD_ENV);
    assert.equal(res.status, 404);
    assert.equal(w.store.transferRecords.size, 0);
    assert.equal((await w.store.getPayment(p.paymentId))?.status, 'created');
  });

  it('a repeated delivery returns 200 duplicate and writes once', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({ amount: p.amount, content: p.transferCode });
    assert.deepEqual(await handlePaymentWebhook(signed(raw), w.deps, WEBHOOK_ENV), { status: 200, body: { ok: true, outcome: 'paid' } });
    assert.deepEqual(await handlePaymentWebhook(signed(raw), w.deps, WEBHOOK_ENV), { status: 200, body: { ok: true, outcome: 'duplicate' } });
    assert.equal(w.store.transferRecords.size, 1);
    const received = (await w.store.getLedgerEntriesForPayment(p.paymentId)).filter((e) => e.type === 'payment_received');
    assert.equal(received.length, 1);
  });

  it('a missing secret returns 500', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({ amount: p.amount, content: p.transferCode });
    const { FAKE_PAYMENT_WEBHOOK_SECRET: _unused, ...noSecret } = WEBHOOK_ENV;
    void _unused;
    const res = await handlePaymentWebhook(signed(raw), w.deps, noSecret);
    assert.equal(res.status, 500);
    assert.equal(w.store.transferRecords.size, 0);
  });

  it('a transient failure returns 500 so the provider retries', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({ amount: p.amount, content: p.transferCode });
    const failing = { ...w.deps, store: Object.assign(Object.create(w.store) as typeof w.store, {
      runTransaction: async () => { throw new Error('ABORTED: contention'); },
    }) };
    const res = await handlePaymentWebhook(signed(raw), failing, WEBHOOK_ENV);
    assert.equal(res.status, 500);
    assert.equal(res.body.ok, false);
  });

  it('a transfer that names no payment is 200 needs_review', async () => {
    const w = paymentWorld();
    const res = await handlePaymentWebhook(signed(bodyOf({ amount: 200_000, content: 'CHUYEN TIEN' })), w.deps, WEBHOOK_ENV);
    assert.deepEqual(res, { status: 200, body: { ok: true, outcome: 'needs_review' } });
    assert.equal(w.store.transferRecords.get('fake_txn_0001')?.outcome, 'needs_review');
  });

  it('logs the provider, the txnId and the outcome, never the body or the payer', async (t) => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({ amount: p.amount, content: `${p.transferCode} LE THI SECRET`, payer: { name: 'LE THI SECRET', accountMasked: '•••• 9876' } });
    const lines = await captureLogs(t, () => handlePaymentWebhook(signed(raw), w.deps, WEBHOOK_ENV));
    const logged = lines.filter((l) => l.includes('paymentWebhook'));
    assert.equal(logged.length, 1, lines.join(''));
    assert.match(logged[0] ?? '', /"provider":"fake"/);
    assert.match(logged[0] ?? '', /"txnId":"txn_0001"/);
    assert.match(logged[0] ?? '', /"outcome":"paid"/);
    for (const l of lines) {
      assert.doesNotMatch(l, /SECRET|9876/, l);
      assert.doesNotMatch(l, new RegExp(p.transferCode), l);
    }
  });

  it('a transfer with payer.accountNumber stores the payer encrypted on the payment and redacts raw', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({
      amount: p.amount,
      content: p.transferCode,
      payer: { bankCode: 'VCB', accountNumber: '0071000123456', name: 'NGUYEN THANH HA' },
    });
    const res = await handlePaymentWebhook(signed(raw), w.deps, WEBHOOK_ENV);
    assert.deepEqual(res, { status: 200, body: { ok: true, outcome: 'paid' } });

    const pay = await w.store.getPayment(p.paymentId);
    assert.ok(pay?.payer);
    assert.equal(pay?.payer?.bankCode, 'VCB');
    assert.equal(pay?.payer?.accountLast4, '3456');
    assert.equal(pay?.payer?.holderName, 'NGUYEN THANH HA');
    assert.doesNotMatch(pay?.payer?.accountNumberEnc ?? '', /0071000123456/);

    const rec = w.store.transferRecords.get('fake_txn_0001');
    assert.ok(rec);
    assert.doesNotMatch(rec.raw ?? '', /0071000123456/);
    assert.match(rec.raw ?? '', /•••• 3456/);
  });

  it('a refund body done moves the refund to done (200 refund_applied)', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const at = '2026-10-01T10:00:00.000Z';
    await w.store.runTransaction(async (tx) => {
      tx.setPayment({
        id: p.paymentId,
        subjectType: 'booking',
        subjectId: p.bookingId,
        payerId: 'c1',
        payeeId: 'p1',
        provider: 'fake',
        amount: 1_000_000,
        status: 'paid',
        escrowStatus: 'held',
        idempotencyKey: 'idem_1',
        createdAt: at,
        updatedAt: at,
      });
      tx.addRefund({
        id: 'ref_1',
        paymentId: p.paymentId,
        subjectType: 'booking',
        amount: 1_000_000,
        percent: 100,
        status: 'pending',
        method: 'gateway',
        attempts: 1,
        manual: false,
        fromEscrow: true,
        createdAt: at,
        updatedAt: at,
      });
    });

    const refundBody = JSON.stringify({
      type: 'refund',
      refundId: 'ref_1',
      status: 'done',
      providerRef: 'pref_1',
    });
    const res = await handlePaymentWebhook(signed(refundBody), w.deps, WEBHOOK_ENV);
    assert.deepEqual(res, { status: 200, body: { ok: true, outcome: 'refund_applied' } });
    const ref = await w.store.getRefund('ref_1');
    assert.equal(ref?.status, 'done');
    assert.equal(ref?.providerRef, 'pref_1');
  });

  it('a refund body for an unknown id answers 200 refund_unknown', async () => {
    const w = paymentWorld();
    const refundBody = JSON.stringify({
      type: 'refund',
      refundId: 'ref_unknown_999',
      status: 'done',
    });
    const res = await handlePaymentWebhook(signed(refundBody), w.deps, WEBHOOK_ENV);
    assert.deepEqual(res, { status: 200, body: { ok: true, outcome: 'refund_unknown' } });
  });

  it('a refund body with a bad signature is 401', async () => {
    const w = paymentWorld();
    const refundBody = JSON.stringify({ type: 'refund', refundId: 'ref_1', status: 'done' });
    const res = await handlePaymentWebhook(
      { provider: 'fake', rawBody: refundBody, headers: { [FAKE_SIGNATURE_HEADER]: signFakeWebhook(refundBody, 'wrong') } },
      w.deps,
      WEBHOOK_ENV,
    );
    assert.equal(res.status, 401);
  });

  it('a refund body with a bad status is 400', async () => {
    const w = paymentWorld();
    const refundBody = JSON.stringify({ type: 'refund', refundId: 'ref_1', status: 'invalid_status' });
    const res = await handlePaymentWebhook(signed(refundBody), w.deps, WEBHOOK_ENV);
    assert.equal(res.status, 400);
  });
});

describe('servePaymentWebhook (HTTP adapter)', () => {
  function fakeRes() {
    const out: { status?: number; body?: unknown; headers: Record<string, string> } = { headers: {} };
    const res = {
      status(code: number) { out.status = code; return res; },
      set(name: string, value: string) { out.headers[name] = value; return res; },
      json(body: unknown) { out.body = body; return res; },
    };
    return { res, out };
  }

  it('a GET returns 405 and touches nothing', async () => {
    const w = paymentWorld();
    const { res, out } = fakeRes();
    await servePaymentWebhook({ method: 'GET', query: { provider: 'fake' }, headers: {}, rawBody: Buffer.from('') }, res, w.deps, WEBHOOK_ENV);
    assert.equal(out.status, 405);
    assert.equal(out.headers.Allow, 'POST');
  });

  it('a POST passes the raw bytes (not re-serialised JSON) and the provider from the query', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    // Spacing and key order a re-serialisation would change: the signature covers these exact bytes.
    const raw = `{ "content": "${p.transferCode}",  "amount": ${p.amount}, "txnId": "txn_0001", "receivedAt": "${RECEIVED_AT}" }`;
    const { res, out } = fakeRes();
    await servePaymentWebhook(
      {
        method: 'POST',
        query: { provider: 'fake' },
        headers: { [FAKE_SIGNATURE_HEADER]: signFakeWebhook(raw, SECRET), 'content-type': 'application/json' },
        rawBody: Buffer.from(raw, 'utf8'),
      },
      res,
      w.deps,
      WEBHOOK_ENV,
    );
    assert.equal(out.status, 200);
    assert.deepEqual(out.body, { ok: true, outcome: 'paid' });
    assert.equal(w.store.transferRecords.get('fake_txn_0001')?.raw, raw);
  });

  it('a repeated header (array) uses its first value; no provider is 404', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const raw = bodyOf({ amount: p.amount, content: p.transferCode });
    const sig = signFakeWebhook(raw, SECRET);
    const a = fakeRes();
    await servePaymentWebhook({ method: 'POST', query: { provider: 'fake' }, headers: { [FAKE_SIGNATURE_HEADER]: [sig, 'x'] }, rawBody: Buffer.from(raw) }, a.res, w.deps, WEBHOOK_ENV);
    assert.equal(a.out.status, 200);
    const b = fakeRes();
    await servePaymentWebhook({ method: 'POST', query: {}, headers: { [FAKE_SIGNATURE_HEADER]: sig }, rawBody: Buffer.from(raw) }, b.res, w.deps, WEBHOOK_ENV);
    assert.equal(b.out.status, 404);
  });
});

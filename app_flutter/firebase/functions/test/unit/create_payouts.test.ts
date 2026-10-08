import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import {
  DEFAULT_PAYOUT_POLICY,
  FakePayoutGateway,
  MemoryBookingStore,
  MemoryPayoutStore,
  type Payment,
  type Payout,
  type PayoutDeps,
  type PayoutStore,
} from '@photobooking/domain';
import { CREATE_PAYOUTS_OPTIONS, PAYOUT_ACCOUNT_KEY, REGION } from '../../src/config.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { handleCreatePayouts } from '../../src/scheduled/create_payouts.js';
import { captureLogs } from './support/payment_world.js';

const NOW = new Date('2026-10-10T03:00:00.000Z');
const T = NOW.toISOString();
const EARLIER = '2026-10-01T03:00:00.000Z';
const KEY = Buffer.alloc(32, 7).toString('base64');
const NUMBER = '0123456789';

const payment = (id: string, payeeId: string, amount: number): Payment => ({
  id, subjectType: 'booking', subjectId: `b-${id}`, payerId: 'c1', payeeId, provider: 'fake',
  amount, status: 'paid', escrowStatus: 'released', idempotencyKey: `k-${id}`, createdAt: T, updatedAt: T,
});

/** An earlier payout to a1 that was paid, so the next one needs no approval. */
const paidBefore: Payout = {
  id: 'po0', payeeId: 'p1', accountId: 'a1', amount: 100_000, status: 'paid',
  items: [{ paymentId: 'old', amount: 100_000, fee: 0, tax: 7_000, net: 93_000 }],
  platformFee: 0, taxWithheld: 7_000, amountNet: 93_000, feeRateBp: 0, taxRateBp: 700, firstPayout: true,
  approvedBy: 's1', approvedAt: EARLIER, createdBy: 's1', createdAt: EARLIER, updatedAt: EARLIER, paidAt: EARLIER,
};

describe('createPayouts job', () => {
  let booking: MemoryBookingStore;
  let store: MemoryPayoutStore;
  let needed: { payeeId: string; amount: number }[];
  let n: number;
  const cipher = aesGcmCipher(KEY);
  const deps = (s: PayoutStore = store): PayoutDeps => ({
    store: s,
    cipher,
    gateway: new FakePayoutGateway(),
    clock: { now: () => NOW },
    ids: { newId: () => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n++).padStart(2, '0')}` },
    policy: DEFAULT_PAYOUT_POLICY,
    notices: {
      accountNeeded: async (payeeId, amount) => void needed.push({ payeeId, amount }),
      accountChanged: async () => undefined,
    },
  });
  const addAccount = async (uid: string, id: string) =>
    store.accounts.set(`${uid}/${id}`, {
      id, userId: uid, bankCode: 'VCB', accountNumberEnc: await cipher.encrypt(NUMBER), accountLast4: '6789',
      holderName: 'NGUYEN VAN AN', active: true, createdAt: EARLIER, nameStatus: 'matched', activeFrom: EARLIER,
    });

  beforeEach(async () => {
    booking = new MemoryBookingStore();
    store = new MemoryPayoutStore(booking);
    needed = [];
    n = 10;
    booking.payments.set('pay1', payment('pay1', 'p1', 450_000));
    booking.payments.set('pay2', payment('pay2', 'p2', 300_000));
    await addAccount('p1', 'a1');
    store.seedPayout(paidBefore);
  });

  it('off mode creates nothing and returns null', async (t) => {
    let result: unknown = 'unset';
    const lines = await captureLogs(t, async () => {
      result = await handleCreatePayouts(deps(), 'off');
    });
    assert.equal(result, null);
    assert.deepEqual([...store.payouts.keys()], ['po0']);
    assert.equal(booking.payments.get('pay1')?.payoutId ?? null, null);
    assert.deepEqual(needed, []);
    assert.equal(lines.filter((l) => l.includes('createPayouts skipped')).length, 1, lines.join(''));
  });

  it('fake mode runs the daily payouts and logs the report', async (t) => {
    let report = null as Awaited<ReturnType<typeof handleCreatePayouts>>;
    const lines = await captureLogs(t, async () => {
      report = await handleCreatePayouts(deps(), 'fake');
    });
    const expected = { created: 1, needsApproval: 0, onHold: 0, executed: 1, paid: 1, failed: 0, noAccount: 1, notActive: 0, errors: 0 };
    assert.deepEqual(report, expected);
    const created = [...store.payouts.values()].find((p) => p.id !== 'po0');
    assert.equal(created?.status, 'paid');
    assert.equal(created?.taxWithheld, 31_500);
    assert.equal(created?.amountNet, 418_500);
    assert.equal(booking.payments.get('pay1')?.escrowStatus, 'paid_out');
    assert.deepEqual(needed, [{ payeeId: 'p2', amount: 300_000 }]);

    const logged = lines.filter((l) => /"message":"createPayouts"/.test(l));
    assert.equal(logged.length, 1, lines.join(''));
    const { severity: _s, message: _m, ...fields } = JSON.parse(logged[0] ?? '{}') as Record<string, unknown>;
    void _s;
    void _m;
    assert.deepEqual(fields, expected);
    for (const l of lines) assert.doesNotMatch(l, new RegExp(NUMBER), l);
  });

  it('a thrown error of one payee is logged with the payee id and code only', async (t) => {
    booking.payments.set('pay3', payment('pay3', 'p3', 200_000));
    await addAccount('p3', 'a3');
    const failing: PayoutStore = {
      listDuePayees: () => store.listDuePayees(),
      listPayoutIdsByStatus: (s, l) => store.listPayoutIdsByStatus(s, l),
      runTransaction: (fn) =>
        store.runTransaction((tx) =>
          fn({
            ...tx,
            getActiveAccount: async (uid) => {
              if (uid === 'p3') throw new Error(`bank refused ${NUMBER} of NGUYEN VAN AN`);
              return tx.getActiveAccount(uid);
            },
          }),
        ),
    };
    let report = null as Awaited<ReturnType<typeof handleCreatePayouts>>;
    const lines = await captureLogs(t, async () => {
      report = await handleCreatePayouts(deps(failing), 'fake');
    });
    // p1 is still created and paid; p3's failure is counted.
    assert.equal(report?.errors, 1);
    assert.equal(report?.paid, 1);
    assert.equal(booking.payments.get('pay3')?.payoutId ?? null, null);

    const failed = lines.filter((l) => l.includes('createPayouts item failed'));
    assert.equal(failed.length, 1, lines.join(''));
    const { severity, message: _m, ...fields } = JSON.parse(failed[0] ?? '{}') as Record<string, unknown>;
    void _m;
    assert.equal(severity, 'ERROR');
    assert.deepEqual(fields, { id: 'p3', step: 'create', code: 'Error' });
    for (const l of lines) assert.doesNotMatch(l, /0123456789|NGUYEN|bank refused/, l);
  });

  it('a failure of the whole run is logged by code and rethrown', async (t) => {
    const broken: PayoutStore = {
      runTransaction: (fn) => store.runTransaction(fn),
      listPayoutIdsByStatus: (s, l) => store.listPayoutIdsByStatus(s, l),
      listDuePayees: async () => {
        throw new Error(`index missing for ${NUMBER}`);
      },
    };
    const lines = await captureLogs(t, () => assert.rejects(handleCreatePayouts(deps(broken), 'fake')));
    const logged = lines.filter((l) => l.includes('createPayouts failed'));
    assert.equal(logged.length, 1, lines.join(''));
    assert.match(logged[0] ?? '', /"code":"Error"/);
    for (const l of lines) assert.doesNotMatch(l, new RegExp(NUMBER), l);
  });

  it('runs daily at 10:00 Vietnam time, one instance, no retry, 540 s, with the account key', () => {
    assert.equal(CREATE_PAYOUTS_OPTIONS.schedule, '0 10 * * *');
    assert.equal(CREATE_PAYOUTS_OPTIONS.timeZone, 'Asia/Ho_Chi_Minh');
    assert.equal(CREATE_PAYOUTS_OPTIONS.region, REGION);
    assert.equal(CREATE_PAYOUTS_OPTIONS.maxInstances, 1);
    assert.equal(CREATE_PAYOUTS_OPTIONS.retryCount, 0);
    assert.equal(CREATE_PAYOUTS_OPTIONS.timeoutSeconds, 540);
    assert.deepEqual(CREATE_PAYOUTS_OPTIONS.secrets, [PAYOUT_ACCOUNT_KEY]);
  });
});

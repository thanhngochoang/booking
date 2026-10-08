import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import {
  DEFAULT_PAYOUT_POLICY,
  FakePayoutGateway,
  MemoryBookingStore,
  MemoryPayoutStore,
  approvePayout,
  type Payment,
  type PayoutDeps,
} from '@photobooking/domain';
import { cliPayoutsMode, devProjectFromFirebaserc, parseArgs, runCli, type CliIo } from '../../tools/payouts.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { payoutGateway } from '../../src/infra/live_payout.js';
import { payoutsMode } from '../../src/config.js';

const NOW = new Date('2026-10-10T12:00:00.000Z');
const KEY = Buffer.alloc(32, 5).toString('base64');
const T = NOW.toISOString();

const payment = (id: string, over: Partial<Payment> = {}): Payment => ({
  id, subjectType: 'booking', subjectId: `b-${id}`, payerId: 'c1', payeeId: 'p1', provider: 'fake',
  amount: 300_000, status: 'paid', escrowStatus: 'released', idempotencyKey: `k-${id}`, createdAt: T, updatedAt: T, ...over,
});

describe('payouts staff CLI', () => {
  let booking: MemoryBookingStore;
  let store: MemoryPayoutStore;
  let out: string[];
  let admin: boolean;
  let n: number;
  const cipher = aesGcmCipher(KEY);
  const deps = (gateway = new FakePayoutGateway()): PayoutDeps => ({
    store, cipher, gateway, clock: { now: () => NOW },
    ids: { newId: () => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n++).padStart(2, '0')}` },
    policy: DEFAULT_PAYOUT_POLICY,
    notices: { accountNeeded: async () => undefined, accountChanged: async () => undefined },
  });
  /** The first payout to an account waits for staff (the CLI's `approve` comes with the daily run). */
  const approve = (id: string) => approvePayout(deps(), { uid: 's1', isAdmin: true }, id);
  const io: CliIo = {
    print: (s) => void out.push(s),
    isAdmin: async () => admin,
    listOpenPayouts: async () => [...store.payouts.values()].filter((p) => p.status !== 'paid' && p.status !== 'failed'),
  };

  beforeEach(async () => {
    booking = new MemoryBookingStore();
    store = new MemoryPayoutStore(booking);
    store.seedRole('p1', 'photographer');
    out = [];
    admin = true;
    n = 10;
    booking.payments.set('pay1', payment('pay1'));
    booking.payments.set('pay2', payment('pay2', { escrowStatus: 'held' }));
    store.accounts.set('p1/a1', {
      id: 'a1', userId: 'p1', bankCode: 'VCB', accountNumberEnc: await cipher.encrypt('0123456789'),
      accountLast4: '6789', holderName: 'NGUYEN VAN AN', active: true, createdAt: T,
      nameStatus: 'matched', activeFrom: T,
    });
  });

  it('parses commands and the actor', () => {
    assert.deepEqual(parseArgs(['hold', 'po1', 'Kiểm tra tài khoản', '--actor', 's1']), { command: 'hold', target: 'po1', reason: 'Kiểm tra tài khoản', actor: 's1' });
    assert.throws(() => parseArgs(['hold', 'po1']), /reason/);
    assert.throws(() => parseArgs(['bogus']), /usage/);
    assert.throws(() => parseArgs(['show']), /missing/);
  });

  it('due lists payees with released money', async () => {
    await runCli(['due'], deps(), io, 'fake');
    assert.deepEqual(out, ['p1  300,000 VND  account']);
  });

  it('create needs --actor and the admin claim', async () => {
    await assert.rejects(runCli(['create', 'p1'], deps(), io, 'fake'), /--actor/);
    admin = false;
    await assert.rejects(runCli(['create', 'p1', '--actor', 's1'], deps(), io, 'fake'), /admin claim/);
    assert.equal(store.payouts.size, 0);
  });

  it('create, hold, resume and execute walk a payout through', async () => {
    await runCli(['create', 'p1', '--actor', 's1'], deps(), io, 'fake');
    const id = [...store.payouts.keys()][0] as string;
    assert.equal(store.payouts.get(id)?.status, 'needs_approval');
    await approve(id);
    await runCli(['hold', id, 'Kiểm tra tài khoản', '--actor', 's1'], deps(), io, 'fake');
    assert.equal(store.payouts.get(id)?.status, 'on_hold');
    await runCli(['resume', id, '--actor', 's1'], deps(), io, 'fake');
    // The approval given before the hold is kept.
    assert.equal(store.payouts.get(id)?.status, 'pending');
    await runCli(['execute', id, '--actor', 's1'], deps(), io, 'fake');
    assert.equal(store.payouts.get(id)?.status, 'paid');
    assert.equal(booking.payments.get('pay1')?.escrowStatus, 'paid_out');
    assert.equal(booking.payments.get('pay2')?.escrowStatus, 'held');
  });

  it('execute refuses outside fake mode and changes nothing', async () => {
    await runCli(['create', 'p1', '--actor', 's1'], deps(), io, 'fake');
    const id = [...store.payouts.keys()][0] as string;
    await approve(id);
    await assert.rejects(runCli(['execute', id, '--actor', 's1'], deps(), io, 'off'), /no real bank adapter/);
    assert.equal(store.payouts.get(id)?.status, 'pending');
  });

  it('the off-mode gateway throws not_eligible and the modes follow the environment', async () => {
    await assert.rejects(
      payoutGateway('off').transfer({ payoutId: 'x', amount: 1, bankCode: 'VCB', accountNumber: '1', holderName: 'A' }),
      (e: unknown) => (e as { code?: string }).code === 'not_eligible',
    );
    assert.equal(payoutsMode({}), 'off');
    assert.equal(payoutsMode({ FUNCTIONS_EMULATOR: 'true' }), 'fake');
    assert.equal(payoutsMode({ PAYOUTS_MODE: 'fake' }), 'fake');
    assert.equal(cliPayoutsMode({ FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' }), 'fake');
    assert.equal(cliPayoutsMode({}), 'off');
  });

  it('PAYOUTS_MODE=fake works only in the dev project of .firebaserc', () => {
    const dev = devProjectFromFirebaserc('{"projects":{"dev":"proj-dev","prod":"proj-prod"}}');
    assert.equal(dev, 'proj-dev');
    assert.equal(cliPayoutsMode({ PAYOUTS_MODE: 'fake', GCLOUD_PROJECT: 'proj-dev' }, dev), 'fake');
    assert.equal(cliPayoutsMode({ PAYOUTS_MODE: 'fake', GCLOUD_PROJECT: 'proj-prod' }, dev), 'off');
    assert.equal(cliPayoutsMode({ PAYOUTS_MODE: 'fake' }, dev), 'off');
    assert.equal(cliPayoutsMode({ PAYOUTS_MODE: 'fake', GCLOUD_PROJECT: 'proj-dev' }, null), 'off');
    assert.equal(cliPayoutsMode({ GCLOUD_PROJECT: 'proj-dev' }, dev), 'off');
    assert.equal(devProjectFromFirebaserc('not json'), null);
    assert.equal(devProjectFromFirebaserc('{"projects":{}}'), null);
  });

  it('show masks the account number', async () => {
    await runCli(['create', 'p1', '--actor', 's1'], deps(), io, 'fake');
    const id = [...store.payouts.keys()][0] as string;
    out = [];
    await runCli(['show', id], deps(), io, 'fake');
    const text = out.join('\n');
    assert.match(text, /VCB •••• 6789 NGUYEN VAN AN/);
    assert.doesNotMatch(text, /0123456789|v1:/);
    await assert.rejects(runCli(['show', 'missing'], deps(), io, 'fake'), /not found/);
  });
});

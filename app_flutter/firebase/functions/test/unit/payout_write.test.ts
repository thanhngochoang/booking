import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  type EarningsDeps,
  type NotifyDeps,
} from '@photobooking/domain';
import { handlePayoutWrite } from '../../src/triggers/payout_write.js';

// onPayoutWritten (S17 Decision 5): the earnings refresh first, then `payout_released` to the payee
// when the payout becomes `paid`. Dedupe `payout_released_{payoutId}` makes a retry harmless.

const NOW = new Date('2026-10-10T10:00:00.000Z'); // 17:00 in Vietnam
const items = [{ paymentId: 'pay1', amount: 300_000 }, { paymentId: 'pay2', amount: 200_000 }];

function setup(opts: { notifyFails?: boolean } = {}) {
  const order: string[] = [];
  const earnings = {
    store: {
      runTransaction: async () => {
        order.push('refresh');
        return {};
      },
    },
    clock: { now: () => NOW },
  } as unknown as EarningsDeps;
  const store = new MemoryNotificationStore();
  const real = store.getPrefs.bind(store);
  store.getPrefs = async (uid: string) => {
    order.push('notify');
    if (opts.notifyFails === true) throw new Error('firestore unavailable');
    return real(uid);
  };
  const push = new MemoryPushSender();
  const notify: NotifyDeps = { store, push, users: new MemoryUserDirectory(), clock: { now: () => NOW } };
  return { order, earnings, store, push, notify };
}

const doc = (status: string, over: Record<string, unknown> = {}) => ({ payeeId: 'p1', status, amount: 500_000, items, ...over });

describe('handlePayoutWrite', () => {
  it('pending → paid sends payout_released with amountNet when present', async () => {
    const w = setup();
    assert.equal(await handlePayoutWrite('po1', doc('processing'), doc('paid', { amountNet: 480_000 }), w.earnings, w.notify), 'p1');
    const rows = w.store.rowsOf('p1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.id, 'n_payout_released_po1');
    assert.equal(rows[0]?.type, 'payout_released');
    assert.equal(rows[0]?.title, 'Đã chuyển 480.000₫ cho bạn');
    assert.equal(rows[0]?.body, 'Tiền của 2 khoản đã vào tài khoản nhận tiền. Xem chi tiết trong Thu nhập.');
    assert.equal(rows[0]?.target, '/work/earnings');
    assert.equal(w.push.sent.length, 1);
  });

  it('falls back to amount', async () => {
    const w = setup();
    await handlePayoutWrite('po1', doc('pending'), doc('paid'), w.earnings, w.notify);
    assert.equal(w.store.rowsOf('p1')[0]?.title, 'Đã chuyển 500.000₫ cho bạn');
  });

  it('a paid payout without items omits the count clause (never "Tiền của 0 khoản")', async () => {
    for (const over of [{ items: undefined }, { items: [] }]) {
      const w = setup();
      await handlePayoutWrite('po1', doc('pending'), doc('paid', over), w.earnings, w.notify);
      assert.equal(w.store.rowsOf('p1')[0]?.body, 'Tiền đã vào tài khoản nhận tiền. Xem chi tiết trong Thu nhập.');
    }
  });

  it('paid → paid (rewrite) sends nothing', async () => {
    const w = setup();
    await handlePayoutWrite('po1', doc('paid'), doc('paid', { updatedAt: 'later' }), w.earnings, w.notify);
    assert.equal(w.store.rowsOf('p1').length, 0);
    assert.deepEqual(w.order, ['refresh']);
  });

  it('pending → failed sends nothing', async () => {
    const w = setup();
    await handlePayoutWrite('po1', doc('pending'), doc('failed'), w.earnings, w.notify);
    assert.equal(w.store.rowsOf('p1').length, 0);
    assert.deepEqual(w.order, ['refresh']);
  });

  it('a retry of the paid transition is a duplicate', async () => {
    const w = setup();
    await handlePayoutWrite('po1', doc('processing'), doc('paid'), w.earnings, w.notify);
    await handlePayoutWrite('po1', doc('processing'), doc('paid'), w.earnings, w.notify);
    assert.equal(w.store.rowsOf('p1').length, 1);
    assert.equal(w.push.sent.length, 1);
  });

  it('the earnings refresh still runs first and a notify failure is rethrown after it', async () => {
    const w = setup({ notifyFails: true });
    await assert.rejects(
      handlePayoutWrite('po1', doc('processing'), doc('paid'), w.earnings, w.notify),
      /firestore unavailable/,
    );
    assert.deepEqual(w.order, ['refresh', 'notify']);
  });

  it('without notify deps only the refresh runs', async () => {
    const w = setup();
    await handlePayoutWrite('po1', doc('processing'), doc('paid'), w.earnings);
    assert.deepEqual(w.order, ['refresh']);
  });
});

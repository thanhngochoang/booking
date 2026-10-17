import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { PAYOUT_ACCOUNT_KEY, PAYMENT_CALLABLE_OPTIONS, WEBHOOK_OPTIONS, PAYMENT_CLOCK_OPTIONS, BOOKING_REFUND_CALLABLE_OPTIONS, BOOKING_CLOCK_OPTIONS, EVENT_CLOCK_OPTIONS, EVENT_REFUND_CALLABLE_OPTIONS } from '../../src/config.js';
import { lazyAccountCipher } from '../../src/infra/account_cipher.js';
import { liveRefundSubjects } from '../../src/infra/live_refunds.js';

describe('refund wiring', () => {
  it('every function that can capture a payer or send a bank refund binds PAYOUT_ACCOUNT_KEY', () => {
    const optionSets = [
      { name: 'PAYMENT_CALLABLE_OPTIONS', options: PAYMENT_CALLABLE_OPTIONS },
      { name: 'WEBHOOK_OPTIONS', options: WEBHOOK_OPTIONS },
      { name: 'PAYMENT_CLOCK_OPTIONS', options: PAYMENT_CLOCK_OPTIONS },
      { name: 'BOOKING_REFUND_CALLABLE_OPTIONS', options: BOOKING_REFUND_CALLABLE_OPTIONS },
      { name: 'BOOKING_CLOCK_OPTIONS', options: BOOKING_CLOCK_OPTIONS },
      { name: 'EVENT_REFUND_CALLABLE_OPTIONS', options: EVENT_REFUND_CALLABLE_OPTIONS },
      { name: 'EVENT_CLOCK_OPTIONS', options: EVENT_CLOCK_OPTIONS },
    ];
    for (const { name, options } of optionSets) {
      const secrets = (options as { secrets?: unknown[] }).secrets;
      assert.ok(Array.isArray(secrets), `${name} has secrets array`);
      assert.ok(secrets.includes(PAYOUT_ACCOUNT_KEY), `${name} includes PAYOUT_ACCOUNT_KEY`);
    }
  });

  it('lazyAccountCipher reads the key only on first use', async () => {
    let keyReads = 0;
    const cipher = lazyAccountCipher(() => {
      keyReads += 1;
      return Buffer.alloc(32, 7).toString('base64');
    });
    assert.equal(keyReads, 0, 'no read after construction');

    const enc1 = await cipher.encrypt('123456');
    assert.equal(keyReads, 1, 'read on first encrypt');

    const enc2 = await cipher.encrypt('654321');
    assert.equal(keyReads, 1, 'no further read on subsequent encrypt');

    assert.equal(await cipher.decrypt(enc1), '123456');
    assert.equal(await cipher.decrypt(enc2), '654321');
    assert.equal(keyReads, 1, 'no further read on decrypt');
  });

  it('liveRefundSubjects has an event_registration handler', () => {
    const subjects = liveRefundSubjects();
    assert.ok(subjects.event_registration !== undefined, 'event_registration handler exists');
    assert.equal(typeof subjects.event_registration.resend, 'function');
    assert.equal(typeof subjects.event_registration.record, 'function');
  });
});

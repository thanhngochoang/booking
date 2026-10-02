import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, requireCustomerPhone, requirePhone } from '../src/index.js';

const phoneRequired = (e: unknown) => e instanceof DomainError && e.code === 'phone_required';

describe('requirePhone', () => {
  test('returns the stored Vietnamese number', () => {
    assert.equal(requirePhone({ phone: '+84903123456' }), '+84903123456');
  });

  test('missing, malformed or foreign numbers are phone_required', () => {
    for (const contact of [null, {}, { phone: '' }, { phone: '0903123456' }, { phone: '+14155552671' }, { phone: 84903123456 }]) {
      assert.throws(() => requirePhone(contact), phoneRequired, JSON.stringify(contact));
    }
  });

  test('requireCustomerPhone reads the contact of that user only', async () => {
    const asked: string[] = [];
    const contacts = {
      get: async (uid: string) => {
        asked.push(uid);
        return uid === 'c1' ? { phone: '+84903123456' } : null;
      },
    };
    assert.equal(await requireCustomerPhone(contacts, 'c1'), '+84903123456');
    await assert.rejects(requireCustomerPhone(contacts, 'c2'), phoneRequired);
    assert.deepEqual(asked, ['c1', 'c2']);
  });
});

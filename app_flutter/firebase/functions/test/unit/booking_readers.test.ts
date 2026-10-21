import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { serviceRecordOf } from '../../src/infra/booking_readers.js';
import type { DocumentData } from 'firebase-admin/firestore';

describe('serviceRecordOf', () => {
  it('reads deliverables.revisions', () => {
    const d: DocumentData = {
      name: 'Cưới',
      price: 3_000_000,
      durationMinutes: 240,
      deliverables: { revisions: 2 },
    };
    const s = serviceRecordOf('srv_01', 'p1', d);
    assert.equal(s.revisions, 2);
    assert.equal(s.name, 'Cưới');
    assert.equal(s.price, 3_000_000);
    assert.equal(s.durationMinutes, 240);
    assert.equal(s.active, true);
  });

  it('a package without deliverables.revisions has no revisions', () => {
    const d: DocumentData = {
      name: 'Chân dung',
      price: 500_000,
    };
    const s = serviceRecordOf('srv_01', 'p1', d);
    assert.equal('revisions' in s, false);
  });

  it('a non-number revisions is ignored', () => {
    const d: DocumentData = {
      name: 'Gia đình',
      deliverables: { revisions: '2' },
    };
    const s = serviceRecordOf('srv_01', 'p1', d);
    assert.equal('revisions' in s, false);
  });

  it('defaults are unchanged', () => {
    const d1: DocumentData = {};
    const s1 = serviceRecordOf('srv_empty', 'p1', d1);
    assert.deepEqual(s1, {
      id: 'srv_empty',
      photographerId: 'p1',
      name: '',
      price: 0,
      durationMinutes: 60,
      active: true,
    });

    const d2: DocumentData = { active: false };
    const s2 = serviceRecordOf('srv_inactive', 'p1', d2);
    assert.equal(s2.active, false);
  });

  it('a provider with deletionPending is not accepting orders', async () => {
    const { FirestoreProviderOrderGate } = await import('../../src/infra/booking_readers.js');
    const fakeFirestore = {
      collection: () => ({
        doc: () => ({
          get: async () => ({
            exists: true,
            data: () => ({
              verified: true,
              onboardingComplete: true,
              deletionPending: true,
            }),
          }),
        }),
      }),
    };
    const gate = new FirestoreProviderOrderGate(fakeFirestore as any);
    const result = await gate.acceptsOrders('p1');
    assert.equal(result, false);
  });
});

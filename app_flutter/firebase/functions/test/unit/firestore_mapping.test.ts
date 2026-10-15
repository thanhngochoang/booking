import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import { bookingFromDoc, channelsFromDoc, lastCompletedAt, numbersFromDoc } from '../../src/infra/firestore.js';

const t = (iso: string) => Timestamp.fromDate(new Date(iso));

describe('Firestore → domain mapping', () => {
  test('booking: ids, status and completedAt from the timeline', () => {
    assert.deepEqual(
      bookingFromDoc('b1', {
        customerId: 'c1',
        photographerId: 'p1',
        status: 'completed',
        timeline: [{ status: 'requested', at: t('2026-09-01T00:00:00Z') }, { status: 'completed', at: t('2026-09-20T10:00:00Z') }],
      }),
      { id: 'b1', customerId: 'c1', photographerId: 'p1', status: 'completed', completedAt: new Date('2026-09-20T10:00:00Z') },
    );
  });

  test('booking: a top-level completedAt wins over the timeline', () => {
    const b = bookingFromDoc('b1', {
      customerId: 'c1',
      photographerId: 'p1',
      status: 'completed',
      completedAt: t('2026-09-21T00:00:00Z'),
      timeline: [{ status: 'completed', at: t('2026-09-20T00:00:00Z') }],
    });
    assert.deepEqual(b?.completedAt, new Date('2026-09-21T00:00:00Z'));
  });

  test('booking: a missing doc or unusable ids give null', () => {
    assert.equal(bookingFromDoc('b1', undefined), null);
    assert.equal(bookingFromDoc('b1', { customerId: 'c1', photographerId: 'a/b', status: 'accepted' }), null);
    assert.equal(bookingFromDoc('b1', { customerId: 'c1', photographerId: 'p1' }), null);
  });

  test('lastCompletedAt takes the latest completed entry and ignores junk', () => {
    assert.deepEqual(
      lastCompletedAt([
        { status: 'completed', at: t('2026-09-01T00:00:00Z') },
        'x',
        null,
        { status: 'completed', at: 'yesterday' },
        { status: 'completed', at: t('2026-09-05T00:00:00Z') },
      ]),
      new Date('2026-09-05T00:00:00Z'),
    );
    assert.equal(lastCompletedAt(undefined), null);
  });

  test('channels are strict booleans; numbers need a phone', () => {
    assert.deepEqual(channelsFromDoc({ contactChannels: { call: true, zalo: 'yes', acceptInquiries: true } }), {
      call: true,
      zalo: false,
      whatsapp: false,
    });
    assert.equal(channelsFromDoc({}), null);
    assert.equal(channelsFromDoc(undefined), null);
    assert.deepEqual(numbersFromDoc({ phone: '+84912000001', zaloPhone: '+84912000002' }), {
      phone: '+84912000001',
      zaloPhone: '+84912000002',
      whatsappPhone: null,
    });
    assert.equal(numbersFromDoc({ zaloPhone: '+84912000002' }), null);
  });
});

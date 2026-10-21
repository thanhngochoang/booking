import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { emitQuoteNotices, quoteNotices } from '../src/job_notices.js';
import type { QuoteRecord } from '../src/job.js';
import { createNotifyWorld } from './support/notify_world.js';

describe('job notices', () => {
  const baseQuote: QuoteRecord = {
    id: 'p_tu',
    jobId: 'job_01',
    photographerId: 'p_tu',
    customerId: 'cust_lan',
    jobTitle: 'Kỷ yếu 12A1',
    photographer: {
      name: 'Tú',
      avatarUrl: null,
      providerType: 'individual',
      verified: true,
      tomatoPct: 95,
      score: 1.0,
      reviewCount: 10,
      completedCount: 20,
      approvedAwardCount: 0,
      studioDistrict: null,
    },
    basedOnServiceId: null,
    terms: {
      price: 3000000,
      durationMinutes: 240,
      photoCount: null,
      editedCount: 40,
      deliveryDays: 7,
      revisions: 1,
      milestones: [
        { kind: 'shoot', percent: 50 },
        { kind: 'delivery', percent: 50 },
      ],
    },
    milestoneAmounts: { shoot: 1500000, delivery: 1500000 },
    proposal: { day: '2026-10-20', start: '07:00', end: '11:00' },
    message: 'Lời nhắn báo giá',
    albumId: null,
    album: null,
    invited: false,
    fit: 90,
    status: 'submitted',
    notSelectedReason: null,
    autoWithdrawn: false,
    declineReason: null,
    bookingId: null,
    withdrawnAt: null,
    version: 1,
    createdAt: new Date('2026-10-05T02:00:00.000Z'),
    updatedAt: new Date('2026-10-05T02:00:00.000Z'),
  };

  it('new quote maps to quote_new for customer', () => {
    const notices = quoteNotices(null, baseQuote);
    assert.deepEqual(notices, [{ to: 'customer', kind: 'new' }]);
  });

  it('resubmitted quote maps to quote_new', () => {
    const withdrawn = { ...baseQuote, status: 'withdrawn' as const };
    const resubmitted = { ...baseQuote, version: 2 };
    const notices = quoteNotices(withdrawn, resubmitted);
    assert.deepEqual(notices, [{ to: 'customer', kind: 'new' }]);
  });

  it('submitted -> withdrawn maps to quote_withdrawn for customer', () => {
    const withdrawn = { ...baseQuote, status: 'withdrawn' as const, version: 2 };
    const notices = quoteNotices(baseQuote, withdrawn);
    assert.deepEqual(notices, [{ to: 'customer', kind: 'withdrawn' }]);
  });

  it('submitted -> accepted maps to quote_accepted for photographer', () => {
    const accepted = { ...baseQuote, status: 'accepted' as const, bookingId: 'b_01', version: 2 };
    const notices = quoteNotices(baseQuote, accepted);
    assert.deepEqual(notices, [{ to: 'photographer', kind: 'accepted' }]);
  });

  it('submitted -> not_selected maps to quote_not_selected for photographer', () => {
    const notSel = { ...baseQuote, status: 'not_selected' as const, notSelectedReason: 'expired' as const, version: 2 };
    const notices = quoteNotices(baseQuote, notSel);
    assert.deepEqual(notices, [{ to: 'photographer', kind: 'not_selected' }]);
  });

  it('submitted -> declined maps to quote_not_selected for photographer', () => {
    const dec = { ...baseQuote, status: 'declined' as const, declineReason: 'Giá cao', version: 2 };
    const notices = quoteNotices(baseQuote, dec);
    assert.deepEqual(notices, [{ to: 'photographer', kind: 'not_selected' }]);
  });

  it('edits within submitted emit nothing', () => {
    const edited = { ...baseQuote, terms: { ...baseQuote.terms, price: 3500000 }, version: 2 };
    const notices = quoteNotices(baseQuote, edited);
    assert.deepEqual(notices, []);
  });

  it('emitQuoteNotices calls notify hooks', async () => {
    const nw = createNotifyWorld();
    const count = await emitQuoteNotices(nw.deps, null, baseQuote);
    assert.equal(count, 1);
    assert.equal(nw.store.rows.size, 1);
    const row = nw.store.rowsOf('cust_lan')[0];
    assert.equal(row.type, 'quote_new');
    assert.equal(row.userId, 'cust_lan');
  });
});

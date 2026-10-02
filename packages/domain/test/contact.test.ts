import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DomainError,
  bookingContactUnlocked,
  contactUrlFor,
  parseContactLinkRequest,
  ticketContactUnlocked,
  type ContactNumbers,
  type ExternalChannel,
} from '../src/index.js';
import { isAllowedContactUrl } from './client_allow_list.js';

const vn: ContactNumbers = { phone: '+84903123456' };
const own: ContactNumbers = { phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: '+14155552671' };
const external: ExternalChannel[] = ['call', 'zalo', 'whatsapp'];
const NOW = new Date('2026-10-01T12:00:00Z');
const daysAgo = (days: number, extraMs = 0) => new Date(NOW.getTime() - days * 86_400_000 - extraMs);

describe('contactUrlFor: the exact URL formats (same as the client)', () => {
  test('call is tel: with the plus', () => assert.equal(contactUrlFor('call', vn), 'tel:+84903123456'));
  test('zalo is https://zalo.me/ with digits only', () =>
    assert.equal(contactUrlFor('zalo', vn), 'https://zalo.me/84903123456'));
  test('whatsapp is https://wa.me/ without the plus', () =>
    assert.equal(contactUrlFor('whatsapp', vn), 'https://wa.me/84903123456'));
  test('own Zalo and WhatsApp numbers are used, call keeps the main one', () => {
    assert.equal(contactUrlFor('call', own), 'tel:+84903123456');
    assert.equal(contactUrlFor('zalo', own), 'https://zalo.me/84912345678');
    assert.equal(contactUrlFor('whatsapp', own), 'https://wa.me/14155552671');
  });
  test('every URL passes the client allow-list for its own channel', () => {
    for (const c of external) assert.equal(isAllowedContactUrl(contactUrlFor(c, own) ?? '', c), true, c);
  });
  test('a stored number that is not valid for the channel never becomes a URL', () => {
    assert.equal(contactUrlFor('call', { phone: '0903123456' }), null);
    assert.equal(contactUrlFor('zalo', { phone: '+84903123456', zaloPhone: '+14155552671' }), null);
    assert.equal(contactUrlFor('whatsapp', { phone: '+84903123456', whatsappPhone: '+123' }), null);
    assert.equal(contactUrlFor('call', { phone: '+84903123456?x=1' }), null);
  });
});

describe('booking contact unlock (domain-model §5; client contactAccessForBooking)', () => {
  test('open from the deposit until the booking is over', () => {
    for (const status of ['requested', 'accepted', 'upcoming']) {
      assert.equal(bookingContactUnlocked({ status, completedAt: null }, NOW), true, status);
    }
  });
  test('closed for drafts, bookings that fell through and unknown codes', () => {
    for (const status of ['draft', 'declined', 'expired', 'cancelled', 'refunded', '']) {
      assert.equal(bookingContactUnlocked({ status, completedAt: daysAgo(1) }, NOW), false, status);
    }
  });
  test('completed and reviewed stay open for 30 days, inclusive', () => {
    for (const status of ['completed', 'reviewed']) {
      assert.equal(bookingContactUnlocked({ status, completedAt: daysAgo(29) }, NOW), true, status);
      assert.equal(bookingContactUnlocked({ status, completedAt: daysAgo(30) }, NOW), true, status);
      assert.equal(bookingContactUnlocked({ status, completedAt: daysAgo(30, 1000) }, NOW), false, status);
      assert.equal(bookingContactUnlocked({ status, completedAt: null }, NOW), false, status);
    }
  });
});

describe('ticket contact unlock', () => {
  test('a paid ticket is open until 7 days after the event, inclusive', () => {
    const tomorrow = new Date(NOW.getTime() + 86_400_000);
    assert.equal(ticketContactUnlocked({ status: 'paid', eventEndsAt: tomorrow }, NOW), true);
    assert.equal(ticketContactUnlocked({ status: 'paid', eventEndsAt: daysAgo(7) }, NOW), true);
    assert.equal(ticketContactUnlocked({ status: 'paid', eventEndsAt: daysAgo(7, 1000) }, NOW), false);
    assert.equal(ticketContactUnlocked({ status: 'paid', eventEndsAt: null }, NOW), false);
  });
  test('held, cancelled and refunded tickets are closed', () => {
    for (const status of ['held', 'cancelled', 'refunded']) {
      assert.equal(ticketContactUnlocked({ status, eventEndsAt: NOW }, NOW), false, status);
    }
  });
});

describe('parseContactLinkRequest (wire contract of getContactLink)', () => {
  test('booking and registration requests', () => {
    assert.deepEqual(parseContactLinkRequest({ bookingId: 'b1', channel: 'zalo' }), {
      subject: { type: 'booking', id: 'b1' },
      channel: 'zalo',
    });
    assert.deepEqual(parseContactLinkRequest({ registrationId: 'r9', channel: 'whatsapp' }), {
      subject: { type: 'event_registration', id: 'r9' },
      channel: 'whatsapp',
    });
  });
  test('anything else is invalid_argument', () => {
    const bad: unknown[] = [
      null, 'b1', [], {}, { bookingId: 'b1' },
      { bookingId: 'b1', channel: 'in_app' }, { bookingId: 'b1', channel: 'sms' },
      { bookingId: 'b1', registrationId: 'r1', channel: 'call' },
      { bookingId: 'a/b', channel: 'call' }, { bookingId: '', channel: 'call' }, { bookingId: 5, channel: 'call' },
      { bookingId: 'b1', channel: 'call', phone: '+84903123456' },
    ];
    for (const data of bad) {
      assert.throws(
        () => parseContactLinkRequest(data),
        (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument',
        JSON.stringify(data),
      );
    }
  });
});

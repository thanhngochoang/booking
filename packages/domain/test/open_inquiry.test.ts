import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError } from '../src/errors.js';
import { openInquiry } from '../src/open_inquiry.js';
import { createChatWorld } from './support/chat_world.js';

describe('openInquiry (Task 2)', () => {
  it('opens one inquiry per pair and returns it again', async () => {
    const { deps, chats } = createChatWorld();
    const res1 = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });
    assert.equal(res1.chatId, 'cust1_phot1');
    assert.equal(res1.created, true);

    const stored = chats.chats.get('cust1_phot1');
    assert.ok(stored);
    assert.equal(stored.kind, 'inquiry');
    assert.equal(stored.customerId, 'cust1');
    assert.equal(stored.photographerId, 'phot1');
    assert.equal(stored.customerMessagesBeforeReply, 0);

    // Unread counters initialized to 0
    assert.equal(chats.unread.get('cust1_phot1')?.get('cust1'), 0);
    assert.equal(chats.unread.get('cust1_phot1')?.get('phot1'), 0);

    // Call again -> returns existing chat, created: false
    const res2 = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot1' });
    assert.equal(res2.chatId, 'cust1_phot1');
    assert.equal(res2.created, false);
  });

  it('refuses a new inquiry when the photographer turned inquiries off, but returns an existing chat', async () => {
    const { deps, photographers } = createChatWorld();
    photographers.disableInquiries('phot_busy');

    // Refused when new
    await assert.rejects(
      () => openInquiry(deps, { customerId: 'cust1', photographerId: 'phot_busy' }),
      (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
    );

    // If photographer allows temporarily and chat is created:
    photographers.enableInquiries('phot_busy');
    const created = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot_busy' });
    assert.equal(created.created, true);

    // Now photographer disables inquiries:
    photographers.disableInquiries('phot_busy');
    // But existing chat is returned!
    const existing = await openInquiry(deps, { customerId: 'cust1', photographerId: 'phot_busy' });
    assert.equal(existing.chatId, created.chatId);
    assert.equal(existing.created, false);
  });

  it('cannot open an inquiry with yourself', async () => {
    const { deps } = createChatWorld();
    await assert.rejects(
      () => openInquiry(deps, { customerId: 'same_user', photographerId: 'same_user' }),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
  });
});

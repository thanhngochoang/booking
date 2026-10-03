import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertCanSend,
  afterMessage,
  chatIdFor,
  DomainError,
  isInquiryClosed,
  previewOf,
  roleInChat,
  validateMessageInput,
  type Chat,
  type Message,
} from '../src/index.js';

describe('chat model and rules (Task 1)', () => {
  const baseChat: Chat = {
    id: 'cust1_phot1',
    kind: 'inquiry',
    customerId: 'cust1',
    photographerId: 'phot1',
    bookingId: null,
    photographerRepliedAt: null,
    customerMessagesBeforeReply: 0,
    lastMessageAt: null,
    lastMessagePreview: null,
    lastSenderId: null,
    readOnlyAt: null,
    rescheduleUsed: false,
    createdAt: new Date('2026-10-01T00:00:00Z'),
    updatedAt: new Date('2026-10-01T00:00:00Z'),
  };

  it('chatIdFor joins customer and photographer', () => {
    assert.equal(chatIdFor('cust1', 'phot1'), 'cust1_phot1');
    assert.equal(chatIdFor('user_abc', 'pro_xyz'), 'user_abc_pro_xyz');
  });

  it('roleInChat', () => {
    assert.equal(roleInChat(baseChat, 'cust1'), 'customer');
    assert.equal(roleInChat(baseChat, 'phot1'), 'photographer');
    assert.equal(roleInChat(baseChat, 'outsider'), null);
  });

  it('previewOf trims to 80 graphemes and names media', () => {
    assert.equal(previewOf({ type: 'image', body: null }), 'Ảnh');
    assert.equal(previewOf({ type: 'location', body: null }), 'Vị trí');
    assert.equal(previewOf({ type: 'system', body: null }), '');
    assert.equal(previewOf({ type: 'text', body: '   Xin chào bạn   ' }), 'Xin chào bạn');

    const longText = 'A'.repeat(120);
    const preview = previewOf({ type: 'text', body: longText });
    assert.equal(preview.length, 80);
    assert.equal(preview, 'A'.repeat(80));

    // Multibyte / grapheme check
    const emojiText = '🎉'.repeat(90);
    const emojiPreview = previewOf({ type: 'text', body: emojiText });
    assert.equal([...new Intl.Segmenter().segment(emojiPreview)].length, 80);
  });

  it('inquiry is closed after 14 days without messages and open again after a new one', () => {
    const t0 = new Date('2026-10-01T10:00:00Z');
    const chatWithMsg: Chat = {
      ...baseChat,
      lastMessageAt: t0,
    };

    // Before 14 days
    const t1 = new Date('2026-10-15T09:59:59Z');
    assert.equal(isInquiryClosed(chatWithMsg, t1), false);

    // Exactly 14 days
    const t14d = new Date('2026-10-15T10:00:00Z');
    assert.equal(isInquiryClosed(chatWithMsg, t14d), true);

    // After 14 days
    const tLate = new Date('2026-10-16T10:00:00Z');
    assert.equal(isInquiryClosed(chatWithMsg, tLate), true);

    // If lastMessageAt is null, chat is newly opened and not closed
    assert.equal(isInquiryClosed(baseChat, tLate), false);

    // Reopened with a new message at tLate
    const reopened: Chat = {
      ...chatWithMsg,
      lastMessageAt: tLate,
    };
    assert.equal(isInquiryClosed(reopened, tLate), false);

    // Booking chats are never closed inquiries
    const bookingChat: Chat = {
      ...chatWithMsg,
      kind: 'booking',
      bookingId: 'book_1',
    };
    assert.equal(isInquiryClosed(bookingChat, tLate), false);
  });

  it('assertCanSend: outsider permission_denied; read-only not_eligible at exactly readOnlyAt; customer\'s 4th unanswered inquiry message limit_exceeded; photographer always allowed; after the photographer replied the customer is unlimited; booking chats have no cap', () => {
    const now = new Date('2026-10-01T12:00:00Z');

    // Outsider
    assert.throws(
      () => assertCanSend(baseChat, 'outsider', now),
      (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
    );

    // Read-only at exactly readOnlyAt
    const roChat: Chat = {
      ...baseChat,
      readOnlyAt: now,
    };
    assert.throws(
      () => assertCanSend(roChat, 'cust1', now),
      (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
    );
    assert.throws(
      () => assertCanSend(roChat, 'phot1', now),
      (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
    );

    // Customer inquiry cap: 0, 1, 2 allowed, 3rd message allowed, 4th refused
    const chat0 = { ...baseChat, customerMessagesBeforeReply: 0 };
    assert.doesNotThrow(() => assertCanSend(chat0, 'cust1', now));

    const chat2 = { ...baseChat, customerMessagesBeforeReply: 2 };
    assert.doesNotThrow(() => assertCanSend(chat2, 'cust1', now));

    const chat3 = { ...baseChat, customerMessagesBeforeReply: 3 };
    assert.throws(
      () => assertCanSend(chat3, 'cust1', now),
      (err: unknown) => err instanceof DomainError && err.code === 'limit_exceeded',
    );

    // Photographer is always allowed even if 3 messages sent
    assert.doesNotThrow(() => assertCanSend(chat3, 'phot1', now));

    // After photographer replied, customer is unlimited
    const repliedChat: Chat = {
      ...baseChat,
      photographerRepliedAt: new Date('2026-10-01T11:00:00Z'),
      customerMessagesBeforeReply: 3,
    };
    assert.doesNotThrow(() => assertCanSend(repliedChat, 'cust1', now));

    // Booking chats have no cap
    const bookingChat: Chat = {
      ...baseChat,
      kind: 'booking',
      bookingId: 'book_1',
      customerMessagesBeforeReply: 10,
      photographerRepliedAt: null,
    };
    assert.doesNotThrow(() => assertCanSend(bookingChat, 'cust1', now));
  });

  it('afterMessage: a photographer message in an inquiry sets photographerRepliedAt once; a customer message before any reply increments the counter; lastMessage fields follow', () => {
    const t1 = new Date('2026-10-01T10:00:00Z');
    const custMsg1: Message = {
      id: 'msg_1',
      chatId: baseChat.id,
      senderId: 'cust1',
      type: 'text',
      body: 'Chào bạn',
      imagePath: null,
      point: null,
      system: null,
      createdAt: t1,
    };

    const afterCust1 = afterMessage(baseChat, custMsg1, t1);
    assert.equal(afterCust1.customerMessagesBeforeReply, 1);
    assert.equal(afterCust1.photographerRepliedAt, null);
    assert.deepEqual(afterCust1.lastMessageAt, t1);
    assert.equal(afterCust1.lastMessagePreview, 'Chào bạn');
    assert.equal(afterCust1.lastSenderId, 'cust1');
    assert.deepEqual(afterCust1.updatedAt, t1);

    // Photographer replies
    const t2 = new Date('2026-10-01T10:05:00Z');
    const photMsg: Message = {
      id: 'msg_2',
      chatId: baseChat.id,
      senderId: 'phot1',
      type: 'text',
      body: 'Chào bạn, mình có thể giúp gì?',
      imagePath: null,
      point: null,
      system: null,
      createdAt: t2,
    };
    const afterPhot = afterMessage(afterCust1, photMsg, t2);
    assert.deepEqual(afterPhot.photographerRepliedAt, t2);
    assert.equal(afterPhot.customerMessagesBeforeReply, 1); // not incremented
    assert.deepEqual(afterPhot.lastMessageAt, t2);
    assert.equal(afterPhot.lastMessagePreview, 'Chào bạn, mình có thể giúp gì?');
    assert.equal(afterPhot.lastSenderId, 'phot1');

    // Another photographer message doesn't overwrite photographerRepliedAt
    const t3 = new Date('2026-10-01T10:10:00Z');
    const photMsg2: Message = {
      id: 'msg_3',
      chatId: baseChat.id,
      senderId: 'phot1',
      type: 'text',
      body: 'Gửi bạn ảnh mẫu',
      imagePath: null,
      point: null,
      system: null,
      createdAt: t3,
    };
    const afterPhot2 = afterMessage(afterPhot, photMsg2, t3);
    assert.deepEqual(afterPhot2.photographerRepliedAt, t2);

    // Customer sends message after reply: counter does not increment
    const t4 = new Date('2026-10-01T10:15:00Z');
    const custMsg2: Message = {
      id: 'msg_4',
      chatId: baseChat.id,
      senderId: 'cust1',
      type: 'text',
      body: 'Đẹp quá',
      imagePath: null,
      point: null,
      system: null,
      createdAt: t4,
    };
    const afterCust2 = afterMessage(afterPhot2, custMsg2, t4);
    assert.equal(afterCust2.customerMessagesBeforeReply, 1);
  });

  it('validateMessageInput: empty or whitespace text refused; text over 2000 refused; image needs a chats/ path of this sender; location needs lat in -90..90, lng in -180..180; clientId must be an id', () => {
    // Valid text
    assert.deepEqual(
      validateMessageInput(
        { type: 'text', body: 'Xin chào', clientId: 'client_123' },
        'user_1',
      ),
      {
        type: 'text',
        body: 'Xin chào',
        imagePath: null,
        point: null,
        clientId: 'client_123',
      },
    );

    // ClientId must be an id
    assert.throws(
      () => validateMessageInput({ type: 'text', body: 'Hi', clientId: '' }, 'user_1'),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
    assert.throws(
      () =>
        validateMessageInput(
          { type: 'text', body: 'Hi', clientId: 'bad space!' },
          'user_1',
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );

    // Empty or whitespace text refused
    assert.throws(
      () => validateMessageInput({ type: 'text', body: '', clientId: 'c1' }, 'user_1'),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
    assert.throws(
      () =>
        validateMessageInput(
          { type: 'text', body: '   \n  ', clientId: 'c1' },
          'user_1',
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
    assert.throws(
      () => validateMessageInput({ type: 'text', body: null, clientId: 'c1' }, 'user_1'),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );

    // Text over 2000 refused
    assert.throws(
      () =>
        validateMessageInput(
          { type: 'text', body: 'a'.repeat(2001), clientId: 'c1' },
          'user_1',
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );

    // Valid image
    assert.deepEqual(
      validateMessageInput(
        {
          type: 'image',
          imagePath: 'chats/chat_1/user_1/01HZY123.webp',
          clientId: 'c1',
        },
        'user_1',
      ),
      {
        type: 'image',
        body: null,
        imagePath: 'chats/chat_1/user_1/01HZY123.webp',
        point: null,
        clientId: 'c1',
      },
    );

    // Image path not starting with chats/ or invalid sender
    assert.throws(
      () =>
        validateMessageInput(
          { type: 'image', imagePath: 'other/path/img.webp', clientId: 'c1' },
          'user_1',
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
    assert.throws(
      () =>
        validateMessageInput(
          {
            type: 'image',
            imagePath: 'chats/chat_1/wrong_user/01HZY123.webp',
            clientId: 'c1',
          },
          'user_1',
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );

    // Location valid
    assert.deepEqual(
      validateMessageInput(
        { type: 'location', point: { lat: 10.762622, lng: 106.660172 }, clientId: 'c1' },
        'user_1',
      ),
      {
        type: 'location',
        body: null,
        imagePath: null,
        point: { lat: 10.762622, lng: 106.660172 },
        clientId: 'c1',
      },
    );

    // Location out of bounds
    assert.throws(
      () =>
        validateMessageInput(
          { type: 'location', point: { lat: 91, lng: 106.0 }, clientId: 'c1' },
          'user_1',
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
    assert.throws(
      () =>
        validateMessageInput(
          { type: 'location', point: { lat: 10.0, lng: 181 }, clientId: 'c1' },
          'user_1',
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
    assert.throws(
      () =>
        validateMessageInput(
          { type: 'location', point: { lat: NaN, lng: 106.0 }, clientId: 'c1' },
          'user_1',
        ),
      (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
    );
  });
});

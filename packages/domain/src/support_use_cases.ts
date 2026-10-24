import type { Dispute } from './dispute.js';
import { DomainError } from './errors.js';
import type { Clock, IdGenerator } from './ports.js';
import { graphemeCount } from './booking_requests.js';
import { truncateGraphemes } from './notification_render.js';
import {
  SUPPORT_RATE_LIMIT,
  SUPPORT_RATE_WINDOW_MINUTES,
  SUPPORT_TEXT_MAX,
  type SupportMessage,
  type SupportRateEntry,
  type SupportSenderRole,
  type SupportThread,
} from './support_thread.js';

export interface DisplayNames {
  displayName(uid: string): Promise<string>;
}

export interface SupportTx {
  getThread(id: string): Promise<SupportThread | null>;
  getMessage(threadId: string, id: string): Promise<SupportMessage | null>;
  /** #142: the dispute of a dispute thread (parties, status). */
  getDispute(id: string): Promise<Dispute | null>;
  putThread(t: SupportThread): void;
  addMessage(m: SupportMessage): void;
}

export interface SupportStore {
  runTransaction<T>(fn: (tx: SupportTx) => Promise<T>): Promise<T>;
  listAwaitingStaff(limit: number): Promise<readonly SupportThread[]>;
  listMessages(threadId: string, limit: number): Promise<readonly SupportMessage[]>;
}

export interface SupportDeps {
  readonly store: SupportStore;
  readonly names: DisplayNames;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

export interface SendSupportMessageInput {
  readonly threadId?: string | null;
  readonly clientId: string;
  readonly text: string;
}

function parseSendInput(raw: unknown): SendSupportMessageInput {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  const clientId = typeof r.clientId === 'string' ? r.clientId.trim() : '';
  if (!clientId) {
    throw new DomainError('invalid_argument');
  }
  const text = typeof r.text === 'string' ? r.text.trim() : '';
  const len = graphemeCount(text);
  if (len === 0 || len > SUPPORT_TEXT_MAX) {
    throw new DomainError('invalid_argument');
  }
  const threadId = typeof r.threadId === 'string' ? r.threadId.trim() : null;
  return {
    threadId,
    clientId,
    text,
  };
}

function checkRateLimit(
  currentRate: SupportRateEntry | undefined,
  now: Date,
): { rate: SupportRateEntry } {
  const windowMs = SUPPORT_RATE_WINDOW_MINUTES * 60 * 1000;
  if (!currentRate) {
    return { rate: { windowStart: now.toISOString(), count: 1 } };
  }
  const start = new Date(currentRate.windowStart).getTime();
  if (Number.isNaN(start) || now.getTime() - start >= windowMs) {
    return { rate: { windowStart: now.toISOString(), count: 1 } };
  }
  if (currentRate.count >= SUPPORT_RATE_LIMIT) {
    throw new DomainError('limit_exceeded');
  }
  return { rate: { windowStart: currentRate.windowStart, count: currentRate.count + 1 } };
}

export async function sendSupportMessage(
  deps: SupportDeps,
  senderId: string,
  raw: unknown,
): Promise<{ threadId: string; messageId: string }> {
  const input = parseSendInput(raw);
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    let thread: SupportThread;
    let targetThreadId: string;
    let senderRole: SupportSenderRole = 'user';

    if (input.threadId) {
      targetThreadId = input.threadId;
      const existing = await tx.getThread(targetThreadId);
      if (!existing) {
        throw new DomainError('not_found');
      }
      if (existing.kind === 'dispute') {
        // #142 Decision 8: the parties write while the dispute is open; the provider's messages are the "giải trình".
        const dispute = existing.disputeId ? await tx.getDispute(existing.disputeId) : null;
        if (!dispute) {
          throw new DomainError('not_found');
        }
        if (!dispute.parties.includes(senderId)) {
          throw new DomainError('permission_denied');
        }
        if (dispute.status !== 'open' || existing.status !== 'open') {
          throw new DomainError('not_eligible');
        }
        senderRole = senderId === dispute.customerId ? 'customer' : 'provider';
      } else if (!existing.participants.includes(senderId)) {
        throw new DomainError('permission_denied');
      }
      thread = existing;
    } else {
      targetThreadId = `help_${senderId}`;
      const existing = await tx.getThread(targetThreadId);
      if (existing) {
        if (!existing.participants.includes(senderId)) {
          throw new DomainError('permission_denied');
        }
        thread = existing;
      } else {
        thread = {
          id: targetThreadId,
          kind: 'help',
          ownerId: senderId,
          disputeId: null,
          participants: [senderId],
          status: 'open',
          awaitingStaff: true,
          lastMessageAt: null,
          lastMessagePreview: null,
          lastSenderRole: null,
          rate: {},
          createdAt: nowIso,
          updatedAt: nowIso,
        };
      }
    }

    // Idempotency check: clientId already recorded as message id
    const existingMsg = await tx.getMessage(targetThreadId, input.clientId);
    if (existingMsg) {
      return { threadId: targetThreadId, messageId: existingMsg.id };
    }

    // Rate limit check
    const currentRate = thread.rate[senderId];
    const { rate: nextSenderRate } = checkRateLimit(currentRate, now);

    const senderName = (await deps.names.displayName(senderId)) || 'Người dùng';
    const message: SupportMessage = {
      id: input.clientId,
      threadId: targetThreadId,
      senderId,
      senderRole,
      senderName,
      body: input.text,
      createdAt: nowIso,
    };

    const nextRate: Record<string, SupportRateEntry> = {
      ...thread.rate,
      [senderId]: nextSenderRate,
    };

    const updatedThread: SupportThread = {
      ...thread,
      awaitingStaff: true,
      lastMessageAt: nowIso,
      lastMessagePreview: truncateGraphemes(input.text, 80),
      lastSenderRole: senderRole,
      rate: nextRate,
      updatedAt: nowIso,
    };

    tx.putThread(updatedThread);
    tx.addMessage(message);

    return { threadId: targetThreadId, messageId: message.id };
  });
}

export interface StaffReplyInput {
  readonly threadId: string;
  readonly text: string;
}

function parseStaffReplyInput(raw: unknown): StaffReplyInput {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  const threadId = typeof r.threadId === 'string' ? r.threadId.trim() : '';
  if (!threadId) {
    throw new DomainError('invalid_argument');
  }
  const text = typeof r.text === 'string' ? r.text.trim() : '';
  const len = graphemeCount(text);
  if (len === 0 || len > SUPPORT_TEXT_MAX) {
    throw new DomainError('invalid_argument');
  }
  return { threadId, text };
}

export async function staffReply(
  deps: SupportDeps,
  staffId: string,
  raw: unknown,
): Promise<{ threadId: string; messageId: string }> {
  const input = parseStaffReplyInput(raw);
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const thread = await tx.getThread(input.threadId);
    if (!thread) {
      throw new DomainError('not_found');
    }

    const messageId = deps.ids.newId();
    const message: SupportMessage = {
      id: messageId,
      threadId: thread.id,
      senderId: staffId,
      senderRole: 'staff',
      senderName: 'Hỗ trợ',
      body: input.text,
      createdAt: nowIso,
    };

    const updatedThread: SupportThread = {
      ...thread,
      awaitingStaff: false,
      lastMessageAt: nowIso,
      lastMessagePreview: truncateGraphemes(input.text, 80),
      lastSenderRole: 'staff',
      updatedAt: nowIso,
    };

    tx.putThread(updatedThread);
    tx.addMessage(message);

    return { threadId: thread.id, messageId };
  });
}

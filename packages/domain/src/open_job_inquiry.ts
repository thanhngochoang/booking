import type { ChatDeps } from './chat_ports.js';
import type { JobDeps } from './job_ports.js';
import { chatIdFor, type Chat } from './chat.js';
import { DomainError } from './errors.js';

export interface OpenJobInquiryInput {
  readonly jobId: string;
  readonly photographerId?: string;
}

export async function openJobInquiry(
  deps: { job: JobDeps; chat: ChatDeps },
  uid: string,
  input: OpenJobInquiryInput,
): Promise<{ chatId: string }> {
  if (!input || typeof input !== 'object' || typeof input.jobId !== 'string') {
    throw new DomainError('invalid_argument', 'jobId');
  }
  const jobId = input.jobId.trim();

  // Read job
  const job = await deps.job.jobs.runTransaction(async (tx) => {
    return tx.getJob(jobId);
  });
  if (!job) {
    throw new DomainError('not_found');
  }

  const isOwner = job.customerId === uid;
  let customerId: string;
  let photographerId: string;
  let startedBy: 'customer' | 'photographer';

  if (isOwner) {
    if (!input.photographerId || typeof input.photographerId !== 'string') {
      throw new DomainError('invalid_argument', 'photographerId');
    }
    photographerId = input.photographerId.trim();
    customerId = uid;
    startedBy = 'customer';

    // Must have quote, invite or match on the job
    const allowed = await deps.job.jobs.runTransaction(async (tx) => {
      const q = await tx.getQuote(jobId, photographerId);
      if (q) return true;
      const inv = await tx.getInvite(jobId, photographerId);
      if (inv) return true;
      const matches = await tx.listMatches(jobId);
      if (matches.some((m) => m.photographerId === photographerId)) return true;
      return false;
    });

    if (!allowed) {
      throw new DomainError('permission_denied');
    }
  } else {
    // Caller is photographer
    photographerId = uid;
    customerId = job.customerId;
    startedBy = 'photographer';

    // Must be eligible photographer to read the job (open, or quoted/invited)
    const allowed = await deps.job.jobs.runTransaction(async (tx) => {
      if (job.status === 'open') return true;
      const q = await tx.getQuote(jobId, photographerId);
      if (q) return true;
      const inv = await tx.getInvite(jobId, photographerId);
      if (inv) return true;
      return false;
    });

    if (!allowed) {
      throw new DomainError('permission_denied');
    }
  }

  // Check if photographer accepts inquiries
  const accepts = await deps.chat.photographers.acceptsInquiries(photographerId);
  if (!accepts) {
    throw new DomainError('not_eligible');
  }

  const chatId = chatIdFor(customerId, photographerId);

  return deps.chat.chats.runTransaction(async (tx) => {
    const existing = await tx.getChat(chatId);
    const now = deps.chat.clock.now();

    if (existing) {
      // Existing chat: set jobId only, kind unchanged
      const updated: Chat = {
        ...existing,
        jobId,
        updatedAt: now,
      };
      tx.setChat(updated);
      return { chatId };
    }

    // New inquiry chat
    const newChat: Chat = {
      id: chatId,
      kind: 'inquiry',
      customerId,
      photographerId,
      bookingId: null,
      bookingStatus: null,
      jobId,
      startedBy,
      photographerRepliedAt: startedBy === 'customer' ? null : null,
      customerMessagesBeforeReply: 0,
      customerRepliedAt: null,
      photographerMessagesBeforeReply: 0,
      lastMessageAt: null,
      lastMessagePreview: null,
      lastSenderId: null,
      readOnlyAt: null,
      blockedAt: null,
      rescheduleUsed: false,
      createdAt: now,
      updatedAt: now,
    };

    tx.setChat(newChat);
    tx.incrementUnread(chatId, customerId, 0);
    tx.incrementUnread(chatId, photographerId, 0);

    return { chatId };
  });
}

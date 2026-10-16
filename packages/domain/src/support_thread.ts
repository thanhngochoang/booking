export type SupportThreadKind = 'help' | 'dispute';

export type SupportSenderRole = 'customer' | 'provider' | 'user' | 'staff' | 'system';

export interface SupportRateEntry {
  readonly windowStart: string;
  readonly count: number;
}

export interface SupportThread {
  readonly id: string;
  readonly kind: SupportThreadKind;
  readonly ownerId: string | null;
  readonly disputeId: string | null;
  readonly participants: readonly string[];
  readonly status: 'open' | 'closed';
  readonly awaitingStaff: boolean;
  readonly lastMessageAt: string | null;
  readonly lastMessagePreview: string | null;
  readonly lastSenderRole: SupportSenderRole | null;
  readonly rate: Readonly<Record<string, SupportRateEntry>>;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface SupportMessage {
  readonly id: string;
  readonly threadId: string;
  readonly senderId: string | null;
  readonly senderRole: SupportSenderRole;
  readonly senderName: string;
  readonly body: string;
  readonly createdAt: string;
}

export const SUPPORT_TEXT_MAX = 1000;
export const SUPPORT_RATE_LIMIT = 10; // messages
export const SUPPORT_RATE_WINDOW_MINUTES = 10;

// packages/domain/src/ports.ts
import type { ContactChannel, ContactChannels, ContactNumbers, ContactSubject } from './contact.js';

// Ports: what the domain needs from the outside. Firebase adapters live in
// app_flutter/firebase/functions/src/infra; a self-hosted server writes its own.

export interface Clock {
  now(): Date;
}

export interface IdGenerator {
  newId(): string;
}

/** `users/{uid}/private/contact` as stored. The domain validates it; it is not trusted. */
export interface UserContactRecord {
  readonly phone?: unknown;
}

export interface UserContactReader {
  get(uid: string): Promise<UserContactRecord | null>;
}

export interface BookingRecord {
  readonly id: string;
  readonly customerId: string;
  readonly photographerId: string;
  /** `BookingStatus` code; unknown codes are treated as locked. */
  readonly status: string;
  readonly completedAt: Date | null;
}

export interface BookingReader {
  /** One document. */
  get(id: string): Promise<BookingRecord | null>;
}

export interface RegistrationRecord {
  readonly id: string;
  readonly userId: string;
  /** Host photographer; null for platform-hosted events (no photographer number to open). */
  readonly photographerId: string | null;
  /** `RegistrationStatus` code. */
  readonly status: string;
  readonly eventEndsAt: Date | null;
}

export interface RegistrationReader {
  /** One document. */
  get(id: string): Promise<RegistrationRecord | null>;
}

export interface PhotographerContact {
  readonly channels: ContactChannels | null;
  readonly numbers: ContactNumbers | null;
}

export interface PhotographerContactReader {
  /** Public flags and private numbers together: two documents in one round trip. */
  read(photographerId: string): Promise<PhotographerContact>;
}

/** One row of `ContactAccessLog` (domain-model.md §2.7). Never holds a number. */
export interface ContactAccessLogEntry {
  readonly id: string;
  readonly requesterId: string;
  readonly subjectType: ContactSubject['type'];
  readonly subjectId: string;
  readonly channel: ContactChannel;
  readonly granted: boolean;
  readonly at: Date;
}

export interface ContactAccessLogWriter {
  append(entry: ContactAccessLogEntry): Promise<void>;
}

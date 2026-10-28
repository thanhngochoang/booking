/**
 * Passes (S30, plan #223 Decisions 7, 8, 14; spec §6.1): the one QR a customer shows for a paid booking,
 * entry ticket, or both (a booking with tickets shares one pass). A pass code is 8 random characters of
 * the transfer-code alphabet (30^8 ≈ 6.6·10¹¹), drawn with the caller's random source and drawn again
 * when `passes/{code}` is taken; it is shown as `VE-XXXX-XXXX`. `passes/{code8}` is server-only; the
 * customer reads the code from `bookings/{id}/private/pass` or `registrations/{rid}/private/pass`;
 * public documents carry only its last 4 characters (`Booking.passCode4`,
 * `RegistrationDoc.ticketCodeLast4`). Pure.
 */

import type { Booking } from './booking.js';
import { DomainError } from './errors.js';
import type { RandomBytes } from './ids.js';
import { TRANSFER_CODE_ALPHABET } from './payment_code.js';

/** `23456789ABCDEFGHJKMNPQRSTVWXYZ`: no 0, 1, I, L, O or U. */
export const PASS_ALPHABET = TRANSFER_CODE_ALPHABET;
export const PASS_CODE_LENGTH = 8;
/** Codes drawn before giving up (`conflict`); a clash is ~1 in 10¹¹ per draw. */
export const PASS_CODE_ATTEMPTS = 5;
/** The scan opens 2 hours before a booking's start or an event's `startAt` (spec §6.2). */
export const SCAN_OPEN_BEFORE_HOURS = 2;

/** `passes/{code8}` (server only). */
export interface PassRecord {
  readonly code8: string;
  readonly customerId: string;
  /** The day it is used (`yyyy-MM-dd`, Vietnam): the booking's day or the visit day. */
  readonly day: string;
  readonly bookingId: string | null;
  /** The event of `registrationIds` (one pass never spans two events); null without registrations. */
  readonly eventId: string | null;
  readonly registrationIds: readonly string[];
  readonly createdAt: string;
}

/** Where the customer's copy lives: `bookings/{id}/private/pass` or `events/{e}/registrations/{r}/private/pass`. */
export type PrivatePassRef = { readonly bookingId: string } | { readonly eventId: string; readonly regId: string };

/** The largest multiple of 30 below 256: bytes from here on are dropped so every character is equally likely. */
const ACCEPT_BELOW = Math.floor(256 / PASS_ALPHABET.length) * PASS_ALPHABET.length;

/** 8 characters, uniform over PASS_ALPHABET (rejection sampling over the random bytes). */
export function newPassCode(random: RandomBytes): string {
  let code = '';
  while (code.length < PASS_CODE_LENGTH) {
    // Only as many bytes as characters still missing: a rejected byte asks for one more.
    for (const b of random(PASS_CODE_LENGTH - code.length)) {
      if (b < ACCEPT_BELOW) code += PASS_ALPHABET.charAt(b % PASS_ALPHABET.length);
    }
  }
  return code;
}

/** Uppercase, trimmed, without `VE-` and dashes: 8 characters of the alphabet → the code, else null. */
export function normalizePassCode(raw: string): string | null {
  let s = raw.trim().toUpperCase();
  if (s.startsWith('VE-')) s = s.slice(3);
  s = s.replace(/-/g, '');
  if (s.length !== PASS_CODE_LENGTH) return null;
  return [...s].every((ch) => PASS_ALPHABET.includes(ch)) ? s : null;
}

export const isPassCode = (raw: string): boolean => normalizePassCode(raw) !== null;

export const passDisplay = (code8: string): string => `VE-${code8.slice(0, 4)}-${code8.slice(4)}`;

/** The last 4 random characters: what public documents and lists show (never a date). */
export const passCode4 = (code8: string): string => code8.slice(PASS_CODE_LENGTH - 4);

/**
 * A code no pass holds yet: draws one, asks `taken` (a transaction read, so every caller does it
 * before its first write) and draws again on a clash. `conflict` after PASS_CODE_ATTEMPTS clashes.
 */
export async function freshPassCode(random: RandomBytes, taken: (code8: string) => Promise<boolean>): Promise<string> {
  for (let i = 0; i < PASS_CODE_ATTEMPTS; i++) {
    const code = newPassCode(random);
    if (!(await taken(code))) return code;
  }
  throw new DomainError('conflict');
}

/** Decision 14: every paid booking gets a pass except an instant one (#140: it confirms on the spot). */
export const bookingGetsPass = (b: Pick<Booking, 'source'>): boolean => b.source !== 'instant';

export function newPass(p: {
  readonly code8: string;
  readonly customerId: string;
  readonly day: string;
  readonly bookingId: string | null;
  readonly eventId: string | null;
  readonly registrationIds: readonly string[];
  readonly now: Date;
}): PassRecord {
  return {
    code8: p.code8,
    customerId: p.customerId,
    day: p.day,
    bookingId: p.bookingId,
    eventId: p.registrationIds.length > 0 ? p.eventId : null,
    registrationIds: [...p.registrationIds],
    createdAt: p.now.toISOString(),
  };
}

/** What writes a pass: the record and each customer copy (the booking's and every registration's). */
export interface PassWriter {
  putPass(p: PassRecord): Promise<void> | void;
  putPrivatePass(ref: PrivatePassRef, code8: string): Promise<void> | void;
}

/** Writes only: `passes/{code8}` and the private copy of each of its parts. */
export async function writePass(tx: PassWriter, pass: PassRecord): Promise<void> {
  await tx.putPass(pass);
  if (pass.bookingId !== null) await tx.putPrivatePass({ bookingId: pass.bookingId }, pass.code8);
  const eventId = pass.eventId;
  if (eventId === null) return;
  for (const regId of pass.registrationIds) await tx.putPrivatePass({ eventId, regId }, pass.code8);
}

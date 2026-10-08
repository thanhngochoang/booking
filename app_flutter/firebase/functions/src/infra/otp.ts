import { createHash, randomBytes } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { DomainError, type OtpCrypto, type OtpPhoneReader, type OtpSender } from '@photobooking/domain';
import { fakePaymentsAllowed } from './fake_payments.js';

type Env = Readonly<Record<string, string | undefined>>;

/**
 * The fake OTP channel exists exactly where fake payments do (Decision 10): the dev project, or
 * the emulator on a `demo-*` project. Nowhere else (no SMS vendor yet; Needs the owner 2).
 */
export function fakeOtpAllowed(env: Env = process.env): boolean {
  return fakePaymentsAllowed(env);
}

/**
 * Where the fake is allowed, the code is logged (`fake otp`, `{uid, code}`) so a tester reads it
 * in the emulator UI (:4000 → Logs); never the phone. Elsewhere sending is refused `not_eligible`.
 */
export function otpSender(env: Env = process.env, uid?: string): OtpSender {
  if (!fakeOtpAllowed(env)) {
    return {
      send: async () => {
        throw new DomainError('not_eligible');
      },
    };
  }
  return {
    send: async ({ code }) => {
      logger.info('fake otp', { ...(uid !== undefined ? { uid } : {}), code });
    },
  };
}

/** SHA-256 (lower-case hex) and a CSPRNG. */
export const nodeOtpCrypto: OtpCrypto = {
  sha256Hex: async (input) => createHash('sha256').update(input, 'utf8').digest('hex'),
  random: (n) => new Uint8Array(randomBytes(n)),
};

/**
 * The phone the OTP goes to: `photographers/{uid}/private/contact.phone` (every set-up
 * photographer has one, S08.05). #135 may switch this to the verified phone; the port stays.
 */
export class FirestorePhotographerPhoneReader implements OtpPhoneReader {
  constructor(private readonly db: Firestore) {}

  async phoneOf(uid: string): Promise<string | null> {
    const snap = await this.db.collection('photographers').doc(uid).collection('private').doc('contact').get();
    const phone: unknown = snap.data()?.phone;
    return typeof phone === 'string' && phone.trim() !== '' ? phone : null;
  }
}

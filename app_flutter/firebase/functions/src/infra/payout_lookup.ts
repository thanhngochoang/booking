import type { Firestore } from 'firebase-admin/firestore';
import { FakeAccountNameLookup, type AccountNameLookup, type VerifiedNameReader } from '@photobooking/domain';
import { fakePayoutsMode } from './fake_payments.js';

/**
 * The verified legal name: `users/{uid}/private/identity.legalName` (identity spec §3, written by
 * #135; the seed writes An's). Blank or missing → null. Server read only (the owner can read the
 * doc too, but never writes it).
 */
export class FirestoreVerifiedNameReader implements VerifiedNameReader {
  constructor(private readonly db: Firestore) {}

  async legalName(uid: string): Promise<string | null> {
    const snap = await this.db.collection('users').doc(uid).collection('private').doc('identity').get();
    const name: unknown = snap.data()?.legalName;
    return typeof name === 'string' && name.trim() !== '' ? name : null;
  }
}

/**
 * The bank's holder-name lookup (Decision 11). `fake` is the domain's one fake, echoing
 * `echoName` (the caller's verified name); `off` always answers `unsupported` (no intermediary
 * adapter yet: staff compares the name before the first payout). Never logs the number.
 */
export function accountNameLookup(mode: 'fake' | 'off', echoName: string | null): AccountNameLookup {
  if (mode === 'fake') return new FakeAccountNameLookup(echoName);
  return { lookup: async () => ({ status: 'unsupported' }) };
}

/**
 * `fake` only where fake payouts run (`payoutsMode()`) AND fake payments are allowed (the dev
 * project or the emulator on `demo-*`): the echo would match any number to the caller's own name,
 * so a stray `PAYOUTS_MODE=fake` on another project still gets `off` (staff review). Same gate as
 * `createPayouts` (`fakePayoutsMode`).
 */
export function lookupMode(env: Readonly<Record<string, string | undefined>> = process.env): 'fake' | 'off' {
  return fakePayoutsMode(env);
}

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import { DomainError, type OtpChallenge } from '@photobooking/domain';
import { DEV_PROJECT_ID } from '../../src/config.js';
import { FirestorePhotographerPhoneReader, fakeOtpAllowed, nodeOtpCrypto, otpSender } from '../../src/infra/otp.js';
import { FirestoreVerifiedNameReader, accountNameLookup, lookupMode } from '../../src/infra/payout_lookup.js';
import {
  OTP_CHALLENGES_COLLECTION,
  PAYOUT_LOOKUPS_COLLECTION,
  otpChallengeDocId,
  otpChallengeFromFirestore,
  otpChallengeToFirestore,
} from '../../src/infra/payout_firestore.js';
import { captureLogs } from './support/payment_world.js';

const EMULATOR = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-nag' };
const target = (accountNumber: string) => ({ bankCode: 'VCB', accountNumber });

/** A Firestore stand-in that serves one document per path (`a/b/c/d`). */
function docsDb(docs: Record<string, Record<string, unknown>>): { db: Firestore; reads: string[] } {
  const reads: string[] = [];
  const at = (path: string[]): unknown => ({
    collection: (c: string) => ({ doc: (d: string) => at([...path, c, d]) }),
    get: async () => {
      const key = path.join('/');
      reads.push(key);
      const data = docs[key];
      return { exists: data !== undefined, data: () => data };
    },
  });
  return { db: at([]) as unknown as Firestore, reads };
}

describe('account name lookup adapters', () => {
  it('fake lookup echoes the verified name; 4321 → TRAN VAN B; 9999 → unsupported; 0404 → not_found', async () => {
    const lookup = accountNameLookup('fake', 'Nguyễn Văn An');
    assert.deepEqual(await lookup.lookup(target('0123456789')), { status: 'found', holderName: 'Nguyễn Văn An' });
    assert.deepEqual(await lookup.lookup(target('5554321')), { status: 'found', holderName: 'TRAN VAN B' });
    assert.deepEqual(await lookup.lookup(target('5559999')), { status: 'unsupported' });
    assert.deepEqual(await lookup.lookup(target('5550404')), { status: 'not_found' });
    // No verified name to echo: the bank "does not support" the lookup (staff compares).
    assert.deepEqual(await accountNameLookup('fake', null).lookup(target('0123456789')), { status: 'unsupported' });
  });

  it('off lookup is unsupported', async () => {
    const lookup = accountNameLookup('off', 'Nguyễn Văn An');
    for (const n of ['0123456789', '5554321', '5550404']) {
      assert.deepEqual(await lookup.lookup(target(n)), { status: 'unsupported' });
    }
  });

  it('the lookup is fake only on the emulator (demo-*) or the dev project in fake payout mode', () => {
    assert.equal(lookupMode(EMULATOR), 'fake');
    assert.equal(lookupMode({ GCLOUD_PROJECT: DEV_PROJECT_ID, PAYOUTS_MODE: 'fake' }), 'fake');
    assert.equal(lookupMode({ GCLOUD_PROJECT: DEV_PROJECT_ID }), 'off');
    assert.equal(lookupMode({ GCLOUD_PROJECT: 'booking-prod-1', PAYOUTS_MODE: 'fake' }), 'off');
    assert.equal(lookupMode({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'booking-prod-1' }), 'off');
  });

  it('the verified name is users/{uid}/private/identity.legalName; blank or missing is null', async () => {
    const { db, reads } = docsDb({
      'users/p1/private/identity': { legalName: 'Nguyễn Văn An' },
      'users/p2/private/identity': { legalName: '  ' },
      'users/p3/private/identity': { legalName: 7 },
    });
    const names = new FirestoreVerifiedNameReader(db);
    assert.equal(await names.legalName('p1'), 'Nguyễn Văn An');
    assert.equal(await names.legalName('p2'), null);
    assert.equal(await names.legalName('p3'), null);
    assert.equal(await names.legalName('p4'), null);
    assert.deepEqual(reads, [
      'users/p1/private/identity',
      'users/p2/private/identity',
      'users/p3/private/identity',
      'users/p4/private/identity',
    ]);
  });
});

describe('OTP adapters', () => {
  it('fakeOtpAllowed: emulator on demo-* and the dev project only; FUNCTIONS_EMULATOR on another project is false', () => {
    assert.equal(fakeOtpAllowed(EMULATOR), true);
    assert.equal(fakeOtpAllowed({ GCLOUD_PROJECT: DEV_PROJECT_ID }), true);
    assert.equal(fakeOtpAllowed({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'booking-prod-1' }), false);
    assert.equal(fakeOtpAllowed({ FUNCTIONS_EMULATOR: 'true' }), false);
    assert.equal(fakeOtpAllowed({ GCLOUD_PROJECT: 'booking-prod-1' }), false);
    assert.equal(fakeOtpAllowed({}), false);
  });

  it('the off sender refuses with not_eligible', async () => {
    const sender = otpSender({ GCLOUD_PROJECT: 'booking-prod-1' }, 'p1');
    await assert.rejects(
      sender.send({ phone: '+84912000001', code: '123456', purpose: 'payout_account' }),
      (e: unknown) => e instanceof DomainError && e.code === 'not_eligible',
    );
  });

  it('the fake sender logs the uid and the code, never the phone', async (t) => {
    const sender = otpSender(EMULATOR, 'p1');
    const lines = await captureLogs(t, () => sender.send({ phone: '+84912000001', code: '042424', purpose: 'payout_account' }));
    const logged = lines.filter((l) => l.includes('fake otp'));
    assert.equal(logged.length, 1, lines.join(''));
    assert.match(logged[0] ?? '', /"uid":"p1"/);
    assert.match(logged[0] ?? '', /"code":"042424"/);
    assert.doesNotMatch(logged[0] ?? '', /912000001|phone/);
  });

  it('nodeOtpCrypto hashes deterministically and random gives n bytes', async () => {
    const a = await nodeOtpCrypto.sha256Hex('salt:123456');
    assert.equal(a, await nodeOtpCrypto.sha256Hex('salt:123456'));
    assert.match(a, /^[0-9a-f]{64}$/);
    assert.notEqual(a, await nodeOtpCrypto.sha256Hex('salt:123457'));
    // SHA-256 of the empty string (a known vector).
    assert.equal(await nodeOtpCrypto.sha256Hex(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    for (const n of [4, 16]) {
      const r = nodeOtpCrypto.random(n);
      assert.ok(r instanceof Uint8Array);
      assert.equal(r.length, n);
    }
    assert.notDeepEqual(nodeOtpCrypto.random(16), nodeOtpCrypto.random(16));
  });

  it('the OTP phone is photographers/{uid}/private/contact.phone', async () => {
    const { db, reads } = docsDb({
      'photographers/p1/private/contact': { phone: '+84912000001' },
      'photographers/p2/private/contact': { zaloPhone: '+84912000002' },
    });
    const phones = new FirestorePhotographerPhoneReader(db);
    assert.equal(await phones.phoneOf('p1'), '+84912000001');
    assert.equal(await phones.phoneOf('p2'), null);
    assert.equal(await phones.phoneOf('p3'), null);
    assert.deepEqual(reads, ['photographers/p1/private/contact', 'photographers/p2/private/contact', 'photographers/p3/private/contact']);
  });
});

describe('otp_challenges and payout_lookups mapping', () => {
  const challenge: OtpChallenge = {
    uid: 'p1',
    purpose: 'payout_account',
    codeHash: 'c'.repeat(64),
    salt: 'a'.repeat(32),
    targetHash: 't'.repeat(64),
    expiresAt: '2026-10-10T12:05:00.000Z',
    attempts: 2,
    sentAt: '2026-10-10T12:00:00.000Z',
    sendDay: '2026-10-10',
    sendsToday: 3,
    consumedAt: null,
  };

  it('server-only collections and one challenge per uid', () => {
    assert.equal(OTP_CHALLENGES_COLLECTION, 'otp_challenges');
    assert.equal(PAYOUT_LOOKUPS_COLLECTION, 'payout_lookups');
    assert.equal(otpChallengeDocId('p1'), 'p1_payout_account');
  });

  it('a challenge round-trips with Timestamps and holds no code', () => {
    const doc = otpChallengeToFirestore(challenge);
    assert.ok(doc.expiresAt instanceof Timestamp);
    assert.ok(doc.sentAt instanceof Timestamp);
    assert.equal(doc.consumedAt, null);
    assert.deepEqual(Object.keys(doc).sort(), [
      'attempts', 'codeHash', 'consumedAt', 'expiresAt', 'purpose', 'salt', 'sendDay', 'sendsToday', 'sentAt', 'targetHash', 'uid',
    ]);
    assert.deepEqual(otpChallengeFromFirestore(doc), challenge);
    const consumed = { ...challenge, consumedAt: '2026-10-10T12:01:00.000Z' };
    assert.deepEqual(otpChallengeFromFirestore(otpChallengeToFirestore(consumed)), consumed);
  });

  it('a missing or malformed challenge reads as none', () => {
    assert.equal(otpChallengeFromFirestore(undefined), null);
    assert.equal(otpChallengeFromFirestore({ ...otpChallengeToFirestore(challenge), codeHash: 1 }), null);
    assert.equal(otpChallengeFromFirestore({ ...otpChallengeToFirestore(challenge), expiresAt: 'soon' }), null);
  });
});

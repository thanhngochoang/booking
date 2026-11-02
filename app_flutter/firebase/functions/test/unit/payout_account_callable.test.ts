import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { FakeAccountNameLookup, FakeOtpSender, MemoryPayoutStore, type PayoutAccountDeps } from '@photobooking/domain';
import {
  handleLookupPayoutAccountName,
  handleRequestPayoutOtp,
  handleSavePayoutAccount,
} from '../../src/callables/payout_account.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';
import { captureLogs } from './support/payment_world.js';

const NOW = new Date('2026-10-10T12:00:00.000Z');
const KEY = Buffer.alloc(32, 3).toString('base64');
const INPUT = { bankCode: 'VCB', accountNumber: '0123 456 789' };
const CHANGE = { bankCode: 'VCB', accountNumber: '9876543210' };
const EMULATOR = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-nag' };
const PROD = { GCLOUD_PROJECT: 'booking-prod-1' };
// The test crypto's random() gives zero bytes, so every code is 000000.
const RIGHT_CODE = '000000';

/**
 * A captured log line without the stack trace logger.error appends to `message` (its file line
 * numbers are not data): every field, and the message's first line.
 */
function logPayload(line: string): string {
  try {
    const entry = JSON.parse(line) as Record<string, unknown>;
    const message = typeof entry.message === 'string' ? entry.message.split('\n')[0] : entry.message;
    return JSON.stringify({ ...entry, message });
  } catch {
    return line;
  }
}

const refusedWith = (transport: string, code: string) => (e: unknown) =>
  e instanceof HttpsError && e.code === transport && (e.details as { code: string }).code === code;

describe('payout account callables', () => {
  let store: MemoryPayoutStore;
  let sender: FakeOtpSender;
  let n: number;
  const deps = (over: Partial<PayoutAccountDeps> = {}): PayoutAccountDeps => ({
    store,
    cipher: aesGcmCipher(KEY),
    clock: { now: () => NOW },
    ids: { newId: () => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n++).padStart(2, '0')}` },
    lookup: new FakeAccountNameLookup('Nguyễn Văn An'),
    names: { legalName: async () => 'Nguyễn Văn An' },
    otp: {
      sender,
      phones: { phoneOf: async () => '0912345678' },
      crypto: { sha256Hex: async (s) => s, random: (k) => new Uint8Array(k) },
    },
    notices: { accountNeeded: async () => undefined, accountChanged: async () => undefined },
    ...over,
  });
  const p1 = (data: unknown) => ({ auth: { uid: 'p1' }, data });

  beforeEach(() => {
    store = new MemoryPayoutStore();
    store.seedRole('p1', 'photographer');
    store.seedRole('c1', 'customer');
    sender = new FakeOtpSender();
    n = 10;
  });

  describe('lookupPayoutAccountName', () => {
    it('lookup without auth is unauthenticated', async () => {
      await assert.rejects(handleLookupPayoutAccountName({ data: INPUT }, deps()), (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated');
      assert.equal(store.lookupQuotas.size, 0);
    });

    it('lookup passes data through and returns the decision', async () => {
      assert.deepEqual(await handleLookupPayoutAccountName(p1(INPUT), deps()), {
        decision: 'matched',
        holderName: 'NGUYEN VAN AN',
        verifiedName: 'Nguyễn Văn An',
      });
      assert.deepEqual(await handleLookupPayoutAccountName(p1({ ...INPUT, accountNumber: '5554321' }), deps()), {
        decision: 'mismatch',
        holderName: 'TRAN VAN B',
        verifiedName: 'Nguyễn Văn An',
      });
      await assert.rejects(handleLookupPayoutAccountName({ auth: { uid: 'c1' }, data: INPUT }, deps()), refusedWith('permission-denied', 'permission_denied'));
      await assert.rejects(handleLookupPayoutAccountName(p1({ ...INPUT, holderName: 'X' }), deps()), refusedWith('invalid-argument', 'invalid_argument'));
      assert.equal(store.lookupQuotas.get('p1')?.count, 2);
    });

    it('lookup callable logs only the code', async (t) => {
      const NUMBER = '0123456789';
      const throwing = deps({
        lookup: {
          lookup: async () => {
            throw new Error(`bank said no for ${NUMBER}`);
          },
        },
      });
      const lines = await captureLogs(t, async () => {
        await handleLookupPayoutAccountName(p1({ bankCode: 'VCB', accountNumber: NUMBER }), deps()); // success: logs nothing
        await assert.rejects(handleLookupPayoutAccountName({ auth: { uid: 'c1' }, data: { bankCode: 'VCB', accountNumber: NUMBER } }, deps()));
        await assert.rejects(handleLookupPayoutAccountName(p1({ bankCode: 'VCB', accountNumber: `x${NUMBER}y` }), deps()));
        await assert.rejects(handleLookupPayoutAccountName(p1({ bankCode: 'VCB', accountNumber: NUMBER }), throwing));
        store.lookupQuotas.set('p1', { day: '2026-10-10', count: 20 });
        await assert.rejects(handleLookupPayoutAccountName(p1({ bankCode: 'VCB', accountNumber: NUMBER }), deps()));
      });
      const logged = lines.filter((l) => l.includes('lookupPayoutAccountName'));
      assert.equal(logged.length, 4, lines.join(''));
      for (const l of lines.map(logPayload)) {
        // No run of the number's digits (nor any 4 digits) in any log argument, and no name.
        assert.doesNotMatch(l, /\d{4}/, `a log line carries digits: ${l.replace(/\d/g, '#')}`);
        assert.doesNotMatch(l, /NGUY|Nguy|TRAN|VCB/, 'a log line carries a name or bank');
      }
      assert.match(logged[0] ?? '', /"code":"permission_denied"/);
      assert.match(logged[1] ?? '', /"code":"invalid_argument"/);
      assert.match(logged[2] ?? '', /"code":"internal"/);
      assert.match(logged[3] ?? '', /"code":"limit_exceeded"/);
    });
  });

  describe('requestPayoutOtp', () => {
    it('requestPayoutOtp returns phoneLast4', async () => {
      await handleSavePayoutAccount(p1(INPUT), deps());
      assert.deepEqual(await handleRequestPayoutOtp(p1(CHANGE), deps(), EMULATOR), {
        phoneLast4: '5678',
        expiresInSeconds: 300,
        resendInSeconds: 60,
      });
      assert.deepEqual(sender.sent, [{ phone: '0912345678', code: RIGHT_CODE }]);
    });

    it('requestPayoutOtp without auth is unauthenticated', async () => {
      await assert.rejects(handleRequestPayoutOtp({ data: CHANGE }, deps(), EMULATOR), (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated');
    });

    it('outside fake mode it is not_eligible and spends no send', async () => {
      await handleSavePayoutAccount(p1(INPUT), deps());
      await assert.rejects(handleRequestPayoutOtp(p1(CHANGE), deps(), PROD), refusedWith('failed-precondition', 'not_eligible'));
      assert.equal(store.otpChallenges.size, 0);
      assert.deepEqual(sender.sent, []);
    });

    it('a resend within 60 s is limit_exceeded', async () => {
      await handleSavePayoutAccount(p1(INPUT), deps());
      await handleRequestPayoutOtp(p1(CHANGE), deps(), EMULATOR);
      await assert.rejects(handleRequestPayoutOtp(p1(CHANGE), deps(), EMULATOR), refusedWith('resource-exhausted', 'limit_exceeded'));
    });
  });

  describe('savePayoutAccount', () => {
    it('unauthenticated save is refused', async () => {
      await assert.rejects(handleSavePayoutAccount({ data: INPUT }, deps()), (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated');
    });

    it('the first save stores ciphertext and the masked view', async () => {
      const res = await handleSavePayoutAccount(p1(INPUT), deps());
      assert.equal(res.accountLast4, '6789');
      assert.equal(res.nameStatus, 'matched');
      assert.equal(res.activeFrom, NOW.toISOString());
      const stored = [...store.accounts.values()][0];
      assert.ok(stored);
      assert.ok(!JSON.stringify(stored).includes('0123456789'));
      assert.equal(await aesGcmCipher(KEY).decrypt(stored.accountNumberEnc), '0123456789');
      assert.deepEqual(store.accountViews.get('p1')?.accountLast4, '6789');
    });

    it('save no longer reads auth_time (an old token still saves a first account)', async () => {
      const request = { auth: { uid: 'p1', token: { auth_time: Math.floor(NOW.getTime() / 1000) - 30 * 86_400 } }, data: INPUT };
      const res = await handleSavePayoutAccount(request, deps());
      assert.equal(res.accountLast4, '6789');
    });

    it('save maps name_mismatch / otp_invalid to failed-precondition with details.code', async () => {
      await assert.rejects(
        handleSavePayoutAccount(p1({ ...INPUT, accountNumber: '5554321' }), deps()),
        refusedWith('failed-precondition', 'name_mismatch'),
      );
      await handleSavePayoutAccount(p1(INPUT), deps());
      await assert.rejects(handleSavePayoutAccount(p1(CHANGE), deps()), refusedWith('failed-precondition', 'otp_required'));
      await handleRequestPayoutOtp(p1(CHANGE), deps(), EMULATOR);
      await assert.rejects(
        handleSavePayoutAccount(p1({ ...CHANGE, otpCode: '123456' }), deps()),
        refusedWith('failed-precondition', 'otp_invalid'),
      );
      const saved = await handleSavePayoutAccount(p1({ ...CHANGE, otpCode: RIGHT_CODE }), deps());
      assert.equal(saved.accountLast4, '3210');
      assert.equal(saved.activeFrom, new Date(NOW.getTime() + 72 * 3_600_000).toISOString());
    });

    it('changing to the account already active is conflict', async () => {
      await handleSavePayoutAccount(p1(INPUT), deps());
      await assert.rejects(handleSavePayoutAccount(p1(INPUT), deps()), refusedWith('aborted', 'conflict'));
    });

    it('a refused save logs only the code', async (t) => {
      const lines = await captureLogs(t, async () => {
        await assert.rejects(handleSavePayoutAccount({ auth: { uid: 'c1' }, data: INPUT }, deps())); // not a photographer
        await assert.rejects(handleSavePayoutAccount(p1({ ...INPUT, accountNumber: 'x0123456789y' }), deps()));
        await assert.rejects(handleSavePayoutAccount(p1({ ...INPUT, accountNumber: '5554321' }), deps()));
      });
      const logged = lines.filter((l) => l.includes('savePayoutAccount'));
      assert.equal(logged.length, 3, lines.join(''));
      for (const l of lines.map(logPayload)) {
        assert.doesNotMatch(l, /\d{4}/, `a log line carries digits: ${l.replace(/\d/g, '#')}`);
        assert.doesNotMatch(l, /NGUY|Nguy|TRAN|VCB/, 'a log line carries a name or bank');
      }
      assert.match(logged[0] ?? '', /"code":"permission_denied"/);
      assert.match(logged[1] ?? '', /"code":"invalid_argument"/);
      assert.match(logged[2] ?? '', /"code":"name_mismatch"/);
    });
  });
  describe('organizers (S06.06 for an active organizer)', () => {
    const org = (data: unknown, uid = 'org1') => ({ auth: { uid }, data });
    const orgDeps = () =>
      deps({
        lookup: new FakeAccountNameLookup('CÔNG TY TNHH BÃI ĐÁ'),
        businessNames: { legalName: async () => 'CÔNG TY TNHH BÃI ĐÁ' },
      });

    it('an active organizer passes the role check and saves; a customer who is not an organizer and a suspended organizer are permission-denied', async () => {
      store.seedOrganizer('org1', 'active');
      store.seedOrganizer('org2', 'suspended');
      assert.equal((await handleLookupPayoutAccountName(org(INPUT), orgDeps())).decision, 'matched');
      const saved = await handleSavePayoutAccount(org(INPUT), orgDeps());
      assert.equal(saved.accountLast4, '6789');
      assert.equal(store.organizerPayoutOk.get('org1'), true);
      for (const uid of ['c1', 'org2']) {
        await assert.rejects(handleSavePayoutAccount(org(INPUT, uid), orgDeps()), refusedWith('permission-denied', 'permission_denied'));
        await assert.rejects(handleLookupPayoutAccountName(org(INPUT, uid), orgDeps()), refusedWith('permission-denied', 'permission_denied'));
      }
      assert.equal(store.organizerPayoutOk.has('org2'), false);
    });
  });
});

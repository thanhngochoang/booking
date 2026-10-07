import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { MemoryPayoutStore, type PayoutAccountDeps } from '@photobooking/domain';
import { handleSavePayoutAccount } from '../../src/callables/payout_account.js';
import { aesGcmCipher } from '../../src/infra/account_cipher.js';

const NOW = new Date('2026-10-10T12:00:00.000Z');
const KEY = Buffer.alloc(32, 3).toString('base64');
const INPUT = { bankCode: 'VCB', accountNumber: '0123 456 789', holderName: 'Nguyễn Văn An' };

describe('savePayoutAccount callable', () => {
  let store: MemoryPayoutStore;
  let n: number;
  const deps = (): PayoutAccountDeps => ({
    store,
    cipher: aesGcmCipher(KEY),
    clock: { now: () => NOW },
    ids: { newId: () => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n++).padStart(2, '0')}` },
  });
  const authTime = (ageSeconds: number): number => Math.floor(NOW.getTime() / 1000) - ageSeconds;

  beforeEach(() => {
    store = new MemoryPayoutStore();
    store.seedRole('p1', 'photographer');
    n = 10;
  });

  it('unauthenticated save is refused', async () => {
    await assert.rejects(handleSavePayoutAccount({ data: INPUT }, deps()), (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated');
  });

  it('the first save stores ciphertext and the masked view', async () => {
    const res = await handleSavePayoutAccount({ auth: { uid: 'p1' }, data: INPUT }, deps());
    assert.equal(res.accountLast4, '6789');
    const stored = [...store.accounts.values()][0];
    assert.ok(stored);
    assert.ok(!JSON.stringify(stored).includes('0123456789'));
    assert.equal(await aesGcmCipher(KEY).decrypt(stored.accountNumberEnc), '0123456789');
    assert.deepEqual(store.accountViews.get('p1')?.accountLast4, '6789');
  });

  it('auth_time reaches the use case as authTime', async () => {
    await handleSavePayoutAccount({ auth: { uid: 'p1' }, data: INPUT }, deps());
    // A change with a fresh sign-in passes, a stale one asks for re-authentication.
    const change = { ...INPUT, accountNumber: '9876543210' };
    await assert.rejects(
      handleSavePayoutAccount({ auth: { uid: 'p1', token: { auth_time: authTime(3600) } }, data: change }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'failed-precondition' && (e.details as { code: string }).code === 'reauth_required',
    );
    await assert.rejects(handleSavePayoutAccount({ auth: { uid: 'p1' }, data: change }, deps()), (e: unknown) => e instanceof HttpsError && e.message === 'reauth_required');
    const ok = await handleSavePayoutAccount({ auth: { uid: 'p1', token: { auth_time: authTime(60) } }, data: change }, deps());
    assert.equal(ok.accountLast4, '3210');
  });

  it('a refused save logs only the code', async (t) => {
    const lines: string[] = [];
    const capture = (chunk: unknown): boolean => {
      lines.push(String(chunk));
      return true;
    };
    t.mock.method(process.stdout, 'write', capture);
    t.mock.method(process.stderr, 'write', capture);
    await assert.rejects(handleSavePayoutAccount({ auth: { uid: 'p2' }, data: INPUT }, deps())); // not a photographer
    await assert.rejects(handleSavePayoutAccount({ auth: { uid: 'p1' }, data: { ...INPUT, accountNumber: 'x0123456789y' } }, deps()));
    t.mock.restoreAll();
    const logged = lines.filter((l) => l.includes('savePayoutAccount'));
    assert.equal(logged.length, 2, lines.join(''));
    for (const l of logged) {
      assert.doesNotMatch(l, /\d{4}/, l);
      assert.doesNotMatch(l, /NGUY|Nguy|VCB/, l);
    }
    assert.match(logged[0] ?? '', /"code":"permission_denied"/);
    assert.match(logged[1] ?? '', /"code":"invalid_argument"/);
  });
});

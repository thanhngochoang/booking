import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { PROVIDER_RULES_VERSION, fakeIdNumberOf } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { ADMIN, BINH, GIANG, LAN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// S21 verification (#135, no fee until #203) on the Functions emulator: the real callables over
// FirestoreVerificationStore, the fake identity verifier and the dev vault (the emulator runs a
// demo-* project, so fakes are allowed). Needs the emulators; CI runs it (npm run test:integration).
// Bình walks the whole flow; two throwaway photographers race for one identity.

let app: App;
let db: Firestore;
let auth: Auth;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'verification-test');
  db = getFirestore(app);
  auth = getAuth(app);
  await applySeed(db, auth, new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const codeOf = (res: { error?: { details?: unknown } }) => (res.error?.details as { code?: string } | undefined)?.code;
const data = async (path: string) => (await db.doc(path).get()).data() ?? {};

/** A fresh onboarded individual photographer with a verified Auth phone equal to its contact phone. */
async function newPhotographer(uid: string, phone: string): Promise<void> {
  await auth.createUser({ uid, email: `${uid}@seed.test`, password: SEED_PASSWORD, displayName: uid, phoneNumber: phone });
  await db.doc(`users/${uid}`).set({ displayName: uid, role: 'photographer', createdAt: new Date(), updatedAt: new Date() });
  await db.doc(`photographers/${uid}`).set({ onboardingComplete: true, verified: false, acceptingOrders: false, createdAt: new Date() });
  await db.doc(`users/${uid}/private/contact`).set({ phone, phoneVerified: false, updatedAt: new Date() });
  tokens.set(uid, await signIn(`${uid}@seed.test`, SEED_PASSWORD));
}

describe('verification callables on the emulators', () => {
  test('two accounts with the same fake identity: one gets identity_in_use', async () => {
    const shared = '012345678901';
    await newPhotographer('int-ver-x', '+84976100001');
    await newPhotographer('int-ver-y', '+84976100002');
    for (const uid of ['int-ver-x', 'int-ver-y']) {
      await db.doc(`fake_identities/${uid}`).set({ idNumber: shared, legalName: 'NGUYỄN VĂN TRÙNG', dob: '1990-02-02' });
    }
    const sx = await call('startIdentityVerification', 'int-ver-x', { method: 'vneid' });
    const sy = await call('startIdentityVerification', 'int-ver-y', { method: 'nfc' });
    assert.equal(sx.status, 200, sx.text);
    assert.equal(sy.status, 200, sy.text);
    const [rx, ry] = await Promise.all([
      call('completeIdentityVerification', 'int-ver-x', { sessionId: (sx.result as { sessionId: string }).sessionId }),
      call('completeIdentityVerification', 'int-ver-y', { sessionId: (sy.result as { sessionId: string }).sessionId }),
    ]);
    const outcomes = [rx, ry].map((r) => (r.status === 200 ? 'passed' : codeOf(r))).sort();
    assert.deepEqual(outcomes, ['identity_in_use', 'passed'], `${rx.text} | ${ry.text}`);
    const loser = rx.status === 200 ? 'int-ver-y' : 'int-ver-x';
    assert.equal((rx.status === 200 ? ry : rx).status, 409);
    assert.equal((await db.doc(`users/${loser}/private/identity`).get()).exists, false);

    // A seeded identity (Giang's) is taken as well.
    await db.doc(`fake_identities/${BINH}`).set({ idNumber: fakeIdNumberOf(GIANG) });
    const sb = await call('startIdentityVerification', BINH, { method: 'vneid' });
    const rb = await call('completeIdentityVerification', BINH, { sessionId: (sb.result as { sessionId: string }).sessionId });
    assert.equal(codeOf(rb), 'identity_in_use', rb.text);
    await db.doc(`fake_identities/${BINH}`).delete();
  });

  test('full path on the emulator: phone, identity (fake), rules, submit, approve → photographers.acceptingOrders true', async () => {
    // As if S21.01 linked the OTP-verified number to the Auth user.
    await auth.updateUser(BINH, { phoneNumber: '+84987000001' });
    await db.doc(`users/${BINH}/private/contact`).set({ phone: '+84987000001', phoneVerified: false, updatedAt: new Date() });

    const phone = await call('confirmPhoneVerified', BINH, {});
    assert.deepEqual(phone.result, { phoneVerified: true }, phone.text);
    assert.equal((await data(`users/${BINH}/private/contact`)).phoneVerified, true);

    const early = await call('submitVerification', BINH, {});
    assert.equal(codeOf(early), 'not_eligible', early.text);

    const start = await call('startIdentityVerification', BINH, { method: 'vneid' });
    assert.equal(start.status, 200, start.text);
    const { sessionId, redirectUrl } = start.result as { sessionId: string; redirectUrl: string | null };
    assert.equal(redirectUrl, null);
    const done = await call('completeIdentityVerification', BINH, { sessionId });
    assert.equal((done.result as { result: string }).result, 'passed', done.text);
    const identity = await data(`users/${BINH}/private/identity`);
    assert.equal(identity.provider, 'fake');
    assert.ok(!JSON.stringify(identity).includes(fakeIdNumberOf(BINH)));
    assert.equal((await data(`identity_hashes/${identity.idHash as string}`)).uid, BINH);

    const rules = await call('acceptVerificationRules', BINH, { version: PROVIDER_RULES_VERSION });
    assert.deepEqual(rules.result, {}, rules.text);
    const submitted = await call('submitVerification', BINH, {});
    assert.deepEqual(submitted.result, { status: 'submitted' }, submitted.text);

    const notAdmin = await call('reviewVerification', BINH, { uid: BINH, action: 'approve' });
    assert.equal(codeOf(notAdmin), 'permission_denied', notAdmin.text);

    const approved = await call('reviewVerification', ADMIN, { uid: BINH, action: 'approve' });
    assert.deepEqual(approved.result, { status: 'approved' }, approved.text);
    const profile = await data(`photographers/${BINH}`);
    assert.equal(profile.verified, true);
    assert.equal(profile.acceptingOrders, true);
    const v = await data(`verifications/${BINH}`);
    assert.equal(v.status, 'approved');
    assert.equal(v.decidedBy, ADMIN);
    assert.equal(v.steps.fee, null);
    const audit = await db.collection('verificationAudit').where('uid', '==', BINH).where('action', '==', 'approve').get();
    assert.equal(audit.size, 1);
    const rows = await db.collection(`users/${BINH}/notifications`).where('type', '==', 'verification_approved').get();
    assert.equal(rows.size, 1);
  });

  test('createBooking refuses after revoke', async () => {
    const draft = {
      photographerId: BINH,
      serviceId: 'seed-service-family',
      day: '2026-12-05',
      start: '09:00',
      place: { name: 'Biển Mỹ Khê', point: { lat: 16.06, lng: 108.25 } },
      expectedPrice: 1_200_000,
    };
    const open = await call('createBooking', LAN, draft);
    assert.equal(open.status, 200, open.text);

    const shortNote = await call('reviewVerification', ADMIN, { uid: BINH, action: 'revoke', note: 'x' });
    assert.equal(codeOf(shortNote), 'invalid_argument', shortNote.text);
    const revoked = await call('reviewVerification', ADMIN, { uid: BINH, action: 'revoke', note: 'Tài khoản bị báo cáo giả mạo' });
    assert.deepEqual(revoked.result, { status: 'revoked' }, revoked.text);
    const profile = await data(`photographers/${BINH}`);
    assert.equal(profile.verified, false);
    assert.equal(profile.acceptingOrders, false);

    const refused = await call('createBooking', LAN, { ...draft, day: '2026-12-12' });
    assert.equal(refused.status, 400, refused.text);
    assert.equal(codeOf(refused), 'not_accepting_orders');
  });

  test('the seeded submitted record (Giang) is approved by staff and opens orders', async () => {
    const res = await call('reviewVerification', ADMIN, { uid: GIANG, action: 'approve' });
    assert.deepEqual(res.result, { status: 'approved' }, res.text);
    assert.equal((await data(`photographers/${GIANG}`)).acceptingOrders, true);
  });
});

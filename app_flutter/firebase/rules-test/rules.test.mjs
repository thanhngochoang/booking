import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, writeBatch, serverTimestamp, Timestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nag',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => env.cleanup());

test('user can create and update own profile with a valid role', async () => {
  const db = env.authenticatedContext('u1').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/u1'), { displayName: 'Lan', role: null }));
  await assertSucceeds(updateDoc(doc(db, 'users/u1'), { role: 'photographer' }));
});
test('user cannot write another user or an invalid role', async () => {
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(setDoc(doc(db, 'users/u2'), { displayName: 'X' }));
  await assertFails(setDoc(doc(db, 'users/u1'), { displayName: 'Lan', role: 'admin' }));
});
test('anyone signed in can read profiles; anonymous cannot', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'users/u9'), { displayName: 'P' }));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('u1').firestore(), 'users/u9')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/u9')));
});
const asPhotographer = (uid) => env.withSecurityRulesDisabled(async (c) =>
  setDoc(doc(c.firestore(), `users/${uid}`), { displayName: uid, role: 'photographer' }));

test('photographer doc only by owner; bookings are read-only for clients', async () => {
  await asPhotographer('u1'); await asPhotographer('u2');
  const db = env.authenticatedContext('u1').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/u1'), { onboardingComplete: false }));
  await assertFails(setDoc(doc(db, 'photographers/u2'), { onboardingComplete: false }));
  await assertFails(setDoc(doc(db, 'bookings/b1'), { customerId: 'u1', status: 'requested' }));
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'bookings/b2'), { customerId: 'u1', photographerId: 'u2', status: 'requested' }));
  await assertSucceeds(getDoc(doc(db, 'bookings/b2')));
  await assertFails(getDoc(doc(env.authenticatedContext('u3').firestore(), 'bookings/b2')));
});
test('client can create its photographer doc unverified, but never verify itself', async () => {
  await asPhotographer('p1'); await asPhotographer('p2');
  const db = env.authenticatedContext('p1').firestore();
  // Exactly what FirestoreUserRepository.setRole writes on role selection.
  await assertSucceeds(setDoc(doc(db, 'photographers/p1'), { onboardingComplete: false, verified: false, specialties: [] }));
  await assertFails(updateDoc(doc(db, 'photographers/p1'), { verified: true }));
  await assertFails(setDoc(doc(env.authenticatedContext('p2').firestore(), 'photographers/p2'), { verified: true }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/p1'), { onboardingComplete: true }));
});
test('users docs never hold an email address (readable by every signed-in user)', async () => {
  const db = env.authenticatedContext('e1').firestore();
  await assertFails(setDoc(doc(db, 'users/e1'), { displayName: 'E', email: 'e@x.vn' }));
  await assertSucceeds(setDoc(doc(db, 'users/e1'), { displayName: 'E' }));
  await assertFails(updateDoc(doc(db, 'users/e1'), { email: 'e@x.vn' }));
});

test('server-computed reputation fields are never client-writable', async () => {
  await asPhotographer('s1');
  const db = env.authenticatedContext('s1').firestore();
  await assertFails(setDoc(doc(db, 'photographers/s1'), { onboardingComplete: false, stats: { rating: 5, reviewCount: 9999 } }));
  await assertFails(setDoc(doc(db, 'photographers/s1'), { onboardingComplete: false, startingPrice: 1 }));
  await assertSucceeds(setDoc(doc(db, 'photographers/s1'), { onboardingComplete: false, verified: false, bio: 'Chân dung' }));
  await assertFails(updateDoc(doc(db, 'photographers/s1'), { 'stats.rating': 5 }));
  await assertFails(updateDoc(doc(db, 'photographers/s1'), { startingPrice: 1 }));
  await assertFails(updateDoc(doc(db, 'photographers/s1'), { anythingElse: true }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/s1'), { bio: 'Cưới', specialties: ['wedding'], onboardingComplete: true }));
});

test('only accounts with the photographer role may own a photographer doc', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'users/c1'), { displayName: 'C', role: 'customer' }));
  const db = env.authenticatedContext('c1').firestore();
  await assertFails(setDoc(doc(db, 'photographers/c1'), { onboardingComplete: false, verified: false }));
});

test('role selection batch (users role + photographer doc) is allowed', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'users/b1'), { displayName: 'B', role: null }));
  const db = env.authenticatedContext('b1').firestore();
  const batch = writeBatch(db);
  batch.update(doc(db, 'users/b1'), { role: 'photographer' });
  batch.set(doc(db, 'photographers/b1'), { onboardingComplete: false, verified: false, specialties: [] }, { merge: true });
  await assertSucceeds(batch.commit());
});

test('users docs accept only profile fields, never server counters', async () => {
  const db = env.authenticatedContext('k1').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/k1'), { displayName: 'K', role: null, avatarUrl: null }));
  await assertFails(updateDoc(doc(db, 'users/k1'), { followerCount: 100000 }));
  await assertFails(setDoc(doc(db, 'users/k2'.replace('k2', 'k1')), { displayName: 'K', savedCount: 5 }));
  await assertSucceeds(updateDoc(doc(db, 'users/k1'), { displayName: 'Kim', avatarUrl: 'https://x/y.jpg' }));
});

const contactPath = (uid) => `users/${uid}/private/contact`;

test('owner can save a valid private contact; defaults work', async () => {
  const db = env.authenticatedContext('c1').firestore();
  await assertSucceeds(setDoc(doc(db, contactPath('c1')), {
    phone: '+84903123456', allowZalo: true, allowWhatsApp: false, phoneVerified: false,
  }));
  await assertSucceeds(setDoc(doc(db, contactPath('c1')), { phone: '+84321234567' }, { merge: true }));
  await assertSucceeds(getDoc(doc(db, contactPath('c1'))));
});

test('nobody else can read or write someone\'s private contact', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), contactPath('c2')), { phone: '+84903123456' }));
  const other = env.authenticatedContext('c3').firestore();
  await assertFails(getDoc(doc(other, contactPath('c2'))));
  await assertFails(setDoc(doc(other, contactPath('c2')), { phone: '+84912345678' }));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), contactPath('c2'))));
});

test('contact rejects malformed numbers, extra fields and other documents', async () => {
  const db = env.authenticatedContext('c4').firestore();
  for (const phone of ['0903123456', '+8490312345', '+84123456789', '903123456', 123]) {
    await assertFails(setDoc(doc(db, contactPath('c4')), { phone }));
  }
  await assertFails(setDoc(doc(db, contactPath('c4')), { phone: '+84903123456', note: 'x' }));
  await assertFails(setDoc(doc(db, contactPath('c4')), { phone: '+84903123456', allowZalo: 'yes' }));
  await assertFails(setDoc(doc(db, 'users/c4/private/other'), { phone: '+84903123456' }));
  await assertFails(setDoc(doc(db, contactPath('c4')), {}));
});

test('a client can never mark its phone verified', async () => {
  const db = env.authenticatedContext('c5').firestore();
  await assertFails(setDoc(doc(db, contactPath('c5')), { phone: '+84903123456', phoneVerified: true }));
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), contactPath('c5')), { phone: '+84903123456', phoneVerified: true }));
  // Toggling a permission keeps the server's flag untouched.
  await assertSucceeds(updateDoc(doc(db, contactPath('c5')), { allowZalo: false }));
  await assertFails(updateDoc(doc(db, contactPath('c5')), { phoneVerified: false }));
});

test('the public users doc still refuses a phone field', async () => {
  const db = env.authenticatedContext('c6').firestore();
  await assertFails(setDoc(doc(db, 'users/c6'), { displayName: 'X', phone: '+84903123456' }));
});

test('changing the phone resets verification; omitting the flag on a change fails', async () => {
  const seed = (uid) => env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), contactPath(uid)), { phone: '+84903123456', phoneVerified: true }));
  await seed('v1');
  const db1 = env.authenticatedContext('v1').firestore();
  await assertSucceeds(setDoc(doc(db1, contactPath('v1')),
    { phone: '+84912345678', phoneVerified: false }, { merge: true }));
  await seed('v2');
  const db2 = env.authenticatedContext('v2').firestore();
  await assertFails(setDoc(doc(db2, contactPath('v2')), { phone: '+84912345678' }, { merge: true }));
  await assertSucceeds(updateDoc(doc(db2, contactPath('v2')), { allowZalo: false }));
});

test('updatedAt must be the server time', async () => {
  const db = env.authenticatedContext('t1').firestore();
  await assertFails(setDoc(doc(db, contactPath('t1')),
    { phone: '+84903123456', updatedAt: Timestamp.fromDate(new Date('2020-01-01')) }));
  await assertSucceeds(setDoc(doc(db, contactPath('t1')),
    { phone: '+84903123456', updatedAt: serverTimestamp() }));
});

const privateContact = (uid) => `photographers/${uid}/private/contact`;
const goodNumbers = { phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: '+14155552671' };
const allChannels = { call: true, zalo: true, whatsapp: true, acceptInquiries: true };

test('photographer saves numbers, public flags and service area in one batch', async () => {
  await asPhotographer('ph1');
  const db = env.authenticatedContext('ph1').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, privateContact('ph1')), goodNumbers);
  batch.set(doc(db, 'photographers/ph1'), {
    serviceArea: { city: 'Hà Nội', radiusKm: 20 },
    contactChannels: allChannels,
    onboardingComplete: true,
  }, { merge: true });
  await assertSucceeds(batch.commit());
  // Later edits: drop an own number by replacing the doc, flip one flag.
  await assertSucceeds(setDoc(doc(db, privateContact('ph1')), { phone: '+84903123456' }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/ph1'), { 'contactChannels': { ...allChannels, zalo: false } }));
});

test('the adapter write shape (with server timestamps) is accepted', async () => {
  await asPhotographer('ph1b');
  const db = env.authenticatedContext('ph1b').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, privateContact('ph1b')), { phone: '+84903123456', updatedAt: serverTimestamp() });
  batch.set(doc(db, 'photographers/ph1b'), {
    serviceArea: { city: 'Hà Nội', radiusKm: 20 },
    contactChannels: { call: true, zalo: false, whatsapp: false, acceptInquiries: true },
    onboardingComplete: true,
    updatedAt: serverTimestamp(),
  }, { merge: true });
  await assertSucceeds(batch.commit());
});

test('numbers are readable by their owner only, flags by every signed-in user', async () => {
  await asPhotographer('ph2'); await asPhotographer('ph3');
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), privateContact('ph2')), goodNumbers);
    await setDoc(doc(c.firestore(), 'photographers/ph2'), { contactChannels: allChannels, onboardingComplete: true });
  });
  await assertSucceeds(getDoc(doc(env.authenticatedContext('ph2').firestore(), privateContact('ph2'))));
  await assertFails(getDoc(doc(env.authenticatedContext('ph3').firestore(), privateContact('ph2')))); // another photographer
  await assertFails(getDoc(doc(env.authenticatedContext('some-customer').firestore(), privateContact('ph2'))));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), privateContact('ph2'))));
  const publicDoc = await assertSucceeds(getDoc(doc(env.authenticatedContext('some-customer').firestore(), 'photographers/ph2')));
  assert.equal(publicDoc.data().contactChannels.call, true);
  assert.ok(!JSON.stringify(publicDoc.data()).includes('+84'), 'the public photographer doc must hold no number');
  // Nobody else may write them either.
  await assertFails(setDoc(doc(env.authenticatedContext('ph3').firestore(), privateContact('ph2')), { phone: '+84903123456' }));
});

test('numbers never go onto the public photographer doc', async () => {
  await asPhotographer('ph4');
  const db = env.authenticatedContext('ph4').firestore();
  await assertFails(setDoc(doc(db, 'photographers/ph4'), { contact: { phone: '+84903123456' } }));
  await assertFails(setDoc(doc(db, 'photographers/ph4'), { phone: '+84903123456' }));
  await assertFails(setDoc(doc(db, 'photographers/ph4'), { contactChannels: { call: false, phone: '+84903123456' } }));
});

test('private contact validates every number and rejects extras', async () => {
  await asPhotographer('ph5');
  const db = env.authenticatedContext('ph5').firestore();
  const bad = [
    { phone: '0903123456' }, { phone: '+84123456789' }, { phone: '+8490312345' }, { phone: 5 }, {},
    { phone: '+84903123456', zaloPhone: '+14155552671' },      // Zalo must be Vietnamese
    { phone: '+84903123456', whatsappPhone: '0903123456' },    // WhatsApp needs a +country code
    { phone: '+84903123456', whatsappPhone: '+123' },
    { phone: '+84903123456', note: 'x' },
  ];
  for (const data of bad) await assertFails(setDoc(doc(db, privateContact('ph5')), data));
  await assertFails(setDoc(doc(db, 'photographers/ph5/private/other'), { phone: '+84903123456' }));
  await assertSucceeds(setDoc(doc(db, privateContact('ph5')), { phone: '+84903123456', whatsappPhone: '+14155552671' }));
});

test('only a photographer-role account may write private contact', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'users/cust-1'), { displayName: 'C', role: 'customer' }));
  await assertFails(setDoc(doc(env.authenticatedContext('cust-1').firestore(), privateContact('cust-1')), { phone: '+84903123456' }));
});

test('a channel cannot be public without a stored number, and flags are validated', async () => {
  await asPhotographer('ph6');
  const db = env.authenticatedContext('ph6').firestore();
  // No private doc yet: turning a channel on fails, all-off passes.
  await assertFails(setDoc(doc(db, 'photographers/ph6'), { contactChannels: { call: true } }, { merge: true }));
  await assertSucceeds(setDoc(doc(db, 'photographers/ph6'), { contactChannels: { call: false, zalo: false, whatsapp: false, acceptInquiries: true } }, { merge: true }));
  // Wrong shapes.
  await assertFails(setDoc(doc(db, 'photographers/ph6'), { contactChannels: { call: 'yes' } }, { merge: true }));
  await assertFails(setDoc(doc(db, 'photographers/ph6'), { contactChannels: { sms: true } }, { merge: true }));
  await assertFails(setDoc(doc(db, 'photographers/ph6'), { contactChannels: true }, { merge: true }));
  // Once the number exists in the same batch it works.
  const batch = writeBatch(db);
  batch.set(doc(db, privateContact('ph6')), { phone: '+84903123456' });
  batch.set(doc(db, 'photographers/ph6'), { contactChannels: { call: true } }, { merge: true });
  await assertSucceeds(batch.commit());
});

test('service area has a city and an integer radius', async () => {
  await asPhotographer('ph7');
  const db = env.authenticatedContext('ph7').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/ph7'), { serviceArea: { city: 'Đà Nẵng', radiusKm: 50 } }));
  for (const serviceArea of [
    { city: 'Đ', radiusKm: 50 }, { city: 'Đà Nẵng', radiusKm: 0 }, { city: 'Đà Nẵng', radiusKm: 201 },
    { city: 'Đà Nẵng', radiusKm: 12.5 }, { city: 'Đà Nẵng' }, { city: 'Đà Nẵng', radiusKm: 5, extra: 1 }, 'Đà Nẵng',
  ]) {
    await assertFails(setDoc(doc(db, 'photographers/ph7'), { serviceArea }));
  }
});

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, deleteField, arrayUnion, writeBatch, serverTimestamp, Timestamp, GeoPoint, collection, collectionGroup, query, where, or } from 'firebase/firestore';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nag',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: readFileSync('../storage.rules', 'utf8'), host: '127.0.0.1', port: 9199 },
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
test('acceptingOrders is server-only: not creatable, not changeable, unchanged keys pass', async () => {
  await asPhotographer('ao1'); await asPhotographer('ao2');
  const db = env.authenticatedContext('ao1').firestore();
  await assertFails(setDoc(doc(db, 'photographers/ao1'), { onboardingComplete: false, verified: false, acceptingOrders: true }));
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'photographers/ao2'), { onboardingComplete: true, verified: true, acceptingOrders: true, bio: 'x' }));
  const owner = env.authenticatedContext('ao2').firestore();
  await assertFails(updateDoc(doc(owner, 'photographers/ao2'), { acceptingOrders: false }));
  await assertSucceeds(updateDoc(doc(owner, 'photographers/ao2'), { bio: 'y' }));
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
  await assertFails(setDoc(doc(db, 'photographers/s1'), { onboardingComplete: false, stats: { tomatoPct: 100, reviewCount: 9999 } }));
  await assertFails(setDoc(doc(db, 'photographers/s1'), { onboardingComplete: false, startingPrice: 1 }));
  await assertSucceeds(setDoc(doc(db, 'photographers/s1'), { onboardingComplete: false, verified: false, bio: 'Chân dung' }));
  await assertFails(updateDoc(doc(db, 'photographers/s1'), { 'stats.score': 1 }));
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

test('photographer numbers: updatedAt must be the server time', async () => {
  await asPhotographer('ph1c');
  const db = env.authenticatedContext('ph1c').firestore();
  await assertFails(setDoc(doc(db, privateContact('ph1c')),
    { phone: '+84903123456', updatedAt: Timestamp.fromDate(new Date('2020-01-01')) }));
  await assertSucceeds(setDoc(doc(db, privateContact('ph1c')),
    { phone: '+84903123456', updatedAt: serverTimestamp() }));
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

// ---- discovery: posts, likes, saves, follows ----
test('any signed-in user reads posts; nobody writes them from the client yet', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'posts/post1'), { photographerId: 'p1', serviceId: 's1', imageUrls: ['x'] }));
  const db = env.authenticatedContext('v1').firestore();
  await assertSucceeds(getDoc(doc(db, 'posts/post1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'posts/post1')));
  await assertFails(setDoc(doc(db, 'posts/post2'), { photographerId: 'v1', serviceId: 's1', imageUrls: ['x'] }));
  await assertFails(updateDoc(doc(db, 'posts/post1'), { likeCount: 9999 }));
});

for (const [col, field, extra] of [['likes', 'postId', 'post1'], ['saves', 'postId', 'post1'], ['follows', 'photographerId', 'p1']]) {
  test(`${col}: the owner creates, reads (even a missing doc) and deletes their own marker`, async () => {
    const db = env.authenticatedContext('v1').firestore();
    const ref = doc(db, `${col}/v1_${extra}`);
    await assertSucceeds(getDoc(ref)); // a missing document must be readable to know "not liked"
    await assertSucceeds(setDoc(ref, { userId: 'v1', [field]: extra, createdAt: serverTimestamp() }));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(deleteDoc(ref));
  });

  test(`${col}: nobody else's marker can be read, created, changed or deleted`, async () => {
    await env.withSecurityRulesDisabled(async (c) =>
      setDoc(doc(c.firestore(), `${col}/v2_${extra}`), { userId: 'v2', [field]: extra }));
    const db = env.authenticatedContext('v1').firestore();
    await assertFails(getDoc(doc(db, `${col}/v2_${extra}`)));
    await assertFails(setDoc(doc(db, `${col}/v2_${extra}`), { userId: 'v2', [field]: extra, createdAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(db, `${col}/v2_${extra}`)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `${col}/v1_${extra}`)));
  });

  test(`${col}: a marker must match its document id and carry only the expected fields`, async () => {
    const db = env.authenticatedContext('v1').firestore();
    await assertFails(setDoc(doc(db, `${col}/v1_other`), { userId: 'v1', [field]: extra, createdAt: serverTimestamp() })); // id/target mismatch
    await assertFails(setDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v2', [field]: extra, createdAt: serverTimestamp() })); // wrong owner
    await assertFails(setDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v1', [field]: extra, createdAt: serverTimestamp(), weight: 5 })); // extra field
    await assertFails(setDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v1', [field]: extra, createdAt: Timestamp.fromMillis(1000) })); // client-chosen time
    await assertFails(setDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v1', [field]: extra })); // no createdAt
    await assertSucceeds(setDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v1', [field]: extra, createdAt: serverTimestamp() }));
  });

  test(`${col}: set() on an existing marker (idempotent write) keeps the same shape`, async () => {
    const db = env.authenticatedContext('v1').firestore();
    const ref = doc(db, `${col}/v1_${extra}`);
    await assertSucceeds(setDoc(ref, { userId: 'v1', [field]: extra, createdAt: serverTimestamp() }));
    await assertSucceeds(setDoc(ref, { userId: 'v1', [field]: extra, createdAt: serverTimestamp() })); // repeat
    await assertFails(setDoc(ref, { userId: 'v1', [field]: 'changed', createdAt: serverTimestamp() })); // retarget
    await assertFails(updateDoc(ref, { userId: 'v2' })); // change owner
    await assertFails(updateDoc(ref, { weight: 5 })); // extra field
  });
}

test('a client cannot touch counters on posts or users through likes', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'users/v1'), { displayName: 'V', role: 'photographer', followerCount: 3, savedCount: 1 });
    await setDoc(doc(c.firestore(), 'photographers/v1'), {
      onboardingComplete: true, verified: false, bio: 'x', followerCount: 3, stats: { tomatoPct: 90 },
    });
  });
  const db = env.authenticatedContext('v1').firestore();
  // Allowed updates still work, so the failures below are about the counters.
  await assertSucceeds(updateDoc(doc(db, 'users/v1'), { displayName: 'Vee' }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/v1'), { bio: 'y' }));
  await assertFails(updateDoc(doc(db, 'users/v1'), { savedCount: 10 }));
  await assertFails(updateDoc(doc(db, 'users/v1'), { followerCount: 10 }));
  await assertFails(updateDoc(doc(db, 'photographers/v1'), { followerCount: 10 }));
  await assertFails(updateDoc(doc(db, 'photographers/v1'), { 'stats.tomatoPct': 100 }));
  await assertFails(updateDoc(doc(db, 'photographers/v1'), { verified: true }));
});

test('saves: listing needs the userId filter and only your own', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'saves/l1_post1'), { userId: 'l1', postId: 'post1' });
    await setDoc(doc(c.firestore(), 'saves/l1_post2'), { userId: 'l1', postId: 'post2' });
    await setDoc(doc(c.firestore(), 'saves/l2_post1'), { userId: 'l2', postId: 'post1' });
  });
  const db = env.authenticatedContext('l1').firestore();
  const saves = collection(db, 'saves');
  const own = await assertSucceeds(getDocs(query(saves, where('userId', '==', 'l1'), where('postId', 'in', ['post1', 'post2']))));
  assert.equal(own.size, 2);
  await assertFails(getDocs(saves)); // no userId filter
  await assertFails(getDocs(query(saves, where('postId', '==', 'post1')))); // filter on something else
  await assertFails(getDocs(query(saves, where('userId', '==', 'l2')))); // someone else's
  await assertFails(getDocs(query(collection(env.unauthenticatedContext().firestore(), 'saves'), where('userId', '==', 'l1'))));
});

test('markers: uid v1 cannot get or delete v1_x_post1, which belongs to v1_x', async () => {
  for (const [col, field] of [['likes', 'postId'], ['saves', 'postId'], ['follows', 'photographerId']]) {
    await env.withSecurityRulesDisabled(async (c) =>
      setDoc(doc(c.firestore(), `${col}/v1_x_post1`), { userId: 'v1_x', [field]: 'post1' }));
    const db = env.authenticatedContext('v1').firestore();
    await assertFails(getDoc(doc(db, `${col}/v1_x_post1`)));
    await assertFails(deleteDoc(doc(db, `${col}/v1_x_post1`)));
    await assertFails(setDoc(doc(db, `${col}/v1_x_post1`), { userId: 'v1', [field]: 'x_post1', createdAt: serverTimestamp() }));
  }
});

test('markers: createdAt on a direct update is the server time or nothing', async () => {
  for (const [col, field, target] of [['likes', 'postId', 'post1'], ['saves', 'postId', 'post1'], ['follows', 'photographerId', 'p1']]) {
    await env.withSecurityRulesDisabled(async (c) =>
      setDoc(doc(c.firestore(), `${col}/u7_${target}`), { userId: 'u7', [field]: target, createdAt: Timestamp.fromMillis(5000) }));
    const ref = doc(env.authenticatedContext('u7').firestore(), `${col}/u7_${target}`);
    await assertSucceeds(updateDoc(ref, { createdAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { createdAt: Timestamp.fromMillis(1) }));
  }
});

// ---- photographers/{uid}.skills (plan 2c, spec 3e.2–3e.3) ----
const goodSkills = () => ({
  schemaVersion: 1,
  specialties: [
    { id: 'portrait', level: 3, evidencePostIds: ['post1', 'post2'] },
    { id: 'couple', level: 2, evidencePostIds: [] },
    { id: 'family', level: 1, evidencePostIds: [] },
  ],
  styles: ['natural_light', 'film'],
  extras: ['retouch', 'posing'],
  languages: ['vi', 'en'],
  audiences: ['couple', 'shy_subjects'],
  yearsExperience: 6,
});
const genre = (id, level = 2, evidencePostIds = []) => ({ id, level, evidencePostIds });
const skillsOwner = async (uid, extra = {}) => {
  await asPhotographer(uid);
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), `photographers/${uid}`), { onboardingComplete: false, verified: false, ...extra }));
  return env.authenticatedContext(uid).firestore();
};
const writeSkills = (db, uid, skills) => setDoc(doc(db, `photographers/${uid}`), { skills }, { merge: true });

test('a photographer can save valid skills in the spec shape', async () => {
  const db = await skillsOwner('k1');
  await assertSucceeds(writeSkills(db, 'k1', goodSkills()));
  await assertSucceeds(writeSkills(db, 'k1', { ...goodSkills(), yearsExperience: null }));
  await assertSucceeds(writeSkills(db, 'k1', {
    ...goodSkills(),
    specialties: [{ id: 'wedding', level: 2, years: 4, evidencePostIds: [] }],
    languages: ['vi', 'en', 'zh', 'ko', 'ja'],
  }));
});

test('skills reject ids outside the catalogue', async () => {
  const db = await skillsOwner('k2');
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), specialties: [genre('underwater')] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), specialties: [genre('shy_subjects')] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), styles: ['neon'] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), extras: ['juggling'] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), languages: ['fr'] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), audiences: ['kids'] }));
  await assertFails(writeSkills(db, 'k2', { ...goodSkills(), styles: [7] }));
});

test('skills enforce the limits', async () => {
  const db = await skillsOwner('k3');
  const seven = ['portrait', 'wedding', 'couple', 'family', 'graduation', 'event', 'product'].map((id) => genre(id));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: seven }));
  await assertSucceeds(writeSkills(db, 'k3', { ...goodSkills(), specialties: seven.slice(0, 6) }));
  const fourExperts = ['portrait', 'wedding', 'couple', 'family'].map((id, i) => genre(id, 3, [`e${i}`]));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: fourExperts }));
  await assertSucceeds(writeSkills(db, 'k3', { ...goodSkills(), specialties: fourExperts.slice(0, 3) }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: [genre('portrait', 2, ['a', 'b', 'c', 'd'])] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: [genre('portrait', 2, ['a', 'a'])] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: [genre('portrait', 2, ['a/b'])] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), specialties: [genre('portrait'), genre('portrait')] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), styles: ['natural_light', 'film', 'minimal', 'editorial', 'documentary'] }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), styles: ['film', 'film'] }));
  await assertFails(writeSkills(db, 'k3', {
    ...goodSkills(),
    extras: ['retouch', 'posing', 'video', 'drone', 'studio', 'kids', 'pets', 'low_light', 'outdoor'],
  }));
  await assertFails(writeSkills(db, 'k3', { ...goodSkills(), audiences: ['couple', 'family_kids', 'business', 'foreigner', 'shy_subjects'] }));
});

test('level 3 needs evidence; levels are the integers 1..3', async () => {
  const db = await skillsOwner('k4');
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [genre('portrait', 3, [])] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [{ id: 'portrait', level: 3 }] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [genre('portrait', 4)] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [genre('portrait', 0)] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [genre('portrait', '3', ['a'])] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [{ ...genre('portrait'), note: 'x' }] }));
  await assertFails(writeSkills(db, 'k4', { ...goodSkills(), specialties: [{ ...genre('portrait'), years: 60 }] }));
});

test('at least one genre and one language; years 0..50', async () => {
  const db = await skillsOwner('k5');
  await assertFails(writeSkills(db, 'k5', { ...goodSkills(), specialties: [] }));
  await assertFails(writeSkills(db, 'k5', { ...goodSkills(), languages: [] }));
  for (const years of [51, -1, 6.5, '6']) {
    await assertFails(writeSkills(db, 'k5', { ...goodSkills(), yearsExperience: years }));
  }
  await assertSucceeds(writeSkills(db, 'k5', { ...goodSkills(), yearsExperience: 0 }));
  await assertSucceeds(writeSkills(db, 'k5', { ...goodSkills(), yearsExperience: 50 }));
});

test('completeness and skills.updatedAt are server-only', async () => {
  const db = await skillsOwner('k6');
  await assertFails(writeSkills(db, 'k6', { ...goodSkills(), completeness: 99 }));
  await assertFails(writeSkills(db, 'k6', { ...goodSkills(), updatedAt: new Date() }));
  const db7 = await skillsOwner('k7', { skills: { ...goodSkills(), completeness: 40 } });
  // The app's merge write leaves the server value in place.
  await assertSucceeds(writeSkills(db7, 'k7', { ...goodSkills(), styles: ['minimal'] }));
  await assertFails(updateDoc(doc(db7, 'photographers/k7'), { 'skills.completeness': 99 }));
  const snap = await getDoc(doc(db7, 'photographers/k7'));
  assert.equal(snap.data().skills.completeness, 40);
});

test('the adapter merge save keeps server skills fields; changing or removing them fails', async () => {
  const stamp = Timestamp.fromMillis(7000);
  const db = await skillsOwner('k11', { skills: { ...goodSkills(), completeness: 55, updatedAt: stamp } });
  const ref = doc(db, 'photographers/k11');
  // Exact shape of FirestoreSkillsRepository.save: skillsToMap + top-level server time, merged.
  await assertSucceeds(setDoc(ref, {
    skills: { ...goodSkills(), styles: ['film'], yearsExperience: null },
    updatedAt: serverTimestamp(),
  }, { merge: true }));
  const snap = await getDoc(ref);
  assert.equal(snap.data().skills.completeness, 55);
  assert.equal(snap.data().skills.updatedAt.toMillis(), 7000);
  assert.deepEqual(snap.data().skills.styles, ['film']);
  await assertFails(writeSkills(db, 'k11', { ...goodSkills(), completeness: 100 }));
  await assertFails(writeSkills(db, 'k11', { ...goodSkills(), updatedAt: Timestamp.fromMillis(9000) }));
  await assertFails(writeSkills(db, 'k11', { ...goodSkills(), updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { 'skills.updatedAt': Timestamp.fromMillis(9000) }));
  await assertFails(updateDoc(ref, { 'skills.completeness': deleteField() }));
  await assertFails(updateDoc(ref, { 'skills.updatedAt': deleteField() }));
  // A full overwrite that drops the server fields is refused as well.
  await assertFails(setDoc(ref, { onboardingComplete: false, verified: false, skills: goodSkills() }));
});

test('completenessNext, completenessNextAfter and evidenceRemovedAt are server-only like completeness', async () => {
  const stamp = Timestamp.fromMillis(8000);
  const server = {
    completeness: 85, completenessNext: 'audiences', completenessNextAfter: 'styles',
    updatedAt: stamp, evidenceRemovedAt: stamp,
  };
  const db = await skillsOwner('k12', { skills: { ...goodSkills(), ...server } });
  const ref = doc(db, 'photographers/k12');
  // Exact shape of FirestoreSkillsRepository.save: the stored server fields survive the merge.
  await assertSucceeds(setDoc(ref, { skills: { ...goodSkills(), styles: ['film'] }, updatedAt: serverTimestamp() }, { merge: true }));
  const snap = await getDoc(ref);
  assert.equal(snap.data().skills.completenessNext, 'audiences');
  assert.equal(snap.data().skills.completenessNextAfter, 'styles');
  assert.equal(snap.data().skills.evidenceRemovedAt.toMillis(), 8000);
  await assertFails(writeSkills(db, 'k12', { ...goodSkills(), completenessNext: 'styles' }));
  await assertFails(writeSkills(db, 'k12', { ...goodSkills(), completenessNext: null }));
  await assertFails(writeSkills(db, 'k12', { ...goodSkills(), completenessNextAfter: 'extras' }));
  await assertFails(writeSkills(db, 'k12', { ...goodSkills(), completenessNextAfter: null }));
  await assertFails(writeSkills(db, 'k12', { ...goodSkills(), evidenceRemovedAt: serverTimestamp() }));
  await assertFails(updateDoc(ref, { 'skills.completenessNext': deleteField() }));
  await assertFails(updateDoc(ref, { 'skills.completenessNextAfter': deleteField() }));
  await assertFails(updateDoc(ref, { 'skills.evidenceRemovedAt': deleteField() }));
  // None stored yet: the client cannot add them either, not even as null.
  const fresh = await skillsOwner('k13');
  await assertFails(writeSkills(fresh, 'k13', { ...goodSkills(), completenessNext: null }));
  await assertFails(writeSkills(fresh, 'k13', { ...goodSkills(), completenessNextAfter: null }));
  await assertFails(writeSkills(fresh, 'k13', { ...goodSkills(), evidenceRemovedAt: Timestamp.fromMillis(1) }));
  await assertSucceeds(writeSkills(fresh, 'k13', goodSkills()));
});

test('expression budget: the largest valid skills save still passes with all five server fields stored', async () => {
  const ids = (p) => [`${p}1`, `${p}2`, `${p}3`];
  const largest = {
    ...goodSkills(),
    specialties: [
      genre('portrait', 3, ids('a')), genre('wedding', 3, ids('b')), genre('couple', 3, ids('c')),
      genre('family', 2, ids('d')), genre('graduation', 2, ids('e')), { ...genre('event', 1, ids('f')), years: 50 },
    ],
    styles: ['natural_light', 'film', 'minimal', 'editorial'],
    extras: ['retouch', 'posing', 'video', 'drone', 'studio', 'kids', 'pets', 'low_light'],
    languages: ['vi', 'en', 'zh', 'ko', 'ja'],
    audiences: ['couple', 'family_kids', 'business', 'foreigner'],
  };
  const stamp = Timestamp.fromMillis(9000);
  const db = await skillsOwner('k14', {
    skills: {
      ...largest, completeness: 100, completenessNext: null, completenessNextAfter: null,
      updatedAt: stamp, evidenceRemovedAt: stamp,
    },
  });
  await assertSucceeds(setDoc(doc(db, 'photographers/k14'), {
    skills: { ...largest, yearsExperience: 7 },
    updatedAt: serverTimestamp(),
  }, { merge: true }));
});

test('skills shape: known keys only, schema version 1, owner only', async () => {
  const db = await skillsOwner('k8');
  await assertFails(writeSkills(db, 'k8', { ...goodSkills(), schemaVersion: 2 }));
  const { schemaVersion, ...noVersion } = goodSkills();
  assert.equal(schemaVersion, 1);
  await assertFails(writeSkills(db, 'k8', noVersion));
  await assertFails(writeSkills(db, 'k8', { ...goodSkills(), equipment: ['A7'] }));
  await assertFails(writeSkills(db, 'k8', 'portrait'));
  await skillsOwner('k9');
  await assertFails(writeSkills(db, 'k9', goodSkills()));
});

test('unchanged legacy skills do not block other profile edits', async () => {
  const db = await skillsOwner('k10', { skills: { schemaVersion: 1, specialties: [] } });
  await assertSucceeds(updateDoc(doc(db, 'photographers/k10'), { bio: 'Chân dung' }));
  await assertFails(writeSkills(db, 'k10', { schemaVersion: 1, specialties: [], styles: ['film'] }));
});

// Budget guard: the costliest valid profile must stay accepted, as a fresh save and over stored
// values, on a document whose stored serviceArea / contactChannels are re-validated by the merge.
const fullProfileOwner = async (uid, skills) => {
  const db = await skillsOwner(uid, {
    serviceArea: { city: 'Hà Nội', radiusKm: 30, center: new GeoPoint(21.03, 105.85) },
    contactChannels: { call: true, zalo: true, whatsapp: true, acceptInquiries: true },
    ...(skills ? { skills } : {}),
  });
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), `photographers/${uid}/private/contact`),
      { phone: '+84912345678', zaloPhone: '+84912345678', whatsappPhone: '+84912345678' }));
  return db;
};
test('the largest valid skills profile stays within the rules evaluation budget', async () => {
  const largest = () => ({
    schemaVersion: 1,
    specialties: ['portrait', 'wedding', 'couple', 'family', 'graduation', 'event'].map((id, i) => ({
      id, level: i < 3 ? 3 : 2, years: 50,
      evidencePostIds: [`a${i}`.padEnd(64, 'x'), `b${i}`.padEnd(64, 'x'), `c${i}`.padEnd(64, 'x')],
    })),
    styles: ['natural_light', 'film', 'minimal', 'editorial'],
    extras: ['retouch', 'posing', 'video', 'drone', 'studio', 'kids', 'pets', 'low_light'],
    languages: ['vi', 'en', 'zh', 'ko', 'ja'],
    audiences: ['couple', 'family_kids', 'business', 'foreigner'],
    yearsExperience: 50,
  });
  const db = await fullProfileOwner('k12');
  await assertSucceeds(setDoc(doc(db, 'photographers/k12'), { skills: largest(), updatedAt: serverTimestamp() }, { merge: true }));
  const db13 = await fullProfileOwner('k13', { ...goodSkills(), completeness: 70, updatedAt: Timestamp.fromMillis(3) });
  await assertSucceeds(setDoc(doc(db13, 'photographers/k13'), { skills: largest(), updatedAt: serverTimestamp() }, { merge: true }));
});

test('evidence ids holding separators cannot fake count, uniqueness or pattern', async () => {
  const db = await skillsOwner('k14');
  const one = (level, ev) => ({ ...goodSkills(), specialties: [genre('portrait', level, ev)] });
  await assertFails(writeSkills(db, 'k14', one(2, ['a,b'])));
  await assertFails(writeSkills(db, 'k14', one(3, ['a,a'])));
  await assertFails(writeSkills(db, 'k14', one(2, ['a', 'b', 'c|1:n:d', 'e', 'f'])));
  await assertFails(writeSkills(db, 'k14', one(2, Array.from({ length: 200 }, (_, i) => `x${i}|1:n:y${i}`))));
  await assertFails(writeSkills(db, 'k14', one(2, ['a:b'])));
  await assertFails(writeSkills(db, 'k14', one(2, [''])));
  await assertFails(writeSkills(db, 'k14', one(3, [''])));
  await assertFails(writeSkills(db, 'k14', one(2, ['x'.repeat(65)])));
  await assertSucceeds(writeSkills(db, 'k14', one(2, ['x'.repeat(64)])));
  await assertFails(writeSkills(db, 'k14', one(2, 'post1')));
  await assertFails(writeSkills(db, 'k14', one(2, { a: 'post1' })));
  await assertFails(writeSkills(db, 'k14', one(2, [1, 2])));
  await assertFails(writeSkills(db, 'k14', one(3, [true])));
  await assertFails(writeSkills(db, 'k14', one(2, [null])));
  await assertFails(writeSkills(db, 'k14', one(2, ['a', 7])));
});

test('server skills fields stay absent when none is stored; skills cannot be deleted', async () => {
  const db = await skillsOwner('k15');
  await assertFails(writeSkills(db, 'k15', { ...goodSkills(), completeness: null }));
  await assertFails(writeSkills(db, 'k15', { ...goodSkills(), updatedAt: null }));
  await assertSucceeds(writeSkills(db, 'k15', goodSkills()));
  await assertFails(updateDoc(doc(db, 'photographers/k15'), { skills: deleteField() }));
  await assertFails(updateDoc(doc(db, 'photographers/k15'), { 'skills.completeness': null }));
});

test('contact access log is server-only: no client reads or writes, not even the requester', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'contact_access_log/l1'), {
    requesterId: 'u1', subjectType: 'booking', subjectId: 'b1', channel: 'call', granted: true,
  }));
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(getDoc(doc(db, 'contact_access_log/l1')));
  await assertFails(setDoc(doc(db, 'contact_access_log/l2'), { requesterId: 'u1' }));
});

// ---- Plan 2d1: days off, intro, packages ----
const dayPath = (uid, day) => `availability/${uid}/days/${day}`;
const asCustomer = (uid) => env.withSecurityRulesDisabled(async (c) =>
  setDoc(doc(c.firestore(), `users/${uid}`), { displayName: uid, role: 'customer' }));

test('a photographer marks a free day off and frees it again', async () => {
  await asPhotographer('cal1');
  const db = env.authenticatedContext('cal1').firestore();
  const r = doc(db, dayPath('cal1', '2026-10-12'));
  await assertSucceeds(setDoc(r, { state: 'off', updatedAt: serverTimestamp() }));
  await assertSucceeds(getDoc(r));
  await assertSucceeds(deleteDoc(r));
});

test('booked and pending days belong to the server', async () => {
  await asPhotographer('cal2');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), dayPath('cal2', '2026-10-13')), { state: 'booked', bookingId: 'b1' }));
  const db = env.authenticatedContext('cal2').firestore();
  await assertFails(setDoc(doc(db, dayPath('cal2', '2026-10-14')), { state: 'booked' }));
  await assertFails(setDoc(doc(db, dayPath('cal2', '2026-10-14')), { state: 'pending' }));
  await assertFails(deleteDoc(doc(db, dayPath('cal2', '2026-10-13'))));
  await assertFails(setDoc(doc(db, dayPath('cal2', '2026-10-13')), { state: 'off' }), 'an overwrite is an update');
  await assertFails(setDoc(doc(db, dayPath('cal2', '2026-10-15')), { state: 'off', bookingId: 'x' }));
  await assertFails(setDoc(doc(db, dayPath('cal2', '12-10-2026')), { state: 'off' }));
});

test('only the photographer edits their calendar; every signed-in user reads it', async () => {
  await asPhotographer('cal3');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), dayPath('cal3', '2026-10-16')), { state: 'off' }));
  const other = env.authenticatedContext('cal4').firestore();
  await assertSucceeds(getDoc(doc(other, dayPath('cal3', '2026-10-16'))));
  await assertFails(setDoc(doc(other, dayPath('cal3', '2026-10-17')), { state: 'off' }));
  await assertFails(deleteDoc(doc(other, dayPath('cal3', '2026-10-16'))));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), dayPath('cal3', '2026-10-16'))));
  await asCustomer('cal5');
  await assertFails(setDoc(doc(env.authenticatedContext('cal5').firestore(), dayPath('cal5', '2026-10-18')), { state: 'off' }));
});

test('a signed-in user can read a day nobody has written (a free day)', async () => {
  const db = env.authenticatedContext('viewer').firestore();
  await assertSucceeds(getDoc(doc(db, dayPath('cal6', '2026-10-13'))));
});

const svcPath = (uid, id) => `photographers/${uid}/services/${id}`;
const svc = (o = {}) => ({
  name: 'Chân dung 2 giờ', price: 1500000, durationMinutes: 120,
  deliverables: { editedCount: 40, deliveryDays: 3 }, active: true, ...o,
});

test('a photographer adds, edits and hides own packages, and never deletes them', async () => {
  await asPhotographer('sv1');
  const db = env.authenticatedContext('sv1').firestore();
  const r = doc(db, svcPath('sv1', '01JB0Z8K3V5N6Q7R8S9T0V1W2X'));
  await assertSucceeds(setDoc(r, { ...svc(), createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(r, { price: 1800000, updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(r, { active: false }));
  await assertFails(deleteDoc(r));
});

test('package values are checked', async () => {
  await asPhotographer('sv2');
  const r = doc(env.authenticatedContext('sv2').firestore(), svcPath('sv2', 's1'));
  for (const bad of [
    svc({ price: 0 }), svc({ price: 1500.5 }), svc({ price: '1500000' }), svc({ price: 1000000001 }),
    svc({ durationMinutes: 90 }), svc({ name: 'A' }), svc({ name: 'x'.repeat(61) }),
    svc({ deliverables: { editedCount: -1 } }), svc({ deliverables: { deliveryDays: 91 } }),
    svc({ deliverables: { extra: 1 } }), svc({ active: 'yes' }), svc({ note: 'x' }), svc({ startingPrice: 1 }),
  ]) {
    await assertFails(setDoc(r, bad));
  }
  await assertSucceeds(setDoc(r, svc({ deliverables: {} })));
});

test('nobody else, and no customer, writes packages; everyone signed in reads them', async () => {
  await asPhotographer('sv3');
  await assertFails(setDoc(doc(env.authenticatedContext('sv4').firestore(), svcPath('sv3', 's1')), svc()));
  await asCustomer('sv5');
  await assertFails(setDoc(doc(env.authenticatedContext('sv5').firestore(), svcPath('sv5', 's1')), svc()));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('sv4').firestore(), svcPath('sv3', 's1'))));
});

test('the step 1 intro is length-checked', async () => {
  await asPhotographer('in1');
  const db = env.authenticatedContext('in1').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/in1'), { onboardingComplete: false, verified: false, specialties: [] }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/in1'), {
    bio: 'Ánh sáng tự nhiên.', equipment: ['Sony A7 IV'], updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'photographers/in1'), { bio: 'x'.repeat(301) }));
  await assertFails(updateDoc(doc(db, 'photographers/in1'), { bio: 42 }));
  await assertFails(updateDoc(doc(db, 'photographers/in1'), { equipment: Array.from({ length: 9 }, (_, i) => `M${i}`) }));
  await assertFails(updateDoc(doc(db, 'photographers/in1'), { equipment: 'Sony' }));
});

// ---- Storage: post photos ----
const photo = (n = 4) => new Uint8Array(n);
const jpeg = { contentType: 'image/jpeg' };

test('a user uploads, reads and deletes photos under their own post path', async () => {
  const st = env.authenticatedContext('ph1').storage();
  const r = ref(st, 'posts/ph1/post1/a.jpg');
  await assertSucceeds(uploadBytes(r, photo(), jpeg));
  await assertSucceeds(getBytes(r));
  await assertSucceeds(deleteObject(r));
});

test('nobody uploads into or deletes from someone else\'s post path', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    uploadBytes(ref(c.storage(), 'posts/ph1/post1/b.jpg'), photo(), jpeg));
  const other = env.authenticatedContext('ph2').storage();
  await assertFails(uploadBytes(ref(other, 'posts/ph1/post1/c.jpg'), photo(), jpeg));
  await assertFails(deleteObject(ref(other, 'posts/ph1/post1/b.jpg')));
  await assertSucceeds(getBytes(ref(other, 'posts/ph1/post1/b.jpg'))); // reading is for every signed-in user
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), 'posts/ph1/post1/b.jpg')));
  await assertFails(uploadBytes(ref(env.unauthenticatedContext().storage(), 'posts/ph1/post1/d.jpg'), photo(), jpeg));
});

test('posts: only JPEG up to 3 MiB is accepted (portfolio 2048 px, share 1600 px)', async () => {
  const st = env.authenticatedContext('ph1').storage();
  await assertFails(uploadBytes(ref(st, 'posts/ph1/post1/e.pdf'), photo(), { contentType: 'application/pdf' }));
  await assertSucceeds(uploadBytes(ref(st, 'posts/ph1/post1/ok.jpg'), photo(3 * 1024 * 1024), jpeg));
  await assertFails(uploadBytes(ref(st, 'posts/ph1/post1/f.jpg'), photo(3 * 1024 * 1024 + 1), jpeg));
  await assertFails(uploadBytes(ref(st, 'posts/ph1/post1/f8.jpg'), photo(8 * 1024 * 1024 + 1), jpeg));
  await assertFails(uploadBytes(ref(st, 'posts/ph1/post1/h.webp'), photo(), { contentType: 'image/webp' }));
  await assertFails(uploadBytes(ref(st, 'posts/ph1/post1/h.png'), photo(), { contentType: 'image/png' }));
  await assertSucceeds(uploadBytes(ref(st, 'posts/ph1/post1/g.jpg'), photo(1024 * 1024), jpeg));
});

test('every other Storage path is closed, users/{uid}/** included', async () => {
  const st = env.authenticatedContext('ph1').storage();
  await assertFails(uploadBytes(ref(st, 'misc/ph1/a.jpg'), photo(), jpeg));
  await assertFails(uploadBytes(ref(st, 'posts/ph1/a.jpg'), photo(), jpeg)); // missing the post folder
  await assertFails(getBytes(ref(st, 'misc/x.jpg')));
  await assertFails(uploadBytes(ref(st, 'users/ph1/x.jpg'), photo(), jpeg)); // path closed (no writer)
  await env.withSecurityRulesDisabled(async (c) =>
    uploadBytes(ref(c.storage(), 'users/ph1/old.jpg'), photo(), jpeg));
  await assertFails(getBytes(ref(st, 'users/ph1/old.jpg')));
  await assertFails(deleteObject(ref(st, 'users/ph1/old.jpg')));
});

// ---- creating posts ----
const validPost = (uid, extra = {}) => ({
  kind: 'work', authorId: uid, photographerId: uid, serviceId: 's1', specialty: 'portrait',
  imageUrls: ['https://x/1.jpg'], imageMeta: [{ blurHash: null, w: null, h: null }],
  caption: 'Chiều muộn #chandung', hashtags: ['chandung'], location: { name: 'Bến Bạch Đằng' },
  style: 'film', inPortfolio: true, likeCount: 0, saveCount: 0, createdAt: serverTimestamp(), ...extra,
});

async function seedShooter(uid, { role = 'photographer', service = true, active = true } = {}) {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, `users/${uid}`), { displayName: uid, role });
    if (service) {
      await setDoc(doc(db, `photographers/${uid}/services/s1`), { name: 'Gói', price: 1500000, active });
    }
  });
}

test('a photographer creates a post for themself with their own package', async () => {
  await seedShooter('c1');
  const db = env.authenticatedContext('c1').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/post-ok'), validPost('c1')));
});

test('the post and its portfolio entry can be written in one batch', async () => {
  await seedShooter('c2');
  const db = env.authenticatedContext('c2').firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, 'posts/post-batch'), validPost('c2'));
  batch.set(doc(db, 'photographers/c2'), { portfolio: arrayUnion('post-batch'), updatedAt: serverTimestamp() }, { merge: true });
  await assertSucceeds(batch.commit());
});

test('optional fields may be left out', async () => {
  await seedShooter('c3');
  const db = env.authenticatedContext('c3').firestore();
  const bare = validPost('c3');
  for (const k of ['specialty', 'imageMeta', 'location', 'style', 'hashtags', 'inPortfolio']) delete bare[k];
  await assertSucceeds(setDoc(doc(db, 'posts/post-bare'), bare));
});

test('nobody posts as someone else, and customers cannot post', async () => {
  await seedShooter('c4');
  await seedShooter('cust', { role: 'customer' });
  const db = env.authenticatedContext('c4').firestore();
  await assertFails(setDoc(doc(db, 'posts/x1'), validPost('c5')));
  await assertFails(setDoc(doc(db, 'posts/x2'), validPost('c4', { authorId: 'c5' })));
  const customer = env.authenticatedContext('cust').firestore();
  await assertFails(setDoc(doc(customer, 'posts/x3'), validPost('cust')));
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'posts/x4'), validPost('c4')));
});

test('the package must exist, be yours and be active', async () => {
  await seedShooter('c6', { service: false });
  await seedShooter('c7', { active: false });
  await seedShooter('c8');
  await assertFails(setDoc(doc(env.authenticatedContext('c6').firestore(), 'posts/y1'), validPost('c6')));
  await assertFails(setDoc(doc(env.authenticatedContext('c7').firestore(), 'posts/y2'), validPost('c7')));
  // A package id is looked up under the poster's own packages only.
  await assertFails(setDoc(doc(env.authenticatedContext('c8').firestore(), 'posts/y3'), validPost('c8', { serviceId: 'other' })));
});

test('one to ten photos', async () => {
  await seedShooter('c9');
  const db = env.authenticatedContext('c9').firestore();
  await assertFails(setDoc(doc(db, 'posts/z1'), validPost('c9', { imageUrls: [], imageMeta: [] })));
  const eleven = Array.from({ length: 11 }, (_, i) => `https://x/${i}.jpg`);
  const tooMany = validPost('c9', { imageUrls: eleven });
  delete tooMany.imageMeta;
  await assertFails(setDoc(doc(db, 'posts/z2'), tooMany));
  const ten = eleven.slice(0, 10);
  await assertSucceeds(setDoc(doc(db, 'posts/z3'), validPost('c9', { imageUrls: ten, imageMeta: ten.map(() => ({ blurHash: null, w: null, h: null })) })));
  await assertFails(setDoc(doc(db, 'posts/z4'), validPost('c9', { imageMeta: [] }))); // meta must match the photo count
});

test('counters, kind, time and extra fields cannot be forged', async () => {
  await seedShooter('d1');
  const db = env.authenticatedContext('d1').firestore();
  await assertFails(setDoc(doc(db, 'posts/f1'), validPost('d1', { likeCount: 500 })));
  await assertFails(setDoc(doc(db, 'posts/f2'), validPost('d1', { saveCount: 1 })));
  await assertFails(setDoc(doc(db, 'posts/f3'), validPost('d1', { kind: 'real_shoot' })));
  await assertFails(setDoc(doc(db, 'posts/f4'), validPost('d1', { createdAt: new Date('2020-01-01') })));
  await assertFails(setDoc(doc(db, 'posts/f5'), validPost('d1', { bookingId: 'b1' })));
  await assertFails(setDoc(doc(db, 'posts/f6'), validPost('d1', { caption: 'x'.repeat(2001) })));
  await assertFails(setDoc(doc(db, 'posts/f7'), validPost('d1', { hashtags: Array.from({ length: 31 }, (_, i) => `t${i}`) })));
  await assertSucceeds(setDoc(doc(db, 'posts/f8'), validPost('d1', { caption: 'x'.repeat(2000) })));
});

test('posts cannot be edited or deleted from the client yet', async () => {
  await seedShooter('d2');
  const db = env.authenticatedContext('d2').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/own'), validPost('d2')));
  await assertFails(updateDoc(doc(db, 'posts/own'), { caption: 'đổi' }));
  await assertFails(updateDoc(doc(db, 'posts/own'), { likeCount: 10 }));
  await assertFails(deleteDoc(doc(db, 'posts/own')));
});

// ---- portfolio albums (plan C) ----
async function seedAlbum(id, photographerId) {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), `albums/${id}`), { photographerId, title: 'A', position: 1, postCount: 0, mediaCount: 0, visible: false }));
}

test('albums are readable by signed-in users', async () => {
  await seedAlbum('alb-read', 'e1');
  await assertSucceeds(getDoc(doc(env.authenticatedContext('anyone').firestore(), 'albums/alb-read')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'albums/alb-read')));
});

test('nobody writes albums', async () => {
  await seedAlbum('alb-w', 'e1');
  const db = env.authenticatedContext('e1').firestore();
  await assertFails(setDoc(doc(db, 'albums/alb-new'), { photographerId: 'e1', title: 'B' }));
  await assertFails(updateDoc(doc(db, 'albums/alb-w'), { title: 'C' }));
  await assertFails(deleteDoc(doc(db, 'albums/alb-w')));
});

test('a post may name the author\'s own album', async () => {
  await seedShooter('e1');
  await seedAlbum('alb-own', 'e1');
  const db = env.authenticatedContext('e1').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/post-alb'), validPost('e1', { albumId: 'alb-own' })));
});

test('a post may not name another photographer\'s existing album', async () => {
  await seedShooter('e2');
  await seedAlbum('alb-other', 'e9');
  const db = env.authenticatedContext('e2').firestore();
  await assertFails(setDoc(doc(db, 'posts/post-alb2'), validPost('e2', { albumId: 'alb-other' })));
});

test('a post may name a deleted (missing) album and lands unsorted later', async () => {
  await seedShooter('e5');
  const db = env.authenticatedContext('e5').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/post-alb3'), validPost('e5', { albumId: 'alb-missing' })));
});

test('a post may not name an album id with a slash', async () => {
  await seedShooter('e6');
  const db = env.authenticatedContext('e6').firestore();
  await assertFails(setDoc(doc(db, 'posts/post-alb7'), validPost('e6', { albumId: 'a/b/c' })));
});

test('a post may not name an over-long album id', async () => {
  await seedShooter('e7');
  const db = env.authenticatedContext('e7').firestore();
  await assertFails(setDoc(doc(db, 'posts/post-alb8'), validPost('e7', { albumId: 'a'.repeat(65) })));
});

test('a post may not set albumPosition', async () => {
  await seedShooter('e3');
  await seedAlbum('alb-e3', 'e3');
  const db = env.authenticatedContext('e3').firestore();
  await assertFails(setDoc(doc(db, 'posts/post-alb4'), validPost('e3', { albumId: 'alb-e3', albumPosition: 1 })));
  await assertFails(setDoc(doc(db, 'posts/post-alb5'), validPost('e3', { albumPosition: 1 })));
});

test('posts still cannot be updated', async () => {
  await seedShooter('e4');
  await seedAlbum('alb-e4', 'e4');
  const db = env.authenticatedContext('e4').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/post-alb6'), validPost('e4', { albumId: 'alb-e4' })));
  await assertFails(updateDoc(doc(db, 'posts/post-alb6'), { albumId: deleteField() }));
  await assertFails(updateDoc(doc(db, 'posts/post-alb6'), { albumPosition: 1 }));
});

async function seedSpot(id, status) {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), `spots/${id}`), { name: 'Hồ Tây', status }));
}

test('a photographer creates a post with spotId of an active spot', async () => {
  await seedShooter('sp1');
  await seedSpot('spot-active', 'active');
  const db = env.authenticatedContext('sp1').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/post-spot1'), validPost('sp1', { spotId: 'spot-active' })));
});

test('spotId of an archived or missing spot is refused', async () => {
  await seedShooter('sp2');
  await seedSpot('spot-old', 'archived');
  const db = env.authenticatedContext('sp2').firestore();
  await assertFails(setDoc(doc(db, 'posts/post-spot2'), validPost('sp2', { spotId: 'spot-old' })));
  await assertFails(setDoc(doc(db, 'posts/post-spot3'), validPost('sp2', { spotId: 'spot-missing' })));
  await assertFails(setDoc(doc(db, 'posts/post-spot4'), validPost('sp2', { spotId: 'a/b' })));
  await assertFails(setDoc(doc(db, 'posts/post-spot5'), validPost('sp2', { spotId: 5 })));
});

test('a post without spotId still passes', async () => {
  await seedShooter('sp3');
  const db = env.authenticatedContext('sp3').firestore();
  await assertSucceeds(setDoc(doc(db, 'posts/post-spot6'), validPost('sp3', {})));
});

// ---- Plan 2d2: avatars ----
const ulidJpg = '01JB0Z8K3V5N6Q7R8S9T0V1W2X.jpg';

test('users keep the storage key of their own avatar only', async () => {
  const db = env.authenticatedContext('av1').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/av1'), { displayName: 'A' }));
  await assertSucceeds(updateDoc(doc(db, 'users/av1'), {
    avatarUrl: 'https://storage.test/a.jpg', avatarPath: `avatars/av1/${ulidJpg}`,
  }));
  await assertFails(updateDoc(doc(db, 'users/av1'), { avatarPath: `avatars/av2/${ulidJpg}` }));
  await assertFails(updateDoc(doc(db, 'users/av1'), { avatarPath: 'posts/av1/p/a.jpg' }));
  await assertFails(updateDoc(doc(db, 'users/av1'), { avatarPath: 'avatars/av1/a.jpg' }));
  await assertFails(updateDoc(doc(db, 'users/av1'), { avatarPath: 42 }));
});

test('a user uploads, replaces and deletes only their own avatar, JPEG up to 512 KiB', async () => {
  const st = env.authenticatedContext('av1').storage();
  const own = ref(st, `avatars/av1/${ulidJpg}`);
  await assertSucceeds(uploadBytes(own, photo(), jpeg));
  await assertSucceeds(uploadBytes(own, photo(8), jpeg));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('av2').storage(), `avatars/av1/${ulidJpg}`)));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), `avatars/av1/${ulidJpg}`)));
  await assertFails(uploadBytes(ref(env.authenticatedContext('av2').storage(), 'avatars/av1/b.jpg'), photo(), jpeg));
  await assertFails(deleteObject(ref(env.authenticatedContext('av2').storage(), `avatars/av1/${ulidJpg}`)));
  await assertFails(uploadBytes(ref(st, 'avatars/av1/c.pdf'), photo(), { contentType: 'application/pdf' }));
  await assertSucceeds(uploadBytes(ref(st, 'avatars/av1/e.jpg'), photo(512 * 1024), jpeg));
  await assertFails(uploadBytes(ref(st, 'avatars/av1/d.jpg'), photo(512 * 1024 + 1), jpeg));
  await assertFails(uploadBytes(ref(st, 'avatars/av1/f.png'), photo(), { contentType: 'image/png' }));
  await assertSucceeds(deleteObject(own));
});

// ---- Plan 4a: bookings, contact copy and escrow rules ----
test('bookings/private/contact is readable by customer always, photographer only when unlocked', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'bookings/b_req'), { customerId: 'c1', photographerId: 'p1', status: 'requested' });
    await setDoc(doc(f, 'bookings/b_req/private/contact'), { name: 'Customer C1', phone: '+84903123456' });

    await setDoc(doc(f, 'bookings/b_draft'), { customerId: 'c1', photographerId: 'p1', status: 'draft' });
    await setDoc(doc(f, 'bookings/b_draft/private/contact'), { name: 'Customer C1', phone: '+84903123456' });

    await setDoc(doc(f, 'bookings/b_canc'), { customerId: 'c1', photographerId: 'p1', status: 'cancelled' });
    await setDoc(doc(f, 'bookings/b_canc/private/contact'), { name: 'Customer C1', phone: '+84903123456' });
  });

  const cDb = env.authenticatedContext('c1').firestore();
  const pDb = env.authenticatedContext('p1').firestore();
  const strangerDb = env.authenticatedContext('stranger').firestore();

  // Customer reads all their booking contacts
  await assertSucceeds(getDoc(doc(cDb, 'bookings/b_req/private/contact')));
  await assertSucceeds(getDoc(doc(cDb, 'bookings/b_draft/private/contact')));
  await assertSucceeds(getDoc(doc(cDb, 'bookings/b_canc/private/contact')));

  // Photographer reads unlocked contact, but not locked/draft/cancelled
  await assertSucceeds(getDoc(doc(pDb, 'bookings/b_req/private/contact')));
  await assertFails(getDoc(doc(pDb, 'bookings/b_draft/private/contact')));
  await assertFails(getDoc(doc(pDb, 'bookings/b_canc/private/contact')));

  // Stranger cannot read
  await assertFails(getDoc(doc(strangerDb, 'bookings/b_req/private/contact')));

  // Writes denied to all clients
  await assertFails(setDoc(doc(cDb, 'bookings/b_req/private/contact'), { name: 'Hacked' }));
  await assertFails(setDoc(doc(pDb, 'bookings/b_req/private/contact'), { name: 'Hacked' }));
});

test('payments, refunds, and ledger_entries are denied to clients', async () => {
  const db = env.authenticatedContext('c1').firestore();
  await assertFails(getDoc(doc(db, 'payments/pay1')));
  await assertFails(setDoc(doc(db, 'payments/pay1'), { amount: 100 }));
  await assertFails(getDoc(doc(db, 'refunds/ref1')));
  await assertFails(setDoc(doc(db, 'refunds/ref1'), { amount: 100 }));
  await assertFails(getDoc(doc(db, 'ledger_entries/le1')));
  await assertFails(setDoc(doc(db, 'ledger_entries/le1'), { amount: 100 }));
});

test('payment_notifications is denied to clients', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'payment_notifications/fake_txn1'), {
      provider: 'fake', txnId: 'txn1', raw: '{"payer":{"name":"NGUYEN VAN A"}}', outcome: 'paid', paymentId: 'pay1',
    });
  });
  for (const db of [env.authenticatedContext('c1').firestore(), env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(db, 'payment_notifications/fake_txn1')));
    await assertFails(getDocs(collection(db, 'payment_notifications')));
    await assertFails(setDoc(doc(db, 'payment_notifications/fake_txn2'), { provider: 'fake', txnId: 'txn2', outcome: 'paid' }));
    await assertFails(deleteDoc(doc(db, 'payment_notifications/fake_txn1')));
  }
});

test('clients can never write the checkout mirror or payableUntil of a booking', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'bookings/b_co1'), { customerId: 'c1', photographerId: 'p1', status: 'draft' });
  });
  const cDb = env.authenticatedContext('c1').firestore();
  await assertSucceeds(getDoc(doc(cDb, 'bookings/b_co1')));
  await assertFails(updateDoc(doc(cDb, 'bookings/b_co1'), { checkout: { paymentId: 'pay1', amount: 1 } }));
  await assertFails(updateDoc(doc(cDb, 'bookings/b_co1'), { payableUntil: new Date('2030-01-01T00:00:00Z') }));
});

test('booking events are readable by both parties and nobody else', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'bookings/b_ev1'), { customerId: 'c1', photographerId: 'p1', status: 'requested' });
    await setDoc(doc(f, 'bookings/b_ev1/events/ev1'), { status: 'requested', actorId: 'c1' });
  });

  const cDb = env.authenticatedContext('c1').firestore();
  const pDb = env.authenticatedContext('p1').firestore();
  const otherDb = env.authenticatedContext('other').firestore();
  const unauthDb = env.unauthenticatedContext().firestore();

  // Both parties can read
  await assertSucceeds(getDoc(doc(cDb, 'bookings/b_ev1/events/ev1')));
  await assertSucceeds(getDoc(doc(pDb, 'bookings/b_ev1/events/ev1')));

  // Strangers and unauthenticated cannot read
  await assertFails(getDoc(doc(otherDb, 'bookings/b_ev1/events/ev1')));
  await assertFails(getDoc(doc(unauthDb, 'bookings/b_ev1/events/ev1')));
});

test('clients cannot write booking events', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'bookings/b_ev2'), { customerId: 'c1', photographerId: 'p1', status: 'requested' });
    await setDoc(doc(f, 'bookings/b_ev2/events/ev1'), { status: 'requested', actorId: 'c1' });
  });

  const cDb = env.authenticatedContext('c1').firestore();
  const pDb = env.authenticatedContext('p1').firestore();
  const otherDb = env.authenticatedContext('other').firestore();

  // Customer cannot create, update, or delete events
  await assertFails(setDoc(doc(cDb, 'bookings/b_ev2/events/ev2'), { status: 'accepted', actorId: 'c1' }));
  await assertFails(updateDoc(doc(cDb, 'bookings/b_ev2/events/ev1'), { status: 'cancelled' }));
  await assertFails(deleteDoc(doc(cDb, 'bookings/b_ev2/events/ev1')));

  // Photographer cannot create, update, or delete events
  await assertFails(setDoc(doc(pDb, 'bookings/b_ev2/events/ev2'), { status: 'accepted', actorId: 'p1' }));
  await assertFails(updateDoc(doc(pDb, 'bookings/b_ev2/events/ev1'), { status: 'cancelled' }));
  await assertFails(deleteDoc(doc(pDb, 'bookings/b_ev2/events/ev1')));

  // Strangers cannot create, update, or delete events
  await assertFails(setDoc(doc(otherDb, 'bookings/b_ev2/events/ev2'), { status: 'accepted', actorId: 'other' }));
  await assertFails(updateDoc(doc(otherDb, 'bookings/b_ev2/events/ev1'), { status: 'cancelled' }));
  await assertFails(deleteDoc(doc(otherDb, 'bookings/b_ev2/events/ev1')));
});

// ---- Plan 4d: chat and messaging rules ----
test('members read the chat and its messages, others cannot', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'chats/chat1'), {
      members: ['userA', 'userB'],
      bookingId: 'b1',
      lastMessageText: 'Hello',
    });
    await setDoc(doc(f, 'chats/chat1/messages/msg1'), {
      senderId: 'userA',
      text: 'Hello from A',
    });
  });

  const dbA = env.authenticatedContext('userA').firestore();
  const dbB = env.authenticatedContext('userB').firestore();
  const dbC = env.authenticatedContext('userC').firestore();
  const dbAnon = env.unauthenticatedContext().firestore();

  // Chat document read: members succeed, non-member and unauth fail
  await assertSucceeds(getDoc(doc(dbA, 'chats/chat1')));
  await assertSucceeds(getDoc(doc(dbB, 'chats/chat1')));
  await assertFails(getDoc(doc(dbC, 'chats/chat1')));
  await assertFails(getDoc(doc(dbAnon, 'chats/chat1')));

  // Messages subcollection read: members succeed, non-member and unauth fail
  await assertSucceeds(getDoc(doc(dbA, 'chats/chat1/messages/msg1')));
  await assertSucceeds(getDoc(doc(dbB, 'chats/chat1/messages/msg1')));
  await assertFails(getDoc(doc(dbC, 'chats/chat1/messages/msg1')));
  await assertFails(getDoc(doc(dbAnon, 'chats/chat1/messages/msg1')));
});

test('nobody writes chats or messages from the client', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'chats/chat2'), {
      members: ['userA', 'userB'],
      bookingId: 'b2',
    });
    await setDoc(doc(f, 'chats/chat2/messages/msg1'), {
      senderId: 'userA',
      text: 'Initial message',
    });
  });

  const dbA = env.authenticatedContext('userA').firestore();
  const dbC = env.authenticatedContext('userC').firestore();

  // Create/update/delete chats doc is forbidden to all clients
  await assertFails(setDoc(doc(dbA, 'chats/newChat'), { members: ['userA', 'userB'] }));
  await assertFails(updateDoc(doc(dbA, 'chats/chat2'), { lastMessageText: 'Updated' }));
  await assertFails(deleteDoc(doc(dbA, 'chats/chat2')));
  await assertFails(setDoc(doc(dbC, 'chats/newChat2'), { members: ['userC'] }));

  // Create/update/delete messages doc is forbidden to all clients
  await assertFails(setDoc(doc(dbA, 'chats/chat2/messages/msg2'), { senderId: 'userA', text: 'Spam' }));
  await assertFails(updateDoc(doc(dbA, 'chats/chat2/messages/msg1'), { text: 'Edited' }));
  await assertFails(deleteDoc(doc(dbA, 'chats/chat2/messages/msg1')));
  await assertFails(setDoc(doc(dbC, 'chats/chat2/messages/msg3'), { senderId: 'userC', text: 'Intruder' }));
});

test('a member may only zero its own unread counter with lastReadAt = request.time', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'chats/chat3'), { members: ['userA', 'userB'] });
    await setDoc(doc(f, 'chats/chat3/members/userA'), {
      unreadCount: 5,
      lastReadAt: Timestamp.fromDate(new Date('2026-01-01')),
    });
    await setDoc(doc(f, 'chats/chat3/members/userB'), {
      unreadCount: 2,
      lastReadAt: Timestamp.fromDate(new Date('2026-01-01')),
    });
  });

  const dbA = env.authenticatedContext('userA').firestore();
  const dbB = env.authenticatedContext('userB').firestore();
  const dbC = env.authenticatedContext('userC').firestore();

  // Member can read own member doc, but not other's
  await assertSucceeds(getDoc(doc(dbA, 'chats/chat3/members/userA')));
  await assertFails(getDoc(doc(dbB, 'chats/chat3/members/userA')));
  await assertFails(getDoc(doc(dbC, 'chats/chat3/members/userA')));

  // Create / delete is denied
  await assertFails(setDoc(doc(dbA, 'chats/chat3/members/userNew'), { unreadCount: 0 }));
  await assertFails(deleteDoc(doc(dbA, 'chats/chat3/members/userA')));

  // Cannot update someone else's member doc
  await assertFails(updateDoc(doc(dbA, 'chats/chat3/members/userB'), {
    unreadCount: 0,
    lastReadAt: serverTimestamp(),
  }));

  // Cannot set unreadCount to non-zero
  await assertFails(updateDoc(doc(dbA, 'chats/chat3/members/userA'), {
    unreadCount: 1,
    lastReadAt: serverTimestamp(),
  }));

  // Cannot set lastReadAt to non-server timestamp
  await assertFails(updateDoc(doc(dbA, 'chats/chat3/members/userA'), {
    unreadCount: 0,
    lastReadAt: Timestamp.fromDate(new Date('2026-02-01')),
  }));

  // Cannot add extra keys
  await assertFails(updateDoc(doc(dbA, 'chats/chat3/members/userA'), {
    unreadCount: 0,
    lastReadAt: serverTimestamp(),
    extraKey: 'forbidden',
  }));

  // Valid update succeeds
  await assertSucceeds(updateDoc(doc(dbA, 'chats/chat3/members/userA'), {
    unreadCount: 0,
    lastReadAt: serverTimestamp(),
  }));
});

test('reviews are readable by any signed-in user and writable by no client', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'reviews/rev_b1'), {
      bookingId: 'rev_b1',
      subjectType: 'photographer',
      subjectId: 'p1',
      customerId: 'cust1',
      photographerId: 'p1',
      verdict: 'tomato',
      hits: 5,
      intensity: 0.82,
      reasons: [],
      text: 'Chụp rất đẹp',
    });
  });

  const authDb = env.authenticatedContext('u_any').firestore();
  const unauthDb = env.unauthenticatedContext().firestore();

  // Any signed-in user can read reviews
  await assertSucceeds(getDoc(doc(authDb, 'reviews/rev_b1')));

  // Unauthenticated users cannot read
  await assertFails(getDoc(doc(unauthDb, 'reviews/rev_b1')));

  // No client can create, update, or delete reviews
  await assertFails(updateDoc(doc(authDb, 'reviews/rev_b1'), { text: 'Modified review' }));
  await assertFails(updateDoc(doc(authDb, 'reviews/rev_b1'), { hits: 10, intensity: 1 }));
  await assertFails(deleteDoc(doc(authDb, 'reviews/rev_b1')));
  await assertFails(setDoc(doc(unauthDb, 'reviews/rev_b3'), { verdict: 'tomato', hits: 1 }));
});

test('a customer cannot create reviews/{bookingId} with a verdict', async () => {
  await asCustomer('cust_rv');
  const db = env.authenticatedContext('cust_rv').firestore();
  const review = {
    bookingId: 'rev_c1',
    subjectType: 'photographer',
    subjectId: 'p1',
    customerId: 'cust_rv',
    photographerId: 'p1',
    verdict: 'brick',
    hits: 3,
    intensity: 0.69,
    reasons: ['late'],
    text: 'Đến trễ 30 phút, ảnh giao chậm.',
    photoPostId: null,
    countedAt: null,
  };
  await assertFails(setDoc(doc(db, 'reviews/rev_c1'), review));
  await assertFails(setDoc(doc(db, 'reviews/rev_c1_studio'), { ...review, subjectType: 'studio' }));
});

test('a customer cannot write photographers/{uid}.stats.tomatoPct', async () => {
  await asPhotographer('p_tp');
  await asCustomer('cust_tp');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'photographers/p_tp'), {
      onboardingComplete: true, verified: true, bio: 'x', stats: { reviewCount: 4, tomatoCount: 3, tomatoPct: 75, score: 0.8 },
    }));
  // The stored tomatoPct (75) differs from the attempted one (100): writing the stored value
  // back changes nothing, so the rules rightly allow it and the assertion would test nothing.
  const customer = env.authenticatedContext('cust_tp').firestore();
  await assertFails(updateDoc(doc(customer, 'photographers/p_tp'), { 'stats.tomatoPct': 100 }));
  await assertFails(setDoc(doc(customer, 'photographers/p_tp'), { stats: { tomatoPct: 100 } }, { merge: true }));
  // Not the owner either: stats are server-computed.
  const owner = env.authenticatedContext('p_tp').firestore();
  await assertFails(updateDoc(doc(owner, 'photographers/p_tp'), { 'stats.tomatoPct': 100 }));
  await assertFails(setDoc(doc(owner, 'photographers/p_tp'), { stats: { tomatoPct: 100 } }, { merge: true }));
  await assertFails(updateDoc(doc(owner, 'photographers/p_tp'), { 'stats.score': 1, 'stats.brickCount': 0 }));
  await assertSucceeds(updateDoc(doc(owner, 'photographers/p_tp'), { bio: 'y' }));
});

test('clients still cannot create real_shoot posts', async () => {
  await seedShooter('p_rs');
  const dbPhotographer = env.authenticatedContext('p_rs').firestore();
  const dbCustomer = env.authenticatedContext('cust_rs').firestore();

  // Photographer cannot create a real_shoot post
  await assertFails(setDoc(doc(dbPhotographer, 'posts/rs_post_1'), validPost('p_rs', { kind: 'real_shoot' })));

  // Customer cannot create a real_shoot post
  await assertFails(setDoc(doc(dbCustomer, 'posts/rs_post_2'), {
    kind: 'real_shoot',
    authorId: 'cust_rs',
    photographerId: 'p_rs',
    serviceId: 's1',
    bookingId: 'b1',
    imageUrls: ['https://x/1.jpg'],
    caption: 'Great shoot',
    likeCount: 0,
    saveCount: 0,
    createdAt: serverTimestamp(),
  }));
});



// Provider types (plan A1): server-only fields and the studio address.
test('owner cannot set providerType', async () => {
  await asPhotographer('pt1');
  const db = env.authenticatedContext('pt1').firestore();
  await assertFails(setDoc(doc(db, 'photographers/pt1'), { onboardingComplete: false, providerType: 'artist' }));
  await assertSucceeds(setDoc(doc(db, 'photographers/pt1'), { onboardingComplete: false }));
  await assertFails(updateDoc(doc(db, 'photographers/pt1'), { providerType: 'studio' }));
});
test('owner cannot remove providerType', async () => {
  await asPhotographer('pt2');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'photographers/pt2'), { onboardingComplete: false, providerType: 'studio' }));
  const db = env.authenticatedContext('pt2').firestore();
  await assertFails(updateDoc(doc(db, 'photographers/pt2'), { providerType: deleteField() }));
});
test('owner cannot set studioDistrict', async () => {
  await asPhotographer('pt3');
  const db = env.authenticatedContext('pt3').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/pt3'), { onboardingComplete: false }));
  await assertFails(updateDoc(doc(db, 'photographers/pt3'), { studioDistrict: 'Quận 1' }));
  await assertFails(updateDoc(doc(db, 'photographers/pt3'), { studioCity: 'TP.HCM' }));
});
test('owner cannot set artistSince or approvedAwardCount', async () => {
  await asPhotographer('pt3b');
  const db = env.authenticatedContext('pt3b').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/pt3b'), { onboardingComplete: false }));
  await assertFails(updateDoc(doc(db, 'photographers/pt3b'), { artistSince: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, 'photographers/pt3b'), { approvedAwardCount: 3 }));
});
test('a photographer doc cannot be created with studioDistrict', async () => {
  await asPhotographer('pt3c');
  const db = env.authenticatedContext('pt3c').firestore();
  await assertFails(setDoc(doc(db, 'photographers/pt3c'), { onboardingComplete: false, studioDistrict: 'Quận 1' }));
  await assertFails(setDoc(doc(db, 'photographers/pt3c'), { onboardingComplete: false, artistSince: serverTimestamp() }));
  await assertFails(setDoc(doc(db, 'photographers/pt3c'), { onboardingComplete: false, approvedAwardCount: 0 }));
});
test('studio cannot finish setup without an address', async () => {
  await asPhotographer('pt4');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'photographers/pt4'), { onboardingComplete: false, providerType: 'studio' }));
  const db = env.authenticatedContext('pt4').firestore();
  await assertFails(updateDoc(doc(db, 'photographers/pt4'), { onboardingComplete: true }));
});
test('studio with an address can finish setup', async () => {
  await asPhotographer('pt5');
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'photographers/pt5'), { onboardingComplete: false, providerType: 'studio' });
    await setDoc(doc(c.firestore(), 'photographers/pt5/private/studioAddress'), {
      line: '12 Lê Lợi', ward: null, district: 'Quận 1', city: 'TP.HCM', lat: null, lng: null,
    });
  });
  const db = env.authenticatedContext('pt5').firestore();
  await assertSucceeds(updateDoc(doc(db, 'photographers/pt5'), { onboardingComplete: true }));
});
test('individual finishes setup as before', async () => {
  await asPhotographer('pt6');
  const db = env.authenticatedContext('pt6').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/pt6'), { onboardingComplete: false }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/pt6'), { onboardingComplete: true }));
});
test('owner cannot un-finish setup', async () => {
  await asPhotographer('pt6b');
  const db = env.authenticatedContext('pt6b').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/pt6b'), { onboardingComplete: false }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/pt6b'), { onboardingComplete: true }));
  await assertFails(updateDoc(doc(db, 'photographers/pt6b'), { onboardingComplete: false }));
  await assertFails(updateDoc(doc(db, 'photographers/pt6b'), { onboardingComplete: deleteField() }));
  await assertFails(setDoc(doc(db, 'photographers/pt6b'), { onboardingComplete: false }));
  // Other edits keep working once setup is finished.
  await assertSucceeds(updateDoc(doc(db, 'photographers/pt6b'), { bio: 'Chân dung' }));
});
test('others cannot read private/studioAddress', async () => {
  await asPhotographer('pt7');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'photographers/pt7/private/studioAddress'), {
      line: '12 Lê Lợi', ward: null, district: 'Quận 1', city: 'TP.HCM', lat: null, lng: null,
    }));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('pt7').firestore(), 'photographers/pt7/private/studioAddress')));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(), 'photographers/pt7/private/studioAddress')));
  await assertFails(setDoc(doc(env.authenticatedContext('pt7').firestore(), 'photographers/pt7/private/studioAddress'), { line: 'x' }));
});

// ---- Plan B1: awards, proofs, audit and proof images ----
async function seedAward(id, photographerId, status) {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), `awards/${id}`), { photographerId, competition: 'Sony', year: 2025, result: 'gold', status });
    await setDoc(doc(c.firestore(), `awardProofs/${id}`), { photographerId, files: [], links: ['https://example.com/x'] });
  });
}

test('anyone signed in reads approved awards', async () => {
  await seedAward('aw-ok', 'awo1', 'approved');
  await assertSucceeds(getDoc(doc(env.authenticatedContext('anyone').firestore(), 'awards/aw-ok')));
  await assertSucceeds(getDocs(query(collection(env.authenticatedContext('anyone').firestore(), 'awards'),
    where('photographerId', '==', 'awo1'), where('status', '==', 'approved'))));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'awards/aw-ok')));
});

test('a pending award is readable by its owner only', async () => {
  await seedAward('aw-pend', 'awo1', 'pending');
  await assertSucceeds(getDoc(doc(env.authenticatedContext('awo1').firestore(), 'awards/aw-pend')));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(), 'awards/aw-pend')));
  await assertFails(getDocs(query(collection(env.authenticatedContext('other').firestore(), 'awards'),
    where('photographerId', '==', 'awo1'))));
});

test('nobody writes awards from the client', async () => {
  await seedAward('aw-w', 'awo1', 'pending');
  const db = env.authenticatedContext('awo1').firestore();
  await assertFails(setDoc(doc(db, 'awards/aw-new'), { photographerId: 'awo1', status: 'approved' }));
  await assertFails(updateDoc(doc(db, 'awards/aw-w'), { status: 'approved' }));
  await assertFails(deleteDoc(doc(db, 'awards/aw-w')));
});

test('proof docs are owner-only', async () => {
  await seedAward('aw-pr', 'awo1', 'approved');
  await assertSucceeds(getDoc(doc(env.authenticatedContext('awo1').firestore(), 'awardProofs/aw-pr')));
  await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(), 'awardProofs/aw-pr')));
  await assertFails(updateDoc(doc(env.authenticatedContext('awo1').firestore(), 'awardProofs/aw-pr'), { links: [] }));
});

test('nobody reads the audit log', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'awardAudit/au1'), { awardId: 'aw-pr', actorId: 'staff', action: 'approve', note: '', at: Timestamp.now() }));
  await assertFails(getDoc(doc(env.authenticatedContext('staff').firestore(), 'awardAudit/au1')));
  await assertFails(setDoc(doc(env.authenticatedContext('awo1').firestore(), 'awardAudit/au2'), { awardId: 'x' }));
});

test('the owner uploads, reads and deletes a proof image; others cannot read it', async () => {
  const own = ref(env.authenticatedContext('awo1').storage(), 'awardProofs/awo1/aw1/0.jpg');
  await assertSucceeds(uploadBytes(own, photo(), jpeg));
  await assertSucceeds(getBytes(own));
  await assertFails(getBytes(ref(env.authenticatedContext('other').storage(), 'awardProofs/awo1/aw1/0.jpg')));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), 'awardProofs/awo1/aw1/0.jpg')));
  await assertFails(uploadBytes(ref(env.authenticatedContext('other').storage(), 'awardProofs/awo1/aw1/1.jpg'), photo(), jpeg));
  await assertSucceeds(deleteObject(own));
});

test('an existing proof file cannot be overwritten', async () => {
  const own = ref(env.authenticatedContext('awo1').storage(), 'awardProofs/awo1/aw1/fixed.jpg');
  await assertSucceeds(uploadBytes(own, photo(), jpeg));
  await assertFails(uploadBytes(own, photo(), jpeg));
});

test('a proof over 3 MiB, a PNG, an SVG or a non-image is refused', async () => {
  const st = env.authenticatedContext('awo1').storage();
  await assertSucceeds(uploadBytes(ref(st, 'awardProofs/awo1/aw1/ok.jpg'), photo(3 * 1024 * 1024), jpeg));
  await assertFails(uploadBytes(ref(st, 'awardProofs/awo1/aw1/big.jpg'), photo(3 * 1024 * 1024 + 1), jpeg));
  await assertFails(uploadBytes(ref(st, 'awardProofs/awo1/aw1/big10.jpg'), photo(10 * 1024 * 1024), jpeg));
  await assertFails(uploadBytes(ref(st, 'awardProofs/awo1/aw1/a.pdf'), photo(), { contentType: 'application/pdf' }));
  await assertFails(uploadBytes(ref(st, 'awardProofs/awo1/aw1/a.svg'), photo(), { contentType: 'image/svg+xml' }));
  await assertFails(uploadBytes(ref(st, 'awardProofs/awo1/aw1/b.png'), photo(), { contentType: 'image/png' })); // was allowed before JPEG-only
  await assertFails(uploadBytes(ref(st, 'awardProofs/awo1/aw1/b.heic'), photo(), { contentType: 'image/heic' }));
});

// ---- notifications, prefs, badges, devices (plan 10a) ----

const seedNotification = (uid, id, readAt = null) =>
  env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), `users/${uid}/notifications/${id}`), {
      type: 'booking_accepted', tab: 'activity', category: 'booking', title: 't', body: 'b', target: '/b/x',
      groupKey: null, actors: [], count: 1, thumbUrl: null, lastEventId: null, createdAt: Timestamp.now(), readAt,
    }));

const goodPrefs = () => ({
  channels: { booking: { push: true, inApp: true }, chat: { push: false, inApp: true } },
  quietHours: { enabled: true, from: '22:00', to: '07:00' },
  reminders: { h24: true, h2: false },
  updatedAt: serverTimestamp(),
});

test('notifications: the owner reads their own rows, others cannot', async () => {
  await seedNotification('nu1', 'n_a');
  await assertSucceeds(getDoc(doc(env.authenticatedContext('nu1').firestore(), 'users/nu1/notifications/n_a')));
  await assertFails(getDoc(doc(env.authenticatedContext('nu2').firestore(), 'users/nu1/notifications/n_a')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/nu1/notifications/n_a')));
});

test('notifications: the owner may set readAt once to request.time', async () => {
  await seedNotification('nu1', 'n_b');
  const db = env.authenticatedContext('nu1').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users/nu1/notifications/n_b'), { readAt: serverTimestamp() }));
});

test('notifications: readAt cannot be cleared, set twice or set to another time', async () => {
  await seedNotification('nu1', 'n_c', Timestamp.now());
  const db = env.authenticatedContext('nu1').firestore();
  await assertFails(updateDoc(doc(db, 'users/nu1/notifications/n_c'), { readAt: null }));
  await assertFails(updateDoc(doc(db, 'users/nu1/notifications/n_c'), { readAt: serverTimestamp() }));
  await seedNotification('nu1', 'n_d');
  await assertFails(updateDoc(doc(db, 'users/nu1/notifications/n_d'), { readAt: Timestamp.fromMillis(1000) }));
});

test('notifications: no other field of a row can change', async () => {
  await seedNotification('nu1', 'n_e');
  const db = env.authenticatedContext('nu1').firestore();
  await assertFails(updateDoc(doc(db, 'users/nu1/notifications/n_e'), { title: 'x' }));
  await assertFails(updateDoc(doc(db, 'users/nu1/notifications/n_e'), { readAt: serverTimestamp(), title: 'x' }));
});

test('notifications: nobody creates or deletes rows', async () => {
  await seedNotification('nu1', 'n_f');
  const db = env.authenticatedContext('nu1').firestore();
  await assertFails(setDoc(doc(db, 'users/nu1/notifications/n_new'), { type: 'promo', readAt: null }));
  await assertFails(deleteDoc(doc(db, 'users/nu1/notifications/n_f')));
});

test('unreadCount is not client-writable, and the private inbox doc is owner-read only', async () => {
  const db = env.authenticatedContext('nu1').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/nu1'), { displayName: 'N' }));
  await assertFails(updateDoc(doc(db, 'users/nu1'), { unreadCount: 0 }));
  await assertFails(updateDoc(doc(db, 'users/nu1'), { unreadCountAt: serverTimestamp() }));
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'users/nu1/private/inbox'), { unreadCount: 3, unreadCountAt: Timestamp.now() }));
  await assertSucceeds(getDoc(doc(db, 'users/nu1/private/inbox')));
  await assertFails(getDoc(doc(env.authenticatedContext('nu2').firestore(), 'users/nu1/private/inbox')));
  await assertFails(setDoc(doc(db, 'users/nu1/private/inbox'), { unreadCount: 0 }));
  await assertFails(updateDoc(doc(db, 'users/nu1/private/inbox'), { unreadCount: 0 }));
});

test('prefs: the owner writes a valid doc', async () => {
  const db = env.authenticatedContext('pf1').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/pf1/private/notification_prefs'), goodPrefs()));
  await assertSucceeds(getDoc(doc(db, 'users/pf1/private/notification_prefs')));
});

test('prefs: booking.inApp false is refused', async () => {
  const db = env.authenticatedContext('pf1').firestore();
  const p = goodPrefs();
  p.channels.booking = { push: true, inApp: false };
  await assertFails(setDoc(doc(db, 'users/pf1/private/notification_prefs'), p));
});

test('prefs: a bad time string or extra key is refused', async () => {
  const db = env.authenticatedContext('pf1').firestore();
  const p = goodPrefs();
  p.quietHours.from = '25:00';
  await assertFails(setDoc(doc(db, 'users/pf1/private/notification_prefs'), p));
  await assertFails(setDoc(doc(db, 'users/pf1/private/notification_prefs'), { ...goodPrefs(), extra: 1 }));
});

test('prefs: other users cannot read or write them', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'users/pf1/private/notification_prefs'), { channels: {} }));
  const other = env.authenticatedContext('pf2').firestore();
  await assertFails(getDoc(doc(other, 'users/pf1/private/notification_prefs')));
  await assertFails(setDoc(doc(other, 'users/pf1/private/notification_prefs'), goodPrefs()));
});

test('badgeProgress is owner-only and not writable', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'users/bp1/private/badgeProgress'), { entries: { punctual: { current: 3, target: 5 } } }));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('bp1').firestore(), 'users/bp1/private/badgeProgress')));
  await assertFails(getDoc(doc(env.authenticatedContext('bp2').firestore(), 'users/bp1/private/badgeProgress')));
  await assertFails(setDoc(doc(env.authenticatedContext('bp1').firestore(), 'users/bp1/private/badgeProgress'), { entries: {} }));
});

test('earned badges are readable by signed-in users, never writable', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'users/bp1/badges/top_rated'), { badgeId: 'top_rated', uid: 'bp1', awardedAt: Timestamp.now(), snapshot: { text: 'x' } }));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('bp2').firestore(), 'users/bp1/badges/top_rated')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/bp1/badges/top_rated')));
  await assertFails(setDoc(doc(env.authenticatedContext('bp1').firestore(), 'users/bp1/badges/shoots_10'), { badgeId: 'shoots_10' }));
  await assertFails(deleteDoc(doc(env.authenticatedContext('bp1').firestore(), 'users/bp1/badges/top_rated')));
});

test('badge catalogue is readable, not writable', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'badges/top_rated'), { name: 'Được đánh giá cao' }));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('bp1').firestore(), 'badges/top_rated')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'badges/top_rated')));
  await assertFails(setDoc(doc(env.authenticatedContext('bp1').firestore(), 'badges/x'), { name: 'x' }));
});

test('devices: owner creates with the id pattern; other uid or extra keys refused', async () => {
  const db = env.authenticatedContext('du1').firestore();
  const good = { userId: 'du1', provider: 'fcm', token: 'tok-123', platform: 'android', lastSeenAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db, 'devices/du1_ABCDEFGH12'), good));
  await assertSucceeds(getDoc(doc(db, 'devices/du1_ABCDEFGH12')));
  await assertFails(setDoc(doc(db, 'devices/du2_ABCDEFGH12'), { ...good, userId: 'du2' }));
  await assertFails(setDoc(doc(db, 'devices/du1_ABCDEFGH12'), { ...good, extra: 1 }));
  await assertFails(setDoc(doc(db, 'devices/du1_ABCDEFGH12'), { ...good, platform: 'web' }));
  await assertFails(getDoc(doc(env.authenticatedContext('du2').firestore(), 'devices/du1_ABCDEFGH12')));
  await assertSucceeds(deleteDoc(doc(db, 'devices/du1_ABCDEFGH12')));
});

// ---- earnings and payout accounts (unit 10b) ----
const seedDoc = (path, data) => env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), path), data));

test('the owner reads their earnings and rows', async () => {
  await seedDoc('earnings/ea1', { heldAmount: 1, soonAmount: 2, receivedAmount: 3, lastPayout: null, updatedAt: Timestamp.now() });
  await seedDoc('earnings/ea1/items/pay1', { payeeId: 'ea1', amount: 5, state: 'held' });
  const db = env.authenticatedContext('ea1').firestore();
  await assertSucceeds(getDoc(doc(db, 'earnings/ea1')));
  await assertSucceeds(getDoc(doc(db, 'earnings/ea1/items/pay1')));
  await assertSucceeds(getDocs(collection(db, 'earnings/ea1/items')));
});
test('another user cannot read earnings or items', async () => {
  const other = env.authenticatedContext('ea2').firestore();
  await assertFails(getDoc(doc(other, 'earnings/ea1')));
  await assertFails(getDoc(doc(other, 'earnings/ea1/items/pay1')));
  await assertFails(getDocs(collection(other, 'earnings/ea1/items')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'earnings/ea1')));
});
test('nobody writes earnings', async () => {
  const db = env.authenticatedContext('ea1').firestore();
  await assertFails(setDoc(doc(db, 'earnings/ea1'), { heldAmount: 9 }));
  await assertFails(updateDoc(doc(db, 'earnings/ea1'), { heldAmount: 9 }));
  await assertFails(setDoc(doc(db, 'earnings/ea1/items/pay2'), { amount: 9 }));
  await assertFails(deleteDoc(doc(db, 'earnings/ea1/items/pay1')));
});
test('the owner reads the masked account view and cannot write it', async () => {
  await seedDoc('payoutAccounts/pa1', { accountId: 'a1', bankCode: 'VCB', accountLast4: '6789', holderName: 'NGUYEN VAN AN', updatedAt: Timestamp.now() });
  const db = env.authenticatedContext('pa1').firestore();
  await assertSucceeds(getDoc(doc(db, 'payoutAccounts/pa1')));
  await assertFails(getDoc(doc(env.authenticatedContext('pa2').firestore(), 'payoutAccounts/pa1')));
  await assertFails(setDoc(doc(db, 'payoutAccounts/pa1'), { accountLast4: '0000' }));
  await assertFails(updateDoc(doc(db, 'payoutAccounts/pa1'), { holderName: 'X' }));
  await assertFails(deleteDoc(doc(db, 'payoutAccounts/pa1')));
});
test('the owner cannot read the accounts history', async () => {
  await seedDoc('payoutAccounts/pa1/accounts/a1', { accountNumberEnc: 'v1:x:y:z', userId: 'pa1' });
  const db = env.authenticatedContext('pa1').firestore();
  await assertFails(getDoc(doc(db, 'payoutAccounts/pa1/accounts/a1')));
  await assertFails(getDocs(collection(db, 'payoutAccounts/pa1/accounts')));
  await assertFails(setDoc(doc(db, 'payoutAccounts/pa1/accounts/a2'), { accountNumberEnc: 'v1:x:y:z' }));
});
test('payouts are server-only: the payee cannot read or write them', async () => {
  await seedDoc('payouts/po1', { payeeId: 'pp1', status: 'paid', amount: 100, items: [], holdReason: 'x', createdAt: Timestamp.now() });
  await assertFails(getDoc(doc(env.authenticatedContext('pp1').firestore(), 'payouts/po1')));
  await assertFails(getDocs(query(collection(env.authenticatedContext('pp1').firestore(), 'payouts'), where('payeeId', '==', 'pp1'))));
  await assertFails(getDoc(doc(env.authenticatedContext('pp2').firestore(), 'payouts/po1')));
  await assertFails(setDoc(doc(env.authenticatedContext('pp1').firestore(), 'payouts/po2'), { payeeId: 'pp1' }));
  await assertFails(updateDoc(doc(env.authenticatedContext('pp1').firestore(), 'payouts/po1'), { status: 'failed' }));
});
// ---- S06 #134: assignee booking read (Decision 18) and the payout account v2 server-only docs ----
test('the assignee can read a booking with assigneeId == uid', async () => {
  await seedDoc('bookings/b_as1', { customerId: 'asc1', photographerId: 'asstudio1', assigneeId: 'asm1', status: 'upcoming' });
  await assertSucceeds(getDoc(doc(env.authenticatedContext('asm1').firestore(), 'bookings/b_as1')));
  // The customer and the studio still read it.
  await assertSucceeds(getDoc(doc(env.authenticatedContext('asc1').firestore(), 'bookings/b_as1')));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('asstudio1').firestore(), 'bookings/b_as1')));
  // Reading is all: the assignee cannot write the booking.
  await assertFails(updateDoc(doc(env.authenticatedContext('asm1').firestore(), 'bookings/b_as1'), { status: 'completed' }));
});
test('a stranger cannot read a booking assigned to someone else', async () => {
  await seedDoc('bookings/b_as2', { customerId: 'asc1', photographerId: 'asstudio1', assigneeId: 'asm1', status: 'upcoming' });
  await assertFails(getDoc(doc(env.authenticatedContext('asm2').firestore(), 'bookings/b_as2')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'bookings/b_as2')));
  // A booking without assigneeId is not readable by a stranger either.
  await seedDoc('bookings/b_as3', { customerId: 'asc1', photographerId: 'asstudio1', status: 'upcoming' });
  await assertFails(getDoc(doc(env.authenticatedContext('asm2').firestore(), 'bookings/b_as3')));
});
test('an assignee query (where assigneeId == uid) is allowed; an unfiltered one is not', async () => {
  await seedDoc('bookings/b_as4', { customerId: 'asc1', photographerId: 'asstudio1', assigneeId: 'asm3', status: 'upcoming' });
  const db = env.authenticatedContext('asm3').firestore();
  const snap = await assertSucceeds(getDocs(query(collection(db, 'bookings'), where('assigneeId', '==', 'asm3'))));
  assert.ok(snap.docs.some((d) => d.id === 'b_as4'));
  await assertFails(getDocs(query(collection(db, 'bookings'), where('assigneeId', '==', 'asm1'))));
  await assertFails(getDocs(collection(db, 'bookings')));
});
test('nobody reads or writes otp_challenges', async () => {
  await seedDoc('otp_challenges/otp1_payout_account', { uid: 'otp1', purpose: 'payout_account', codeHash: 'h', salt: 's', targetHash: 't', attempts: 0 });
  const owner = env.authenticatedContext('otp1').firestore();
  await assertFails(getDoc(doc(owner, 'otp_challenges/otp1_payout_account')));
  await assertFails(getDocs(query(collection(owner, 'otp_challenges'), where('uid', '==', 'otp1'))));
  await assertFails(setDoc(doc(owner, 'otp_challenges/otp1_payout_account'), { attempts: 0 }));
  await assertFails(updateDoc(doc(owner, 'otp_challenges/otp1_payout_account'), { attempts: 0 }));
  await assertFails(deleteDoc(doc(owner, 'otp_challenges/otp1_payout_account')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'otp_challenges/otp1_payout_account')));
});
test('nobody reads or writes payout_lookups', async () => {
  await seedDoc('payout_lookups/pl1', { day: '2026-10-10', count: 20 });
  const owner = env.authenticatedContext('pl1').firestore();
  await assertFails(getDoc(doc(owner, 'payout_lookups/pl1')));
  await assertFails(setDoc(doc(owner, 'payout_lookups/pl1'), { day: '2026-10-10', count: 0 }));
  await assertFails(updateDoc(doc(owner, 'payout_lookups/pl1'), { count: 0 }));
  await assertFails(deleteDoc(doc(owner, 'payout_lookups/pl1')));
  await assertFails(getDoc(doc(env.authenticatedContext('pl2').firestore(), 'payout_lookups/pl1')));
});
test('the owner still cannot write payoutAccounts', async () => {
  await seedDoc('payoutAccounts/pa3', {
    accountId: 'a1', bankCode: 'VCB', accountLast4: '6789', holderName: 'NGUYEN VAN AN', updatedAt: Timestamp.now(),
    nameStatus: 'matched', activeFrom: Timestamp.now(),
  });
  const db = env.authenticatedContext('pa3').firestore();
  await assertSucceeds(getDoc(doc(db, 'payoutAccounts/pa3')));
  await assertFails(updateDoc(doc(db, 'payoutAccounts/pa3'), { nameStatus: 'staff_confirmed' }));
  await assertFails(updateDoc(doc(db, 'payoutAccounts/pa3'), { activeFrom: Timestamp.now() }));
  await assertFails(setDoc(doc(db, 'payoutAccounts/pa3/accounts/a9'), { accountNumberEnc: 'v1:x:y:z', userId: 'pa3', active: true }));
});
test('payments stay closed', async () => {
  await seedDoc('payments/pay9', { payeeId: 'pp1', amount: 5 });
  await assertFails(getDoc(doc(env.authenticatedContext('pp1').firestore(), 'payments/pay9')));
  await assertFails(setDoc(doc(env.authenticatedContext('pp1').firestore(), 'payments/pay10'), { payeeId: 'pp1' }));
});

// ---- Photo events (plan 10c) ----
const EV_PUBLIC = ['open', 'full'];
const evDoc = (over = {}) => ({
  host: { type: 'photographer', id: 'eh1', name: 'An', avatarUrl: null, verified: true },
  hostId: 'eh1', createdBy: 'eh1', createdByRole: 'photographer', hostConsent: 'not_required',
  title: 'Photo walk', status: 'open', price: 0, capacity: 10, registeredCount: 1, heldCount: 0,
  startAt: Timestamp.fromMillis(Date.now() + 5 * 86_400_000),
  endAt: Timestamp.fromMillis(Date.now() + 5 * 86_400_000 + 3_600_000),
  createdAt: Timestamp.now(), ...over,
});
const regDoc = (userId, over = {}) => ({
  id: 'r1', eventId: 'e1', userId, status: 'paid', quantity: 1, amount: 0, contactEligible: false,
  ticketCode: 'VE-ABCD-1012', createdAt: Timestamp.now(), ...over,
});
const evSeed = (path, data) => env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), path), data));
const evDb = (uid, claims) => env.authenticatedContext(uid, claims).firestore();

test('events: a visitor reads an open event', async () => {
  await evSeed('events/e1', evDoc());
  await assertSucceeds(getDoc(doc(evDb('v1'), 'events/e1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'events/e1')));
});
test('events: a visitor cannot read a draft', async () => {
  await evSeed('events/e2', evDoc({ status: 'draft' }));
  await assertFails(getDoc(doc(evDb('v1'), 'events/e2')));
  await assertSucceeds(getDoc(doc(evDb('eh1'), 'events/e2')));
});
test('events: the creator lists their drafts', async () => {
  await evSeed('events/e3', evDoc({ status: 'draft', createdBy: 'creator1', hostId: null,
    host: { type: 'platform', id: null, name: null, avatarUrl: null, verified: true } }));
  await assertSucceeds(getDocs(query(collection(evDb('creator1'), 'events'), where('createdBy', '==', 'creator1'))));
});
test('events: "my events" is createdBy == me OR hostId == me (S06.01, /events/mine)', async () => {
  await evSeed('events/e4', evDoc({ status: 'draft', createdBy: 'staff1', hostId: 'host1', hostConsent: 'accepted',
    host: { type: 'photographer', id: 'host1', name: 'H', avatarUrl: null, verified: true } }));
  const mine = (uid) => query(collection(evDb(uid), 'events'),
    or(where('createdBy', '==', uid), where('hostId', '==', uid)));
  await assertSucceeds(getDocs(mine('host1')));
  await assertSucceeds(getDocs(mine('staff1')));
});
test('events: a public list must filter status', async () => {
  await assertSucceeds(getDocs(query(collection(evDb('v1'), 'events'), where('status', 'in', EV_PUBLIC))));
  await assertFails(getDocs(collection(evDb('v1'), 'events')));
});
test('events: nobody writes events', async () => {
  await assertFails(setDoc(doc(evDb('eh1'), 'events/e9'), evDoc()));
  await assertFails(updateDoc(doc(evDb('eh1'), 'events/e1'), { title: 'x' }));
  await assertFails(deleteDoc(doc(evDb('eh1'), 'events/e1')));
  await assertFails(setDoc(doc(evDb('adm', { staffRole: 'admin' }), 'events/e9'), evDoc()));
});
test('events: a user reads their own registration', async () => {
  await evSeed('events/e1', evDoc());
  await evSeed('events/e1/registrations/r1', regDoc('att1'));
  await assertSucceeds(getDoc(doc(evDb('att1'), 'events/e1/registrations/r1')));
});
test('events: another user cannot read a registration', async () => {
  await assertFails(getDoc(doc(evDb('att2'), 'events/e1/registrations/r1')));
});
test('events: the host reads every registration of their event', async () => {
  await assertSucceeds(getDoc(doc(evDb('eh1'), 'events/e1/registrations/r1')));
  await assertSucceeds(getDocs(collection(evDb('eh1'), 'events/e1/registrations')));
});
test('events: a sales user cannot read registrations of another sales user\'s event', async () => {
  await evSeed('events/e4', evDoc({ createdBy: 'sales1', hostId: null,
    host: { type: 'platform', id: null, name: null, avatarUrl: null, verified: true } }));
  await evSeed('events/e4/registrations/r1', regDoc('att1', { eventId: 'e4' }));
  await assertSucceeds(getDoc(doc(evDb('sales1', { staffRole: 'sales' }), 'events/e4/registrations/r1')));
  await assertFails(getDoc(doc(evDb('sales2', { staffRole: 'sales' }), 'events/e4/registrations/r1')));
});
test('events: an admin reads any registration', async () => {
  await assertSucceeds(getDoc(doc(evDb('adm', { staffRole: 'admin' }), 'events/e4/registrations/r1')));
  await assertSucceeds(getDoc(doc(evDb('adm', { staffRole: 'admin' }), 'events/e1/registrations/r1')));
});
test('events: a host reads a paid attendee\'s contact', async () => {
  await evSeed('events/e1/registrations/r2', regDoc('att3', { id: 'r2', amount: 120000, contactEligible: true }));
  await evSeed('events/e1/registrations/r2/private/contact', { name: 'Khách', phone: '+84912345678' });
  await assertSucceeds(getDoc(doc(evDb('eh1'), 'events/e1/registrations/r2/private/contact')));
});
test('events: a host cannot read a held attendee\'s contact', async () => {
  await evSeed('events/e1/registrations/r3', regDoc('att4', { id: 'r3', status: 'held', amount: 120000 }));
  await evSeed('events/e1/registrations/r3/private/contact', { name: 'Khách', phone: '+84912345679' });
  await assertFails(getDoc(doc(evDb('eh1'), 'events/e1/registrations/r3/private/contact')));
});
test('events: a host cannot read the contact of a free registration (O3)', async () => {
  await evSeed('events/e1/registrations/r1/private/contact', { name: 'Khách', phone: '+84912345600' });
  await assertFails(getDoc(doc(evDb('eh1'), 'events/e1/registrations/r1/private/contact')));
  await assertFails(getDoc(doc(evDb('adm', { staffRole: 'admin' }), 'events/e1/registrations/r1/private/contact')));
});
test('events: the attendee reads their own contact', async () => {
  await assertSucceeds(getDoc(doc(evDb('att3'), 'events/e1/registrations/r2/private/contact')));
  await assertFails(getDoc(doc(evDb('att2'), 'events/e1/registrations/r2/private/contact')));
  await assertFails(setDoc(doc(evDb('att3'), 'events/e1/registrations/r2/private/contact'), { phone: '+84900000000' }));
});
test('events: a host cannot read a paid contact after the 7-day window', async () => {
  await evSeed('events/e5', evDoc({ endAt: Timestamp.fromMillis(Date.now() - 8 * 86_400_000) }));
  await evSeed('events/e5/registrations/r1', regDoc('att1', { eventId: 'e5', amount: 5000, contactEligible: true }));
  await evSeed('events/e5/registrations/r1/private/contact', { name: 'K', phone: '+84912345601' });
  await assertFails(getDoc(doc(evDb('eh1'), 'events/e5/registrations/r1/private/contact')));
});
test('events: collection group: a user lists only their registrations', async () => {
  await assertSucceeds(getDocs(query(collectionGroup(evDb('att1'), 'registrations'), where('userId', '==', 'att1'))));
  await assertFails(getDocs(query(collectionGroup(evDb('att1'), 'registrations'), where('userId', '==', 'att2'))));
  await assertFails(getDocs(collectionGroup(evDb('att1'), 'registrations')));
});
test('events: guards are closed', async () => {
  await evSeed('event_hashtags/photowalk1012', { eventId: 'e1' });
  await evSeed('ticket_codes/VE-ABCD-1012', { eventId: 'e1', registrationId: 'r1' });
  await assertFails(getDoc(doc(evDb('eh1'), 'event_hashtags/photowalk1012')));
  await assertFails(setDoc(doc(evDb('eh1'), 'event_hashtags/other'), { eventId: 'e1' }));
  await assertFails(getDoc(doc(evDb('eh1'), 'ticket_codes/VE-ABCD-1012')));
  await assertFails(setDoc(doc(evDb('att1'), 'ticket_codes/VE-ZZZZ-1012'), { eventId: 'e1', registrationId: 'r1' }));
});
test('events storage: an owner uploads a cover, others cannot', async () => {
  const mine = ref(env.authenticatedContext('eh1').storage(), 'eventCovers/eh1/e1/cover.jpg');
  await assertSucceeds(uploadBytes(mine, photo(), jpeg));
  await assertSucceeds(getBytes(mine));
  const other = env.authenticatedContext('eh2').storage();
  await assertFails(uploadBytes(ref(other, 'eventCovers/eh1/e1/x.jpg'), photo(), jpeg));
  await assertFails(deleteObject(ref(other, 'eventCovers/eh1/e1/cover.jpg')));
  await assertSucceeds(getBytes(ref(other, 'eventCovers/eh1/e1/cover.jpg')));
  const eh1 = env.authenticatedContext('eh1').storage();
  await assertSucceeds(uploadBytes(ref(eh1, 'eventCovers/eh1/e1/ok2.jpg'), photo(2 * 1024 * 1024), jpeg));
  await assertFails(uploadBytes(ref(eh1, 'eventCovers/eh1/e1/big.jpg'), photo(2 * 1024 * 1024 + 1), jpeg));
  await assertFails(uploadBytes(ref(eh1, 'eventCovers/eh1/e1/c.png'), photo(), { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(env.authenticatedContext('eh1').storage(), 'eventCovers/eh1/e1/a.txt'), photo(), { contentType: 'text/plain' }));
  await assertSucceeds(deleteObject(mine));
});

test('events: a cancelled never-published draft is private; a cancelled published event is readable', async () => {
  await evSeed('events/e6', evDoc({ status: 'cancelled', publishedAt: null, hostConsent: 'declined' }));
  await evSeed('events/e7', evDoc({ status: 'cancelled', publishedAt: Timestamp.now() }));
  await assertFails(getDoc(doc(evDb('v1'), 'events/e6')));
  await assertSucceeds(getDoc(doc(evDb('eh1'), 'events/e6')));
  await assertSucceeds(getDoc(doc(evDb('v1'), 'events/e7')));
  await assertFails(getDocs(query(collection(evDb('v1'), 'events'), where('status', '==', 'cancelled'))));
  await assertFails(getDocs(query(collection(evDb('v1'), 'events'), where('status', 'in', ['open', 'cancelled']))));
});

// ---- Event timeline and group chat (plan 10c, Task 7) ----
const tlRow = (status, over = {}) => ({
  postId: 'tp1', source: 'hashtag', status, authorId: 'att1', authorName: 'Lan', isHost: false,
  imageUrl: 'https://s.test/a.jpg', imageW: 10, imageH: 20, imageCount: 1, addedAt: Timestamp.now(), moderatedBy: null, ...over,
});

test('timeline: visitors read visible rows', async () => {
  await evSeed('events/e1', evDoc());
  await evSeed('events/e1/timeline/tp1', tlRow('visible'));
  await assertSucceeds(getDoc(doc(evDb('v1'), 'events/e1/timeline/tp1')));
  await assertSucceeds(getDocs(query(collection(evDb('v1'), 'events/e1/timeline'), where('status', '==', 'visible'))));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'events/e1/timeline/tp1')));
});
test('timeline: visitors cannot read pending or hidden rows', async () => {
  await evSeed('events/e1/timeline/tp2', tlRow('pending', { postId: 'tp2' }));
  await evSeed('events/e1/timeline/tp3', tlRow('hidden', { postId: 'tp3' }));
  await assertFails(getDoc(doc(evDb('v1'), 'events/e1/timeline/tp2')));
  await assertFails(getDoc(doc(evDb('att1'), 'events/e1/timeline/tp3')));
  await assertFails(getDocs(query(collection(evDb('v1'), 'events/e1/timeline'), where('status', '==', 'pending'))));
  await assertFails(getDocs(collection(evDb('v1'), 'events/e1/timeline')));
});
test('timeline: managers read pending and hidden rows', async () => {
  await assertSucceeds(getDoc(doc(evDb('eh1'), 'events/e1/timeline/tp2')));
  await assertSucceeds(getDoc(doc(evDb('adm', { staffRole: 'admin' }), 'events/e1/timeline/tp3')));
  await assertSucceeds(getDocs(query(collection(evDb('eh1'), 'events/e1/timeline'), where('status', '==', 'pending'))));
  await assertFails(getDoc(doc(evDb('sales2', { staffRole: 'sales' }), 'events/e1/timeline/tp2')));
});
test('timeline: nobody writes rows', async () => {
  await assertFails(setDoc(doc(evDb('eh1'), 'events/e1/timeline/new'), tlRow('visible', { postId: 'new' })));
  await assertFails(updateDoc(doc(evDb('eh1'), 'events/e1/timeline/tp2'), { status: 'visible' }));
  await assertFails(deleteDoc(doc(evDb('adm', { staffRole: 'admin' }), 'events/e1/timeline/tp2')));
  await assertFails(updateDoc(doc(evDb('att1'), 'events/e1/timeline/tp1'), { status: 'hidden' }));
});

const grpChat = (members, over = {}) => ({
  kind: 'event_group', eventId: 'e1', title: 'Photo walk', members, moderators: ['eh1'], memberCount: members.length,
  moderatorsOnly: false, readOnlyAt: null, createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...over,
});
const grpMember = (name, over = {}) => ({
  role: 'member', name, avatarUrl: null, mutedUntil: null, joinedAt: Timestamp.now(), removedAt: null, removedBy: null,
  sentWindowStart: null, sentInWindow: 0, ...over,
});

test('chat pins: members read them, others cannot, nobody writes', async () => {
  await evSeed('chats/event_e1', grpChat(['eh1', 'att1']));
  await evSeed('chats/event_e1/pins/m1', { body: 'Họp 8h', senderName: 'An', pinnedBy: 'eh1', pinnedAt: Timestamp.now() });
  await assertSucceeds(getDoc(doc(evDb('att1'), 'chats/event_e1/pins/m1')));
  await assertSucceeds(getDocs(collection(evDb('eh1'), 'chats/event_e1/pins')));
  await assertFails(getDoc(doc(evDb('v1'), 'chats/event_e1/pins/m1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'chats/event_e1/pins/m1')));
  await assertFails(setDoc(doc(evDb('eh1'), 'chats/event_e1/pins/m2'), { body: 'x' }));
  await assertFails(deleteDoc(doc(evDb('eh1'), 'chats/event_e1/pins/m1')));
});
test('a removed member cannot read messages, pins or the chat', async () => {
  await evSeed('chats/event_e2', grpChat(['eh1', 'att1']));
  await evSeed('chats/event_e2/messages/m1', { senderId: 'att1', senderName: 'Lan', type: 'text', body: 'hi', createdAt: Timestamp.now() });
  await evSeed('chats/event_e2/pins/m1', { body: 'hi', senderName: 'Lan', pinnedBy: 'eh1', pinnedAt: Timestamp.now() });
  await assertSucceeds(getDoc(doc(evDb('att1'), 'chats/event_e2/messages/m1')));
  // the server removes att1: the uid leaves `members`, the member doc stays as history
  await evSeed('chats/event_e2', grpChat(['eh1']));
  await evSeed('chats/event_e2/members/att1', grpMember('Lan', { removedAt: Timestamp.now(), removedBy: 'eh1' }));
  await assertFails(getDoc(doc(evDb('att1'), 'chats/event_e2/messages/m1')));
  await assertFails(getDocs(collection(evDb('att1'), 'chats/event_e2/messages')));
  await assertFails(getDoc(doc(evDb('att1'), 'chats/event_e2/pins/m1')));
  await assertFails(getDoc(doc(evDb('att1'), 'chats/event_e2')));
  await assertSucceeds(getDoc(doc(evDb('eh1'), 'chats/event_e2/messages/m1')));
});
test('group chat members read each other\'s member docs; 1-1 chats keep owner-only', async () => {
  await evSeed('chats/event_e3', grpChat(['eh1', 'att1']));
  await evSeed('chats/event_e3/members/eh1', grpMember('An', { role: 'moderator' }));
  await evSeed('chats/event_e3/members/att1', grpMember('Lan'));
  await assertSucceeds(getDoc(doc(evDb('att1'), 'chats/event_e3/members/eh1')));
  await assertSucceeds(getDocs(collection(evDb('att1'), 'chats/event_e3/members')));
  await assertFails(getDoc(doc(evDb('v1'), 'chats/event_e3/members/att1')));
  await assertFails(setDoc(doc(evDb('att1'), 'chats/event_e3/members/att1'), grpMember('Hack', { role: 'moderator' })));
  await evSeed('chats/chat_1on1', { kind: 'inquiry', members: ['userA', 'userB'] });
  await evSeed('chats/chat_1on1/members/userA', { unreadCount: 1 });
  await assertFails(getDoc(doc(evDb('userB'), 'chats/chat_1on1/members/userA')));
  await assertSucceeds(getDoc(doc(evDb('userA'), 'chats/chat_1on1/members/userA')));
});
test('a group member marks the chat read but changes nothing else on their member doc', async () => {
  await assertSucceeds(updateDoc(doc(evDb('att1'), 'chats/event_e3/members/att1'), { unreadCount: 0, lastReadAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(evDb('att1'), 'chats/event_e3/members/att1'), { role: 'moderator' }));
  // M14: a real value, alongside an otherwise valid read marker, so only the affectedKeys guard refuses it.
  await assertFails(updateDoc(doc(evDb('att1'), 'chats/event_e3/members/att1'), { mutedUntil: Timestamp.now() }));
  await assertFails(updateDoc(doc(evDb('att1'), 'chats/event_e3/members/att1'),
    { unreadCount: 0, lastReadAt: serverTimestamp(), mutedUntil: Timestamp.now() }));
});

test('chat storage: a removed member cannot read chat images', async () => {
  await evSeed('chats/event_e4', grpChat(['eh1', 'att1']));
  const path = 'chats/event_e4/att1/pic.jpg';
  await assertSucceeds(uploadBytes(ref(evStorage('att1'), path), photo(), jpeg));
  await assertSucceeds(getBytes(ref(evStorage('eh1'), path)));
  await assertFails(getBytes(ref(evStorage('v1'), path)));
  await evSeed('chats/event_e4', grpChat(['eh1']));
  await assertFails(getBytes(ref(evStorage('att1'), path)));
  await assertFails(uploadBytes(ref(evStorage('att1'), 'chats/event_e4/att1/again.jpg'), photo(), jpeg));
});
test('chat storage: a member uploads up to 1.5 MiB of JPEG, nothing else', async () => {
  await evSeed('chats/event_e5', grpChat(['eh1', 'att1']));
  const st = evStorage('att1');
  await assertSucceeds(uploadBytes(ref(st, 'chats/event_e5/att1/ok.jpg'), photo(1536 * 1024), jpeg));
  await assertFails(uploadBytes(ref(st, 'chats/event_e5/att1/big.jpg'), photo(1536 * 1024 + 1), jpeg));
  await assertFails(uploadBytes(ref(st, 'chats/event_e5/att1/c.png'), photo(), { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(st, 'chats/event_e5/att1/c.webp'), photo(), { contentType: 'image/webp' }));
  // not a member, or someone else's folder
  await assertFails(uploadBytes(ref(evStorage('v1'), 'chats/event_e5/v1/a.jpg'), photo(), jpeg));
  await assertFails(uploadBytes(ref(evStorage('eh1'), 'chats/event_e5/att1/a.jpg'), photo(), jpeg));
  // no delete, and an existing image cannot be overwritten (`resource == null`)
  await assertFails(deleteObject(ref(st, 'chats/event_e5/att1/ok.jpg')));
  await assertFails(uploadBytes(ref(st, 'chats/event_e5/att1/ok.jpg'), photo(), jpeg));
});
function evStorage(uid) { return env.authenticatedContext(uid).storage(); }

// S02 Discover security rules tests (written, not run locally in CI session)
test('signed-in users read catalog/explore', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'catalog/explore'), { specialties: { portrait: { serviceCount: 1 } } }));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('u1').firestore(), 'catalog/explore')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'catalog/explore')));
});

test('nobody writes catalog/explore', async () => {
  await assertFails(setDoc(doc(env.authenticatedContext('u1').firestore(), 'catalog/explore'), { specialties: {} }));
  await assertFails(updateDoc(doc(env.authenticatedContext('u1').firestore(), 'catalog/explore'), { updatedAt: serverTimestamp() }));
  await assertFails(deleteDoc(doc(env.authenticatedContext('u1').firestore(), 'catalog/explore')));
});

test('a client cannot write stats.nextFreeDate or startingPrice (create and update)', async () => {
  await asPhotographer('p_disc');
  const db = env.authenticatedContext('p_disc').firestore();
  // create with stats.nextFreeDate
  await assertFails(setDoc(doc(db, 'photographers/p_disc'), {
    onboardingComplete: false,
    verified: false,
    specialties: [],
    stats: { nextFreeDate: '2026-10-10' },
  }));
  // create with startingPrice
  await assertFails(setDoc(doc(db, 'photographers/p_disc'), {
    onboardingComplete: false,
    verified: false,
    specialties: [],
    startingPrice: 500000,
  }));
  // valid create
  await assertSucceeds(setDoc(doc(db, 'photographers/p_disc'), {
    onboardingComplete: false,
    verified: false,
    specialties: [],
  }));
  // update with stats.nextFreeDate
  await assertFails(updateDoc(doc(db, 'photographers/p_disc'), {
    'stats.nextFreeDate': '2026-10-10',
  }));
  // update with startingPrice
  await assertFails(updateDoc(doc(db, 'photographers/p_disc'), {
    startingPrice: 500000,
  }));
});

test('a client cannot update likeCount on a post', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'posts/post_disc'), {
      likeCount: 0,
      saveCount: 0,
      authorId: 'u1',
    }));
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(updateDoc(doc(db, 'posts/post_disc'), { likeCount: 5 }));
});

// ---- provider verification (S21, #135) ----

const seedVerification = (uid) => env.withSecurityRulesDisabled(async (c) =>
  setDoc(doc(c.firestore(), `verifications/${uid}`), {
    uid, kind: 'individual', status: 'in_progress', steps: { phone: null, fee: null, identity: null, rules: null },
    version: 1, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));

test('the owner reads verifications/{uid}, another user cannot', async () => {
  await seedVerification('ver1');
  await assertSucceeds(getDoc(doc(env.authenticatedContext('ver1').firestore(), 'verifications/ver1')));
  await assertFails(getDoc(doc(env.authenticatedContext('ver2').firestore(), 'verifications/ver1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'verifications/ver1')));
  await assertFails(getDocs(query(collection(env.authenticatedContext('ver2').firestore(), 'verifications'),
    where('status', '==', 'in_progress'))));
});

test('nobody writes verifications', async () => {
  await seedVerification('ver3');
  const owner = env.authenticatedContext('ver3').firestore();
  await assertFails(updateDoc(doc(owner, 'verifications/ver3'), { status: 'approved' }));
  await assertFails(setDoc(doc(owner, 'verifications/ver3'), { uid: 'ver3', status: 'submitted' }));
  await assertFails(deleteDoc(doc(owner, 'verifications/ver3')));
  await assertFails(setDoc(doc(env.authenticatedContext('ver4').firestore(), 'verifications/ver4'), { uid: 'ver4', status: 'approved' }));
});

// #203: the fee is a server-only payment; the payer can neither read nor forge it, nor record it on the record.
test('the payer cannot read or forge a verification fee payment, its refund or ledger entry, or set steps.fee', async () => {
  await seedVerification('ver6');
  await seedDoc('payments/vfee6', {
    subjectType: 'verification_fee', subjectId: 'ver6', payerId: 'ver6', payeeId: 'platform', amount: 99000,
    status: 'created', escrowStatus: 'held', idempotencyKey: 'vfee_ver6_1_bank_qr',
  });
  await seedDoc('refunds/rvfee6', { paymentId: 'vfee6', subjectType: 'verification_fee', amount: 99000, status: 'pending' });
  await seedDoc('ledger_entries/lvfee6', { type: 'fee_charged', paymentId: 'vfee6', accountOwnerId: 'platform_revenue', amount: 99000 });
  const payer = env.authenticatedContext('ver6').firestore();
  await assertFails(getDoc(doc(payer, 'payments/vfee6')));
  await assertFails(updateDoc(doc(payer, 'payments/vfee6'), { status: 'paid' }));
  await assertFails(setDoc(doc(payer, 'payments/vfee7'), { subjectType: 'verification_fee', subjectId: 'ver6', payerId: 'ver6', status: 'paid' }));
  await assertFails(getDocs(query(collection(payer, 'payments'), where('subjectId', '==', 'ver6'))));
  await assertFails(getDoc(doc(payer, 'refunds/rvfee6')));
  await assertFails(getDoc(doc(payer, 'ledger_entries/lvfee6')));
  await assertFails(updateDoc(doc(payer, 'verifications/ver6'), {
    'steps.fee': { paymentId: 'vfee6', amount: 99000, paidAt: Timestamp.now() },
  }));
});

test('the owner cannot read private/identity but still reads private/contact', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'users/ver5/private/identity'), {
      legalName: 'NGUYỄN MINH TRÍ', dob: '1995-01-01', idNumberEnc: 'v1:a:b:c', idHash: 'h', method: 'vneid', provider: 'fake',
    });
    await setDoc(doc(c.firestore(), contactPath('ver5')), { phone: '+84903123456', phoneVerified: true });
  });
  const owner = env.authenticatedContext('ver5').firestore();
  await assertFails(getDoc(doc(owner, 'users/ver5/private/identity')));
  await assertFails(setDoc(doc(owner, 'users/ver5/private/identity'), { legalName: 'X' }));
  await assertFails(getDoc(doc(env.authenticatedContext('ver6').firestore(), 'users/ver5/private/identity')));
  await assertSucceeds(getDoc(doc(owner, contactPath('ver5'))));
});

test('identity_hashes, verificationAudit, fake_identities are closed', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'identity_hashes/h1'), { uid: 'ver7', createdAt: Timestamp.now() });
    await setDoc(doc(c.firestore(), 'verificationAudit/a1'), { uid: 'ver7', target: 'identity', action: 'approve', actorId: 'staff' });
    await setDoc(doc(c.firestore(), 'fake_identities/ver7'), { dob: '2010-05-01' });
  });
  const owner = env.authenticatedContext('ver7').firestore();
  const staff = env.authenticatedContext('staff', { staffRole: 'admin' }).firestore();
  for (const path of ['identity_hashes/h1', 'verificationAudit/a1', 'fake_identities/ver7']) {
    await assertFails(getDoc(doc(owner, path)));
    await assertFails(getDoc(doc(staff, path)));
    await assertFails(setDoc(doc(owner, path), { uid: 'ver7' }));
  }
  await assertFails(setDoc(doc(owner, 'identity_hashes/h2'), { uid: 'ver7' }));
  await assertFails(setDoc(doc(owner, 'fake_identities/ver7'), { dob: '1990-01-01' }, { merge: true }));
});

test('a client cannot set businessVerified on photographers', async () => {
  await asPhotographer('bv1'); await asPhotographer('bv2');
  const db = env.authenticatedContext('bv1').firestore();
  await assertFails(setDoc(doc(db, 'photographers/bv1'), { onboardingComplete: false, verified: false, businessVerified: true }));
  await assertFails(setDoc(doc(db, 'photographers/bv1'), { onboardingComplete: false, verified: false, businessVerified: false }));
  await assertSucceeds(setDoc(doc(db, 'photographers/bv1'), { onboardingComplete: false, verified: false }));
  await assertFails(updateDoc(doc(db, 'photographers/bv1'), { businessVerified: true }));
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'photographers/bv2'), { onboardingComplete: true, verified: true, businessVerified: true, bio: 'x' }));
  const owner2 = env.authenticatedContext('bv2').firestore();
  await assertFails(updateDoc(doc(owner2, 'photographers/bv2'), { businessVerified: false }));
  await assertFails(updateDoc(doc(owner2, 'photographers/bv2'), { businessVerified: deleteField() }));
  await assertSucceeds(updateDoc(doc(owner2, 'photographers/bv2'), { bio: 'y' }));
});

test('a client cannot set phoneVerified true on private/contact', async () => {
  const db = env.authenticatedContext('pv1').firestore();
  await assertFails(setDoc(doc(db, contactPath('pv1')), { phone: '+84903123456', phoneVerified: true }));
  await assertSucceeds(setDoc(doc(db, contactPath('pv1')), { phone: '+84903123456', phoneVerified: false }));
  await assertFails(updateDoc(doc(db, contactPath('pv1')), { phoneVerified: true }));
  await assertFails(setDoc(doc(db, contactPath('pv1')), { phone: '+84903123456', phoneVerified: true }, { merge: true }));
});

test('the owner uploads a business photo once, cannot overwrite, others cannot read', async () => {
  const st = env.authenticatedContext('bd1').storage();
  const own = ref(st, 'businessDocs/bd1/01JBUSINESS.jpg');
  await assertSucceeds(uploadBytes(own, photo(), jpeg));
  await assertSucceeds(getBytes(own));
  await assertFails(uploadBytes(own, photo(), jpeg));
  await assertFails(deleteObject(own));
  await assertFails(getBytes(ref(env.authenticatedContext('bd2').storage(), 'businessDocs/bd1/01JBUSINESS.jpg')));
  await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), 'businessDocs/bd1/01JBUSINESS.jpg')));
  await assertFails(uploadBytes(ref(env.authenticatedContext('bd2').storage(), 'businessDocs/bd1/other.jpg'), photo(), jpeg));
  await assertSucceeds(uploadBytes(ref(st, 'businessDocs/bd1/max.jpg'), photo(3 * 1024 * 1024), jpeg));
  await assertFails(uploadBytes(ref(st, 'businessDocs/bd1/big.jpg'), photo(3 * 1024 * 1024 + 1), jpeg));
  await assertFails(uploadBytes(ref(st, 'businessDocs/bd1/a.png'), photo(), { contentType: 'image/png' }));
  await assertFails(uploadBytes(ref(st, 'businessDocs/bd1/a.pdf'), photo(), { contentType: 'application/pdf' }));
});

// ---- S18 support threads (#204) ----

test('a user gets their missing help thread (no error)', async () => {
  const db = env.authenticatedContext('u1').firestore();
  // Document does not exist, getDoc should succeed (returning exists === false)
  const snap = await assertSucceeds(getDoc(doc(db, 'support_threads/help_u1')));
  assert.equal(snap.exists(), false);
});

test('a user cannot get another users help thread', async () => {
  const db = env.authenticatedContext('u2').firestore();
  await assertFails(getDoc(doc(db, 'support_threads/help_u1')));
});

test('nobody writes support threads or messages from the client', async () => {
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(setDoc(doc(db, 'support_threads/help_u1'), { kind: 'help' }));
  await assertFails(setDoc(doc(db, 'support_threads/help_u1/messages/m1'), { body: 'hack' }));
});

test('a participant reads the threads messages, a third user cannot', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'support_threads/help_u1'), {
      id: 'help_u1',
      kind: 'help',
      participants: ['u1'],
      status: 'open',
    });
    await setDoc(doc(c.firestore(), 'support_threads/help_u1/messages/m1'), {
      id: 'm1',
      threadId: 'help_u1',
      body: 'Xin chao',
      senderRole: 'user',
    });
  });

  const participantDb = env.authenticatedContext('u1').firestore();
  await assertSucceeds(getDoc(doc(participantDb, 'support_threads/help_u1/messages/m1')));

  const thirdPartyDb = env.authenticatedContext('u3').firestore();
  await assertFails(getDoc(doc(thirdPartyDb, 'support_threads/help_u1/messages/m1')));
});

// ---- photographers/{uid}/addons (S08.06, #190) ----
const addonPath = (uid, id) => `photographers/${uid}/addons/${id}`;
const addonDoc = (o = {}) => ({
  kind: 'makeup', name: 'Trang điểm', price: 800000, unit: 'per_person', maxQty: 4,
  serviceIds: [], active: true, ...o,
});
const seedAddons = (uid) => env.withSecurityRulesDisabled(async (c) => {
  const f = c.firestore();
  await setDoc(doc(f, addonPath(uid, 'on')), addonDoc());
  await setDoc(doc(f, addonPath(uid, 'off')), addonDoc({ name: 'Chỉnh thêm ảnh', active: false }));
});

test('a signed-in customer reads an active add-on', async () => {
  await asPhotographer('ad1'); await seedAddons('ad1');
  const db = env.authenticatedContext('cust-ad1').firestore();
  await assertSucceeds(getDoc(doc(db, addonPath('ad1', 'on'))));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), addonPath('ad1', 'on'))));
});

test("a customer cannot read another provider's inactive add-on", async () => {
  await asPhotographer('ad2'); await seedAddons('ad2');
  const db = env.authenticatedContext('cust-ad2').firestore();
  await assertFails(getDoc(doc(db, addonPath('ad2', 'off'))));
});

test('the owner reads their inactive add-on', async () => {
  await asPhotographer('ad3'); await seedAddons('ad3');
  const db = env.authenticatedContext('ad3').firestore();
  await assertSucceeds(getDoc(doc(db, addonPath('ad3', 'off'))));
});

test('a customer list query filtered by active == true succeeds; unfiltered fails', async () => {
  await asPhotographer('ad4'); await seedAddons('ad4');
  const db = env.authenticatedContext('cust-ad4').firestore();
  const col = collection(db, `photographers/ad4/addons`);
  await assertSucceeds(getDocs(query(col, where('active', '==', true))));
  await assertFails(getDocs(col));
});

test('the owner cannot create, update or delete an add-on directly', async () => {
  await asPhotographer('ad5'); await seedAddons('ad5');
  const db = env.authenticatedContext('ad5').firestore();
  await assertFails(setDoc(doc(db, addonPath('ad5', 'new')), addonDoc()));
  await assertFails(updateDoc(doc(db, addonPath('ad5', 'on')), { price: 900000 }));
  await assertFails(deleteDoc(doc(db, addonPath('ad5', 'on'))));
});

test('nobody writes private/addons from a client; the owner reads it', async () => {
  await asPhotographer('ad6');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'photographers/ad6/private/addons'), { activeCount: 1, updatedAt: Timestamp.now() }));
  const db = env.authenticatedContext('ad6').firestore();
  await assertFails(setDoc(doc(db, 'photographers/ad6/private/addons'), { activeCount: 0 }));
  await assertFails(updateDoc(doc(db, 'photographers/ad6/private/addons'), { activeCount: 0 }));
  await assertFails(deleteDoc(doc(db, 'photographers/ad6/private/addons')));
  await assertSucceeds(getDoc(doc(db, 'photographers/ad6/private/addons')));
  await assertFails(getDoc(doc(env.authenticatedContext('cust-ad6').firestore(), 'photographers/ad6/private/addons')));
});

test('a third user cannot read a booking that has a pickup', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'bookings/bk-pickup'), {
      customerId: 'u-pk1', photographerId: 'u-pk2', status: 'requested',
      addons: [{ addonId: 'a1', kind: 'transport', name: 'Xe đón', unit: 'per_booking', unitPrice: 300000, qty: 1, amount: 300000 }],
      pickup: { name: '12 Lê Lợi, Quận 1' },
    }));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('u-pk1').firestore(), 'bookings/bk-pickup')));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('u-pk2').firestore(), 'bookings/bk-pickup')));
  await assertFails(getDoc(doc(env.authenticatedContext('u-pk3').firestore(), 'bookings/bk-pickup')));
});

// S20: Blocks and Reports security rules
test('a user lists their own blocks', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'blocks/u1_u2'), { blockerId: 'u1', blockedId: 'u2' });
  });
  const db = env.authenticatedContext('u1').firestore();
  await assertSucceeds(getDoc(doc(db, 'blocks/u1_u2')));
  const col = collection(db, 'blocks');
  await assertSucceeds(getDocs(query(col, where('blockerId', '==', 'u1'))));
});

test('a user cannot read blocks made by others (including against them)', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'blocks/u1_u2'), { blockerId: 'u1', blockedId: 'u2' });
  });
  const db = env.authenticatedContext('u2').firestore();
  await assertFails(getDoc(doc(db, 'blocks/u1_u2')));
  const db3 = env.authenticatedContext('u3').firestore();
  await assertFails(getDoc(doc(db3, 'blocks/u1_u2')));
});

test('nobody reads or writes reports from client', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'reports/rep_1'), { reporterId: 'u1', status: 'open' });
  });
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(getDoc(doc(db, 'reports/rep_1')));
  await assertFails(setDoc(doc(db, 'reports/rep_2'), { reporterId: 'u1', status: 'open' }));
  await assertFails(updateDoc(doc(db, 'reports/rep_1'), { status: 'dismissed' }));
  await assertFails(deleteDoc(doc(db, 'reports/rep_1')));
});

test('the owner reads private/blocks but cannot write it', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'users/u1/private/blocks'), { blockedIds: ['u2'], blockedByIds: [] });
  });
  const db1 = env.authenticatedContext('u1').firestore();
  await assertSucceeds(getDoc(doc(db1, 'users/u1/private/blocks')));
  await assertFails(setDoc(doc(db1, 'users/u1/private/blocks'), { blockedIds: [] }));
  await assertFails(updateDoc(doc(db1, 'users/u1/private/blocks'), { blockedIds: [] }));

  const db2 = env.authenticatedContext('u2').firestore();
  await assertFails(getDoc(doc(db2, 'users/u1/private/blocks')));
});

test('a client cannot write private/report_quota', async () => {
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(setDoc(doc(db, 'users/u1/private/report_quota'), { day: '2026-10-07', count: 0 }));
});

test('a chat member cannot set blockedAt', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'chats/u1_u2'), { members: ['u1', 'u2'], kind: 'inquiry' });
  });
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(updateDoc(doc(db, 'chats/u1_u2'), { blockedAt: Timestamp.now() }));
});

// ---- S22 Account Deletion & Data Export (#205) ----
test('client cannot read or write account_deletions', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'account_deletions/u1'), { uid: 'u1', status: 'pending' });
  });
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(getDoc(doc(db, 'account_deletions/u1')));
  await assertFails(setDoc(doc(db, 'account_deletions/u2'), { uid: 'u2', status: 'pending' }));
  await assertFails(updateDoc(doc(db, 'account_deletions/u1'), { status: 'restored' }));
  await assertFails(deleteDoc(doc(db, 'account_deletions/u1')));
});

test('client cannot set deleted on users/{uid}', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'users/u1'), { displayName: 'User One', role: 'customer' });
  });
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(updateDoc(doc(db, 'users/u1'), { deleted: true }));
  await assertFails(updateDoc(doc(db, 'users/u1'), { accountStatus: 'deletion_pending' }));
  await assertFails(updateDoc(doc(db, 'users/u1'), { restoreUntil: '2026-11-20T10:00:00Z' }));
});

test('owner can set hiddenFromDiscovery to a bool, not a string', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'users/p1'), { displayName: 'Photographer', role: 'photographer' });
    await setDoc(doc(c.firestore(), 'photographers/p1'), {
      bio: 'Bio',
      onboardingComplete: true,
      verified: false,
    });
  });
  const db = env.authenticatedContext('p1').firestore();
  await assertSucceeds(updateDoc(doc(db, 'photographers/p1'), { hiddenFromDiscovery: true }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/p1'), { hiddenFromDiscovery: false }));
  await assertFails(updateDoc(doc(db, 'photographers/p1'), { hiddenFromDiscovery: 'true' }));
  await assertFails(updateDoc(doc(db, 'photographers/p1'), { deletionPending: true }));
});

// ---- S26 #136: studio members, quota, day load, assignee reads, server fields on photographers ----
const studioRel = (studioId, memberId, status = 'invited') => ({
  studioId, memberId, status, initiatedBy: 'studio', createdAt: Timestamp.fromDate(new Date('2026-10-10T03:00:00Z')),
  expiresAt: Timestamp.fromDate(new Date('2026-10-17T03:00:00Z')), expiringNotifiedAt: null, version: 1,
});
test('the studio and the member read their relation; a third user cannot', async () => {
  await seedDoc('studio_members/sm_s1_m1_1', studioRel('sm_s1', 'sm_m1'));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('sm_s1').firestore(), 'studio_members/sm_s1_m1_1')));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('sm_m1').firestore(), 'studio_members/sm_s1_m1_1')));
  await assertFails(getDoc(doc(env.authenticatedContext('sm_x').firestore(), 'studio_members/sm_s1_m1_1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'studio_members/sm_s1_m1_1')));
  // The app's listeners: the studio's own relations and the member's own; never someone else's.
  await assertSucceeds(getDocs(query(collection(env.authenticatedContext('sm_s1').firestore(), 'studio_members'), where('studioId', '==', 'sm_s1'))));
  await assertSucceeds(getDocs(query(collection(env.authenticatedContext('sm_m1').firestore(), 'studio_members'), where('memberId', '==', 'sm_m1'))));
  await assertFails(getDocs(query(collection(env.authenticatedContext('sm_x').firestore(), 'studio_members'), where('studioId', '==', 'sm_s1'))));
});
test('nobody writes studio_members or studio_quota; studio_day_load is closed', async () => {
  const studio = env.authenticatedContext('sm_s2').firestore();
  const member = env.authenticatedContext('sm_m2').firestore();
  await assertFails(setDoc(doc(studio, 'studio_members/sm_s2_m2_1'), studioRel('sm_s2', 'sm_m2')));
  await assertFails(setDoc(doc(member, 'studio_members/sm_s2_m2_2'), { ...studioRel('sm_s2', 'sm_m2', 'active') }));
  await seedDoc('studio_members/sm_s2_m2_3', studioRel('sm_s2', 'sm_m2'));
  await assertFails(updateDoc(doc(member, 'studio_members/sm_s2_m2_3'), { status: 'active' }));
  await assertFails(deleteDoc(doc(studio, 'studio_members/sm_s2_m2_3')));
  await assertFails(setDoc(doc(studio, 'studio_quota/sm_s2'), { dayKey: '2026-10-10', studioActions: 0, memberActions: 0 }));
  await seedDoc('studio_day_load/sm_s2_2026-10-14', { studioId: 'sm_s2', day: '2026-10-14', unassignedIds: ['b1'], assignedIds: [] });
  await assertFails(getDoc(doc(studio, 'studio_day_load/sm_s2_2026-10-14')));
  await assertFails(setDoc(doc(studio, 'studio_day_load/sm_s2_2026-10-15'), { unassignedIds: [] }));
});
test('the owner reads their quota; nobody else does', async () => {
  await seedDoc('studio_quota/sm_s3', { dayKey: '2026-10-10', studioActions: 2, memberActions: 0 });
  await assertSucceeds(getDoc(doc(env.authenticatedContext('sm_s3').firestore(), 'studio_quota/sm_s3')));
  await assertFails(getDoc(doc(env.authenticatedContext('sm_m3').firestore(), 'studio_quota/sm_s3')));
});
test('the assignee reads the booking and its events', async () => {
  await seedDoc('bookings/b_sa1', { customerId: 'sac1', photographerId: 'sas1', assigneeId: 'sam1', isStudio: true, status: 'upcoming' });
  await seedDoc('bookings/b_sa1/events/e1', { status: 'upcoming', at: Timestamp.now() });
  const db = env.authenticatedContext('sam1').firestore();
  await assertSucceeds(getDoc(doc(db, 'bookings/b_sa1')));
  await assertSucceeds(getDoc(doc(db, 'bookings/b_sa1/events/e1')));
  await assertSucceeds(getDocs(collection(db, 'bookings/b_sa1/events')));
  // Another member of the studio does not.
  await assertFails(getDoc(doc(env.authenticatedContext('sam2').firestore(), 'bookings/b_sa1/events/e1')));
  // Deliveries stay the studio's.
  await seedDoc('bookings/b_sa1/deliverySamples/f1', { path: 'x' });
  await assertFails(getDoc(doc(db, 'bookings/b_sa1/deliverySamples/f1')));
});
test('a former assignee cannot read the booking, its events or the booking chat', async () => {
  await seedDoc('bookings/b_sa2', { customerId: 'sac1', photographerId: 'sas1', assigneeId: 'sam2', isStudio: true, status: 'upcoming' });
  await seedDoc('bookings/b_sa2/events/e1', { status: 'upcoming', at: Timestamp.now() });
  await seedDoc('chats/sac1_sas1', { kind: 'booking', customerId: 'sac1', photographerId: 'sas1', assigneeId: 'sam2', members: ['sac1', 'sas1', 'sam2'] });
  await seedDoc('chats/sac1_sas1/messages/m1', { senderId: 'sac1', type: 'text', body: 'Xin chào' });
  const old = env.authenticatedContext('sam1').firestore();
  await assertFails(getDoc(doc(old, 'bookings/b_sa2')));
  await assertFails(getDoc(doc(old, 'bookings/b_sa2/events/e1')));
  await assertFails(getDoc(doc(old, 'chats/sac1_sas1')));
  await assertFails(getDoc(doc(old, 'chats/sac1_sas1/messages/m1')));
  // The chat accepts three members: the new assignee reads it and its messages.
  const now = env.authenticatedContext('sam2').firestore();
  await assertSucceeds(getDoc(doc(now, 'chats/sac1_sas1')));
  await assertSucceeds(getDoc(doc(now, 'chats/sac1_sas1/messages/m1')));
});
test('the assignee reads the customer contact only while unlocked', async () => {
  await seedDoc('bookings/b_sa3', { customerId: 'sac1', photographerId: 'sas1', assigneeId: 'sam3', isStudio: true, status: 'accepted' });
  await seedDoc('bookings/b_sa3/private/contact', { name: 'Lan', phone: '+84903000001' });
  await seedDoc('bookings/b_sa4', { customerId: 'sac1', photographerId: 'sas1', assigneeId: 'sam3', isStudio: true, status: 'cancelled' });
  await seedDoc('bookings/b_sa4/private/contact', { name: 'Lan', phone: '+84903000001' });
  const db = env.authenticatedContext('sam3').firestore();
  await assertSucceeds(getDoc(doc(db, 'bookings/b_sa3/private/contact')));
  await assertFails(getDoc(doc(db, 'bookings/b_sa4/private/contact')));
  await assertFails(getDoc(doc(env.authenticatedContext('sam4').firestore(), 'bookings/b_sa3/private/contact')));
  // The delivery document stays the studio's and the customer's.
  await seedDoc('bookings/b_sa3/private/delivery', { url: 'https://x' });
  await assertFails(getDoc(doc(db, 'bookings/b_sa3/private/delivery')));
});
test('a client cannot set studioId, memberCount, assignableMembers, nameKey or the counters on photographers', async () => {
  await asPhotographer('sp1');
  await seedDoc('photographers/sp1', { onboardingComplete: true, verified: false, bio: 'x' });
  const db = env.authenticatedContext('sp1').firestore();
  for (const field of ['studioId', 'studioJoinedAt', 'studioCooldownUntil', 'memberCount', 'lateAssignCount',
    'changeDeclinedCount', 'lateReassignCount', 'lateDeliveryCount', 'nameKey', 'assignableMembers']) {
    await assertFails(updateDoc(doc(db, 'photographers/sp1'), { [field]: field === 'studioId' || field === 'nameKey' ? 'x' : 1 }));
  }
  await assertSucceeds(updateDoc(doc(db, 'photographers/sp1'), { bio: 'y' }));
  // A server-written value stays when the client saves other fields.
  await seedDoc('photographers/sp1', { onboardingComplete: true, verified: false, bio: 'y', studioId: 'sas1', nameKey: 'sp1', memberCount: 0 });
  await assertSucceeds(updateDoc(doc(db, 'photographers/sp1'), { bio: 'z' }));
  await assertFails(updateDoc(doc(db, 'photographers/sp1'), { studioId: null }));
});
test("a studio's full day is server-written; the owner may only turn it off", async () => {
  await asPhotographer('sfs1');
  await seedDoc('availability/sfs1/days/2026-10-14', { state: 'full' });
  const db = env.authenticatedContext('sfs1').firestore();
  await assertFails(setDoc(doc(db, 'availability/sfs1/days/2026-10-15'), { state: 'full' }));
  await assertFails(deleteDoc(doc(db, 'availability/sfs1/days/2026-10-14')));
  await assertFails(setDoc(doc(db, 'availability/sfs1/days/2026-10-14'), { state: 'booked', bookingId: 'x' }));
  await assertFails(setDoc(doc(db, 'availability/sfs1/days/2026-10-14'), { state: 'off', note: 'x' }));
  await assertFails(setDoc(doc(env.authenticatedContext('sfs2').firestore(), 'availability/sfs1/days/2026-10-14'), { state: 'off' }));
  await assertSucceeds(setDoc(doc(db, 'availability/sfs1/days/2026-10-14'), { state: 'off', updatedAt: serverTimestamp() }));
  // A booked day stays server-only.
  await seedDoc('availability/sfs1/days/2026-10-16', { state: 'booked', bookingId: 'b1' });
  await assertFails(setDoc(doc(db, 'availability/sfs1/days/2026-10-16'), { state: 'off' }));
});

// S29 Trending Spots security rules tests (written, not run locally in CI session)
test('a signed-in user reads spots, spot_rankings, spot_directory and spot_days; a signed-out user reads none', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'spots/spot1'), { name: 'Spot 1' });
    await setDoc(doc(f, 'spot_rankings/r1'), { rank: 1 });
    await setDoc(doc(f, 'spot_directory/dir1'), { name: 'Dir 1' });
    await setDoc(doc(f, 'spot_days/sd1'), { date: '2026-10-15' });
  });
  const authDb = env.authenticatedContext('u1').firestore();
  const unauthDb = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(authDb, 'spots/spot1')));
  await assertSucceeds(getDoc(doc(authDb, 'spot_rankings/r1')));
  await assertSucceeds(getDoc(doc(authDb, 'spot_directory/dir1')));
  await assertSucceeds(getDoc(doc(authDb, 'spot_days/sd1')));

  await assertFails(getDoc(doc(unauthDb, 'spots/spot1')));
  await assertFails(getDoc(doc(unauthDb, 'spot_rankings/r1')));
  await assertFails(getDoc(doc(unauthDb, 'spot_directory/dir1')));
  await assertFails(getDoc(doc(unauthDb, 'spot_days/sd1')));
});

test('nobody writes spots, spot_rankings, spot_directory, spot_schedules, spot_slot_offers or spot_days from a client', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'spots/sp_w'), { name: 'Spot' });
    await setDoc(doc(f, 'spot_rankings/rk_w'), { rank: 1 });
    await setDoc(doc(f, 'spot_directory/dir_w'), { name: 'Dir' });
    await setDoc(doc(f, 'spot_schedules/sch_w'), { status: 'open', providerId: 'u1' });
    await setDoc(doc(f, 'spot_slot_offers/off_w'), { status: 'open', providerId: 'u1' });
    await setDoc(doc(f, 'spot_days/day_w'), { date: '2026-10-15' });
  });
  const db = env.authenticatedContext('u1').firestore();
  // create
  await assertFails(setDoc(doc(db, 'spots/sp_new'), { name: 'New' }));
  await assertFails(setDoc(doc(db, 'spot_rankings/rk_new'), { rank: 2 }));
  await assertFails(setDoc(doc(db, 'spot_directory/dir_new'), { name: 'New' }));
  await assertFails(setDoc(doc(db, 'spot_schedules/sch_new'), { status: 'open' }));
  await assertFails(setDoc(doc(db, 'spot_slot_offers/off_new'), { status: 'open' }));
  await assertFails(setDoc(doc(db, 'spot_days/day_new'), { date: '2026-10-16' }));
  // update
  await assertFails(updateDoc(doc(db, 'spots/sp_w'), { name: 'Changed' }));
  await assertFails(updateDoc(doc(db, 'spot_rankings/rk_w'), { rank: 2 }));
  await assertFails(updateDoc(doc(db, 'spot_directory/dir_w'), { name: 'Changed' }));
  await assertFails(updateDoc(doc(db, 'spot_schedules/sch_w'), { status: 'cancelled' }));
  await assertFails(updateDoc(doc(db, 'spot_slot_offers/off_w'), { status: 'closed' }));
  await assertFails(updateDoc(doc(db, 'spot_days/day_w'), { date: '2026-10-17' }));
  // delete
  await assertFails(deleteDoc(doc(db, 'spots/sp_w')));
  await assertFails(deleteDoc(doc(db, 'spot_rankings/rk_w')));
  await assertFails(deleteDoc(doc(db, 'spot_directory/dir_w')));
  await assertFails(deleteDoc(doc(db, 'spot_schedules/sch_w')));
  await assertFails(deleteDoc(doc(db, 'spot_slot_offers/off_w')));
  await assertFails(deleteDoc(doc(db, 'spot_days/day_w')));
});

test('a customer reads an open schedule and cannot read a cancelled one', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'spot_schedules/sch_open'), { status: 'open', providerId: 'prov1', assigneeId: 'asg1' });
    await setDoc(doc(f, 'spot_schedules/sch_cancelled'), { status: 'cancelled', providerId: 'prov1', assigneeId: 'asg1' });
  });
  const db = env.authenticatedContext('cust1').firestore();
  await assertSucceeds(getDoc(doc(db, 'spot_schedules/sch_open')));
  await assertFails(getDoc(doc(db, 'spot_schedules/sch_cancelled')));
});

test('the provider and the assignee read their cancelled schedule', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'spot_schedules/sch_canc_2'), {
      status: 'cancelled',
      providerId: 'prov2',
      assigneeId: 'asg2',
    });
  });
  const provDb = env.authenticatedContext('prov2').firestore();
  const asgDb = env.authenticatedContext('asg2').firestore();
  const otherDb = env.authenticatedContext('other_u').firestore();
  await assertSucceeds(getDoc(doc(provDb, 'spot_schedules/sch_canc_2')));
  await assertSucceeds(getDoc(doc(asgDb, 'spot_schedules/sch_canc_2')));
  await assertFails(getDoc(doc(otherDb, 'spot_schedules/sch_canc_2')));
});

test('a customer list query on spot_schedules filtered by status == open succeeds; unfiltered fails', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'spot_schedules/sch_q1'), {
      status: 'open',
      providerId: 'prov_q',
    });
  });
  const db = env.authenticatedContext('cust_q').firestore();
  await assertSucceeds(getDocs(query(collection(db, 'spot_schedules'), where('status', '==', 'open'))));
  await assertFails(getDocs(collection(db, 'spot_schedules')));
});

test('a customer reads an open offer, not a closed one; the provider reads a closed one', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    const f = c.firestore();
    await setDoc(doc(f, 'spot_slot_offers/off_open'), { status: 'open', providerId: 'prov_off' });
    await setDoc(doc(f, 'spot_slot_offers/off_closed'), { status: 'closed', providerId: 'prov_off' });
  });
  const custDb = env.authenticatedContext('cust_off').firestore();
  const provDb = env.authenticatedContext('prov_off').firestore();
  await assertSucceeds(getDoc(doc(custDb, 'spot_slot_offers/off_open')));
  await assertFails(getDoc(doc(custDb, 'spot_slot_offers/off_closed')));
  await assertSucceeds(getDoc(doc(provDb, 'spot_slot_offers/off_closed')));
});

test('the owner cannot create or delete a spot availability day (only off)', async () => {
  await asPhotographer('spot_p1');
  const db = env.authenticatedContext('spot_p1').firestore();
  const day = dayPath('spot_p1', '2026-10-20');
  await assertFails(setDoc(doc(db, day), { state: 'spot', scheduleId: 'sch1', spotId: 'sp1', updatedAt: serverTimestamp() }));
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), day), { state: 'spot', scheduleId: 'sch1', spotId: 'sp1' }));
  await assertFails(deleteDoc(doc(db, day)));
  await assertFails(setDoc(doc(db, day), { state: 'off' }));
});

test('spots storage: a signed-in user reads spots/x/card.jpg; nobody uploads there', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    await uploadBytes(ref(c.storage(), 'spots/sp1/card.jpg'), photo(), jpeg);
  });
  const authSt = env.authenticatedContext('u1').storage();
  const unauthSt = env.unauthenticatedContext().storage();
  await assertSucceeds(getBytes(ref(authSt, 'spots/sp1/card.jpg')));
  await assertFails(getBytes(ref(unauthSt, 'spots/sp1/card.jpg')));
  await assertFails(uploadBytes(ref(authSt, 'spots/sp1/card.jpg'), photo(), jpeg));
  await assertFails(deleteObject(ref(authSt, 'spots/sp1/card.jpg')));
});

// ---- Chụp ngay (S13–S14, #140): presence, requests, contact copy, offers, tracks ----
describe('instant', () => {
  const seed = (path, data) => env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), path), data));
  const ago = (s) => Timestamp.fromMillis(Date.now() - s * 1000);
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const presence = (over = {}) => ({
    online: true, helpReady: false, priceListVersion: 1, cityId: 'hcm',
    lat: 10.7746, lng: 106.6924, accuracyM: 20, geohash5: 'w3gv2', geohash4: 'w3gv', heartbeatAt: ago(120),
    activeRequestId: null, pendingOffers: [], reliability: { offers: 0, accepted: 0, declined: 0, expired: 0, cancelled: 0, late: 0, noShow: 0 },
    profile: { name: 'Hà' }, updatedAt: ago(120), ...over,
  });
  const beat = (over = {}) => ({ lat: 10.775, lng: 106.693, accuracyM: 15, geohash5: 'w3gv2', geohash4: 'w3gv', heartbeatAt: serverTimestamp(), ...over });
  const request = (over = {}) => ({
    customerId: 'ic_cust', photographerId: 'ic_ph', status: 'assigned', active: true, paidAt: null,
    meetPoint: { lat: 10.7746, lng: 106.6924, name: 'Cổng Trương Định' }, offers: [], ...over,
  });
  const track = (over = {}) => ({
    customerId: 'ic_cust', photographerId: 'ic_ph', active: true, lat: 10.77, lng: 106.69, accuracyM: 20, heading: null, at: ago(30), ...over,
  });
  const point = (over = {}) => ({ lat: 10.771, lng: 106.691, accuracyM: 12, heading: 90, at: serverTimestamp(), ...over });

  test('signed-in user reads instant_config', async () => {
    await seed('instant_config/current', { enabled: true, priceListVersion: 1, platformFeeBp: 0 });
    await assertSucceeds(getDoc(doc(as('ic_any'), 'instant_config/current')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'instant_config/current')));
  });

  test('nobody writes instant_config', async () => {
    await assertFails(setDoc(doc(as('ic_any'), 'instant_config/current'), { enabled: false }));
    await assertFails(updateDoc(doc(as('ic_any'), 'instant_config/current'), { platformFeeBp: 9999 }));
  });

  test('owner reads own presence, others cannot', async () => {
    await seed('instant_presence/ip_own', presence());
    await assertSucceeds(getDoc(doc(as('ip_own'), 'instant_presence/ip_own')));
    await assertFails(getDoc(doc(as('ic_cust'), 'instant_presence/ip_own')));
    await assertFails(getDocs(query(collection(as('ic_cust'), 'instant_presence'), where('online', '==', true))));
  });

  test('owner heartbeat with request.time passes', async () => {
    await seed('instant_presence/ip_hb', presence());
    await assertSucceeds(updateDoc(doc(as('ip_hb'), 'instant_presence/ip_hb'), beat()));
  });

  test('heartbeat within 60 s is denied', async () => {
    await seed('instant_presence/ip_fast', presence({ heartbeatAt: ago(20) }));
    await assertFails(updateDoc(doc(as('ip_fast'), 'instant_presence/ip_fast'), beat()));
  });

  test('a heartbeat with a client-chosen time or a bad position is denied', async () => {
    await seed('instant_presence/ip_bad', presence());
    const ref = doc(as('ip_bad'), 'instant_presence/ip_bad');
    await assertFails(updateDoc(ref, beat({ heartbeatAt: Timestamp.now() })));
    await assertFails(updateDoc(ref, beat({ lat: 91 })));
    await assertFails(updateDoc(ref, beat({ geohash5: 'w3gv' })));
    await assertFails(updateDoc(ref, beat({ geohash4: 'w3gx' })));
    await assertFails(updateDoc(ref, beat({ geohash5: 'w3gva', geohash4: 'w3gv' }))); // 'a' is not base32
    await assertSucceeds(updateDoc(ref, beat()));
  });

  test('owner cannot switch online by writing', async () => {
    await seed('instant_presence/ip_on', presence({ online: false }));
    await assertFails(updateDoc(doc(as('ip_on'), 'instant_presence/ip_on'), { online: true }));
    await seed('instant_presence/ip_off', presence());
    await assertFails(updateDoc(doc(as('ip_off'), 'instant_presence/ip_off'), { ...beat(), online: false }));
  });

  test('owner cannot write activeRequestId, pendingOffers, cityId or priceListVersion', async () => {
    await seed('instant_presence/ip_keys', presence({ pendingOffers: [{ offerId: 'of1', requestId: 'ir_x', expiresAt: ago(-30) }] }));
    const ref = doc(as('ip_keys'), 'instant_presence/ip_keys');
    await assertFails(updateDoc(ref, { ...beat(), activeRequestId: 'ir_x' }));
    await assertFails(updateDoc(ref, { ...beat(), pendingOffers: [] }));
    await assertFails(updateDoc(ref, { ...beat(), reliability: { offers: 0 } }));
    await assertFails(updateDoc(ref, { ...beat(), cityId: 'hn' }));
    await assertFails(updateDoc(ref, { ...beat(), priceListVersion: 2 }));
    await assertFails(setDoc(doc(as('ip_new'), 'instant_presence/ip_new'), presence()));
    await assertFails(deleteDoc(ref));
  });

  test('heartbeat on an offline presence is denied', async () => {
    await seed('instant_presence/ip_offline', presence({ online: false }));
    await assertFails(updateDoc(doc(as('ip_offline'), 'instant_presence/ip_offline'), beat()));
  });

  test('customer reads own request; assigned photographer reads it', async () => {
    await seed('instant_requests/ir_read', request());
    await assertSucceeds(getDoc(doc(as('ic_cust'), 'instant_requests/ir_read')));
    await assertSucceeds(getDoc(doc(as('ic_ph'), 'instant_requests/ir_read')));
    await assertSucceeds(getDocs(query(collection(as('ic_cust'), 'instant_requests'), where('customerId', '==', 'ic_cust'), where('active', '==', true))));
    await assertSucceeds(getDocs(query(collection(as('ic_ph'), 'instant_requests'), where('photographerId', '==', 'ic_ph'), where('active', '==', true))));
    await assertFails(getDocs(query(collection(as('ic_cust'), 'instant_requests'), where('active', '==', true))));
  });

  test('an invited photographer cannot read the request', async () => {
    await seed('instant_requests/ir_inv', request({ status: 'searching', photographerId: null,
      offers: [{ offerId: 'of1', photographerId: 'ic_invited', outcome: 'pending' }] }));
    await assertFails(getDoc(doc(as('ic_invited'), 'instant_requests/ir_inv')));
    await assertFails(getDoc(doc(as('ic_stranger'), 'instant_requests/ir_inv')));
  });

  test('nobody writes a request', async () => {
    await seed('instant_requests/ir_w', request());
    await assertFails(updateDoc(doc(as('ic_cust'), 'instant_requests/ir_w'), { status: 'completed' }));
    await assertFails(updateDoc(doc(as('ic_ph'), 'instant_requests/ir_w'), { status: 'arrived' }));
    await assertFails(setDoc(doc(as('ic_cust'), 'instant_requests/ir_new'), request()));
    await assertFails(deleteDoc(doc(as('ic_cust'), 'instant_requests/ir_w')));
  });

  test('assigned photographer reads the contact copy while active', async () => {
    await seed('instant_requests/ir_c', request({ paidAt: ago(300) }));
    await seed('instant_requests/ir_c/private/contact', { name: 'Lan', phone: '+84903123456', allowZalo: true, allowWhatsApp: false });
    await assertSucceeds(getDoc(doc(as('ic_ph'), 'instant_requests/ir_c/private/contact')));
    await assertFails(setDoc(doc(as('ic_ph'), 'instant_requests/ir_c/private/contact'), { phone: '+84900000000' }));
    await seed('instant_requests/ir_c', request({ paidAt: ago(300), status: 'completed', active: false }));
    await assertFails(getDoc(doc(as('ic_ph'), 'instant_requests/ir_c/private/contact')));
  });

  test('a cancelled photographer cannot read the contact copy', async () => {
    await seed('instant_requests/ir_cx', request({ paidAt: ago(300) }));
    await seed('instant_requests/ir_cx/private/contact', { name: 'Lan', phone: '+84903123456', allowZalo: false, allowWhatsApp: false });
    // The photographer cancelled: the request went back to choosing with another (or no) photographer.
    await seed('instant_requests/ir_cx', request({ paidAt: ago(300), status: 'choosing', photographerId: null }));
    await assertFails(getDoc(doc(as('ic_ph'), 'instant_requests/ir_cx/private/contact')));
  });

  test('an unpaid request never exposes the contact copy, even to the assigned photographer', async () => {
    await seed('instant_requests/ir_unpaid', request({ paidAt: null }));
    await seed('instant_requests/ir_unpaid/private/contact', { name: 'Lan', phone: '+84903123456', allowZalo: false, allowWhatsApp: false });
    await assertFails(getDoc(doc(as('ic_ph'), 'instant_requests/ir_unpaid/private/contact')));
  });

  test('customer cannot read the contact copy', async () => {
    await seed('instant_requests/ir_cc', request({ paidAt: ago(300) }));
    await seed('instant_requests/ir_cc/private/contact', { name: 'Lan', phone: '+84903123456', allowZalo: false, allowWhatsApp: false });
    await assertFails(getDoc(doc(as('ic_cust'), 'instant_requests/ir_cc/private/contact')));
  });

  test('nobody reads private/dispatch or the customer lock', async () => {
    await seed('instant_requests/ir_d', request());
    await seed('instant_requests/ir_d/private/dispatch', { excludedIds: ['ic_skipped'] });
    await assertFails(getDoc(doc(as('ic_ph'), 'instant_requests/ir_d/private/dispatch')));
    await assertFails(getDoc(doc(as('ic_cust'), 'instant_requests/ir_d/private/dispatch')));
    await seed('instant_customers/ic_cust', { activeRequestId: 'ir_d' });
    await assertFails(getDoc(doc(as('ic_cust'), 'instant_customers/ic_cust')));
    await assertFails(setDoc(doc(as('ic_cust'), 'instant_customers/ic_cust'), { activeRequestId: null }));
  });

  test('owner reads own offers, another photographer cannot', async () => {
    await seed('instant_offers/io_ph/offers/of1', { requestId: 'ir_x', photographerId: 'io_ph', outcome: 'pending', areaLabel: 'Quận 1, TP.HCM' });
    await assertSucceeds(getDoc(doc(as('io_ph'), 'instant_offers/io_ph/offers/of1')));
    await assertSucceeds(getDocs(query(collection(as('io_ph'), 'instant_offers/io_ph/offers'), where('outcome', '==', 'pending'))));
    await assertFails(getDoc(doc(as('io_other'), 'instant_offers/io_ph/offers/of1')));
    await assertFails(updateDoc(doc(as('io_ph'), 'instant_offers/io_ph/offers/of1'), { outcome: 'accepted' }));
  });

  test('both parties read the track, another user cannot', async () => {
    await seed('instant_tracks/it_r', track());
    await assertSucceeds(getDoc(doc(as('ic_cust'), 'instant_tracks/it_r')));
    await assertSucceeds(getDoc(doc(as('ic_ph'), 'instant_tracks/it_r')));
    await assertFails(getDoc(doc(as('ic_stranger'), 'instant_tracks/it_r')));
  });

  test('assigned photographer updates the track with request.time', async () => {
    await seed('instant_tracks/it_u', track());
    await assertSucceeds(updateDoc(doc(as('ic_ph'), 'instant_tracks/it_u'), point()));
  });

  test('track write within 15 s is denied', async () => {
    await seed('instant_tracks/it_fast', track({ at: ago(5) }));
    await assertFails(updateDoc(doc(as('ic_ph'), 'instant_tracks/it_fast'), point()));
  });

  test('an inactive track is not readable by either party', async () => {
    await seed('instant_tracks/it_gone', track({ active: false }));
    await assertFails(getDoc(doc(as('ic_cust'), 'instant_tracks/it_gone')));
    await assertFails(getDoc(doc(as('ic_ph'), 'instant_tracks/it_gone')));
  });

  test('track write when inactive is denied', async () => {
    await seed('instant_tracks/it_off', track({ active: false }));
    await assertFails(updateDoc(doc(as('ic_ph'), 'instant_tracks/it_off'), point()));
  });

  test('customer cannot write the track', async () => {
    await seed('instant_tracks/it_c', track());
    await assertFails(updateDoc(doc(as('ic_cust'), 'instant_tracks/it_c'), point()));
    await assertFails(updateDoc(doc(as('ic_ph'), 'instant_tracks/it_c'), { ...point(), photographerId: 'ic_ph2' }));
    await assertFails(updateDoc(doc(as('ic_ph'), 'instant_tracks/it_c'), point({ at: Timestamp.now() })));
    await assertFails(setDoc(doc(as('ic_ph'), 'instant_tracks/it_new'), track()));
    await assertFails(deleteDoc(doc(as('ic_ph'), 'instant_tracks/it_c')));
  });
});

// ---- S27 #151: recruit posts (R3), applications, collaborations, collab jobs (fee private), contact R8 ----
describe('S27 studio recruiting', () => {
  const as = (uid) => env.authenticatedContext(uid).firestore();
  const DAY = 86_400_000;
  const at = (ms) => Timestamp.fromDate(new Date(ms));
  const recruitPost = (studioId) => ({
    studioId, studio: { name: 'Cúc Studio', avatarUrl: null, businessVerified: true }, kind: 'collaborator',
    title: 'Tuyển CTV chụp cưới cuối tuần', specialties: ['wedding'], areas: ['hcm-q1'], frequency: 'weekly',
    feeHint: { type: 'negotiable' }, requirements: '', status: 'open', renewed: false, applicationCount: 0,
    matchKeys: ['a=hcm-q1|s=wedding'], filterKeys: ['k=collaborator'], createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(), expiresAt: at(Date.now() + 30 * DAY), closedAt: null,
  });
  // users/{uid}.role + photographers/{uid} (or no photographer doc).
  const seedAccount = async (uid, role, photographer) => {
    await seedDoc(`users/${uid}`, { displayName: uid, role });
    if (photographer) await seedDoc(`photographers/${uid}`, { onboardingComplete: true, ...photographer });
  };
  const posts = (uid) => getDocs(query(collection(as(uid), 'recruitPosts'), where('status', '==', 'open')));

  before(async () => {
    await seedAccount('rc_studio', 'photographer', { providerType: 'studio', verified: true });
    await seedAccount('rc_ind', 'photographer', { providerType: 'individual', verified: false });
    await seedAccount('rc_cust', 'customer', null);
    await seedAccount('rc_switched', 'customer', { providerType: 'individual', verified: true });
    await seedAccount('rc_other', 'photographer', { providerType: 'individual', verified: true });
    await seedDoc('recruitPosts/rp1', recruitPost('rc_studio'));
  });

  test('provider (individual, unverified) can get and list recruitPosts', async () => {
    await assertSucceeds(getDoc(doc(as('rc_ind'), 'recruitPosts/rp1')));
    await assertSucceeds(posts('rc_ind'));
  });

  test('studio can list recruitPosts', async () => {
    await assertSucceeds(posts('rc_studio'));
    await assertSucceeds(getDocs(query(collection(as('rc_studio'), 'recruitPosts'), where('studioId', '==', 'rc_studio'))));
  });

  test('customer cannot get or list recruitPosts', async () => {
    await assertFails(getDoc(doc(as('rc_cust'), 'recruitPosts/rp1')));
    await assertFails(posts('rc_cust'));
  });

  test('customer-mode account with a photographers doc cannot read recruitPosts', async () => {
    await assertFails(getDoc(doc(as('rc_switched'), 'recruitPosts/rp1')));
    await assertFails(posts('rc_switched'));
  });

  test('signed-out cannot list recruitPosts', async () => {
    await assertFails(getDocs(query(collection(env.unauthenticatedContext().firestore(), 'recruitPosts'), where('status', '==', 'open'))));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'recruitPosts/rp1')));
  });

  test('nobody writes recruitPosts, recruitApplications, studio_collaborations, collab_jobs, staff_flags', async () => {
    for (const uid of ['rc_studio', 'rc_ind', 'rc_cust']) {
      const db = as(uid);
      await assertFails(setDoc(doc(db, 'recruitPosts/rp_new'), recruitPost('rc_studio')));
      await assertFails(updateDoc(doc(db, 'recruitPosts/rp1'), { title: 'Tuyển CTV chụp cưới tháng sau' }));
      await assertFails(deleteDoc(doc(db, 'recruitPosts/rp1')));
      await assertFails(setDoc(doc(db, 'recruitApplications/rp1_rc_ind'), { postId: 'rp1', studioId: 'rc_studio', applicantId: 'rc_ind', status: 'applied' }));
      await assertFails(setDoc(doc(db, 'studio_collaborations/rc_studio_rc_ind'), { studioId: 'rc_studio', collaboratorId: 'rc_ind', status: 'active' }));
      await assertFails(setDoc(doc(db, 'studio_collaborations/rc_studio_rc_ind/history/h1'), { studioId: 'rc_studio', collaboratorId: 'rc_ind' }));
      await assertFails(setDoc(doc(db, 'collab_jobs/b1_rc_ind'), { studioId: 'rc_studio', collaboratorId: 'rc_ind', agreedFee: 1000 }));
      await assertFails(setDoc(doc(db, 'staff_flags/poach_rc_ind_rc_cust'), { kind: 'collab_poaching' }));
    }
    await seedDoc('staff_flags/poach_rc_ind_rc_cust', { kind: 'collab_poaching', photographerId: 'rc_ind', customerId: 'rc_cust' });
    await assertFails(getDoc(doc(as('rc_ind'), 'staff_flags/poach_rc_ind_rc_cust')));
    await assertFails(getDoc(doc(as('rc_cust'), 'staff_flags/poach_rc_ind_rc_cust')));
  });

  test('applicant and studio read an application, another provider cannot', async () => {
    await seedDoc('recruitApplications/rp1_rc_ind', { postId: 'rp1', studioId: 'rc_studio', applicantId: 'rc_ind', status: 'applied', createdAt: Timestamp.now() });
    await assertSucceeds(getDoc(doc(as('rc_ind'), 'recruitApplications/rp1_rc_ind')));
    await assertSucceeds(getDoc(doc(as('rc_studio'), 'recruitApplications/rp1_rc_ind')));
    await assertFails(getDoc(doc(as('rc_other'), 'recruitApplications/rp1_rc_ind')));
    await assertSucceeds(getDocs(query(collection(as('rc_ind'), 'recruitApplications'), where('applicantId', '==', 'rc_ind'))));
    await assertSucceeds(getDocs(query(collection(as('rc_studio'), 'recruitApplications'), where('studioId', '==', 'rc_studio'), where('postId', '==', 'rp1'))));
    await assertFails(getDocs(query(collection(as('rc_other'), 'recruitApplications'), where('postId', '==', 'rp1'))));
  });

  test('the two parties read a collaboration and its history, a third cannot', async () => {
    await seedDoc('studio_collaborations/rc_studio_rc_ind', { studioId: 'rc_studio', collaboratorId: 'rc_ind', status: 'active', updatedAt: Timestamp.now() });
    await seedDoc('studio_collaborations/rc_studio_rc_ind/history/h1', { studioId: 'rc_studio', collaboratorId: 'rc_ind', status: 'ended' });
    for (const uid of ['rc_studio', 'rc_ind']) {
      await assertSucceeds(getDoc(doc(as(uid), 'studio_collaborations/rc_studio_rc_ind')));
      await assertSucceeds(getDoc(doc(as(uid), 'studio_collaborations/rc_studio_rc_ind/history/h1')));
    }
    await assertSucceeds(getDocs(query(collection(as('rc_studio'), 'studio_collaborations'), where('studioId', '==', 'rc_studio'))));
    await assertSucceeds(getDocs(query(collection(as('rc_ind'), 'studio_collaborations'), where('collaboratorId', '==', 'rc_ind'))));
    await assertFails(getDoc(doc(as('rc_other'), 'studio_collaborations/rc_studio_rc_ind')));
    await assertFails(getDoc(doc(as('rc_other'), 'studio_collaborations/rc_studio_rc_ind/history/h1')));
    await assertFails(getDocs(query(collection(as('rc_other'), 'studio_collaborations'), where('studioId', '==', 'rc_studio'))));
  });

  // Review Focus 2: the agreed fee and the pay record stay with the studio and that collaborator.
  test('customer cannot read collab_jobs', async () => {
    await seedDoc('collab_jobs/rcb1_rc_ind', { bookingId: 'rcb1', studioId: 'rc_studio', collaboratorId: 'rc_ind', customerId: 'rc_cust', agreedFee: 600000, offerStatus: 'accepted', payStatus: 'due', updatedAt: Timestamp.now() });
    await assertFails(getDoc(doc(as('rc_cust'), 'collab_jobs/rcb1_rc_ind')));
    await assertFails(getDocs(query(collection(as('rc_cust'), 'collab_jobs'), where('customerId', '==', 'rc_cust'))));
    await assertSucceeds(getDoc(doc(as('rc_studio'), 'collab_jobs/rcb1_rc_ind')));
    await assertSucceeds(getDoc(doc(as('rc_ind'), 'collab_jobs/rcb1_rc_ind')));
    await assertSucceeds(getDocs(query(collection(as('rc_studio'), 'collab_jobs'), where('studioId', '==', 'rc_studio'))));
    await assertSucceeds(getDocs(query(collection(as('rc_ind'), 'collab_jobs'), where('collaboratorId', '==', 'rc_ind'))));
  });

  test('another photographer cannot read collab_jobs', async () => {
    await seedDoc('collab_jobs/rcb2_rc_ind', { bookingId: 'rcb2', studioId: 'rc_studio', collaboratorId: 'rc_ind', customerId: 'rc_cust', agreedFee: 600000 });
    await assertFails(getDoc(doc(as('rc_other'), 'collab_jobs/rcb2_rc_ind')));
    await assertFails(getDocs(query(collection(as('rc_other'), 'collab_jobs'), where('studioId', '==', 'rc_studio'))));
  });

  test('owner cannot write photographers/{uid}.recruitMatchKeys', async () => {
    await seedDoc('photographers/rc_other', { onboardingComplete: true, verified: true, providerType: 'individual', bio: 'x' });
    const db = as('rc_other');
    await assertFails(updateDoc(doc(db, 'photographers/rc_other'), { recruitMatchKeys: ['a=hcm-q1|s=wedding'] }));
    await assertSucceeds(updateDoc(doc(db, 'photographers/rc_other'), { bio: 'y' }));
    // A server-written value stays when the owner saves other fields.
    await seedDoc('photographers/rc_other', { onboardingComplete: true, verified: true, providerType: 'individual', bio: 'y', recruitMatchKeys: ['a=hue|s=portrait'] });
    await assertSucceeds(updateDoc(doc(db, 'photographers/rc_other'), { bio: 'z' }));
    await assertFails(updateDoc(doc(db, 'photographers/rc_other'), { recruitMatchKeys: [] }));
  });

  test('owner reads photographers/{uid}/private/recruit, cannot write it', async () => {
    await seedDoc('photographers/rc_studio/private/recruit', { openPostCount: 1, unpaidFlags: [], recruitBlockedUntil: null });
    await assertSucceeds(getDoc(doc(as('rc_studio'), 'photographers/rc_studio/private/recruit')));
    await assertFails(getDoc(doc(as('rc_ind'), 'photographers/rc_studio/private/recruit')));
    await assertFails(setDoc(doc(as('rc_studio'), 'photographers/rc_studio/private/recruit'), { openPostCount: 0 }));
    await assertFails(updateDoc(doc(as('rc_studio'), 'photographers/rc_studio/private/recruit'), { recruitBlockedUntil: null }));
  });

  // Review Focus 3 (R8): the customer contact opens to a collaborator only once the offer is accepted.
  const collabBooking = (id, over) => seedDoc(`bookings/${id}`, {
    customerId: 'rc_cust', photographerId: 'rc_studio', isStudio: true, status: 'accepted',
    assigneeId: 'rc_ind', assigneeKind: 'collaborator', assigneeAccepted: false, ...over,
  });
  const contactOf = async (id) => seedDoc(`bookings/${id}/private/contact`, { name: 'Lan', phone: '+84903000001' });

  test('pending collaborator cannot read the customer contact', async () => {
    await collabBooking('rcb_pending', {});
    await contactOf('rcb_pending');
    await assertFails(getDoc(doc(as('rc_ind'), 'bookings/rcb_pending/private/contact')));
    // The studio still does; the customer reads their own.
    await assertSucceeds(getDoc(doc(as('rc_studio'), 'bookings/rcb_pending/private/contact')));
    await assertSucceeds(getDoc(doc(as('rc_cust'), 'bookings/rcb_pending/private/contact')));
  });

  test('accepted collaborator can', async () => {
    await collabBooking('rcb_accepted', { assigneeAccepted: true, status: 'upcoming' });
    await contactOf('rcb_accepted');
    await assertSucceeds(getDoc(doc(as('rc_ind'), 'bookings/rcb_accepted/private/contact')));
  });

  test('replaced collaborator cannot', async () => {
    await collabBooking('rcb_replaced', { assigneeId: 'rc_other', assigneeAccepted: false });
    await contactOf('rcb_replaced');
    await assertFails(getDoc(doc(as('rc_ind'), 'bookings/rcb_replaced/private/contact')));
    await assertFails(getDoc(doc(as('rc_ind'), 'bookings/rcb_replaced')));
    // A member assigned in its place reads it under S26's rule.
    await collabBooking('rcb_member', { assigneeId: 'rc_other', assigneeKind: 'member', assigneeAccepted: true });
    await contactOf('rcb_member');
    await assertSucceeds(getDoc(doc(as('rc_other'), 'bookings/rcb_member/private/contact')));
    await assertFails(getDoc(doc(as('rc_ind'), 'bookings/rcb_member/private/contact')));
  });

  test('accepted collaborator cannot read it 7 days after completedAt', async () => {
    await collabBooking('rcb_done_old', { assigneeAccepted: true, status: 'completed', completedAt: at(Date.now() - 8 * DAY) });
    await contactOf('rcb_done_old');
    await assertFails(getDoc(doc(as('rc_ind'), 'bookings/rcb_done_old/private/contact')));
    await collabBooking('rcb_done_new', { assigneeAccepted: true, status: 'completed', completedAt: at(Date.now() - 2 * DAY) });
    await contactOf('rcb_done_new');
    await assertSucceeds(getDoc(doc(as('rc_ind'), 'bookings/rcb_done_new/private/contact')));
    // Cancelled: the same 7 days from cancel.at.
    await collabBooking('rcb_cancel_old', { assigneeAccepted: true, status: 'cancelled', cancel: { by: 'customer', at: at(Date.now() - 8 * DAY), refundPercent: 100 } });
    await contactOf('rcb_cancel_old');
    await assertFails(getDoc(doc(as('rc_ind'), 'bookings/rcb_cancel_old/private/contact')));
    await collabBooking('rcb_cancel_new', { assigneeAccepted: true, status: 'cancelled', cancel: { by: 'customer', at: at(Date.now() - DAY), refundPercent: 100 } });
    await contactOf('rcb_cancel_new');
    await assertSucceeds(getDoc(doc(as('rc_ind'), 'bookings/rcb_cancel_new/private/contact')));
  });
});

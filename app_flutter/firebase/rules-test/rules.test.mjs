import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, updateDoc, deleteDoc, deleteField, writeBatch, serverTimestamp, Timestamp, GeoPoint, collection, query, where } from 'firebase/firestore';

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
      onboardingComplete: true, verified: false, bio: 'x', followerCount: 3, stats: { rating: 4 },
    });
  });
  const db = env.authenticatedContext('v1').firestore();
  // Allowed updates still work, so the failures below are about the counters.
  await assertSucceeds(updateDoc(doc(db, 'users/v1'), { displayName: 'Vee' }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/v1'), { bio: 'y' }));
  await assertFails(updateDoc(doc(db, 'users/v1'), { savedCount: 10 }));
  await assertFails(updateDoc(doc(db, 'users/v1'), { followerCount: 10 }));
  await assertFails(updateDoc(doc(db, 'photographers/v1'), { followerCount: 10 }));
  await assertFails(updateDoc(doc(db, 'photographers/v1'), { 'stats.rating': 5 }));
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

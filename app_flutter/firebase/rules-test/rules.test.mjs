import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc } from 'firebase/firestore';

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
test('photographer doc only by owner; bookings are read-only for clients', async () => {
  const db = env.authenticatedContext('u1').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/u1'), { onboardingComplete: false }));
  await assertFails(setDoc(doc(db, 'photographers/u2'), { onboardingComplete: false }));
  await assertFails(setDoc(doc(db, 'bookings/b1'), { customerId: 'u1', status: 'requested' }));
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'bookings/b2'), { customerId: 'u1', photographerId: 'u2', status: 'requested' }));
  await assertSucceeds(getDoc(doc(db, 'bookings/b2')));
  await assertFails(getDoc(doc(env.authenticatedContext('u3').firestore(), 'bookings/b2')));
});
test('client can create its photographer doc unverified, but never verify itself', async () => {
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

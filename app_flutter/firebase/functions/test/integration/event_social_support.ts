import { getAuth } from 'firebase-admin/auth';
import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import type { App } from 'firebase-admin/app';
import { newUlid } from '@photobooking/domain';
import { callCallable, emulatorProject, signIn } from '../../seed/emulator_client.js';
import { SEED_PASSWORD } from '../../seed/fixtures.js';

export const DAY = 86_400_000;

export const bucketUrl = (path: string): string =>
  `http://127.0.0.1:9199/v0/b/${emulatorProject()}.firebasestorage.app/o/${encodeURIComponent(path)}?alt=media&token=t`;

/** Polls until `fn` returns a value (a trigger ran), or fails after ~15 s. */
export async function waitFor<T>(what: string, fn: () => Promise<T | null | undefined | false>): Promise<T> {
  const until = Date.now() + 15_000;
  for (;;) {
    const v = await fn();
    if (v !== null && v !== undefined && v !== false) return v;
    if (Date.now() > until) throw new Error(`timed out waiting for ${what}`);
    await new Promise((r) => setTimeout(r, 250));
  }
}

export interface SocialEnv {
  readonly app: App;
  readonly db: Firestore;
  readonly tokens: Map<string, string>;
}

export const callAs = (env: SocialEnv, name: string, uid: string, data: unknown) =>
  callCallable(name, data, env.tokens.get(uid));

/** A customer with a phone (registering needs one), created through the Admin SDK. */
export async function makeCustomer(env: SocialEnv, label: string): Promise<string> {
  const uid = `soc-${label}-${Date.now()}`;
  const email = `${uid}@seed.test`;
  await getAuth(env.app).createUser({ uid, email, password: SEED_PASSWORD, displayName: `Khách ${label}` });
  await env.db.doc(`users/${uid}`).set({ displayName: `Khách ${label}`, role: 'customer', createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
  await env.db.doc(`users/${uid}/private/contact`).set({ phone: `+8490600${String(Date.now()).slice(-4)}`, phoneVerified: false, allowZalo: false, allowWhatsApp: false });
  env.tokens.set(uid, await signIn(email, SEED_PASSWORD));
  return uid;
}

let nextDay = 60;

/** A published free event of `host` on its own day (publishing reserves the host's day). */
export async function publishFreeEvent(env: SocialEnv, host: string): Promise<{ eventId: string; hashtag: string }> {
  const eventId = newUlid(Date.now());
  const path = `eventCovers/${host}/${eventId}/cover.jpg`;
  const start = new Date(Date.now() + nextDay++ * DAY);
  const saved = await callAs(env, 'saveEventDraft', host, {
    eventId, title: `Photo walk ${eventId.slice(-6)}`, type: 'photo_walk',
    coverUrl: bucketUrl(path), coverPath: path,
    startAt: start.toISOString(), endAt: new Date(start.getTime() + 3 * 3_600_000).toISOString(),
    location: { name: 'Hồ Gươm', lat: 21.0285, lng: 105.8542 }, capacity: 10, price: 0,
  });
  const hashtag = (saved.result as { hashtag: string }).hashtag;
  await callAs(env, 'publishEvent', host, { eventId });
  return { eventId, hashtag };
}

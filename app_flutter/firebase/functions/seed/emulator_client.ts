import { REGION } from '../src/config.js';
import { assertLocalEmulators } from './local_guard.js';

// Talks to the emulators over their REST endpoints, like the app does: Auth sign-in and the
// callable protocol (POST {data} → {result} | {error}). Used by the integration tests and try_contact_link.ts.

const host = (key: string, fallback: string): string => process.env[key] ?? fallback;
const authHost = () => host('FIREBASE_AUTH_EMULATOR_HOST', '127.0.0.1:9099');
const firestoreHost = () => host('FIRESTORE_EMULATOR_HOST', '127.0.0.1:8080');
const functionsHost = () => host('FUNCTIONS_EMULATOR_HOST', '127.0.0.1:5001');

export function emulatorProject(): string {
  return assertLocalEmulators({ functions: true });
}

/** Signs in on the Auth emulator and returns an ID token. */
export async function signIn(email: string, password: string): Promise<string> {
  const res = await fetch(
    `http://${authHost()}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, returnSecureToken: true }) },
  );
  const body = (await res.json()) as { idToken?: string };
  if (!res.ok || body.idToken === undefined) throw new Error(`sign-in failed for ${email}: HTTP ${res.status}`);
  return body.idToken;
}

export interface CallableResponse {
  readonly status: number;
  /** Raw response body, for asserting what travels over the wire. */
  readonly text: string;
  readonly result?: unknown;
  readonly error?: { readonly message?: string; readonly status?: string; readonly details?: unknown };
}

/** Invokes a callable exactly like the Firebase client SDK does. */
export async function callCallable(name: string, data: unknown, idToken?: string): Promise<CallableResponse> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (idToken !== undefined) headers.Authorization = `Bearer ${idToken}`;
  const res = await fetch(`http://${functionsHost()}/${emulatorProject()}/${REGION}/${name}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data }),
  });
  const text = await res.text();
  let parsed: { result?: unknown; error?: CallableResponse['error'] } = {};
  try {
    parsed = JSON.parse(text) as typeof parsed;
  } catch {
    // Not a callable response (for example the emulator's 404 for an unknown function).
  }
  return { status: res.status, text, ...parsed };
}

/** Empties Firestore and Auth of the emulator project (emulator-only REST endpoints). */
export async function resetEmulators(): Promise<void> {
  const project = emulatorProject();
  await fetch(`http://${firestoreHost()}/emulator/v1/projects/${project}/databases/(default)/documents`, { method: 'DELETE' });
  await fetch(`http://${authHost()}/emulator/v1/projects/${project}/accounts`, { method: 'DELETE' });
}

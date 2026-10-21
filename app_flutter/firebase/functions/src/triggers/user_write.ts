import type { DocumentData } from 'firebase-admin/firestore';
import { foldNameKey } from '@photobooking/domain';

/** `photographers/{uid}.nameKey` reads and writes (server field, S26.02 search, Decision 19). */
export interface NameKeyStore {
  photographerExists(uid: string): Promise<boolean>;
  /** `users/{uid}.displayName`, null when absent. */
  displayName(uid: string): Promise<string | null>;
  setNameKey(uid: string, nameKey: string): Promise<void>;
}

export interface UserWriteInput {
  readonly uid: string;
  readonly before: DocumentData | undefined;
  readonly after: DocumentData | undefined;
}

function nameOf(d: DocumentData | undefined): string | null {
  return typeof d?.displayName === 'string' ? d.displayName : null;
}

/** `users/{uid}` written: a changed `displayName` refreshes the photographer's `nameKey`, if there is a photographer doc. */
export async function handleUserWrite(
  input: UserWriteInput,
  store: NameKeyStore,
): Promise<'written' | 'unchanged' | 'no_photographer'> {
  if (input.after === undefined) return 'unchanged';
  const name = nameOf(input.after);
  if (input.before !== undefined && nameOf(input.before) === name) return 'unchanged';
  if (!(await store.photographerExists(input.uid))) return 'no_photographer';
  await store.setNameKey(input.uid, foldNameKey(name ?? ''));
  return 'written';
}

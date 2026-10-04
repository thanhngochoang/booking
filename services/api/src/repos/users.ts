import type { Kysely } from 'kysely';

import { authProviderCode, type Principal } from '../auth/identity.js';
import type { Database, UserRole } from '../db/database.js';
import { ApiError } from '../errors.js';
import { newId } from '../ids.js';

/** users/{uid} as everyone may see it: never a phone, never an email. */
export interface PublicProfile {
  id: string;
  displayName: string;
  role: UserRole | null;
  avatarUrl: string | null;
}

export const profileQuery = (db: Kysely<Database>, id: string) =>
  db
    .selectFrom('users as u')
    .leftJoin('files as f', 'f.id', 'u.avatar_file_id')
    .select(['u.id', 'u.display_name', 'u.role', 'f.storage_provider', 'f.storage_key'])
    .where('u.id', '=', id)
    .where('u.deleted_at', 'is', null);

export async function findProfile(db: Kysely<Database>, id: string): Promise<PublicProfile | null> {
  const r = await profileQuery(db, id).executeTakeFirst();
  if (!r) return null;
  return {
    id: r.id,
    displayName: r.display_name,
    role: r.role,
    // MediaUrlResolver for real storage keys arrives with the Storage plan.
    avatarUrl: r.storage_provider === 'external' ? r.storage_key : null,
  };
}

/** Creates users/{uid} when missing (never overwrites) and records the sign-in identity. */
export async function ensureProfile(
  db: Kysely<Database>,
  p: Principal,
  input: { displayName: string; avatarUrl?: string },
): Promise<{ profile: PublicProfile; created: boolean }> {
  return db.transaction().execute(async (trx) => {
    const inserted = await trx
      .insertInto('users')
      .values({ id: p.uid, display_name: input.displayName })
      .onConflict((oc) => oc.column('id').doNothing())
      .returning('id')
      .executeTakeFirst();
    const created = inserted !== undefined;
    if (created && input.avatarUrl) {
      await trx
        .insertInto('files')
        .values({
          id: newId(),
          owner_user_id: p.uid,
          storage_provider: 'external',
          storage_key: input.avatarUrl,
          mime_type: 'image/*',
          size_bytes: 0,
        })
        .onConflict((oc) => oc.columns(['storage_provider', 'storage_key']).doNothing())
        .execute();
      const file = await trx
        .selectFrom('files')
        .select('id')
        .where('storage_provider', '=', 'external')
        .where('storage_key', '=', input.avatarUrl)
        .executeTakeFirstOrThrow();
      await trx.updateTable('users').set({ avatar_file_id: file.id }).where('id', '=', p.uid).execute();
    }
    await trx
      .insertInto('auth_identities')
      .values({
        id: newId(),
        user_id: p.uid,
        provider: authProviderCode(p.signInProvider),
        subject: p.providerSubject,
        email: p.email,
      })
      .onConflict((oc) => oc.columns(['provider', 'subject']).doNothing())
      .execute();
    const profile = await findProfile(trx, p.uid);
    if (!profile) throw new ApiError('permission_denied', 'this account was deleted');
    return { profile, created };
  });
}

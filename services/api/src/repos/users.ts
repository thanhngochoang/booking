import { sql, type Kysely } from 'kysely';

import { authProviderCode, type Principal } from '../auth/identity.js';
import { isForeignKeyViolation, type Database, type UserRole } from '../db/database.js';
import { ApiError } from '../errors.js';
import { newId } from '../ids.js';
import { iso } from '../wire.js';

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

export async function updateDisplayName(db: Kysely<Database>, id: string, displayName: string): Promise<PublicProfile | null> {
  const r = await db
    .updateTable('users')
    .set({ display_name: displayName })
    .where('id', '=', id)
    .where('deleted_at', 'is', null)
    .returning('id')
    .executeTakeFirst();
  return r ? findProfile(db, id) : null;
}

/** Use case set_role. The first switch to photographer creates the photographer row. */
export async function setRole(db: Kysely<Database>, id: string, role: UserRole): Promise<PublicProfile | null> {
  return db.transaction().execute(async (trx) => {
    const r = await trx
      .updateTable('users')
      .set({ role })
      .where('id', '=', id)
      .where('deleted_at', 'is', null)
      .returning('id')
      .executeTakeFirst();
    if (!r) return null;
    if (role === 'photographer') {
      await trx.insertInto('photographers').values({ user_id: id }).onConflict((oc) => oc.column('user_id').doNothing()).execute();
    }
    return findProfile(trx, id);
  });
}

export interface UserContactDto {
  phone: string;
  phoneVerified: boolean;
  allowZalo: boolean;
  allowWhatsApp: boolean;
  updatedAt: string;
}

export const contactQuery = (db: Kysely<Database>, userId: string) =>
  db
    .selectFrom('user_contacts')
    .select(['phone_e164', 'phone_verified', 'allow_zalo', 'allow_whatsapp', 'updated_at'])
    .where('user_id', '=', userId);

const toContact = (r: {
  phone_e164: string;
  phone_verified: boolean;
  allow_zalo: boolean;
  allow_whatsapp: boolean;
  updated_at: Date;
}): UserContactDto => ({
  phone: r.phone_e164,
  phoneVerified: r.phone_verified,
  allowZalo: r.allow_zalo,
  allowWhatsApp: r.allow_whatsapp,
  updatedAt: iso(r.updated_at),
});

export async function findContact(db: Kysely<Database>, userId: string): Promise<UserContactDto | null> {
  const r = await contactQuery(db, userId).executeTakeFirst();
  return r ? toContact(r) : null;
}

/** One statement: a changed number is unverified, a toggle keeps the server's flag. */
export async function saveContact(
  db: Kysely<Database>,
  userId: string,
  input: { phone: string; allowZalo: boolean; allowWhatsApp: boolean },
): Promise<UserContactDto> {
  try {
    const r = await db
      .insertInto('user_contacts')
      .values({
        user_id: userId,
        phone_e164: input.phone,
        phone_verified: false,
        allow_zalo: input.allowZalo,
        allow_whatsapp: input.allowWhatsApp,
      })
      .onConflict((oc) =>
        oc.column('user_id').doUpdateSet((eb) => ({
          phone_e164: eb.ref('excluded.phone_e164'),
          allow_zalo: eb.ref('excluded.allow_zalo'),
          allow_whatsapp: eb.ref('excluded.allow_whatsapp'),
          phone_verified: sql<boolean>`case when user_contacts.phone_e164 = excluded.phone_e164
            then user_contacts.phone_verified else false end`,
        })),
      )
      .returning(['phone_e164', 'phone_verified', 'allow_zalo', 'allow_whatsapp', 'updated_at'])
      .executeTakeFirstOrThrow();
    return toContact(r);
  } catch (e) {
    if (isForeignKeyViolation(e)) throw new ApiError('not_found', 'create the profile first (POST /v1/me)');
    throw e;
  }
}

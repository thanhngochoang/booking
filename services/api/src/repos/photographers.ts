import type { Kysely } from 'kysely';

import type { Database } from '../db/database.js';
import { ApiError } from '../errors.js';

export interface ChannelsDto {
  call: boolean;
  zalo: boolean;
  whatsapp: boolean;
  acceptInquiries: boolean;
}

export interface NumbersDto {
  phone: string;
  zaloPhone: string | null;
  whatsappPhone: string | null;
}

export interface AreaDto {
  city: string;
  radiusKm: number;
}

export const channelsQuery = (db: Kysely<Database>, id: string) =>
  db
    .selectFrom('photographer_contact_channels as c')
    .innerJoin('photographers as p', 'p.user_id', 'c.photographer_id')
    .select(['c.call_enabled', 'c.zalo_enabled', 'c.whatsapp_enabled', 'p.accepts_inquiries'])
    .where('c.photographer_id', '=', id);

export async function findChannels(db: Kysely<Database>, id: string): Promise<ChannelsDto | null> {
  const r = await channelsQuery(db, id).executeTakeFirst();
  return r
    ? { call: r.call_enabled, zalo: r.zalo_enabled, whatsapp: r.whatsapp_enabled, acceptInquiries: r.accepts_inquiries }
    : null;
}

export const numbersQuery = (db: Kysely<Database>, id: string) =>
  db
    .selectFrom('photographer_contact_numbers')
    .select(['phone_e164', 'zalo_phone_e164', 'whatsapp_phone_e164'])
    .where('photographer_id', '=', id);

export async function findNumbers(db: Kysely<Database>, id: string): Promise<NumbersDto | null> {
  const r = await numbersQuery(db, id).executeTakeFirst();
  return r ? { phone: r.phone_e164, zaloPhone: r.zalo_phone_e164, whatsappPhone: r.whatsapp_phone_e164 } : null;
}

export const serviceAreaQuery = (db: Kysely<Database>, id: string) =>
  db.selectFrom('photographers').select(['service_city', 'service_radius_km', 'onboarding_complete']).where('user_id', '=', id);

export async function findServiceArea(
  db: Kysely<Database>,
  id: string,
): Promise<{ area: AreaDto; onboardingComplete: boolean } | null> {
  const r = await serviceAreaQuery(db, id).executeTakeFirst();
  if (!r || r.service_city === null || r.service_radius_km === null) return null;
  return { area: { city: r.service_city, radiusKm: r.service_radius_km }, onboardingComplete: r.onboarding_complete };
}

/** S34 "Hoàn tất": area, public flags and private numbers in one transaction, then onboarding done. */
export async function completeContactSetup(
  db: Kysely<Database>,
  uid: string,
  input: {
    area: AreaDto;
    channels: ChannelsDto;
    numbers: { phone: string; zaloPhone?: string | null; whatsappPhone?: string | null };
  },
): Promise<void> {
  await db.transaction().execute(async (trx) => {
    const user = await trx
      .selectFrom('users')
      .select('role')
      .where('id', '=', uid)
      .where('deleted_at', 'is', null)
      .executeTakeFirst();
    if (!user) throw new ApiError('not_found', 'create the profile first (POST /v1/me)');
    if (user.role !== 'photographer') throw new ApiError('permission_denied', 'only photographers set contact channels');

    await trx
      .insertInto('photographers')
      .values({
        user_id: uid,
        service_city: input.area.city,
        service_radius_km: input.area.radiusKm,
        accepts_inquiries: input.channels.acceptInquiries,
        onboarding_complete: true,
      })
      .onConflict((oc) =>
        oc.column('user_id').doUpdateSet((eb) => ({
          service_city: eb.ref('excluded.service_city'),
          service_radius_km: eb.ref('excluded.service_radius_km'),
          accepts_inquiries: eb.ref('excluded.accepts_inquiries'),
          onboarding_complete: true,
        })),
      )
      .execute();

    await trx
      .insertInto('photographer_contact_channels')
      .values({
        photographer_id: uid,
        call_enabled: input.channels.call,
        zalo_enabled: input.channels.zalo,
        whatsapp_enabled: input.channels.whatsapp,
      })
      .onConflict((oc) =>
        oc.column('photographer_id').doUpdateSet((eb) => ({
          call_enabled: eb.ref('excluded.call_enabled'),
          zalo_enabled: eb.ref('excluded.zalo_enabled'),
          whatsapp_enabled: eb.ref('excluded.whatsapp_enabled'),
        })),
      )
      .execute();

    // The whole row is replaced, so a cleared own number really goes away.
    await trx
      .insertInto('photographer_contact_numbers')
      .values({
        photographer_id: uid,
        phone_e164: input.numbers.phone,
        zalo_phone_e164: input.numbers.zaloPhone ?? null,
        whatsapp_phone_e164: input.numbers.whatsappPhone ?? null,
      })
      .onConflict((oc) =>
        oc.column('photographer_id').doUpdateSet((eb) => ({
          phone_e164: eb.ref('excluded.phone_e164'),
          zalo_phone_e164: eb.ref('excluded.zalo_phone_e164'),
          whatsapp_phone_e164: eb.ref('excluded.whatsapp_phone_e164'),
        })),
      )
      .execute();
  });
}

import type { Kysely } from 'kysely';

import world from '../../test/fixtures/contract-world.json' with { type: 'json' };
import type { BookingStatus, Database } from '../db/database.js';

export interface WorldBooking {
  id: string;
  photographerId: string;
  status: BookingStatus;
  day: string;
  completedDaysAgo: number | null;
  unlocked: boolean;
}

export interface WorldPhotographer {
  numbers: { phone: string; zaloPhone?: string; whatsappPhone?: string };
  channels: { call: boolean; zalo: boolean; whatsapp: boolean; acceptInquiries: boolean };
}

export interface ContractWorld {
  customer: string;
  otherCustomer: string;
  photographers: Record<string, WorldPhotographer>;
  bookings: WorldBooking[];
}

export const contractWorld = world as ContractWorld;

const DAY_MS = 86_400_000;

/** Idempotent: upserts every row of the world; booking events are rebuilt per booking. */
export async function seedContractWorld(db: Kysely<Database>, now: Date, w: ContractWorld = contractWorld): Promise<void> {
  await db.transaction().execute(async (trx) => {
    const users = [
      { id: w.customer, display_name: 'Khách hợp đồng', role: 'customer' as const },
      { id: w.otherCustomer, display_name: 'Khách khác', role: 'customer' as const },
      ...Object.keys(w.photographers).map((id) => ({ id, display_name: `Thợ ảnh ${id}`, role: 'photographer' as const })),
    ];
    await trx
      .insertInto('users')
      .values(users)
      .onConflict((oc) =>
        oc.column('id').doUpdateSet((eb) => ({ display_name: eb.ref('excluded.display_name'), role: eb.ref('excluded.role'), deleted_at: null })),
      )
      .execute();

    for (const [id, p] of Object.entries(w.photographers)) {
      await trx
        .insertInto('photographers')
        .values({ user_id: id, onboarding_complete: true, accepts_inquiries: p.channels.acceptInquiries, service_city: 'Hà Nội', service_radius_km: 20 })
        .onConflict((oc) => oc.column('user_id').doUpdateSet({ onboarding_complete: true, accepts_inquiries: p.channels.acceptInquiries }))
        .execute();
      await trx
        .insertInto('photographer_contact_channels')
        .values({ photographer_id: id, call_enabled: p.channels.call, zalo_enabled: p.channels.zalo, whatsapp_enabled: p.channels.whatsapp })
        .onConflict((oc) =>
          oc.column('photographer_id').doUpdateSet({ call_enabled: p.channels.call, zalo_enabled: p.channels.zalo, whatsapp_enabled: p.channels.whatsapp }),
        )
        .execute();
      const numbers = {
        phone_e164: p.numbers.phone,
        zalo_phone_e164: p.numbers.zaloPhone ?? null,
        whatsapp_phone_e164: p.numbers.whatsappPhone ?? null,
      };
      await trx
        .insertInto('photographer_contact_numbers')
        .values({ photographer_id: id, ...numbers })
        .onConflict((oc) => oc.column('photographer_id').doUpdateSet(numbers))
        .execute();
      await trx
        .insertInto('services')
        .values({ id: `${id}_service`, photographer_id: id, name: 'Gói hợp đồng', duration_minutes: 120, price: 1_000_000 })
        .onConflict((oc) => oc.column('id').doNothing())
        .execute();
    }

    for (const b of w.bookings) {
      await trx
        .insertInto('bookings')
        .values({
          id: b.id, customer_id: w.customer, photographer_id: b.photographerId, service_id: `${b.photographerId}_service`,
          service_name: 'Gói hợp đồng', service_price: 1_000_000, service_duration_minutes: 120,
          day: b.day, start_time: '09:00', end_time: '11:00', status: b.status,
          deposit_amount: 300_000, remaining_amount: 700_000,
        })
        .onConflict((oc) => oc.column('id').doUpdateSet({ status: b.status, day: b.day, customer_id: w.customer }))
        .execute();
      await trx.deleteFrom('booking_events').where('booking_id', '=', b.id).execute();
      if (b.completedDaysAgo !== null) {
        await trx
          .insertInto('booking_events')
          .values({ id: `${b.id}_completed`, booking_id: b.id, status: 'completed', at: new Date(now.getTime() - b.completedDaysAgo * DAY_MS) })
          .execute();
      }
    }
  });
}

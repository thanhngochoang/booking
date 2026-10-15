/**
 * Use case: createBookingDraft and buildBookingDraft
 * Customer creates a draft booking, holding the photographer's day as pending.
 * Every order path builds its booking with `buildBookingDraft`; later units extend it only through the slots.
 */

import type { AddonLine, Booking, BookingPickup } from './booking.js';
import {
  DRAFT_EXPIRY_MINUTES,
  addMinutesToTime,
  clampRevisions,
  computeDeposit,
} from './booking_policy.js';
import type { BookingDeps, ServiceRecord } from './booking_ports.js';
import { validateCreateBookingDraftInput } from './booking_requests.js';
import { DomainError } from './errors.js';
import { assertOrderAllowed } from './order_gate.js';
import { requireCustomerPhone } from './require_phone.js';

// ── Draft slots: imports (one block per unit; edit only your own) ──
// slot #139 (quotes)

// slot #136 (studio)

import { addonDraftFields, bookingTotal, priceAddonLines, requirePickup } from './addon_pricing.js';

// ── end draft slot imports ──

/** What every order path supplies. */
export interface BookingDraftCore {
  readonly id: string;
  readonly customerId: string;
  readonly photographerId: string;
  /** The package; a quote passes a synthetic record (#139). `serviceId` = `service.id`. */
  readonly service: ServiceRecord;
  readonly day: string; // yyyy-MM-dd
  readonly start: string; // HH:mm
  readonly place: Booking['place'];
  readonly note?: string;
  readonly now: Date;
}

/** Core + the optional fields of later units, one slot each (Decision 2). */
export interface BookingDraftInput extends BookingDraftCore {
  // slot #139 (quotes): readonly quote?: { jobId: string; quoteId: string; terms: BookingTerms };

  // slot #136 (studio): readonly providerType?: ProviderType | null;

  readonly addons?: readonly AddonLine[];
  readonly pickup?: BookingPickup;
}

/** The amount the customer pays; #190 replaces the body (Decision 3). */
export function draftTotal(i: BookingDraftInput): number {
  return bookingTotal(i.service, i.addons ?? []);
}

function coreDraft(i: BookingDraftInput): Booking {
  const { id, customerId, photographerId, service, day, start, place, note, now } = i;
  const createdAt = now.toISOString();
  const end = addMinutesToTime(start, service.durationMinutes);
  const total = draftTotal(i);
  const { deposit, remaining } = computeDeposit(total);
  const payableUntil = new Date(now.getTime() + DRAFT_EXPIRY_MINUTES * 60_000).toISOString();
  const revisionsIncluded = clampRevisions(service.revisions);

  return {
    id,
    customerId,
    photographerId,
    serviceId: service.id,
    serviceSnapshot: {
      name: service.name,
      price: service.price,
      durationMinutes: service.durationMinutes,
    },
    day,
    start,
    end,
    place,
    note,
    status: 'draft',
    deposit,
    remaining,
    payableUntil,
    revisionsIncluded,
    version: 1,
    createdAt,
    updatedAt: createdAt,
  };
}

/**
 * Pure. status 'draft'; serviceId = service.id; serviceSnapshot {name, price, durationMinutes};
 * end = addMinutesToTime(start, durationMinutes); {deposit, remaining} = computeDeposit(draftTotal(i));
 * payableUntil = now + DRAFT_EXPIRY_MINUTES; revisionsIncluded = clampRevisions(service.revisions);
 * version 1; createdAt = updatedAt = now.toISOString(); then each slot's fields.
 */
export function buildBookingDraft(i: BookingDraftInput): Booking {
  const core = coreDraft(i);
  return {
    ...core,
    // slot #139 (quotes): ...quoteDraftFields(i),

    // slot #136 (studio): ...studioDraftFields(i, core),

    ...addonDraftFields(i),
  };
}

export async function createBookingDraft(
  deps: BookingDeps,
  rawInput: unknown,
): Promise<Booking> {
  const now = deps.clock.now();
  const input = validateCreateBookingDraftInput(rawInput, now);

  // 1. Service check
  const service = await deps.services.getService(input.photographerId, input.serviceId);
  if (!service || !service.active || service.photographerId !== input.photographerId) {
    throw new DomainError('not_found');
  }

  // Providers who cannot take orders yet, and blocked pairs, are not bookable
  await assertOrderAllowed(deps, { customerId: input.customerId, providerId: input.photographerId });

  if (input.expectedPrice !== undefined && input.expectedPrice !== service.price) {
    throw new DomainError('price_changed');
  }

  // Add-ons: priced from the provider's catalogue; the read is skipped without picks
  const addons =
    input.addons.length > 0
      ? priceAddonLines(await deps.addons.listAddons(input.photographerId), input.addons, input.serviceId)
      : [];
  const pickup = requirePickup(addons, input.pickup);
  if (input.expectedTotal !== undefined && input.expectedTotal !== bookingTotal(service, addons)) {
    throw new DomainError('addon_changed');
  }

  // 2. Phone requirement check (server enforced)
  const phone = await requireCustomerPhone(deps.contacts, input.customerId);
  const contactRecord = await deps.contacts.get(input.customerId);

  // 3. Transactional availability hold and booking creation
  return deps.store.runTransaction(async (tx) => {
    const existingDay = await tx.getAvailabilityDay(input.photographerId, input.day);
    const existingDraft = await tx.getCustomerDraftForDay(
      input.customerId,
      input.photographerId,
      input.day,
    );

    if (existingDay) {
      if (existingDay.state === 'off' || existingDay.state === 'booked') {
        throw new DomainError('day_taken');
      }
      if (existingDay.state === 'pending') {
        // Allowed only if it is the same customer's own earlier draft (Review Focus 2)
        const isOwnDraft = existingDraft && existingDay.bookingId === existingDraft.id;
        if (!isOwnDraft) {
          throw new DomainError('day_taken');
        }
      }
    }

    // Replace customer's earlier draft if present
    if (existingDraft) {
      await tx.deleteBooking(existingDraft.id);
      await tx.deleteContactSnapshot(existingDraft.id);
    }

    const bookingId = deps.ids.newId();
    const booking = buildBookingDraft({
      id: bookingId,
      customerId: input.customerId,
      photographerId: input.photographerId,
      service,
      day: input.day,
      start: input.start,
      place: input.place,
      note: input.note,
      addons,
      pickup,
      now,
    });

    await tx.setBooking(booking);
    await tx.setAvailabilityDay(input.photographerId, input.day, {
      state: 'pending',
      bookingId,
    });
    await tx.setContactSnapshot(bookingId, {
      name: contactRecord?.name ?? '',
      phone,
      allowZalo: contactRecord?.allowZalo ?? false,
      allowWhatsApp: contactRecord?.allowWhatsApp ?? false,
    });

    return booking;
  });
}

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
import { profileOrderBlocker } from './order_gate.js';
import { requireCustomerPhone } from './require_phone.js';
import type { Spot } from './spot.js';
import { dayHolderOf, type SpotSchedule } from './spot_schedule.js';
import type { SlotOffer } from './spot_slots.js';
import { assertSpotBooking, withInterval, withoutInterval, type SpotDay } from './spot_booking.js';

// ── Draft slots: imports (one block per unit; edit only your own) ──
// slot #139 (quotes)

// slot #136 (studio)
import type { ProviderType } from './provider_type.js';
import { memberDayReleasable, studioDayCapacity, studioDayLoadWith } from './studio_capacity.js';
import { studioDraftFields } from './studio_assignment.js';

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
  readonly spot?: {
    readonly spotId: string;
    readonly scheduleId: string;
    readonly source: 'spot' | 'spot_slot';
    readonly slotOfferId?: string;
  };
  readonly assigneeId?: string | null;

  // slot #139 (quotes): readonly quote?: { jobId: string; quoteId: string; terms: BookingTerms };

  // slot #136 (studio): readonly providerType?: ProviderType | null;
  readonly providerType?: ProviderType | null;

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
    ...studioDraftFields(i, core),

    // #194: spot fields; a studio's spot booking comes already assigned to the schedule's member (Decision 7)
    ...spotDraftFields(i),

    ...addonDraftFields(i),
  };
}

function spotDraftFields(i: BookingDraftInput): Partial<Booking> {
  if (!i.spot) return {};
  const at = i.now.toISOString();
  return {
    spotId: i.spot.spotId,
    spotScheduleId: i.spot.scheduleId,
    source: i.spot.source,
    ...(i.spot.slotOfferId ? { slotOfferId: i.spot.slotOfferId } : {}),
    ...(i.assigneeId
      ? {
          assigneeId: i.assigneeId,
          assigneeKind: 'member' as const,
          assignStatus: 'assigned' as const,
          assignedAt: at,
          assignments: [
            { assigneeId: i.assigneeId, assigneeKind: 'member' as const, at, by: i.photographerId, reason: null, late: false },
          ],
        }
      : {}),
  };
}

export async function createBookingDraft(
  deps: BookingDeps,
  rawInput: unknown,
): Promise<Booking> {
  const now = deps.clock.now();
  const input = validateCreateBookingDraftInput(rawInput, now);

  // Service check
  let service: ServiceRecord;
  if (input.slotOfferId !== undefined) {
    const preOffer = deps.store.getSlotOffer ? await deps.store.getSlotOffer(input.slotOfferId) : null;
    if (!preOffer) {
      throw new DomainError('not_found');
    }
    if (preOffer.status !== 'open') {
      throw new DomainError('outside_schedule');
    }
    service = {
      id: preOffer.id,
      photographerId: input.photographerId,
      name: preOffer.name,
      price: preOffer.price,
      durationMinutes: preOffer.slotMinutes,
      active: true,
    };
  } else {
    const s = await deps.services.getService(input.photographerId, input.serviceId);
    if (!s || !s.active || s.photographerId !== input.photographerId) {
      throw new DomainError('not_found');
    }
    service = s;
  }

  // Providers who cannot take orders yet, and blocked pairs, are not bookable. One read gives the gate
  // and the provider type (a studio's booking gets the studio fields and is held on the studio's day load).
  const profile = await deps.providers.orderProfile(input.photographerId);
  const blocker = await profileOrderBlocker(deps, profile, {
    customerId: input.customerId,
    providerId: input.photographerId,
  });
  if (blocker) throw new DomainError(blocker);
  const isStudio = profile?.providerType === 'studio';
  const memberOf = !isStudio ? (profile?.studioId ?? null) : null;

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

  const end = addMinutesToTime(input.start, service.durationMinutes);

  // 3. Transactional availability hold and booking creation
  return deps.store.runTransaction(async (tx) => {
    let ctx: {
      schedule: SpotSchedule;
      spot: Spot;
      offer: SlotOffer | null;
      spotDay: SpotDay | null;
    } | null = null;

    if (input.spotScheduleId !== undefined) {
      const schedule = await tx.getSpotSchedule(input.spotScheduleId);
      if (!schedule || schedule.providerId !== input.photographerId) {
        throw new DomainError('outside_schedule');
      }
      const spot = await tx.getSpot(schedule.spotId);
      if (!spot) {
        throw new DomainError('not_found');
      }
      let offer: SlotOffer | null = null;
      if (input.slotOfferId !== undefined) {
        offer = await tx.getSlotOffer(input.slotOfferId);
        if (!offer || offer.scheduleId !== schedule.id) {
          throw new DomainError('outside_schedule');
        }
      }
      const spotDay = await tx.getSpotDay(schedule.id, input.day);
      ctx = { schedule, spot, offer, spotDay };
    }

    const holder = ctx ? dayHolderOf(ctx.schedule) : input.photographerId;
    const day = await tx.getAvailabilityDay(holder, input.day);
    const draft = await tx.getCustomerDraftForDay(
      input.customerId,
      input.photographerId,
      input.day,
    );
    const draftDay = draft?.spotScheduleId !== undefined && draft.spotScheduleId !== input.spotScheduleId
      ? await tx.getSpotDay(draft.spotScheduleId, draft.day)
      : null;
    // A studio holds its day on the load doc, one booking per free member (Decision 26); a member's own booking
    // must leave the studio enough free members that day. A spot booking (a studio's too) holds an interval of
    // its spot day instead and never enters the load (#194 Decision 7); the load is still read when it replaces
    // the customer's earlier non-spot studio draft, to take that draft off it.
    const draftOnLoad = isStudio && draft !== null && draft.spotScheduleId === undefined;
    const loadOwner = ctx ? (draftOnLoad ? input.photographerId : null) : isStudio ? input.photographerId : memberOf;
    const load = loadOwner ? await tx.getStudioDayLoad(loadOwner, input.day) : null;
    const memberDays = loadOwner && !ctx ? await tx.getMemberDays(loadOwner, input.day) : [];

    if (ctx) {
      if (day?.state !== 'spot' || day.scheduleId !== ctx.schedule.id) {
        throw new DomainError('outside_schedule');
      }
      const own = draft?.spotScheduleId === ctx.schedule.id ? draft : null;
      const taken = (ctx.spotDay?.taken ?? []).filter((t) => !(own && t.start === own.start && t.end === own.end));
      assertSpotBooking({
        spot: ctx.spot,
        schedule: ctx.schedule,
        offer: ctx.offer,
        serviceId: service.id,
        day: input.day,
        start: input.start,
        end,
        taken,
      });
    } else if (isStudio) {
      const facts = {
        studioOff: day?.state === 'off',
        memberDays,
        unassignedIds: (load?.unassignedIds ?? []).filter((id) => id !== draft?.id),
        assignedIds: load?.assignedIds ?? [],
      };
      if (!studioDayCapacity(facts).bookable) throw new DomainError('day_taken');
    } else if (day) {
      if (day.state === 'spot' || day.state === 'off' || day.state === 'booked' || day.state === 'full') {
        throw new DomainError('day_taken');
      }
      if (day.state === 'pending') {
        // Allowed only if it is the same customer's own earlier draft (Review Focus 2)
        const isOwnDraft = draft && day.bookingId === draft.id;
        if (!isOwnDraft) {
          throw new DomainError('day_taken');
        }
      }
    }
    if (memberOf && !ctx) {
      const facts = {
        studioOff: false,
        memberDays,
        unassignedIds: load?.unassignedIds ?? [],
        assignedIds: load?.assignedIds ?? [],
      };
      if (!memberDayReleasable(facts, input.photographerId)) throw new DomainError('day_taken');
    }

    const nowIso = now.toISOString();

    // Replace customer's earlier draft if present
    if (draft) {
      await tx.deleteBooking(draft.id);
      await tx.deleteContactSnapshot(draft.id);
      if (draftDay) {
        await tx.setSpotDay(withoutInterval(draftDay, draft, nowIso));
      } else if (ctx && !draft.spotScheduleId && day && day.bookingId === draft.id) {
        // only a spot booking leaves the day without a new pending write (one write per document)
        await tx.deleteAvailabilityDay(input.photographerId, input.day);
      }
    }

    const bookingId = deps.ids.newId();
    const booking = buildBookingDraft({
      id: bookingId,
      customerId: input.customerId,
      photographerId: input.photographerId,
      service,
      day: input.day,
      start: input.start,
      place: ctx ? { name: ctx.spot.name, point: ctx.spot.point } : input.place,
      note: input.note,
      providerType: profile?.providerType ?? null,
      addons,
      pickup,
      now,
      spot: ctx
        ? {
            spotId: ctx.spot.id,
            scheduleId: ctx.schedule.id,
            source: ctx.offer ? 'spot_slot' : 'spot',
            ...(ctx.offer ? { slotOfferId: ctx.offer.id } : {}),
          }
        : undefined,
      assigneeId: ctx?.schedule.assigneeId ?? undefined,
    });

    await tx.setBooking(booking);
    const loadKey = { studioId: input.photographerId, day: input.day };
    if (ctx) {
      if (draftOnLoad && draft) {
        await tx.setStudioDayLoad(studioDayLoadWith(load, loadKey, draft.id, null, nowIso));
      }
      const base = {
        scheduleId: ctx.schedule.id,
        spotId: ctx.spot.id,
        providerId: input.photographerId,
        day: input.day,
      };
      const latest = draft?.spotScheduleId === ctx.schedule.id && ctx.spotDay
        ? withoutInterval(ctx.spotDay, draft, nowIso)
        : ctx.spotDay;
      await tx.setSpotDay(
        withInterval(
          latest,
          base,
          { start: input.start, end, ...(ctx.offer ? { offerId: ctx.offer.id } : {}) },
          nowIso,
        ),
      );
    } else if (isStudio) {
      const withoutOld = draft ? studioDayLoadWith(load, loadKey, draft.id, null, nowIso) : load;
      await tx.setStudioDayLoad(studioDayLoadWith(withoutOld, loadKey, bookingId, 'unassigned', nowIso));
    } else {
      await tx.setAvailabilityDay(input.photographerId, input.day, {
        state: 'pending',
        bookingId,
      });
    }

    await tx.setContactSnapshot(bookingId, {
      name: contactRecord?.name ?? '',
      phone,
      allowZalo: contactRecord?.allowZalo ?? false,
      allowWhatsApp: contactRecord?.allowWhatsApp ?? false,
    });

    return booking;
  });
}


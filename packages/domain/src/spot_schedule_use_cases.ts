/**
 * Spot schedule and slot offer use cases (spec S29).
 */

import { DomainError } from './errors.js';
import { isId } from './ids.js';
import { formatVnDate } from './booking_policy.js';
import {
  dayConflicts,
  dayHolderOf,
  priceFromOf,
  scheduleEditBlocks,
  validateScheduleInput,
  MAX_OPEN_SCHEDULES,
  type SpotSchedule,
} from './spot_schedule.js';
import {
  slotsFor,
  validateSlotOfferInput,
  MAX_OFFERS_PER_SCHEDULE,
  type SlotOffer,
} from './spot_slots.js';
import type { SpotScheduleDeps } from './spot_schedule_ports.js';
import type { AvailabilityDayRecord, SpotDay } from './index.js';

export async function saveSpotSchedule(
  deps: SpotScheduleDeps,
  callerId: string,
  raw: unknown,
): Promise<{ scheduleId: string; addedDays: string[] }> {
  const now = deps.clock.now();
  const nowIso = now.toISOString();
  const today = formatVnDate(now);

  const input = validateScheduleInput(raw, today);

  const profile = await deps.providers.orderProfile(callerId);
  if (!profile) {
    throw new DomainError('permission_denied');
  }
  if (!profile.acceptsOrders) {
    throw new DomainError('not_accepting_orders');
  }

  const isStudio = profile.providerType === 'studio';
  if (isStudio !== (input.assigneeId !== undefined)) {
    throw new DomainError('invalid_argument', 'assigneeId');
  }

  if (isStudio) {
    const assigneeId = input.assigneeId;
    if (!assigneeId) {
      throw new DomainError('invalid_argument', 'assigneeId');
    }
    const rel = await deps.roster.relationOf(callerId, assigneeId);
    if (rel !== 'member') {
      throw new DomainError('invalid_argument', 'assigneeId');
    }
    const memberAccepts = await deps.providers.acceptsOrders(assigneeId);
    if (!memberAccepts) {
      throw new DomainError('not_accepting_orders', 'assigneeId');
    }
  }

  const holderId = input.assigneeId ?? callerId;

  return deps.schedules.runTransaction(async (tx) => {
    await tx.lockProvider(callerId);

    const spot = await tx.getSpot(input.spotId);
    if (!spot) {
      throw new DomainError('not_found', 'spotId');
    }
    if (spot.status !== 'active') {
      throw new DomainError('spot_archived');
    }

    let existing: SpotSchedule | null = null;
    if (input.scheduleId !== undefined) {
      existing = await tx.getSchedule(input.scheduleId);
      if (!existing || existing.providerId !== callerId || existing.status !== 'open') {
        throw new DomainError('not_found');
      }
      if (existing.spotId !== input.spotId || existing.assigneeId !== (input.assigneeId ?? null)) {
        throw new DomainError('invalid_argument', 'spotId');
      }
    }

    const open = await tx.openSchedulesOf(callerId, today);
    if (!existing && open.length >= MAX_OPEN_SCHEDULES) {
      throw new DomainError('schedule_limit');
    }

    const activeSrvs = await tx.activeServices(callerId);
    const priceFrom = priceFromOf(activeSrvs, input.serviceIds);

    const existingDays = existing ? existing.days : [];
    const addedDays = input.days.filter((d) => !existingDays.includes(d));
    const removedDays = existingDays.filter((d) => !input.days.includes(d));

    const availRecords = new Map<string, AvailabilityDayRecord | null>();
    for (const d of input.days) {
      availRecords.set(d, await tx.availability(holderId, d));
    }
    const conflicts = dayConflicts(input.days, availRecords, existing?.id ?? null);
    if (conflicts.length > 0) {
      throw new DomainError('day_conflict', 'days', { days: conflicts });
    }

    if (existing) {
      const spotDaysToCheck = new Map<string, SpotDay | null>();
      const allDaysToInspect = Array.from(new Set([...existingDays, ...input.days]));
      for (const d of allDaysToInspect) {
        spotDaysToCheck.set(d, await tx.getSpotDay(existing.id, d));
      }
      const blocks = scheduleEditBlocks(removedDays, input.window, spotDaysToCheck);
      if (blocks.length > 0) {
        throw new DomainError('schedule_has_bookings', 'days', { days: blocks });
      }
    }

    const scheduleId = existing ? existing.id : deps.ids.newId();

    tx.touchLock(callerId, nowIso);

    for (const d of addedDays) {
      tx.setSpotAvailability(holderId, d, { scheduleId, spotId: input.spotId }, nowIso);
    }

    for (const d of removedDays) {
      if (d >= today) {
        tx.deleteAvailability(holderId, d);
      }
    }

    const pastDays = existingDays.filter((d) => d < today);
    const finalDays = Array.from(new Set([...pastDays, ...input.days])).sort();

    const newSchedule: SpotSchedule = {
      id: scheduleId,
      providerId: callerId,
      assigneeId: input.assigneeId ?? null,
      spotId: input.spotId,
      days: finalDays,
      window: input.window,
      serviceIds: input.serviceIds,
      priceFrom,
      status: 'open',
      createdAt: existing ? existing.createdAt : nowIso,
      updatedAt: nowIso,
    };
    tx.putSchedule(newSchedule);

    return { scheduleId, addedDays };
  });
}

export async function cancelSpotSchedule(
  deps: SpotScheduleDeps,
  callerId: string,
  raw: unknown,
): Promise<Record<string, never>> {
  if (!raw || typeof raw !== 'object') {
    throw new DomainError('invalid_argument');
  }
  const scheduleId = (raw as Record<string, unknown>).scheduleId;
  if (typeof scheduleId !== 'string' || !isId(scheduleId)) {
    throw new DomainError('invalid_argument', 'scheduleId');
  }

  const now = deps.clock.now();
  const nowIso = now.toISOString();
  const today = formatVnDate(now);

  return deps.schedules.runTransaction(async (tx) => {
    await tx.lockProvider(callerId);

    const schedule = await tx.getSchedule(scheduleId);
    if (!schedule || schedule.providerId !== callerId || schedule.status !== 'open') {
      throw new DomainError('not_found');
    }

    const holderId = dayHolderOf(schedule);

    for (const d of schedule.days) {
      const sd = await tx.getSpotDay(schedule.id, d);
      if (sd && sd.taken.length > 0) {
        throw new DomainError('schedule_has_bookings');
      }
    }

    const offers = await tx.offersOf(schedule.id);

    // Writes start here
    for (const d of schedule.days) {
      if (d >= today) {
        tx.deleteAvailability(holderId, d);
      }
    }

    for (const o of offers) {
      if (o.status === 'open') {
        tx.putOffer({ ...o, status: 'closed', updatedAt: nowIso });
      }
    }

    tx.putSchedule({ ...schedule, status: 'cancelled', updatedAt: nowIso });
    tx.touchLock(callerId, nowIso);

    return {};
  });
}

export async function saveSlotOffer(
  deps: SpotScheduleDeps,
  callerId: string,
  raw: unknown,
): Promise<{ offerId: string }> {
  const input = validateSlotOfferInput(raw);

  const profile = await deps.providers.orderProfile(callerId);
  if (!profile) {
    throw new DomainError('permission_denied');
  }
  if (!profile.acceptsOrders) {
    throw new DomainError('not_accepting_orders');
  }

  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.schedules.runTransaction(async (tx) => {
    await tx.lockProvider(callerId);

    const schedule = await tx.getSchedule(input.scheduleId);
    if (!schedule || schedule.providerId !== callerId || schedule.status !== 'open') {
      throw new DomainError('not_found');
    }

    const spot = await tx.getSpot(schedule.spotId);
    if (!spot || spot.status !== 'active') {
      throw new DomainError('spot_archived');
    }

    const slots = slotsFor(schedule.window, input.slotMinutes, input.gapMinutes);
    if (slots.length === 0) {
      throw new DomainError('invalid_argument', 'slotMinutes');
    }

    let existingOffer: SlotOffer | null = null;
    if (input.offerId !== undefined) {
      existingOffer = await tx.getOffer(input.offerId);
      if (!existingOffer || existingOffer.scheduleId !== schedule.id || existingOffer.providerId !== callerId) {
        throw new DomainError('not_found');
      }
    }

    const allOffers = await tx.offersOf(schedule.id);
    const openOffers = allOffers.filter((o) => o.status === 'open');
    if (!existingOffer && openOffers.length >= MAX_OFFERS_PER_SCHEDULE) {
      throw new DomainError('limit_exceeded');
    }

    const offerId = existingOffer ? existingOffer.id : deps.ids.newId();
    const offer: SlotOffer = {
      id: offerId,
      providerId: callerId,
      scheduleId: schedule.id,
      spotId: schedule.spotId,
      name: input.name,
      price: input.price,
      slotMinutes: input.slotMinutes,
      gapMinutes: input.gapMinutes,
      photoCount: input.photoCount,
      editedCount: input.editedCount,
      deliveryDays: input.deliveryDays,
      status: 'open',
      createdAt: existingOffer ? existingOffer.createdAt : nowIso,
      updatedAt: nowIso,
    };

    tx.putOffer(offer);
    tx.touchLock(callerId, nowIso);

    return { offerId };
  });
}

export async function closeSlotOffer(
  deps: SpotScheduleDeps,
  callerId: string,
  raw: unknown,
): Promise<Record<string, never>> {
  if (!raw || typeof raw !== 'object') {
    throw new DomainError('invalid_argument');
  }
  const offerId = (raw as Record<string, unknown>).offerId;
  if (typeof offerId !== 'string' || !isId(offerId)) {
    throw new DomainError('invalid_argument', 'offerId');
  }

  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.schedules.runTransaction(async (tx) => {
    await tx.lockProvider(callerId);

    const offer = await tx.getOffer(offerId);
    if (!offer || offer.providerId !== callerId) {
      throw new DomainError('not_found');
    }

    if (offer.status === 'closed') {
      return {};
    }

    tx.putOffer({ ...offer, status: 'closed', updatedAt: nowIso });
    tx.touchLock(callerId, nowIso);

    return {};
  });
}

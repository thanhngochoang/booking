import type { EventCaller } from '../../src/event.js';
import type { EntryItem } from '../../src/entry_tickets.js';
import { publishEvent, saveEventDraft } from '../../src/event_use_cases.js';
import { registerEntry } from '../../src/event_registration.js';
import { createTicketPaymentWorld, type TicketPaymentWorld } from './event_world.js';
import { createNotifyWorld, type NotifyWorld } from './notify_world.js';
import { organizerOf, spotOf } from './organizer_world.js';

/** Sunday 2026-10-18, 10:00 in Vietnam. */
export const ENTRY_NOW = new Date('2026-10-18T03:00:00.000Z');
export const ENTRY_TODAY = '2026-10-18';
export const ENTRY_ID = 'en1_aaaaaaaaaaaaaaaaaaaa';
/** A Thursday inside the range. */
export const VISIT = '2026-10-22';
export const HOUR = 3_600_000;

export const org1: EventCaller = { uid: 'org1', staffRole: null };
export const org2: EventCaller = { uid: 'org2', staffRole: null };
export const org3: EventCaller = { uid: 'org3', staffRole: null };

export const SPOT_COVER = { url: 'https://storage.test/spotCovers/s1/cover.jpg', cardUrl: 'https://storage.test/spotCovers/s1/card.jpg', path: 'spotCovers/s1/cover.jpg' };

export interface EntryWorld extends TicketPaymentWorld {
  readonly notify: NotifyWorld;
}

/**
 * The event world plus organizers: org1 manages spot s1 and can sell; org2 is an active organizer
 * that manages nothing; org3 manages s2 without a verified business. Customers cu1…cu5 have phones.
 */
export function createEntryWorld(): EntryWorld {
  const w = createTicketPaymentWorld();
  w.clock.set(ENTRY_NOW);
  w.store.spots.set('s1', spotOf('s1', { name: 'Bãi đá sông Hồng', managedBy: 'org1', cover: SPOT_COVER, areaCode: 'hn' }));
  w.store.spots.set('s2', spotOf('s2', { managedBy: 'org3' }));
  w.store.organizers.set('org1', organizerOf('org1', { name: 'Bãi đá sông Hồng', businessVerified: true, payoutAccountOk: true, managedSpotIds: ['s1'] }));
  w.store.organizers.set('org2', organizerOf('org2', { businessVerified: true, payoutAccountOk: true }));
  w.store.organizers.set('org3', organizerOf('org3', { managedSpotIds: ['s2'] }));
  const notify = createNotifyWorld(ENTRY_NOW);
  return { ...w, notify };
}

export function entryRaw(over: Record<string, unknown> = {}, eventId = ENTRY_ID): Record<string, unknown> {
  return {
    eventId,
    type: 'entry',
    title: 'Vé vào cửa Bãi đá',
    spotId: 's1',
    startAt: ENTRY_TODAY,
    endAt: '2026-12-31',
    closedWeekdays: [1],
    closedDays: ['2026-10-25'],
    openHours: { start: '08:00', end: '17:00' },
    ticketTypes: [
      { id: 'adult', name: 'Người lớn', price: 70_000 },
      { id: 'child', name: 'Trẻ em', price: 40_000 },
    ],
    dailyCapacity: 10,
    ...over,
  };
}

/** Saves and publishes org1's entry event on s1. */
export async function publishedEntry(w: EntryWorld, over: Record<string, unknown> = {}, caller: EventCaller = org1): Promise<string> {
  const { eventId } = await saveEventDraft(w.deps, caller, entryRaw(over));
  await publishEvent(w.deps, caller, { eventId });
  return eventId;
}

export const buy = (w: EntryWorld, caller: EventCaller, items: EntryItem[] = [{ ticketTypeId: 'adult', qty: 1 }], visitDay = VISIT) =>
  registerEntry(w.deps, caller, { eventId: ENTRY_ID, visitDay, items, name: 'Nguyễn An', method: 'bank_qr' });

/** Buys and pays (exact transfer); returns the registration id. */
export async function bought(w: EntryWorld, caller: EventCaller, items?: EntryItem[], visitDay = VISIT): Promise<string> {
  const r = await buy(w, caller, items, visitDay);
  await w.payTicket(r.paymentId as string, 'exact', caller);
  return r.registrationId;
}

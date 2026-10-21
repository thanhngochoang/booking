/**
 * A studio takes one booking per free member per day (#136 Decision 26, owner 2026-10-07). Pure.
 */

/** What decides a studio's day. */
export interface StudioDayFacts {
  /** The studio marked the day `off`: it takes nothing. */
  readonly studioOff: boolean;
  /** Active members; `verified` = may be assigned, `free` = their own day record is empty. */
  readonly memberDays: readonly { readonly uid: string; readonly verified: boolean; readonly free: boolean }[];
  /** This studio's open bookings of the day without assignee (drafts included). */
  readonly unassignedIds: readonly string[];
  /** This studio's open bookings of the day with an assignee (their member's day holds them). */
  readonly assignedIds: readonly string[];
}

export interface StudioDayCapacity {
  readonly freeMembers: number;
  readonly capacity: number;
  readonly load: number;
  /** A new studio booking fits. */
  readonly bookable: boolean;
  /** The day shows as full ("Hết chỗ"). */
  readonly full: boolean;
}

export function studioDayCapacity(f: StudioDayFacts): StudioDayCapacity {
  const freeMembers = f.memberDays.filter((m) => m.verified && m.free).length;
  const capacity = freeMembers + f.assignedIds.length;
  const load = f.unassignedIds.length + f.assignedIds.length;
  return {
    freeMembers,
    capacity,
    load,
    bookable: !f.studioOff && f.unassignedIds.length < freeMembers,
    full: f.studioOff || load >= capacity,
  };
}

/**
 * Whether `memberUid` may fill their own day (a personal booking) without leaving the studio short: with the
 * member counted free, the studio's unassigned bookings must still fit in the other free members. An unverified
 * or unknown member adds no capacity, so they are always releasable.
 */
export function memberDayReleasable(f: StudioDayFacts, memberUid: string): boolean {
  const me = f.memberDays.find((m) => m.uid === memberUid);
  if (!me || !me.verified) return true;
  const freeWithMe = f.memberDays.filter((m) => m.verified && (m.free || m.uid === memberUid)).length;
  return f.unassignedIds.length <= freeWithMe - 1;
}

/**
 * What the derived `availability/{studioId}/days/{day}` record should become: `set_full` when the day is full and
 * not yet marked, `clear_full` when a place freed up, null when nothing changes. A studio `off` day is the
 * studio's own record and is never touched.
 */
export function studioDayMark(
  current: { readonly state: string } | null,
  f: StudioDayFacts,
): 'set_full' | 'clear_full' | null {
  if (current?.state === 'off' || f.studioOff) return null;
  const full = studioDayCapacity(f).full;
  if (full && current?.state !== 'full') return 'set_full';
  if (!full && current?.state === 'full') return 'clear_full';
  return null;
}

/**
 * The studio's day load with `bookingId` moved to `where` (null = removed from both lists). The other ids keep
 * their order; a missing load starts empty.
 */
export function studioDayLoadWith(
  load: { readonly unassignedIds: readonly string[]; readonly assignedIds: readonly string[] } | null,
  key: { readonly studioId: string; readonly day: string },
  bookingId: string,
  where: 'unassigned' | 'assigned' | null,
  nowIso: string,
): { studioId: string; day: string; unassignedIds: string[]; assignedIds: string[]; updatedAt: string } {
  const unassignedIds = (load?.unassignedIds ?? []).filter((id) => id !== bookingId);
  const assignedIds = (load?.assignedIds ?? []).filter((id) => id !== bookingId);
  if (where === 'unassigned') unassignedIds.push(bookingId);
  if (where === 'assigned') assignedIds.push(bookingId);
  return { studioId: key.studioId, day: key.day, unassignedIds, assignedIds, updatedAt: nowIso };
}

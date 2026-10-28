/**
 * In-memory reference implementation of OrganizerStore (S30, #223): serialized transactions, writes
 * staged until the function returns, and no reads after the first write (like `MemorySpotStore`).
 */

import type { EventRecord } from './event.js';
import type { GateStaff, Organizer, Resident, SpotClaim } from './organizer.js';
import { ANY_ORGANIZER, type ExpiredResidentRef, type OrganizerStore, type OrganizerTx } from './organizer_ports.js';
import type { Spot } from './spot.js';

const CLOSED_EVENT = new Set(['cancelled', 'completed']);

export class MemoryOrganizerStore implements OrganizerStore {
  readonly organizers = new Map<string, Organizer>();
  readonly spots = new Map<string, Spot>();
  readonly claims = new Map<string, SpotClaim>();
  /** spotId → providerId → resident. */
  readonly residents = new Map<string, Map<string, Resident>>();
  /** organizerId → staffUid → row. */
  readonly gateStaff = new Map<string, Map<string, GateStaff>>();
  /** Committed write count. */
  writes = 0;

  private queue: Promise<unknown> = Promise.resolve();

  /** `events` is the event store's map (a shared view), read by `openEventsOf`. */
  constructor(private readonly events: ReadonlyMap<string, EventRecord> = new Map()) {}

  seedOrganizer(o: Organizer): void {
    this.organizers.set(o.id, { ...o });
  }

  seedSpot(s: Spot): void {
    this.spots.set(s.id, { ...s });
  }

  seedClaim(c: SpotClaim): void {
    this.claims.set(c.id, { ...c });
  }

  seedResident(spotId: string, r: Resident): void {
    this.residentMap(spotId).set(r.providerId, { ...r });
  }

  seedGateStaff(organizerId: string, g: GateStaff): void {
    this.staffMap(organizerId).set(g.staffUid, { ...g });
  }

  residentsOfSync(spotId: string): Resident[] {
    return [...(this.residents.get(spotId)?.values() ?? [])].map((r) => ({ ...r }));
  }

  gateStaffOfSync(organizerId: string): GateStaff[] {
    return [...(this.gateStaff.get(organizerId)?.values() ?? [])].map((g) => ({ ...g }));
  }

  private residentMap(spotId: string): Map<string, Resident> {
    let m = this.residents.get(spotId);
    if (!m) {
      m = new Map();
      this.residents.set(spotId, m);
    }
    return m;
  }

  private staffMap(organizerId: string): Map<string, GateStaff> {
    let m = this.gateStaff.get(organizerId);
    if (!m) {
      m = new Map();
      this.gateStaff.set(organizerId, m);
    }
    return m;
  }

  async getOrganizer(uid: string): Promise<Organizer | null> {
    const o = this.organizers.get(uid);
    return o ? { ...o } : null;
  }

  async expiredResidents(today: string, limit: number): Promise<ExpiredResidentRef[]> {
    const out: ExpiredResidentRef[] = [];
    for (const [spotId, rows] of this.residents) {
      for (const r of rows.values()) {
        if (r.validUntil !== null && r.validUntil < today) out.push({ spotId, providerId: r.providerId });
      }
    }
    return out.slice(0, limit);
  }

  async runTransaction<T>(fn: (tx: OrganizerTx) => Promise<T>): Promise<T> {
    const run = async () => {
      const staged: Array<() => void> = [];
      let hasWritten = false;

      const read = <R>(name: string, get: () => R): Promise<R> => {
        if (hasWritten) throw new Error(`Transaction read after write: ${name} called after a write operation`);
        return Promise.resolve(get());
      };
      const write = (apply: () => void): void => {
        hasWritten = true;
        staged.push(apply);
      };

      const tx: OrganizerTx = {
        getOrganizer: (uid) => read('getOrganizer', () => {
          const o = this.organizers.get(uid);
          return o ? { ...o } : null;
        }),
        putOrganizer: (o) => write(() => this.organizers.set(o.id, { ...o })),
        getSpot: (id) => read('getSpot', () => {
          const s = this.spots.get(id);
          return s ? { ...s } : null;
        }),
        putSpot: (s) => write(() => this.spots.set(s.id, { ...s })),
        getClaim: (id) => read('getClaim', () => {
          const c = this.claims.get(id);
          return c ? { ...c } : null;
        }),
        pendingClaimsOf: (spotId, organizerId) => read('pendingClaimsOf', () =>
          [...this.claims.values()]
            .filter((c) => c.status === 'pending' && c.spotId === spotId
              && (organizerId === ANY_ORGANIZER || c.organizerId === organizerId))
            .map((c) => ({ ...c }))),
        putClaim: (c) => write(() => this.claims.set(c.id, { ...c })),
        residentsOf: (spotId) => read('residentsOf', () => this.residentsOfSync(spotId)),
        getResident: (spotId, providerId) => read('getResident', () => {
          const r = this.residents.get(spotId)?.get(providerId);
          return r ? { ...r } : null;
        }),
        putResident: (spotId, r) => write(() => this.residentMap(spotId).set(r.providerId, { ...r })),
        deleteResident: (spotId, providerId) => write(() => {
          this.residents.get(spotId)?.delete(providerId);
        }),
        gateStaffOf: (organizerId) => read('gateStaffOf', () => this.gateStaffOfSync(organizerId)),
        putGateStaff: (organizerId, g) => write(() => this.staffMap(organizerId).set(g.staffUid, { ...g })),
        openEventsOf: (organizerId) => read('openEventsOf', () =>
          [...this.events.values()].filter((e) =>
            e.host.type === 'organizer' && e.host.id === organizerId && !CLOSED_EVENT.has(e.status))),
      };

      const result = await fn(tx);
      for (const apply of staged) apply();
      this.writes += staged.length;
      return result;
    };

    const next = this.queue.then(run, run);
    this.queue = next.catch(() => {});
    return next;
  }
}

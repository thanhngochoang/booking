/**
 * The unit of work of one Chụp ngay transaction (plan #140 Task 3): every use case reads and
 * settles through it, decides, then changes documents in memory; `flush` is the only writer.
 */
import type { BookingContactSnapshot } from './booking.js';
import { DomainError } from './errors.js';
import {
  isInstantActive,
  livePendingOffers,
  type InstantOffer,
  type InstantOfferRow,
  type InstantPresence,
  type InstantRequest,
  type OfferOutcome,
} from './instant.js';
import type { InstantDeps, InstantTrackDoc, InstantTx } from './instant_ports.js';
import { nextDeadlineOf, settleInstant } from './instant_settle.js';

interface Slot<T> { readonly base: T | null; cur: T | null }

/**
 * Everything one instant transaction reads and decides on: documents are read once through the
 * transaction (all reads happen before `flush`, which is the only place that writes), changed in
 * memory, and written together. Rule for the use cases: settle and read first, decide (and refuse)
 * next, change last; a refusal then keeps exactly what the settles changed.
 */
export class InstantWork {
  private readonly requests = new Map<string, Slot<InstantRequest>>();
  private readonly offers = new Map<string, Slot<InstantOffer>>();
  private readonly presences = new Map<string, Slot<InstantPresence>>();
  private side: Array<(tx: InstantTx) => void> = [];
  private mark: { requests: Map<string, InstantRequest | null>; offers: Map<string, InstantOffer | null>; presences: Map<string, InstantPresence | null>; side: number } | null = null;
  private discarded = false;

  constructor(readonly tx: InstantTx, readonly now: Date) {}

  async request(id: string): Promise<InstantRequest | null> {
    let s = this.requests.get(id);
    if (s === undefined) {
      const r = await this.tx.getRequest(id);
      s = { base: r, cur: r };
      this.requests.set(id, s);
    }
    return s.cur;
  }

  async offer(photographerId: string, offerId: string): Promise<InstantOffer | null> {
    const key = `${photographerId}/${offerId}`;
    let s = this.offers.get(key);
    if (s === undefined) {
      const o = await this.tx.getOffer(photographerId, offerId);
      s = { base: o, cur: o };
      this.offers.set(key, s);
    }
    return s.cur;
  }

  async presence(uid: string): Promise<InstantPresence | null> {
    let s = this.presences.get(uid);
    if (s === undefined) {
      const p = await this.tx.getPresence(uid);
      s = { base: p, cur: p };
      this.presences.set(uid, s);
    }
    return s.cur;
  }

  setRequest(r: InstantRequest): void {
    const s = this.requests.get(r.id);
    if (s === undefined) this.requests.set(r.id, { base: null, cur: r });
    else s.cur = r;
  }

  setOffer(o: InstantOffer): void {
    const key = `${o.photographerId}/${o.id}`;
    const s = this.offers.get(key);
    if (s === undefined) this.offers.set(key, { base: null, cur: o });
    else s.cur = o;
  }

  setPresence(p: InstantPresence): void {
    const s = this.presences.get(p.uid);
    if (s === undefined) this.presences.set(p.uid, { base: null, cur: p });
    else s.cur = p;
  }

  putTrack(requestId: string, t: InstantTrackDoc): void {
    this.side.push((tx) => tx.putTrack(requestId, t));
  }

  deleteTrack(requestId: string): void {
    this.side.push((tx) => tx.deleteTrack(requestId));
  }

  putContact(requestId: string, c: BookingContactSnapshot): void {
    this.side.push((tx) => tx.putContact(requestId, c));
  }

  deleteContact(requestId: string): void {
    this.side.push((tx) => tx.deleteContact(requestId));
  }

  /** Nothing of this transaction is written (a dry run). */
  discard(): void {
    this.discarded = true;
  }

  /**
   * Applies every timer due now to the request and the side writes of what settled: expired and
   * withdrawn offer docs, the photographers' pending entries (`reliability.expired` on expiry), and
   * on an end the assigned photographer's presence and the track. Marks the point a refusal rolls back to.
   */
  async settle(id: string): Promise<InstantRequest | null> {
    const r = await this.request(id);
    if (r === null) return null;
    const out = settleInstant(r, this.now);
    if (out.changed) {
      for (const row of out.expired) await this.closeOffer(row, 'expired');
      for (const row of out.withdrawn) await this.closeOffer(row, 'withdrawn');
      if (out.ended && out.request.photographerId !== null) {
        await this.freePresence(out.request.photographerId, id);
        this.deleteTrack(id);
      }
      this.setRequest(out.request);
    } else if ((r.nextDeadlineAt?.getTime() ?? null) !== (nextDeadlineOf(r)?.getTime() ?? null)) {
      this.setRequest({ ...r }); // a stale stored deadline would make the clock step pick it forever
    }
    this.checkpoint();
    return this.requests.get(id)?.cur ?? null;
  }

  /**
   * The offer doc of a row gets its final outcome (only while still pending) and the photographer's
   * pending entry goes; an expiry counts in `reliability.expired`, a decline in `declined`.
   */
  async closeOffer(row: Pick<InstantOfferRow, 'offerId' | 'photographerId'>, outcome: Exclude<OfferOutcome, 'pending' | 'accepted'>): Promise<void> {
    if (row.offerId === null) return;
    const offer = await this.offer(row.photographerId, row.offerId);
    const presence = await this.presence(row.photographerId);
    if (offer !== null && offer.outcome === 'pending') this.setOffer({ ...offer, outcome, decidedAt: this.now });
    if (presence !== null) {
      const rel = presence.reliability;
      this.setPresence({
        ...presence,
        pendingOffers: presence.pendingOffers.filter((p) => p.offerId !== row.offerId),
        reliability: outcome === 'expired' ? { ...rel, expired: rel.expired + 1 }
          : outcome === 'declined' ? { ...rel, declined: rel.declined + 1 } : rel,
      });
    }
  }

  /** The photographer is free again when this request was their job. */
  async freePresence(uid: string, requestId: string): Promise<InstantPresence | null> {
    const p = await this.presence(uid);
    if (p === null || p.activeRequestId !== requestId) return p;
    const next = { ...p, activeRequestId: null };
    this.setPresence(next);
    return next;
  }

  private checkpoint(): void {
    const snap = <T>(m: Map<string, Slot<T>>): Map<string, T | null> => new Map([...m].map(([k, s]) => [k, s.cur]));
    this.mark = { requests: snap(this.requests), offers: snap(this.offers), presences: snap(this.presences), side: this.side.length };
  }

  /** Back to the last settle; false when nothing was settled (then nothing is worth writing). */
  rollback(): boolean {
    if (this.mark === null || this.discarded) return false;
    const restore = <T>(m: Map<string, Slot<T>>, saved: Map<string, T | null>): void => {
      for (const [k, s] of m) {
        if (saved.has(k)) s.cur = saved.get(k) ?? null;
        else if (s.base === null) m.delete(k);
        else s.cur = s.base;
      }
    };
    restore(this.requests, this.mark.requests);
    restore(this.offers, this.mark.offers);
    restore(this.presences, this.mark.presences);
    this.side = this.side.slice(0, this.mark.side);
    return true;
  }

  /**
   * Writes every changed document. Requests get `active`, `nextDeadlineAt = nextDeadlineOf(r)`,
   * `updatedAt` and one version bump; presences drop pending entries that expired (Decision 14).
   */
  flush(): void {
    if (this.discarded) return;
    for (const s of this.requests.values()) {
      if (s.cur === null || s.cur === s.base) continue;
      const r = { ...s.cur, active: isInstantActive(s.cur.status) };
      this.tx.putRequest({
        ...r,
        nextDeadlineAt: nextDeadlineOf(r),
        updatedAt: s.base === null ? r.updatedAt : this.now,
        version: s.base === null ? r.version : s.base.version + 1,
      });
    }
    for (const s of this.offers.values()) {
      if (s.cur !== null && s.cur !== s.base) this.tx.putOffer(s.cur);
    }
    for (const s of this.presences.values()) {
      if (s.cur === null || s.cur === s.base) continue;
      this.tx.putPresence({ ...s.cur, pendingOffers: livePendingOffers(s.cur, this.now), updatedAt: this.now });
    }
    for (const write of this.side) write(this.tx);
  }
}

/**
 * One instant transaction. A DomainError refuses the call but still writes what the settles of this
 * transaction changed (an accept at 60,5 s answers `offer_expired` and the row reads "Hết hạn").
 */
export async function runInstant<T>(deps: Pick<InstantDeps, 'store' | 'clock'>, fn: (w: InstantWork) => Promise<T>): Promise<T> {
  const box: { error: DomainError | null } = { error: null };
  const result = await deps.store.runTransaction(async (tx) => {
    box.error = null;
    const w = new InstantWork(tx, deps.clock.now());
    try {
      const out = await fn(w);
      w.flush();
      return out;
    } catch (e) {
      if (!(e instanceof DomainError)) throw e;
      if (w.rollback()) w.flush();
      box.error = e;
      return undefined;
    }
  });
  if (box.error !== null) throw box.error;
  return result as T;
}

/** A read outside any decision (pre-reads for the gate, the day state and the candidates). */
export async function peekInstantRequest(deps: Pick<InstantDeps, 'store'>, id: string): Promise<InstantRequest | null> {
  return deps.store.runTransaction((tx) => tx.getRequest(id));
}

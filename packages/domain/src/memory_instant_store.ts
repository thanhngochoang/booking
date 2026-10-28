import type { BookingContactSnapshot } from './booking.js';
import type { TransferRecord } from './booking_ports.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';
import type { InstantOffer, InstantPresence, InstantRequest } from './instant.js';
import type { InstantStore, InstantTrackDoc, InstantTx, PresenceDirectory } from './instant_ports.js';

const offerKey = (photographerId: string, offerId: string): string => `${photographerId}/${offerId}`;

/**
 * In-memory InstantStore for tests and the reference of the Firestore adapter: transactions run one
 * at a time (like Firestore retrying the loser of a conflict), writes are staged and applied at the
 * end, and a read after a write in the same transaction throws.
 */
export class MemoryInstantStore implements InstantStore {
  readonly requests = new Map<string, InstantRequest>();
  /** Key `${photographerId}/${offerId}`. */
  readonly offers = new Map<string, InstantOffer>();
  readonly presences = new Map<string, InstantPresence>();
  readonly payments = new Map<string, Payment>();
  readonly refunds = new Map<string, Refund>();
  readonly ledger = new Map<string, LedgerEntry>();
  /** V1's transfer records (a `PaymentSource` with `payments` for MemoryPaymentLookup). */
  readonly transferRecords = new Map<string, TransferRecord>();
  /** `instant_requests/{id}/private/contact`, key = request id. */
  readonly contacts = new Map<string, BookingContactSnapshot>();
  /** `instant_tracks/{requestId}`. */
  readonly tracks = new Map<string, InstantTrackDoc>();
  /** Committed transactions that wrote something. */
  commits = 0;

  private queue: Promise<unknown> = Promise.resolve();

  offer(photographerId: string, offerId: string): InstantOffer | undefined {
    return this.offers.get(offerKey(photographerId, offerId));
  }

  /** Offers of one photographer, oldest first. */
  offersOf(photographerId: string): InstantOffer[] {
    return [...this.offers.values()]
      .filter((o) => o.photographerId === photographerId)
      .sort((a, b) => a.offeredAt.getTime() - b.offeredAt.getTime() || (a.id < b.id ? -1 : 1));
  }

  async findDue(now: Date, limit: number): Promise<readonly InstantRequest[]> {
    return [...this.requests.values()]
      .filter((r) => r.active && r.nextDeadlineAt !== null && r.nextDeadlineAt.getTime() <= now.getTime())
      .sort((a, b) => (a.nextDeadlineAt?.getTime() ?? 0) - (b.nextDeadlineAt?.getTime() ?? 0))
      .slice(0, limit);
  }

  runTransaction<T>(fn: (tx: InstantTx) => Promise<T>): Promise<T> {
    const run = async (): Promise<T> => this.execute(fn);
    const next = this.queue.then(run, run);
    this.queue = next.catch(() => undefined);
    return next;
  }

  private async execute<T>(fn: (tx: InstantTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    let hasWritten = false;
    const read = <V>(name: string, get: () => V): Promise<V> => {
      if (hasWritten) return Promise.reject(new Error(`Transaction read after write: ${name} called after a write operation`));
      return Promise.resolve(get());
    };
    const write = (apply: () => void): void => {
      hasWritten = true;
      staged.push(apply);
    };
    const tx: InstantTx = {
      getRequest: (id) => read('getRequest', () => this.requests.get(id) ?? null),
      getOffer: (uid, id) => read('getOffer', () => this.offers.get(offerKey(uid, id)) ?? null),
      getPresence: (uid) => read('getPresence', () => this.presences.get(uid) ?? null),
      getPayment: (id) => read('getPayment', () => this.payments.get(id) ?? null),
      getRefund: (id) => read('getRefund', () => this.refunds.get(id) ?? null),
      getTransferRecord: (id) => read('getTransferRecord', () => this.transferRecords.get(id) ?? null),
      paymentsOfRequest: (requestId) =>
        read('paymentsOfRequest', () =>
          [...this.payments.values()].filter((p) => p.subjectType === 'instant_request' && p.subjectId === requestId)),
      findActiveRequestOfCustomer: (customerId) =>
        read('findActiveRequestOfCustomer', () => [...this.requests.values()].find((r) => r.customerId === customerId && r.active) ?? null),
      putRequest: (r) => write(() => this.requests.set(r.id, r)),
      putOffer: (o) => write(() => this.offers.set(offerKey(o.photographerId, o.id), o)),
      putPresence: (p) => write(() => this.presences.set(p.uid, p)),
      putPayment: (p) => write(() => this.payments.set(p.id, p)),
      putRefund: (r) => write(() => this.refunds.set(r.id, r)),
      putLedgerEntry: (e) => write(() => this.ledger.set(e.id, e)),
      putTransferRecord: (r) => write(() => this.transferRecords.set(r.id, r)),
      putContact: (id, c) => write(() => this.contacts.set(id, c)),
      deleteContact: (id) => write(() => this.contacts.delete(id)),
      putTrack: (id, t) => write(() => this.tracks.set(id, t)),
      deleteTrack: (id) => write(() => this.tracks.delete(id)),
    };
    const result = await fn(tx);
    for (const apply of staged) apply();
    if (staged.length > 0) this.commits += 1;
    return result;
  }
}

/** PresenceDirectory over a MemoryInstantStore: `online` and the cell field filtered in memory. */
export class MemoryPresenceDirectory implements PresenceDirectory {
  /** Every query, for assertions. */
  readonly queries: Array<{ field: 'geohash5' | 'geohash4'; cells: readonly string[]; limit: number }> = [];

  constructor(private readonly store: MemoryInstantStore) {}

  async nearby(q: { field: 'geohash5' | 'geohash4'; cells: readonly string[]; limit: number }): Promise<readonly InstantPresence[]> {
    this.queries.push(q);
    return [...this.store.presences.values()]
      .filter((p) => p.online && p[q.field] !== null && q.cells.includes(p[q.field] as string))
      .sort((a, b) => (a.uid < b.uid ? -1 : a.uid > b.uid ? 1 : 0))
      .slice(0, q.limit);
  }
}

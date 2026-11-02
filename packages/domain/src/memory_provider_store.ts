import type {
  ProviderProfile,
  ProviderStore,
  ProviderTx,
  StudioAddress,
} from './provider_ports.js';
import type { ProviderType } from './provider_type.js';

export class MemoryProviderStore implements ProviderStore {
  readonly profiles = new Map<string, ProviderProfile>();
  readonly studioAddresses = new Map<string, StudioAddress>();
  /** Seed: number of requested | accepted | upcoming | shooting bookings per photographer. */
  readonly activeBookings = new Map<string, number>();
  /** Seed: number of held | partially_refunded | disputed payments per payee. */
  readonly heldPayments = new Map<string, number>();
  /** Seed: number of open studio relations (as studio or member) per uid. */
  readonly openRelations = new Map<string, number>();
  /** Committed write count. */
  writes = 0;
  /** Order of committed writes (tests may append hook calls too). */
  readonly log: string[] = [];

  seedProfile(p: ProviderProfile): void {
    this.profiles.set(p.uid, p);
  }

  async runTransaction<T>(fn: (tx: ProviderTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    let hasWritten = false;

    const guardRead = (name: string): void => {
      if (hasWritten) {
        throw new Error(`Transaction read after write: ${name} called after a write operation`);
      }
    };

    const tx: ProviderTx = {
      getProfile: async (uid) => {
        guardRead('getProfile');
        return this.profiles.get(uid) ?? null;
      },
      countActiveBookings: async (uid) => {
        guardRead('countActiveBookings');
        return this.activeBookings.get(uid) ?? 0;
      },
      countHeldPayments: async (uid) => {
        guardRead('countHeldPayments');
        return this.heldPayments.get(uid) ?? 0;
      },
      countOpenRelations: async (uid) => {
        guardRead('countOpenRelations');
        return this.openRelations.get(uid) ?? 0;
      },
      setProviderType: (uid: string, type: ProviderType): void => {
        hasWritten = true;
        staged.push(() => {
          const p = this.profiles.get(uid);
          if (p === undefined) return;
          this.profiles.set(uid, {
            ...p,
            providerType: type,
            artistSince: type === 'artist' ? p.artistSince : null,
          });
          this.writes += 1;
          this.log.push('setProviderType');
        });
      },
      setStudioAddress: (uid: string, a: StudioAddress): void => {
        hasWritten = true;
        staged.push(() => {
          const p = this.profiles.get(uid);
          if (p === undefined) return;
          this.studioAddresses.set(uid, a);
          this.profiles.set(uid, { ...p, studioDistrict: a.district, studioCity: a.city });
          this.writes += 1;
          this.log.push('setStudioAddress');
        });
      },
    };

    const result = await fn(tx);
    for (const apply of staged) apply();
    return result;
  }
}

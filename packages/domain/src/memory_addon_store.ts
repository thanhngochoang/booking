import type { ServiceAddon } from './addon.js';
import type { AddonCatalog, AddonStore, AddonTx } from './addon_ports.js';

export class MemoryAddonStore implements AddonStore, AddonCatalog {
  /** Uids that are providers (photographers/{uid} exists and role == photographer). */
  readonly providers = new Set<string>();
  /** Key: `${providerId}/${addonId}`. */
  readonly addons = new Map<string, ServiceAddon>();
  /** Lock document `photographers/{uid}/private/addons`. */
  readonly locks = new Map<string, { activeCount: number; updatedAt: string }>();
  /** Committed write count. */
  writes = 0;

  private chain: Promise<unknown> = Promise.resolve();

  seedAddon(a: ServiceAddon): void {
    this.addons.set(`${a.providerId}/${a.id}`, a);
  }

  async listAddons(providerId: string): Promise<ServiceAddon[]> {
    return [...this.addons.values()]
      .filter((a) => a.providerId === providerId)
      .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  }

  /** Transactions run one at a time, like Firestore retrying a conflict on the lock document. */
  runTransaction<T>(fn: (tx: AddonTx) => Promise<T>): Promise<T> {
    const run = this.chain.then(() => this.execute(fn));
    this.chain = run.catch(() => undefined);
    return run;
  }

  private async execute<T>(fn: (tx: AddonTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    let hasWritten = false;
    let locked = false;
    const guardRead = (name: string): void => {
      if (hasWritten) throw new Error(`Transaction read after write: ${name} called after a write operation`);
    };
    const guardWrite = (name: string): void => {
      if (!locked) throw new Error(`lockProvider must be called before ${name}`);
      hasWritten = true;
    };

    const tx: AddonTx = {
      isProvider: async (uid) => {
        guardRead('isProvider');
        return this.providers.has(uid);
      },
      listAddons: async (providerId) => {
        guardRead('listAddons');
        return this.listAddons(providerId);
      },
      lockProvider: async () => {
        guardRead('lockProvider');
        locked = true;
      },
      putAddon: (a) => {
        guardWrite('putAddon');
        staged.push(() => {
          this.addons.set(`${a.providerId}/${a.id}`, a);
          this.writes += 1;
        });
      },
      deleteAddon: (providerId, addonId) => {
        guardWrite('deleteAddon');
        staged.push(() => {
          this.addons.delete(`${providerId}/${addonId}`);
          this.writes += 1;
        });
      },
      setActiveCount: (providerId, n, now) => {
        guardWrite('setActiveCount');
        staged.push(() => {
          this.locks.set(providerId, { activeCount: n, updatedAt: now });
          this.writes += 1;
        });
      },
    };

    const result = await fn(tx);
    for (const apply of staged) apply();
    return result;
  }
}

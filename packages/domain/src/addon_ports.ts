import type { ServiceAddon } from './addon.js';
import type { ServiceCatalog } from './booking_ports.js';
import type { Clock, IdGenerator } from './ports.js';

export interface AddonTx {
  /** photographers/{uid} exists and users/{uid}.role == 'photographer'. */
  isProvider(uid: string): Promise<boolean>;
  /** All add-ons of the provider, active or not, ordered by id. */
  listAddons(providerId: string): Promise<ServiceAddon[]>;
  /** Reads then writes photographers/{uid}/private/addons (Decision 8). Call before any write. */
  lockProvider(providerId: string): Promise<void>;
  putAddon(a: ServiceAddon): void;
  deleteAddon(providerId: string, addonId: string): void;
  setActiveCount(providerId: string, n: number, now: string): void;
}

export interface AddonStore {
  runTransaction<T>(fn: (tx: AddonTx) => Promise<T>): Promise<T>;
}

/** Read side used by createBookingDraft (outside its transaction, like ServiceCatalog). */
export interface AddonCatalog {
  listAddons(providerId: string): Promise<ServiceAddon[]>;
}

export interface AddonDeps {
  readonly addons: AddonStore;
  readonly services: ServiceCatalog;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

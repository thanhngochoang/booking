import type { Clock } from './ports.js';
import type { ProviderType } from './provider_type.js';

export interface ProviderProfile {
  readonly uid: string;
  readonly providerType: ProviderType;
  readonly onboardingComplete: boolean;
  readonly artistSince: Date | null;
  readonly studioDistrict: string | null;
  readonly studioCity: string | null;
  /** Studio: active members (`photographers/{uid}.memberCount`, absent = 0). */
  readonly memberCount: number;
}

export interface StudioAddress {
  readonly line: string;
  readonly ward: string | null;
  readonly district: string;
  readonly city: string;
  readonly lat: number | null;
  readonly lng: number | null;
}

export interface ProviderTx {
  getProfile(uid: string): Promise<ProviderProfile | null>;
  /** Bookings where photographerId = uid in requested | accepted | upcoming. */
  countActiveBookings(uid: string): Promise<number>;
  /** Payments where payeeId = uid in escrowStatus held | partially_refunded | disputed. */
  countHeldPayments(uid: string): Promise<number>;
  /** `studio_members` with studioId = uid or memberId = uid in invited | requested | active (#136 Decision 7). */
  countOpenRelations(uid: string): Promise<number>;
  /** Also clears artistSince when type != 'artist'. */
  setProviderType(uid: string, type: ProviderType, now: Date): void;
  /** Private doc + public district/city. */
  setStudioAddress(uid: string, a: StudioAddress, now: Date): void;
}

export interface ProviderStore {
  runTransaction<T>(fn: (tx: ProviderTx) => Promise<T>): Promise<T>;
}

export interface ProviderDeps {
  readonly providers: ProviderStore;
  readonly clock: Clock;
  /** Plan B1 fills this; here a no-op. Runs after the transaction commits. */
  readonly recomputeArtistTier: (uid: string) => Promise<void>;
}

import type { ProviderType } from './provider_type.js';
import type { Clock, IdGenerator } from './ports.js';
import type {
  IdentityMethod,
  IdentityRecord,
  VerificationRecord,
} from './verification.js';

export interface ProviderVerificationView {
  readonly providerType: ProviderType;
  readonly onboardingComplete: boolean;
  readonly verified: boolean;
  readonly businessVerified: boolean;
}

export interface VerificationAuditEntry {
  readonly id: string;
  readonly uid: string;
  readonly target: 'identity' | 'business';
  readonly action: string;
  readonly reason: string | null;
  readonly note: string | null;
  readonly actorId: string | null;
  readonly otherUid?: string;
  readonly at: string;
}

export interface VerificationTx {
  getVerification(uid: string): Promise<VerificationRecord | null>;
  getProvider(uid: string): Promise<ProviderVerificationView | null>;
  getContact(uid: string): Promise<{ phone: string | null; phoneVerified: boolean }>;
  getIdentity(uid: string): Promise<IdentityRecord | null>;
  identityOwner(idHash: string): Promise<string | null>;
  putVerification(r: VerificationRecord): void;
  setProviderFlags(
    uid: string,
    patch: { verified?: boolean; verifiedAt?: string | null; acceptingOrders?: boolean; businessVerified?: boolean },
  ): void;
  setPhoneVerified(uid: string): void;
  putIdentity(uid: string, r: IdentityRecord): void;
  putIdentityHash(idHash: string, uid: string): void;
  addAudit(e: VerificationAuditEntry): void;
}

export interface VerificationStore {
  runTransaction<T>(fn: (tx: VerificationTx) => Promise<T>): Promise<T>;
  dueForNudge(cutoff: Date, limit: number): Promise<VerificationRecord[]>;
  queue(target: 'identity' | 'business', limit: number): Promise<VerificationRecord[]>;
}

export interface AuthPhoneReader {
  verifiedPhoneOf(uid: string): Promise<string | null>;
}

export interface IdentityResult {
  readonly passed: boolean;
  readonly legalName: string;
  readonly dob: string;
  readonly gender: 'male' | 'female' | null;
  readonly idNumber: string;
  readonly provider: string;
  readonly providerRef: string;
}

export interface IdentityVerifier {
  start(uid: string, method: IdentityMethod): Promise<{ sessionId: string; redirectUrl: string | null }>;
  result(uid: string, sessionId: string): Promise<IdentityResult>;
}

export interface IdentityVault {
  hashId(idNumber: string): Promise<string>;
  encryptId(idNumber: string): Promise<string>;
}

export interface TaxCodeInfo {
  readonly name: string;
  readonly address: string;
  readonly status: 'active' | 'inactive';
  readonly kind: 'company' | 'household';
}

export interface TaxCodeLookup {
  lookup(taxCode: string): Promise<TaxCodeInfo | null>;
}

export interface VerificationDeps {
  readonly store: VerificationStore;
  readonly authPhones: AuthPhoneReader;
  readonly identity: IdentityVerifier | null;
  readonly vault: IdentityVault | null;
  readonly taxCodes: TaxCodeLookup | null;
  readonly feeRequired: boolean;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

export interface StaffCaller {
  readonly uid: string;
  readonly isAdmin: boolean;
}

import type { TransferRecord } from './booking_ports.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';
import type { PaymentSource } from './memory_payment_lookup.js';
import type {
  IdentityRecord,
  VerificationRecord,
} from './verification.js';
import type {
  OrganizerVerificationView,
  ProviderVerificationView,
  VerificationAuditEntry,
  VerificationStore,
  VerificationTx,
} from './verification_ports.js';

export class MemoryVerificationStore implements VerificationStore, PaymentSource {
  readonly verifications = new Map<string, VerificationRecord>();
  readonly providers = new Map<string, ProviderVerificationView>();
  /** `organizers/{uid}` as S21.04 sees it (S30). */
  readonly organizers = new Map<string, OrganizerVerificationView>();
  readonly organizerFlags = new Map<string, { businessVerified?: boolean }>();
  readonly contacts = new Map<string, { phone: string | null; phoneVerified: boolean }>();
  readonly identities = new Map<string, IdentityRecord>();
  readonly identityHashes = new Map<string, string>(); // hash -> uid
  readonly audits: VerificationAuditEntry[] = [];
  readonly providerFlags = new Map<string, { verified?: boolean; verifiedAt?: string | null; acceptingOrders?: boolean; businessVerified?: boolean }>();
  // The verification fee (#203); also a PaymentSource for MemoryPaymentLookup.
  readonly payments = new Map<string, Payment>();
  readonly refunds = new Map<string, Refund>();
  readonly ledger: LedgerEntry[] = [];
  readonly transferRecords = new Map<string, TransferRecord>();

  async runTransaction<T>(fn: (tx: VerificationTx) => Promise<T>): Promise<T> {
    const stagedVerifications = new Map<string, VerificationRecord>();
    const stagedProviderFlags = new Map<string, { verified?: boolean; verifiedAt?: string | null; acceptingOrders?: boolean; businessVerified?: boolean }>();
    const stagedOrganizerFlags = new Map<string, { businessVerified?: boolean }>();
    const stagedPhoneVerified = new Set<string>();
    const stagedIdentities = new Map<string, IdentityRecord>();
    const stagedHashes = new Map<string, string>();
    const stagedAudits: VerificationAuditEntry[] = [];
    const stagedPayments = new Map<string, Payment>();
    const stagedRefunds = new Map<string, Refund>();
    const stagedLedger: LedgerEntry[] = [];
    const stagedTransferRecords = new Map<string, TransferRecord>();

    const tx: VerificationTx = {
      getVerification: async (uid) => {
        const staged = stagedVerifications.get(uid);
        if (staged !== undefined) return staged;
        return this.verifications.get(uid) ?? null;
      },
      getProvider: async (uid) => {
        const p = this.providers.get(uid);
        if (!p) return null;
        const flags = stagedProviderFlags.get(uid) ?? this.providerFlags.get(uid);
        if (!flags) return p;
        return {
          ...p,
          verified: flags.verified ?? p.verified,
          businessVerified: flags.businessVerified ?? p.businessVerified,
        };
      },
      getOrganizer: async (uid) => {
        const o = this.organizers.get(uid);
        if (!o) return null;
        const flags = stagedOrganizerFlags.get(uid) ?? this.organizerFlags.get(uid);
        return flags ? { ...o, businessVerified: flags.businessVerified ?? o.businessVerified } : o;
      },
      getContact: async (uid) => {
        const c = this.contacts.get(uid) ?? { phone: null, phoneVerified: false };
        if (stagedPhoneVerified.has(uid)) {
          return { ...c, phoneVerified: true };
        }
        return c;
      },
      getIdentity: async (uid) => {
        const staged = stagedIdentities.get(uid);
        if (staged !== undefined) return staged;
        return this.identities.get(uid) ?? null;
      },
      identityOwner: async (idHash) => {
        const staged = stagedHashes.get(idHash);
        if (staged !== undefined) return staged;
        return this.identityHashes.get(idHash) ?? null;
      },
      getPayment: async (id) => stagedPayments.get(id) ?? this.payments.get(id) ?? null,
      feePaymentsOf: async (uid) => {
        const all = new Map(this.payments);
        for (const [id, p] of stagedPayments) all.set(id, p);
        return [...all.values()].filter((p) => p.subjectType === 'verification_fee' && p.subjectId === uid);
      },
      getRefund: async (id) => stagedRefunds.get(id) ?? this.refunds.get(id) ?? null,
      getTransferRecord: async (id) => stagedTransferRecords.get(id) ?? this.transferRecords.get(id) ?? null,
      putVerification: (r) => {
        stagedVerifications.set(r.uid, r);
      },
      setProviderFlags: (uid, patch) => {
        const existing = stagedProviderFlags.get(uid) ?? this.providerFlags.get(uid) ?? {};
        stagedProviderFlags.set(uid, { ...existing, ...patch });
      },
      setOrganizerFlags: (uid, patch) => {
        const existing = stagedOrganizerFlags.get(uid) ?? this.organizerFlags.get(uid) ?? {};
        stagedOrganizerFlags.set(uid, { ...existing, ...patch });
      },
      setPhoneVerified: (uid) => {
        stagedPhoneVerified.add(uid);
      },
      putIdentity: (uid, r) => {
        stagedIdentities.set(uid, r);
      },
      putIdentityHash: (idHash, uid) => {
        stagedHashes.set(idHash, uid);
      },
      addAudit: (e) => {
        stagedAudits.push(e);
      },
      putPayment: (p) => {
        stagedPayments.set(p.id, p);
      },
      putRefund: (r) => {
        stagedRefunds.set(r.id, r);
      },
      addLedgerEntry: (e) => {
        stagedLedger.push(e);
      },
      putTransferRecord: (r) => {
        stagedTransferRecords.set(r.id, r);
      },
    };

    const result = await fn(tx);

    for (const [uid, r] of stagedVerifications) {
      this.verifications.set(uid, r);
    }
    for (const [uid, patch] of stagedProviderFlags) {
      this.providerFlags.set(uid, patch);
      const p = this.providers.get(uid);
      if (p) {
        this.providers.set(uid, {
          ...p,
          verified: patch.verified ?? p.verified,
          businessVerified: patch.businessVerified ?? p.businessVerified,
        });
      }
    }
    for (const [uid, patch] of stagedOrganizerFlags) {
      this.organizerFlags.set(uid, patch);
      const o = this.organizers.get(uid);
      if (o) this.organizers.set(uid, { ...o, businessVerified: patch.businessVerified ?? o.businessVerified });
    }
    for (const uid of stagedPhoneVerified) {
      const c = this.contacts.get(uid) ?? { phone: null, phoneVerified: false };
      this.contacts.set(uid, { ...c, phoneVerified: true });
    }
    for (const [uid, r] of stagedIdentities) {
      this.identities.set(uid, r);
    }
    for (const [idHash, uid] of stagedHashes) {
      this.identityHashes.set(idHash, uid);
    }
    for (const a of stagedAudits) {
      this.audits.push(a);
    }
    for (const [id, p] of stagedPayments) this.payments.set(id, p);
    for (const [id, r] of stagedRefunds) this.refunds.set(id, r);
    this.ledger.push(...stagedLedger);
    for (const [id, r] of stagedTransferRecords) this.transferRecords.set(id, r);

    return result;
  }

  async dueForNudge(cutoff: Date, limit: number): Promise<VerificationRecord[]> {
    const cutoffMs = cutoff.getTime();
    const result: VerificationRecord[] = [];
    for (const r of this.verifications.values()) {
      if (r.status === 'in_progress' && r.nudgedAt === null) {
        if (Date.parse(r.updatedAt) <= cutoffMs) {
          result.push(r);
          if (result.length >= limit) break;
        }
      }
    }
    return result;
  }

  async queue(target: 'identity' | 'business', limit: number): Promise<VerificationRecord[]> {
    const list: VerificationRecord[] = [];
    for (const r of this.verifications.values()) {
      if (target === 'identity') {
        if (r.status === 'submitted') {
          list.push(r);
        }
      } else {
        if (r.business?.status === 'submitted') {
          list.push(r);
        }
      }
    }

    list.sort((a, b) => {
      const aTime = target === 'identity' ? Date.parse(a.submittedAt ?? a.createdAt) : Date.parse(a.business?.submittedAt ?? a.createdAt);
      const bTime = target === 'identity' ? Date.parse(b.submittedAt ?? b.createdAt) : Date.parse(b.business?.submittedAt ?? b.createdAt);
      return aTime - bTime;
    });

    return list.slice(0, limit);
  }
}

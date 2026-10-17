import {
  Timestamp,
  type DocumentData,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import type {
  AuthPhoneReader,
  BusinessRejectReason,
  BusinessVerificationRecord,
  FeeStepRecord,
  IdentityAttemptsRecord,
  IdentityMethod,
  IdentityRecord,
  IdentitySessionRecord,
  IdentityStepRecord,
  LedgerEntry,
  Payment,
  PhoneStepRecord,
  ProviderVerificationView,
  RejectReason,
  Refund,
  RejectReasonRecord,
  RulesStepRecord,
  TransferRecord,
  VerificationAuditEntry,
  VerificationKind,
  VerificationRecord,
  VerificationStatus,
  VerificationSteps,
  VerificationStore,
  VerificationTx,
} from '@photobooking/domain';
import { providerTypeOf } from '@photobooking/domain';
import {
  LEDGER_COLLECTION,
  PAYMENTS_COLLECTION,
  PAYMENT_NOTIFICATIONS_COLLECTION,
  REFUNDS_COLLECTION,
  ledgerEntryToFirestore,
  paymentFromFirestore,
  paymentToFirestore,
  refundFromFirestore,
  refundToFirestore,
  transferRecordFromFirestore,
  transferRecordToFirestore,
} from './booking_firestore.js';

// Server-written; rules: owner reads verifications/{uid}, everything else here is closed.
export const VERIFICATIONS_COLLECTION = 'verifications';
export const IDENTITY_HASHES_COLLECTION = 'identity_hashes';
export const VERIFICATION_AUDIT_COLLECTION = 'verificationAudit';
/** Emulator/dev overrides read by the fake identity verifier (Decision 6). */
export const FAKE_IDENTITIES_COLLECTION = 'fake_identities';
const PHOTOGRAPHERS_COLLECTION = 'photographers';

/** `users/{uid}/private/{docId}` (identity is server-only; contact is the owner's). */
function privateDoc(firestore: Firestore, uid: string, docId: 'contact' | 'identity') {
  return firestore.collection('users').doc(uid).collection('private').doc(docId);
}

function toIsoString(v: unknown): string | null {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string') return v;
  return null;
}

function toTimestamp(iso: string | null | undefined): Timestamp | null {
  if (!iso) return null;
  return Timestamp.fromDate(new Date(iso));
}

export function verificationToFirestore(r: VerificationRecord): DocumentData {
  return {
    uid: r.uid,
    kind: r.kind,
    status: r.status,
    steps: {
      phone: r.steps.phone ? { doneAt: toTimestamp(r.steps.phone.doneAt) } : null,
      fee: r.steps.fee
        ? {
            paymentId: r.steps.fee.paymentId,
            amount: r.steps.fee.amount,
            paidAt: toTimestamp(r.steps.fee.paidAt),
          }
        : null,
      identity: r.steps.identity
        ? {
            method: r.steps.identity.method,
            checkedAt: toTimestamp(r.steps.identity.checkedAt),
            result: r.steps.identity.result,
            failure: r.steps.identity.failure ?? null,
            maskedName: r.steps.identity.maskedName ?? null,
          }
        : null,
      rules: r.steps.rules
        ? {
            acceptedAt: toTimestamp(r.steps.rules.acceptedAt),
            version: r.steps.rules.version,
          }
        : null,
    },
    identitySession: r.identitySession
      ? {
          id: r.identitySession.id,
          method: r.identitySession.method,
          startedAt: toTimestamp(r.identitySession.startedAt),
        }
      : null,
    identityAttempts: {
      dayKey: r.identityAttempts.dayKey,
      count: r.identityAttempts.count,
    },
    feeAttempt: r.feeAttempt,
    submittedAt: toTimestamp(r.submittedAt),
    decidedAt: toTimestamp(r.decidedAt),
    decidedBy: r.decidedBy ?? null,
    rejectReason: r.rejectReason
      ? {
          code: r.rejectReason.code,
          text: r.rejectReason.text ?? null,
        }
      : null,
    freeResubmitsLeft: r.freeResubmitsLeft,
    nudgedAt: toTimestamp(r.nudgedAt),
    business: r.business
      ? {
          status: r.business.status,
          kind: r.business.kind,
          taxCode: r.business.taxCode,
          name: r.business.name,
          address: r.business.address,
          registryStatus: r.business.registryStatus,
          docPath: r.business.docPath ?? null,
          representativeMatched: r.business.representativeMatched,
          submittedAt: toTimestamp(r.business.submittedAt),
          decidedAt: toTimestamp(r.business.decidedAt),
          decidedBy: r.business.decidedBy ?? null,
          rejectReason: r.business.rejectReason
            ? {
                code: r.business.rejectReason.code,
                text: r.business.rejectReason.text ?? null,
              }
            : null,
          purgeAfter: toTimestamp(r.business.purgeAfter),
        }
      : null,
    version: r.version,
    createdAt: toTimestamp(r.createdAt),
    updatedAt: toTimestamp(r.updatedAt),
  };
}

export function verificationFromFirestore(d: DocumentData | null | undefined): VerificationRecord | null {
  if (!d) return null;

  const stepsData = d.steps ?? {};

  const phone: PhoneStepRecord | null = stepsData.phone
    ? { doneAt: toIsoString(stepsData.phone.doneAt) ?? '' }
    : null;

  const fee: FeeStepRecord | null = stepsData.fee
    ? {
        paymentId: String(stepsData.fee.paymentId),
        amount: Number(stepsData.fee.amount),
        paidAt: toIsoString(stepsData.fee.paidAt) ?? '',
      }
    : null;

  const identity: IdentityStepRecord | null = stepsData.identity
    ? {
        method: stepsData.identity.method as IdentityMethod,
        checkedAt: toIsoString(stepsData.identity.checkedAt) ?? '',
        result: stepsData.identity.result as 'passed' | 'failed',
        failure: stepsData.identity.failure ?? null,
        maskedName: stepsData.identity.maskedName ?? null,
      }
    : null;

  const rules: RulesStepRecord | null = stepsData.rules
    ? {
        acceptedAt: toIsoString(stepsData.rules.acceptedAt) ?? '',
        version: String(stepsData.rules.version),
      }
    : null;

  const steps: VerificationSteps = { phone, fee, identity, rules };

  const identitySession: IdentitySessionRecord | null = d.identitySession
    ? {
        id: String(d.identitySession.id),
        method: d.identitySession.method as IdentityMethod,
        startedAt: toIsoString(d.identitySession.startedAt) ?? '',
      }
    : null;

  const identityAttempts: IdentityAttemptsRecord = {
    dayKey: String(d.identityAttempts?.dayKey ?? ''),
    count: Number(d.identityAttempts?.count ?? 0),
  };

  const rejectReason: RejectReasonRecord | null = d.rejectReason
    ? {
        code: d.rejectReason.code as RejectReason,
        text: d.rejectReason.text ?? null,
      }
    : null;

  const b = d.business;
  const business: BusinessVerificationRecord | null = b
    ? {
        status: b.status,
        kind: b.kind,
        taxCode: String(b.taxCode),
        name: String(b.name),
        address: String(b.address),
        registryStatus: b.registryStatus,
        docPath: b.docPath ?? null,
        representativeMatched: Boolean(b.representativeMatched),
        submittedAt: toIsoString(b.submittedAt) ?? '',
        decidedAt: toIsoString(b.decidedAt),
        decidedBy: b.decidedBy ?? null,
        rejectReason: b.rejectReason
          ? {
              code: b.rejectReason.code as BusinessRejectReason,
              text: b.rejectReason.text ?? null,
            }
          : null,
        purgeAfter: toIsoString(b.purgeAfter),
      }
    : null;

  return {
    uid: String(d.uid),
    kind: d.kind as VerificationKind,
    status: d.status as VerificationStatus,
    steps,
    identitySession,
    identityAttempts,
    feeAttempt: Number(d.feeAttempt ?? 1),
    submittedAt: toIsoString(d.submittedAt),
    decidedAt: toIsoString(d.decidedAt),
    decidedBy: d.decidedBy ?? null,
    rejectReason,
    freeResubmitsLeft: Number(d.freeResubmitsLeft ?? 0),
    nudgedAt: toIsoString(d.nudgedAt),
    business,
    version: Number(d.version ?? 1),
    createdAt: toIsoString(d.createdAt) ?? '',
    updatedAt: toIsoString(d.updatedAt) ?? '',
  };
}

export function identityToFirestore(r: IdentityRecord): DocumentData {
  return {
    legalName: r.legalName,
    dob: r.dob,
    gender: r.gender ?? null,
    idNumberEnc: r.idNumberEnc,
    idHash: r.idHash,
    method: r.method,
    provider: r.provider,
    providerRef: r.providerRef,
    verifiedAt: toTimestamp(r.verifiedAt),
  };
}

export function identityFromFirestore(d: DocumentData | null | undefined): IdentityRecord | null {
  if (!d) return null;
  return {
    legalName: String(d.legalName),
    dob: String(d.dob),
    gender: d.gender ?? null,
    idNumberEnc: String(d.idNumberEnc),
    idHash: String(d.idHash),
    method: d.method as IdentityMethod,
    provider: String(d.provider),
    providerRef: String(d.providerRef),
    verifiedAt: toIsoString(d.verifiedAt) ?? '',
  };
}

export class FirestoreVerificationTx implements VerificationTx {
  constructor(
    private readonly firestore: Firestore,
    private readonly tx: Transaction,
  ) {}

  async getVerification(uid: string): Promise<VerificationRecord | null> {
    const ref = this.firestore.collection(VERIFICATIONS_COLLECTION).doc(uid);
    const snap = await this.tx.get(ref);
    if (!snap.exists) return null;
    return verificationFromFirestore(snap.data());
  }

  async getProvider(uid: string): Promise<ProviderVerificationView | null> {
    const ref = this.firestore.collection(PHOTOGRAPHERS_COLLECTION).doc(uid);
    const snap = await this.tx.get(ref);
    if (!snap.exists) return null;
    const d = snap.data() ?? {};
    return {
      providerType: providerTypeOf(d.providerType),
      onboardingComplete: Boolean(d.onboardingComplete),
      verified: Boolean(d.verified),
      businessVerified: Boolean(d.businessVerified),
    };
  }

  async getContact(uid: string): Promise<{ phone: string | null; phoneVerified: boolean }> {
    const snap = await this.tx.get(privateDoc(this.firestore, uid, 'contact'));
    if (!snap.exists) {
      return { phone: null, phoneVerified: false };
    }
    const d = snap.data() ?? {};
    return {
      phone: typeof d.phone === 'string' && d.phone !== '' ? d.phone : null,
      phoneVerified: d.phoneVerified === true,
    };
  }

  async getIdentity(uid: string): Promise<IdentityRecord | null> {
    const snap = await this.tx.get(privateDoc(this.firestore, uid, 'identity'));
    if (!snap.exists) return null;
    return identityFromFirestore(snap.data());
  }

  async identityOwner(idHash: string): Promise<string | null> {
    const ref = this.firestore.collection(IDENTITY_HASHES_COLLECTION).doc(idHash);
    const snap = await this.tx.get(ref);
    if (!snap.exists) return null;
    return (snap.data()?.uid as string) ?? null;
  }

  // ---- the verification fee (#203): the shared payments, refunds, ledger and transfer records,
  // mapped exactly as every other payment subject (booking_firestore.ts) ----

  async getPayment(id: string): Promise<Payment | null> {
    const snap = await this.tx.get(this.firestore.collection(PAYMENTS_COLLECTION).doc(id));
    return snap.exists ? paymentFromFirestore(snap.id, snap.data()) : null;
  }

  /** Equality on two fields only: served by the single-field indexes, no composite index. */
  async feePaymentsOf(uid: string): Promise<readonly Payment[]> {
    const snap = await this.tx.get(
      this.firestore
        .collection(PAYMENTS_COLLECTION)
        .where('subjectType', '==', 'verification_fee')
        .where('subjectId', '==', uid),
    );
    return snap.docs
      .map((d) => paymentFromFirestore(d.id, d.data()))
      .filter((p): p is Payment => p !== null);
  }

  async getRefund(id: string): Promise<Refund | null> {
    const snap = await this.tx.get(this.firestore.collection(REFUNDS_COLLECTION).doc(id));
    return snap.exists ? refundFromFirestore(snap.id, snap.data()) : null;
  }

  async getTransferRecord(id: string): Promise<TransferRecord | null> {
    const snap = await this.tx.get(this.firestore.collection(PAYMENT_NOTIFICATIONS_COLLECTION).doc(id));
    return snap.exists ? transferRecordFromFirestore(snap.id, snap.data()) : null;
  }

  putPayment(p: Payment): void {
    this.tx.set(this.firestore.collection(PAYMENTS_COLLECTION).doc(p.id), paymentToFirestore(p));
  }

  putRefund(r: Refund): void {
    this.tx.set(this.firestore.collection(REFUNDS_COLLECTION).doc(r.id), refundToFirestore(r));
  }

  addLedgerEntry(e: LedgerEntry): void {
    this.tx.set(this.firestore.collection(LEDGER_COLLECTION).doc(e.id), ledgerEntryToFirestore(e));
  }

  putTransferRecord(r: TransferRecord): void {
    this.tx.set(this.firestore.collection(PAYMENT_NOTIFICATIONS_COLLECTION).doc(r.id), transferRecordToFirestore(r));
  }

  putVerification(r: VerificationRecord): void {
    // The whole record every time: a merge would keep keys the domain dropped.
    const ref = this.firestore.collection(VERIFICATIONS_COLLECTION).doc(r.uid);
    this.tx.set(ref, verificationToFirestore(r));
  }

  setProviderFlags(
    uid: string,
    patch: {
      verified?: boolean;
      verifiedAt?: string | null;
      acceptingOrders?: boolean;
      businessVerified?: boolean;
    },
  ): void {
    // Same transaction as the verification record (Decision 12); the domain checked the doc exists.
    const ref = this.firestore.collection(PHOTOGRAPHERS_COLLECTION).doc(uid);
    const data: DocumentData = {};
    if (patch.verified !== undefined) data.verified = patch.verified;
    if (patch.verifiedAt !== undefined) data.verifiedAt = toTimestamp(patch.verifiedAt);
    if (patch.acceptingOrders !== undefined) data.acceptingOrders = patch.acceptingOrders;
    if (patch.businessVerified !== undefined) data.businessVerified = patch.businessVerified;
    this.tx.set(ref, data, { merge: true });
  }

  setPhoneVerified(uid: string): void {
    this.tx.set(privateDoc(this.firestore, uid, 'contact'), { phoneVerified: true }, { merge: true });
  }

  putIdentity(uid: string, r: IdentityRecord): void {
    this.tx.set(privateDoc(this.firestore, uid, 'identity'), identityToFirestore(r));
  }

  putIdentityHash(idHash: string, uid: string): void {
    // create, not set: the domain read the guard as absent in this transaction, so an existing doc
    // means a race the transaction must lose (Decision 7).
    const ref = this.firestore.collection(IDENTITY_HASHES_COLLECTION).doc(idHash);
    this.tx.create(ref, { uid, createdAt: Timestamp.now() });
  }

  addAudit(e: VerificationAuditEntry): void {
    const ref = this.firestore.collection(VERIFICATION_AUDIT_COLLECTION).doc(e.id);
    this.tx.set(ref, {
      id: e.id,
      uid: e.uid,
      target: e.target,
      action: e.action,
      reason: e.reason ?? null,
      note: e.note ?? null,
      actorId: e.actorId ?? null,
      otherUid: e.otherUid ?? null,
      at: toTimestamp(e.at),
    });
  }
}

export class FirestoreVerificationStore implements VerificationStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: VerificationTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx) => {
      const tx = new FirestoreVerificationTx(this.firestore, fTx);
      return fn(tx);
    });
  }

  /** in_progress, never nudged, unchanged since `cutoff` (index: status, nudgedAt, updatedAt). */
  async dueForNudge(cutoff: Date, limit: number): Promise<VerificationRecord[]> {
    const cutoffTs = Timestamp.fromDate(cutoff);
    // nudgedAt == null in the query, not only in the filter below: nudged records stay
    // in_progress and would otherwise fill every page.
    const snap = await this.firestore
      .collection(VERIFICATIONS_COLLECTION)
      .where('status', '==', 'in_progress')
      .where('nudgedAt', '==', null)
      .where('updatedAt', '<=', cutoffTs)
      .limit(limit)
      .get();

    return snap.docs
      .map((d) => verificationFromFirestore(d.data()))
      .filter((r): r is VerificationRecord => r !== null && r.nudgedAt === null);
  }

  async queue(target: 'identity' | 'business', limit: number): Promise<VerificationRecord[]> {
    if (target === 'identity') {
      const snap = await this.firestore
        .collection(VERIFICATIONS_COLLECTION)
        .where('status', '==', 'submitted')
        .orderBy('submittedAt', 'asc')
        .limit(limit)
        .get();
      return snap.docs
        .map((d) => verificationFromFirestore(d.data()))
        .filter((r): r is VerificationRecord => r !== null);
    } else {
      const snap = await this.firestore
        .collection(VERIFICATIONS_COLLECTION)
        .where('business.status', '==', 'submitted')
        .orderBy('business.submittedAt', 'asc')
        .limit(limit)
        .get();
      return snap.docs
        .map((d) => verificationFromFirestore(d.data()))
        .filter((r): r is VerificationRecord => r !== null);
    }
  }

  /** Business records whose registration photo is due for deletion (single-field index on business.purgeAfter). */
  async findDueBusinessPurges(now: Date, limit: number): Promise<BusinessDocPurge[]> {
    const snap = await this.firestore
      .collection(VERIFICATIONS_COLLECTION)
      .where('business.purgeAfter', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    const results: BusinessDocPurge[] = [];
    for (const doc of snap.docs) {
      const rec = verificationFromFirestore(doc.data());
      if (rec?.business) results.push({ uid: rec.uid, docPath: rec.business.docPath });
    }
    return results;
  }

  /**
   * After the file is gone: clears `business.docPath` and `business.purgeAfter` so the record
   * leaves the purge query. Skipped when the studio has meanwhile sent another photo.
   */
  async clearBusinessDoc(uid: string, docPath: string | null, now: Date): Promise<void> {
    await this.firestore.runTransaction(async (tx) => {
      const ref = this.firestore.collection(VERIFICATIONS_COLLECTION).doc(uid);
      const rec = verificationFromFirestore((await tx.get(ref)).data());
      if (!rec?.business || rec.business.docPath !== docPath) return;
      tx.set(
        ref,
        verificationToFirestore({
          ...rec,
          business: { ...rec.business, docPath: null, purgeAfter: null },
          updatedAt: now.toISOString(),
          version: rec.version + 1,
        }),
      );
    });
  }
}

export interface BusinessDocPurge {
  readonly uid: string;
  readonly docPath: string | null;
}

export function adminAuthPhoneReader(): AuthPhoneReader {
  return {
    async verifiedPhoneOf(uid: string): Promise<string | null> {
      try {
        const user = await getAuth().getUser(uid);
        return user.phoneNumber ?? null;
      } catch (e) {
        // A missing Auth user has no phone; anything else (network, quota) is an internal error.
        if ((e as { code?: string }).code === 'auth/user-not-found') return null;
        throw e;
      }
    },
  };
}

import { DomainError } from './errors.js';
import {
  emptyVerification,
  type BusinessSubject,
  type BusinessVerificationRecord,
  type VerificationRecord,
} from './verification.js';
import type {
  TaxCodeInfo,
  VerificationDeps,
  VerificationTx,
} from './verification_ports.js';
import type { VerificationChange } from './verification_use_cases.js';

/**
 * Valid tax codes:
 * - 10 digits: company
 * - 10 digits + '-' + 3 digits: branch / enterprise
 * - 12 digits: household (personal citizen ID of owner)
 */
export function isTaxCode(s: unknown): s is string {
  if (typeof s !== 'string') return false;
  const clean = s.trim();
  const tenOrBranch = /^\d{10}(-\d{3})?$/;
  const twelve = /^\d{12}$/;
  return tenOrBranch.test(clean) || twelve.test(clean);
}

/**
 * Who may start or send S21.04 (plan #223 Decision 3): a verified studio, else a user with an `active`
 * organizer document. A suspended organizer is `conflict`; someone who is neither is `permission_denied`
 * (no provider profile) or `not_eligible` (a provider who is not a verified studio), as before.
 */
async function businessSubjectOf(tx: VerificationTx, uid: string): Promise<BusinessSubject> {
  const provider = await tx.getProvider(uid);
  if (provider !== null && provider.providerType === 'studio' && provider.verified) return 'studio';
  const organizer = await tx.getOrganizer(uid);
  if (organizer?.status === 'active') return 'organizer';
  if (organizer?.status === 'suspended') throw new DomainError('conflict');
  if (provider === null) throw new DomainError('permission_denied');
  throw new DomainError('not_eligible');
}

const isOwnDoc = (docPath: string | null, uid: string): docPath is string =>
  docPath !== null && docPath.startsWith(`businessDocs/${uid}/`);

export async function lookupTaxCode(
  deps: VerificationDeps,
  uid: string,
  raw: unknown,
): Promise<TaxCodeInfo> {
  if (!deps.taxCodes) throw new DomainError('not_eligible');

  await deps.store.runTransaction((tx) => businessSubjectOf(tx, uid));

  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }

  const taxCode = (raw as { taxCode?: unknown }).taxCode;
  if (!isTaxCode(taxCode)) {
    throw new DomainError('invalid_argument');
  }

  const info = await deps.taxCodes.lookup(taxCode);
  if (!info) throw new DomainError('not_found');
  return info;
}

export async function submitBusinessVerification(
  deps: VerificationDeps,
  uid: string,
  raw: unknown,
): Promise<VerificationChange> {
  if (!deps.taxCodes || !deps.vault) throw new DomainError('not_eligible');

  const subject = await deps.store.runTransaction((tx) => businessSubjectOf(tx, uid));

  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }

  const input = raw as { taxCode?: unknown; docPath?: unknown };
  if (!isTaxCode(input.taxCode)) {
    throw new DomainError('invalid_argument');
  }

  const taxCode = input.taxCode;
  const docPath = typeof input.docPath === 'string' ? input.docPath : null;

  const info = await deps.taxCodes.lookup(taxCode);
  if (!info) throw new DomainError('not_found');
  if (info.status === 'inactive') {
    throw new DomainError('not_eligible');
  }

  const now = deps.clock.now();
  const nowIso = now.toISOString();

  // If company, registration photo is required
  if (info.kind === 'company') {
    if (!isOwnDoc(docPath, uid)) {
      throw new DomainError('invalid_argument');
    }
  }

  const taxCodeHash = await deps.vault.hashId(taxCode);

  return deps.store.runTransaction(async (tx) => {
    // Re-checked with the writes: the caller may have changed since the first read.
    if ((await businessSubjectOf(tx, uid)) !== subject) throw new DomainError('conflict');
    const stored = await tx.getVerification(uid);
    // A studio's S21 record exists by then; an organizer has none until it first sends a business.
    if (!stored && subject === 'studio') throw new DomainError('not_eligible');
    const rec = stored ?? emptyVerification(uid, 'individual', now);
    // A pending record keeps its photo (the purge deletes that path) and an approved one keeps the
    // businessVerified flag it set; only a rejected record may be sent again.
    if (rec.business?.status === 'submitted' || rec.business?.status === 'approved') {
      throw new DomainError('conflict');
    }

    const identity = await tx.getIdentity(uid);
    // A studio's household code is matched to its owner's verified identity; an organizer needs none.
    if (!identity && subject === 'studio') throw new DomainError('not_eligible');

    let bizRecord: BusinessVerificationRecord;

    const matched = identity !== null && taxCodeHash === identity.idHash;
    // A company always goes to staff. A household code is decided by the owner's identity: a studio is
    // approved on a match and rejected otherwise; an organizer (who needs no identity) is approved on a
    // match, and otherwise goes to staff with its photo like a company.
    const toStaff = info.kind === 'company' || (subject === 'organizer' && !matched);
    if (toStaff && !isOwnDoc(docPath, uid)) throw new DomainError('invalid_argument');

    if (!toStaff) {
      if (matched) {
        // Approved immediately
        bizRecord = {
          subject,
          status: 'approved',
          kind: 'household',
          taxCode,
          name: info.name,
          address: info.address,
          registryStatus: 'active',
          docPath: null,
          representativeMatched: true,
          submittedAt: nowIso,
          decidedAt: nowIso,
          decidedBy: null,
          rejectReason: null,
          purgeAfter: null,
        };

        if (subject === 'organizer') tx.setOrganizerFlags(uid, { businessVerified: true });
        else tx.setProviderFlags(uid, { businessVerified: true });
      } else {
        // Rejected representative_mismatch
        bizRecord = {
          subject,
          status: 'rejected',
          kind: 'household',
          taxCode,
          name: info.name,
          address: info.address,
          registryStatus: 'active',
          docPath: null,
          representativeMatched: false,
          submittedAt: nowIso,
          decidedAt: nowIso,
          decidedBy: null,
          rejectReason: {
            code: 'representative_mismatch',
            text: 'Mã số thuế không khớp với danh tính chủ studio.',
          },
          purgeAfter: null,
        };
      }
    } else {
      // Submitted for staff review
      bizRecord = {
        subject,
        status: 'submitted',
        kind: info.kind,
        taxCode,
        name: info.name,
        address: info.address,
        registryStatus: 'active',
        docPath,
        representativeMatched: false,
        submittedAt: nowIso,
        decidedAt: null,
        decidedBy: null,
        rejectReason: null,
        purgeAfter: null,
      };
    }

    const after: VerificationRecord = {
      ...rec,
      business: bizRecord,
      updatedAt: nowIso,
      version: rec.version + 1,
    };

    tx.putVerification(after);
    return { before: rec, after };
  });
}

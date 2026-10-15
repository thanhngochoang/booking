import { DomainError } from './errors.js';
import type {
  BusinessVerificationRecord,
  VerificationRecord,
} from './verification.js';
import type {
  TaxCodeInfo,
  VerificationDeps,
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

export async function lookupTaxCode(
  deps: VerificationDeps,
  uid: string,
  raw: unknown,
): Promise<TaxCodeInfo> {
  if (!deps.taxCodes) throw new DomainError('not_eligible');

  const provider = await deps.store.runTransaction((tx) => tx.getProvider(uid));
  if (!provider) throw new DomainError('permission_denied');
  if (provider.providerType !== 'studio' || !provider.verified) {
    throw new DomainError('not_eligible');
  }

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

  const provider = await deps.store.runTransaction((tx) => tx.getProvider(uid));
  if (!provider) throw new DomainError('permission_denied');
  if (provider.providerType !== 'studio' || !provider.verified) {
    throw new DomainError('not_eligible');
  }

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
    if (!docPath || !docPath.startsWith(`businessDocs/${uid}/`)) {
      throw new DomainError('invalid_argument');
    }
  }

  const taxCodeHash = await deps.vault.hashId(taxCode);

  return deps.store.runTransaction(async (tx) => {
    const rec = await tx.getVerification(uid);
    if (!rec) throw new DomainError('not_eligible');
    // A pending record keeps its photo (the purge deletes that path) and an approved one keeps the
    // businessVerified flag it set; only a rejected record may be sent again.
    if (rec.business?.status === 'submitted' || rec.business?.status === 'approved') {
      throw new DomainError('conflict');
    }

    const identity = await tx.getIdentity(uid);
    if (!identity) throw new DomainError('not_eligible');

    let bizRecord: BusinessVerificationRecord;

    if (info.kind === 'household') {
      const match = taxCodeHash === identity.idHash;
      if (match) {
        // Approved immediately
        bizRecord = {
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

        tx.setProviderFlags(uid, { businessVerified: true });
      } else {
        // Rejected representative_mismatch
        bizRecord = {
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
      // Company: submitted for staff review
      bizRecord = {
        status: 'submitted',
        kind: 'company',
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

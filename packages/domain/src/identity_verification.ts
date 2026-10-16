import { DomainError } from './errors.js';
import {
  ageOn,
  emptyVerification,
  IDENTITY_ATTEMPTS_PER_DAY,
  type IdentityMethod,
  maskLegalName,
  MIN_PROVIDER_AGE_YEARS,
  type VerificationRecord,
  verificationKindOf,
  vnDayKey,
} from './verification.js';
import type { VerificationDeps } from './verification_ports.js';

export async function startIdentityVerification(
  deps: VerificationDeps,
  uid: string,
  raw: unknown,
): Promise<{ sessionId: string; redirectUrl: string | null }> {
  if (!deps.identity) throw new DomainError('not_eligible');

  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }

  const method = (raw as { method?: unknown }).method as IdentityMethod;
  if (method !== 'vneid' && method !== 'nfc') {
    throw new DomainError('invalid_argument');
  }

  const now = deps.clock.now();
  const nowIso = now.toISOString();
  const todayKey = vnDayKey(now);

  // Refuse before calling the vendor: a session costs money and should only be opened for a
  // request that can be recorded. The write transaction below re-checks the same rules.
  const provider = await deps.store.runTransaction(async (tx) => {
    const p = await tx.getProvider(uid);
    if (!p) throw new DomainError('permission_denied');
    refuseIdentityStart(await tx.getVerification(uid), todayKey);
    return p;
  });

  const session = await deps.identity.start(uid, method);

  await deps.store.runTransaction(async (tx) => {
    let rec = await tx.getVerification(uid);
    if (!rec) {
      rec = emptyVerification(uid, verificationKindOf(provider.providerType), now);
    } else if (rec.steps.fee === null) {
      rec = { ...rec, kind: verificationKindOf(provider.providerType) };
    }

    const currentAttempts = refuseIdentityStart(rec, todayKey);

    const after: VerificationRecord = {
      ...rec,
      status: rec.status === 'not_started' ? 'in_progress' : rec.status,
      identitySession: {
        id: session.sessionId,
        method,
        startedAt: nowIso,
      },
      identityAttempts: {
        dayKey: todayKey,
        count: currentAttempts + 1,
      },
      updatedAt: nowIso,
      version: rec.version + 1,
    };

    tx.putVerification(after);
  });

  return session;
}

/**
 * `conflict` once identity passed, `rate_limited` at [IDENTITY_ATTEMPTS_PER_DAY] starts in one
 * VN day; otherwise today's attempt count so far.
 */
function refuseIdentityStart(rec: VerificationRecord | null, todayKey: string): number {
  if (!rec) return 0;
  if (rec.steps.identity?.result === 'passed') {
    throw new DomainError('conflict');
  }
  const attempts = rec.identityAttempts.dayKey === todayKey ? rec.identityAttempts.count : 0;
  if (attempts >= IDENTITY_ATTEMPTS_PER_DAY) {
    throw new DomainError('rate_limited');
  }
  return attempts;
}

export async function completeIdentityVerification(
  deps: VerificationDeps,
  uid: string,
  raw: unknown,
): Promise<{ result: 'passed'; maskedName: string }> {
  if (!deps.identity || !deps.vault) throw new DomainError('not_eligible');

  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }

  const sessionId = (raw as { sessionId?: unknown }).sessionId;
  if (typeof sessionId !== 'string' || !sessionId) {
    throw new DomainError('invalid_argument');
  }

  const now = deps.clock.now();
  const nowIso = now.toISOString();

  // Only ask the vendor about a session this uid started and has not used yet; the write
  // transaction below re-checks it in case another call used it meanwhile.
  await deps.store.runTransaction(async (tx) => {
    const rec = await tx.getVerification(uid);
    if (!rec || !rec.identitySession || rec.identitySession.id !== sessionId) {
      throw new DomainError('not_found');
    }
  });

  // Call identity verifier result outside transaction
  const res = await deps.identity.result(uid, sessionId);
  const hash = await deps.vault.hashId(res.idNumber);
  const enc = await deps.vault.encryptId(res.idNumber);

  const outcome = await deps.store.runTransaction(async (tx) => {
    const rec = await tx.getVerification(uid);
    if (!rec || !rec.identitySession || rec.identitySession.id !== sessionId) {
      throw new DomainError('not_found');
    }

    const method = rec.identitySession.method;
    const owner = await tx.identityOwner(hash);

    let failure: 'provider_failed' | 'underage' | 'identity_in_use' | null = null;
    if (!res.passed) {
      failure = 'provider_failed';
    } else if (ageOn(res.dob, now) < MIN_PROVIDER_AGE_YEARS) {
      failure = 'underage';
    } else if (owner !== null && owner !== uid) {
      failure = 'identity_in_use';
    }

    if (failure !== null) {
      const after: VerificationRecord = {
        ...rec,
        identitySession: null,
        steps: {
          ...rec.steps,
          identity: {
            method,
            checkedAt: nowIso,
            result: 'failed',
            failure,
            maskedName: null,
          },
        },
        updatedAt: nowIso,
        version: rec.version + 1,
      };

      tx.putVerification(after);

      if (failure === 'identity_in_use' && owner !== null) {
        tx.addAudit({
          id: deps.ids.newId(),
          uid,
          target: 'identity',
          action: 'duplicate',
          reason: 'identity_in_use',
          note: `Duplicate id hash: matches ${owner}`,
          actorId: null,
          otherUid: owner,
          at: nowIso,
        });
      }

      return { failure, maskedName: null } as const;
    }

    // Success path
    const masked = maskLegalName(res.legalName);
    tx.putIdentity(uid, {
      legalName: res.legalName,
      dob: res.dob,
      gender: res.gender,
      idNumberEnc: enc,
      idHash: hash,
      method,
      provider: res.provider,
      providerRef: res.providerRef,
      verifiedAt: nowIso,
    });

    if (owner === null) {
      tx.putIdentityHash(hash, uid);
    }

    const after: VerificationRecord = {
      ...rec,
      identitySession: null,
      steps: {
        ...rec.steps,
        identity: {
          method,
          checkedAt: nowIso,
          result: 'passed',
          failure: null,
          maskedName: masked,
        },
      },
      updatedAt: nowIso,
      version: rec.version + 1,
    };

    tx.putVerification(after);
    return { failure: null, maskedName: masked } as const;
  });

  if (outcome.failure === 'provider_failed') {
    throw new DomainError('not_eligible');
  }
  if (outcome.failure !== null) {
    throw new DomainError(outcome.failure);
  }

  const masked = outcome.maskedName ?? '';
  return { result: 'passed', maskedName: masked };
}

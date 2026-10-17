import {
  BUSINESS_DOC_RETENTION_DAYS,
  BUSINESS_REJECT_REASONS,
  type BusinessRejectReason,
  type BusinessVerificationRecord,
  emptyVerification,
  PROVIDER_RULES_VERSION,
  type RejectReason,
  REJECT_REASONS,
  requiredSteps,
  RESUBMITTABLE_REASONS,
  stepDone,
  stepsLeft,
  VERIFICATION_NUDGE_AFTER_HOURS,
  type VerificationRecord,
  verificationKindOf,
} from './verification.js';
import type {
  StaffCaller,
  VerificationDeps,
} from './verification_ports.js';
import { DomainError } from './errors.js';
import { acceptsOrders } from './provider_orders.js';
import type { NotifyDeps } from './notification_ports.js';
import {
  notifyBusinessDecision,
  notifyVerificationDecision,
  notifyVerificationReminder,
} from './notification_hooks.js';

export interface VerificationChange {
  readonly before: VerificationRecord | null;
  readonly after: VerificationRecord;
}

export type VerificationNotice =
  | { hook: 'decision'; outcome: 'approved' | 'rejected' | 'revoked'; decidedAt: string }
  | { hook: 'business'; outcome: 'verified' | 'rejected'; decidedAt: string };

export function verificationNotices(
  before: VerificationRecord | null,
  after: VerificationRecord,
): VerificationNotice[] {
  const notices: VerificationNotice[] = [];
  if (before?.status !== after.status) {
    if (after.status === 'approved' || after.status === 'rejected' || after.status === 'revoked') {
      if (after.decidedAt) {
        notices.push({
          hook: 'decision',
          outcome: after.status,
          decidedAt: after.decidedAt,
        });
      }
    }
  }

  const beforeBiz = before?.business?.status;
  const afterBiz = after.business?.status;
  if (beforeBiz !== afterBiz && after.business?.decidedAt) {
    if (afterBiz === 'approved') {
      notices.push({
        hook: 'business',
        outcome: 'verified',
        decidedAt: after.business.decidedAt,
      });
    } else if (afterBiz === 'rejected') {
      notices.push({
        hook: 'business',
        outcome: 'rejected',
        decidedAt: after.business.decidedAt,
      });
    }
  }

  return notices;
}

export async function notifyVerificationChange(
  notify: NotifyDeps,
  change: VerificationChange,
): Promise<void> {
  const notices = verificationNotices(change.before, change.after);
  for (const n of notices) {
    if (n.hook === 'decision') {
      await notifyVerificationDecision(notify, {
        uid: change.after.uid,
        outcome: n.outcome,
        decidedAt: n.decidedAt,
      });
    } else if (n.hook === 'business') {
      await notifyBusinessDecision(notify, {
        uid: change.after.uid,
        outcome: n.outcome,
        decidedAt: n.decidedAt,
      });
    }
  }
}

export async function confirmPhoneVerified(
  deps: VerificationDeps,
  uid: string,
): Promise<VerificationChange> {
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const provider = await tx.getProvider(uid);
    if (!provider) throw new DomainError('permission_denied');

    const contact = await tx.getContact(uid);
    if (!contact.phone) throw new DomainError('phone_required');

    const authPhone = await deps.authPhones.verifiedPhoneOf(uid);
    if (!authPhone || authPhone !== contact.phone) {
      throw new DomainError('conflict');
    }

    let rec = await tx.getVerification(uid);
    const before = rec;
    if (!rec) {
      rec = emptyVerification(uid, verificationKindOf(provider.providerType), now);
    } else if (rec.steps.fee === null) {
      rec = { ...rec, kind: verificationKindOf(provider.providerType) };
    }

    const after: VerificationRecord = {
      ...rec,
      status: rec.status === 'not_started' ? 'in_progress' : rec.status,
      steps: {
        ...rec.steps,
        phone: { doneAt: nowIso },
      },
      updatedAt: nowIso,
      version: rec.version + 1,
    };

    tx.setPhoneVerified(uid);
    tx.putVerification(after);

    return { before, after };
  });
}

export async function acceptVerificationRules(
  deps: VerificationDeps,
  uid: string,
  raw: unknown,
): Promise<VerificationChange> {
  if (typeof raw !== 'object' || raw === null || (raw as { version?: unknown }).version !== PROVIDER_RULES_VERSION) {
    throw new DomainError('invalid_argument');
  }

  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const provider = await tx.getProvider(uid);
    if (!provider) throw new DomainError('permission_denied');

    let rec = await tx.getVerification(uid);
    const before = rec;
    if (!rec) {
      rec = emptyVerification(uid, verificationKindOf(provider.providerType), now);
    } else if (rec.steps.fee === null) {
      rec = { ...rec, kind: verificationKindOf(provider.providerType) };
    }

    if (rec.status !== 'not_started' && rec.status !== 'in_progress' && rec.status !== 'rejected') {
      throw new DomainError('not_eligible');
    }

    const after: VerificationRecord = {
      ...rec,
      status: rec.status === 'not_started' ? 'in_progress' : rec.status,
      steps: {
        ...rec.steps,
        rules: {
          acceptedAt: nowIso,
          version: PROVIDER_RULES_VERSION,
        },
      },
      updatedAt: nowIso,
      version: rec.version + 1,
    };

    tx.putVerification(after);
    return { before, after };
  });
}

export async function submitVerification(
  deps: VerificationDeps,
  uid: string,
): Promise<VerificationChange> {
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const provider = await tx.getProvider(uid);
    if (!provider) throw new DomainError('permission_denied');

    const contact = await tx.getContact(uid);
    const rec = await tx.getVerification(uid);
    if (!rec) throw new DomainError('not_eligible');

    if (rec.status !== 'in_progress') {
      throw new DomainError('not_eligible');
    }

    const req = requiredSteps(deps.feeRequired);
    for (const step of req) {
      if (!stepDone(rec, step, contact.phoneVerified)) {
        throw new DomainError('not_eligible');
      }
    }

    const after: VerificationRecord = {
      ...rec,
      status: 'submitted',
      submittedAt: nowIso,
      updatedAt: nowIso,
      version: rec.version + 1,
    };

    tx.putVerification(after);
    return { before: rec, after };
  });
}

export async function resubmitVerification(
  deps: VerificationDeps,
  uid: string,
): Promise<VerificationChange> {
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const provider = await tx.getProvider(uid);
    if (!provider) throw new DomainError('permission_denied');

    const contact = await tx.getContact(uid);
    const rec = await tx.getVerification(uid);
    if (!rec || rec.status !== 'rejected') throw new DomainError('not_eligible');

    if (!rec.rejectReason || !RESUBMITTABLE_REASONS.includes(rec.rejectReason.code as typeof RESUBMITTABLE_REASONS[number])) {
      throw new DomainError('not_eligible');
    }

    const req = requiredSteps(deps.feeRequired);
    for (const step of req) {
      if (!stepDone(rec, step, contact.phoneVerified)) {
        throw new DomainError('not_eligible');
      }
    }

    let after: VerificationRecord;
    if (rec.freeResubmitsLeft > 0) {
      after = {
        ...rec,
        status: 'submitted',
        freeResubmitsLeft: rec.freeResubmitsLeft - 1,
        submittedAt: nowIso,
        decidedAt: null,
        decidedBy: null,
        rejectReason: null,
        updatedAt: nowIso,
        version: rec.version + 1,
      };
    } else {
      // Free resubmits = 0
      if (!deps.feeRequired) {
        // Free verification mode: straight back to submitted
        after = {
          ...rec,
          status: 'submitted',
          submittedAt: nowIso,
          decidedAt: null,
          decidedBy: null,
          rejectReason: null,
          updatedAt: nowIso,
          version: rec.version + 1,
        };
      } else if (feePaidAfterRejection(rec)) {
        // A record rejected before the fee existed paid it while rejected: that payment is the paid
        // resubmit, so it goes back to staff and is never charged twice.
        after = {
          ...rec,
          status: 'submitted',
          submittedAt: nowIso,
          decidedAt: null,
          decidedBy: null,
          rejectReason: null,
          updatedAt: nowIso,
          version: rec.version + 1,
        };
      } else {
        // Paid resubmit (#203, Decision 13): back to the steps with the fee open under a new attempt
        // (`vfee_{uid}_{feeAttempt}_…`); pay again, then "Gửi duyệt".
        after = {
          ...rec,
          status: 'in_progress',
          steps: { ...rec.steps, fee: null },
          feeAttempt: rec.feeAttempt + 1,
          submittedAt: null,
          decidedAt: null,
          decidedBy: null,
          rejectReason: null,
          updatedAt: nowIso,
          version: rec.version + 1,
        };
      }
    }

    tx.putVerification(after);
    return { before: rec, after };
  });
}

/** True when the recorded fee was paid after the record's last decision (the rejection). */
function feePaidAfterRejection(rec: VerificationRecord): boolean {
  const fee = rec.steps.fee;
  return fee !== null && rec.decidedAt !== null && Date.parse(fee.paidAt) > Date.parse(rec.decidedAt);
}

export async function reviewVerification(
  deps: VerificationDeps,
  staff: StaffCaller,
  raw: unknown,
): Promise<VerificationChange> {
  if (!staff.isAdmin) throw new DomainError('permission_denied');

  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }

  const input = raw as {
    uid?: unknown;
    target?: unknown;
    action?: unknown;
    reason?: unknown;
    note?: unknown;
  };

  if (typeof input.uid !== 'string' || !input.uid) {
    throw new DomainError('invalid_argument');
  }

  const target = input.target ?? 'identity';
  if (target !== 'identity' && target !== 'business') {
    throw new DomainError('invalid_argument');
  }

  const action = input.action;
  if (action !== 'approve' && action !== 'reject' && action !== 'revoke') {
    throw new DomainError('invalid_argument');
  }

  const now = deps.clock.now();
  const nowIso = now.toISOString();

  return deps.store.runTransaction(async (tx) => {
    const rec = await tx.getVerification(input.uid as string);
    if (!rec) throw new DomainError('not_found');

    const p = await tx.getProvider(input.uid as string);
    if (!p) throw new DomainError('not_found');

    if (target === 'identity') {
      switch (action) {
        case 'approve': {
          if (rec.status !== 'submitted') throw new DomainError('conflict');

          const after: VerificationRecord = {
            ...rec,
            status: 'approved',
            decidedAt: nowIso,
            decidedBy: staff.uid,
            rejectReason: null,
            updatedAt: nowIso,
            version: rec.version + 1,
          };

          tx.putVerification(after);
          tx.setProviderFlags(input.uid as string, {
            verified: true,
            verifiedAt: nowIso,
            acceptingOrders: acceptsOrders({
              verified: true,
              onboardingComplete: p.onboardingComplete,
            }),
          });
          tx.addAudit({
            id: deps.ids.newId(),
            uid: input.uid as string,
            target: 'identity',
            action: 'approve',
            reason: null,
            note: typeof input.note === 'string' ? input.note : null,
            actorId: staff.uid,
            at: nowIso,
          });

          return { before: rec, after };
        }

        case 'reject': {
          if (rec.status !== 'submitted') throw new DomainError('conflict');

          const reasonCode = input.reason as RejectReason;
          if (!REJECT_REASONS.includes(reasonCode)) {
            throw new DomainError('invalid_argument');
          }

          const note = typeof input.note === 'string' ? input.note.trim() : null;
          if (reasonCode === 'other') {
            if (!note || note.length < 5 || note.length > 500) {
              throw new DomainError('invalid_argument');
            }
          } else if (note && (note.length < 5 || note.length > 500)) {
            throw new DomainError('invalid_argument');
          }

          const steps = { ...rec.steps };
          if (reasonCode === 'identity_mismatch') {
            steps.identity = null;
          }

          const after: VerificationRecord = {
            ...rec,
            status: 'rejected',
            steps,
            decidedAt: nowIso,
            decidedBy: staff.uid,
            rejectReason: {
              code: reasonCode,
              text: note,
            },
            updatedAt: nowIso,
            version: rec.version + 1,
          };

          tx.putVerification(after);
          tx.addAudit({
            id: deps.ids.newId(),
            uid: input.uid as string,
            target: 'identity',
            action: 'reject',
            reason: reasonCode,
            note,
            actorId: staff.uid,
            at: nowIso,
          });

          return { before: rec, after };
        }

        case 'revoke': {
          if (rec.status !== 'approved') throw new DomainError('conflict');

          const note = typeof input.note === 'string' ? input.note.trim() : null;
          if (!note || note.length < 5 || note.length > 500) {
            throw new DomainError('invalid_argument');
          }

          const after: VerificationRecord = {
            ...rec,
            status: 'revoked',
            decidedAt: nowIso,
            decidedBy: staff.uid,
            updatedAt: nowIso,
            version: rec.version + 1,
          };

          tx.putVerification(after);
          tx.setProviderFlags(input.uid as string, {
            verified: false,
            acceptingOrders: false,
          });
          tx.addAudit({
            id: deps.ids.newId(),
            uid: input.uid as string,
            target: 'identity',
            action: 'revoke',
            reason: null,
            note,
            actorId: staff.uid,
            at: nowIso,
          });

          return { before: rec, after };
        }
      }
    } else {
      // Business target (Task 3 handles detailed business verification use cases; review branch stubbed here)
      if (!rec.business || rec.business.status !== 'submitted') {
        throw new DomainError('conflict');
      }

      if (action === 'approve') {
        const purgeAfter = businessDocPurgeAfter(rec.business.docPath, now);
        const bizAfter: BusinessVerificationRecord = {
          ...rec.business,
          status: 'approved',
          decidedAt: nowIso,
          decidedBy: staff.uid,
          rejectReason: null,
          purgeAfter,
        };

        const after: VerificationRecord = {
          ...rec,
          business: bizAfter,
          updatedAt: nowIso,
          version: rec.version + 1,
        };

        tx.putVerification(after);
        tx.setProviderFlags(input.uid as string, { businessVerified: true });
        tx.addAudit({
          id: deps.ids.newId(),
          uid: input.uid as string,
          target: 'business',
          action: 'approve',
          reason: null,
          note: typeof input.note === 'string' ? input.note : null,
          actorId: staff.uid,
          at: nowIso,
        });

        return { before: rec, after };
      } else if (action === 'reject') {
        const reasonCode = input.reason as BusinessRejectReason;
        if (!BUSINESS_REJECT_REASONS.includes(reasonCode)) {
          throw new DomainError('invalid_argument');
        }

        const note = typeof input.note === 'string' ? input.note.trim() : null;
        if (reasonCode === 'other') {
          if (!note || note.length < 5 || note.length > 500) {
            throw new DomainError('invalid_argument');
          }
        } else if (note && (note.length < 5 || note.length > 500)) {
          throw new DomainError('invalid_argument');
        }

        const bizAfter: BusinessVerificationRecord = {
          ...rec.business,
          status: 'rejected',
          decidedAt: nowIso,
          decidedBy: staff.uid,
          rejectReason: {
            code: reasonCode,
            text: note,
          },
          // The registration photo is deleted on the same clock after either decision (Decision 20).
          purgeAfter: businessDocPurgeAfter(rec.business.docPath, now),
        };

        const after: VerificationRecord = {
          ...rec,
          business: bizAfter,
          updatedAt: nowIso,
          version: rec.version + 1,
        };

        tx.putVerification(after);
        tx.addAudit({
          id: deps.ids.newId(),
          uid: input.uid as string,
          target: 'business',
          action: 'reject',
          reason: reasonCode,
          note,
          actorId: staff.uid,
          at: nowIso,
        });

        return { before: rec, after };
      } else {
        throw new DomainError('invalid_argument');
      }
    }
  });
}

/** When a company's registration photo is deleted: BUSINESS_DOC_RETENTION_DAYS after the decision; null without a photo. */
function businessDocPurgeAfter(docPath: string | null, decidedAt: Date): string | null {
  if (docPath === null) return null;
  return new Date(decidedAt.getTime() + BUSINESS_DOC_RETENTION_DAYS * 24 * 60 * 60 * 1000).toISOString();
}

export async function sendVerificationNudges(
  deps: VerificationDeps,
  notify: NotifyDeps,
): Promise<number> {
  const now = deps.clock.now();
  const cutoff = new Date(now.getTime() - VERIFICATION_NUDGE_AFTER_HOURS * 60 * 60 * 1000);
  const candidates = await deps.store.dueForNudge(cutoff, 50);

  let sent = 0;
  for (const rec of candidates) {
    const contact = await deps.store.runTransaction((tx) => tx.getContact(rec.uid));
    // A record with every step done is still in_progress until it is sent: sending is the step left.
    const left = Math.max(1, stepsLeft(rec, contact.phoneVerified, deps.feeRequired));

    const wrote = await deps.store.runTransaction(async (tx) => {
      const current = await tx.getVerification(rec.uid);
      if (!current || current.status !== 'in_progress' || current.nudgedAt !== null) {
        return false;
      }
      tx.putVerification({
        ...current,
        nudgedAt: now.toISOString(),
        updatedAt: now.toISOString(),
        version: current.version + 1,
      });
      return true;
    });
    // Another run nudged it, or it moved on (submitted, edited) since the query: no push.
    if (!wrote) continue;

    await notifyVerificationReminder(notify, {
      uid: rec.uid,
      stepsLeft: left,
      since: rec.updatedAt,
    });
    sent++;
  }

  return sent;
}

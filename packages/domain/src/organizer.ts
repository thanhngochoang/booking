/**
 * Organizers (S30, plan #223 Decisions 2–5): an organizer document per user, staff-reviewed spot claims,
 * a spot's reference entry fees (`access`), resident photographers with waivers, and gate staff. Pure.
 */

import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';

export const ORGANIZER_NAME_MIN = 3;
export const ORGANIZER_NAME_MAX = 60;
export const ORGANIZER_BIO_MAX = 300;
export const MAX_RESIDENTS = 50;
export const MAX_GATE_STAFF = 10;
export const GATE_INVITE_HOURS = 72;
export const ACCESS_FEES_MAX = 6;
export const ACCESS_NOTE_MAX = 120;
export const ORGANIZER_TERMS_VERSION = '2026-10-18';

/** A fee label ("Người lớn", "Gửi xe máy"): 1–40 graphemes. */
export const ACCESS_FEE_LABEL_MAX = 40;
/** Free text on a spot claim (`note`) and a staff rejection `reason`. */
export const CLAIM_NOTE_MAX = 300;
export const CLAIM_PROOFS_MIN = 1;
export const CLAIM_PROOFS_MAX = 3;

export const ORGANIZER_STATUSES = ['active', 'suspended'] as const;
export type OrganizerStatus = (typeof ORGANIZER_STATUSES)[number];

/** `organizers/{uid}`. `phoneVerified`, `businessVerified`, `payoutAccountOk` mirror S21.01, S21.04 and S06.06. */
export interface Organizer {
  readonly id: string;
  readonly name: string;
  readonly bio: string;
  readonly avatarUrl: string | null;
  readonly status: OrganizerStatus;
  readonly phoneVerified: boolean;
  readonly businessVerified: boolean;
  readonly payoutAccountOk: boolean;
  readonly managedSpotIds: readonly string[];
  readonly createdAt: string;
  readonly updatedAt: string;
}

/** Decision 3: selling anything priced needs an active organizer with a verified business and its payout account. */
export const canSell = (o: Pick<Organizer, 'status' | 'businessVerified' | 'payoutAccountOk'>): boolean =>
  o.status === 'active' && o.businessVerified && o.payoutAccountOk;

export const ACCESS_TYPES = ['open', 'ticket'] as const;
export type AccessType = (typeof ACCESS_TYPES)[number];

export interface AccessFee {
  readonly label: string;
  readonly amountVnd: number;
}

/** `spots/{id}.access` (spec §3.3): reference prices shown as "Giá tham khảo · cập nhật {ngày}". */
export interface SpotAccess {
  readonly type: AccessType;
  readonly fees: readonly AccessFee[];
  readonly note: string;
  readonly updatedAt: string;
  readonly source: 'staff' | 'organizer';
}

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

const isPositiveVnd = (v: unknown): v is number => typeof v === 'number' && Number.isSafeInteger(v) && v > 0;

/**
 * `{type, fees, note?}` → SpotAccess stamped with `now` and `source`. `invalid_argument` with field `type`,
 * `fees` (more than 6, a label of 0 or > 40 graphemes, an amount that is not an integer VND > 0) or `note` (> 120).
 * An `open` spot may keep fees as reference (parking, a donation box).
 */
export function validateAccess(raw: unknown, source: SpotAccess['source'], now: Date): SpotAccess {
  if (!isRecord(raw)) throw new DomainError('invalid_argument', 'access');
  const type = raw.type;
  if (type !== 'open' && type !== 'ticket') throw new DomainError('invalid_argument', 'type');
  const rawFees = raw.fees ?? [];
  if (!Array.isArray(rawFees) || rawFees.length > ACCESS_FEES_MAX) throw new DomainError('invalid_argument', 'fees');
  const fees = rawFees.map((f: unknown): AccessFee => {
    if (!isRecord(f) || typeof f.label !== 'string' || !isPositiveVnd(f.amountVnd)) throw new DomainError('invalid_argument', 'fees');
    const label = f.label.trim();
    const n = graphemeCount(label);
    if (n === 0 || n > ACCESS_FEE_LABEL_MAX) throw new DomainError('invalid_argument', 'fees');
    return { label, amountVnd: f.amountVnd };
  });
  const rawNote = raw.note ?? '';
  if (typeof rawNote !== 'string') throw new DomainError('invalid_argument', 'note');
  const note = rawNote.trim();
  if (graphemeCount(note) > ACCESS_NOTE_MAX) throw new DomainError('invalid_argument', 'note');
  return { type, fees, note, updatedAt: now.toISOString(), source };
}

/** `spots/{spotId}/residents/{providerId}` (Decision 5). `validUntil` is a Vietnam day, inclusive. */
export interface Resident {
  readonly providerId: string;
  readonly waivesProvider: boolean;
  readonly waivesGuests: boolean;
  readonly maxGuests: number | null;
  readonly validUntil: string | null;
  readonly addedAt: string;
  readonly addedBy: string;
}

export interface Waiver {
  readonly provider: boolean;
  readonly guests: boolean;
  readonly maxGuests: number | null;
}

export const NO_WAIVER: Waiver = Object.freeze({ provider: false, guests: false, maxGuests: null });

/** The waiver a resident row gives on `today` (yyyy-MM-dd, Vietnam): none after `validUntil`, even before the sweep. */
export function waiverFor(r: Resident | null, today: string): Waiver {
  if (r === null) return NO_WAIVER;
  if (r.validUntil !== null && r.validUntil < today) return NO_WAIVER;
  return { provider: r.waivesProvider, guests: r.waivesGuests, maxGuests: r.maxGuests };
}

export const GATE_STAFF_STATUSES = ['invited', 'active', 'removed'] as const;
export type GateStaffStatus = (typeof GATE_STAFF_STATUSES)[number];

/** `organizers/{uid}/gate_staff/{staffUid}` (spec §3.5). */
export interface GateStaff {
  readonly staffUid: string;
  readonly status: GateStaffStatus;
  readonly invitedAt: string;
  readonly respondedAt: string | null;
  /** S30.06 "{n} mã hôm nay": this staff's gate scans of `day` (Vietnam), written by `scanPass` only. */
  readonly scansToday?: { readonly day: string; readonly count: number };
}

const HOUR_MS = 3_600_000;

/** An invite can still be accepted: `invited` and less than 72 hours old (checked on read and respond, no sweep). */
export const inviteOpen = (g: GateStaff, now: Date): boolean =>
  g.status === 'invited' && Date.parse(g.invitedAt) + GATE_INVITE_HOURS * HOUR_MS > now.getTime();

/** A seat counted towards MAX_GATE_STAFF: active staff and invites still open. */
export const holdsGateSeat = (g: GateStaff, now: Date): boolean => g.status === 'active' || inviteOpen(g, now);

export const SPOT_CLAIM_STATUSES = ['pending', 'approved', 'rejected'] as const;
export type SpotClaimStatus = (typeof SPOT_CLAIM_STATUSES)[number];

export interface SpotProposal {
  readonly name: string;
  readonly address: string;
}

/**
 * `spot_claims/{id}` (Decision 4). A proposal for a spot that does not exist yet has `spotId: null` and a
 * `proposal`; staff add the spot (`spots add`), set `spotId`, then approve.
 */
export interface SpotClaim {
  readonly id: string;
  readonly spotId: string | null;
  readonly proposal: SpotProposal | null;
  readonly organizerId: string;
  readonly status: SpotClaimStatus;
  readonly proofPaths: readonly string[];
  readonly note: string;
  readonly reason: string | null;
  readonly createdAt: string;
  readonly reviewedAt: string | null;
  readonly reviewedBy: string | null;
}

/** The reason written on the other pending claims of a spot when one claim is approved. */
export const CLAIM_REASON_SPOT_MANAGED = 'spot_managed';

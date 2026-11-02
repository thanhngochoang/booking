/**
 * S30 organizer callables (#223, plan Task 6): thin adapters around the organizer use cases. Every handler
 * needs a signed-in caller (`unauthenticated` otherwise), passes the caller's uid, and maps domain refusals
 * through `toHttpsError` (logged by code only). Staff (`reviewSpotClaim`) is the caller's `staffRole == admin`
 * claim, never a lookup of another uid.
 */

import {
  DomainError,
  becomeOrganizer,
  claimSpot,
  inviteGateStaff,
  removeGateStaff,
  removeResident,
  respondGateStaff,
  reviewSpotClaim,
  saveResident,
  updateManagedSpot,
  type EventCaller,
  type Organizer,
  type OrganizerDeps,
  type SpotClaim,
  type SpotCover,
} from '@photobooking/domain';
import { eventCallerOf, runEventCallable, type EventCallableInput } from './event.js';

/** The organizer deps plus the Storage URL prefixes a manager's uploaded spot cover must start with. */
export type OrganizerCallableDeps = OrganizerDeps & { readonly spotCoverPrefixes: readonly string[] };

type Empty = Record<string, never>;

const dataOf = (request: EventCallableInput): Record<string, unknown> =>
  request.data !== null && typeof request.data === 'object' && !Array.isArray(request.data)
    ? (request.data as Record<string, unknown>)
    : {};

/** The caller's deps: staff is the caller's own admin claim. */
function depsFor(deps: OrganizerDeps, caller: EventCaller): OrganizerDeps {
  const p = deps.people;
  return {
    ...deps,
    people: {
      phoneVerified: (uid) => p.phoneVerified(uid),
      businessVerified: (uid) => p.businessVerified(uid),
      payoutAccountOk: (uid) => p.payoutAccountOk(uid),
      lookup: (target) => p.lookup(target),
      isStaff: async (uid) => uid === caller.uid && caller.staffRole === 'admin',
    },
  };
}

async function run<T>(
  operation: string,
  request: EventCallableInput,
  deps: OrganizerDeps,
  fn: (deps: OrganizerDeps, uid: string) => Promise<T>,
): Promise<T> {
  const caller = eventCallerOf(request);
  return runEventCallable(operation, () => fn(depsFor(deps, caller), caller.uid));
}

/**
 * `coverPath` (+ `coverUrl`) of S30.03 → the domain's cover: the manager's upload under `spots/{spotId}/`, whose URL
 * is a download URL of exactly that object in this project's bucket (`prefixes`). `coverPath: null` clears it;
 * absent leaves it. The card image is the cover itself (the app uploads one size).
 */
export function spotCoverOf(
  spotId: string,
  r: { readonly coverPath?: unknown; readonly coverUrl?: unknown },
  prefixes: readonly string[],
): { cover?: SpotCover | null } {
  if (r.coverPath === undefined) return {};
  if (r.coverPath === null) return { cover: null };
  const path = r.coverPath;
  const url = r.coverUrl;
  if (typeof path !== 'string' || typeof url !== 'string' || !path.startsWith(`spots/${spotId}/`)
    || !/^spots\/[A-Za-z0-9_-]+\/[A-Za-z0-9_.-]+$/.test(path)) {
    throw new DomainError('invalid_argument', 'coverPath');
  }
  const prefix = prefixes.find((p) => url.startsWith(p));
  let object = '';
  try {
    object = prefix === undefined ? '' : decodeURIComponent(url.slice(prefix.length).split('?')[0] ?? '');
  } catch {
    object = '';
  }
  if (object !== path) throw new DomainError('invalid_argument', 'coverPath');
  return { cover: { url, cardUrl: url, path } };
}

/** `{name, bio, avatarUrl?}` → `{organizer}` */
export async function handleBecomeOrganizer(request: EventCallableInput, deps: OrganizerDeps): Promise<{ organizer: Organizer }> {
  return run('becomeOrganizer', request, deps, async (d, uid) => ({ organizer: await becomeOrganizer(d, uid, dataOf(request)) }));
}

/** `{spotId? | proposal?, proofPaths[1–3], note?}` → `{claimId}` */
export async function handleClaimSpot(request: EventCallableInput, deps: OrganizerDeps): Promise<{ claimId: string }> {
  return run('claimSpot', request, deps, (d, uid) => claimSpot(d, uid, dataOf(request)));
}

/** Staff admin: `{claimId, approve, reason?}` → `{claim}` */
export async function handleReviewSpotClaim(request: EventCallableInput, deps: OrganizerDeps): Promise<{ claim: SpotClaim }> {
  return run('reviewSpotClaim', request, deps, async (d, uid) => ({ claim: await reviewSpotClaim(d, uid, dataOf(request)) }));
}

/** `{spotId, description?, tips?, coverPath?, coverUrl?, openHours?, access?}` → `{}` */
export async function handleUpdateManagedSpot(request: EventCallableInput, deps: OrganizerCallableDeps): Promise<Empty> {
  return run('updateManagedSpot', request, deps, async (d, uid) => {
    const { coverPath, coverUrl, ...rest } = dataOf(request);
    const spotId = typeof rest.spotId === 'string' ? rest.spotId : '';
    await updateManagedSpot(d, uid, { ...rest, ...spotCoverOf(spotId, { coverPath, coverUrl }, deps.spotCoverPrefixes) });
    return {};
  });
}

/** `{spotId, providerId, waivesProvider, waivesGuests, maxGuests?, validUntil?}` → `{}` */
export async function handleSaveResident(request: EventCallableInput, deps: OrganizerDeps): Promise<Empty> {
  return run('saveResident', request, deps, async (d, uid) => {
    await saveResident(d, uid, dataOf(request));
    return {};
  });
}

/** `{spotId, providerId}` → `{}`: the spot's manager, or the provider leaving. */
export async function handleRemoveResident(request: EventCallableInput, deps: OrganizerDeps): Promise<Empty> {
  return run('removeResident', request, deps, async (d, uid) => {
    await removeResident(d, uid, dataOf(request));
    return {};
  });
}

/** `{target}` (phone; `@username` resolves to nobody until a username exists) → `{}` */
export async function handleInviteGateStaff(request: EventCallableInput, deps: OrganizerDeps): Promise<Empty> {
  return run('inviteGateStaff', request, deps, async (d, uid) => {
    await inviteGateStaff(d, uid, dataOf(request));
    return {};
  });
}

/** `{organizerId, accept}` → `{}`: the invitee, within 72 h. */
export async function handleRespondGateStaff(request: EventCallableInput, deps: OrganizerDeps): Promise<Empty> {
  return run('respondGateStaff', request, deps, async (d, uid) => {
    await respondGateStaff(d, uid, dataOf(request));
    return {};
  });
}

/** `{staffUid}` → `{}` */
export async function handleRemoveGateStaff(request: EventCallableInput, deps: OrganizerDeps): Promise<Empty> {
  return run('removeGateStaff', request, deps, async (d, uid) => {
    await removeGateStaff(d, uid, dataOf(request));
    return {};
  });
}

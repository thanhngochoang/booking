import { DomainError } from './errors.js';
import type { ProviderDeps } from './provider_ports.js';
import { chosenTypeOf, type ProviderType } from './provider_type.js';

function parseChoice(raw: unknown): 'individual' | 'studio' {
  const type = typeof raw === 'object' && raw !== null ? (raw as { type?: unknown }).type : undefined;
  if (type === 'individual' || type === 'studio') return type;
  throw new DomainError('invalid_argument');
}

/**
 * A provider picks individual or studio; only with no open work or held money, and (#136 Decision 7)
 * no members and no open studio relation: a studio keeps its members, a member stays a photographer.
 */
export async function setProviderType(
  deps: ProviderDeps,
  callerId: string,
  raw: unknown,
): Promise<{ providerType: ProviderType }> {
  const wanted = parseChoice(raw);

  const result = await deps.providers.runTransaction(async (tx) => {
    const p = await tx.getProfile(callerId);
    if (p === null) throw new DomainError('not_found');
    if (chosenTypeOf(p.providerType) === wanted) {
      return { changed: false, type: p.providerType };
    }
    // Always checked, whatever onboardingComplete says: a client could
    // write it back to false to skip the check. A new profile has no work.
    const [bookings, held, relations] = await Promise.all([
      tx.countActiveBookings(callerId),
      tx.countHeldPayments(callerId),
      tx.countOpenRelations(callerId),
    ]);
    if (bookings > 0 || held > 0) throw new DomainError('not_eligible');
    if (p.memberCount > 0 || relations > 0) throw new DomainError('membership_conflict');
    tx.setProviderType(callerId, wanted, deps.clock.now());
    return { changed: true, type: wanted as ProviderType };
  });

  if (result.changed && result.type === 'individual') {
    await deps.recomputeArtistTier(callerId);
  }
  return { providerType: result.type };
}

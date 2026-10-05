import { DomainError } from './errors.js';
import type { ProviderDeps } from './provider_ports.js';
import { chosenTypeOf, type ProviderType } from './provider_type.js';

function parseChoice(raw: unknown): 'individual' | 'studio' {
  const type = typeof raw === 'object' && raw !== null ? (raw as { type?: unknown }).type : undefined;
  if (type === 'individual' || type === 'studio') return type;
  throw new DomainError('invalid_argument');
}

/** A provider picks individual or studio; after setup, only with no open work or held money. */
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
    if (p.onboardingComplete) {
      const [bookings, held] = await Promise.all([
        tx.countActiveBookings(callerId),
        tx.countHeldPayments(callerId),
      ]);
      if (bookings > 0 || held > 0) throw new DomainError('not_eligible');
    }
    tx.setProviderType(callerId, wanted, deps.clock.now());
    return { changed: true, type: wanted as ProviderType };
  });

  if (result.changed && result.type === 'individual') {
    await deps.recomputeArtistTier(callerId);
  }
  return { providerType: result.type };
}

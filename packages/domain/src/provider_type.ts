export const PROVIDER_TYPES = ['individual', 'artist', 'studio'] as const;
export type ProviderType = (typeof PROVIDER_TYPES)[number];

/** Missing or unknown → 'individual'. */
export function providerTypeOf(raw: unknown): ProviderType {
  return (PROVIDER_TYPES as readonly unknown[]).includes(raw) ? (raw as ProviderType) : 'individual';
}

/** 'artist' counts as 'individual' for choices and switches. */
export function chosenTypeOf(t: ProviderType): 'individual' | 'studio' {
  return t === 'studio' ? 'studio' : 'individual';
}

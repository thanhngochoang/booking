import { ARTIST_THRESHOLD } from './award.js';
import type { ProviderType } from './provider_type.js';

/** Pure tier rule (spec §2.3). */
export function tierFor(current: ProviderType, approvedCount: number): ProviderType {
  if (current === 'studio') return 'studio';
  return approvedCount >= ARTIST_THRESHOLD ? 'artist' : 'individual';
}

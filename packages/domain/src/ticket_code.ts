import { formatVnDate } from './booking_policy.js';

/** No `0 O 1 I`: easy to read out loud and to type from a screen. */
export const TICKET_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/**
 * `VE-XXXX-MMDD` candidates (MMDD = the event day in Vietnam). Distinct; fewer than `count` only if
 * the random source keeps repeating itself.
 */
export function ticketCodeCandidates(
  eventDay: Date,
  random: (n: number) => Uint8Array,
  count = 5,
): string[] {
  const [, mm, dd] = formatVnDate(eventDay).split('-');
  const suffix = `${mm ?? '00'}${dd ?? '00'}`;
  const out = new Set<string>();
  for (let attempt = 0; attempt < count * 20 && out.size < count; attempt++) {
    const bytes = random(4);
    let part = '';
    for (let i = 0; i < 4; i++) part += TICKET_ALPHABET.charAt((bytes[i] ?? 0) % TICKET_ALPHABET.length);
    out.add(`VE-${part}-${suffix}`);
  }
  return [...out];
}

export const isTicketCode = (s: string): boolean => /^VE-[A-HJ-NP-Z2-9]{4}-\d{4}$/.test(s);

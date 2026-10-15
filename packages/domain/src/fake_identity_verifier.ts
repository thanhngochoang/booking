import { foldVietnamese } from './event_hashtag.js';
import type { IdGenerator } from './ports.js';
import type {
  IdentityResult,
  IdentityVerifier,
} from './verification_ports.js';
import type { IdentityMethod } from './verification.js';

/**
 * FNV-1a 32-bit hash implementation.
 * Returns '0' + 11 digits = 12 digits total.
 */
export function fakeIdNumberOf(uid: string): string {
  let hash = 0x811c9dc5;
  for (let i = 0; i < uid.length; i++) {
    hash ^= uid.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  // Convert 32-bit unsigned integer to positive number
  const unsigned = hash >>> 0;
  // Pad/truncate to 11 digits
  const elevenDigits = String(unsigned).padStart(11, '0').slice(-11);
  return `0${elevenDigits}`;
}

export class FakeIdentityVerifier implements IdentityVerifier {
  constructor(
    private readonly source: (uid: string) => Promise<(Partial<IdentityResult> & { displayName?: string }) | null>,
    private readonly ids: IdGenerator,
  ) {}

  async start(uid: string, method: IdentityMethod): Promise<{ sessionId: string; redirectUrl: string | null }> {
    void uid;
    void method;
    const sessionId = this.ids.newId();
    return {
      sessionId,
      redirectUrl: null,
    };
  }

  async result(uid: string, sessionId: string): Promise<IdentityResult> {
    void sessionId;
    const override = await this.source(uid);

    let legalName = 'NGUOI DUNG THU';
    if (override?.legalName) {
      legalName = override.legalName;
    } else if (override?.displayName) {
      legalName = foldVietnamese(override.displayName).toUpperCase();
    }

    return {
      passed: override?.passed ?? true,
      legalName,
      dob: override?.dob ?? '1995-01-01',
      gender: override?.gender ?? null,
      idNumber: override?.idNumber ?? fakeIdNumberOf(uid),
      provider: override?.provider ?? 'fake',
      providerRef: override?.providerRef ?? `fake_ref_${uid}`,
    };
  }
}

import * as logger from 'firebase-functions/logger';

export interface DeviceWriteDeps {
  /** Ids of the other device docs holding `token`. */
  otherDevicesWithToken(token: string, exceptId: string): Promise<string[]>;
  remove(ids: readonly string[]): Promise<void>;
}

/**
 * Tradeoff (kept on purpose): the other docs are removed whatever their owner, because the case this
 * covers is a second account signing in on the same phone; the old account's push would otherwise
 * reach the new user. A token is per install, so two real users never legitimately share one.
 * Decision 10: a token belongs to one account; the previous holders' docs go (same phone, new sign-in).
 */
export async function handleDeviceWrite(
  id: string,
  before: { token?: unknown } | undefined,
  after: { token?: unknown } | undefined,
  deps: DeviceWriteDeps,
): Promise<number> {
  const token = after?.token;
  if (typeof token !== 'string' || token === '' || before?.token === token) return 0;
  const others = await deps.otherDevicesWithToken(token, id);
  if (others.length > 0) {
    await deps.remove(others);
    logger.info('onDeviceWrite removed stale device docs', { removed: others.length });
  }
  return others.length;
}

import { evaluateUserBadges, type BadgeDeps } from '@photobooking/domain';

type Service = { active?: unknown } | undefined;

/** `complete_profile` depends on having an active package: evaluate when that changes. */
export async function handleServiceWrite(uid: string, before: Service, after: Service, deps: BadgeDeps): Promise<boolean> {
  const active = (s: Service): boolean => s !== undefined && s.active !== false;
  if (active(before) === active(after)) return false;
  await evaluateUserBadges(deps, uid);
  return true;
}

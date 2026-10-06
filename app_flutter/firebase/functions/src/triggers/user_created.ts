import { evaluateUserBadges, type BadgeDeps } from '@photobooking/domain';

/** A new account earns `new_member` right away. */
export async function handleUserCreated(uid: string, deps: BadgeDeps): Promise<string[]> {
  return (await evaluateUserBadges(deps, uid)).awarded;
}

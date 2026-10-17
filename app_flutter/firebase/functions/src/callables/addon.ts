import { HttpsError } from 'firebase-functions/v2/https';
import { deleteAddon, saveAddon, type AddonDeps } from '@photobooking/domain';
import { handleCallableError } from './booking.js';
import type { CallableInput } from './get_contact_link.js';

function requireUid(request: CallableInput): string {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  return uid;
}

/** `{addonId?, kind, name, description?, price, unit, maxQty, serviceIds, active}` → `{addonId}` */
export async function handleSaveAddon(request: CallableInput, deps: AddonDeps): Promise<{ addonId: string }> {
  const uid = requireUid(request);
  try {
    return await saveAddon(deps, uid, request.data);
  } catch (e) {
    handleCallableError('saveAddon', e);
  }
}

/** `{addonId}` → `{}` */
export async function handleDeleteAddon(request: CallableInput, deps: AddonDeps): Promise<Record<string, never>> {
  const uid = requireUid(request);
  try {
    return await deleteAddon(deps, uid, request.data);
  } catch (e) {
    handleCallableError('deleteAddon', e);
  }
}

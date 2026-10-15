import { MAX_ACTIVE_ADDONS, validateAddonInput } from './addon.js';
import type { AddonDeps } from './addon_ports.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export async function saveAddon(
  deps: AddonDeps,
  callerId: string,
  raw: unknown,
): Promise<{ addonId: string }> {
  const input = validateAddonInput(raw);
  for (const sid of input.serviceIds) {
    if (!(await deps.services.getService(callerId, sid))) {
      throw new DomainError('invalid_argument', 'serviceIds');
    }
  }
  const now = deps.clock.now().toISOString();
  return deps.addons.runTransaction(async (tx) => {
    if (!(await tx.isProvider(callerId))) throw new DomainError('permission_denied');
    await tx.lockProvider(callerId); // Decision 8: serializes concurrent saves
    const all = await tx.listAddons(callerId);
    const existing =
      input.addonId === undefined ? null : (all.find((a) => a.id === input.addonId) ?? null);
    if (input.addonId !== undefined && existing === null) throw new DomainError('not_found');
    const othersActive = all.filter((a) => a.active && a.id !== existing?.id).length;
    const turningOn = input.active && !(existing?.active ?? false);
    if (turningOn && othersActive >= MAX_ACTIVE_ADDONS) throw new DomainError('addon_limit');
    const id = existing?.id ?? deps.ids.newId();
    tx.putAddon({
      id,
      providerId: callerId,
      kind: input.kind,
      name: input.name,
      ...(input.description ? { description: input.description } : {}),
      price: input.price,
      unit: input.unit,
      maxQty: input.unit === 'per_booking' ? 1 : input.maxQty,
      serviceIds: input.serviceIds,
      active: input.active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    });
    tx.setActiveCount(callerId, othersActive + (input.active ? 1 : 0), now);
    return { addonId: id };
  });
}

export async function deleteAddon(
  deps: AddonDeps,
  callerId: string,
  raw: unknown,
): Promise<Record<string, never>> {
  const addonId = (raw as { addonId?: unknown } | null)?.addonId;
  if (!isId(addonId)) throw new DomainError('invalid_argument', 'addonId');
  const now = deps.clock.now().toISOString();
  await deps.addons.runTransaction(async (tx) => {
    if (!(await tx.isProvider(callerId))) throw new DomainError('permission_denied');
    await tx.lockProvider(callerId);
    const all = await tx.listAddons(callerId);
    if (!all.some((a) => a.id === addonId)) throw new DomainError('not_found');
    tx.deleteAddon(callerId, addonId);
    tx.setActiveCount(callerId, all.filter((a) => a.active && a.id !== addonId).length, now);
  });
  return {};
}

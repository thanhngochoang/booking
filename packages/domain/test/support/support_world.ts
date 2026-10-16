import type { Clock, IdGenerator } from '../../src/ports.js';
import { MemorySupportStore } from '../../src/memory_support_store.js';
import type { DisplayNames, SupportDeps } from '../../src/support_use_cases.js';

export interface SupportWorld {
  readonly store: MemorySupportStore;
  readonly names: DisplayNames;
  readonly clock: Clock;
  readonly ids: IdGenerator;
  readonly deps: SupportDeps;
}

export function createSupportWorld(initialNow: Date = new Date('2026-10-10T10:00:00.000Z')): SupportWorld {
  let currentTime = initialNow.getTime();
  let nextIdNum = 1;

  const store = new MemorySupportStore();
  const displayNamesMap = new Map<string, string>([
    ['u1', 'Người Dùng Một'],
    ['u2', 'Người Dùng Hai'],
    ['staff1', 'Nhân Viên Một'],
  ]);

  const names: DisplayNames = {
    displayName: async (uid: string) => displayNamesMap.get(uid) ?? '',
  };

  const clock: Clock & { set: (d: Date) => void; advanceMinutes: (m: number) => void } = {
    now: () => new Date(currentTime),
    set: (d: Date) => {
      currentTime = d.getTime();
    },
    advanceMinutes: (m: number) => {
      currentTime += m * 60 * 1000;
    },
  };

  const ids: IdGenerator = {
    newId: () => `id_${nextIdNum++}`,
  };

  const deps: SupportDeps = {
    store,
    names,
    clock,
    ids,
  };

  return {
    store,
    names,
    clock,
    ids,
    deps,
  };
}

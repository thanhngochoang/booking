import type { Clock } from '../../src/ports.js';
import type { DiscoveryDeps } from '../../src/discovery_ports.js';
import { MemoryDiscoveryStore } from '../../src/memory_discovery_store.js';

export function createDiscoveryWorld(opts?: { nowIso?: string }): {
  deps: DiscoveryDeps;
  store: MemoryDiscoveryStore;
  setNow(iso: string): void;
} {
  let currentTime = opts?.nowIso
    ? new Date(opts.nowIso)
    : new Date('2026-10-07T12:00:00Z');

  const clock: Clock = {
    now: () => currentTime,
  };

  const store = new MemoryDiscoveryStore();

  const deps: DiscoveryDeps = {
    stats: store,
    engagement: store,
    catalog: store,
    clock,
  };

  return {
    deps,
    store,
    setNow(iso: string) {
      currentTime = new Date(iso);
    },
  };
}

import type { PublicProfiles } from '../../src/block_ports.js';
import { MemoryBlockStore } from '../../src/memory_block_store.js';
import { MemoryReportStore } from '../../src/memory_report_store.js';
import type { BlockDeps } from '../../src/block_ports.js';
import type { ReportDeps } from '../../src/report_ports.js';
import { FakeClock } from './chat_world.js';

export class FakePublicProfiles implements PublicProfiles {
  readonly profiles = new Map<string, { name: string; avatarUrl: string | null }>();

  setProfile(uid: string, name: string, avatarUrl: string | null = null): void {
    this.profiles.set(uid, { name, avatarUrl });
  }

  async get(uid: string): Promise<{ name: string; avatarUrl: string | null } | null> {
    const p = this.profiles.get(uid);
    return p ? { ...p } : null;
  }
}

export interface SafetyWorld {
  readonly clock: FakeClock;
  readonly blockStore: MemoryBlockStore;
  readonly profiles: FakePublicProfiles;
  readonly blockDeps: BlockDeps;
  readonly reportStore: MemoryReportStore;
  readonly reportDeps: ReportDeps;
}

export function createSafetyWorld(): SafetyWorld {
  const clock = new FakeClock(new Date('2026-10-07T10:00:00.000Z'));
  const blockStore = new MemoryBlockStore();
  const profiles = new FakePublicProfiles();
  const reportStore = new MemoryReportStore();

  const blockDeps: BlockDeps = {
    store: blockStore,
    profiles,
    clock,
  };

  const reportDeps: ReportDeps = {
    store: reportStore,
    blocks: blockDeps,
    clock,
  };

  return {
    clock,
    blockStore,
    profiles,
    blockDeps,
    reportStore,
    reportDeps,
  };
}

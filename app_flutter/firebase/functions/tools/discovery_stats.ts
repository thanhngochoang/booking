// Staff/admin CLI for recomputing discovery stats:
//   npm run stats -- recompute [--only nextFree|price|completed|engagement|catalog|acceptingOrders]
// Refuses to touch a production project without explicit credentials, like tools/awards.ts.

import { fileURLToPath } from 'node:url';
import {
  acceptingOrdersPatch,
  refreshNextFreeDate,
  refreshStartingPrice,
  refreshCompletedCount,
  refreshEngagementCount,
  refreshExploreCategory,
  type DiscoveryDeps,
} from '@photobooking/domain';
import { assertLocalEmulators } from '../seed/local_guard.js';

export const HELP = `usage: stats recompute [--only nextFree|price|completed|engagement|catalog|acceptingOrders]

Environment:
  GOOGLE_APPLICATION_CREDENTIALS  path to a service account key (real project)
  GCLOUD_PROJECT                  project id
  FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
                                  use these instead of credentials to work against the emulators
`;

export type StatSubKind = 'nextFree' | 'price' | 'completed' | 'engagement' | 'catalog' | 'acceptingOrders';

export interface ParsedStatsArgs {
  readonly command: 'recompute';
  readonly only: StatSubKind | null;
}

export function parseStatsArgs(argv: readonly string[]): ParsedStatsArgs {
  const rest: string[] = [];
  let only: StatSubKind | null = null;
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i] as string;
    if (a === '--only') {
      const val = argv[i + 1] as StatSubKind | undefined;
      i += 1;
      if (!val || !['nextFree', 'price', 'completed', 'engagement', 'catalog', 'acceptingOrders'].includes(val)) {
        throw new Error('invalid --only option. ' + HELP);
      }
      only = val;
    } else {
      rest.push(a);
    }
  }
  if (rest[0] !== 'recompute') {
    throw new Error('invalid command. ' + HELP);
  }
  return { command: 'recompute', only };
}

export interface StatsCliIo {
  print(line: string): void;
  listPhotographerUids(): Promise<string[]>;
  listPostIds(): Promise<string[]>;
  listSpecialties(): Promise<string[]>;
  syncAcceptingOrders(uid: string): Promise<boolean>;
}

export async function runStatsCli(
  argv: readonly string[],
  deps: DiscoveryDeps,
  io: StatsCliIo,
): Promise<void> {
  const args = parseStatsArgs(argv);

  const shouldRun = (k: StatSubKind) => args.only === null || args.only === k;

  let nextFreeCount = 0;
  let priceCount = 0;
  let completedCount = 0;
  let engagementCount = 0;
  let catalogCount = 0;
  let acceptingOrdersCount = 0;

  if (shouldRun('acceptingOrders') || shouldRun('nextFree') || shouldRun('price') || shouldRun('completed')) {
    const uids = await io.listPhotographerUids();
    for (const uid of uids) {
      if (shouldRun('acceptingOrders')) {
        const synced = await io.syncAcceptingOrders(uid);
        if (synced) acceptingOrdersCount += 1;
      }
      if (shouldRun('nextFree')) {
        const res = await refreshNextFreeDate(deps, uid);
        if (res === 'written') nextFreeCount += 1;
      }
      if (shouldRun('price')) {
        const res = await refreshStartingPrice(deps, uid);
        if (res === 'written') priceCount += 1;
      }
      if (shouldRun('completed')) {
        const res = await refreshCompletedCount(deps, uid);
        if (res === 'written') completedCount += 1;
      }
    }
  }

  if (shouldRun('engagement')) {
    const postIds = await io.listPostIds();
    for (const pid of postIds) {
      const l = await refreshEngagementCount(deps, 'like', pid);
      const s = await refreshEngagementCount(deps, 'save', pid);
      if (l === 'written' || s === 'written') engagementCount += 1;
    }
  }

  if (shouldRun('catalog')) {
    const specialties = await io.listSpecialties();
    for (const spec of specialties) {
      const res = await refreshExploreCategory(deps, spec);
      if (res === 'written') catalogCount += 1;
    }
  }

  io.print(`recomputed: nextFree=${nextFreeCount} price=${priceCount} completed=${completedCount} engagement=${engagementCount} catalog=${catalogCount} acceptingOrders=${acceptingOrdersCount}`);
}

async function main(): Promise<void> {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log(HELP);
    return;
  }

  const env = process.env;
  if (!env.FIRESTORE_EMULATOR_HOST) {
    if (!env.GOOGLE_APPLICATION_CREDENTIALS && !env.GCLOUD_PROJECT) {
      throw new Error('Refusing to run without credentials or emulator environment. ' + HELP);
    }
  } else {
    assertLocalEmulators({ allowAnyProject: true }, env);
  }

  const { db } = await import('../src/infra/admin.js');
  const { liveDiscoveryDeps } = await import('../src/infra/live_discovery.js');
  const firestore = db();
  const deps = liveDiscoveryDeps();

  const io: StatsCliIo = {
    print: (l) => console.log(l),
    listPhotographerUids: async () => {
      const snap = await firestore.collection('photographers').select().get();
      return snap.docs.map((d) => d.id);
    },
    listPostIds: async () => {
      const snap = await firestore.collection('posts').select().get();
      return snap.docs.map((d) => d.id);
    },
    listSpecialties: async () => {
      const snap = await firestore.collectionGroup('services').select('specialty').get();
      const set = new Set<string>();
      for (const d of snap.docs) {
        const s = d.get('specialty');
        if (typeof s === 'string' && s.length > 0) set.add(s);
      }
      return [...set];
    },
    syncAcceptingOrders: async (uid: string) => {
      const doc = await firestore.collection('photographers').doc(uid).get();
      if (!doc.exists) return false;
      const data = doc.data() ?? {};
      const patch = acceptingOrdersPatch(data);
      if (patch === null) return false;
      await doc.ref.update({ acceptingOrders: patch.acceptingOrders });
      return true;
    },
  };

  await runStatsCli(process.argv.slice(2), deps, io);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}

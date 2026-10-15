// Staff CLI for spots management and ranking (spec S29, plan Task 4):
//   npm run spots -- list [--area <code>]
//   npm run spots -- add --name … --city … --area … --lat … --lng … --radius … [--season 10,11,12] [--cover <file.jpg>] [--card <file.jpg>] [--description …] [--tip …]… --actor <uid>
//   npm run spots -- edit <id> [same flags] --actor <uid>
//   npm run spots -- pin|unpin|hide|unhide|archive <id> --actor <uid>
//   npm run spots -- rank
// Uses the Admin SDK.

import { fileURLToPath } from 'node:url';
import * as fs from 'node:fs/promises';
import {
  addSpot,
  editSpot,
  setSpotFlag,
  rankSpots,
  spotDirectory,
  runSpotRanking,
  formatVnDate,
  type Spot,
  type SpotCover,
  type SpotRankStore,
  type SpotCounter,
  type SpotAdminStore,
  type Clock,
  type IdGenerator,
} from '@photobooking/domain';
import { assertLocalEmulators, LOCAL_HOST } from '../seed/local_guard.js';

export const HELP = `usage: spots list [--area <code>]
       spots add --name <n> --city <c> --area <a> --lat <lat> --lng <lng> --radius <m> [--season 10,11,12] [--cover <file.jpg>] [--card <file.jpg>] [--description <d>] [--tip <t>]... --actor <uid>
       spots edit <id> [same flags] --actor <uid>
       spots pin|unpin|hide|unhide|archive <id> --actor <uid>
       spots rank

Environment:
  GOOGLE_APPLICATION_CREDENTIALS  path to a service account key (production)
  GCLOUD_PROJECT                  project id
  STORAGE_BUCKET                  bucket for spot covers (or FIREBASE_STORAGE_BUCKET)
  FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST, FIREBASE_STORAGE_EMULATOR_HOST
                                  use these instead of credentials to work against the emulators
--actor must be a user with the custom claim staffRole = admin.

scripts/spots-local.sh sets all of this for the local emulators.`;

const EMULATOR_HOST_VARS = [
  'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_AUTH_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST',
] as const;

export function guardEnv(env: Readonly<Record<string, string | undefined>>): void {
  const clientStorage = env.STORAGE_EMULATOR_HOST;
  if (clientStorage !== undefined && clientStorage !== '' && !LOCAL_HOST.test(clientStorage.replace(/^https?:\/\//, ''))) {
    throw new Error(`Refusing to run: STORAGE_EMULATOR_HOST must point at a local emulator (got ${clientStorage}).`);
  }
  if (!EMULATOR_HOST_VARS.some((k) => env[k] !== undefined && env[k] !== '')) return;
  assertLocalEmulators({ allowAnyProject: true }, env as NodeJS.ProcessEnv);
  if (env.GOOGLE_APPLICATION_CREDENTIALS !== undefined && env.GOOGLE_APPLICATION_CREDENTIALS !== '') {
    throw new Error(
      'Refusing to run: GOOGLE_APPLICATION_CREDENTIALS is set while the emulator hosts are; unset it (scripts/spots-local.sh does).',
    );
  }
  const storage = env.FIREBASE_STORAGE_EMULATOR_HOST;
  if (storage === undefined || storage === '' || !LOCAL_HOST.test(storage)) {
    throw new Error(
      `Refusing to run: FIREBASE_STORAGE_EMULATOR_HOST must point at a local emulator (got ${storage ?? 'nothing'}).`,
    );
  }
}

export type Command = 'list' | 'add' | 'edit' | 'pin' | 'unpin' | 'hide' | 'unhide' | 'archive' | 'rank';

export interface ParsedArgs {
  readonly command: Command;
  readonly id: string | null;
  readonly area: string | null;
  readonly name: string | null;
  readonly city: string | null;
  readonly lat: number | null;
  readonly lng: number | null;
  readonly radiusM: number | null;
  readonly seasonMonths: number[] | null;
  readonly coverPath: string | null;
  readonly cardPath: string | null;
  readonly description: string | null;
  readonly tips: string[];
  readonly actor: string | null;
}

export function parseArgs(argv: readonly string[]): ParsedArgs {
  if (argv.length === 0) throw new Error(HELP);
  const command = argv[0] as Command;
  if (!['list', 'add', 'edit', 'pin', 'unpin', 'hide', 'unhide', 'archive', 'rank'].includes(command)) {
    throw new Error(HELP);
  }

  let id: string | null = null;
  let area: string | null = null;
  let name: string | null = null;
  let city: string | null = null;
  let lat: number | null = null;
  let lng: number | null = null;
  let radiusM: number | null = null;
  let seasonMonths: number[] | null = null;
  let coverPath: string | null = null;
  let cardPath: string | null = null;
  let description: string | null = null;
  const tips: string[] = [];
  let actor: string | null = null;

  let i = 1;
  if (['edit', 'pin', 'unpin', 'hide', 'unhide', 'archive'].includes(command)) {
    id = argv[1] ?? null;
    if (!id || id.startsWith('--')) {
      throw new Error(`Command ${command} requires a spot id. ${HELP}`);
    }
    i = 2;
  }

  for (; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--area') {
      area = argv[++i] ?? null;
    } else if (a === '--name') {
      name = argv[++i] ?? null;
    } else if (a === '--city') {
      city = argv[++i] ?? null;
    } else if (a === '--lat') {
      lat = parseFloat(argv[++i] ?? '');
    } else if (a === '--lng') {
      lng = parseFloat(argv[++i] ?? '');
    } else if (a === '--radius') {
      radiusM = parseInt(argv[++i] ?? '', 10);
    } else if (a === '--season') {
      const s = argv[++i] ?? '';
      seasonMonths = s.split(',').map((v) => parseInt(v.trim(), 10)).filter((n) => !isNaN(n));
    } else if (a === '--cover') {
      coverPath = argv[++i] ?? null;
    } else if (a === '--card') {
      cardPath = argv[++i] ?? null;
    } else if (a === '--description') {
      description = argv[++i] ?? null;
    } else if (a === '--tip') {
      const t = argv[++i];
      if (t) tips.push(t);
    } else if (a === '--actor') {
      actor = argv[++i] ?? null;
    }
  }

  return {
    command,
    id,
    area,
    name,
    city,
    lat,
    lng,
    radiusM,
    seasonMonths,
    coverPath,
    cardPath,
    description,
    tips,
    actor,
  };
}

export interface SpotCliIo {
  print(line: string): void;
  now(): Date;
  isAdmin(uid: string): Promise<boolean>;
  uploadCover?(spotId: string, coverPath: string, cardPath: string): Promise<SpotCover>;
}

export interface SpotCliDeps {
  readonly spots: SpotRankStore & SpotAdminStore;
  readonly counter: SpotCounter;
  readonly clock: Clock;
  readonly ids: IdGenerator;
  readonly staff: { isAdmin(uid: string): Promise<boolean> };
}

/** Validates that a file is a JPEG <= maxSize bytes. */
export async function validateJpegFile(filePath: string, maxSize: number): Promise<void> {
  const stat = await fs.stat(filePath);
  if (stat.size > maxSize) {
    throw new Error(`File ${filePath} exceeds max size ${maxSize} bytes (got ${stat.size})`);
  }
  const fh = await fs.open(filePath, 'r');
  try {
    const buf = Buffer.alloc(3);
    await fh.read(buf, 0, 3, 0);
    if (buf[0] !== 0xff || buf[1] !== 0xd8 || buf[2] !== 0xff) {
      throw new Error(`File ${filePath} is not a valid JPEG (missing SOI marker 0xFF 0xD8 0xFF)`);
    }
  } finally {
    await fh.close();
  }
}

/** Rewrites rankings and directory from stored spots without re-counting stats. */
async function rewriteRankings(spotsStore: SpotRankStore, clock: Clock): Promise<void> {
  const allSpots = await spotsStore.listSpots();
  const now = clock.now();
  const nowIso = now.toISOString();
  const today = formatVnDate(now);
  const month = parseInt(today.split('-')[1] ?? '1', 10);

  const rankings = rankSpots(allSpots, month, nowIso);
  const directory = spotDirectory(allSpots, month);

  const staleKeys = (await spotsStore.listRankingKeys?.()) ?? [];
  const activeKeys = new Set(rankings.map((r) => r.key));
  await spotsStore.saveRankings(rankings, staleKeys.filter((k) => !activeKeys.has(k)));
  await spotsStore.saveDirectory(directory, nowIso);
}

export async function runCli(argv: readonly string[], deps: SpotCliDeps, io: SpotCliIo): Promise<void> {
  const args = parseArgs(argv);

  if (args.command === 'list') {
    const all = await deps.spots.listSpots();
    const filtered = args.area ? all.filter((s) => s.areaCode === args.area) : all;
    for (const s of filtered) {
      const flags = [
        s.pinned ? 'pinned' : null,
        s.hidden ? 'hidden' : null,
        s.status === 'archived' ? 'archived' : null,
      ]
        .filter(Boolean)
        .join(',');
      io.print(`${s.id}  ${s.name}  ${s.areaCode}  ${s.status}  ${flags ? `[${flags}]` : '[]'}  hotScore: ${s.hotScore}`);
    }
    return;
  }

  if (args.command === 'rank') {
    const result = await runSpotRanking({
      store: deps.spots,
      counter: deps.counter,
      clock: deps.clock,
    });
    io.print(`rankSpots completed: spots: ${result.spots}, changed: ${result.changed}, keys: ${result.keys.join(', ')}`);
    return;
  }

  if (!args.actor) {
    throw new Error(`Command ${args.command} needs --actor <uid> of an admin. ${HELP}`);
  }
  if (!(await io.isAdmin(args.actor))) {
    throw new Error(`${args.actor} does not have the admin claim`);
  }

  if (args.command === 'add') {
    let cover: SpotCover | null = null;
    const spotId = deps.ids.newId();
    if (args.coverPath && args.cardPath && io.uploadCover) {
      await validateJpegFile(args.coverPath, 2 * 1024 * 1024);
      await validateJpegFile(args.cardPath, 200 * 1024);
      cover = await io.uploadCover(spotId, args.coverPath, args.cardPath);
    }

    const raw = {
      name: args.name,
      city: args.city,
      areaCode: args.area,
      lat: args.lat,
      lng: args.lng,
      radiusM: args.radiusM,
      seasonMonths: args.seasonMonths ?? [],
      description: args.description ?? '',
      tips: args.tips,
      cover,
    };

    const added = await addSpot(
      {
        spots: deps.spots,
        staff: deps.staff,
        clock: deps.clock,
        ids: { newId: () => spotId },
      },
      args.actor,
      raw,
    );

    await rewriteRankings(deps.spots, deps.clock);
    io.print(`Added spot ${added.id}: ${added.name}`);
    return;
  }

  const id = args.id as string;

  if (args.command === 'edit') {
    let cover: SpotCover | null | undefined = undefined;
    if (args.coverPath && args.cardPath && io.uploadCover) {
      await validateJpegFile(args.coverPath, 2 * 1024 * 1024);
      await validateJpegFile(args.cardPath, 200 * 1024);
      cover = await io.uploadCover(id, args.coverPath, args.cardPath);
    }

    const existing = await deps.spots.getSpot(id);
    if (!existing) throw new Error(`Spot ${id} not found`);

    const raw = {
      name: args.name ?? existing.name,
      city: args.city ?? existing.city,
      areaCode: args.area ?? existing.areaCode,
      lat: args.lat ?? existing.point.lat,
      lng: args.lng ?? existing.point.lng,
      radiusM: args.radiusM ?? existing.radiusM,
      seasonMonths: args.seasonMonths ?? existing.seasonMonths,
      description: args.description ?? existing.description,
      tips: args.tips.length > 0 ? args.tips : existing.tips,
      cover: cover !== undefined ? cover : existing.cover,
    };

    const edited = await editSpot(
      {
        spots: deps.spots,
        staff: deps.staff,
        clock: deps.clock,
        ids: deps.ids,
      },
      args.actor,
      id,
      raw,
    );

    await rewriteRankings(deps.spots, deps.clock);
    io.print(`Edited spot ${edited.id}: ${edited.name}`);
    return;
  }

  if (['pin', 'unpin', 'hide', 'unhide', 'archive'].includes(args.command)) {
    const updated = await setSpotFlag(
      {
        spots: deps.spots,
        staff: deps.staff,
        clock: deps.clock,
        ids: deps.ids,
      },
      args.actor,
      id,
      args.command as 'pin' | 'unpin' | 'hide' | 'unhide' | 'archive',
    );

    await rewriteRankings(deps.spots, deps.clock);
    io.print(`Spot ${updated.id} -> ${args.command}`);
    return;
  }
}

async function main(): Promise<void> {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log(HELP);
    return;
  }
  guardEnv(process.env);
  const { getAuth } = await import('firebase-admin/auth');
  const { getStorage } = await import('firebase-admin/storage');
  const { db } = await import('../src/infra/admin.js');
  const {
    FirestoreSpotRankStore,
    FirestoreSpotAdminStore,
    FirestoreSpotCounter,
  } = await import('../src/infra/spot_rank_firestore.js');
  const { randomUUID } = await import('node:crypto');

  const firestore = db();
  const rankStore = new FirestoreSpotRankStore(firestore);
  const adminStore = new FirestoreSpotAdminStore(firestore);
  const counter = new FirestoreSpotCounter(firestore);

  const mergedStore: SpotRankStore & SpotAdminStore = {
    listSpots: () => rankStore.listSpots(),
    saveSpot: (s: Spot) => rankStore.saveSpot(s),
    listRankingKeys: () => rankStore.listRankingKeys(),
    saveRankings: (r, s) => rankStore.saveRankings(r, s),
    saveDirectory: (d, n) => rankStore.saveDirectory(d, n),
    getSpot: (id) => adminStore.getSpot(id),
    putSpot: (s) => adminStore.putSpot(s),
  };

  const io: SpotCliIo = {
    print: (l) => console.log(l),
    now: () => new Date(),
    isAdmin: async (uid) => (await getAuth().getUser(uid)).customClaims?.staffRole === 'admin',
    uploadCover: async (spotId, coverPath, cardPath) => {
      const bucketName = process.env.STORAGE_BUCKET ?? process.env.FIREBASE_STORAGE_BUCKET;
      const bucket = getStorage().bucket(bucketName);
      const coverDest = `spots/${spotId}/cover.jpg`;
      const cardDest = `spots/${spotId}/card.jpg`;
      await bucket.upload(coverPath, { destination: coverDest, contentType: 'image/jpeg' });
      await bucket.upload(cardPath, { destination: cardDest, contentType: 'image/jpeg' });
      const bucketHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST
        ? `http://${process.env.FIREBASE_STORAGE_EMULATOR_HOST}/${bucket.name}`
        : `https://storage.googleapis.com/${bucket.name}`;
      return {
        url: `${bucketHost}/${coverDest}`,
        cardUrl: `${bucketHost}/${cardDest}`,
        path: coverDest,
      };
    },
  };

  const deps: SpotCliDeps = {
    spots: mergedStore,
    counter,
    clock: { now: () => new Date() },
    ids: { newId: () => randomUUID().replace(/-/g, '').slice(0, 26) },
    staff: { isAdmin: (uid) => io.isAdmin(uid) },
  };

  await runCli(process.argv.slice(2), deps, io);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}

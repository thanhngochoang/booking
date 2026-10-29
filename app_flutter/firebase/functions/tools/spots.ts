// Staff CLI for spots management and ranking (spec S29, plan Task 4):
//   npm run spots -- list [--area <code>]
//   npm run spots -- add --name … --city … --area … --lat … --lng … --radius … [--season 10,11,12] [--cover <file.jpg>] [--card <file.jpg>] [--description …] [--tip …]… --actor <uid>
//   npm run spots -- edit <id> [same flags] --actor <uid>
//   npm run spots -- pin|unpin|hide|unhide|archive <id> --actor <uid>
//   npm run spots -- rank
// S30 organizers (#223 Decisions 2, 4, Phase 1 staff review):
//   npm run spots -- claims list [--status pending|approved|rejected]
//   npm run spots -- claims approve <claimId> [--spot <spotId>] --actor <uid>
//   npm run spots -- claims reject <claimId> --reason <text> --actor <uid>
//   npm run spots -- access <spotId> --type open|ticket|none [--fee "Người lớn=70000"]… [--note <text>] --actor <uid>
//   npm run spots -- organizers suspend|sync <uid> --actor <uid>
// Uses the Admin SDK.

import { fileURLToPath } from 'node:url';
import * as fs from 'node:fs/promises';
import {
  DomainError,
  SPOT_CLAIM_STATUSES,
  reviewSpotClaim,
  setSpotAccess,
  suspendOrganizer,
  syncOrganizerSelling,
  type SpotClaim,
  type SpotClaimStatus,
  type SuspendOrganizerDeps,
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
import { emulatorPayoutKey as defaultEmulatorKey } from '../seed/emulator_key.js';

export const HELP = `usage: spots list [--area <code>]
       spots add --name <n> --city <c> --area <a> --lat <lat> --lng <lng> --radius <m> [--season 10,11,12] [--cover <file.jpg>] [--card <file.jpg>] [--description <d>] [--tip <t>]... --actor <uid>
       spots edit <id> [same flags] --actor <uid>
       spots pin|unpin|hide|unhide|archive <id> --actor <uid>
       spots rank
       spots claims list [--status pending|approved|rejected]
       spots claims approve <claimId> [--spot <spotId>] --actor <uid>
       spots claims reject <claimId> --reason <text> --actor <uid>
       spots access <spotId> --type open|ticket|none [--fee "Người lớn=70000"]... [--note <text>] --actor <uid>
       spots organizers suspend <uid> --actor <uid>
       spots organizers sync <uid> --actor <uid>

S30 (organizers): claims approve sets the spot's manager (a proposal needs --spot, the spot staff
added for it with "spots add"); organizers suspend cancels every open event of the organizer with
100% refunds and prints any event it could not cancel; organizers sync recomputes the selling flags
(business, payout account) after a staff change.

Environment:
  GOOGLE_APPLICATION_CREDENTIALS  path to a service account key (production)
  GCLOUD_PROJECT                  project id
  STORAGE_BUCKET                  bucket for spot covers (or FIREBASE_STORAGE_BUCKET)
  PAYOUT_ACCOUNT_KEY              base64 account-cipher key: organizers suspend refunds bank-QR tickets with it on a
                                  real project (the emulators use the committed emulator key)
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

/** The S30 staff tools (claims, access, suspension): the organizer use cases and the claims listing. */
export interface SpotCliStaffDeps {
  readonly organizer: SuspendOrganizerDeps;
  readonly claims: {
    list(status: SpotClaimStatus): Promise<SpotClaim[]>;
    /** A pending proposal (`spotId` null) gets the spot staff added for it; null when it is not one. */
    setSpot(claimId: string, spotId: string): Promise<SpotClaim | null>;
  };
}

export interface SpotCliDeps {
  readonly spots: SpotRankStore & SpotAdminStore;
  readonly counter: SpotCounter;
  readonly clock: Clock;
  readonly ids: IdGenerator;
  readonly staff: { isAdmin(uid: string): Promise<boolean> };
  /** S30 commands; absent → they are refused. */
  readonly staffTools?: SpotCliStaffDeps;
}

// ---- S30 staff commands ---------------------------------------------------------------------

export type StaffCommand = 'claims' | 'access' | 'organizers';
const STAFF_COMMANDS: readonly string[] = ['claims', 'access', 'organizers'];

export interface StaffArgs {
  readonly command: StaffCommand;
  readonly sub: 'list' | 'approve' | 'reject' | 'suspend' | 'sync' | null;
  /** The claim, spot or organizer id. */
  readonly id: string | null;
  readonly status: SpotClaimStatus;
  readonly reason: string | null;
  readonly spot: string | null;
  /** `access`: the block to set, or null for `--type none` (clears it). */
  readonly access: { type: 'open' | 'ticket'; fees: { label: string; amountVnd: number }[]; note: string } | null;
  readonly actor: string | null;
}

/** `"Người lớn=70000"` (dots and spaces in the amount are ignored) → a fee line; anything else throws. */
function feeOf(raw: string | undefined): { label: string; amountVnd: number } {
  const i = raw?.lastIndexOf('=') ?? -1;
  const label = i > 0 ? (raw as string).slice(0, i).trim() : '';
  const amount = i > 0 ? (raw as string).slice(i + 1).replace(/[\s.,]/g, '') : '';
  if (label === '' || !/^\d+$/.test(amount)) throw new Error(`--fee needs "<label>=<amount VND>" (got ${raw ?? 'nothing'}). ${HELP}`);
  return { label, amountVnd: Number(amount) };
}

export function parseStaffArgs(argv: readonly string[]): StaffArgs {
  const command = argv[0] as StaffCommand;
  if (!STAFF_COMMANDS.includes(command)) throw new Error(HELP);
  let sub: StaffArgs['sub'] = null;
  let i = 1;
  if (command === 'claims') {
    sub = argv[1] as StaffArgs['sub'];
    if (sub !== 'list' && sub !== 'approve' && sub !== 'reject') throw new Error(`claims needs list, approve or reject. ${HELP}`);
    i = 2;
  } else if (command === 'organizers') {
    sub = argv[1] as StaffArgs['sub'];
    if (sub !== 'suspend' && sub !== 'sync') throw new Error(`organizers needs suspend or sync. ${HELP}`);
    i = 2;
  }
  let id: string | null = null;
  if (sub !== 'list') {
    id = argv[i] ?? null;
    if (id === null || id.startsWith('--')) throw new Error(`${command}${sub ? ` ${sub}` : ''} needs an id. ${HELP}`);
    i += 1;
  }
  let status: SpotClaimStatus = 'pending';
  let reason: string | null = null;
  let spot: string | null = null;
  let type: string | null = null;
  const fees: { label: string; amountVnd: number }[] = [];
  let note = '';
  let actor: string | null = null;
  for (; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--status') {
      const v = argv[++i] ?? '';
      if (!(SPOT_CLAIM_STATUSES as readonly string[]).includes(v)) throw new Error(`--status must be pending, approved or rejected. ${HELP}`);
      status = v as SpotClaimStatus;
    } else if (a === '--reason') reason = argv[++i] ?? null;
    else if (a === '--spot') spot = argv[++i] ?? null;
    else if (a === '--type') type = argv[++i] ?? null;
    else if (a === '--fee') fees.push(feeOf(argv[++i]));
    else if (a === '--note') note = argv[++i] ?? '';
    else if (a === '--actor') actor = argv[++i] ?? null;
  }
  if (sub === 'reject' && (reason === null || reason.trim() === '')) throw new Error(`claims reject needs --reason <text>. ${HELP}`);
  let access: StaffArgs['access'] = null;
  if (command === 'access') {
    if (type !== 'open' && type !== 'ticket' && type !== 'none') throw new Error(`access needs --type open, ticket or none. ${HELP}`);
    access = type === 'none' ? null : { type, fees, note };
  }
  return { command, sub, id, status, reason, spot, access, actor };
}

/**
 * The account-cipher key of `organizers suspend` (bank-QR refunds): `PAYOUT_ACCOUNT_KEY`, else the committed emulator
 * key only when the CLI runs against the emulators (`FIRESTORE_EMULATOR_HOST`); a real project without it is refused.
 */
export function payoutKeyOf(env: Readonly<Record<string, string | undefined>>, emulatorKey: () => string = defaultEmulatorKey): string {
  const key = env.PAYOUT_ACCOUNT_KEY;
  if (key !== undefined && key !== '') return key;
  const emulator = env.FIRESTORE_EMULATOR_HOST;
  if (emulator !== undefined && emulator !== '') return emulatorKey();
  throw new Error('PAYOUT_ACCOUNT_KEY is required (base64, 32 bytes) outside the emulators');
}

const codeOf = (e: unknown): string => (e instanceof DomainError ? e.code : e instanceof Error ? e.name : 'unknown');

async function runStaffCommand(argv: readonly string[], deps: SpotCliDeps, io: SpotCliIo): Promise<void> {
  const args = parseStaffArgs(argv);
  const tools = deps.staffTools;
  if (tools === undefined) throw new Error(`${args.command} is not available here. ${HELP}`);

  if (args.command === 'claims' && args.sub === 'list') {
    const claims = await tools.claims.list(args.status);
    if (claims.length === 0) io.print(`No ${args.status} claims`);
    for (const c of claims) {
      const what = c.spotId !== null ? `spot ${c.spotId}` : `proposal "${c.proposal?.name ?? ''}" (${c.proposal?.address ?? ''})`;
      const extra = c.reason !== null ? `  reason: ${c.reason}` : '';
      io.print(`${c.id}  ${what}  organizer ${c.organizerId}  ${c.createdAt}  proofs: ${c.proofPaths.join(', ')}${extra}`);
    }
    return;
  }

  const actor = args.actor;
  if (actor === null) throw new Error(`${args.command} needs --actor <uid> of an admin. ${HELP}`);
  if (!(await io.isAdmin(actor))) throw new Error(`${actor} does not have the admin claim`);
  const id = args.id as string;
  const org = tools.organizer;

  try {
    if (args.command === 'claims') {
      if (args.sub === 'approve' && args.spot !== null && (await tools.claims.setSpot(id, args.spot)) === null) {
        throw new Error(`Claim ${id} is not a pending proposal without a spot`);
      }
      const reviewed = await reviewSpotClaim(org, actor, {
        claimId: id, approve: args.sub === 'approve', ...(args.reason !== null ? { reason: args.reason } : {}),
      });
      io.print(reviewed.status === 'approved'
        ? `Claim ${id} approved: spot ${reviewed.spotId ?? ''} is managed by ${reviewed.organizerId}`
        : `Claim ${id} rejected: ${reviewed.reason ?? ''}`);
      return;
    }
    if (args.command === 'access') {
      const spot = await setSpotAccess(org, actor, { spotId: id, access: args.access });
      const a = spot.access;
      io.print(a === null
        ? `Spot ${id} access: cleared`
        : `Spot ${id} access: ${a.type}${a.fees.length > 0 ? ` · ${a.fees.map((f) => `${f.label} ${f.amountVnd}`).join(', ')}` : ''}`);
      return;
    }
    if (args.sub === 'sync') {
      const o = await syncOrganizerSelling(org, id);
      if (o === null) throw new Error(`${id} is not an organizer`);
      io.print(`Organizer ${id}: businessVerified ${o.businessVerified}, payoutAccountOk ${o.payoutAccountOk}`);
      return;
    }
    const failed: string[] = [];
    const { cancelledEvents } = await suspendOrganizer(org, actor, { organizerId: id }, (eventId, e) => {
      failed.push(eventId);
      io.print(`cancel failed: ${eventId} (${codeOf(e)})`);
    });
    io.print(`Organizer ${id} suspended: ${cancelledEvents} open event(s) cancelled`);
    if (failed.length > 0) throw new Error(`${failed.length} event(s) not cancelled; run organizers suspend ${id} again`);
  } catch (e) {
    if (e instanceof DomainError) throw new Error(`${args.command}${args.sub ? ` ${args.sub}` : ''} ${id}: ${e.code}${e.field ? ` (${e.field})` : ''}`);
    throw e;
  }
}

/** Validates that a file is a JPEG <= maxSize bytes. */
export async function validateJpegFile(filePath: string, maxSize: number): Promise<void> {
  const fh = await fs.open(filePath, 'r');
  try {
    const stat = await fh.stat();
    if (stat.size > maxSize) {
      throw new Error(`File ${filePath} exceeds max size ${maxSize} bytes (got ${stat.size})`);
    }
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
  if (argv[0] !== undefined && STAFF_COMMANDS.includes(argv[0])) {
    await runStaffCommand(argv, deps, io);
    return;
  }
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
    putSpot: (s, fields) => adminStore.putSpot(s, fields),
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

  const { liveOrganizerDeps } = await import('../src/infra/live_organizer.js');
  const { FirestoreOrganizerStore } = await import('../src/infra/organizer_firestore.js');
  const { lazyAccountCipher } = await import('../src/infra/account_cipher.js');
  const organizerStore = new FirestoreOrganizerStore(firestore);
  const organizer = liveOrganizerDeps();
  // `organizers suspend` refunds bank-QR tickets (the payer's account is encrypted). Read on first use.
  const cipher = lazyAccountCipher(() => payoutKeyOf(process.env));
  const deps: SpotCliDeps = {
    spots: mergedStore,
    counter,
    clock: { now: () => new Date() },
    ids: { newId: () => randomUUID().replace(/-/g, '').slice(0, 26) },
    staff: { isAdmin: (uid) => io.isAdmin(uid) },
    staffTools: {
      organizer: { ...organizer, eventPayments: { ...organizer.eventPayments, cipher } },
      claims: {
        list: (status) => organizerStore.listClaims(status),
        setSpot: (claimId, spotId) => organizerStore.setClaimSpot(claimId, spotId),
      },
    },
  };

  await runCli(process.argv.slice(2), deps, io);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}

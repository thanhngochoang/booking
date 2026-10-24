// Dev CLI for Chụp ngay (#140 Decision 29), emulators only:
//   npm run instant -- offer --photographer <uid> [--customer seed-customer-lan] [--package p60] [--genre portrait]
//   npm run instant -- status <requestId>
// `offer` needs the photographer online in Live Shutter (S14.01) with a fresh heartbeat: it creates a
// request for the customer 500 m north of them (meet point "Điểm hẹn thử (CLI)"), invites them (bank
// QR) and confirms the fake payment (V1's `confirmFakePayment`, #202), which sends the offer, so
// S14.02/S14.03 can be checked on a device. Push is only logged. When the photographer cannot get the
// offer, the request is cancelled again (paid: refunded 100%) so the customer's lock is free.
// Refuses unless FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST point at a local host.

import { fileURLToPath } from 'node:url';
import {
  cancelInstantRequest,
  confirmFakePayment,
  createInstantRequest,
  inviteInstant,
  isDomainError,
  isInstantGenre,
  peekInstantRequest,
  presenceFresh,
  type InstantDeps,
  type SettlementDeps,
} from '@photobooking/domain';
import { assertLocalEmulators } from '../seed/local_guard.js';

export const USAGE = `usage: npm run instant -- offer --photographer <uid> [--customer seed-customer-lan] [--package p60] [--genre portrait]
       npm run instant -- status <requestId>
(local emulators only)`;

export const CLI_MEET_NAME = 'Điểm hẹn thử (CLI)';
/** 500 m north: 1° of latitude is 111.195 km (R = 6371.0088). */
const NORTH_500M_DEG = 0.5 / 111.19508;

export interface InstantCliIo {
  print(line: string): void;
  /** Opened only after the guard passed (the live wiring starts the Admin SDK). */
  deps(): Promise<InstantDeps>;
  /** V1's settlement whose `instant_request` settler runs on `deps` (for the fake payment). */
  settlement(deps: InstantDeps): Promise<SettlementDeps>;
}

export type InstantCommand =
  | { readonly kind: 'offer'; readonly photographer: string; readonly customer: string; readonly packageCode: string; readonly genre: string }
  | { readonly kind: 'status'; readonly requestId: string };

/** Null when the arguments do not make a command. */
export function parseInstantArgs(argv: readonly string[]): InstantCommand | null {
  const [command, ...rest] = argv;
  if (command === 'status') {
    const requestId = rest[0];
    return requestId !== undefined && !requestId.startsWith('--') && rest.length === 1 ? { kind: 'status', requestId } : null;
  }
  if (command !== 'offer') return null;
  const flags = new Map<string, string>();
  for (let i = 0; i < rest.length; i += 2) {
    const key = rest[i];
    const value = rest[i + 1];
    if (key === undefined || value === undefined || !key.startsWith('--') || value.startsWith('--')) return null;
    if (!['--photographer', '--customer', '--package', '--genre'].includes(key)) return null;
    flags.set(key, value);
  }
  const photographer = flags.get('--photographer');
  if (photographer === undefined) return null;
  return {
    kind: 'offer',
    photographer,
    customer: flags.get('--customer') ?? 'seed-customer-lan',
    packageCode: flags.get('--package') ?? 'p60',
    genre: flags.get('--genre') ?? 'portrait',
  };
}

/** Returns the exit code. Refuses (throws) before opening anything when the hosts are not local. */
export async function runInstantCli(argv: readonly string[], env: NodeJS.ProcessEnv, io: InstantCliIo): Promise<number> {
  const cmd = parseInstantArgs(argv);
  if (cmd === null) {
    io.print(USAGE);
    return argv[0] === '--help' || argv[0] === '-h' ? 0 : 2;
  }
  assertLocalEmulators({ allowAnyProject: true }, env);
  const deps = await io.deps();
  try {
    return cmd.kind === 'offer' ? await offer(deps, await io.settlement(deps), cmd, io) : await status(deps, cmd.requestId, io);
  } catch (e) {
    if (!isDomainError(e)) throw e;
    io.print(`refused: ${e.code}`);
    return 1;
  }
}

async function offer(
  deps: InstantDeps,
  settlement: SettlementDeps,
  cmd: Extract<InstantCommand, { kind: 'offer' }>,
  io: InstantCliIo,
): Promise<number> {
  if (!isInstantGenre(cmd.genre)) {
    io.print(`unknown genre ${cmd.genre} (portrait, couple, family, event, product)`);
    return 2;
  }
  const presence = await deps.store.runTransaction((tx) => tx.getPresence(cmd.photographer));
  if (presence === null || !presenceFresh(presence, deps.clock.now()) || presence.lat === null || presence.lng === null) {
    io.print(`${cmd.photographer} is not online in Live Shutter with a fresh position (turn it on in S14.01 first)`);
    return 1;
  }
  const customer = { uid: cmd.customer };
  const meetPoint = { lat: presence.lat + NORTH_500M_DEG, lng: presence.lng, name: CLI_MEET_NAME };
  const created = await createInstantRequest(deps, customer, { packageCode: cmd.packageCode, genre: cmd.genre, meetPoint });
  const request = await peekInstantRequest(deps, created.requestId);
  if (request === null || !request.candidates.some((c) => c.photographerId === cmd.photographer)) {
    io.print(`request ${created.requestId}`);
    io.print(`${cmd.photographer} is not among the candidates (price list, day held, block or an active job); nothing sent`);
    await dropOrphan(deps, customer, created.requestId, io);
    return 1;
  }
  const res = await inviteInstant(deps, customer, {
    requestId: created.requestId, photographerIds: [cmd.photographer], skipped: [], expectedAmountVnd: created.amountVnd,
    payMethod: 'bank_qr',
  });
  io.print(`request ${created.requestId}`);
  if (res.kind !== 'payment') {
    io.print(res.kind === 'price_changed' ? `price changed to ${res.amountVnd}; run again` : `unexpected answer ${res.kind}; nothing sent`);
    await dropOrphan(deps, customer, created.requestId, io);
    return 1;
  }
  const paid = await confirmFakePayment(settlement, customer, { paymentId: res.instructions.paymentId });
  io.print(`paid ${res.instructions.paymentId} (${paid.outcome})`);
  const after = await peekInstantRequest(deps, created.requestId);
  const row = after?.offers.find((o) => o.photographerId === cmd.photographer);
  if (row?.outcome !== 'pending' || row.offerId === null) {
    io.print(`${cmd.photographer} is unavailable; nothing sent`);
    await dropOrphan(deps, customer, created.requestId, io);
    return 1;
  }
  io.print(`offer ${row.offerId}`);
  return 0;
}

/**
 * A request the photographer cannot get would keep the customer's one-active-request lock (and every
 * later `offer` run would answer `conflict`): cancel it (a paid one is refunded 100%) and say so.
 */
async function dropOrphan(deps: InstantDeps, customer: { uid: string }, requestId: string, io: InstantCliIo): Promise<void> {
  const res = await cancelInstantRequest(deps, customer, { requestId, dryRun: false });
  io.print(`request ${requestId} cancelled: status=${res.status}, ${customer.uid} can request again`);
}

async function status(deps: InstantDeps, requestId: string, io: InstantCliIo): Promise<number> {
  const r = await peekInstantRequest(deps, requestId);
  if (r === null) {
    io.print(`no request ${requestId}`);
    return 1;
  }
  io.print(`request ${r.id} status=${r.status} round=${r.round} photographer=${r.photographerId ?? '-'}`);
  for (const o of r.offers) {
    io.print(`  ${o.photographerId} ${o.outcome} offer=${o.offerId ?? '-'} expires=${o.expiresAt?.toISOString() ?? '-'}`);
  }
  return 0;
}

async function main(): Promise<void> {
  const io: InstantCliIo = {
    print: (l) => console.log(l),
    deps: async () => {
      const { liveInstantDeps } = await import('../src/infra/live_instant.js');
      const { LoggingPushSender } = await import('../src/infra/fcm_push.js');
      return { ...liveInstantDeps(), push: new LoggingPushSender() };
    },
    settlement: async (deps) => {
      const { liveSettlementDeps } = await import('../src/infra/live_payments.js');
      const { InstantPaymentSettler } = await import('@photobooking/domain');
      const live = liveSettlementDeps();
      return { ...live, subjects: { ...live.subjects, instant_request: new InstantPaymentSettler(deps) } };
    },
  };
  process.exitCode = await runInstantCli(process.argv.slice(2), process.env, io);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}

/**
 * Production and emulator wiring of the safety ports.
 */

import type { BlockDeps, BlockGate, ReportDeps } from '@photobooking/domain';
import { db } from './admin.js';
import {
  FirestoreBlockGate,
  FirestoreBlockStore,
  FirestorePublicProfiles,
  FirestoreReportStore,
} from './safety_firestore.js';

export function liveBlockGate(): BlockGate {
  return new FirestoreBlockGate(db());
}

export function liveBlockDeps(): BlockDeps {
  const firestore = db();
  return {
    store: new FirestoreBlockStore(firestore),
    profiles: new FirestorePublicProfiles(firestore),
    clock: { now: () => new Date() },
  };
}

export function liveReportDeps(): ReportDeps {
  const firestore = db();
  const blockDeps = liveBlockDeps();
  return {
    store: new FirestoreReportStore(firestore),
    blocks: blockDeps,
    clock: { now: () => new Date() },
  };
}

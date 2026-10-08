/**
 * Production and emulator wiring of the safety ports.
 */

import type { BlockGate } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreBlockGate } from './safety_firestore.js';

export function liveBlockGate(): BlockGate {
  return new FirestoreBlockGate(db());
}

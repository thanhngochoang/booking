/**
 * S30 scan and shoot-question callables (#223, plan Task 6): `scanPass` (S30.07; the server decides what a scan
 * changes from the scanner's roles) and `answerShootHappened` (S05.02-askshot). The scan response carries names,
 * titles and counts only, never a phone (Review Focus 3).
 */

import {
  DomainError,
  answerShootHappened,
  scanPass,
  type BookingDeps,
  type BookingStatus,
  type ScanDeps,
  type ScanResult,
} from '@photobooking/domain';
import { eventCallerOf, runEventCallable, type EventCallableInput } from './event.js';

const dataOf = (request: EventCallableInput): Record<string, unknown> =>
  request.data !== null && typeof request.data === 'object' && !Array.isArray(request.data)
    ? (request.data as Record<string, unknown>)
    : {};

/** `{code}` (`VE-XXXX-XXXX`, 8 characters, or a legacy `VE-XXXX-MMDD`) → `{booking, registrations, waived, todayCount}` */
export async function handleScanPass(request: EventCallableInput, deps: ScanDeps): Promise<ScanResult> {
  const caller = eventCallerOf(request);
  return runEventCallable('scanPass', () => scanPass(deps, caller.uid, dataOf(request)));
}

/** `{bookingId, happened}` → `{status}`: the customer answers "Buổi chụp có diễn ra không?". */
export async function handleAnswerShootHappened(
  request: EventCallableInput,
  deps: BookingDeps,
): Promise<{ status: BookingStatus }> {
  const caller = eventCallerOf(request);
  return runEventCallable('answerShootHappened', async () => {
    const d = dataOf(request);
    if (typeof d.bookingId !== 'string' || typeof d.happened !== 'boolean') throw new DomainError('invalid_argument');
    const b = await answerShootHappened(deps, { bookingId: d.bookingId, customerId: caller.uid, happened: d.happened });
    return { status: b.status };
  });
}

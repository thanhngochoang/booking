import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  saveSpotSchedule,
  cancelSpotSchedule,
  saveSlotOffer,
  closeSlotOffer,
  type SpotScheduleDeps,
} from '@photobooking/domain';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

function requireUid(request: CallableInput): string {
  const uid = request.auth?.uid;
  if (uid === undefined) {
    throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  }
  return uid;
}

async function run<T>(
  operation: string,
  request: CallableInput,
  fn: (uid: string) => Promise<T>,
): Promise<T> {
  const uid = requireUid(request);
  try {
    return await fn(uid);
  } catch (e) {
    const error = toHttpsError(e);
    if (error.code === 'internal') {
      logger.error(`${operation} failed`, { code: error.message });
    } else {
      logger.info(`${operation} refused`, { code: error.message });
    }
    throw error;
  }
}

export async function handleSaveSpotSchedule(
  request: CallableInput,
  deps: SpotScheduleDeps,
  afterSave?: (holder: string, days: string[]) => Promise<void>,
): Promise<{ scheduleId: string; addedDays: string[] }> {
  return run('saveSpotSchedule', request, async (uid) => {
    const res = await saveSpotSchedule(deps, uid, request.data);
    if (afterSave && res.addedDays.length > 0) {
      const holder =
        request.data &&
        typeof request.data === 'object' &&
        typeof (request.data as Record<string, unknown>).assigneeId === 'string'
          ? ((request.data as Record<string, unknown>).assigneeId as string)
          : uid;
      try {
        await afterSave(holder, res.addedDays);
      } catch (err) {
        logger.warn('afterSave failed for spot schedule', { error: err });
      }
    }
    return res;
  });
}

export async function handleCancelSpotSchedule(
  request: CallableInput,
  deps: SpotScheduleDeps,
): Promise<Record<string, never>> {
  return run('cancelSpotSchedule', request, (uid) => cancelSpotSchedule(deps, uid, request.data));
}

export async function handleSaveSlotOffer(
  request: CallableInput,
  deps: SpotScheduleDeps,
): Promise<{ offerId: string }> {
  return run('saveSlotOffer', request, (uid) => saveSlotOffer(deps, uid, request.data));
}

export async function handleCloseSlotOffer(
  request: CallableInput,
  deps: SpotScheduleDeps,
): Promise<Record<string, never>> {
  return run('closeSlotOffer', request, (uid) => closeSlotOffer(deps, uid, request.data));
}

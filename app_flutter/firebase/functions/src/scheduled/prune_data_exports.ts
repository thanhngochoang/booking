import type { Bucket } from '@google-cloud/storage';
import * as logger from 'firebase-functions/logger';
import { EXPORT_TTL_DAYS } from '@photobooking/domain';

export async function pruneDataExports(
  bucket: Bucket,
  now: Date = new Date(),
): Promise<number> {
  const cutoffMs = now.getTime() - EXPORT_TTL_DAYS * 24 * 60 * 60 * 1000;
  let deletedCount = 0;

  try {
    const [files] = await bucket.getFiles({ prefix: 'exports/' });
    for (const file of files) {
      const [metadata] = await file.getMetadata();
      const timeCreated = metadata.timeCreated ? new Date(metadata.timeCreated).getTime() : null;
      if (timeCreated && timeCreated < cutoffMs) {
        await file.delete();
        deletedCount++;
      }
    }
  } catch (e) {
    logger.error('pruneDataExports error', { error: String(e) });
    throw e;
  }

  return deletedCount;
}

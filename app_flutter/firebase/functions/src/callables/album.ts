import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  createAlbum,
  deleteAlbum,
  movePostsToAlbum,
  reorderAlbumPosts,
  reorderAlbums,
  updateAlbum,
  type AlbumDeps,
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

/** `{title, description?}` → `{albumId}` */
export const handleCreateAlbum = (request: CallableInput, deps: AlbumDeps): Promise<{ albumId: string }> =>
  run('createAlbum', request, (uid) => createAlbum(deps, uid, request.data));

/** `{albumId, title?, description?, cover?}` → `{}` */
export const handleUpdateAlbum = (request: CallableInput, deps: AlbumDeps): Promise<Record<string, never>> =>
  run('updateAlbum', request, async (uid) => {
    await updateAlbum(deps, uid, request.data);
    return {};
  });

/** `{albumId}` → `{}` */
export const handleDeleteAlbum = (request: CallableInput, deps: AlbumDeps): Promise<Record<string, never>> =>
  run('deleteAlbum', request, async (uid) => {
    await deleteAlbum(deps, uid, request.data);
    return {};
  });

/** `{albumIds}` → `{}` */
export const handleReorderAlbums = (request: CallableInput, deps: AlbumDeps): Promise<Record<string, never>> =>
  run('reorderAlbums', request, async (uid) => {
    await reorderAlbums(deps, uid, request.data);
    return {};
  });

/** `{albumId | null, postIds}` → `{}` */
export const handleMovePostsToAlbum = (request: CallableInput, deps: AlbumDeps): Promise<Record<string, never>> =>
  run('movePostsToAlbum', request, async (uid) => {
    await movePostsToAlbum(deps, uid, request.data);
    return {};
  });

/** `{albumId, postIds}` → `{}` */
export const handleReorderAlbumPosts = (request: CallableInput, deps: AlbumDeps): Promise<Record<string, never>> =>
  run('reorderAlbumPosts', request, async (uid) => {
    await reorderAlbumPosts(deps, uid, request.data);
    return {};
  });

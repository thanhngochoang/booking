import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { MemoryAlbumStore, type AlbumDeps } from '@photobooking/domain';
import {
  handleCreateAlbum,
  handleDeleteAlbum,
  handleMovePostsToAlbum,
  handleReorderAlbumPosts,
  handleReorderAlbums,
  handleUpdateAlbum,
} from '../../src/callables/album.js';
import { handlePostCreated } from '../../src/triggers/post_created.js';

const ID = (n: number): string => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n).padStart(2, '0')}`;

describe('album callables', () => {
  let store: MemoryAlbumStore;
  let next: number;

  function deps(): AlbumDeps {
    return {
      albums: store,
      clock: { now: () => new Date('2026-10-10T12:00:00.000Z') },
      ids: { newId: () => ID(next++) },
    };
  }

  beforeEach(() => {
    store = new MemoryAlbumStore();
    next = 10;
  });

  it('unauthenticated is refused', async () => {
    const handlers = [
      handleCreateAlbum,
      handleUpdateAlbum,
      handleDeleteAlbum,
      handleReorderAlbums,
      handleMovePostsToAlbum,
      handleReorderAlbumPosts,
    ];
    for (const h of handlers) {
      await assert.rejects(
        () => h({ auth: undefined, data: {} }, deps()),
        (e: unknown) =>
          e instanceof HttpsError &&
          e.code === 'unauthenticated' &&
          (e.details as { code?: string } | undefined)?.code === 'permission_denied',
      );
    }
  });

  it('domain errors map to HttpsError', async () => {
    await assert.rejects(
      () => handleCreateAlbum({ auth: { uid: 'p1' }, data: { title: '' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'invalid-argument',
    );
    await assert.rejects(
      () => handleDeleteAlbum({ auth: { uid: 'p1' }, data: { albumId: ID(1) } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'not-found',
    );
    await handleCreateAlbum({ auth: { uid: 'p1' }, data: { title: 'Cưới' } }, deps());
    await assert.rejects(
      () => handleCreateAlbum({ auth: { uid: 'p1' }, data: { title: 'cưới' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'aborted',
    );
  });

  it('createAlbum returns the new id', async () => {
    const res = await handleCreateAlbum({ auth: { uid: 'p1' }, data: { title: 'Cưới' } }, deps());
    assert.deepEqual(res, { albumId: ID(10) });
  });

  it('onPostCreated appends a post and ignores a retry', async () => {
    const { albumId } = await handleCreateAlbum({ auth: { uid: 'p1' }, data: { title: 'A' } }, deps());
    store.seedPost({ id: ID(2), authorId: 'p1', kind: 'work', imageCount: 3, albumId, albumPosition: null });
    assert.equal(await handlePostCreated(ID(2), deps()), 'appended');
    assert.equal(await handlePostCreated(ID(2), deps()), 'skipped');
    assert.equal(store.albums.get(albumId)?.postCount, 1);
  });
});

import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import type { Album, AlbumPost } from '../src/album.js';
import type { AlbumDeps } from '../src/album_ports.js';
import {
  appendNewPost,
  createAlbum,
  deleteAlbum,
  movePostsToAlbum,
  reorderAlbumPosts,
  reorderAlbums,
  updateAlbum,
} from '../src/album_use_cases.js';
import { DomainError } from '../src/errors.js';
import { MemoryAlbumStore } from '../src/memory_album_store.js';

const NOW = new Date('2026-10-05T10:00:00.000Z');
const OLD = new Date('2026-10-01T00:00:00.000Z');

async function refused(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

describe('album use cases', () => {
  let store: MemoryAlbumStore;
  let deps: AlbumDeps;
  let n: number;

  const album = (id: string, position: number, over: Partial<Album> = {}): Album => ({
    id,
    photographerId: 'u1',
    title: id,
    titleKey: id,
    description: '',
    cover: null,
    position,
    postCount: 0,
    mediaCount: 0,
    visible: false,
    createdAt: OLD,
    updatedAt: OLD,
    ...over,
  });
  const post = (id: string, over: Partial<AlbumPost> = {}): AlbumPost => ({
    id,
    authorId: 'u1',
    kind: 'work',
    imageCount: 2,
    albumId: null,
    albumPosition: null,
    ...over,
  });
  /** Seeds an album holding the given posts in order (2 images each). */
  const fill = (id: string, position: number, postIds: string[], over: Partial<Album> = {}): void => {
    store.seedAlbum(
      album(id, position, {
        postCount: postIds.length,
        mediaCount: postIds.length * 2,
        visible: postIds.length > 0,
        ...over,
      }),
    );
    postIds.forEach((p, i) => store.seedPost(post(p, { albumId: id, albumPosition: i + 1 })));
  };
  const inAlbum = (id: string): string[] =>
    [...store.posts.values()]
      .filter((p) => p.albumId === id)
      .sort((a, b) => (a.albumPosition ?? 0) - (b.albumPosition ?? 0))
      .map((p) => `${p.id}:${p.albumPosition}`);

  beforeEach(() => {
    store = new MemoryAlbumStore();
    n = 0;
    deps = { albums: store, clock: { now: () => NOW }, ids: { newId: () => `a${++n}` } };
  });

  it('create appends at the next position', async () => {
    store.seedAlbum(album('x', 1));
    const r = await createAlbum(deps, 'u1', { title: 'Mới' });
    const a = store.albums.get(r.albumId);
    assert.equal(a?.position, 2);
    assert.equal(a?.visible, false);
    assert.equal(a?.postCount, 0);
    assert.equal(a?.titleKey, 'mới');
  });

  it('the 31st album is limit_exceeded', async () => {
    for (let i = 1; i <= 30; i++) store.seedAlbum(album(`x${i}`, i));
    await refused(createAlbum(deps, 'u1', { title: 'Thêm' }), 'limit_exceeded');
    assert.equal(store.writes, 0);
  });

  it('a duplicate title is a conflict', async () => {
    store.seedAlbum(album('x', 1, { title: 'Cưới', titleKey: 'cưới' }));
    await refused(createAlbum(deps, 'u1', { title: ' CƯỚI ' }), 'conflict');
  });

  it('update renames and keeps the position', async () => {
    store.seedAlbum(album('x', 3));
    await updateAlbum(deps, 'u1', { albumId: 'x', title: 'Tên Mới', description: 'd' });
    const a = store.albums.get('x');
    assert.equal(a?.title, 'Tên Mới');
    assert.equal(a?.titleKey, 'tên mới');
    assert.equal(a?.position, 3);
    assert.equal(a?.description, 'd');
    await refused(updateAlbum(deps, 'u2', { albumId: 'x', title: 'Z' }), 'permission_denied');
    await refused(updateAlbum(deps, 'u1', { albumId: 'nope', title: 'Z' }), 'not_found');
  });

  it('cover must be a post in the album', async () => {
    fill('x', 1, ['p1']);
    store.seedPost(post('p9'));
    await updateAlbum(deps, 'u1', { albumId: 'x', cover: { postId: 'p1', imageIndex: 1 } });
    assert.deepEqual(store.albums.get('x')?.cover, { postId: 'p1', imageIndex: 1 });
    await refused(updateAlbum(deps, 'u1', { albumId: 'x', cover: { postId: 'p9', imageIndex: 0 } }), 'invalid_argument');
    await refused(updateAlbum(deps, 'u1', { albumId: 'x', cover: { postId: 'p1', imageIndex: 2 } }), 'invalid_argument');
    await updateAlbum(deps, 'u1', { albumId: 'x', cover: null });
    assert.equal(store.albums.get('x')?.cover, null);
  });

  it('delete clears its posts and renumbers the others', async () => {
    store.seedAlbum(album('a', 1));
    fill('b', 2, ['p1', 'p2']);
    store.seedAlbum(album('c', 3));
    await deleteAlbum(deps, 'u1', { albumId: 'b' });
    assert.equal(store.albums.has('b'), false);
    assert.equal(store.albums.get('a')?.position, 1);
    assert.equal(store.albums.get('c')?.position, 2);
    assert.equal(store.posts.get('p1')?.albumId, null);
    assert.equal(store.posts.get('p2')?.albumPosition, null);
  });

  it("reorder needs exactly the caller's albums", async () => {
    store.seedAlbum(album('a', 1));
    store.seedAlbum(album('b', 2));
    store.seedAlbum(album('z', 1, { photographerId: 'u2' }));
    await reorderAlbums(deps, 'u1', { albumIds: ['b', 'a'] });
    assert.equal(store.albums.get('b')?.position, 1);
    assert.equal(store.albums.get('a')?.position, 2);
    await refused(reorderAlbums(deps, 'u1', { albumIds: ['a'] }), 'invalid_argument');
    await refused(reorderAlbums(deps, 'u1', { albumIds: ['a', 'z'] }), 'invalid_argument');
    await refused(reorderAlbums(deps, 'u1', { albumIds: ['a', 'a'] }), 'invalid_argument');
  });

  it('move into an empty album makes it visible', async () => {
    store.seedAlbum(album('t', 1));
    store.seedPost(post('p1'));
    await movePostsToAlbum(deps, 'u1', { albumId: 't', postIds: ['p1'] });
    const t = store.albums.get('t');
    assert.equal(t?.visible, true);
    assert.equal(t?.postCount, 1);
    assert.equal(t?.mediaCount, 2);
    assert.deepEqual(inAlbum('t'), ['p1:1']);
  });

  it('move appends in the given order', async () => {
    fill('t', 1, ['p1']);
    store.seedPost(post('p2'));
    store.seedPost(post('p3'));
    await movePostsToAlbum(deps, 'u1', { albumId: 't', postIds: ['p3', 'p2'] });
    assert.deepEqual(inAlbum('t'), ['p1:1', 'p3:2', 'p2:3']);
    assert.equal(store.albums.get('t')?.postCount, 3);
    assert.equal(store.albums.get('t')?.mediaCount, 6);
  });

  it('the old album closes the gap', async () => {
    fill('s', 1, ['p1', 'p2', 'p3']);
    store.seedAlbum(album('t', 2));
    await movePostsToAlbum(deps, 'u1', { albumId: 't', postIds: ['p2'] });
    assert.deepEqual(inAlbum('s'), ['p1:1', 'p3:2']);
    assert.equal(store.albums.get('s')?.postCount, 2);
    assert.equal(store.albums.get('s')?.mediaCount, 4);
    assert.deepEqual(inAlbum('t'), ['p2:1']);
  });

  it('moving the cover post resets the old cover', async () => {
    fill('s', 1, ['p1', 'p2'], { cover: { postId: 'p1', imageIndex: 1 } });
    await movePostsToAlbum(deps, 'u1', { albumId: null, postIds: ['p1'] });
    assert.equal(store.albums.get('s')?.cover, null);
    fill('s2', 2, ['q1', 'q2'], { cover: { postId: 'q2', imageIndex: 0 } });
    await movePostsToAlbum(deps, 'u1', { albumId: null, postIds: ['q1'] });
    assert.deepEqual(store.albums.get('s2')?.cover, { postId: 'q2', imageIndex: 0 });
  });

  it('moving to null removes from albums', async () => {
    fill('s', 1, ['p1']);
    await movePostsToAlbum(deps, 'u1', { albumId: null, postIds: ['p1'] });
    assert.equal(store.posts.get('p1')?.albumId, null);
    assert.equal(store.posts.get('p1')?.albumPosition, null);
    assert.equal(store.albums.get('s')?.visible, false);
    assert.equal(store.albums.get('s')?.postCount, 0);
  });

  it("moving someone else's post is permission_denied", async () => {
    store.seedAlbum(album('t', 1));
    store.seedPost(post('p1', { authorId: 'u2' }));
    await refused(movePostsToAlbum(deps, 'u1', { albumId: 't', postIds: ['p1'] }), 'permission_denied');
    await refused(movePostsToAlbum(deps, 'u1', { albumId: 't', postIds: ['nope'] }), 'not_found');
  });

  it('moving a real_shoot post is invalid', async () => {
    store.seedAlbum(album('t', 1));
    store.seedPost(post('p1', { kind: 'real_shoot' }));
    await refused(movePostsToAlbum(deps, 'u1', { albumId: 't', postIds: ['p1'] }), 'invalid_argument');
  });

  it('passing 200 posts is limit_exceeded and writes nothing', async () => {
    fill('t', 1, Array.from({ length: 200 }, (_, i) => `t${i}`));
    store.seedPost(post('p1'));
    const before = store.writes;
    await refused(movePostsToAlbum(deps, 'u1', { albumId: 't', postIds: ['p1'] }), 'limit_exceeded');
    assert.equal(store.writes, before);
    await refused(
      movePostsToAlbum(deps, 'u1', { albumId: 't', postIds: Array.from({ length: 51 }, (_, i) => `m${i}`) }),
      'invalid_argument',
    );
  });

  it('reorder posts needs exactly the album\'s posts', async () => {
    fill('a', 1, ['p1', 'p2', 'p3']);
    await reorderAlbumPosts(deps, 'u1', { albumId: 'a', postIds: ['p3', 'p1', 'p2'] });
    assert.deepEqual(inAlbum('a'), ['p3:1', 'p1:2', 'p2:3']);
    await refused(reorderAlbumPosts(deps, 'u1', { albumId: 'a', postIds: ['p1', 'p2'] }), 'invalid_argument');
    await refused(reorderAlbumPosts(deps, 'u2', { albumId: 'a', postIds: ['p1', 'p2', 'p3'] }), 'permission_denied');
  });

  it('appendNewPost puts the post last', async () => {
    fill('a', 1, ['p1', 'p2']);
    store.seedPost(post('p3', { albumId: 'a' }));
    assert.equal(await appendNewPost(deps, 'p3'), 'appended');
    assert.equal(store.posts.get('p3')?.albumPosition, 3);
    assert.equal(store.albums.get('a')?.postCount, 3);
    assert.equal(store.albums.get('a')?.mediaCount, 6);
    assert.equal(store.albums.get('a')?.visible, true);
  });

  it('appendNewPost detaches when the album is full or missing', async () => {
    fill('full', 1, Array.from({ length: 200 }, (_, i) => `t${i}`));
    store.seedPost(post('p1', { albumId: 'full' }));
    store.seedPost(post('p2', { albumId: 'gone' }));
    store.seedAlbum(album('other', 2, { photographerId: 'u2' }));
    store.seedPost(post('p3', { albumId: 'other' }));
    assert.equal(await appendNewPost(deps, 'p1'), 'detached');
    assert.equal(await appendNewPost(deps, 'p2'), 'detached');
    assert.equal(await appendNewPost(deps, 'p3'), 'detached');
    assert.equal(store.posts.get('p1')?.albumId, null);
    assert.equal(store.posts.get('p2')?.albumId, null);
    assert.equal(store.albums.get('full')?.postCount, 200);
  });

  it('appendNewPost skips a post that already has a position', async () => {
    fill('a', 1, ['p1']);
    const before = store.writes;
    assert.equal(await appendNewPost(deps, 'p1'), 'skipped');
    store.seedPost(post('p2'));
    assert.equal(await appendNewPost(deps, 'p2'), 'skipped');
    assert.equal(await appendNewPost(deps, 'nope'), 'skipped');
    assert.equal(store.writes, before);
    assert.equal(store.albums.get('a')?.postCount, 1);
  });
});

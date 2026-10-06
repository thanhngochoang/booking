import {
  ALBUMS_PER_PHOTOGRAPHER,
  MOVE_BATCH_MAX,
  POSTS_PER_ALBUM,
  titleKeyOf,
  validateAlbumFields,
  type Album,
  type AlbumPost,
} from './album.js';
import type { AlbumDeps, AlbumTx } from './album_ports.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

function idList(v: unknown, max: number): string[] {
  if (!Array.isArray(v) || v.length > max) throw new DomainError('invalid_argument');
  const ids = v.map(idOf);
  if (new Set(ids).size !== ids.length) throw new DomainError('invalid_argument');
  return ids;
}

const sum = (posts: readonly AlbumPost[]): number => posts.reduce((n, p) => n + p.imageCount, 0);

function sameSet(a: readonly string[], b: readonly string[]): boolean {
  if (a.length !== b.length) return false;
  const s = new Set(b);
  return a.every((x) => s.has(x));
}

async function ownedAlbum(tx: AlbumTx, callerId: string, id: string): Promise<Album> {
  const a = await tx.getAlbum(id);
  if (a === null) throw new DomainError('not_found');
  if (a.photographerId !== callerId) throw new DomainError('permission_denied');
  return a;
}

export async function createAlbum(
  deps: AlbumDeps,
  callerId: string,
  raw: unknown,
): Promise<{ albumId: string }> {
  const f = validateAlbumFields(raw, false);
  const title = f.title as string;
  const key = titleKeyOf(title);
  const albumId = deps.ids.newId();
  await deps.albums.runTransaction(async (tx) => {
    const mine = await tx.listAlbums(callerId);
    if (mine.length >= ALBUMS_PER_PHOTOGRAPHER) throw new DomainError('limit_exceeded');
    if (mine.some((a) => a.titleKey === key)) throw new DomainError('conflict');
    const now = deps.clock.now();
    tx.putAlbum({
      id: albumId,
      photographerId: callerId,
      title,
      titleKey: key,
      description: f.description ?? '',
      cover: null,
      position: mine.length + 1,
      postCount: 0,
      mediaCount: 0,
      visible: false,
      createdAt: now,
      updatedAt: now,
    });
  });
  return { albumId };
}

export async function updateAlbum(deps: AlbumDeps, callerId: string, raw: unknown): Promise<void> {
  const albumId = idOf(obj(raw).albumId);
  const f = validateAlbumFields(raw, true);
  await deps.albums.runTransaction(async (tx) => {
    const album = await ownedAlbum(tx, callerId, albumId);
    let titleKey = album.titleKey;
    if (f.title !== undefined) {
      titleKey = titleKeyOf(f.title);
      const mine = await tx.listAlbums(callerId);
      if (mine.some((a) => a.id !== albumId && a.titleKey === titleKey)) {
        throw new DomainError('conflict');
      }
    }
    if (f.cover !== undefined && f.cover !== null) {
      const [post] = await tx.getPosts([f.cover.postId]);
      if (post === null || post === undefined || post.albumId !== albumId) {
        throw new DomainError('invalid_argument');
      }
      if (f.cover.imageIndex >= post.imageCount) throw new DomainError('invalid_argument');
    }
    tx.putAlbum({
      ...album,
      title: f.title ?? album.title,
      titleKey,
      description: f.description ?? album.description,
      cover: f.cover === undefined ? album.cover : f.cover,
      updatedAt: deps.clock.now(),
    });
  });
}

export async function deleteAlbum(deps: AlbumDeps, callerId: string, raw: unknown): Promise<void> {
  const albumId = idOf(obj(raw).albumId);
  await deps.albums.runTransaction(async (tx) => {
    await ownedAlbum(tx, callerId, albumId);
    const posts = await tx.listAlbumPosts(albumId);
    const mine = await tx.listAlbums(callerId);
    for (const p of posts) tx.setPostAlbum(p.id, null, null);
    tx.deleteAlbum(albumId);
    const now = deps.clock.now();
    mine
      .filter((a) => a.id !== albumId)
      .forEach((a, i) => {
        if (a.position !== i + 1) tx.putAlbum({ ...a, position: i + 1, updatedAt: now });
      });
  });
}

export async function reorderAlbums(deps: AlbumDeps, callerId: string, raw: unknown): Promise<void> {
  const albumIds = idList(obj(raw).albumIds, ALBUMS_PER_PHOTOGRAPHER);
  await deps.albums.runTransaction(async (tx) => {
    const mine = await tx.listAlbums(callerId);
    if (!sameSet(albumIds, mine.map((a) => a.id))) throw new DomainError('invalid_argument');
    const byId = new Map(mine.map((a) => [a.id, a]));
    const now = deps.clock.now();
    albumIds.forEach((id, i) => {
      const a = byId.get(id) as Album;
      if (a.position !== i + 1) tx.putAlbum({ ...a, position: i + 1, updatedAt: now });
    });
  });
}

export async function movePostsToAlbum(
  deps: AlbumDeps,
  callerId: string,
  raw: unknown,
): Promise<void> {
  const r = obj(raw);
  const targetId = r.albumId === null ? null : idOf(r.albumId);
  const postIds = idList(r.postIds, MOVE_BATCH_MAX);
  if (postIds.length < 1) throw new DomainError('invalid_argument');

  await deps.albums.runTransaction(async (tx) => {
    // Reads first.
    const target = targetId === null ? null : await ownedAlbum(tx, callerId, targetId);
    const found = await tx.getPosts(postIds);
    const moved: AlbumPost[] = found.map((p) => {
      if (p === null) throw new DomainError('not_found');
      if (p.authorId !== callerId) throw new DomainError('permission_denied');
      if (p.kind !== 'work') throw new DomainError('invalid_argument');
      return p;
    });
    const sourceIds = [
      ...new Set(
        moved.map((p) => p.albumId).filter((id): id is string => id !== null && id !== targetId),
      ),
    ];
    const sources: Album[] = [];
    const srcPosts = new Map<string, AlbumPost[]>();
    for (const id of sourceIds) {
      const a = await tx.getAlbum(id);
      if (a === null) continue;
      sources.push(a);
      srcPosts.set(id, await tx.listAlbumPosts(id));
    }
    const targetPosts = target === null ? [] : await tx.listAlbumPosts(target.id);

    // Plan and check limits before any write.
    const moving = new Set(postIds);
    const base = targetPosts.filter((p) => !moving.has(p.id));
    if (target !== null && base.length + postIds.length > POSTS_PER_ALBUM) {
      throw new DomainError('limit_exceeded');
    }

    const now = deps.clock.now();
    for (const src of sources) {
      const kept = (srcPosts.get(src.id) as AlbumPost[]).filter((p) => !moving.has(p.id));
      kept.forEach((p, i) => {
        if (p.albumPosition !== i + 1) tx.setPostAlbum(p.id, src.id, i + 1);
      });
      const coverGone = src.cover !== null && moving.has(src.cover.postId);
      tx.putAlbum({
        ...src,
        postCount: kept.length,
        mediaCount: sum(kept),
        visible: kept.length > 0,
        cover: coverGone ? null : src.cover,
        updatedAt: now,
      });
    }
    if (target !== null) {
      base.forEach((p, i) => {
        if (p.albumPosition !== i + 1) tx.setPostAlbum(p.id, target.id, i + 1);
      });
      postIds.forEach((id, i) => tx.setPostAlbum(id, target.id, base.length + i + 1));
      tx.putAlbum({
        ...target,
        postCount: base.length + postIds.length,
        mediaCount: sum(base) + sum(moved),
        visible: true,
        updatedAt: now,
      });
    } else {
      postIds.forEach((id) => tx.setPostAlbum(id, null, null));
    }
  });
}

export async function reorderAlbumPosts(
  deps: AlbumDeps,
  callerId: string,
  raw: unknown,
): Promise<void> {
  const r = obj(raw);
  const albumId = idOf(r.albumId);
  const postIds = idList(r.postIds, POSTS_PER_ALBUM);
  await deps.albums.runTransaction(async (tx) => {
    await ownedAlbum(tx, callerId, albumId);
    const posts = await tx.listAlbumPosts(albumId);
    if (!sameSet(postIds, posts.map((p) => p.id))) throw new DomainError('invalid_argument');
    const byId = new Map(posts.map((p) => [p.id, p]));
    postIds.forEach((id, i) => {
      if ((byId.get(id) as AlbumPost).albumPosition !== i + 1) tx.setPostAlbum(id, albumId, i + 1);
    });
  });
}

/** Trigger use case (Decision 2). */
export async function appendNewPost(
  deps: AlbumDeps,
  postId: string,
): Promise<'appended' | 'skipped' | 'detached'> {
  return deps.albums.runTransaction(async (tx) => {
    const [post] = await tx.getPosts([postId]);
    if (post === null || post === undefined) return 'skipped';
    if (post.albumId === null || post.albumPosition !== null) return 'skipped';
    const album = await tx.getAlbum(post.albumId);
    if (
      album === null ||
      album.photographerId !== post.authorId ||
      album.postCount >= POSTS_PER_ALBUM
    ) {
      tx.setPostAlbum(postId, null, null);
      return 'detached';
    }
    tx.setPostAlbum(postId, album.id, album.postCount + 1);
    tx.putAlbum({
      ...album,
      postCount: album.postCount + 1,
      mediaCount: album.mediaCount + post.imageCount,
      visible: true,
      updatedAt: deps.clock.now(),
    });
    return 'appended';
  });
}

import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import type { Album, AlbumPost, AlbumStore, AlbumTx } from '@photobooking/domain';

export const ALBUMS_COLLECTION = 'albums';
export const POSTS = 'posts';

function toDate(v: unknown): Date {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return new Date(0);
}

function int(v: unknown): number {
  return typeof v === 'number' && Number.isInteger(v) ? v : 0;
}

function toAlbum(id: string, d: DocumentData): Album {
  const c = d.cover as { postId?: unknown; imageIndex?: unknown } | null | undefined;
  return {
    id,
    photographerId: String(d.photographerId ?? ''),
    title: String(d.title ?? ''),
    titleKey: String(d.titleKey ?? ''),
    description: String(d.description ?? ''),
    cover:
      c !== null && c !== undefined && typeof c.postId === 'string' && typeof c.imageIndex === 'number'
        ? { postId: c.postId, imageIndex: c.imageIndex }
        : null,
    position: int(d.position),
    postCount: int(d.postCount),
    mediaCount: int(d.mediaCount),
    visible: d.visible === true,
    createdAt: toDate(d.createdAt),
    updatedAt: toDate(d.updatedAt),
  };
}

function toPost(id: string, d: DocumentData): AlbumPost {
  return {
    id,
    authorId: String(d.authorId ?? ''),
    kind: String(d.kind ?? ''),
    imageCount: Array.isArray(d.imageUrls) ? d.imageUrls.length : 0,
    albumId: typeof d.albumId === 'string' ? d.albumId : null,
    albumPosition: typeof d.albumPosition === 'number' ? d.albumPosition : null,
  };
}

/**
 * Albums and the album slice of posts in Firestore. Reads go straight to the transaction; every
 * write is buffered until the callback has finished all its reads (Firestore requires reads
 * before writes), then applied together, so a refusal never leaves a partial write.
 */
export class FirestoreAlbumStore implements AlbumStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: AlbumTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const albumRef = (id: string): DocumentReference => this.firestore.collection(ALBUMS_COLLECTION).doc(id);
      const postRef = (id: string): DocumentReference => this.firestore.collection(POSTS).doc(id);
      const writes: Array<() => void> = [];

      const tx: AlbumTx = {
        listAlbums: async (photographerId) => {
          const snap = await fTx.get(
            this.firestore
              .collection(ALBUMS_COLLECTION)
              .where('photographerId', '==', photographerId)
              .orderBy('position'),
          );
          return snap.docs.map((s) => toAlbum(s.id, s.data()));
        },
        getAlbum: async (id) => {
          const s = await fTx.get(albumRef(id));
          const d = s.data();
          return s.exists && d ? toAlbum(id, d) : null;
        },
        getPosts: async (ids) => {
          if (ids.length === 0) return [];
          const snaps = await fTx.getAll(...ids.map(postRef));
          return snaps.map((s) => {
            const d = s.data();
            return s.exists && d ? toPost(s.id, d) : null;
          });
        },
        listAlbumPosts: async (albumId) => {
          const snap = await fTx.get(
            this.firestore.collection(POSTS).where('albumId', '==', albumId).orderBy('albumPosition'),
          );
          return snap.docs.map((s) => toPost(s.id, s.data()));
        },
        putAlbum: (a) => {
          writes.push(() => {
            fTx.set(albumRef(a.id), {
              photographerId: a.photographerId,
              title: a.title,
              titleKey: a.titleKey,
              description: a.description,
              cover: a.cover === null ? null : { postId: a.cover.postId, imageIndex: a.cover.imageIndex },
              position: a.position,
              postCount: a.postCount,
              mediaCount: a.mediaCount,
              visible: a.visible,
              createdAt: Timestamp.fromDate(a.createdAt),
              updatedAt: Timestamp.fromDate(a.updatedAt),
            });
          });
        },
        deleteAlbum: (id) => {
          writes.push(() => {
            fTx.delete(albumRef(id));
          });
        },
        setPostAlbum: (postId, albumId, position) => {
          writes.push(() => {
            fTx.update(
              postRef(postId),
              albumId === null
                ? { albumId: FieldValue.delete(), albumPosition: FieldValue.delete() }
                : { albumId, albumPosition: position },
            );
          });
        },
      };

      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }
}

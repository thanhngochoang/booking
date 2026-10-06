import type { Album, AlbumPost } from './album.js';
import type { Clock, IdGenerator } from './ports.js';

export interface AlbumTx {
  /** Ordered by position. */
  listAlbums(photographerId: string): Promise<Album[]>;
  getAlbum(id: string): Promise<Album | null>;
  getPosts(ids: readonly string[]): Promise<(AlbumPost | null)[]>;
  /** Ordered by albumPosition. */
  listAlbumPosts(albumId: string): Promise<AlbumPost[]>;
  putAlbum(a: Album): void;
  deleteAlbum(id: string): void;
  setPostAlbum(postId: string, albumId: string | null, position: number | null): void;
}

export interface AlbumStore {
  runTransaction<T>(fn: (tx: AlbumTx) => Promise<T>): Promise<T>;
}

export interface AlbumDeps {
  readonly albums: AlbumStore;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

import type { Album, AlbumPost } from './album.js';
import type { AlbumStore, AlbumTx } from './album_ports.js';

export class MemoryAlbumStore implements AlbumStore {
  readonly albums = new Map<string, Album>();
  readonly posts = new Map<string, AlbumPost>();
  /** Committed write count. */
  writes = 0;

  seedAlbum(a: Album): void {
    this.albums.set(a.id, a);
  }

  seedPost(p: AlbumPost): void {
    this.posts.set(p.id, p);
  }

  async runTransaction<T>(fn: (tx: AlbumTx) => Promise<T>): Promise<T> {
    const staged: Array<() => void> = [];
    let hasWritten = false;
    const guardRead = (name: string): void => {
      if (hasWritten) {
        throw new Error(`Transaction read after write: ${name} called after a write operation`);
      }
    };

    const tx: AlbumTx = {
      listAlbums: async (photographerId) => {
        guardRead('listAlbums');
        return [...this.albums.values()]
          .filter((a) => a.photographerId === photographerId)
          .sort((a, b) => a.position - b.position);
      },
      getAlbum: async (id) => {
        guardRead('getAlbum');
        return this.albums.get(id) ?? null;
      },
      getPosts: async (ids) => {
        guardRead('getPosts');
        return ids.map((id) => this.posts.get(id) ?? null);
      },
      listAlbumPosts: async (albumId) => {
        guardRead('listAlbumPosts');
        return [...this.posts.values()]
          .filter((p) => p.albumId === albumId)
          .sort((a, b) => (a.albumPosition ?? 0) - (b.albumPosition ?? 0));
      },
      putAlbum: (a) => {
        hasWritten = true;
        staged.push(() => {
          this.albums.set(a.id, a);
          this.writes += 1;
        });
      },
      deleteAlbum: (id) => {
        hasWritten = true;
        staged.push(() => {
          this.albums.delete(id);
          this.writes += 1;
        });
      },
      setPostAlbum: (postId, albumId, position) => {
        hasWritten = true;
        staged.push(() => {
          const p = this.posts.get(postId);
          if (p === undefined) return;
          this.posts.set(postId, { ...p, albumId, albumPosition: position });
          this.writes += 1;
        });
      },
    };

    const result = await fn(tx);
    for (const apply of staged) apply();
    return result;
  }
}

import { newUlid, type AlbumDeps } from '@photobooking/domain';
import { db as adminDb } from './admin.js';
import { FirestoreAlbumStore } from './album_firestore.js';

export function liveAlbumDeps(): AlbumDeps {
  return {
    albums: new FirestoreAlbumStore(adminDb()),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}

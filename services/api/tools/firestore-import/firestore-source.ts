// services/api/tools/firestore-import/firestore-source.ts
import { FieldPath, type Firestore, type QueryDocumentSnapshot } from 'firebase-admin/firestore';

import type { DocSource } from './export.js';

/**
 * Reads Firestore with firebase-admin, paged by document id. Points at the
 * emulator when FIRESTORE_EMULATOR_HOST is set, else at the project of
 * GOOGLE_APPLICATION_CREDENTIALS. Read-only.
 */
export function firestoreSource(db: Firestore, pageSize = 500): DocSource {
  return {
    async *list(collection: string) {
      let last: QueryDocumentSnapshot | undefined;
      for (;;) {
        let q = db.collection(collection).orderBy(FieldPath.documentId()).limit(pageSize);
        if (last) q = q.startAfter(last);
        const page = await q.get();
        for (const d of page.docs) yield { id: d.id, data: d.data() };
        if (page.size < pageSize) return;
        last = page.docs[page.docs.length - 1];
      }
    },
    async get(path: string) {
      const s = await db.doc(path).get();
      return s.exists ? (s.data() ?? null) : null;
    },
  };
}

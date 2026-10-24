import type { DocumentData, Firestore } from 'firebase-admin/firestore';

// ---- A strict in-memory Firestore: like the Admin SDK, a transaction refuses a read after its first write. ----

type Filter = [string, string, unknown];
interface Write { readonly op: 'set' | 'delete'; readonly path: string; readonly data?: DocumentData }

/** Documents by path; queries filter on `==` only (order and limit ignored). */
export function strictFirestore(docs: Record<string, DocumentData>) {
  const writes: Write[] = [];
  const reads: string[] = [];
  const snapOf = (path: string) => {
    const data = docs[path];
    return { id: path.split('/').pop() ?? '', exists: data !== undefined, data: () => data, ref: docRef(path) };
  };
  const run = (coll: string, filters: Filter[]) => {
    const found = Object.entries(docs)
      .filter(([path]) => path.startsWith(`${coll}/`) && !path.slice(coll.length + 1).includes('/'))
      .filter(([, d]) => filters.every(([f, op, v]) => (op === '==' ? d[f] === v : true)))
      .map(([path, d]) => ({ id: path.split('/').pop() ?? '', data: () => d }));
    return { empty: found.length === 0, docs: found };
  };
  const query = (coll: string, filters: Filter[]): unknown => ({
    coll,
    filters,
    where: (f: string, op: string, v: unknown) => query(coll, [...filters, [f, op, v]]),
    orderBy: () => query(coll, filters),
    limit: () => query(coll, filters),
    // Outside a transaction (no read-after-write check).
    get: async () => run(coll, filters),
  });
  const collection = (path: string): unknown => ({ ...(query(path, []) as object), doc: (id: string) => docRef(`${path}/${id}`) });
  const docRef = (path: string): unknown => ({ path, id: path.split('/').pop(), collection: (c: string) => collection(`${path}/${c}`) });
  const firestore = {
    collection,
    doc: (path: string) => docRef(path),
    runTransaction: async <T>(fn: (tx: unknown) => Promise<T>) => {
      let wrote = false;
      const pending: Write[] = [];
      const write = (w: Write) => {
        wrote = true;
        pending.push(w);
      };
      const tx = {
        get: async (x: { path?: string; coll?: string; filters?: Filter[] }) => {
          if (wrote) throw new Error(`read after write: ${x.path ?? x.coll ?? '?'}`);
          reads.push(x.path ?? `${x.coll}?${JSON.stringify(x.filters)}`);
          return x.coll !== undefined && x.filters !== undefined ? run(x.coll, x.filters) : snapOf(String(x.path));
        },
        set: (ref: { path: string }, data: DocumentData) => write({ op: 'set', path: ref.path, data }),
        delete: (ref: { path: string }) => write({ op: 'delete', path: ref.path }),
      };
      const result = await fn(tx);
      for (const w of pending) {
        writes.push(w);
        if (w.op === 'delete') Reflect.deleteProperty(docs, w.path);
        else docs[w.path] = w.data ?? {};
      }
      return result;
    },
  } as unknown as Firestore;
  return { firestore, writes, reads };
}


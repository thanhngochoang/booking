/**
 * A small in-memory stand-in for the Admin Firestore API, enough for the adapters' unit tests:
 * documents, collection queries (where ==, !=, in, not-in, array-contains(-any), <, <=, >, >=; orderBy; limit; startAfter), dotted field
 * paths, `FieldPath.documentId()`, transactions (writes applied after the callback, reads after a write
 * refused like Firestore does), `getAll`, `set` with `merge`, `update`, `delete`, and the sentinels
 * `FieldValue.increment`, `FieldValue.delete` and `FieldValue.serverTimestamp`.
 */

import { FieldValue, Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';

type Data = Record<string, unknown>;

function isPlainObject(v: unknown): v is Data {
  return typeof v === 'object' && v !== null && !Array.isArray(v) && Object.getPrototypeOf(v) === Object.prototype;
}

function getField(data: Data, field: string): unknown {
  let cur: unknown = data;
  for (const part of field.split('.')) {
    if (!isPlainObject(cur)) return undefined;
    cur = cur[part];
  }
  return cur;
}

function comparable(v: unknown): unknown {
  if (v instanceof Timestamp) return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return v;
}

function equal(a: unknown, b: unknown): boolean {
  const x = comparable(a);
  const y = comparable(b);
  if (Array.isArray(x) && Array.isArray(y)) return x.length === y.length && x.every((v, i) => equal(v, y[i]));
  return x === y;
}

function compare(a: unknown, b: unknown): number {
  const x = comparable(a) as number | string;
  const y = comparable(b) as number | string;
  return x < y ? -1 : x > y ? 1 : 0;
}

function isSentinel(v: unknown): v is FieldValue {
  return v instanceof FieldValue;
}

function applySentinel(current: unknown, v: FieldValue): unknown {
  if (v.isEqual(FieldValue.delete())) return undefined;
  if (v.isEqual(FieldValue.serverTimestamp())) return Timestamp.now();
  const operand = (v as unknown as { operand?: unknown }).operand;
  if (typeof operand === 'number') return (typeof current === 'number' ? current : 0) + operand;
  throw new Error(`memory_firestore: unsupported FieldValue ${v.constructor.name}`);
}

/** `merge` deep-merges maps, like `set(..., {merge: true})`. */
function mergeInto(base: Data, patch: Data, deep: boolean): Data {
  const out: Data = { ...base };
  for (const [k, v] of Object.entries(patch)) {
    if (isSentinel(v)) {
      const next = applySentinel(out[k], v);
      if (next === undefined) Reflect.deleteProperty(out, k);
      else out[k] = next;
    } else if (deep && isPlainObject(v) && isPlainObject(out[k])) {
      out[k] = mergeInto(out[k] as Data, v, true);
    } else {
      out[k] = isPlainObject(v) ? mergeInto({}, v, true) : v;
    }
  }
  return out;
}

/** `update` takes dotted keys as field paths. */
function updateInto(base: Data, patch: Data): Data {
  let out: Data = { ...base };
  for (const [k, v] of Object.entries(patch)) {
    const parts = k.split('.');
    const nested: Data = {};
    let cur = nested;
    parts.forEach((p, i) => {
      if (i === parts.length - 1) cur[p] = v;
      else cur = cur[p] = {} as Data;
    });
    out = mergeInto(out, nested, true);
  }
  return out;
}

interface Filter {
  readonly field: string | null; // null = document id
  readonly op: string;
  readonly value: unknown;
}

function matches(id: string, data: Data, f: Filter): boolean {
  const v = f.field === null ? id : getField(data, f.field);
  switch (f.op) {
    case '==':
      return v !== undefined && equal(v, f.value);
    case '!=':
      return v !== undefined && v !== null && !equal(v, f.value);
    case 'in':
      return v !== undefined && (f.value as unknown[]).some((x) => equal(v, x));
    case 'not-in':
      return v !== undefined && v !== null && !(f.value as unknown[]).some((x) => equal(v, x));
    case 'array-contains':
      return Array.isArray(v) && v.some((x) => equal(x, f.value));
    case 'array-contains-any':
      return Array.isArray(v) && v.some((x) => (f.value as unknown[]).some((y) => equal(x, y)));
    case '<':
    case '<=':
    case '>':
    case '>=': {
      if (v === undefined || v === null) return false;
      const c = compare(v, f.value);
      return f.op === '<' ? c < 0 : f.op === '<=' ? c <= 0 : f.op === '>' ? c > 0 : c >= 0;
    }
    default:
      throw new Error(`memory_firestore: unsupported operator ${f.op}`);
  }
}

export interface MemorySnapshot {
  readonly id: string;
  readonly exists: boolean;
  readonly ref: MemoryDocRef;
  data(): DocumentData | undefined;
  get(field: string): unknown;
}

export class MemoryFirestore {
  readonly docs = new Map<string, Data>();
  /** Every committed write, in order (path and kind). */
  readonly log: { path: string; kind: 'set' | 'update' | 'delete' }[] = [];
  transactions = 0;
  /** Documents read (each document returned by a get, getAll or query counts once). */
  reads = 0;

  seed(path: string, data: Data): void {
    this.docs.set(path, data);
  }

  data(path: string): Data | undefined {
    return this.docs.get(path);
  }

  collection(path: string): MemoryQuery {
    return new MemoryQuery(this, path, [], [], null);
  }

  doc(path: string): MemoryDocRef {
    return new MemoryDocRef(this, path);
  }

  async getAll(...refs: MemoryDocRef[]): Promise<MemorySnapshot[]> {
    return refs.map((r) => this.snapshot(r.path));
  }

  snapshot(path: string): MemorySnapshot {
    this.reads += 1;
    const d = this.docs.get(path);
    const ref = new MemoryDocRef(this, path);
    return {
      id: ref.id,
      exists: d !== undefined,
      ref,
      data: () => (d === undefined ? undefined : { ...d }),
      get: (field: string) => (d === undefined ? undefined : getField(d, field)),
    };
  }

  write(path: string, kind: 'set' | 'merge' | 'update' | 'delete', data?: Data): void {
    const base = this.docs.get(path);
    if (kind === 'delete') {
      this.docs.delete(path);
    } else if (kind === 'update') {
      if (base === undefined) throw Object.assign(new Error(`NOT_FOUND: ${path}`), { code: 5 });
      this.docs.set(path, updateInto(base, data ?? {}));
    } else {
      this.docs.set(path, mergeInto(kind === 'merge' ? (base ?? {}) : {}, data ?? {}, kind === 'merge'));
    }
    this.log.push({ path, kind: kind === 'merge' ? 'set' : kind });
  }

  async runTransaction<T>(fn: (tx: MemoryTransaction) => Promise<T>): Promise<T> {
    this.transactions += 1;
    const tx = new MemoryTransaction(this);
    const result = await fn(tx);
    tx.commit();
    return result;
  }

  /** The fake typed as the Admin SDK's Firestore, for adapters that take one. */
  asFirestore(): Firestore {
    return this as unknown as Firestore;
  }
}

export class MemoryDocRef {
  readonly id: string;
  constructor(
    private readonly db: MemoryFirestore,
    readonly path: string,
  ) {
    this.id = path.split('/').at(-1) ?? '';
  }

  get parent(): { id: string; path: string; parent: MemoryDocRef | null } {
    const parts = this.path.split('/');
    const colPath = parts.slice(0, -1).join('/');
    const parentDoc = parts.length > 2 ? new MemoryDocRef(this.db, parts.slice(0, -2).join('/')) : null;
    return { id: parts.at(-2) ?? '', path: colPath, parent: parentDoc };
  }

  collection(name: string): MemoryQuery {
    return this.db.collection(`${this.path}/${name}`);
  }

  async get(): Promise<MemorySnapshot> {
    return this.db.snapshot(this.path);
  }

  async set(data: Data, opts?: { merge?: boolean }): Promise<void> {
    this.db.write(this.path, opts?.merge === true ? 'merge' : 'set', data);
  }

  async update(data: Data): Promise<void> {
    this.db.write(this.path, 'update', data);
  }

  async delete(): Promise<void> {
    this.db.write(this.path, 'delete');
  }
}

export class MemoryQuery {
  constructor(
    private readonly db: MemoryFirestore,
    readonly path: string,
    private readonly filters: readonly Filter[],
    private readonly orders: readonly { field: string | null; dir: 'asc' | 'desc' }[],
    private readonly max: number | null,
    /** `startAfter(snapshot)`: the path of the last document of the previous page. */
    private readonly after: string | null = null,
  ) {}

  doc(id: string): MemoryDocRef {
    return new MemoryDocRef(this.db, `${this.path}/${id}`);
  }

  where(field: unknown, op: string, value: unknown): MemoryQuery {
    const f: Filter = { field: typeof field === 'string' ? field : null, op, value };
    return new MemoryQuery(this.db, this.path, [...this.filters, f], this.orders, this.max, this.after);
  }

  orderBy(field: unknown, dir: 'asc' | 'desc' = 'asc'): MemoryQuery {
    const f = typeof field === 'string' && field !== '__name__' ? field : null;
    return new MemoryQuery(this.db, this.path, this.filters, [...this.orders, { field: f, dir }], this.max, this.after);
  }

  limit(n: number): MemoryQuery {
    return new MemoryQuery(this.db, this.path, this.filters, this.orders, n, this.after);
  }

  /** Continues after a document snapshot of the same ordered query (the cursor of `startAfter(doc)`). */
  startAfter(doc: { readonly ref: { readonly path: string } }): MemoryQuery {
    return new MemoryQuery(this.db, this.path, this.filters, this.orders, this.max, doc.ref.path);
  }

  select(): MemoryQuery {
    return this;
  }

  run(): MemorySnapshot[] {
    const depth = this.path.split('/').length + 1;
    let rows = [...this.db.docs.entries()]
      .filter(([p]) => p.startsWith(`${this.path}/`) && p.split('/').length === depth)
      .filter(([p, d]) => this.filters.every((f) => matches(p.split('/').at(-1) ?? '', d, f)));
    for (const o of [...this.orders].reverse()) {
      rows = [...rows].sort(([pa, a], [pb, b]) => {
        const va = o.field === null ? pa : getField(a, o.field);
        const vb = o.field === null ? pb : getField(b, o.field);
        const c = compare(va, vb);
        return o.dir === 'asc' ? c : -c;
      });
    }
    if (this.orders.length > 0) {
      // Firestore leaves out documents without an orderBy field.
      rows = rows.filter(([, d]) => this.orders.every((o) => o.field === null || getField(d, o.field) !== undefined));
    }
    if (this.after !== null) {
      const i = rows.findIndex(([p]) => p === this.after);
      rows = i < 0 ? rows : rows.slice(i + 1);
    }
    const snaps = rows.map(([p]) => this.db.snapshot(p));
    return this.max === null ? snaps : snaps.slice(0, this.max);
  }

  async get(): Promise<{ docs: MemorySnapshot[]; size: number; empty: boolean }> {
    const docs = this.run();
    return { docs, size: docs.length, empty: docs.length === 0 };
  }
}

export class MemoryTransaction {
  private readonly staged: (() => void)[] = [];

  constructor(private readonly db: MemoryFirestore) {}

  private guard(): void {
    if (this.staged.length > 0) throw new Error('Firestore transactions require all reads to be executed before all writes.');
  }

  async get(target: MemoryDocRef | MemoryQuery): Promise<unknown> {
    this.guard();
    if (target instanceof MemoryDocRef) return this.db.snapshot(target.path);
    return target.get();
  }

  async getAll(...refs: MemoryDocRef[]): Promise<MemorySnapshot[]> {
    this.guard();
    return this.db.getAll(...refs);
  }

  set(ref: MemoryDocRef, data: Data, opts?: { merge?: boolean }): this {
    this.staged.push(() => this.db.write(ref.path, opts?.merge === true ? 'merge' : 'set', data));
    return this;
  }

  update(ref: MemoryDocRef, data: Data): this {
    this.staged.push(() => this.db.write(ref.path, 'update', data));
    return this;
  }

  delete(ref: MemoryDocRef): this {
    this.staged.push(() => this.db.write(ref.path, 'delete'));
    return this;
  }

  commit(): void {
    for (const apply of this.staged) apply();
  }
}

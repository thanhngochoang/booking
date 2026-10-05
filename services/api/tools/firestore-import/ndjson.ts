// services/api/tools/firestore-import/ndjson.ts
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';

export const sha256 = (text: string): string => createHash('sha256').update(text).digest('hex');

/** One JSON object per line, snake_case keys, trailing newline. */
export async function writeNdjson(path: string, rows: readonly object[]): Promise<{ rows: number; sha256: string }> {
  const text = rows.map((r) => `${JSON.stringify(r)}\n`).join('');
  await writeFile(path, text, 'utf8');
  return { rows: rows.length, sha256: sha256(text) };
}

export async function readNdjson<T>(path: string): Promise<{ rows: T[]; sha256: string }> {
  const text = await readFile(path, 'utf8');
  return {
    rows: text
      .split('\n')
      .filter((l) => l.length > 0)
      .map((l) => JSON.parse(l) as T),
    sha256: sha256(text),
  };
}

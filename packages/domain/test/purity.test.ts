import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));

function sources(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sources(path);
    return path.endsWith('.ts') ? [path] : [];
  });
}

const specifiers = (code: string): string[] =>
  [...code.matchAll(/(?:import|export)\s[^'"]*?from\s+['"]([^'"]+)['"]/g)].map((m) => m[1] ?? '');

test('domain source imports only its own modules (no Firebase, no Node APIs)', () => {
  const offenders = sources(join(root, 'src')).flatMap((file) =>
    specifiers(readFileSync(file, 'utf8'))
      .filter((s) => !s.startsWith('./') && !s.startsWith('../'))
      .map((s) => `${file}: ${s}`));
  assert.deepEqual(offenders, []);
});

test('domain package has no runtime dependencies', () => {
  const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')) as { dependencies?: unknown };
  assert.equal(pkg.dependencies, undefined);
});

// Bundles src/ and packages/domain into lib/index.js. firebase-admin and firebase-functions stay
// external (installed from package.json), so the deployed folder never needs the ../../../packages path.
import { build, context } from 'esbuild';

const options = {
  entryPoints: ['src/index.ts'],
  outfile: 'lib/index.js',
  bundle: true,
  platform: 'node',
  target: 'node22',
  format: 'esm',
  sourcemap: true,
  external: ['firebase-admin', 'firebase-functions'],
  tsconfig: 'tsconfig.json',
  logLevel: 'info',
};

if (process.argv.includes('--watch')) {
  const ctx = await context(options);
  await ctx.watch();
} else {
  await build(options);
}

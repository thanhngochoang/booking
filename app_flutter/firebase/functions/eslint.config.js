import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['node_modules/**', 'lib/**'] },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    files: ['**/*.js', '**/*.mjs'],
    languageOptions: { globals: { process: 'readonly', console: 'readonly' } },
  },
  {
    // Business rules belong in packages/domain; here only adapters and wiring.
    files: ['src/config.ts'],
    rules: {
      'no-restricted-imports': ['error', {
        patterns: [{ group: ['firebase-admin', 'firebase-admin/*'], message: 'config.ts holds options only.' }],
      }],
    },
  },
);

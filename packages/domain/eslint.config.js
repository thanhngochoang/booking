import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['node_modules/**'] },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    files: ['**/*.js'],
    languageOptions: { globals: { process: 'readonly', console: 'readonly' } },
  },
  {
    files: ['src/**/*.ts'],
    rules: {
      'no-restricted-imports': ['error', {
        patterns: [{
          group: ['firebase', 'firebase/*', 'firebase-admin', 'firebase-admin/*', 'firebase-functions',
            'firebase-functions/*', '@firebase/*', '@google-cloud/*', 'node:*'],
          message: 'packages/domain is backend-agnostic: no Firebase, Google Cloud or Node imports in src/.',
        }],
      }],
    },
  },
);

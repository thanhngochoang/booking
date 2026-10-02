// Refuses to touch anything but local emulators. Shared by the seed, the integration tests
// and the emulator client, so no code path can reach a real Firebase project by accident.

const LOCAL = /^(127\.0\.0\.1|localhost|0\.0\.0\.0|\[::1\]):\d+$/;

export interface LocalGuardOptions {
  /** Also require FUNCTIONS_EMULATOR_HOST (when the caller invokes functions). */
  readonly functions?: boolean;
  /** Skip the `demo-` project rule (dev script only: hosts are still checked). */
  readonly allowAnyProject?: boolean;
}

/** Returns the project id; throws unless every needed emulator host is local and the project is `demo-*`. */
export function assertLocalEmulators(options: LocalGuardOptions = {}, env: NodeJS.ProcessEnv = process.env): string {
  const keys = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST'];
  if (options.functions === true) keys.push('FUNCTIONS_EMULATOR_HOST');
  for (const key of keys) {
    const value = env[key];
    if (value === undefined || !LOCAL.test(value)) {
      throw new Error(`Refusing to run: ${key} must point at a local emulator (got ${value ?? 'nothing'}).`);
    }
  }
  const project = env.GCLOUD_PROJECT;
  if (project === undefined || project === '') throw new Error('Refusing to run: GCLOUD_PROJECT is not set.');
  if (options.allowAnyProject !== true && !project.startsWith('demo-')) {
    throw new Error(`Refusing to run: project id must start with "demo-" (got ${project}).`);
  }
  return project;
}

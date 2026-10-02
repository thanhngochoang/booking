// Ports: what the domain needs from the outside. Firebase adapters live in
// app_flutter/firebase/functions/src/infra; a self-hosted server writes its own.

export interface Clock {
  now(): Date;
}

export interface IdGenerator {
  newId(): string;
}

/** `users/{uid}/private/contact` as stored. The domain validates it; it is not trusted. */
export interface UserContactRecord {
  readonly phone?: unknown;
}

export interface UserContactReader {
  get(uid: string): Promise<UserContactRecord | null>;
}

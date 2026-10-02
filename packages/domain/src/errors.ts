/** Stable business error codes (data-model/domain-model.md §4 `ErrorCode`). */
export const ERROR_CODES = [
  'day_taken',
  'phone_required',
  'contact_locked',
  'sold_out',
  'deadline_passed',
  'limit_exceeded',
  'invalid_argument',
  'permission_denied',
  'not_found',
  'conflict',
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

/** A refused use case. The message is the code itself, so nothing else can leak. */
export class DomainError extends Error {
  constructor(readonly code: ErrorCode) {
    super(code);
    this.name = 'DomainError';
  }
}

export const isDomainError = (e: unknown): e is DomainError => e instanceof DomainError;

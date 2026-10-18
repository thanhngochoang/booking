import type { FastifyError, FastifyInstance } from 'fastify';

import { ERROR_CODES, type ErrorCode } from './domain/index.js';

/** HTTP-only codes, added to the domain catalogue (domain-model.md §4). */
export const TRANSPORT_CODES = ['unauthenticated', 'internal'] as const;
export type ApiErrorCode = ErrorCode | (typeof TRANSPORT_CODES)[number];
export const API_ERROR_CODES: readonly ApiErrorCode[] = [...ERROR_CODES, ...TRANSPORT_CODES];

/** Clients branch on `code`; the status is only HTTP plumbing. */
export const HTTP_STATUS: Record<ApiErrorCode, number> = {
  invalid_argument: 400,
  unauthenticated: 401,
  permission_denied: 403,
  contact_locked: 403,
  not_found: 404,
  conflict: 409,
  day_taken: 409,
  sold_out: 409,
  price_changed: 409,
  // The booking's state refuses another payment ("Tạo QR mới" used MAX_PAYMENT_ATTEMPTS times).
  payment_attempts_exceeded: 409,
  not_eligible: 403,
  not_accepting_orders: 403,
  // The customer and the provider blocked each other (either way): no new order or payment.
  blocked: 403,
  phone_required: 422,
  deadline_passed: 422,
  limit_exceeded: 429,
  reauth_required: 403,
  // S06.06 payout account v2: the bank holder name is not the verified name.
  name_mismatch: 422,
  // An OTP is needed (missing, used or for another account): like reauth_required, fresh proof is asked.
  otp_required: 403,
  // Wrong or expired OTP: the request is well-formed but its value is refused.
  otp_invalid: 422,
  otp_expired: 422,
  // Verification error codes (#135)
  identity_in_use: 409,
  underage: 422,
  rate_limited: 429,
  // Addon error codes (#190)
  addon_changed: 409,
  addon_not_applicable: 422,
  pickup_required: 422,
  addon_limit: 422,
  contact_leak: 422,
  // Delivery error codes (#152)
  not_ready: 422,
  internal: 500,
};

export class ApiError extends Error {
  constructor(
    readonly code: ApiErrorCode,
    message: string = code,
  ) {
    super(message);
    this.name = 'ApiError';
  }

  get status(): number {
    return HTTP_STATUS[this.code];
  }
}

export interface ErrorBody {
  code: ApiErrorCode;
  message: string;
  requestId: string;
}

const body = (code: ApiErrorCode, message: string, requestId: string): ErrorBody => ({ code, message, requestId });

export function installErrorHandling(app: FastifyInstance): void {
  app.setErrorHandler((err: FastifyError, req, reply) => {
    if (err instanceof ApiError) {
      return reply.status(err.status).send(body(err.code, err.message, req.id));
    }
    if (err.validation) {
      return reply.status(400).send(body('invalid_argument', 'request does not match the API contract', req.id));
    }
    if (typeof err.statusCode === 'number' && err.statusCode >= 400 && err.statusCode < 500) {
      return reply.status(err.statusCode).send(body('invalid_argument', 'malformed request', req.id));
    }
    // Never echo the original message: it may carry SQL or personal data.
    req.log.error({ err }, 'unhandled error');
    return reply.status(500).send(body('internal', 'internal error', req.id));
  });
  app.setNotFoundHandler((req, reply) => reply.status(404).send(body('not_found', 'no such route', req.id)));
}

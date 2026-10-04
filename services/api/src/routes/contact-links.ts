import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { ExternalChannel } from '../domain/index.js';
import { ApiError } from '../errors.js';
import { bookingContactQuery, logContactAccess } from '../repos/contact-links.js';
import { decideContactLink, type ContactLinkRow } from '../use-cases/get-contact-link.js';

interface ContactLinkBody {
  bookingId?: string;
  registrationId?: string;
  channel: ExternalChannel;
}

export function registerContactLinkRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Body: ContactLinkBody }>({
    ...operation(deps.contract, 'getContactLink'),
    handler: async (req, reply) => {
      const p = principalOf(req);
      reply.header('cache-control', 'no-store');
      const { channel } = req.body;
      const now = deps.clock.now();

      if (req.body.bookingId === undefined) {
        // The schema's oneOf guarantees registrationId here; event registrations arrive with the events plan.
        await logContactAccess(deps.db, {
          requesterId: p.uid, subjectType: 'event_registration', subjectId: req.body.registrationId ?? '',
          channel, granted: false, at: now,
        });
        throw new ApiError('not_found', 'event registrations are not served by this API yet');
      }

      const bookingId = req.body.bookingId;
      let granted = false;
      try {
        const row = (await bookingContactQuery(deps.db, bookingId).executeTakeFirst()) as ContactLinkRow | undefined;
        const url = decideContactLink(row, p.uid, channel, now);
        granted = true;
        return { url };
      } finally {
        await logContactAccess(deps.db, { requesterId: p.uid, subjectType: 'booking', subjectId: bookingId, channel, granted, at: now });
      }
    },
  });
}

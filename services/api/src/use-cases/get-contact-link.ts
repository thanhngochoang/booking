import type { BookingStatus } from '../db/database.js';
import { contactUnlocked, contactUrl, type ExternalChannel } from '../domain/index.js';
import { ApiError } from '../errors.js';

/** What bookingContactQuery returns for one booking. */
export interface ContactLinkRow {
  customer_id: string;
  status: BookingStatus;
  completed_at: Date | null;
  call_enabled: boolean | null;
  zalo_enabled: boolean | null;
  whatsapp_enabled: boolean | null;
  phone_e164: string | null;
  zalo_phone_e164: string | null;
  whatsapp_phone_e164: string | null;
}

/**
 * Use case get_contact_link (data-model README §5, domain-model.md §5 "Mở khoá liên hệ").
 * Order: exists → caller is the customer → unlocked → channel on with a number.
 */
export function decideContactLink(
  row: ContactLinkRow | undefined,
  requesterId: string,
  channel: ExternalChannel,
  now: Date,
): string {
  if (!row) throw new ApiError('not_found', 'booking not found');
  if (row.customer_id !== requesterId) {
    throw new ApiError('permission_denied', 'only the customer of this booking can open its contact');
  }
  if (!contactUnlocked({ status: row.status, completedAt: row.completed_at }, now)) {
    throw new ApiError('contact_locked', 'contact opens once the booking is paid');
  }
  const enabled = channel === 'call' ? row.call_enabled : channel === 'zalo' ? row.zalo_enabled : row.whatsapp_enabled;
  if (enabled !== true || row.phone_e164 === null) throw new ApiError('not_found', 'this channel is not available');
  const url = contactUrl(channel, {
    phone: row.phone_e164,
    zaloPhone: row.zalo_phone_e164,
    whatsappPhone: row.whatsapp_phone_e164,
  });
  if (!url) throw new ApiError('not_found', 'this channel is not available');
  return url;
}

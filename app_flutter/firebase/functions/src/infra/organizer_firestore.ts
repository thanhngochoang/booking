import { Timestamp, type DocumentData } from 'firebase-admin/firestore';
import { ORGANIZER_STATUSES, type Organizer, type OrganizerStatus, type Resident } from '@photobooking/domain';

/**
 * Read mappers of the S30 organizer documents (#223) used by the event store (entry events read their
 * host organizer and spot residents). The organizer store itself is Task 6's.
 */
export const ORGANIZERS_COLLECTION = 'organizers';
export const RESIDENTS_SUBCOLLECTION = 'residents';

const iso = (v: unknown): string | null => {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  return typeof v === 'string' && v !== '' ? v : null;
};
const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);

/** `organizers/{uid}`; null when the document is missing. */
export function organizerFromFirestore(id: string, d: DocumentData | undefined): Organizer | null {
  if (d === undefined) return null;
  const status: OrganizerStatus = (ORGANIZER_STATUSES as readonly unknown[]).includes(d.status) ? d.status as OrganizerStatus : 'suspended';
  return {
    id,
    name: String(d.name ?? ''),
    bio: String(d.bio ?? ''),
    avatarUrl: str(d.avatarUrl),
    status,
    phoneVerified: d.phoneVerified === true,
    businessVerified: d.businessVerified === true,
    payoutAccountOk: d.payoutAccountOk === true,
    managedSpotIds: Array.isArray(d.managedSpotIds) ? d.managedSpotIds.filter((x: unknown): x is string => typeof x === 'string') : [],
    createdAt: iso(d.createdAt) ?? new Date(0).toISOString(),
    updatedAt: iso(d.updatedAt) ?? new Date(0).toISOString(),
  };
}

/** `spots/{spotId}/residents/{providerId}`; null when the document is missing. */
export function residentFromFirestore(providerId: string, d: DocumentData | undefined): Resident | null {
  if (d === undefined) return null;
  return {
    providerId,
    waivesProvider: d.waivesProvider === true,
    waivesGuests: d.waivesGuests === true,
    maxGuests: typeof d.maxGuests === 'number' && Number.isInteger(d.maxGuests) ? d.maxGuests : null,
    validUntil: str(d.validUntil),
    addedAt: iso(d.addedAt) ?? new Date(0).toISOString(),
    addedBy: String(d.addedBy ?? ''),
  };
}

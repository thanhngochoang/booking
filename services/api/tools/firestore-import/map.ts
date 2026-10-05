// services/api/tools/firestore-import/map.ts
/** Pure Firestore document → relational row mapping for the slice (relational-schema.md §3). */
const ID = /^[A-Za-z0-9_-]{1,64}$/;
const E164 = /^\+[0-9]{8,15}$/;

export type Mapped<T> = { ok: true; value: T } | { ok: false; reason: string };
const ok = <T>(value: T): Mapped<T> => ({ ok: true, value });
const fail = <T>(reason: string): Mapped<T> => ({ ok: false, reason });

type Doc = Record<string, unknown>;

export interface FileRow {
  id: string;
  storage_provider: 'external';
  storage_key: string;
  mime_type: string;
  size_bytes: number;
  owner_user_id: string;
}
export interface UserRow {
  id: string;
  display_name: string;
  role: 'customer' | 'photographer' | null;
  avatar_file_id: string | null;
  created_at: string | null;
  updated_at: string | null;
}
export interface UserContactRow {
  user_id: string;
  phone_e164: string;
  phone_verified: boolean;
  allow_zalo: boolean;
  allow_whatsapp: boolean;
  updated_at: string | null;
}
export interface PhotographerRow {
  user_id: string;
  bio: string;
  years_experience: number | null;
  service_city: string | null;
  service_lat: number | null;
  service_lng: number | null;
  service_radius_km: number | null;
  verified: boolean;
  onboarding_complete: boolean;
  accepts_inquiries: boolean;
  created_at: string | null;
  updated_at: string | null;
}
export interface ChannelsRow {
  photographer_id: string;
  call_enabled: boolean;
  zalo_enabled: boolean;
  whatsapp_enabled: boolean;
}
export interface NumbersRow {
  photographer_id: string;
  phone_e164: string;
  zalo_phone_e164: string | null;
  whatsapp_phone_e164: string | null;
}

/** Firestore Timestamp (has toDate()), Date or ISO string → ISO-8601 UTC; anything else → null. */
export function toIso(v: unknown): string | null {
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'object' && v !== null && typeof (v as { toDate?: unknown }).toDate === 'function') {
    return (v as { toDate: () => Date }).toDate().toISOString();
  }
  if (typeof v === 'string' && !Number.isNaN(Date.parse(v))) return new Date(v).toISOString();
  return null;
}

const asMap = (v: unknown): Doc | null => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Doc) : null);
const intIn = (v: unknown, min: number, max: number): number | null =>
  typeof v === 'number' && Number.isInteger(v) && v >= min && v <= max ? v : null;
const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);

/** Deterministic, so a re-run upserts the same file row. */
export const avatarFileId = (uid: string): string => `avatar_${uid}`;

export function mapUser(id: string, d: Doc): Mapped<{ user: UserRow; file: FileRow | null }> {
  if (!ID.test(id)) return fail('id is not [A-Za-z0-9_-]{1,64}');
  const role = d.role ?? null;
  if (role !== null && role !== 'customer' && role !== 'photographer') return fail('unknown role');
  const url = typeof d.avatarUrl === 'string' && /^https?:\/\//.test(d.avatarUrl) ? d.avatarUrl : null;
  const fileId = avatarFileId(id);
  const file: FileRow | null =
    url && ID.test(fileId)
      ? { id: fileId, storage_provider: 'external', storage_key: url, mime_type: 'image/*', size_bytes: 0, owner_user_id: id }
      : null;
  return ok({
    user: {
      id,
      display_name: typeof d.displayName === 'string' ? d.displayName : '',
      role,
      avatar_file_id: file?.id ?? null,
      created_at: toIso(d.createdAt),
      updated_at: toIso(d.updatedAt),
    },
    file,
  });
}

export function mapUserContact(uid: string, d: Doc): Mapped<UserContactRow> {
  if (typeof d.phone !== 'string' || !E164.test(d.phone)) return fail('phone is not E.164');
  return ok({
    user_id: uid,
    phone_e164: d.phone,
    phone_verified: d.phoneVerified === true,
    allow_zalo: d.allowZalo !== false,
    allow_whatsapp: d.allowWhatsApp === true,
    updated_at: toIso(d.updatedAt),
  });
}

export function mapPhotographer(uid: string, d: Doc): Mapped<{ photographer: PhotographerRow; channels: ChannelsRow | null }> {
  const area = asMap(d.serviceArea);
  const center = asMap(area?.center);
  const channels = asMap(d.contactChannels);
  return ok({
    photographer: {
      user_id: uid,
      bio: typeof d.bio === 'string' ? d.bio : '',
      years_experience: intIn(d.yearsExperience, 0, 50),
      service_city: typeof area?.city === 'string' ? area.city : null,
      service_lat: num(center?.latitude),
      service_lng: num(center?.longitude),
      service_radius_km: intIn(area?.radiusKm, 1, 200),
      verified: d.verified === true,
      onboarding_complete: d.onboardingComplete === true,
      accepts_inquiries: channels?.acceptInquiries !== false,
      created_at: toIso(d.createdAt),
      updated_at: toIso(d.updatedAt),
    },
    channels: channels
      ? {
          photographer_id: uid,
          call_enabled: channels.call === true,
          zalo_enabled: channels.zalo === true,
          whatsapp_enabled: channels.whatsapp === true,
        }
      : null,
  });
}

export function mapPhotographerNumbers(uid: string, d: Doc): Mapped<NumbersRow> {
  if (typeof d.phone !== 'string' || !E164.test(d.phone)) return fail('phone is not E.164');
  const optional = (v: unknown): string | null | undefined =>
    v === undefined || v === null ? null : typeof v === 'string' && E164.test(v) ? v : undefined;
  const zalo = optional(d.zaloPhone);
  const whatsapp = optional(d.whatsappPhone);
  if (zalo === undefined) return fail('zaloPhone is not E.164');
  if (whatsapp === undefined) return fail('whatsappPhone is not E.164');
  return ok({ photographer_id: uid, phone_e164: d.phone, zalo_phone_e164: zalo, whatsapp_phone_e164: whatsapp });
}

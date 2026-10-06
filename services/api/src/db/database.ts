import { Kysely, PostgresDialect, type ColumnType } from 'kysely';
import pg from 'pg';

// int8 (bigint money, count(*)) → number; refuse values a JS number cannot hold exactly.
pg.types.setTypeParser(20, (v: string) => {
  const n = Number(v);
  if (!Number.isSafeInteger(n)) throw new RangeError(`int8 value ${v} exceeds Number.MAX_SAFE_INTEGER`);
  return n;
});
// date stays 'yyyy-MM-dd': a calendar day in Asia/Ho_Chi_Minh, not an instant.
pg.types.setTypeParser(1082, (v: string) => v);

/** `default now()`, never written by the API. */
type CreatedAt = ColumnType<Date, Date | string | undefined, never>;
/** Defaulted on insert; the set_updated_at trigger bumps it on update. */
type UpdatedAt = ColumnType<Date, Date | string | undefined, Date | string>;
/** Nullable column, optional on insert. */
type Opt<T> = ColumnType<T | null, T | null | undefined, T | null>;
/** Column with a database default, optional on insert. */
type Def<T> = ColumnType<T, T | undefined, T>;

export type UserRole = 'customer' | 'photographer';
export type StaffRole = 'admin' | 'sales';
export type AuthProvider = 'password' | 'google' | 'facebook' | 'apple' | 'oidc';
export type BookingStatus =
  | 'draft' | 'requested' | 'accepted' | 'declined' | 'expired' | 'cancelled' | 'upcoming' | 'completed' | 'reviewed';
export type ContactChannelCode = 'in_app' | 'call' | 'zalo' | 'whatsapp';

export interface FilesTable {
  id: string;
  owner_user_id: Opt<string>;
  storage_provider: string;
  storage_key: string;
  mime_type: string;
  size_bytes: number;
  width: Opt<number>;
  height: Opt<number>;
  blurhash: Opt<string>;
  created_at: CreatedAt;
}

export interface UsersTable {
  id: string;
  display_name: Def<string>;
  avatar_file_id: Opt<string>;
  role: Opt<UserRole>;
  staff_role: Opt<StaffRole>;
  city: Opt<string>;
  locale: Def<string>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
  deleted_at: Opt<Date>;
}

export interface UserContactsTable {
  user_id: string;
  phone_e164: string;
  phone_verified: Def<boolean>;
  allow_zalo: Def<boolean>;
  allow_whatsapp: Def<boolean>;
  updated_at: UpdatedAt;
}

export interface AuthIdentitiesTable {
  id: string;
  user_id: string;
  provider: AuthProvider;
  subject: string;
  email: Opt<string>;
  created_at: CreatedAt;
}

export interface TaxonomyItemsTable {
  id: string;
  grp: 'specialty' | 'style' | 'extra' | 'language' | 'audience' | 'area';
  label_vi: string;
  parent_id: Opt<string>;
  sort_order: Def<number>;
  active: Def<boolean>;
}

export interface PhotographersTable {
  user_id: string;
  bio: Def<string>;
  years_experience: Opt<number>;
  service_city: Opt<string>;
  service_lat: Opt<number>;
  service_lng: Opt<number>;
  service_radius_km: Opt<number>;
  cover_file_id: Opt<string>;
  verified: Def<boolean>;
  verified_at: Opt<Date>;
  onboarding_complete: Def<boolean>;
  accepts_inquiries: Def<boolean>;
  /** numeric(3,2): pg returns a string, kept as is (derived, read-only here). */
  rating_avg: Def<string>;
  review_count: Def<number>;
  completed_count: Def<number>;
  response_minutes_median: Opt<number>;
  starting_price: Opt<number>;
  next_free_date: Opt<string>;
  skills_completeness: Def<number>;
  provider_type: Def<'individual' | 'artist' | 'studio'>;
  artist_since: Opt<Date>;
  studio_district: Opt<string>;
  studio_city: Opt<string>;
  approved_award_count: Def<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface StudioAddressesTable {
  photographer_id: string;
  line: string;
  ward: Opt<string>;
  district: string;
  city: string;
  lat: Opt<number>;
  lng: Opt<number>;
  updated_at: UpdatedAt;
}

export interface PhotographerContactChannelsTable {
  photographer_id: string;
  call_enabled: Def<boolean>;
  zalo_enabled: Def<boolean>;
  whatsapp_enabled: Def<boolean>;
}

export interface PhotographerContactNumbersTable {
  photographer_id: string;
  phone_e164: string;
  zalo_phone_e164: Opt<string>;
  whatsapp_phone_e164: Opt<string>;
}

export interface ServicesTable {
  id: string;
  photographer_id: string;
  name: string;
  specialty_id: Opt<string>;
  duration_minutes: number;
  price: number;
  currency: Def<string>;
  photo_count: Opt<number>;
  edited_count: Opt<number>;
  delivery_days: Opt<number>;
  cover_file_id: Opt<string>;
  active: Def<boolean>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface BookingsTable {
  id: string;
  customer_id: string;
  photographer_id: string;
  service_id: string;
  service_name: string;
  service_price: number;
  service_duration_minutes: number;
  day: string;
  start_time: string;
  end_time: string;
  place_name: Opt<string>;
  place_lat: Opt<number>;
  place_lng: Opt<number>;
  note: Opt<string>;
  status: BookingStatus;
  deposit_amount: number;
  remaining_amount: number;
  currency: Def<string>;
  deposit_provider: Opt<'momo' | 'vnpay'>;
  deposit_paid_at: Opt<Date>;
  deposit_refunded_at: Opt<Date>;
  accept_deadline: Opt<Date>;
  cancelled_by: Opt<'customer' | 'photographer' | 'system'>;
  cancel_reason: Opt<string>;
  cancelled_at: Opt<Date>;
  cancel_refund_percent: Opt<number>;
  chat_id: Opt<string>;
  version: Def<number>;
  created_at: CreatedAt;
  updated_at: UpdatedAt;
}

export interface BookingEventsTable {
  id: string;
  booking_id: string;
  status: string;
  actor_id: Opt<string>;
  at: ColumnType<Date, Date | string | undefined, never>;
}

export interface ContactAccessLogTable {
  id: string;
  requester_id: string;
  subject_type: string;
  subject_id: string;
  channel: ContactChannelCode;
  granted: boolean;
  at: ColumnType<Date, Date | string | undefined, never>;
}

export interface Database {
  files: FilesTable;
  users: UsersTable;
  user_contacts: UserContactsTable;
  auth_identities: AuthIdentitiesTable;
  taxonomy_items: TaxonomyItemsTable;
  photographers: PhotographersTable;
  studio_addresses: StudioAddressesTable;
  photographer_contact_channels: PhotographerContactChannelsTable;
  photographer_contact_numbers: PhotographerContactNumbersTable;
  services: ServicesTable;
  bookings: BookingsTable;
  booking_events: BookingEventsTable;
  contact_access_log: ContactAccessLogTable;
}

export function createDb(databaseUrl: string, max: number): Kysely<Database> {
  return new Kysely<Database>({
    dialect: new PostgresDialect({
      pool: new pg.Pool({
        connectionString: databaseUrl,
        max,
        idleTimeoutMillis: 30_000,
        connectionTimeoutMillis: 2_000,
      }),
    }),
  });
}

/** Postgres foreign_key_violation (SQLSTATE 23503). */
export function isForeignKeyViolation(e: unknown): boolean {
  return typeof e === 'object' && e !== null && (e as { code?: unknown }).code === '23503';
}

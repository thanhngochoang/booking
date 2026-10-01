# Lược đồ quan hệ (chuẩn đích) và ánh xạ từ Firestore

Chuẩn đích là PostgreSQL 15+ (với PostGIS tuỳ chọn). Đây là **mô hình chuẩn** để mọi cài đặt (Firestore hiện tại, SQL sau này) cùng tham chiếu. Quy chuẩn kiểu ở [README.md](README.md) mục 2; thực thể và enum ở [domain-model.md](domain-model.md).

## 1. Quy ước DDL

- Bảng và cột `snake_case`; khoá chính `id text` (hoặc khoá ghép); thời điểm `timestamptz`; ngày `date`; giờ `time`; tiền `bigint` + `currency char(3) not null default 'VND'`.
- Enum lưu `text` kèm `CHECK (… IN (…))` (không dùng kiểu `ENUM` của PostgreSQL để thêm giá trị không cần khoá bảng; hoặc dùng bảng tra khi danh mục lớn).
- Mọi bảng có `created_at timestamptz not null default now()`; bảng có cập nhật có `updated_at`; bảng nội dung người dùng có `deleted_at`.
- Khoá ngoại `ON DELETE RESTRICT` mặc định; liên kết con thuần (ảnh của bài, thành viên chat) `ON DELETE CASCADE`.
- Tên ràng buộc: `pk_<bảng>`, `fk_<bảng>_<cột>`, `ck_<bảng>_<ý>`, `ux_<bảng>_<cột>`, `ix_<bảng>_<cột>`.

```sql
-- Dùng trong mọi bảng cần cập nhật
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end $$ language plpgsql;
```

## 2. Bảng

### 2.1 Tài khoản, tệp

```sql
create table files (
  id               text primary key,
  owner_user_id    text,                          -- fk users (thêm sau để tránh vòng)
  storage_provider text not null,                 -- 'firebase' | 's3' | 'gcs' | 'minio'
  storage_key      text not null,                 -- khoá trong kho, KHÔNG phải URL
  mime_type        text not null,
  size_bytes       bigint not null check (size_bytes >= 0),
  width            int, height int,
  blurhash         text,
  created_at       timestamptz not null default now(),
  unique (storage_provider, storage_key)
);

create table users (
  id           text primary key,                  -- = uid Firebase hiện tại
  display_name text not null default '',
  avatar_file_id text references files(id),
  role         text check (role in ('customer','photographer')),   -- null tới khi chọn
  staff_role   text check (staff_role in ('admin','sales')),       -- phản chiếu custom claim
  city         text,
  locale       text not null default 'vi',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
alter table files add constraint fk_files_owner foreign key (owner_user_id) references users(id);

create table user_contacts (                      -- 🔒 riêng tư
  user_id        text primary key references users(id) on delete cascade,
  phone_e164     text not null check (phone_e164 ~ '^\+[0-9]{8,15}$'),
  phone_verified boolean not null default false,
  allow_zalo     boolean not null default true,
  allow_whatsapp boolean not null default false,
  updated_at     timestamptz not null default now()
);

create table auth_identities (                    -- 🔒
  id         text primary key,
  user_id    text not null references users(id) on delete cascade,
  provider   text not null check (provider in ('password','google','facebook','apple','oidc')),
  subject    text not null,                       -- uid/sub ở nhà cung cấp
  email      text,
  created_at timestamptz not null default now(),
  unique (provider, subject)
);

create table devices (                            -- 🔒 thay users.fcmTokens
  id        text primary key,
  user_id   text not null references users(id) on delete cascade,
  provider  text not null check (provider in ('fcm','apns')),
  token     text not null unique,
  platform  text not null check (platform in ('android','ios')),
  last_seen_at timestamptz not null default now()
);
```

### 2.2 Danh mục (taxonomy) và nhiếp ảnh gia

```sql
create table taxonomy_items (
  id         text primary key,                    -- mã ổn định: 'portrait', 'natural_light', 'vi'
  grp        text not null check (grp in ('specialty','style','extra','language','audience','area')),
  label_vi   text not null,
  parent_id  text references taxonomy_items(id),  -- khu vực lồng nhau
  sort_order int not null default 0,
  active     boolean not null default true
);
create index ix_taxonomy_items_grp on taxonomy_items (grp, sort_order);

create table photographers (
  user_id              text primary key references users(id) on delete cascade,
  bio                  text not null default '',
  years_experience     smallint check (years_experience between 0 and 50),
  service_city         text,
  service_lat          double precision, service_lng double precision,
  service_radius_km    smallint,
  cover_file_id        text references files(id),
  verified             boolean not null default false,
  verified_at          timestamptz,
  onboarding_complete  boolean not null default false,
  accepts_inquiries    boolean not null default true,
  -- dẫn xuất (use case ghi)
  rating_avg           numeric(3,2) not null default 0,
  review_count         int not null default 0,
  completed_count      int not null default 0,
  response_minutes_median int,
  starting_price       bigint,
  next_free_date       date,
  skills_completeness  smallint not null default 0 check (skills_completeness between 0 and 100),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create table photographer_contact_channels (      -- công khai: chỉ cờ
  photographer_id text primary key references photographers(user_id) on delete cascade,
  call_enabled     boolean not null default false,
  zalo_enabled     boolean not null default false,
  whatsapp_enabled boolean not null default false
);

create table photographer_contact_numbers (       -- 🔒 không bao giờ ra ngoài use case
  photographer_id text primary key references photographers(user_id) on delete cascade,
  phone_e164      text not null check (phone_e164 ~ '^\+[0-9]{8,15}$'),
  zalo_phone_e164 text, whatsapp_phone_e164 text
);

create table services (
  id               text primary key,
  photographer_id  text not null references photographers(user_id) on delete cascade,
  name             text not null,
  specialty_id     text references taxonomy_items(id),
  duration_minutes int not null check (duration_minutes > 0),
  price            bigint not null check (price > 0),
  currency         char(3) not null default 'VND',
  photo_count      int, edited_count int, delivery_days int,
  cover_file_id    text references files(id),
  active           boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index ix_services_photographer on services (photographer_id) where active;

create table photographer_specialties (
  photographer_id text not null references photographers(user_id) on delete cascade,
  specialty_id    text not null references taxonomy_items(id),
  level           smallint not null check (level between 1 and 3),
  years           smallint,
  primary key (photographer_id, specialty_id)
);
create table photographer_specialty_evidence (
  photographer_id text not null,
  specialty_id    text not null,
  post_id         text not null,                  -- fk posts (thêm sau)
  primary key (photographer_id, specialty_id, post_id),
  foreign key (photographer_id, specialty_id) references photographer_specialties on delete cascade
);
create table photographer_skill_tags (
  photographer_id text not null references photographers(user_id) on delete cascade,
  grp  text not null check (grp in ('style','extra','language','audience')),
  item_id text not null references taxonomy_items(id),
  primary key (photographer_id, grp, item_id)
);

create table availability_days (
  photographer_id text not null references photographers(user_id) on delete cascade,
  day     date not null,
  state   text not null check (state in ('off','booked','pending')),
  booking_id text,                                -- fk bookings (thêm sau)
  event_id   text,                                -- fk events (thêm sau)
  primary key (photographer_id, day)
);
```

### 2.3 Nội dung

```sql
create table posts (
  id              text primary key,
  author_id       text not null references users(id),
  kind            text not null check (kind in ('work','real_shoot','event_share')),
  photographer_id text references photographers(user_id),
  service_id      text references services(id),
  booking_id      text,                           -- fk bookings (thêm sau), với real_shoot
  caption         text not null default '',
  location_name   text, lat double precision, lng double precision, geohash text,
  style_id        text references taxonomy_items(id),
  in_portfolio    boolean not null default false,
  like_count      int not null default 0,
  save_count      int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  check (kind <> 'work' or (photographer_id is not null and service_id is not null))
);
create index ix_posts_feed on posts (kind, created_at desc) where deleted_at is null;
create index ix_posts_photographer on posts (photographer_id, created_at desc) where deleted_at is null;
create index ix_posts_geohash on posts (geohash) where deleted_at is null;
alter table photographer_specialty_evidence add constraint fk_evidence_post foreign key (post_id) references posts(id) on delete cascade;

create table post_images (
  post_id  text not null references posts(id) on delete cascade,
  position smallint not null,
  file_id  text not null references files(id),
  primary key (post_id, position)
);
create table post_hashtags (
  post_id text not null references posts(id) on delete cascade,
  tag     text not null check (tag = lower(tag)),
  primary key (post_id, tag)
);
create index ix_post_hashtags_tag on post_hashtags (tag);

create table likes   (user_id text not null references users(id) on delete cascade, post_id text not null references posts(id) on delete cascade, created_at timestamptz not null default now(), primary key (user_id, post_id));
create table saves   (user_id text not null references users(id) on delete cascade, post_id text not null references posts(id) on delete cascade, created_at timestamptz not null default now(), primary key (user_id, post_id));
create table follows (follower_id text not null references users(id) on delete cascade, photographer_id text not null references photographers(user_id) on delete cascade, created_at timestamptz not null default now(), primary key (follower_id, photographer_id));
```

### 2.4 Đặt lịch, thanh toán, tiền treo

```sql
create table bookings (
  id               text primary key,
  customer_id      text not null references users(id),
  photographer_id  text not null references photographers(user_id),
  service_id       text not null references services(id),
  service_name     text not null,                 -- snapshot gói
  service_price    bigint not null check (service_price > 0),
  service_duration_minutes int not null,
  day              date not null,
  start_time       time not null,
  end_time         time not null check (end_time > start_time),
  place_name       text, place_lat double precision, place_lng double precision,
  note             text,
  status           text not null check (status in ('draft','requested','accepted','declined','expired','cancelled','upcoming','completed','reviewed')),
  deposit_amount   bigint not null check (deposit_amount >= 0),
  remaining_amount bigint not null check (remaining_amount >= 0),
  currency         char(3) not null default 'VND',
  deposit_provider text check (deposit_provider in ('momo','vnpay')),
  deposit_paid_at  timestamptz, deposit_refunded_at timestamptz,
  accept_deadline  timestamptz,
  cancelled_by     text check (cancelled_by in ('customer','photographer','system')),
  cancel_reason    text, cancelled_at timestamptz, cancel_refund_percent smallint,
  chat_id          text,                          -- fk chats (thêm sau)
  version          int not null default 1,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (deposit_amount + remaining_amount = service_price)
);
create index ix_bookings_customer on bookings (customer_id, status, day);
create index ix_bookings_photographer on bookings (photographer_id, status, day);
create unique index ux_bookings_active_day on bookings (photographer_id, day) where status in ('requested','accepted','upcoming');

create table booking_events (
  id         text primary key,
  booking_id text not null references bookings(id) on delete cascade,
  status     text not null,
  actor_id   text references users(id),
  at         timestamptz not null default now()
);
create index ix_booking_events_booking on booking_events (booking_id, at);

create table booking_contacts (                   -- 🔒
  booking_id     text primary key references bookings(id) on delete cascade,
  name           text not null,
  phone_e164     text,
  allow_zalo     boolean not null default true,
  allow_whatsapp boolean not null default false,
  redacted_at    timestamptz
);

alter table availability_days add constraint fk_avail_booking foreign key (booking_id) references bookings(id);
alter table posts add constraint fk_posts_booking foreign key (booking_id) references bookings(id);

create table payments (
  id              text primary key,
  subject_type    text not null check (subject_type in ('booking','event_registration','instant_request')),
  subject_id      text not null,
  payee_id        text references users(id),      -- nhiếp ảnh gia / chủ sự kiện nhận tiền; null = nền tảng
  provider        text not null check (provider in ('momo','vnpay')),
  amount          bigint not null check (amount >= 0),
  currency        char(3) not null default 'VND',
  status          text not null check (status in ('created','paid','failed','refunded','partially_refunded')),
  escrow_status   text not null default 'held' check (escrow_status in ('held','released','paid_out','partially_refunded','refunded','disputed')),
  release_after   timestamptz,                    -- hết cửa sổ khiếu nại
  released_at     timestamptz,
  provider_ref    text,
  raw             jsonb,                          -- phản hồi thô của cổng
  idempotency_key text not null unique,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index ix_payments_subject on payments (subject_type, subject_id);
create index ix_payments_release on payments (escrow_status, release_after) where escrow_status = 'held';

create table refunds (
  id         text primary key,
  payment_id text not null references payments(id),
  amount     bigint not null check (amount > 0),
  percent    smallint check (percent between 0 and 100),
  status     text not null check (status in ('pending','done','failed')),
  manual     boolean not null default false,
  created_at timestamptz not null default now()
);

create table payout_accounts (                    -- 🔒
  id                 text primary key,
  user_id            text not null references users(id) on delete cascade,
  bank_code          text not null,
  account_number_enc bytea not null,              -- mã hoá ở tầng ứng dụng/KMS
  account_last4      char(4) not null,
  holder_name        text not null,
  active             boolean not null default true,
  created_at         timestamptz not null default now()
);
create unique index ux_payout_accounts_active on payout_accounts (user_id) where active;

create table payouts (
  id             text primary key,
  payee_id       text not null references users(id),
  account_id     text not null references payout_accounts(id),
  amount         bigint not null check (amount > 0),
  currency       char(3) not null default 'VND',
  status         text not null check (status in ('pending','on_hold','processing','paid','failed')),
  reference      text,                             -- mã giao dịch ngân hàng
  approved_by    text references users(id),
  failure_reason text,
  created_at     timestamptz not null default now(),
  scheduled_at   timestamptz, paid_at timestamptz
);
create table payout_items (
  payout_id  text not null references payouts(id) on delete cascade,
  payment_id text not null references payments(id),
  amount     bigint not null check (amount > 0),
  primary key (payout_id, payment_id)
);

create table ledger_entries (                     -- bất biến, chỉ thêm
  id              text primary key,
  type            text not null check (type in ('deposit_received','ticket_received','refund_issued','escrow_released','payout_paid','fee_charged','adjustment')),
  payment_id      text references payments(id),
  refund_id       text references refunds(id),
  payout_id       text references payouts(id),
  account_owner_id text references users(id),      -- người được ghi có (nhiếp ảnh gia) hoặc null = nền tảng
  amount          bigint not null,                 -- có dấu
  currency        char(3) not null default 'VND',
  note            text,
  at              timestamptz not null default now()
);
create index ix_ledger_payment on ledger_entries (payment_id, at);
create index ix_ledger_owner on ledger_entries (account_owner_id, at);

create table reviews (
  booking_id      text primary key references bookings(id),
  customer_id     text not null references users(id),
  photographer_id text not null references photographers(user_id),
  rating          smallint not null check (rating between 1 and 5),
  text            text not null,
  photo_post_id   text references posts(id),
  created_at      timestamptz not null default now(),
  deleted_at      timestamptz
);
create index ix_reviews_photographer on reviews (photographer_id, created_at desc) where deleted_at is null;
```

### 2.5 Trò chuyện, thông báo

```sql
create table chats (
  id                   text primary key,
  kind                 text not null check (kind in ('inquiry','booking','event_group')),
  booking_id           text unique references bookings(id),
  event_id             text,                       -- fk events (thêm sau), duy nhất khi event_group
  customer_id          text references users(id),
  photographer_id      text references photographers(user_id),
  assignee_id          text references users(id),  -- hỗ trợ sự kiện nền tảng
  photographer_replied_at timestamptz,
  moderators_only      boolean not null default false,
  last_message_at      timestamptz,
  last_message_preview text,
  closed_at            timestamptz,
  created_at           timestamptz not null default now(),
  check (kind <> 'event_group' or event_id is not null)
);
create unique index ux_chats_event_group on chats (event_id) where kind = 'event_group';
alter table bookings add constraint fk_bookings_chat foreign key (chat_id) references chats(id);

create table chat_members (
  chat_id    text not null references chats(id) on delete cascade,
  user_id    text not null references users(id) on delete cascade,
  role       text not null default 'member' check (role in ('member','moderator')),
  muted_until timestamptz,
  unread_count int not null default 0,
  last_read_at timestamptz,
  joined_at  timestamptz not null default now(),
  removed_at timestamptz,
  primary key (chat_id, user_id)
);

create table messages (
  id        text primary key,
  chat_id   text not null references chats(id) on delete cascade,
  sender_id text references users(id),             -- null = tin hệ thống
  type      text not null check (type in ('text','image','location','system')),
  body      text,
  file_id   text references files(id),
  lat double precision, lng double precision,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index ix_messages_chat on messages (chat_id, created_at desc);

create table chat_pins (
  chat_id    text not null references chats(id) on delete cascade,
  message_id text not null references messages(id) on delete cascade,
  pinned_by  text not null references users(id),
  pinned_at  timestamptz not null default now(),
  primary key (chat_id, message_id)
);

create table notifications (
  id         text primary key,
  user_id    text not null references users(id) on delete cascade,
  type       text not null,
  title      text not null, body text not null,
  booking_id text, post_id text, event_id text,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index ix_notifications_user on notifications (user_id, created_at desc);
```

### 2.6 Sự kiện

```sql
create table events (
  id            text primary key,
  hashtag       text not null unique check (hashtag ~ '^[a-z0-9]{3,40}$'),   -- lưu chữ thường
  host_type     text not null check (host_type in ('photographer','platform')),
  host_photographer_id text references photographers(user_id),
  created_by    text not null references users(id),
  created_by_role text not null check (created_by_role in ('photographer','admin','sales')),
  host_consent  text not null default 'not_required' check (host_consent in ('not_required','pending','accepted','declined')),
  title         text not null, description text not null default '',
  cover_file_id text references files(id),
  type          text not null check (type in ('photo_walk','mini_session','workshop','cosplay','other')),
  starts_at     timestamptz not null, ends_at timestamptz not null check (ends_at > starts_at),
  location_name text not null, meeting_point text,
  lat double precision, lng double precision, geohash text,
  capacity      int not null check (capacity between 1 and 500),
  price         bigint not null default 0 check (price >= 0),   -- 0 = không thu phí
  currency      char(3) not null default 'VND',
  registration_deadline timestamptz not null,
  status        text not null check (status in ('draft','open','full','closed','cancelled','completed')),
  registered_count int not null default 0, held_count int not null default 0,
  chat_id       text,
  version       int not null default 1,
  created_at    timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (host_type <> 'photographer' or host_photographer_id is not null),
  check (registered_count + held_count <= capacity)
);
create index ix_events_listing on events (status, starts_at);
create index ix_events_geohash on events (geohash, starts_at);
alter table availability_days add constraint fk_avail_event foreign key (event_id) references events(id);
alter table chats add constraint fk_chats_event foreign key (event_id) references events(id);
alter table events add constraint fk_events_chat foreign key (chat_id) references chats(id);

create table event_registrations (
  id              text primary key,
  event_id        text not null references events(id),
  user_id         text not null references users(id),
  name            text not null,
  phone_e164      text,                            -- 🔒
  quantity        smallint not null check (quantity between 1 and 4),
  amount          bigint not null check (amount >= 0),
  currency        char(3) not null default 'VND',
  status          text not null check (status in ('held','paid','cancelled','refunded')),
  hold_expires_at timestamptz,
  ticket_code     text not null unique,
  payment_id      text references payments(id),
  checked_in_at   timestamptz, cancelled_at timestamptz,
  refund_percent  smallint,
  version         int not null default 1,
  created_at      timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index ix_event_regs_event on event_registrations (event_id, status);
create index ix_event_regs_user on event_registrations (user_id, status);
create unique index ux_event_regs_active on event_registrations (event_id, user_id) where status in ('held','paid');

create table event_posts (
  event_id text not null references events(id) on delete cascade,
  post_id  text not null references posts(id) on delete cascade,
  source   text not null check (source in ('hashtag','explicit')),
  status   text not null check (status in ('visible','pending','hidden')),
  moderated_by text references users(id),
  added_at timestamptz not null default now(),
  primary key (event_id, post_id)
);
create index ix_event_posts_timeline on event_posts (event_id, status, added_at desc);
```

### 2.7 Huy hiệu, gợi ý, vận hành

```sql
create table badge_definitions (
  id text primary key, name_vi text not null, description_vi text not null, icon_key text not null,
  source text not null check (source in ('review','system')),
  audience text not null check (audience in ('photographer','customer','both')),
  rule jsonb not null,                              -- {metric, op, threshold, minSample?}
  sort_order int not null default 0, active boolean not null default true
);
create table user_badges (
  user_id text not null references users(id) on delete cascade,
  badge_id text not null references badge_definitions(id),
  awarded_at timestamptz not null default now(), snapshot jsonb,
  primary key (user_id, badge_id)
);
create table badge_progress (                      -- 🔒
  user_id text not null references users(id) on delete cascade,
  badge_id text not null references badge_definitions(id),
  current int not null, target int not null, updated_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

create table recommendation_logs (
  id text primary key, request_id text not null, user_key text not null,
  signal_type text not null check (signal_type in ('impression','click','inquiry','booking')),
  photographer_id text not null, rank smallint, algorithm text not null, algorithm_version text not null,
  at timestamptz not null default now()
);
create index ix_reco_request on recommendation_logs (request_id);

create table contact_access_log (
  id text primary key, requester_id text not null references users(id),
  subject_type text not null, subject_id text not null,
  channel text not null check (channel in ('in_app','call','zalo','whatsapp')),
  granted boolean not null, at timestamptz not null default now()
);
create table audit_log (
  id text primary key, actor_id text references users(id), action text not null,
  entity_type text not null, entity_id text not null, diff jsonb, at timestamptz not null default now()
);
create table app_config (key text primary key, value jsonb not null, version int not null default 1, updated_at timestamptz not null default now());
```

### 2.8 Chụp ngay (schema `dispatch`)

Đặc tả ở [`../2026-10-01-instant-booking-design.md`](../2026-10-01-instant-booking-design.md) mục 7. Vị trí "đang sẵn sàng" chỉ nằm trong Redis (TTL 10 phút), không có bảng.

```sql
create schema if not exists dispatch;
create extension if not exists postgis;

create table dispatch.cities (
  id          text primary key,
  name        text not null,
  boundary    geography(Polygon, 4326) not null,
  surge       numeric(3,2) not null default 1.00 check (surge >= 1.00 and surge <= 3.00),
  active      boolean not null default false
);

create table dispatch.instant_packages (
  id                 text primary key,           -- ULID
  code               text not null,              -- 'p30' | 'p60' | 'p120'
  duration_min       integer not null check (duration_min > 0),
  photos             integer not null check (photos >= 0),
  price_vnd          bigint not null check (price_vnd > 0),
  price_list_version integer not null,
  active             boolean not null default true,
  unique (code, price_list_version)
);

create table dispatch.instant_requests (
  id              text primary key,
  customer_id     text not null references users(id),
  package_id      text not null references dispatch.instant_packages(id),
  city_id         text not null references dispatch.cities(id),
  genre           text not null,
  meet_point      geography(Point, 4326) not null,
  meet_address    text not null,
  note            text check (char_length(note) <= 140),
  expand          boolean not null default false,
  amount_vnd      bigint not null check (amount_vnd > 0),
  payout_vnd      bigint not null check (payout_vnd >= 0 and payout_vnd <= amount_vnd),
  status          text not null check (status in ('pending_payment','payment_failed','searching','assigned','en_route','arrived','in_progress','completed','no_match','cancelled_by_customer','no_show_customer','disputed')),
  photographer_id text references photographers(id),
  round           smallint not null default 1 check (round in (1,2)),
  requested_at    timestamptz not null,
  assigned_at     timestamptz,
  arrived_at      timestamptz,
  started_at      timestamptz,
  finished_at     timestamptz,
  completed_at    timestamptz,
  cancelled_at    timestamptz,
  cancel_reason   text,
  version         integer not null default 0
);
create index instant_requests_status_city on dispatch.instant_requests (status, city_id);
create index instant_requests_meet_point on dispatch.instant_requests using gist (meet_point);
-- One open job per photographer.
create unique index instant_requests_one_open_job on dispatch.instant_requests (photographer_id)
  where status in ('assigned','en_route','arrived','in_progress');

create table dispatch.instant_offers (
  id              text primary key,
  request_id      text not null references dispatch.instant_requests(id),
  photographer_id text not null references photographers(id),
  round           smallint not null check (round in (1,2)),
  score           numeric(5,4) not null,
  reasons         jsonb not null default '[]',
  offered_at      timestamptz not null,
  expires_at      timestamptz not null,
  outcome         text not null check (outcome in ('pending','accepted','declined','expired','withdrawn')),
  decided_at      timestamptz,
  unique (request_id, photographer_id)
);
create index instant_offers_request on dispatch.instant_offers (request_id);
create index instant_offers_photographer_outcome on dispatch.instant_offers (photographer_id, outcome);

create table dispatch.photographer_instant_settings (
  photographer_id            text primary key references photographers(id),
  price_list_version_accepted integer,
  help_ready                 boolean not null default false,
  home_city_id               text references dispatch.cities(id),
  updated_at                 timestamptz not null
);

create table dispatch.photographer_reliability (
  photographer_id text primary key references photographers(id),
  offers          integer not null default 0,
  accepted        integer not null default 0,
  cancelled       integer not null default 0,
  no_show         integer not null default 0,
  updated_at      timestamptz not null
);
```

Tiền của chụp ngay đi qua `payments` và sổ cái (mục 2.4) với `subject_type = 'instant_request'`.

## 3. Ánh xạ Firestore → bảng

Quy tắc chung: tên trường `camelCase` ↔ cột `snake_case`; `Timestamp` → `timestamptz`; `GeoPoint` → `lat`+`lng`; mảng → bảng liên kết; tài liệu con (`map`) → cột phẳng có tiền tố; số đếm ghi bởi Functions → cột dẫn xuất.

| Đường dẫn Firestore | Bảng | Ghi chú ánh xạ |
|---------------------|------|----------------|
| `users/{uid}` | `users` | `displayName`→`display_name`, `avatarUrl`→`avatar_file_id` (tạo `files`); `fcmTokens[]`→`devices` |
| `users/{uid}/private/contact` | `user_contacts` | Số điện thoại khách |
| `photographers/{uid}` | `photographers` + `photographer_contact_channels` | `stats.*`→cột dẫn xuất; `serviceArea.*`→`service_*`; `skills.completeness`→`skills_completeness` |
| `photographers/{uid}/private/contact` | `photographer_contact_numbers` | |
| `photographers/{uid}.skills.specialties[]` | `photographer_specialties`, `photographer_specialty_evidence` | `evidencePostIds[]` → bảng bằng chứng |
| `photographers/{uid}.skills.{styles,extras,languages,audiences}[]` | `photographer_skill_tags` | `grp` = nhóm |
| `photographers/{uid}/services/{id}` | `services` | `deliverables.*`→`photo_count`, `edited_count`, `delivery_days` |
| `availability/{uid}/days/{yyyy-mm-dd}` | `availability_days` | Id tài liệu = cột `day` |
| `posts/{id}` | `posts` + `post_images` + `post_hashtags` | `imageUrls[]`→`post_images`/`files`; hashtag trích từ `caption` |
| `likes/{uid}_{postId}`, `saves/…`, `follows/{uid}_{photographerId}` | `likes`, `saves`, `follows` | Khoá ghép thay id ghép chuỗi |
| `bookings/{id}` | `bookings` + `booking_events` + `booking_contacts` | `service.*`→`service_*`; `deposit.*`→`deposit_*`; `cancel.*`→`cancelled_*`; `timeline[]`→`booking_events`; `customerContact`→`booking_contacts` |
| `payments/{id}` | `payments`, `refunds`, `ledger_entries` | `raw`→`jsonb`; thêm cột escrow; bút toán sinh từ lịch sử |
| `reviews/{bookingId}` | `reviews` | |
| `chats/{id}` + `chats/{id}/messages/{id}` | `chats`, `chat_members`, `messages`, `chat_pins` | `members[]`→`chat_members`; `unread{}`→`chat_members.unread_count`; `lastMessage`→cột |
| `notifications/{uid}/items/{id}` | `notifications` | |
| `events/{id}` | `events` | `location.*`→cột phẳng; `host.*`, `createdBy*` |
| `events/{id}/registrations/{id}` | `event_registrations` | `phone` 🔒 |
| *(mới)* `events/{id}/posts/{postId}` | `event_posts` | Liên kết timeline |
| `badges/{id}`, `users/{uid}/badges/{id}`, `users/{uid}/private/badgeProgress` | `badge_definitions`, `user_badges`, `badge_progress` | |
| `taxonomy/skills/items/{id}`, `taxonomy/areas/…` | `taxonomy_items` | |
| `payoutAccounts/{uid}`, `payouts/{id}` | `payout_accounts`, `payouts`, `payout_items` | Số tài khoản mã hoá |
| `recommendation_logs/{id}` | `recommendation_logs` | |
| `config/{key}` | `app_config` | |
| Custom claims (`role`, `staffRole`) | `users.role`, `users.staff_role` | Bảng là nguồn sự thật; claim chỉ là bản sao trong token |

**Ngoại lệ đặt tên** (không tự động): `fcmTokens`→bảng `devices`; `imageUrls`→`post_images`; `members`→`chat_members`; `timeline`→`booking_events`; `unread`→`chat_members.unread_count`.

## 4. Dẫn xuất và đếm

| Giá trị | Nguồn sự thật | Cách giữ |
|---------|---------------|----------|
| `posts.like_count`, `save_count` | `likes`, `saves` | Use case/trigger cập nhật; có job đối soát hằng đêm |
| `photographers.rating_avg`, `review_count`, `completed_count` | `reviews`, `bookings` | `submit_review`, `transition_booking` |
| `photographers.starting_price` | `min(services.price) where active` | `onPhotographerWrite` |
| `photographers.next_free_date` | `availability_days`, `bookings` | Cron mỗi giờ |
| `photographers.skills_completeness` | kỹ năng đã khai | `onPhotographerWrite` |
| `events.registered_count`, `held_count` | `event_registrations` | `register_event` trong giao dịch; đối soát khi `release_expired_holds` |
| `chats.last_message_*`, `chat_members.unread_count` | `messages` | Trigger tin mới |
| Số dư treo/chờ chi trả | `ledger_entries` | Truy vấn tổng; không lưu cột số dư riêng |

## 5. Thứ tự xuất/nhập (phụ thuộc khoá ngoại)

`files` (không `owner_user_id`) → `users` → cập nhật `files.owner_user_id` → `taxonomy_items` → `photographers` và bảng con → `services` → `badge_definitions` → `posts`(+`post_images`, `post_hashtags`) → `bookings`(+con) → `chats` → cập nhật `bookings.chat_id` → `payments`, `refunds`, `payout_accounts`, `payouts`, `payout_items`, `ledger_entries` → `reviews` → `events` → `event_registrations`, `event_posts` → `availability_days` → `messages`, `chat_members`, `chat_pins` → `likes/saves/follows` → `notifications`, `user_badges`, `badge_progress` → `recommendation_logs`, `audit_log`.

Công cụ `tools/export` xuất mỗi bảng thành NDJSON `<bảng>.ndjson` (một đối tượng/dòng, khoá `snake_case`, thời điểm ISO‑8601 UTC, tiền số nguyên) kèm `manifest.json` (số dòng, SHA‑256 từng tệp, phiên bản lược đồ). Nhập kiểm tra khoá ngoại theo thứ tự trên và so khớp số dòng/checksum.

## 6. Dữ liệu mồi (seed)

`taxonomy_items`: thể loại (portrait, wedding, couple, family, graduation, event, product, travel, fashion, food, real_estate, newborn, street, commercial), phong cách (natural_light, film, minimal, editorial, documentary), kỹ năng thêm (retouch, posing, video, drone, studio, kids, pets, low_light, outdoor), ngôn ngữ (vi, en, zh, ko, ja), đối tượng (couple, family_kids, business, foreigner, shy_subjects), khu vực (tỉnh/thành, quận/huyện). `badge_definitions` khởi đầu theo spec chính 3d.2. `app_config`: trọng số `rules-v1`, `dispute_window_hours = 24`, hạn giữ chỗ 10 phút, số tin hỏi trước 3, ngày đóng chat 14.

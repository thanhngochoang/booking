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
  account_status text check (account_status in ('active','deletion_pending')), -- #205
  restore_until timestamptz,                     -- #205: hạn khôi phục 30 ngày khi deletion_pending
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

create table account_deletions (                  -- 🔒 #205 chỉ server đọc/ghi; Firestore: account_deletions/{uid}
  uid          text primary key references users(id) on delete cascade,
  status       text not null check (status in ('pending','restored','purging','done','blocked')),
  requested_at timestamptz not null default now(),
  restore_until timestamptz not null,             -- requested_at + 30 days
  done         text[] not null default '{}',      -- các bước purge đã chạy xong (idempotent)
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index ix_account_deletions_due on account_deletions (status, restore_until);
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
  hidden_from_discovery boolean not null default false, -- #205 (S22.03) ẩn khỏi gợi ý và tìm kiếm
  deletion_pending     boolean not null default false, -- #205 khoá khi tài khoản chờ xoá
  -- dẫn xuất (use case ghi)
  -- 2026-10-06: rating_avg thay bằng các cột cà chua/gạch (migration 1791676800001_tomato_brick.sql, #130)
  tomato_count         int not null default 0,
  brick_count          int not null default 0,
  signed_sum           numeric(8,2) not null default 0,
  tomato_pct           smallint not null default 0 check (tomato_pct between 0 and 100),
  score                numeric(4,3) not null default 0 check (score between -1 and 1),
  review_count         int not null default 0,
  completed_count      int not null default 0,
  response_minutes_median int,
  starting_price       bigint,
  next_free_date       date,
  skills_completeness  smallint not null default 0 check (skills_completeness between 0 and 100),
  skills_completeness_next text check (skills_completeness_next in ('specialties', 'levels', 'evidence', 'styles', 'languages', 'audiences', 'extras')),
  skills_completeness_next_after smallint check (skills_completeness_next_after between 0 and 100),
  skills_evidence_removed_at timestamptz,
  follower_count       int not null default 0, -- dẫn xuất (trigger đếm lại, #143)
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

-- Dịch vụ đi kèm (2026-10-08): chỉ server ghi; tối đa 10 dòng active mỗi nhà cung cấp (bất biến 25).
create table service_addons (
  id           text primary key,
  provider_id  text not null references photographers(user_id) on delete cascade,
  kind         text not null check (kind in ('makeup','retouch','transport','outfit','other')),
  name         text not null check (char_length(name) between 2 and 60),
  description  text check (char_length(description) <= 200),
  price_vnd    bigint not null check (price_vnd between 10000 and 50000000),
  unit         text not null check (unit in ('per_booking','per_person','per_item')),
  max_qty      smallint not null check (max_qty between 1 and 10),
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index ix_service_addons_provider on service_addons (provider_id) where active;
-- Gói mà dịch vụ áp dụng; không có dòng nào = mọi gói (Firestore: serviceIds = []).
create table service_addon_services (
  addon_id   text not null references service_addons(id) on delete cascade,
  service_id text not null references services(id) on delete cascade,
  primary key (addon_id, service_id)
);

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

create table likes               (user_id text not null references users(id) on delete cascade, post_id text not null references posts(id) on delete cascade, created_at timestamptz not null default now(), primary key (user_id, post_id));
create table saves               (user_id text not null references users(id) on delete cascade, post_id text not null references posts(id) on delete cascade, created_at timestamptz not null default now(), primary key (user_id, post_id));
create table saved_photographers (user_id text not null references users(id) on delete cascade, photographer_id text not null references photographers(user_id) on delete cascade, created_at timestamptz not null default now(), primary key (user_id, photographer_id));
create table follows             (follower_id text not null references users(id) on delete cascade, photographer_id text not null references photographers(user_id) on delete cascade, created_at timestamptz not null default now(), primary key (follower_id, photographer_id));
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
  pickup_name      text,                          -- chỉ khi có dịch vụ transport (#190); không bao giờ ở bảng công khai
  pickup_point     jsonb,                         -- {lat, lng}
  status           text not null check (status in ('draft','requested','accepted','declined','expired','cancelled','upcoming','completed','reviewed')),
  deposit_amount   bigint not null check (deposit_amount >= 0),
  remaining_amount bigint not null check (remaining_amount >= 0),
  currency         char(3) not null default 'VND',
  deposit_provider text check (deposit_provider in ('momo','vnpay')),
  checkout         jsonb,                         -- chỉ draft: BookingCheckout do create_payment ghi (QR, hạn, mã chuyển khoản)
  payable_until    timestamptz,                   -- chỉ draft: job dọn xoá draft từ lúc này
  deposit_paid_at  timestamptz, deposit_refunded_at timestamptz,
  accept_deadline  timestamptz,
  cancelled_by     text check (cancelled_by in ('customer','photographer','system')),
  cancel_reason    text, cancelled_at timestamptz, cancel_refund_percent smallint,
  chat_id          text,                          -- fk chats (thêm sau)
  reviewed_at      timestamptz,                   -- submit_review ghi; status không đổi ('reviewed' chỉ còn là trạng thái cũ đọc được)
  version          int not null default 1,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  -- từ #129: deposit_amount = tổng, remaining_amount = 0; tổng = service_price + Σ booking_addons.amount_vnd (#190, kiểm trong use case, không còn check một bảng)
  check (remaining_amount = 0 or deposit_amount + remaining_amount >= service_price)
);

create table booking_addons (                     -- bản chụp dịch vụ đi kèm lúc đặt (#190)
  booking_id     text not null references bookings(id) on delete cascade,
  addon_id       text not null,
  kind           text not null check (kind in ('makeup','retouch','transport','outfit','other')),
  name           text not null,
  unit           text not null check (unit in ('per_booking','per_person','per_item')),
  unit_price_vnd bigint not null check (unit_price_vnd > 0),
  qty            int not null check (qty between 1 and 10),
  amount_vnd     bigint not null check (amount_vnd = unit_price_vnd * qty),
  primary key (booking_id, addon_id)
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
  subject_type    text not null check (subject_type in ('booking','event_registration','instant_request','verification_fee')),
  subject_id      text not null,
  payee_id        text references users(id),      -- nhiếp ảnh gia / chủ sự kiện nhận tiền; null = nền tảng
  provider        text not null check (provider in ('momo','vnpay')),
  method          text check (method in ('bank_qr','momo','zalopay','domestic_card','intl_card')),  -- cách khách trả; null với vé cũ
  amount          bigint not null check (amount >= 0),
  currency        char(3) not null default 'VND',
  status          text not null check (status in ('created','paid','expired','needs_review','refunded','partially_refunded')),
  transfer_code   text,                           -- 'PB XXXXXX', duy nhất trên mọi khoản có mã (ux_payments_transfer_code)
  expires_at      timestamptz,                    -- created_at + 15 phút; chuyển từ lúc này là chuyển muộn
  received_amount bigint check (received_amount >= 0),  -- tổng đã tính vào amount (thiếu thì cộng dồn)
  instructions    jsonb,                          -- PaymentInstructions cho client (QR, tài khoản, hạn)
  payer_bank_code text,                           -- #201: ngân hàng của người chuyển
  payer_bank_name text,                           -- #201: tên ngân hàng hiển thị
  payer_account_enc text,                         -- #201: số tài khoản người chuyển đã mã hoá AES-256-GCM
  payer_account_last4 text,                       -- #201: 4 số cuối tài khoản người chuyển
  payer_holder_name text,                         -- #201: tên chủ tài khoản người chuyển (in hoa, bỏ dấu)
  refunded_amount bigint check (refunded_amount >= 0),  -- #201: tổng VND đã hoàn trên payment
  escrow_status   text not null default 'held' check (escrow_status in ('held','released','paid_out','partially_refunded','refunded','disputed')),
  release_after   timestamptz,                    -- hết cửa sổ khiếu nại
  released_at     timestamptz,
  dispute_reason  text,                           -- do open_dispute ghi; không hiện cho người nhận
  disputed_at     timestamptz,
  provider_ref    text,
  raw             jsonb,                          -- phản hồi thô của cổng
  idempotency_key text not null unique,
  event_id        text,                           -- vé: sự kiện của đăng ký (FK thêm ở 2.6)
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index ix_payments_subject on payments (subject_type, subject_id);
create unique index ux_payments_transfer_code on payments (transfer_code) where transfer_code is not null;
create index ix_payments_reconcile on payments (status, created_at) where status = 'created' and method is not null;  -- job đối soát và hết hạn
create index ix_payments_event on payments (event_id, status, escrow_status) where event_id is not null;
create index ix_payments_release on payments (escrow_status, release_after) where escrow_status = 'held';

create table refunds (
  id              text primary key,                    -- khoá chống trùng gửi sang cổng
  payment_id      text not null references payments(id),
  subject_type    text not null check (subject_type in ('booking','event_registration','instant_request','verification_fee')),
  amount          bigint not null check (amount > 0),
  percent         smallint check (percent between 0 and 100),
  status          text not null check (status in ('awaiting_account','pending','done','failed')),  -- #201: awaiting_account
  method          text not null default 'gateway' check (method in ('gateway','bank_transfer')),   -- #201: bank_transfer cho bank_qr
  destination_bank_code text,                          -- #201: ngân hàng nhận hoàn
  destination_bank_name text,                          -- #201: tên ngân hàng nhận hoàn
  destination_account_enc text,                        -- #201: số tài khoản nhận hoàn mã hoá
  destination_account_last4 text,                      -- #201: 4 số cuối tài khoản nhận hoàn
  destination_holder_name text,                        -- #201: tên chủ tài khoản nhận hoàn
  destination_source text check (destination_source in ('payer','customer')), -- #201: nguồn gốc tài khoản
  confirm_by      timestamptz,                         -- #201/#141: hạn xác nhận tài khoản
  attempts        integer not null default 0,          -- #201: số lần đã gửi lệnh hoàn sang cổng/ngân hàng
  last_attempt_at timestamptz,                         -- #201: lần gửi gần nhất, dùng cho retry
  failure_reason  text,                                -- #201: mã hoặc lý do lỗi từ cổng/ngân hàng
  manual          boolean not null default false,
  from_escrow     boolean not null default true,       -- false: tiền trả lại ngay khi nhận (thừa, chuyển lần hai, trễ), chưa từng vào ký quỹ
  reason          text,                                -- vd overpaid_excess, underpaid_expired, late_transfer, extra_transfer, duplicate_verification_fee, stale_verification_fee
  provider_ref    text,                                -- giao dịch của cổng mà tiền được hoàn từ đó
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index ix_refunds_pending on refunds (status, last_attempt_at) where status = 'pending';
create index ix_refunds_awaiting on refunds (status, confirm_by) where status = 'awaiting_account';

create table payment_notifications (              -- 🔒 chỉ máy chủ; khoá chống trùng của webhook
  id          text primary key,                   -- '{provider}_{txn_id}'
  provider    text not null,
  txn_id      text not null,                      -- mã giao dịch của tổ chức trung gian
  raw         text,                               -- nội dung gốc của webhook
  received_at timestamptz not null,               -- giờ nhận tiền (UTC) do bên cổng báo
  outcome     text not null check (outcome in ('paid','paid_with_refund','partial','refunded','needs_review')),
  payment_id  text references payments(id),       -- null khi needs_review (không khớp khoản nào)
  unique (provider, txn_id)
);

create table payout_accounts (                    -- 🔒
  id                 text primary key,
  user_id            text not null references users(id) on delete cascade,
  bank_code          text not null,
  account_number_enc bytea not null,              -- mã hoá ở tầng ứng dụng/KMS
  account_last4      char(4) not null,
  holder_name        text not null,
  name_status        text not null default 'matched' check (name_status in ('matched','pending_review','staff_confirmed')),
  active_from        timestamptz not null default now(),   -- đổi tài khoản: now() + 72 giờ; không chi trước thời điểm này
  active             boolean not null default true,
  created_at         timestamptz not null default now(),
  deactivated_at     timestamptz
);
create unique index ux_payout_accounts_active on payout_accounts (user_id) where active;

create table payouts (
  id             text primary key,
  payee_id       text not null references users(id),
  account_id     text not null references payout_accounts(id),
  amount         bigint not null check (amount > 0),     -- tổng gộp của các khoản
  platform_fee   bigint not null default 0 check (platform_fee >= 0),   -- hoa hồng (mặc định 0)
  tax_withheld   bigint not null default 0 check (tax_withheld >= 0),   -- thuế khấu trừ (thợ cá nhân)
  amount_net     bigint not null check (amount_net >= 0 and amount_net = amount - platform_fee - tax_withheld),   -- số chuyển thật
  fee_rate_bp    int not null default 0,           -- tỉ lệ đã dùng (basis point), ghi lại để lịch sử không đổi
  tax_rate_bp    int not null default 0,
  first_payout   boolean not null default false,   -- chưa có lô nào của tài khoản đã chi hoặc đã duyệt
  currency       char(3) not null default 'VND',
  status         text not null check (status in ('pending','needs_approval','on_hold','processing','paid','failed')),
  reference      text,                             -- mã giao dịch ngân hàng
  idempotency_key text,                            -- = id lô
  provider       text,                             -- 'fake' tới khi có tổ chức trung gian
  approved_by    text references users(id),
  approved_at    timestamptz,
  failure_reason text,
  hold_reason    text,
  created_by     text references users(id),        -- nhân viên tạo lô; job tự động ghi null (Firestore: 'system:createPayouts')
  created_at     timestamptz not null default now(),
  scheduled_at   timestamptz, paid_at timestamptz
);
create index ix_payouts_account_history on payouts (account_id, status, created_at desc);   -- 'đã có lô đã chi/đã duyệt tới tài khoản này' và '3 lô xong gần nhất' (limit 1 và 3); Firestore: hai chỉ mục ghép của `payouts`
create table payout_items (
  payout_id  text not null references payouts(id) on delete cascade,
  payment_id text not null references payments(id),
  amount     bigint not null check (amount > 0),
  fee        bigint not null default 0,            -- phí và thuế tính trên từng khoản: round(amount × bp / 10000)
  tax        bigint not null default 0,
  net        bigint not null,                      -- amount − fee − tax
  primary key (payout_id, payment_id)
);

create table ledger_entries (                     -- bất biến, chỉ thêm
  id              text primary key,
  type            text not null check (type in ('payment_received','deposit_received','ticket_received','refund_issued','escrow_released','payout_paid','tax_withheld','platform_fee','fee_charged','adjustment')),
  payment_id      text references payments(id),
  refund_id       text references refunds(id),
  payout_id       text references payouts(id),
  account_owner_id text references users(id),      -- người được ghi có (nhiếp ảnh gia) hoặc null = nền tảng
  amount          bigint not null,                 -- có dấu: fee_charged dương (doanh thu nền tảng), platform_fee âm (hoa hồng trừ khỏi tiền chi cho thợ)
  currency        char(3) not null default 'VND',
  note            text,
  at              timestamptz not null default now()
);
create index ix_ledger_payment on ledger_entries (payment_id, at);
create index ix_ledger_owner on ledger_entries (account_owner_id, at);

create table otp_challenges (                      -- 🔒 chỉ máy chủ; mã xác nhận khi đổi tài khoản nhận tiền
  user_id      text not null references users(id) on delete cascade,
  purpose      text not null check (purpose in ('payout_account')),
  code_hash    text not null,                      -- băm có muối; không lưu mã, không lưu số tài khoản
  salt         text not null,
  target_hash  text not null,                      -- băm có muối của 'salt:bankCode:số' của tài khoản mới sắp lưu; mã chỉ dùng cho tài khoản đó
  expires_at   timestamptz not null,               -- gửi + 5 phút
  attempts     int not null default 0,             -- sai 5 lần thì phải gửi lại
  sent_at      timestamptz not null,               -- gửi lại sau 60 giây
  send_day     date not null,                      -- ngày giờ Việt Nam
  sends_today  int not null default 0,             -- tối đa 5 mỗi ngày
  consumed_at  timestamptz,                        -- dùng một lần
  primary key (user_id, purpose)
);
create table payout_lookups (                      -- 🔒 hạn mức tra tên chủ tài khoản: 20 lần mỗi ngày giờ Việt Nam
  user_id text primary key references users(id) on delete cascade,
  day     date not null,
  count   int not null default 0
);

create table reviews (
  booking_id      text not null references bookings(id),
  subject_type    text not null default 'photographer' check (subject_type in ('photographer','studio')),
  subject_id      text not null references users(id),
  customer_id     text not null references users(id),
  photographer_id text not null references photographers(user_id), -- = subject_id; khoá truy vấn tab Đánh giá
  service_id      text references services(id),
  service_name    text not null,          -- ảnh chụp của gói
  booking_day     date not null,          -- ảnh chụp của booking
  verdict         text not null check (verdict in ('tomato','brick')),
  hits            smallint not null check (hits between 1 and 10),
  intensity       numeric(3,2) not null,
  reasons         text[] not null default '{}'
                  check ((verdict = 'brick') = (cardinality(reasons) > 0)),
  text            text not null,
  photo_post_id   text references posts(id),
  created_at      timestamptz not null default now(),
  counted_at      timestamptz,
  deleted_at      timestamptz,
  primary key (booking_id, subject_type)
);
-- Bảng này chưa có trong services/api: migration 1791676800001_tomato_brick.sql chỉ đổi cột của photographers.
-- Bảng reviews do lát cắt thêm posts tạo (Phase 2, #90); khoá (booking_id, subject_type) khớp reviewDocId.
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
  blocked_at           timestamptz,                -- khi hai bên đã chặn nhau (#144)
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

create table support_threads (
  id              text primary key,                   -- 'help_{uid}' hoặc 'dispute_{id}'
  kind            text not null check (kind in ('help', 'dispute')),
  owner_id        text not null references users(id) on delete cascade,
  status          text not null default 'open' check (status in ('open', 'closed')),
  dispute_id      text,
  awaiting_staff  boolean not null default false,
  last_message    jsonb,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index ix_support_threads_owner on support_threads (owner_id, updated_at desc);

create table support_thread_participants (
  thread_id text not null references support_threads(id) on delete cascade,
  user_id   text not null references users(id) on delete cascade,
  primary key (thread_id, user_id)
);

create table support_messages (
  id          text primary key,
  thread_id   text not null references support_threads(id) on delete cascade,
  sender_id   text not null references users(id),
  sender_role text not null check (sender_role in ('user', 'staff')),
  sender_name text not null,
  body        text not null,
  created_at  timestamptz not null default now()
);
create index ix_support_messages_thread on support_messages (thread_id, created_at asc);

create table notifications (
  id         text primary key,                   -- 'n_{dedupeKey}' hoặc 'g_{groupKey}' (dòng gom)
  user_id    text not null references users(id) on delete cascade,
  type       text not null,
  tab        text not null check (tab in ('activity','events','system')),
  category   text not null check (category in ('booking','jobs','instant','events','chat','badges','promo')),
  title      text not null, body text not null,
  target     text not null,                      -- đường dẫn app, ví dụ '/b/01J…'
  group_key  text,
  actors     jsonb not null default '[]',        -- ≤ 3 {id, name, avatarUrl}
  count      int  not null default 1,
  thumb_url  text,
  last_event_id text,
  recent_event_ids text[] not null default '{}',  -- dòng gộp: 20 mã sự kiện gần nhất, mới nhất trước (trùng = bản trùng)
  booking_id text, post_id text, event_id text,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index ix_notifications_user on notifications (user_id, created_at desc);
create index ix_notifications_tab  on notifications (user_id, tab, created_at desc);

create table notification_prefs (                  -- 🔒 một dòng mỗi người dùng
  user_id text primary key references users(id) on delete cascade,
  channels jsonb not null,                         -- {booking:{push,inApp}, jobs:…, instant:…, events:…, chat:…, badges:…, promo:…}
  quiet_enabled boolean not null default true,
  quiet_from text not null default '22:00', quiet_to text not null default '07:00',
  reminder_24h boolean not null default true, reminder_2h boolean not null default true
);
-- Số chưa đọc là count(*) where read_at is null, không có cột riêng; Firestore giữ users/{uid}/private/inbox.
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
  host_consent  text not null default 'not_required' check (host_consent in ('not_required','pending','accepted','declined','expired')),
  host_consent_expires_at timestamptz,            -- O1: lúc mời + 24 giờ
  soon_notice_at timestamptz null,                -- S17 event_soon: đặt khi đã nhắc mọi vé paid (48 giờ trước starts_at); null = chưa nhắc
  soon_notified_reg_ids text[] not null default '{}', -- S17: vé đã nhắc khi lượt nhắc còn dở (thử lại bỏ qua); xoá khi đặt soon_notice_at
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
  faq           jsonb not null default '[]',      -- O2: [{question, answer}], ≤ 10; chỉ sự kiện platform
  version       int not null default 1,
  created_at    timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (host_type <> 'photographer' or host_photographer_id is not null),
  check (registered_count + held_count <= capacity)
);
create index ix_events_listing on events (status, starts_at);
create index ix_events_soon on events (starts_at) where soon_notice_at is null and status in ('open','full','closed');   -- job nhắc event_soon (Firestore: status, soonNoticeAt, startAt)
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
  contact_eligible boolean not null default false, -- O3: true chỉ với vé trả tiền đã paid
  refund_due      boolean not null default false,  -- sự kiện huỷ khi tiền vé còn treo
  refund_id       text,                            -- FK refunds(id), thêm sau khi tạo bảng refunds
  refund_status   text check (refund_status in ('pending','done','failed')),
  version         int not null default 1,
  created_at      timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index ix_event_regs_event on event_registrations (event_id, status);
create index ix_event_regs_user on event_registrations (user_id, status);
create unique index ux_event_regs_active on event_registrations (event_id, user_id) where status in ('held','paid');
create index ix_event_regs_refund_due on event_registrations (refund_due) where refund_due;
alter table event_registrations add constraint fk_event_regs_refund foreign key (refund_id) references refunds(id);
alter table payments add constraint fk_payments_event foreign key (event_id) references events(id);

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

### 2.9 Loại nhà cung cấp, album, giải thưởng, hợp đồng và Đăng việc (2026-10-05)

Theo `domain-model.md` mục 2.8. Bảng của phần hợp đồng (`booking_milestones`, `booking_deliveries`, cột mới của `bookings`) là đề xuất, chỉ tạo khi chốt.

```sql
alter table photographers
  add column provider_type text not null default 'individual' check (provider_type in ('individual','artist','studio')),
  add column artist_since  timestamptz,
  add column studio_district text,   -- công khai, sao từ studio_addresses.district (chỉ server ghi)
  add column studio_city     text,   -- công khai, sao từ studio_addresses.city (chỉ server ghi)
  add column approved_award_count int not null default 0,
  add column accepting_orders boolean not null default false;   -- dẫn xuất = verified and onboarding_complete (chỉ server ghi, #133)
create table studio_addresses (
  photographer_id text primary key references photographers(user_id) on delete cascade,
  line text not null, ward text, district text not null, city text not null, lat double precision, lng double precision,
  updated_at timestamptz not null default now()   -- trigger set_updated_at như các bảng khác
);

create table awards (
  id              text primary key,
  photographer_id text not null references photographers(user_id) on delete cascade,
  competition     text not null,
  year            smallint not null check (year between 1950 and 2100),
  category        text,
  result          text not null check (result in ('gold','silver','bronze','honorable','finalist','exhibited')),
  work_post_id    text references posts(id) on delete set null,
  status          text not null default 'pending' check (status in ('pending','needs_info','approved','rejected','revoked')),
  review_note     text,
  reviewed_by     text references users(id),
  reviewed_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index ix_awards_photographer on awards (photographer_id, status);
create table award_proofs (
  award_id    text primary key references awards(id) on delete cascade,
  links       text[] not null default '{}',
  purge_after timestamptz
);
create table award_proof_files (
  award_id text not null references award_proofs(award_id) on delete cascade,
  position smallint not null,
  file_id  text not null references files(id),
  primary key (award_id, position)
);

create table albums (
  id              text primary key,
  photographer_id text not null references photographers(user_id) on delete cascade,
  title           text not null check (char_length(title) between 1 and 40),
  description     text check (char_length(description) <= 300),
  cover_post_id   text,                      -- fk posts, đặt sau khi tạo posts.album_id
  cover_position  smallint,
  position        int not null,
  post_count      int not null default 0,
  media_count     int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (photographer_id, position) deferrable initially deferred
);
create unique index ux_albums_title on albums (photographer_id, lower(title));
alter table posts
  add column album_id       text references albums(id) on delete set null,
  add column album_position int,
  add constraint ck_posts_album check ((album_id is null) = (album_position is null));
create unique index ux_posts_album_position on posts (album_id, album_position) where album_id is not null and deleted_at is null;
alter table albums add constraint fk_albums_cover foreign key (cover_post_id) references posts(id) on delete set null;
alter table services add column revisions smallint not null default 1 check (revisions between 0 and 5);
-- Khi bật video: post_images → post_media (kind text check (kind in ('image','video')), duration_ms int, poster_file_id text references files(id)).

create table jobs (
  id                text primary key,
  customer_id       text not null references users(id),
  specialty_id      text not null references taxonomy_items(id),
  title             text not null check (char_length(title) between 10 and 60),
  description       text not null default '' check (char_length(description) <= 1000),
  schedule_kind     text not null check (schedule_kind in ('fixed','flexible')),
  day date, start_time time, end_time time, from_day date, to_day date,
  duration_minutes  int not null check (duration_minutes > 0),
  city text not null, district text not null, geohash text not null,
  budget_min        bigint check (budget_min > 0),
  budget_max        bigint check (budget_max >= budget_min),
  wants_edited_count int, wants_delivery_days int,
  allowed_providers text not null default 'all' check (allowed_providers in ('all','artist','studio')),
  quote_deadline    timestamptz not null,
  extended          boolean not null default false,
  status            text not null default 'draft' check (status in ('draft','open','awarded','expired','closed')),
  quote_count       int not null default 0,
  view_count        int not null default 0,
  awarded_quote_id  text,                    -- fk quotes, đặt sau
  booking_id        text references bookings(id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check ((schedule_kind = 'fixed' and day is not null) or (schedule_kind = 'flexible' and from_day is not null and to_day is not null))
);
create index ix_jobs_open on jobs (status, geohash, quote_deadline) where status = 'open';
create index ix_jobs_customer on jobs (customer_id, created_at desc);
create table job_references (
  job_id   text not null references jobs(id) on delete cascade,
  position smallint not null,
  file_id  text not null references files(id),
  primary key (job_id, position)
);
create table quotes (
  id                  text primary key,
  job_id              text not null references jobs(id) on delete cascade,
  photographer_id     text not null references photographers(user_id),
  based_on_service_id text references services(id) on delete set null,
  price               bigint not null check (price > 0),
  duration_minutes    int not null,
  photo_count         int not null default 0,
  edited_count        int not null,
  delivery_days       int not null check (delivery_days between 1 and 60),
  revisions           smallint not null check (revisions between 0 and 5),
  milestones          jsonb not null,           -- [{kind, percent}], tổng 100
  message             text not null check (char_length(message) between 20 and 500),
  album_id            text references albums(id) on delete set null,
  status              text not null default 'submitted' check (status in ('submitted','withdrawn','accepted','not_selected','declined')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (job_id, photographer_id)
);
alter table jobs add constraint fk_jobs_awarded_quote foreign key (awarded_quote_id) references quotes(id);
create table job_invites (
  job_id          text not null references jobs(id) on delete cascade,
  photographer_id text not null references photographers(user_id) on delete cascade,
  created_at      timestamptz not null default now(),
  seen_at         timestamptz,
  primary key (job_id, photographer_id)
);

-- Hợp đồng (đề xuất)
alter table bookings
  add column source          text not null default 'package' check (source in ('package','quote','instant','spot','spot_slot')),
  add column terms           jsonb,              -- BookingTerms; null với booking cũ (đọc service_snapshot)
  add column job_id          text references jobs(id),
  add column quote_id        text references quotes(id),
  add column revisions_used  smallint not null default 0,
  add column shot_at timestamptz, add column delivered_at timestamptz, add column approved_at timestamptz, add column auto_approve_at timestamptz;
create table booking_milestones (
  booking_id    text not null references bookings(id) on delete cascade,
  kind          text not null check (kind in ('shoot','delivery')),
  amount        bigint not null check (amount >= 0),
  status        text not null default 'held' check (status in ('held','released','refunded','disputed')),
  payout_id     text references payouts(id),      -- gán khi giải ngân / vào lô chi trả (#152)
  release_after timestamptz,
  released_at   timestamptz,
  primary key (booking_id, kind)
);
-- Bàn giao hai lớp (#152): booking_deliveries công khai cho cả hai bên (chỉ chứa samples đã đóng watermark),
-- link bộ ảnh gốc bảo mật nằm riêng ở booking_delivery_links và chỉ mở khi approved.
create table booking_deliveries (
  id            text primary key,
  booking_id    text not null references bookings(id) on delete cascade,
  round         smallint not null,
  photo_count   int not null default 0,
  link_host     text not null,                    -- ví dụ 'drive.google.com' để app vẽ 'drive.google.com/••••••••'
  note          text,
  submitted_at  timestamptz not null default now(),
  submitted_by  text not null references users(id),
  decision      text check (decision in ('approve','request_revision')),
  decision_note text,
  decision_extra boolean default false,
  decision_auto boolean default false,
  decided_at    timestamptz,
  unique (booking_id, round)
);
create table booking_delivery_samples (
  id            text primary key,
  delivery_id   text not null references booking_deliveries(id) on delete cascade,
  position      smallint not null,
  file_id       text not null,
  path          text not null,                    -- đường dẫn ảnh watermark 1600 px
  thumb_path    text not null,                    -- đường dẫn thumbnail 400 px
  width         int not null,
  height        int not null,
  unique (delivery_id, position)
);
create table booking_delivery_links (             -- 🔒 bảo mật, mở khi booking approved
  booking_id    text primary key references bookings(id) on delete cascade,
  round         smallint not null,
  link          text not null check (link like 'https://%'),
  unlocked_at   timestamptz
);
```

### 2.10 Xác minh nhận đơn (S21, #135, 2026-10-08)

Theo `domain-model.md` mục 2.9. Chỉ là chuẩn đích: `services/api` chưa có migration cho phần này (không có route đặt lịch ở đó, giống #133).

```sql
alter table photographers
  add column business_verified boolean not null default false;   -- công khai, chỉ server ghi (con dấu Studio)

create table verifications (
  user_id        text primary key references users(id) on delete cascade,
  kind           text not null check (kind in ('individual','studio')),
  status         text not null default 'not_started'
                 check (status in ('not_started','in_progress','submitted','approved','rejected','revoked')),
  phone_done_at  timestamptz,                       -- phản chiếu user_contacts.phone_verified (bước điện thoại là cờ đó)
  fee_payment_id text references payments(id),     -- #203; payments.subject_type = 'verification_fee'; rỗng tới khi phí được ghi (và ở bản ghi gửi trước #203)
  fee_amount     bigint check (fee_amount > 0),
  fee_paid_at    timestamptz,
  identity_method text check (identity_method in ('vneid','nfc')),
  identity_checked_at timestamptz,
  identity_result text check (identity_result in ('passed','failed')),
  identity_failure text check (identity_failure in ('underage','identity_in_use','provider_failed')),
  masked_name    text,                              -- "NGUYỄN M** T**"; tên đầy đủ chỉ ở identities
  session_id     text,                              -- phiên VNeID/chip đang chờ
  session_method text check (session_method in ('vneid','nfc')),
  session_started_at timestamptz,
  attempts_day   date,                              -- ngày giờ Việt Nam của số đếm
  attempts_count smallint not null default 0 check (attempts_count between 0 and 3),   -- số lần BẮT ĐẦU xác minh trong ngày VN (kể cả bỏ dở)
  fee_attempt    smallint not null default 1,
  rules_accepted_at timestamptz,
  rules_version  text,
  submitted_at   timestamptz,
  decided_at     timestamptz,
  decided_by     text references users(id),
  reject_code    text check (reject_code in ('fake_avatar','stolen_portfolio','identity_mismatch','duplicate_account','underage','other')),
  reject_text    text,
  free_resubmits_left smallint not null default 1 check (free_resubmits_left >= 0),
  nudged_at      timestamptz,
  version        int not null default 1,
  -- nhánh doanh nghiệp (Firestore: verifications/{uid}.business)
  business_status text check (business_status in ('submitted','approved','rejected')),
  business_kind  text check (business_kind in ('company','household')),
  business_tax_code text,                           -- hộ kinh doanh: số định danh 12 số của chủ, hiện lưu dạng rõ (câu hỏi mở 9 của spec xác minh)
  business_name  text,
  business_address text,
  business_registry_status text check (business_registry_status in ('active','inactive')),
  business_doc_file_id text references files(id),   -- Storage businessDocs/{uid}/{ulid}.jpg
  business_representative_matched boolean,
  business_submitted_at timestamptz,
  business_decided_at timestamptz,
  business_decided_by text references users(id),
  business_reject_code text check (business_reject_code in ('inactive','representative_mismatch','doc_unreadable','other')),
  business_reject_text text,
  business_purge_after timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index ix_verifications_queue on verifications (status, submitted_at);                      -- hàng đợi staff; Firestore: (status, submittedAt)
create index ix_verifications_nudge on verifications (status, nudged_at, updated_at);             -- job nhắc; Firestore: (status, nudgedAt, updatedAt), nudgedAt lọc ở truy vấn để bản đã nhắc không chặn trang
create index ix_verifications_business_queue on verifications (business_status, business_submitted_at);   -- Firestore: (business.status, business.submittedAt)

create table identities (                           -- 🔒 chỉ server; Firestore: users/{uid}/private/identity
  user_id         text primary key references users(id) on delete cascade,
  legal_name      text not null,
  dob             date not null,
  gender          text check (gender in ('male','female')),
  id_number_enc   text not null,                    -- mã hoá (KMS); không bao giờ ở dạng rõ
  id_hash         text not null,                    -- HMAC có khoá bí mật
  method          text not null check (method in ('vneid','nfc')),
  provider        text not null,
  provider_ref    text not null,
  verified_at     timestamptz not null,
  created_at      timestamptz not null default now()
);
create table identity_hashes (                      -- 🔒 một số định danh một tài khoản; Firestore: identity_hashes/{idHash}
  id_hash    text primary key,
  user_id    text not null references users(id) on delete restrict,   -- giữ sau khi xoá tài khoản theo luật thuế (spec xác minh §9, cần kế toán xác nhận)
  created_at timestamptz not null default now(),
  unique (user_id)
);
create table verification_audit (                   -- 🔒 Firestore: verificationAudit/{id}
  id         text primary key,
  user_id    text not null references users(id),
  target     text not null check (target in ('identity','business')),
  action     text not null,
  reason     text,
  note       text,
  actor_id   text references users(id),
  other_user_id text references users(id),          -- tài khoản kia khi trùng danh tính
  at         timestamptz not null default now()
);
create index ix_verification_audit_user on verification_audit (user_id, at desc);
create trigger trg_verifications_updated before update on verifications for each row execute function set_updated_at();

### 2.11 Báo cáo và chặn (S20, #144)

Theo `domain-model.md` mục 2.10.

```sql
create table blocks (
  blocker_id        text not null references users(id) on delete cascade,
  blocked_id        text not null references users(id) on delete cascade,
  blocked_name      text not null default '',
  blocked_avatar_url text,
  source            text not null check (source in ('menu','report')),
  created_at        timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);
create index ix_blocks_blocker_created on blocks (blocker_id, created_at desc);

create table reports (
  id              text primary key,
  reporter_id     text not null references users(id) on delete cascade,
  target_type     text not null check (target_type in ('user','post','message','event')),
  target_id       text not null,
  chat_id         text references chats(id),
  target_owner_id text references users(id),
  reason          text not null check (reason in ('spam','scam','harassment','inappropriate','stolen_photos','impersonation','other')),
  text            text,
  blocked         boolean not null default false,
  snapshot        jsonb not null default '{}'::jsonb,
  status          text not null default 'open' check (status in ('open','dismissed','actioned')),
  staff_note      text,
  decided_by      text references users(id),
  decided_at      timestamptz,
  created_at      timestamptz not null default now()
);
create index ix_reports_status_created on reports (status, created_at);

create table report_quotas (
  user_id         text not null references users(id) on delete cascade,
  day             date not null,
  count           smallint not null default 0 check (count between 0 and 20),
  primary key (user_id, day)
);

-- Điểm chụp và lịch tại điểm (2026-10-08, #194; `domain-model.md` mục 2.11)
create table spots (
  id             text primary key,
  name           text not null,
  city           text not null,
  area_code      text not null,
  lat            double precision not null,
  lng            double precision not null,
  geohash        text not null,
  radius_m       int not null check (radius_m between 100 and 3000),
  cover_url      text,
  cover_card_url text,
  cover_path     text,
  description    text not null default '',
  tips           jsonb not null default '[]'::jsonb,
  season_months  jsonb not null default '[]'::jsonb,
  pinned         boolean not null default false,
  hidden         boolean not null default false,
  status         text not null default 'active' check (status in ('active','archived')),
  hot_score      int not null default 0,
  stats          jsonb not null default '{"posts14d":0,"events":0,"bookings14d":0,"openSchedules":0,"providersWeek":0,"providersWeekend":0}'::jsonb,
  ranked_at      timestamptz,
  updated_by     text not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table spot_schedules (
  id             text primary key,
  provider_id    text not null references photographers(user_id) on delete cascade,
  assignee_id    text references photographers(user_id) on delete cascade,
  spot_id        text not null references spots(id) on delete restrict,
  window_start   time not null,
  window_end     time not null check (window_end > window_start),
  service_ids    jsonb not null default '[]'::jsonb,
  price_from     bigint,
  status         text not null default 'open' check (status in ('open','cancelled')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table spot_schedule_days (
  schedule_id    text not null references spot_schedules(id) on delete cascade,
  day            date not null,
  primary key (schedule_id, day)
);

create table spot_slot_offers (
  id             text primary key,
  provider_id    text not null references photographers(user_id) on delete cascade,
  schedule_id    text not null references spot_schedules(id) on delete cascade,
  spot_id        text not null references spots(id) on delete restrict,
  name           text not null,
  price          bigint not null check (price >= 10000 and price <= 100000000),
  slot_minutes   smallint not null check (slot_minutes between 15 and 90),
  gap_minutes    smallint not null check (gap_minutes between 0 and 30),
  photo_count    smallint not null check (photo_count >= 1),
  edited_count   smallint not null check (edited_count >= 0 and edited_count <= photo_count),
  delivery_days  smallint not null check (delivery_days between 1 and 30),
  status         text not null default 'open' check (status in ('open','closed')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- spot_day_intervals: khoảng thời gian đã được giữ chỗ/đặt tại điểm.
-- Ghi chú: hình chiếu công khai trên Firestore (/spot_days/{id}) lược bỏ booking_id để bảo vệ quyền riêng tư.
create table spot_day_intervals (
  id             text primary key,
  schedule_id    text not null references spot_schedules(id) on delete cascade,
  day            date not null,
  start_time     time not null,
  end_time       time not null check (end_time > start_time),
  offer_id       text references spot_slot_offers(id) on delete set null,
  booking_id     text references bookings(id) on delete cascade,
  created_at     timestamptz not null default now()
);

-- Mở rộng bookings cho điểm chụp và chia suất (#194)
alter table bookings
  add column spot_id          text references spots(id),
  add column spot_schedule_id text references spot_schedules(id),
  add column slot_offer_id    text references spot_slot_offers(id),
  add column assignee_id      text references photographers(user_id),
  add column assignee_kind    text check (assignee_kind in ('solo','member')),
  add column assigned_at      timestamptz;
```

### 2.12 Studio và thành viên (S26, #136)

Theo `domain-model.md` mục 2.12. Chỉ là chuẩn đích: `services/api` chưa có migration cho phần này (không có route đặt lịch ở đó).

```sql
create table studio_members (
  studio_id            text not null references photographers(user_id),
  member_id            text not null references photographers(user_id),
  created_at           timestamptz not null default now(),
  status               text not null check (status in ('invited','requested','active','declined','cancelled','expired','left','removed')),
  initiated_by         text not null check (initiated_by in ('studio','member')),
  expires_at           timestamptz not null,
  responded_at         timestamptz,
  joined_at            timestamptz,
  ended_at             timestamptz,
  ended_by             text check (ended_by in ('member','studio','system')),
  expiring_notified_at timestamptz,
  studio_name          text not null default '',
  studio_avatar_url    text,
  member_name          text not null default '',
  member_avatar_url    text,
  version              int not null default 0,
  primary key (studio_id, member_id, created_at),
  check (studio_id <> member_id)
);
-- một thợ chỉ `active` ở một studio; một cặp chỉ có một quan hệ mở
create unique index ux_studio_members_active_member on studio_members (member_id) where status = 'active';
create unique index ux_studio_members_open_pair on studio_members (studio_id, member_id) where status in ('invited','requested','active');
create index ix_studio_members_studio_status on studio_members (studio_id, status);
create index ix_studio_members_due on studio_members (status, expires_at) where status in ('invited','requested');

alter table photographers
  add column studio_id               text references photographers(user_id),  -- công khai, chỉ server ghi
  add column studio_joined_at        timestamptz,
  add column studio_cooldown_until   timestamptz,
  add column member_count            int not null default 0,
  add column assignable_members      int,
  add column name_key                text,                                    -- tên bỏ dấu, thường, cho tìm lời mời
  add column late_assign_count       int not null default 0,                  -- bộ đếm vi phạm: server ghi, staff xem
  add column change_declined_count   int not null default 0,
  add column late_reassign_count     int not null default 0,
  add column late_delivery_count     int not null default 0;
create index ix_photographers_studio on photographers (studio_id) where studio_id is not null;

alter table bookings
  add column is_studio          boolean not null default false,
  add column assignee_id        text references photographers(user_id),
  add column assignee_kind      text check (assignee_kind in ('member')),     -- chỉ 'member' tới khi S27 thêm 'collaborator' (khi đó migration đổi check)
  add column assign_status      text check (assign_status in ('unassigned','assigned')),
  add column assign_deadline    timestamptz,
  add column assign_overdue     boolean not null default false,
  add column assigned_at        timestamptz,
  add column assign_reminders_sent text[] not null default '{}',              -- 'h48' | 'h26'
  add column change_request     jsonb,                                        -- {at, note, respondBy, status, declineReason, answeredAt}
  add column studio_fault       jsonb,                                        -- {kind, at}
  add column assignment_returned jsonb;                                       -- {at, reason}
create index ix_bookings_assignee_status on bookings (assignee_id, status) where assignee_id is not null;
create index ix_bookings_assign_sweep on bookings (assign_status, assign_overdue, status, assign_deadline) where is_studio;
create index ix_bookings_unassigned_start on bookings (assign_status, status, day) where is_studio;   -- huỷ booking chưa giao thợ tới giờ chụp (studioStartCancels); Firestore: (assignStatus, status, day)

create table booking_assignments (
  booking_id    text not null references bookings(id) on delete cascade,
  seq           smallint not null,
  assignee_id   text not null references photographers(user_id),
  assignee_kind text not null check (assignee_kind in ('member')),
  at            timestamptz not null,
  by            text not null references users(id),
  reason        text,
  late          boolean not null default false,
  primary key (booking_id, seq)
);

create table studio_quotas (
  user_id         text not null references users(id) on delete cascade,
  day             date not null,
  studio_actions  smallint not null default 0,
  member_actions  smallint not null default 0,
  primary key (user_id, day)
);

create table studio_day_load_bookings (   -- tải theo ngày của studio: mỗi dòng một booking mở
  studio_id   text not null references photographers(user_id),
  day         date not null,
  booking_id  text not null references bookings(id) on delete cascade,
  assigned    boolean not null default false,   -- false = chưa giao thợ (unassignedIds), true = đã giao (assignedIds)
  primary key (studio_id, day, booking_id)
);
-- Số thợ rảnh của ngày không lưu: tính từ availability_days của các thành viên lúc tính lại.

alter table reviews
  add column via_studio_id   text references photographers(user_id),
  add column via_studio_name text,
  add column assignee_id     text references photographers(user_id),
  add column assignee_name   text;
-- khoá (booking_id, subject_type) đã có ở bảng reviews; booking studio có hai dòng: 'photographer' (thợ) và 'studio'
```

## 3. Ánh xạ Firestore → bảng

Quy tắc chung: tên trường `camelCase` ↔ cột `snake_case`; `Timestamp` → `timestamptz`; `GeoPoint` → `lat`+`lng`; mảng → bảng liên kết; tài liệu con (`map`) → cột phẳng có tiền tố; số đếm ghi bởi Functions → cột dẫn xuất.

| Đường dẫn Firestore | Bảng | Ghi chú ánh xạ |
|---------------------|------|----------------|
| `users/{uid}` | `users` | `displayName`→`display_name`, `avatarUrl` + `avatarPath`→`avatar_file_id` (tạo `files`, `avatarPath` là khoá Storage `avatars/{uid}/{ulid}.jpg`); `fcmTokens[]`→`devices`; `accountStatus`→`account_status`; `restoreUntil`→`restore_until` |
| `users/{uid}/private/contact` | `user_contacts` | Số điện thoại khách |
| `account_deletions/{uid}` | `account_deletions` | #205 bản ghi yêu cầu xoá tài khoản; `uid` PK, `restoreUntil`→`restore_until`, `done[]`→`done text[]` |
| `verifications/{uid}` | `verifications` | `steps.*`, `identitySession.*`, `identityAttempts.*`, `rejectReason.*` → cột phẳng có tiền tố; `business.*` → cột `business_*` (cùng bảng); `steps.phone` phản chiếu `user_contacts.phone_verified`; `steps.fee` → `fee_*` (#203; khoản thanh toán là dòng `payments` có `subject_type = 'verification_fee'`) |
| `users/{uid}/private/identity` | `identities` | Chỉ server đọc/ghi; `idNumberEnc` → `id_number_enc` |
| `identity_hashes/{idHash}` | `identity_hashes` | Id tài liệu = `id_hash`; `uid` → `user_id` |
| `verificationAudit/{id}` | `verification_audit` | `actorId` → `actor_id`, `otherUid` → `other_user_id` |
| `fake_identities/{uid}` | (không có bảng) | Chỉ emulator/dev, kết quả giả của `FakeIdentityVerifier` |
| `photographers/{uid}` | `photographers` + `photographer_contact_channels` | `stats.*`→cột dẫn xuất; `serviceArea.*`→`service_*`; `skills.completeness`→`skills_completeness`; `skills.completenessNext`→`skills_completeness_next`; `skills.completenessNextAfter`→`skills_completeness_next_after`; `skills.evidenceRemovedAt`→`skills_evidence_removed_at`; `hiddenFromDiscovery`→`hidden_from_discovery`; `deletionPending`→`deletion_pending` |
| `photographers/{uid}/private/contact` | `photographer_contact_numbers` | |
| `photographers/{uid}.skills.specialties[]` | `photographer_specialties`, `photographer_specialty_evidence` | `evidencePostIds[]` → bảng bằng chứng |
| `photographers/{uid}.skills.{styles,extras,languages,audiences}[]` | `photographer_skill_tags` | `grp` = nhóm |
| `photographers/{uid}/services/{id}` | `services` | `deliverables.*`→`photo_count`, `edited_count`, `delivery_days` |
| `photographers/{uid}/addons/{id}` | `service_addons` + `service_addon_services` | `providerId` lấy từ đường dẫn; `serviceIds[]`→`service_addon_services`; `price`→`price_vnd`; khoá `photographers/{uid}/private/addons` (`activeCount`) chỉ là khoá giao dịch của Firestore, bảng dùng `select … for update` trên nhà cung cấp |
| `availability/{uid}/days/{yyyy-mm-dd}` | `availability_days` | Id tài liệu = cột `day` |
| `posts/{id}` | `posts` + `post_images` + `post_hashtags` | `imageUrls[]`→`post_images`/`files`; hashtag trích từ `caption` |
| `likes/{uid}_{postId}`, `saves/…`, `follows/{uid}_{photographerId}` | `likes`, `saves`, `follows` | Khoá ghép thay id ghép chuỗi |
| `awards/{id}`, `awardProofs/{id}` | `awards`, `award_proofs` + `award_proof_files` | `proof.files[]`→`award_proof_files` |
| `albums/{id}`; `posts/{id}.albumId/albumPosition` | `albums`; `posts.album_id`, `album_position` | `cover.{postId,position}`→`cover_post_id`, `cover_position` |
| `jobs/{id}`, `jobs/{id}/quotes/{photographerId}`, `jobs/{id}/invites/{photographerId}` | `jobs` + `job_references`, `quotes`, `job_invites` | `schedule.*`, `area.*`, `budget.*`, `wants.*` → cột phẳng; id báo giá Firestore là uid, bảng dùng `id` riêng + `unique (job_id, photographer_id)` |
| `bookings/{id}/milestones/{kind}`, `bookings/{id}/deliveries/{round}` | `booking_milestones`, `booking_deliveries` + `booking_delivery_previews` | Đề xuất (spec 10-05) |
| `bookings/{id}` + `bookings/{id}/private/contact` | `bookings` + `booking_events` + `booking_contacts` | `service.*`→`service_*`; `deposit.*`→`deposit_*`; `cancel.*`→`cancelled_*`; `timeline[]`→`booking_events`; `bookings/{id}/private/contact`→`booking_contacts` |
| `payments/{id}` | `payments`, `refunds`, `ledger_entries` | `raw`→`jsonb`; thêm cột escrow; bút toán sinh từ lịch sử; `deposit_received` cũ đổi thành `payment_received`; (đề xuất) tài khoản nền tảng của Firestore (`platform_escrow`, `platform_revenue` ở `accountOwnerId`) thành `account_owner_id` null, phân biệt bằng `type` (`fee_charged` là doanh thu) |
| `payment_notifications/{provider}_{txnId}` | `payment_notifications` | Giữ nguyên id; `raw` là chuỗi gốc của webhook |
| `studio_members/{studioId}_{memberId}_{createdAtMs}` | `studio_members` | Id ghép không thành cột: khoá `(studio_id, member_id, created_at)`; `createdAt` là phần mili giây của id |
| `studio_quota/{uid}` | `studio_quotas` | `dayKey`→`day`; `studioActions`, `memberActions`→`studio_actions`, `member_actions` |
| `studio_day_load/{id}` | `studio_day_load_bookings` | Chỉ server; id = studio + ngày; `unassignedIds[]`/`assignedIds[]`→ một dòng mỗi booking, `assigned` phân biệt hai mảng |
| `bookings/{id}.assignments[]` | `booking_assignments` | `seq` = vị trí trong mảng; `changeRequest`, `studioFault`, `assignmentReturned`→`jsonb` |
| `reviews/{reviewId}` (`reviewId = reviewDocId(bookingId, subjectType)`: `bookingId` hoặc `{bookingId}_studio`) | `reviews` | Khoá `(booking_id, subject_type)`; `reviewId` không thành cột |
| `chats/{id}` + `chats/{id}/messages/{id}` | `chats`, `chat_members`, `messages`, `chat_pins` | `members[]`→`chat_members`; `unread{}`→`chat_members.unread_count`; `lastMessage`→cột; `chats.bookingStatus`→không có cột, suy ra từ `bookings.status` qua `chats.booking_id` (join; trường Firestore chỉ là read model cho danh sách S07.02) |
| `support_threads/{id}` + `support_threads/{id}/messages/{id}` | `support_threads`, `support_thread_participants`, `support_messages` | `participants[]`→`support_thread_participants`; `lastMessage`→jsonb cột `last_message` |
| `users/{uid}/notifications/{id}` | `notifications` | `actors[]`→`actors jsonb`; `users/{uid}/private/inbox.unreadCount` không có cột (đếm `read_at is null`) |
| `users/{uid}/private/notification_prefs` | `notification_prefs` | `quietHours.*`→`quiet_*`, `reminders.*`→`reminder_*` |
| `events/{id}` | `events` | `location.*`→cột phẳng; `host.*`, `createdBy*` |
| `events/{id}/registrations/{id}` | `event_registrations` | `phone` 🔒 |
| `events/{id}/timeline/{postId}` | `event_posts` | Liên kết timeline; tên `timeline`, không phải `posts`, để không trùng id bộ sưu tập `posts` (và index của nó); `status` visible/pending/hidden, `source` hashtag/explicit; `events.postCount` chỉ đếm hàng `visible`. Nhóm chat sự kiện `chats/event_{id}` (+ `members`, `messages`, `pins/{messageId}`) → `chats` kind `event_group`, `chat_members`, `messages`, `chat_pins` |
| `badges/{id}`, `users/{uid}/badges/{id}`, `users/{uid}/private/badgeProgress` | `badge_definitions`, `user_badges`, `badge_progress` | |
| `taxonomy/skills/items/{id}`, `taxonomy/areas/…` | `taxonomy_items` | |
| `payoutAccounts/{uid}` + `accounts/{id}`, `payouts/{id}` | `payout_accounts`, `payouts`, `payout_items` | Số tài khoản mã hoá; `payoutAccounts/{uid}` là bản che (`account_last4`, `name_status`, `active_from`), không có bảng riêng. `payouts` cũ đọc phí 0, thuế 0, `amount_net = amount`; `payout_accounts` cũ đọc `name_status = 'matched'`, `active_from = created_at` |
| `otp_challenges/{uid}_payout_account`, `payout_lookups/{uid}` | `otp_challenges`, `payout_lookups` | Chỉ máy chủ; id Firestore ghép `uid` và `purpose` thành khoá `(user_id, purpose)` |
| `earnings/{uid}` + `items` | (không có bảng) | Hình chiếu tính bởi `earningsOf` (SQL tổng và join `payments`/`refunds`/`payouts`) |
| `recommendation_logs/{id}` | `recommendation_logs` | |
| `contact_access_log/{id}` | `contact_access_log` | Ghi bởi `getContactLink` (Admin SDK), id ULID; client không đọc/ghi; không chứa số điện thoại |
| `spots/{id}` | `spots` | Điểm chụp |
| `spot_rankings/{key}` | (không có bảng) | Bảng xếp hạng dẫn xuất từ `spots`, ghi định kỳ bởi job `rankSpots` |
| `spot_directory/{key}` | (không có bảng) | Danh mục điểm chụp hoạt động, ghi định kỳ bởi job `rankSpots` |
| `spot_schedules/{id}` | `spot_schedules` + `spot_schedule_days` | `days[]` → `spot_schedule_days` |
| `spot_slot_offers/{id}` | `spot_slot_offers` | Gói chia suất tại điểm |
| `spot_days/{id}` | `spot_day_intervals` | Hình chiếu công khai của các khoảng giờ đã kín trong ngày; doc id `{scheduleId}_{day}`, không lưu `booking_id` |
| `config/{key}` | `app_config` | |
| `blocks/{blockerId}_{blockedId}` | `blocks` | Id ghép `blockerId_blockedId`; `source`, `createdAt` |
| `users/{uid}/private/blocks` | (dẫn xuất từ `blocks`) | Chỉ mục hai chiều do server duy trì; không có bảng riêng (được tạo bởi query/trigger trên `blocks`) |
| `reports/{id}` | `reports` | Id báo cáo; client không đọc/ghi; staff quản lý |
| `users/{uid}/private/report_quota` | `report_quotas` | Hạn ngạch 20 báo cáo/ngày/tài khoản |
| Custom claims (`role`, `staffRole`) | `users.role`, `users.staff_role` | Bảng là nguồn sự thật; claim chỉ là bản sao trong token |

**Ngoại lệ đặt tên** (không tự động): `fcmTokens`→bảng `devices`; `imageUrls`→`post_images`; `members`→`chat_members`; `timeline`→`booking_events`; `unread`→`chat_members.unread_count`.

## 4. Dẫn xuất và đếm

| Giá trị | Nguồn sự thật | Cách giữ |
|---------|---------------|----------|
| `posts.like_count`, `save_count` | `likes`, `saves` | Use case/trigger cập nhật (`onLikeWrite`, `onSaveWrite`); có job đối soát |
| `photographers.tomato_count`, `brick_count`, `signed_sum`, `tomato_pct`, `score`, `review_count`, `completed_count` | `reviews`, `bookings` | `onReviewWrite`, `onBookingWrite` (#130, #132) |
| `photographers.starting_price` | `min(services.price) where active` | `onServiceWrite` (#132) |
| `photographers.next_free_date` | `availability_days`, `bookings` | Hướng sự kiện (`onAvailabilityWrite`) + rollover hằng ngày 00:10 (#132) |
| `explore_specialty_stats` (view) | `services` active | View `(specialty, service_count, cover_url)` phản chiếu `catalog/explore` (#132) |
| `photographers.skills_completeness` | kỹ năng đã khai | `onPhotographerWrite` |
| `events.registered_count`, `held_count` | `event_registrations` | `register_event` trong giao dịch; đối soát khi `release_expired_holds` |
| `chats.last_message_*`, `chat_members.unread_count` | `messages` | Trigger tin mới |
| Số dư treo/chờ chi trả | `ledger_entries` | Truy vấn tổng; không lưu cột số dư riêng |

## 5. Thứ tự xuất/nhập (phụ thuộc khoá ngoại)

`files` (không `owner_user_id`) → `users` → cập nhật `files.owner_user_id` → `taxonomy_items` → `spots` → `photographers` và bảng con → `services` → `spot_schedules` → `spot_schedule_days` → `spot_slot_offers` → `badge_definitions` → `posts`(+`post_images`, `post_hashtags`) → `studio_members`, `bookings`(+con, `booking_assignments`) → `spot_day_intervals` → `chats` → cập nhật `bookings.chat_id` → `payments`, `refunds`, `payment_notifications`, `payout_accounts`, `payouts`, `payout_items`, `ledger_entries` → `reviews` → `studio_quotas`, `studio_day_load_bookings` → `events` → `event_registrations`, `event_posts` → `availability_days` → `messages`, `chat_members`, `chat_pins` → `likes/saves/follows` → `notifications`, `user_badges`, `badge_progress` → `recommendation_logs`, `audit_log`.

Công cụ `tools/export` xuất mỗi bảng thành NDJSON `<bảng>.ndjson` (một đối tượng/dòng, khoá `snake_case`, thời điểm ISO‑8601 UTC, tiền số nguyên) kèm `manifest.json` (số dòng, SHA‑256 từng tệp, phiên bản lược đồ). Nhập kiểm tra khoá ngoại theo thứ tự trên và so khớp số dòng/checksum.

## 6. Dữ liệu mồi (seed)

`taxonomy_items`: thể loại (portrait, wedding, couple, family, graduation, event, product, travel, fashion, food, real_estate, newborn, street, commercial), phong cách (natural_light, film, minimal, editorial, documentary), kỹ năng thêm (retouch, posing, video, drone, studio, kids, pets, low_light, outdoor), ngôn ngữ (vi, en, zh, ko, ja), đối tượng (couple, family_kids, business, foreigner, shy_subjects), khu vực (tỉnh/thành, quận/huyện). `badge_definitions` khởi đầu theo spec chính 3d.2. `app_config`: trọng số `rules-v1`, `dispute_window_hours = 24`, hạn giữ chỗ 10 phút, số tin hỏi trước 3, ngày đóng chat 14.

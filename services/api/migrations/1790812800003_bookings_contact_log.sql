-- Up Migration
create table bookings (
  id               text primary key,
  customer_id      text not null references users(id),
  photographer_id  text not null references photographers(user_id),
  service_id       text not null references services(id),
  service_name     text not null,
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
  chat_id          text,
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

create table contact_access_log (
  id text primary key, requester_id text not null references users(id),
  subject_type text not null, subject_id text not null,
  channel text not null check (channel in ('in_app','call','zalo','whatsapp')),
  granted boolean not null, at timestamptz not null default now()
);

create trigger trg_bookings_updated_at before update on bookings
  for each row execute function set_updated_at();

-- Down Migration
drop table contact_access_log;
drop table booking_events;
drop table bookings;

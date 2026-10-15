-- Up Migration
create table taxonomy_items (
  id         text primary key,
  grp        text not null check (grp in ('specialty','style','extra','language','audience','area')),
  label_vi   text not null,
  parent_id  text references taxonomy_items(id),
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

create table photographer_contact_channels (
  photographer_id text primary key references photographers(user_id) on delete cascade,
  call_enabled     boolean not null default false,
  zalo_enabled     boolean not null default false,
  whatsapp_enabled boolean not null default false
);

create table photographer_contact_numbers (
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

create trigger trg_photographers_updated_at before update on photographers
  for each row execute function set_updated_at();
create trigger trg_services_updated_at before update on services
  for each row execute function set_updated_at();

-- Down Migration
drop table services;
drop table photographer_contact_numbers;
drop table photographer_contact_channels;
drop table photographers;
drop table taxonomy_items;

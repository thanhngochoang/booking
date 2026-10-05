-- Up Migration
-- relational-schema.md §2.9: provider type (individual / artist / studio) and the private studio address.
alter table photographers
  add column provider_type text not null default 'individual'
    check (provider_type in ('individual','artist','studio')),
  add column artist_since timestamptz,
  add column studio_district text,
  add column studio_city text,
  add column approved_award_count int not null default 0;

create table studio_addresses (
  photographer_id text primary key references photographers(user_id) on delete cascade,
  line text not null,
  ward text,
  district text not null,
  city text not null,
  lat double precision,
  lng double precision,
  updated_at timestamptz not null default now()
);

-- Down Migration
drop table studio_addresses;
alter table photographers
  drop column approved_award_count,
  drop column studio_city,
  drop column studio_district,
  drop column artist_since,
  drop column provider_type;

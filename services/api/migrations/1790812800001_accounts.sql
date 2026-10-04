-- Up Migration
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end $$ language plpgsql;

create table files (
  id               text primary key,
  owner_user_id    text,
  storage_provider text not null,
  storage_key      text not null,
  mime_type        text not null,
  size_bytes       bigint not null check (size_bytes >= 0),
  width            int, height int,
  blurhash         text,
  created_at       timestamptz not null default now(),
  unique (storage_provider, storage_key)
);

create table users (
  id           text primary key,
  display_name text not null default '',
  avatar_file_id text references files(id),
  role         text check (role in ('customer','photographer')),
  staff_role   text check (staff_role in ('admin','sales')),
  city         text,
  locale       text not null default 'vi',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz
);
alter table files add constraint fk_files_owner foreign key (owner_user_id) references users(id);

create table user_contacts (
  user_id        text primary key references users(id) on delete cascade,
  phone_e164     text not null check (phone_e164 ~ '^\+[0-9]{8,15}$'),
  phone_verified boolean not null default false,
  allow_zalo     boolean not null default true,
  allow_whatsapp boolean not null default false,
  updated_at     timestamptz not null default now()
);

create table auth_identities (
  id         text primary key,
  user_id    text not null references users(id) on delete cascade,
  provider   text not null check (provider in ('password','google','facebook','apple','oidc')),
  subject    text not null,
  email      text,
  created_at timestamptz not null default now(),
  unique (provider, subject)
);

create trigger trg_users_updated_at before update on users
  for each row execute function set_updated_at();
create trigger trg_user_contacts_updated_at before update on user_contacts
  for each row execute function set_updated_at();

-- Down Migration
drop table auth_identities;
drop table user_contacts;
alter table files drop constraint fk_files_owner;
drop table users;
drop table files;
drop function set_updated_at();

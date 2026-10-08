-- Up Migration
-- Tomato/brick reviews (#130): the star average goes; the server-computed % cà chua stats come in.
-- Mirrors photographers/{uid}.stats in Firestore (tomatoCount, brickCount, signedSum, tomatoPct, score).
alter table photographers
  drop column rating_avg,
  add column tomato_count int not null default 0,
  add column brick_count int not null default 0,
  add column signed_sum numeric(8,2) not null default 0,
  add column tomato_pct smallint not null default 0 check (tomato_pct between 0 and 100),
  add column score numeric(4,3) not null default 0 check (score between -1 and 1);

-- Down Migration
alter table photographers
  drop column score,
  drop column tomato_pct,
  drop column signed_sum,
  drop column brick_count,
  drop column tomato_count,
  add column rating_avg numeric(3,2) not null default 0;

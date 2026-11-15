# Studio listings U1 (schema, normalisation, dedupe, import tool) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** booking-be can take studio records from a staff file and from OpenStreetMap, normalise them into one shape, merge duplicates into `studio_listings` rows and let staff review and publish them from the command line.

**Architecture:** Five separate stages: collect → normalise → merge → review → publish. Raw records are stored verbatim (`listing_source_records`) so the rules can be re-run without collecting again. Every rule (text folding, phone and URL normalisation, "is this a photo studio", specialty mapping, area lookup, duplicate matching, field merge, quality score) is a pure function in `packages/domain`. `tools/studio-listings/` in booking-be holds the source adapters, the Kysely store and a thin CLI, following `tools/firestore-import/`.

**Tech Stack:** TypeScript (ESM, Node 24), PostgreSQL 16 + Kysely, node-pg-migrate SQL migrations, `node --test` in `packages/domain`, Vitest in the API (`tools/**/*.test.ts` is already in `vitest.config.ts`). No new runtime dependency.

**Spec:** `docs/superpowers/specs/2026-11-14-studio-listings-design.md` (app repository `thanhngochoang/booking`), §4, §5.1–§5.5. This plan implements unit U1 of §9 only. **Issue:** thanhngochoang/booking-be#7. **Repo:** all code changes are in `thanhngochoang/booking-be`; branch `feat/7-studio-listings-u1` from `origin/develop` (not `plan/7-…`: `project.py` and `land.py` read the number in a `plan/<n>-…` branch as an issue of the app repository, and this issue lives in booking-be; merge the PR with `gh pr merge --squash` once CI is green), PR titled `feat(listings): studio listings schema, normalisation, dedupe and import tool [#7]`.

## Global Constraints

- Business rules live in `packages/domain` with no Firebase or Node imports and no runtime dependency (`eslint.config.js`, `test/purity.test.ts`). The tool and the API import the domain only through `src/domain/index.ts`.
- Ids are ULIDs from `newId()` (`src/ids.ts`); instants are UTC `timestamptz`; enum values are `snake_case` string codes with a `CHECK`; coordinates are `lat`/`lng` `double precision` plus `geohash` of length 9 (`encodeGeohash` already exists in `packages/domain/src/event.ts`).
- Only facts are stored: name, address, coordinates, contact, website, specialties. No images, descriptions, reviews or ratings from a source (spec L9).
- A collected phone number never appears in a log line, an error message, a report printed by the CLI or a test assertion message (spec §3). Reports print counts and ids. The review CSV is the one place staff see numbers.
- Staff edits (`overrides`) always win over source data, and a listing hidden with `hidden_reason = 'removal_request'` or with `status = 'claimed'` is never recreated or republished by a later run (spec §3, §5.3).
- Every command can be run twice with the same input and change nothing the second time. Writing commands take `--dry-run` (run in a transaction and roll back) and refuse `NODE_ENV=production` unless `--yes-production` is passed.
- Migrations follow `.agents/skills/db-migration/SKILL.md`: one file with `-- Up Migration` / `-- Down Migration`, table types in `src/db/database.ts`, columns in DDL order in `EXPECTED` of `test/migrations.test.ts`, new tables in the `truncate` list of `resetDb` (`test/helpers.ts`).
- Commits: Conventional Commits, subject ends with `[#7]`.
- Tests: API `npx vitest run <file>` (needs Docker or Podman for Testcontainers, or `TEST_DATABASE_URL` naming a database ending in `_test`); domain `cd packages/domain && npm test`. Before the PR: `npm run typecheck && npm test` at the root and `npm run typecheck && npm run lint && npm test` in `packages/domain`.
- Out of scope here (other units of the spec): the API endpoints, geocoding and the `website`/`directory_*` sources, the app, the claim flow, scheduled re-runs and the 180-day stale rule, the Google Maps and Facebook sources.

## Review Focus

1. **Second run.** Importing the same file again, re-running `normalize --all` or `merge` creates no new row and changes no `updated_at` on `studio_listings`. Pinned in Task 6 (`a second full run changes nothing`).
2. **Staff edits and removals survive.** After `edit <id> --set phone=` or `hide <id> --reason removal_request`, a new import of the same studio keeps the edit and does not bring the listing back. Pinned in Task 6 (`overrides win after a re-merge`, `a removed listing absorbs new records and stays hidden`).
3. **A record that changes at the source.** The same `source` + `source_ref` comes back with another phone or position: the raw row is updated in place, the listing is re-merged, no second listing appears. Pinned in Task 6 (`a changed source record updates its listing`).
4. **Bad input does not stop a run.** A record with no name, an emoji-only name, `NaN` or out-of-range coordinates, a 5 000-character name or a non-object payload is rejected as `invalid` and the run continues. Pinned in Task 3 (`malformed records are invalid, never thrown`) and Task 5 (`a bad line is counted and skipped`).
5. **No phone in output.** The text printed by every command over the fixture set contains none of the fixture numbers in any spelling. Pinned in Task 7 (`command output carries no phone number`).

---

## File structure

```
booking-be/
  migrations/1794614400001_studio_listings.sql        six tables (Task 1)
  src/db/database.ts                                   table types (Task 1)
  src/domain/index.ts                                  re-export the listing rules (Tasks 2–4)
  packages/domain/src/
    studio_listing.ts            types, codes, limits, LISTING_NORMALIZE_VERSION
    studio_listing_text.ts       foldText, listingNameKey, nameSimilarity, cleanListingName
    studio_listing_contact.ts    normalizeListingPhone, classifyListingUrl
    studio_listing_classify.ts   isPhotoStudio, listingSpecialties (keyword tables)
    studio_listing_area.ts       LISTING_CITIES, LISTING_AREA_CENTRES, locateListing
    studio_listing_normalize.ts  normalizeListing
    studio_listing_merge.ts      matchListing, mergeListing, listingQualityScore
  packages/domain/test/studio_listing_*.test.ts
  tools/studio-listings/
    cli.ts               argument parsing and dispatch only
    sources/source.ts    ListingSource interface, RawRecord
    sources/manual.ts    CSV/NDJSON → RawRecord, payload → ListingIntermediate
    sources/osm.ts       Overpass query, element → RawRecord, payload → ListingIntermediate
    csv.ts               minimal RFC 4180 reader/writer
    store.ts             Kysely queries of the pipeline
    pipeline.ts          importRecords, runNormalize, runMerge
    staff.ts             review, publish, hide, edit, mergeInto, stats
    fixtures/            manual-hcm.ndjson, osm-hcm.json
    *.test.ts
```

## The fixture set (used by Tasks 5–7)

`tools/studio-listings/fixtures/manual-hcm.ndjson` (source `manual`) and `osm-hcm.json` (an Overpass response, source `osm`). All phone numbers are invented.

| Ref | Source | Name | lat, lng | Phone | URLs | Tags |
|---|---|---|---|---|---|---|
| m1 | manual | Mimosa Wedding Studio | 10.7769, 106.7009 | `0903 123 456` | `https://www.mimosa.example/?utm_source=fb` | `photo_studio` |
| node/101 | osm | Ảnh viện áo cưới Mimosa | 10.7771, 106.7011 | `+84 903 123 456` | — | `craft=photographer` |
| m2 | manual | Mimosa Wedding Studio - CN Thủ Đức | 10.8494, 106.7537 | `0903 123 456` | — | `photo_studio` |
| m3 | manual | Kỷ Yếu Sài Gòn Photo | 10.7840, 106.6842 | `028 3930 1234` | — | — |
| node/102 | osm | Ky Yeu Sai Gon | 10.7843, 106.6845 | — | — | `shop=photo` |
| m4 | manual | Photocopy Minh Anh | 10.7800, 106.6900 | `0911 111 111` | — | — |
| m5 | manual | Studio Thu Âm Hòa Bình | 10.7810, 106.6910 | — | — | — |
| m6 | manual | Baby Moon Studio | 21.0300, 105.8500 | — | — | `photo_studio` |
| m7 | manual | Lala Studio | — | `0933 333 333` | — | `photo_studio` |
| m8 | manual | Nắng Studio | 10.7340, 106.7219 | `0912 345 678` | — | `photo_studio` |
| m9 | manual | Nắng Studio 2 | 10.7400, 106.7250 | `0912 345 678` | — | `photo_studio` |

Expected after `import` (both files) → `normalize` → `merge` with area `hcm`:

- Rejected: m4 and m5 `not_photo_studio`, m6 `outside_area`, m7 `no_location`.
- Five listings:

| Listing | Records | area_code | Specialties | quality_score |
|---|---|---|---|---|
| A "Mimosa Wedding Studio" | m1 + node/101 (same phone, ≈ 31 m) | `hcm-q1` | `wedding` | 1.0 |
| B "Mimosa Wedding Studio - CN Thủ Đức" | m2 (same phone as A but > 2 km away) | `hcm-thu-duc` | `wedding` | 0.65 |
| C "Kỷ Yếu Sài Gòn Photo" | m3 + node/102 (name key `kyyeusaigon`, ≈ 47 m) | `hcm-q3` | `graduation` | 0.9 |
| D "Nắng Studio" | m8 | `hcm-q7` | none | 0.25 |
| E "Nắng Studio 2" | m9 | `hcm-q7` | none | 0.25 |

- One open suspect pair: D–E, reason `phone` (same phone, ≈ 750 m apart).
- `publish --city hcm --min-score 0.7` publishes A and C only.

---

### Task 1: Tables

**Files:**
- Create: `migrations/1794614400001_studio_listings.sql`
- Modify: `src/db/database.ts`, `test/migrations.test.ts` (`EXPECTED`), `test/helpers.ts` (`resetDb`)

**Interfaces:**
- Produces: tables `studio_listings`, `studio_listing_specialties`, `listing_source_records`, `studio_listing_suspects`, `studio_listing_claims`, `studio_listing_reports`; Kysely types `StudioListingsTable`, `StudioListingSpecialtiesTable`, `ListingSourceRecordsTable`, `StudioListingSuspectsTable`, `StudioListingClaimsTable`, `StudioListingReportsTable` registered in `Database` under the table names; string unions `StudioListingStatus`, `ListingHiddenReason`, `ListingRecordStatus`, `ListingRejectReason`.

- [ ] **Step 1: Add the six tables to `EXPECTED` in `test/migrations.test.ts`** with these columns in this order, and add the six names to the `truncate` list in `test/helpers.ts`:

```ts
listing_source_records: ['id', 'source', 'source_ref', 'source_url', 'run_id', 'fetched_at', 'payload', 'payload_hash',
  'normalized', 'normalize_version', 'status', 'reject_reason', 'listing_id', 'created_at', 'updated_at'],
studio_listing_claims: ['id', 'listing_id', 'photographer_id', 'status', 'match_reasons', 'note', 'decided_by',
  'decided_at', 'created_at'],
studio_listing_reports: ['id', 'listing_id', 'reporter_user_id', 'reason', 'note', 'status', 'created_at'],
studio_listing_specialties: ['listing_id', 'specialty_id', 'confidence'],
studio_listing_suspects: ['listing_id', 'other_listing_id', 'reason', 'status', 'created_at'],
studio_listings: ['id', 'name', 'name_key', 'address_line', 'city', 'area_code', 'lat', 'lng', 'geohash', 'website',
  'website_host', 'phone', 'zalo', 'facebook_url', 'instagram_url', 'email', 'status', 'hidden_reason',
  'quality_score', 'claimed_by', 'claimed_at', 'overrides', 'field_sources', 'first_seen_at', 'last_seen_at',
  'published_at', 'created_at', 'updated_at'],
```

- [ ] **Step 2: Run** `npx vitest run test/migrations.test.ts`. Expected: FAIL, the tables do not exist.

- [ ] **Step 3: Write the migration.** Decisions the DDL must carry:

  - `studio_listings`: `id text primary key`; `name text not null check (char_length(name) between 1 and 80)`; `name_key text not null`; `address_line text not null default ''`; `city text not null`; `area_code text`; `lat`, `lng` `double precision not null`; `geohash text not null check (char_length(geohash) = 9)`; `website`, `website_host`, `phone`, `zalo`, `facebook_url`, `instagram_url`, `email` nullable `text`; `status text not null default 'draft' check (status in ('draft','published','hidden','claimed','closed'))`; `hidden_reason text check (hidden_reason in ('staff','removal_request','duplicate','stale'))`; `quality_score real not null default 0 check (quality_score between 0 and 1)`; `claimed_by text references photographers(user_id) on delete set null` (not unique: one studio may claim several listings, spec L16); `claimed_at timestamptz`; `overrides jsonb not null default '{}'`; `field_sources jsonb not null default '{}'`; `first_seen_at`, `last_seen_at` `timestamptz not null`; `published_at timestamptz`; `created_at`, `updated_at` `timestamptz not null default now()`; trigger `set_updated_at`.
  - Indexes on `studio_listings`: `ix_studio_listings_geohash` on `(geohash text_pattern_ops) where status = 'published'`; plain indexes on `(phone)`, `(website_host)`, `(lat, lng)`.
  - `studio_listing_specialties`: `listing_id text not null references studio_listings(id) on delete cascade`, `specialty_id text not null`, `confidence real not null check (confidence between 0 and 1)`, primary key `(listing_id, specialty_id)`. No foreign key to `taxonomy_items`: that table may be empty in a database that only holds listings; the domain validates the codes.
  - `listing_source_records`: `id text primary key`; `source text not null`; `source_ref text not null`; `source_url text`; `run_id text not null`; `fetched_at timestamptz not null`; `payload jsonb not null`; `payload_hash text not null`; `normalized jsonb`; `normalize_version int`; `status text not null default 'new' check (status in ('new','normalized','rejected'))`; `reject_reason text check (reject_reason in ('not_photo_studio','no_location','outside_area','invalid'))`; `listing_id text references studio_listings(id) on delete set null`; `created_at`, `updated_at`; `unique (source, source_ref)`; indexes on `(status)` and `(listing_id)`; trigger `set_updated_at`.
  - `studio_listing_suspects` (pairs staff should look at; the spec's "nghi trùng"): `listing_id` and `other_listing_id` both `references studio_listings(id) on delete cascade`, `check (listing_id < other_listing_id)`, `reason text not null check (reason in ('phone','website_host','name_near','multiple_match'))`, `status text not null default 'open' check (status in ('open','dismissed'))`, `created_at`, primary key `(listing_id, other_listing_id)`.
  - `studio_listing_claims`: `id text primary key`, `listing_id … on delete cascade`, `photographer_id text not null references photographers(user_id) on delete cascade`, `status text not null default 'pending' check (status in ('pending','approved','rejected','withdrawn'))`, `match_reasons text[] not null default '{}'`, `note text`, `decided_by text`, `decided_at timestamptz`, `created_at`; unique index on `(listing_id, photographer_id) where status = 'pending'`.
  - `studio_listing_reports`: `id text primary key`, `listing_id … on delete cascade`, `reporter_user_id text references users(id) on delete set null`, `reason text not null check (reason in ('wrong_info','closed','not_studio','duplicate','removal_request'))`, `note text check (char_length(note) <= 300)`, `status text not null default 'open' check (status in ('open','resolved'))`, `created_at`.
  - Down: drop the six tables in reverse dependency order.

- [ ] **Step 4: Add the table interfaces to `src/db/database.ts`** with the file's helpers (`Opt`, `Def`, `CreatedAt`, `UpdatedAt`); `jsonb` columns are typed `unknown` on select and take a JSON string or object on insert as the file already does for other JSON, `match_reasons` is `string[]`, `quality_score` and `confidence` are `number`.

- [ ] **Step 5: Run** `npx vitest run test/migrations.test.ts` then `npm run typecheck`. Expected: PASS (up, down, up again is clean).

- [ ] **Step 6: Commit** `feat(db): studio listing tables [#7]`.

---

### Task 2: Text and contact rules (domain)

**Files:**
- Create: `packages/domain/src/studio_listing.ts`, `studio_listing_text.ts`, `studio_listing_contact.ts`
- Test: `packages/domain/test/studio_listing_text.test.ts`, `studio_listing_contact.test.ts`
- Modify: `packages/domain/src/index.ts` (export the three files)

**Interfaces:**
- Produces:

```ts
// studio_listing.ts
export const LISTING_NORMALIZE_VERSION = 1;
export const LISTING_NAME_MAX = 80;
export type ListingRejectReason = 'not_photo_studio' | 'no_location' | 'outside_area' | 'invalid';
/** What every source adapter hands to the normaliser. */
export interface ListingIntermediate {
  readonly name: string;
  readonly addressLine?: string;
  readonly lat?: number;
  readonly lng?: number;
  readonly phones: readonly string[];
  readonly urls: readonly string[];
  readonly emails?: readonly string[];
  readonly tags: readonly string[];   // free tags or "key=value" strings of the source
  readonly text?: string;             // title/meta text; used for keywords only, never stored
}
// studio_listing_text.ts
export function foldText(s: string): string;            // lower case, no diacritics, đ→d, single spaces
export function cleanListingName(raw: string): string | null;   // display name, or null when nothing is left
export function listingNameKey(name: string): string;
export function nameSimilarity(a: string, b: string): number;   // 0..1 over two name keys
// studio_listing_contact.ts
export function normalizeListingPhone(raw: string): string | null;   // E.164
export type ListingUrlKind = 'website' | 'facebook' | 'instagram' | 'zalo' | 'other';
export function classifyListingUrl(raw: string): { kind: ListingUrlKind; url: string; host: string } | null;
```

- [ ] **Step 1: Write the failing tests** (`node:test` + `node:assert/strict`, as `test/geo.test.ts`):

```ts
// studio_listing_text.test.ts
it('foldText', () => {
  assert.equal(foldText('  Ảnh Viện  ÁO CƯỚI Đẹp '), 'anh vien ao cuoi dep');
});
it('cleanListingName drops emoji and extra spaces, keeps the source casing', () => {
  assert.equal(cleanListingName('  ✨ Nắng   Studio ✨ '), 'Nắng Studio');
  assert.equal(cleanListingName('✨✨'), null);
  assert.equal(cleanListingName('x'.repeat(200))?.length, 80);
});
it('listingNameKey removes generic words and non-alphanumerics', () => {
  assert.equal(listingNameKey('Kỷ Yếu Sài Gòn Photo'), 'kyyeusaigon');
  assert.equal(listingNameKey('Ky Yeu Sai Gon'), 'kyyeusaigon');
  assert.equal(listingNameKey('Ảnh viện áo cưới Mimosa'), 'mimosa');
  assert.equal(listingNameKey('Nắng Studio 2'), 'nang2');
  // a name made only of generic words keeps them, so it never becomes an empty key
  assert.equal(listingNameKey('Photo Studio'), 'photostudio');
});
it('nameSimilarity is 1 for equal keys and symmetric', () => {
  assert.equal(nameSimilarity('kyyeusaigon', 'kyyeusaigon'), 1);
  assert.equal(nameSimilarity('nang', 'nang2'), nameSimilarity('nang2', 'nang'));
  assert.equal(nameSimilarity('nang', 'nang2'), 0.8);
  assert.equal(nameSimilarity('', 'abc'), 0);
});
// studio_listing_contact.test.ts
it('mobile, landline and old 11-digit mobile numbers become E.164', () => {
  assert.equal(normalizeListingPhone('0903 123 456'), '+84903123456');
  assert.equal(normalizeListingPhone('+84 903.123.456'), '+84903123456');
  assert.equal(normalizeListingPhone('(028) 3930 1234'), '+842839301234');
  assert.equal(normalizeListingPhone('01234 567 890'), '+84834567890');   // 0123 → 083
  assert.equal(normalizeListingPhone('0168 123 4567'), '+84381234567');   // 0168 → 038
});
it('hotlines, short and foreign numbers are dropped', () => {
  for (const s of ['1900 1234', '18006789', '12345', '+1 415 555 0100', 'abc', '']) {
    assert.equal(normalizeListingPhone(s), null);
  }
});
it('classifyListingUrl', () => {
  assert.deepEqual(classifyListingUrl('http://WWW.Mimosa.example/lien-he?utm_source=fb&x=1#top'),
    { kind: 'website', url: 'https://mimosa.example/lien-he?x=1', host: 'mimosa.example' });
  assert.equal(classifyListingUrl('https://m.facebook.com/mimosa.studio/')?.kind, 'facebook');
  assert.equal(classifyListingUrl('instagram.com/mimosa')?.kind, 'instagram');
  assert.equal(classifyListingUrl('https://zalo.me/0903123456')?.kind, 'zalo');
  assert.equal(classifyListingUrl('https://linktr.ee/mimosa')?.kind, 'other');
  assert.equal(classifyListingUrl('not a url'), null);
});
```

- [ ] **Step 2: Run** `cd packages/domain && npm test`. Expected: FAIL (modules missing).

- [ ] **Step 3: Implement.** Decisions:

  - `foldText`: `normalize('NFD')`, strip combining marks, `đ`/`Đ` → `d`, lower case, collapse whitespace, trim.
  - `cleanListingName`: remove emoji and other pictographs (`\p{Extended_Pictographic}`), collapse whitespace, trim, cut to `LISTING_NAME_MAX` characters; `null` when empty.
  - `listingNameKey`: `foldText`, remove the generic phrases `anh vien`, `ao cuoi`, `studio`, `photography`, `photo` (whole words), remove everything outside `[a-z0-9]`. If the result is empty, use the folded name with everything outside `[a-z0-9]` removed.
  - `nameSimilarity`: `1 - levenshtein(a, b) / max(a.length, b.length)`; 0 when either is empty.
  - `normalizeListingPhone`: strip spaces, dots, dashes and brackets. Mobile through the existing `normalizePhone` (`phone.ts`). Landline `^(?:\+84|0)(2\d{8,9})$` → `+84` + group. Old 11-digit mobile `^(?:\+84|0)(1\d{9})$`: replace the 3-digit prefix by the 2018 mapping and re-check as a mobile:

    ```
    120→70 121→79 122→77 126→76 128→78
    123→83 124→84 125→85 127→81 129→82
    162→32 163→33 164→34 165→35 166→36 167→37 168→38 169→39
    186→56 188→58 199→59
    ```
    Anything else (1800/1900 hotlines included) → `null`.
  - `classifyListingUrl`: add `https://` when no scheme; lower-case host; drop a leading `www.` or `m.`; drop the fragment and the query parameters `utm_*`, `fbclid`, `gclid`; force `https`. Kind by host: `facebook.com`/`fb.com`/`fb.me` → `facebook`; `instagram.com` → `instagram`; `zalo.me` → `zalo`; `linktr.ee`, `bio.link`, `beacons.ai`, `tiktok.com`, `youtube.com`, `google.com`, `goo.gl`, `maps.app.goo.gl` → `other`; everything else with a dot in the host → `website`. Use the `URL` global; if `npm run lint` rejects it, add `URL: 'readonly'` to the `globals` of `packages/domain/eslint.config.js` (it is a language-level global on every runtime the domain runs on, not a Node import).

- [ ] **Step 4: Run** `npm test && npm run lint && npm run typecheck` in `packages/domain`. Expected: PASS, including `test/purity.test.ts`.

- [ ] **Step 5: Commit** `feat(domain): text and contact rules for studio listings [#7]`.

---

### Task 3: Classification, area and `normalizeListing` (domain)

**Files:**
- Create: `packages/domain/src/studio_listing_classify.ts`, `studio_listing_area.ts`, `studio_listing_normalize.ts`
- Test: `packages/domain/test/studio_listing_classify.test.ts`, `studio_listing_area.test.ts`, `studio_listing_normalize.test.ts`
- Modify: `packages/domain/src/index.ts`, `src/domain/index.ts` (API shim re-exports everything the tool needs from Tasks 2–4)

**Interfaces:**
- Consumes: Task 2's functions; `encodeGeohash` (`event.ts`), `distanceKm` (`geo.ts`).
- Produces:

```ts
// studio_listing_classify.ts
export function isPhotoStudio(input: Pick<ListingIntermediate, 'name' | 'tags' | 'text'>): boolean;
export interface ListingSpecialty { readonly id: string; readonly confidence: number }
export function listingSpecialties(input: Pick<ListingIntermediate, 'name' | 'tags' | 'text'>): ListingSpecialty[];
// studio_listing_area.ts
export interface ListingCity { readonly code: string; readonly minLat: number; readonly maxLat: number; readonly minLng: number; readonly maxLng: number }
export const LISTING_CITIES: readonly ListingCity[];
export const LISTING_AREA_RADIUS_KM = 5;
export function locateListing(lat: number, lng: number, city: string): { city: string; areaCode: string | null } | null;
// studio_listing_normalize.ts
export interface ListingNormalized {
  readonly name: string; readonly nameKey: string; readonly addressLine: string;
  readonly city: string; readonly areaCode: string | null;
  readonly lat: number; readonly lng: number; readonly geohash: string;
  readonly website: string | null; readonly websiteHost: string | null;
  readonly phone: string | null; readonly zalo: string | null;
  readonly facebookUrl: string | null; readonly instagramUrl: string | null; readonly email: string | null;
  readonly specialties: readonly ListingSpecialty[];
  readonly coordSource: 'map' | 'geocoded';
}
export type ListingNormalizeResult =
  | { readonly ok: true; readonly value: ListingNormalized }
  | { readonly ok: false; readonly reason: ListingRejectReason };
export function normalizeListing(
  raw: unknown, ctx: { readonly city: string; readonly coordSource: 'map' | 'geocoded' },
): ListingNormalizeResult;
```

- [ ] **Step 1: Write the failing tests.**

```ts
// classify
const accept = [
  { name: 'Mimosa Wedding Studio', tags: [] },
  { name: 'Ảnh viện áo cưới Mimosa', tags: [] },
  { name: 'Kỷ Yếu Sài Gòn Photo', tags: [] },
  { name: 'Nắng Studio', tags: ['photo_studio'] },
  { name: 'Tiệm Hùng', tags: ['craft=photographer'] },
  { name: 'Chụp ảnh cưới Lavender', tags: ['shop=photo'] },
];
const reject = [
  { name: 'Photocopy Minh Anh', tags: [] },
  { name: 'Studio Thu Âm Hòa Bình', tags: [] },
  { name: 'Nắng Studio', tags: [] },                       // "studio" alone is not enough
  { name: 'Yoga Studio Lotus', tags: ['photo_studio'] },   // a negative keyword wins over a free tag
  { name: 'Cửa hàng máy ảnh Bình Minh', tags: ['shop=photo'] },
  { name: 'In ảnh lấy liền 24h', tags: ['shop=photo'] },
];
it('isPhotoStudio', () => {
  for (const r of accept) assert.equal(isPhotoStudio(r), true, r.name);
  for (const r of reject) assert.equal(isPhotoStudio(r), false, r.name);
});
it('listingSpecialties maps Vietnamese and English keywords to taxonomy codes', () => {
  assert.deepEqual(listingSpecialties({ name: 'Mimosa Wedding Studio', tags: [] }), [{ id: 'wedding', confidence: 0.9 }]);
  assert.deepEqual(listingSpecialties({ name: 'Kỷ Yếu Sài Gòn Photo', tags: [] }), [{ id: 'graduation', confidence: 0.9 }]);
  assert.deepEqual(listingSpecialties({ name: 'Nắng Studio', tags: ['newborn'], text: 'chụp ảnh gia đình' }),
    [{ id: 'newborn', confidence: 0.8 }, { id: 'family', confidence: 0.6 }]);
  assert.deepEqual(listingSpecialties({ name: 'Nắng Studio', tags: [] }), []);
});
it('at most five specialties, highest confidence first', () => {
  const many = listingSpecialties({ name: 'Cưới kỷ yếu gia đình sản phẩm thời trang sự kiện món ăn', tags: [] });
  assert.equal(many.length, 5);
});
// area
it('locateListing', () => {
  assert.deepEqual(locateListing(10.7769, 106.7009, 'hcm'), { city: 'hcm', areaCode: 'hcm-q1' });
  assert.deepEqual(locateListing(10.8494, 106.7537, 'hcm'), { city: 'hcm', areaCode: 'hcm-thu-duc' });
  assert.deepEqual(locateListing(10.6500, 106.5000, 'hcm'), { city: 'hcm', areaCode: null });   // in the city, far from every centre
  assert.equal(locateListing(21.03, 105.85, 'hcm'), null);
  assert.equal(locateListing(10.7769, 106.7009, 'nowhere'), null);
});
// normalize
it('a full record', () => {
  const r = normalizeListing({ name: ' ✨ Mimosa Wedding Studio ', lat: 10.7769, lng: 106.7009,
    phones: ['abc', '0903 123 456'], urls: ['https://www.mimosa.example/?utm_source=fb', 'facebook.com/mimosa'],
    emails: ['Hello@Mimosa.example'], tags: ['photo_studio'], addressLine: ' 12 Lê Lợi,  Q1 ' },
    { city: 'hcm', coordSource: 'map' });
  assert.deepEqual(r, { ok: true, value: {
    name: 'Mimosa Wedding Studio', nameKey: 'mimosawedding', addressLine: '12 Lê Lợi, Q1',
    city: 'hcm', areaCode: 'hcm-q1', lat: 10.7769, lng: 106.7009, geohash: encodeGeohash(10.7769, 106.7009, 9),
    website: 'https://mimosa.example/', websiteHost: 'mimosa.example', phone: '+84903123456', zalo: null,
    facebookUrl: 'https://facebook.com/mimosa', instagramUrl: null, email: 'hello@mimosa.example',
    specialties: [{ id: 'wedding', confidence: 0.9 }], coordSource: 'map' } });
});
it('rejections', () => {
  const base = { name: 'Nắng Studio', phones: [], urls: [], tags: ['photo_studio'] };
  const ctx = { city: 'hcm', coordSource: 'map' as const };
  assert.deepEqual(normalizeListing({ ...base, name: 'Photocopy Minh Anh', lat: 10.78, lng: 106.69 }, ctx), { ok: false, reason: 'not_photo_studio' });
  assert.deepEqual(normalizeListing(base, ctx), { ok: false, reason: 'no_location' });
  assert.deepEqual(normalizeListing({ ...base, lat: 21.03, lng: 105.85 }, ctx), { ok: false, reason: 'outside_area' });
});
it('malformed records are invalid, never thrown', () => {
  const ctx = { city: 'hcm', coordSource: 'map' as const };
  for (const raw of [null, 'x', 42, [], {}, { name: '✨', phones: [], urls: [], tags: [] },
    { name: 'A Photo', lat: Number.NaN, lng: 106.7, phones: [], urls: [], tags: [] },
    { name: 'A Photo', lat: 95, lng: 106.7, phones: [], urls: [], tags: [] },
    { name: 'A Photo', lat: 10.77, lng: 106.7, phones: 'x', urls: [], tags: [] }]) {
    assert.deepEqual(normalizeListing(raw, ctx), { ok: false, reason: 'invalid' });
  }
});
it('a zalo.me link gives the zalo field; the first mobile is the phone', () => {
  const r = normalizeListing({ name: 'A Photo', lat: 10.7769, lng: 106.7009, phones: ['028 3930 1234', '0903 123 456'],
    urls: ['https://zalo.me/0903123456'], tags: [] }, { city: 'hcm', coordSource: 'map' });
  assert.ok(r.ok);
  assert.equal(r.value.phone, '+84903123456');
  assert.equal(r.value.zalo, 'https://zalo.me/0903123456');
});
```

- [ ] **Step 2: Run** `npm test` in `packages/domain`. Expected: FAIL.

- [ ] **Step 3: Implement.** Decisions:

  - Keywords match as whole words or whole phrases of the folded text (`in anh` does not match `vin anh`), in `isPhotoStudio` and in `listingSpecialties`.
  - `isPhotoStudio` works on `foldText(name + ' ' + text)` and the tags. **A negative keyword always wins**: `photocopy`, `in anh`, `in an`, `thu am`, `phong thu`, `yoga`, `nail`, `xam`, `tattoo`, `gym`, `phong tap`, `may anh`, `camera`, `dance`, `spa`, `piano`. Strong tags (enough without any positive keyword): `craft=photographer`, `studio=photography`. Positive keywords: `anh vien`, `chup anh`, `photo`, `photography`, `wedding`, `ao cuoi`, `anh cuoi`, `ky yeu`, `studio anh`. The free tags `photo_studio` and `photo` count as a positive keyword, not as a strong tag. `shop=photo` alone decides nothing. Result: negative keyword → false; else strong tag → true; else positive keyword → true; else false.
  - `listingSpecialties`: keyword table over folded text, one row per taxonomy code (codes exactly as the app's `kSpecialties`):

    | Code | Keywords |
    |---|---|
    | `wedding` | `cuoi`, `wedding`, `prewedding`, `pre-wedding`, `bride` |
    | `graduation` | `ky yeu`, `tot nghiep`, `graduation` |
    | `newborn` | `newborn`, `so sinh`, `em be`, `baby` |
    | `family` | `gia dinh`, `family` |
    | `portrait` | `chan dung`, `portrait`, `beauty`, `profile` |
    | `product` | `san pham`, `product` |
    | `fashion` | `thoi trang`, `lookbook`, `fashion` |
    | `event` | `su kien`, `event`, `hoi nghi` |
    | `food` | `mon an`, `am thuc`, `food` |
    | `real_estate` | `noi that`, `bat dong san`, `kien truc`, `interior`, `real estate` |
    | `couple` | `cap doi`, `couple` |
    | `commercial` | `quang cao`, `commercial`, `tvc` |
    | `travel` | `du lich`, `travel` |
    | `street` | `duong pho`, `street` |

    Confidence: keyword found in the name 0.9; in a tag 0.8; only in `text` 0.6; keep the highest per code. Sort by confidence descending, then by the table's order; keep the first 5.
  - `LISTING_CITIES`: one entry for the pilot, `{ code: 'hcm', minLat: 10.35, maxLat: 11.17, minLng: 106.35, maxLng: 107.03 }`. Area centres (from the app's `builtInAreas`): `hcm-q1` 10.7769, 106.7009; `hcm-q3` 10.7840, 106.6842; `hcm-q7` 10.7340, 106.7219; `hcm-binh-thanh` 10.8106, 106.7091; `hcm-thu-duc` 10.8494, 106.7537. `locateListing`: `null` when the city code is unknown or the point is outside its box; `areaCode` is the nearest centre of that city within `LISTING_AREA_RADIUS_KM`, else `null`.
  - `normalizeListing` order: shape check (object with a string `name`, array `phones`/`urls`/`tags` of strings; optional finite numbers `lat`/`lng`; lat within −90..90, lng within −180..180) → `invalid`; `cleanListingName` null → `invalid`; `isPhotoStudio` false → `not_photo_studio`; no `lat`/`lng` → `no_location`; `locateListing` null → `outside_area`. Then fields: `phone` = first normalised mobile (`+84` then 3/5/7/8/9), else the first normalised landline; `website` = first URL of kind `website`; `facebookUrl`, `instagramUrl`, `zalo` = first URL of that kind; `email` = first of `emails` matching a simple `x@y.z` pattern, lower-cased; `addressLine` with collapsed whitespace, at most 200 characters; `geohash` of length 9.

- [ ] **Step 4: Add the re-exports to `src/domain/index.ts`** (everything exported by the five `studio_listing*` files so far) and run `npm run typecheck` at the repo root.

- [ ] **Step 5: Run** `npm test && npm run lint && npm run typecheck` in `packages/domain`. Expected: PASS.

- [ ] **Step 6: Commit** `feat(domain): classify, locate and normalise studio listing records [#7]`.

---

### Task 4: Matching, merging and the quality score (domain)

**Files:**
- Create: `packages/domain/src/studio_listing_merge.ts`
- Test: `packages/domain/test/studio_listing_merge.test.ts`
- Modify: `packages/domain/src/index.ts`, `src/domain/index.ts`

**Interfaces:**
- Consumes: `ListingNormalized`, `nameSimilarity`, `distanceKm`.
- Produces:

```ts
export const LISTING_SAME_CONTACT_M = 300;
export const LISTING_SAME_NAME_M = 100;
export const LISTING_SUSPECT_M = 2000;
export const LISTING_NAME_SIMILARITY = 0.85;
export interface ListingCandidate {
  readonly id: string; readonly nameKey: string; readonly lat: number; readonly lng: number;
  readonly phone: string | null; readonly websiteHost: string | null;
}
export type ListingMatchReason = 'phone' | 'website_host' | 'name_near';
export interface ListingMatchResult {
  readonly sameAs: { readonly listingId: string; readonly reason: ListingMatchReason } | null;
  readonly suspects: readonly { readonly listingId: string; readonly reason: ListingMatchReason | 'multiple_match' }[];
}
export function matchListing(record: ListingNormalized, candidates: readonly ListingCandidate[]): ListingMatchResult;

export interface ListingSourceView { readonly recordId: string; readonly source: string; readonly normalized: ListingNormalized }
/** The staff-editable fields of a listing. */
export type ListingFields = Pick<ListingNormalized,
  'name' | 'nameKey' | 'addressLine' | 'city' | 'areaCode' | 'lat' | 'lng' | 'geohash' | 'website' | 'websiteHost'
  | 'phone' | 'zalo' | 'facebookUrl' | 'instagramUrl' | 'email'>;
export interface ListingMerged {
  readonly fields: ListingFields;
  readonly specialties: readonly ListingSpecialty[];
  readonly fieldSources: Readonly<Record<string, string>>;   // field → recordId, or 'override'
  readonly coordSource: 'map' | 'geocoded';
}
export function listingSourceRank(source: string): number;   // lower wins
export function mergeListing(sources: readonly ListingSourceView[], overrides: Partial<ListingFields>): ListingMerged;
export function listingQualityScore(input: {
  readonly sourceCount: number; readonly hasWebsite: boolean; readonly hasPhone: boolean;
  readonly specialtyCount: number; readonly coordSource: 'map' | 'geocoded'; readonly openSuspects: number;
}): number;
```

- [ ] **Step 1: Write the failing tests.** Build records with a small helper `rec({ name, lat, lng, phone?, websiteHost? })` that fills the other `ListingNormalized` fields.

```ts
const A = { id: 'A', nameKey: 'mimosawedding', lat: 10.7769, lng: 106.7009, phone: '+84903123456', websiteHost: 'mimosa.example' };
it('same phone within 300 m is the same studio', () => {
  const r = matchListing(rec({ name: 'Ảnh viện áo cưới Mimosa', lat: 10.7771, lng: 106.7011, phone: '+84903123456' }), [A]);
  assert.deepEqual(r, { sameAs: { listingId: 'A', reason: 'phone' }, suspects: [] });
});
it('same phone more than 2 km away is another branch, not a suspect', () => {
  const r = matchListing(rec({ name: 'Mimosa CN Thủ Đức', lat: 10.8494, lng: 106.7537, phone: '+84903123456' }), [A]);
  assert.deepEqual(r, { sameAs: null, suspects: [] });
});
it('same phone between 300 m and 2 km is a suspect', () => {
  const D = { id: 'D', nameKey: 'nang', lat: 10.7340, lng: 106.7219, phone: '+84912345678', websiteHost: null };
  const r = matchListing(rec({ name: 'Nắng Studio 2', lat: 10.7400, lng: 106.7250, phone: '+84912345678' }), [D]);
  assert.deepEqual(r, { sameAs: null, suspects: [{ listingId: 'D', reason: 'phone' }] });
});
it('same website host within 300 m', () => {
  const r = matchListing(rec({ name: 'Other name', lat: 10.7770, lng: 106.7010, websiteHost: 'mimosa.example' }), [A]);
  assert.equal(r.sameAs?.reason, 'website_host');
});
it('similar name within 100 m; the same name 200 m away is only a suspect', () => {
  const C = { id: 'C', nameKey: 'kyyeusaigon', lat: 10.7840, lng: 106.6842, phone: null, websiteHost: null };
  assert.deepEqual(matchListing(rec({ name: 'Ky Yeu Sai Gon', lat: 10.7843, lng: 106.6845 }), [C]).sameAs,
    { listingId: 'C', reason: 'name_near' });
  assert.deepEqual(matchListing(rec({ name: 'Ky Yeu Sai Gon', lat: 10.7858, lng: 106.6842 }), [C]),
    { sameAs: null, suspects: [{ listingId: 'C', reason: 'name_near' }] });
});
it('short name keys never match by name', () => {
  const S = { id: 'S', nameKey: 'ab', lat: 10.7840, lng: 106.6842, phone: null, websiteHost: null };
  assert.equal(matchListing(rec({ name: 'AB', lat: 10.7840, lng: 106.6842 }), [S]).sameAs, null);
});
it('two matches: the nearest wins, the other is a suspect', () => {
  const A2 = { ...A, id: 'A2', lat: 10.7780, lng: 106.7020 };
  const r = matchListing(rec({ name: 'Mimosa', lat: 10.7770, lng: 106.7010, phone: '+84903123456' }), [A2, A]);
  assert.equal(r.sameAs?.listingId, 'A');
  assert.deepEqual(r.suspects, [{ listingId: 'A2', reason: 'multiple_match' }]);
});
it('mergeListing: manual beats osm per field, gaps are filled, overrides win', () => {
  const manual = { recordId: 'r1', source: 'manual', normalized: rec({ name: 'Mimosa Wedding Studio', lat: 10.7769, lng: 106.7009, phone: '+84903123456', website: 'https://mimosa.example/', websiteHost: 'mimosa.example', specialties: [{ id: 'wedding', confidence: 0.9 }] }) };
  const osm = { recordId: 'r2', source: 'osm', normalized: rec({ name: 'Ảnh viện áo cưới Mimosa', lat: 10.7771, lng: 106.7011, phone: '+84903123456', facebookUrl: 'https://facebook.com/mimosa', specialties: [{ id: 'wedding', confidence: 0.8 }] }) };
  const m = mergeListing([osm, manual], { phone: null });
  assert.equal(m.fields.name, 'Mimosa Wedding Studio');
  assert.equal(m.fields.lat, 10.7769);
  assert.equal(m.fields.facebookUrl, 'https://facebook.com/mimosa');
  assert.equal(m.fields.phone, null);
  assert.equal(m.fieldSources.name, 'r1');
  assert.equal(m.fieldSources.lat, 'r1');
  assert.equal(m.fieldSources.website, 'r1');
  assert.equal(m.fieldSources.facebookUrl, 'r2');
  assert.equal(m.fieldSources.phone, 'override');
  assert.equal('instagramUrl' in m.fieldSources, false);   // nothing to record for an empty field
  assert.deepEqual(m.specialties, [{ id: 'wedding', confidence: 0.9 }]);   // union by id, highest confidence
});
it('listingSourceRank', () => {
  assert.deepEqual(['osm', 'directory_x', 'manual', 'facebook', 'website'].sort((a, b) => listingSourceRank(a) - listingSourceRank(b)),
    ['manual', 'website', 'osm', 'directory_x', 'facebook']);
});
it('listingQualityScore', () => {
  const s = (o: object) => listingQualityScore({ sourceCount: 1, hasWebsite: false, hasPhone: false, specialtyCount: 0, coordSource: 'map', openSuspects: 0, ...o });
  assert.equal(s({ sourceCount: 2, hasWebsite: true, hasPhone: true, specialtyCount: 1 }), 1);
  assert.equal(s({ hasPhone: true, specialtyCount: 1 }), 0.65);
  assert.equal(s({ sourceCount: 2, hasPhone: true, specialtyCount: 1 }), 0.9);
  assert.equal(s({ hasPhone: true, openSuspects: 1 }), 0.25);
  assert.equal(s({ coordSource: 'geocoded', openSuspects: 3 }), 0);
});
```

- [ ] **Step 2: Run** `npm test` in `packages/domain`. Expected: FAIL.

- [ ] **Step 3: Implement.** Decisions:

  - `matchListing`, for each candidate with distance `d` in metres: **same** when (`phone` equal and non-null and `d ≤ 300`) or (`websiteHost` equal and non-null and `d ≤ 300`) or (both name keys at least 3 characters, `nameSimilarity ≥ 0.85` and `d ≤ 100`). The reason is the first that holds in that order. **Suspect** when not same and (phone or host equal with `300 < d ≤ 2000`, reason `phone`/`website_host`) or (name rule with `100 < d ≤ 300`, reason `name_near`). With several "same" candidates the nearest is `sameAs` (ties: smallest id) and the others are suspects with reason `multiple_match`. Suspects are returned sorted by `listingId`.
  - `listingSourceRank`: `manual` 0, `website` 1, `osm` 2, anything starting with `directory_` 3, everything else 4.
  - `mergeListing`: sort sources by rank, then by `recordId`. Each field of `ListingFields` takes the first non-null value in that order; `name`, `nameKey`, `addressLine`, `city`, `areaCode` come as one group from the best-ranked source; `lat`, `lng`, `geohash` come as one group from the best-ranked source whose `coordSource` is `map`, else the best-ranked source; `website` and `websiteHost` come together. A key present in `overrides` (even with value `null`) replaces the field and is recorded as `'override'`; overriding `name` recomputes `nameKey`, overriding `lat`/`lng` recomputes `geohash`. `fieldSources` lists only fields with a non-null value or an override. Specialties: union over sources by id with the highest confidence, sorted as in `listingSpecialties`, at most 5.
  - `listingQualityScore`: start 0.3; +0.25 when `sourceCount ≥ 2`; +0.15 when website or phone; +0.1 more when both; +0.1 when `specialtyCount ≥ 1`; +0.1 when `coordSource` is `map`; −0.3 when `openSuspects ≥ 1`; clamp to 0..1 and round to 2 decimals.

- [ ] **Step 4: Run** `npm test && npm run lint && npm run typecheck` in `packages/domain`, then `npm run typecheck` at the root. Expected: PASS.

- [ ] **Step 5: Commit** `feat(domain): match, merge and score studio listings [#7]`.

---

### Task 5: Sources and raw import

**Files:**
- Create: `tools/studio-listings/sources/source.ts`, `sources/manual.ts`, `sources/osm.ts`, `csv.ts`, `store.ts` (raw part), `pipeline.ts` (`importRecords`), `fixtures/manual-hcm.ndjson`, `fixtures/osm-hcm.json`
- Test: `tools/studio-listings/manual.test.ts`, `osm.test.ts`, `import.test.ts`

**Interfaces:**
- Consumes: `ListingIntermediate` (through `src/domain/index.ts`), `Database`, `newId`.
- Produces:

```ts
// sources/source.ts
export interface RawRecord { source: string; sourceRef: string; sourceUrl: string | null; payload: unknown }
export interface ListingSource {
  readonly code: string;
  /** How good the coordinates of this source are. */
  readonly coordSource: 'map' | 'geocoded';
  /** Pure: the stored payload → the normaliser's input; null when the payload is not usable. */
  toIntermediate(payload: unknown): ListingIntermediate | null;
}
export const SOURCES: Readonly<Record<string, ListingSource>>;   // manual, osm
// sources/manual.ts
export function parseManualFile(text: string, format: 'ndjson' | 'csv'): { records: RawRecord[]; badLines: number[] };
// sources/osm.ts
export function overpassQuery(box: { minLat: number; minLng: number; maxLat: number; maxLng: number }): string;
export function parseOverpass(json: unknown): RawRecord[];
export async function collectOsm(box: …, fetchFn: typeof fetch): Promise<RawRecord[]>;
// pipeline.ts
export interface ImportReport { runId: string; inserted: number; updated: number; unchanged: number; skipped: number }
export async function importRecords(db: Kysely<Database>, records: readonly RawRecord[],
  opts: { now: Date; dryRun?: boolean }): Promise<ImportReport>;
```

- [ ] **Step 1: Write the two fixture files** exactly as the table in "The fixture set": `manual-hcm.ndjson` with one JSON object per line, keys `ref`, `name`, `addressLine`, `lat`, `lng`, `phones`, `urls`, `tags`, `sourceUrl`; `osm-hcm.json` as an Overpass response `{ "elements": [ { "type": "node", "id": 101, "lat": …, "lon": …, "tags": { "name": …, "craft": "photographer", "phone": … } }, { "type": "node", "id": 102, …, "tags": { "name": "Ky Yeu Sai Gon", "shop": "photo" } } ] }`. Add a third element `{ "type": "way", "id": 103, "center": { "lat": 10.79, "lon": 106.70 }, "tags": { "shop": "photo" } }` (no name).

- [ ] **Step 2: Write the failing tests.**

```ts
// manual.test.ts
it('NDJSON: one record per line, ref is the source ref', () => {
  const { records, badLines } = parseManualFile(readFixture('manual-hcm.ndjson'), 'ndjson');
  expect(records).toHaveLength(9);
  expect(badLines).toEqual([]);
  expect(records[0]).toMatchObject({ source: 'manual', sourceRef: 'm1', sourceUrl: null });
});
it('a bad line is counted and skipped', () => {
  const { records, badLines } = parseManualFile('{"ref":"a","name":"A Photo"}\nnot json\n\n{"name":"no ref"}\n', 'ndjson');
  expect(records.map((r) => r.sourceRef)).toEqual(['a', expect.stringMatching(/^h_[0-9a-f]{16}$/)]);
  expect(badLines).toEqual([2]);
});
it('CSV: header ref,name,address,lat,lng,phones,urls,tags,source_url; "|" separates several values', () => {
  const csv = 'ref,name,address,lat,lng,phones,urls,tags,source_url\nm1,"Mimosa, Wedding",12 Lê Lợi,10.7769,106.7009,0903 123 456|028 3930 1234,,photo_studio,\n';
  const { records } = parseManualFile(csv, 'csv');
  expect(SOURCES.manual.toIntermediate(records[0].payload)).toEqual({ name: 'Mimosa, Wedding', addressLine: '12 Lê Lợi',
    lat: 10.7769, lng: 106.7009, phones: ['0903 123 456', '028 3930 1234'], urls: [], tags: ['photo_studio'] });
});
// osm.test.ts
it('overpassQuery asks for the three tags inside the box', () => {
  const q = overpassQuery({ minLat: 10.35, minLng: 106.35, maxLat: 11.17, maxLng: 107.03 });
  for (const s of ['nwr["craft"="photographer"](10.35,106.35,11.17,107.03)', 'nwr["shop"="photo"]', 'nwr["studio"="photography"]', 'out center tags']) expect(q).toContain(s);
});
it('parseOverpass keeps named elements; ways use their centre', () => {
  const records = parseOverpass(JSON.parse(readFixture('osm-hcm.json')));
  expect(records.map((r) => r.sourceRef)).toEqual(['node/101', 'node/102']);
  expect(records[0].sourceUrl).toBe('https://www.openstreetmap.org/node/101');
});
it('toIntermediate maps OSM tags', () => {
  const i = SOURCES.osm.toIntermediate({ type: 'node', id: 9, lat: 10.78, lon: 106.7, tags: { name: 'X Photo', craft: 'photographer',
    phone: '+84 903 123 456;028 3930 1234', 'contact:website': 'https://x.example', 'contact:facebook': 'https://facebook.com/x',
    'addr:housenumber': '12', 'addr:street': 'Lê Lợi', 'addr:city': 'Thành phố Hồ Chí Minh', email: 'a@x.example' } });
  expect(i).toEqual({ name: 'X Photo', addressLine: '12 Lê Lợi, Thành phố Hồ Chí Minh', lat: 10.78, lng: 106.7,
    phones: ['+84 903 123 456', '028 3930 1234'], urls: ['https://x.example', 'https://facebook.com/x'],
    emails: ['a@x.example'], tags: ['craft=photographer'] });
});
it('collectOsm posts the query with a User-Agent and parses the answer', async () => {
  const calls: { url: string; init: RequestInit }[] = [];
  const fake = (async (url: string, init: RequestInit) => { calls.push({ url, init }); return new Response(readFixture('osm-hcm.json')); }) as typeof fetch;
  expect(await collectOsm(HCM_BOX, fake)).toHaveLength(2);
  expect(calls[0].url).toBe('https://overpass-api.de/api/interpreter');
  expect(new Headers(calls[0].init.headers).get('user-agent')).toMatch(/^photobooking-listings\//);
});
// import.test.ts (database; resetDb in beforeEach, as test/users.test.ts)
it('inserts new records, leaves unchanged ones alone, updates changed ones', async () => {
  const recs = parseManualFile(readFixture('manual-hcm.ndjson'), 'ndjson').records;
  expect(await importRecords(db, recs, { now: T0 })).toMatchObject({ inserted: 9, updated: 0, unchanged: 0 });
  expect(await importRecords(db, recs, { now: T1 })).toMatchObject({ inserted: 0, updated: 0, unchanged: 9 });
  const changed = [{ ...recs[0], payload: { ...(recs[0].payload as object), name: 'Mimosa Wedding' } }];
  expect(await importRecords(db, changed, { now: T2 })).toMatchObject({ inserted: 0, updated: 1, unchanged: 0 });
  const row = await db.selectFrom('listing_source_records').selectAll().where('source_ref', '=', 'm1').executeTakeFirstOrThrow();
  expect(row.status).toBe('new');            // a changed record goes back to the normaliser
  expect(row.fetched_at).toEqual(T2);
});
it('--dry-run writes nothing', async () => {
  const recs = parseManualFile(readFixture('manual-hcm.ndjson'), 'ndjson').records;
  expect(await importRecords(db, recs, { now: T0, dryRun: true })).toMatchObject({ inserted: 9 });
  expect(await countRows(db, 'listing_source_records')).toBe(0);
});
```

- [ ] **Step 3: Run** `npx vitest run tools/studio-listings`. Expected: FAIL.

- [ ] **Step 4: Implement.** Decisions:

  - `csv.ts`: a reader for RFC 4180 (quoted fields, doubled quotes, CRLF or LF) returning rows of strings, and a writer that quotes fields containing `,`, `"` or a newline. No dependency.
  - Manual payload = the parsed object as given. `sourceRef` = `ref` when it is a non-empty string, else `h_` + the first 16 hex characters of SHA-256 over `name|addressLine` (`node:crypto`). A line that is not JSON or not an object goes to `badLines` (1-based line numbers); blank lines are ignored. `toIntermediate` copies `name`, `addressLine`, `lat`, `lng`, `phones`, `urls`, `tags` (these three default to `[]`) and, only when present, `emails` and `text`; it returns `null` when `name` is not a string.
  - OSM: endpoint `https://overpass-api.de/api/interpreter`, `POST` with body `data=<query>`, header `User-Agent: photobooking-listings/0.1 (+https://github.com/thanhngochoang/booking-be)`. Query: `[out:json][timeout:90];( nwr["craft"="photographer"](box); nwr["shop"="photo"](box); nwr["studio"="photography"](box); ); out center tags;` with `box` = `minLat,minLng,maxLat,maxLng`. `parseOverpass` drops elements without `tags.name`; `sourceRef` = `<type>/<id>`; payload = the element as returned. `toIntermediate`: position from `lat`/`lon` or `center`; phones from `phone`, `contact:phone`, `contact:mobile` (split on `;`); urls from `website`, `contact:website`, `contact:facebook`, `facebook`, `contact:instagram`; emails from `email`, `contact:email`; address = `addr:housenumber addr:street`, then `addr:suburb` or `addr:district`, then `addr:city`, joined with `, `, missing parts skipped; tags = `craft=…`, `shop=…`, `studio=…` when present. A non-2xx answer throws an `Error` naming the status only.
  - `importRecords`: one transaction. `payload_hash` = SHA-256 of the JSON with keys sorted. Upsert on `(source, source_ref)`: no row → insert with `status 'new'`; same hash → only `fetched_at` and `run_id` change (counted `unchanged`); other hash → replace `payload`, `payload_hash`, `source_url`, `fetched_at`, `run_id`, set `status 'new'`, clear `normalized`, `normalize_version`, `reject_reason`, keep `listing_id` (counted `updated`). `runId` = `newId()`. `dryRun` throws a private rollback error carrying the report, as `tools/firestore-import/load.ts` does.

- [ ] **Step 5: Run** `npx vitest run tools/studio-listings` and `npm run typecheck`. Expected: PASS.

- [ ] **Step 6: Commit** `feat(listings): manual and OpenStreetMap sources, raw import [#7]`.

---

### Task 6: Normalise and merge against the database

**Files:**
- Modify: `tools/studio-listings/store.ts`, `pipeline.ts`
- Test: `tools/studio-listings/pipeline.test.ts`

**Interfaces:**
- Consumes: `SOURCES`, `importRecords`; domain `normalizeListing`, `matchListing`, `mergeListing`, `listingQualityScore`, `LISTING_NORMALIZE_VERSION`, `LISTING_CITIES`.
- Produces:

```ts
export interface NormalizeReport { normalized: number; rejected: Record<ListingRejectReason, number> }
export async function runNormalize(db: Kysely<Database>, opts: { city: string; all?: boolean; dryRun?: boolean }): Promise<NormalizeReport>;
export interface MergeReport { created: number; updated: number; attached: number; suspects: number }
export async function runMerge(db: Kysely<Database>, opts: { now: Date; dryRun?: boolean }): Promise<MergeReport>;
```

- [ ] **Step 1: Write the failing tests** (database; a helper `seedFixtures(db, at = T0)` imports both fixture files with `importRecords` at fetch time `at`, and `full(db)` runs `runNormalize({ city: 'hcm' })` then `runMerge`):

```ts
it('the fixture set gives five listings, four rejections and one suspect', async () => {
  await seedFixtures(db);
  expect(await runNormalize(db, { city: 'hcm' })).toEqual({ normalized: 7,
    rejected: { not_photo_studio: 2, no_location: 1, outside_area: 1, invalid: 0 } });
  expect(await runMerge(db, { now: T0 })).toEqual({ created: 5, updated: 0, attached: 7, suspects: 1 });
  const rows = await listings(db);   // ordered by name
  expect(rows.map((r) => [r.name, r.area_code, r.status, r.quality_score])).toEqual([
    ['Kỷ Yếu Sài Gòn Photo', 'hcm-q3', 'draft', 0.9],
    ['Mimosa Wedding Studio', 'hcm-q1', 'draft', 1],
    ['Mimosa Wedding Studio - CN Thủ Đức', 'hcm-thu-duc', 'draft', 0.65],
    ['Nắng Studio', 'hcm-q7', 'draft', 0.25],
    ['Nắng Studio 2', 'hcm-q7', 'draft', 0.25],
  ]);
  expect(await specialtiesOf(db, 'Mimosa Wedding Studio')).toEqual([{ specialty_id: 'wedding', confidence: 0.9 }]);
  expect(await recordsOf(db, 'Mimosa Wedding Studio')).toEqual(['m1', 'node/101']);
  expect(await openSuspects(db)).toEqual([['Nắng Studio', 'Nắng Studio 2', 'phone']]);
});
it('a second full run changes nothing', async () => {
  await seedFixtures(db); await full(db);
  const before = await snapshot(db);          // every listing row incl. updated_at, specialties, suspects, record links
  await seedFixtures(db);                     // same records, same fetch time T0
  expect(await runNormalize(db, { city: 'hcm', all: true })).toMatchObject({ normalized: 7 });
  expect(await runMerge(db, { now: T1 })).toEqual({ created: 0, updated: 0, attached: 0, suspects: 0 });
  expect(await snapshot(db)).toEqual(before);
});
it('a later fetch of the same records only moves last_seen_at', async () => {
  await seedFixtures(db); await full(db);
  const before = await snapshot(db, { without: ['last_seen_at', 'updated_at'] });
  await seedFixtures(db, T1);
  await runNormalize(db, { city: 'hcm' }); await runMerge(db, { now: T1 });
  expect(await snapshot(db, { without: ['last_seen_at', 'updated_at'] })).toEqual(before);
  expect((await byName(db, 'Nắng Studio')).last_seen_at).toEqual(T1);
});
it('overrides win after a re-merge', async () => {
  await seedFixtures(db); await full(db);
  const id = await idOf(db, 'Mimosa Wedding Studio');
  await db.updateTable('studio_listings').set({ overrides: JSON.stringify({ phone: null, name: 'Mimosa' }) }).where('id', '=', id).execute();
  await runNormalize(db, { city: 'hcm', all: true }); await runMerge(db, { now: T1 });
  const row = await byId(db, id);
  expect([row.name, row.name_key, row.phone]).toEqual(['Mimosa', 'mimosa', null]);
});
it('a removed listing absorbs new records and stays hidden', async () => {
  await seedFixtures(db); await full(db);
  const id = await idOf(db, 'Nắng Studio');
  await db.updateTable('studio_listings').set({ status: 'hidden', hidden_reason: 'removal_request' }).where('id', '=', id).execute();
  await importRecords(db, [{ source: 'osm', sourceRef: 'node/900', sourceUrl: null,
    payload: { type: 'node', id: 900, lat: 10.7341, lon: 106.7220, tags: { name: 'Nang Studio', craft: 'photographer', phone: '0912345678' } } }], { now: T1 });
  await runNormalize(db, { city: 'hcm' });
  expect(await runMerge(db, { now: T1 })).toMatchObject({ created: 0 });
  expect((await byId(db, id)).status).toBe('hidden');
  expect(await countRows(db, 'studio_listings')).toBe(5);
});
it('a changed source record updates its listing', async () => {
  await seedFixtures(db); await full(db);
  const m3 = fixtureRecord('m3');
  await importRecords(db, [{ ...m3, payload: { ...(m3.payload as object), phones: ['028 3930 9999'] } }], { now: T1 });
  await runNormalize(db, { city: 'hcm' });
  expect(await runMerge(db, { now: T1 })).toMatchObject({ created: 0, updated: 1 });
  expect((await byId(db, await idOf(db, 'Kỷ Yếu Sài Gòn Photo'))).phone).toBe('+842839309999');
  expect(await countRows(db, 'studio_listings')).toBe(5);
});
it('a record that becomes rejected leaves its listing', async () => {
  await seedFixtures(db); await full(db);
  const m9 = fixtureRecord('m9');
  await importRecords(db, [{ ...m9, payload: { ...(m9.payload as object), name: 'Photocopy Nắng' } }], { now: T1 });
  await runNormalize(db, { city: 'hcm' }); await runMerge(db, { now: T1 });
  const e = await byName(db, 'Nắng Studio 2');
  expect([e.status, e.hidden_reason]).toEqual(['hidden', 'stale']);   // no source left
  expect(await openSuspects(db)).toEqual([]);
});
it('--dry-run of normalize and merge writes nothing', async () => {
  await seedFixtures(db);
  await runNormalize(db, { city: 'hcm', dryRun: true });
  expect(await countByStatus(db)).toEqual({ new: 11 });
  await runNormalize(db, { city: 'hcm' });
  expect(await runMerge(db, { now: T0, dryRun: true })).toMatchObject({ created: 5 });
  expect(await countRows(db, 'studio_listings')).toBe(0);
});
```

- [ ] **Step 2: Run** `npx vitest run tools/studio-listings/pipeline.test.ts`. Expected: FAIL.

- [ ] **Step 3: Implement `runNormalize`.** For every record with `status = 'new'` (or every record when `all`): `SOURCES[source]` unknown or `toIntermediate` null → `rejected`/`invalid`; else `normalizeListing(intermediate, { city, coordSource: source.coordSource })`. Write `normalized` (the value, as JSON), `normalize_version = LISTING_NORMALIZE_VERSION`, `status`, `reject_reason`. `city` must be a code of `LISTING_CITIES` (else throw before touching anything). A record whose stored `normalized` JSON is already equal and whose status does not change is not written (keeps `updated_at`).

- [ ] **Step 4: Implement `runMerge`** in one transaction, processing records ordered by `listingSourceRank(source)`, then `source_ref`:

  1. **Attach.** For each `normalized` record: if it already has `listing_id`, keep it. Otherwise load candidates = listings (any status) with `lat` within ±0.02 and `lng` within ±0.02 of the record, call `matchListing`; `sameAs` → set `listing_id`; else create a listing (`id = newId()`, `status 'draft'`, `first_seen_at = last_seen_at = now`) from the record alone and attach it. Collect the suspects.
  2. **Detach.** Records that are `rejected` (or `new`) and still have a `listing_id` lose it.
  3. **Rebuild** every listing that is `draft`, `published`, `hidden` or `claimed` (a few tens of thousands of rows at most; no change tracking): `mergeListing(sources, overrides)` → fields, specialties (replace the rows of `studio_listing_specialties`), `field_sources`, `quality_score` from `listingQualityScore` with the number of open suspect rows of the listing, `last_seen_at` = the latest `fetched_at` of its records. Write the row only when a value differs. `status`, `hidden_reason`, `claimed_by`, `overrides`, `published_at` are never changed here, with one exception: a listing in `draft` or `published` with no attached record left becomes `hidden` with reason `stale`, and its suspect rows are deleted.
  4. **Suspects.** Insert each new pair (smaller id first) with `on conflict do nothing`, so a `dismissed` pair stays dismissed.
  5. Report: `created` listings, `updated` listings (rows actually written, created ones excluded), `attached` records newly linked, `suspects` newly inserted.

- [ ] **Step 5: Run** `npx vitest run tools/studio-listings` and `npm run typecheck`. Expected: PASS.

- [ ] **Step 6: Commit** `feat(listings): normalise and merge source records into listings [#7]`.

---

### Task 7: Staff commands, the CLI and the docs

**Files:**
- Create: `tools/studio-listings/staff.ts`, `tools/studio-listings/cli.ts`
- Test: `tools/studio-listings/staff.test.ts`, `tools/studio-listings/cli.test.ts`
- Modify: `package.json` (script `"listings": "tsx tools/studio-listings/cli.ts"`), `AGENTS.md` (Commands and Tools paragraphs), `README.md` (one short section)

**Interfaces:**
- Consumes: Tasks 5–6.
- Produces:

```ts
// staff.ts
export async function reviewCsv(db: Kysely<Database>, opts: { city: string }): Promise<string>;
export async function publishListings(db, opts: { city: string; minScore: number; now: Date; dryRun?: boolean }): Promise<{ published: number }>;
export async function hideListing(db, id: string, reason: ListingHiddenReason): Promise<void>;
export async function editListing(db, id: string, set: Record<string, string | null>, now: Date): Promise<void>;
export async function mergeInto(db, keepId: string, dropId: string, now: Date): Promise<void>;
export async function dismissSuspect(db, a: string, b: string): Promise<void>;
export async function listingStats(db): Promise<{ byStatus: Record<string, number>; bySource: Record<string, number>; byCity: Record<string, number>; rejected: Record<string, number>; openSuspects: number }>;
// cli.ts
export async function runCli(argv: readonly string[], io: { db: Kysely<Database>; now: () => Date; out: (line: string) => void;
  readFile: (path: string) => Promise<string>; writeFile: (path: string, text: string) => Promise<void>; fetchFn: typeof fetch;
  env: Record<string, string | undefined> }): Promise<number>;   // exit code
```

- [ ] **Step 1: Write the failing tests** (database; `ready(db)` = `seedFixtures` then `full` from Task 6):

```ts
it('publish takes drafts at or above the score, in that city only, once', async () => {
  await ready(db);
  expect(await publishListings(db, { city: 'hcm', minScore: 0.7, now: T1 })).toEqual({ published: 2 });
  expect(await namesByStatus(db, 'published')).toEqual(['Kỷ Yếu Sài Gòn Photo', 'Mimosa Wedding Studio']);
  expect(await publishListings(db, { city: 'hcm', minScore: 0.7, now: T2 })).toEqual({ published: 0 });
  expect((await byName(db, 'Mimosa Wedding Studio')).published_at).toEqual(T1);
});
it('hidden, claimed and closed listings are never published', async () => {
  await ready(db);
  await hideListing(db, await idOf(db, 'Mimosa Wedding Studio'), 'removal_request');
  expect(await publishListings(db, { city: 'hcm', minScore: 0, now: T1 })).toEqual({ published: 4 });
});
it('edit stores an override and applies it at once; "" clears a field', async () => {
  await ready(db);
  const id = await idOf(db, 'Nắng Studio');
  await editListing(db, id, { name: 'Nắng Studio Quận 7', phone: '' }, T1);
  const row = await byId(db, id);
  expect([row.name, row.name_key, row.phone, row.overrides]).toEqual(['Nắng Studio Quận 7', 'nangquan7', null, { name: 'Nắng Studio Quận 7', phone: null }]);
  await expect(editListing(db, id, { status: 'published' }, T1)).rejects.toThrow(/cannot edit status/);
  await expect(editListing(db, id, { phone: '12345' }, T1)).rejects.toThrow(/invalid phone/);   // message has no number
});
it('merge-into moves the records, hides the dropped listing as duplicate and closes the suspect', async () => {
  await ready(db);
  const [d, e] = [await idOf(db, 'Nắng Studio'), await idOf(db, 'Nắng Studio 2')];
  await mergeInto(db, d, e, T1);
  expect(await recordsOf(db, 'Nắng Studio')).toEqual(['m8', 'm9']);
  expect([(await byId(db, e)).status, (await byId(db, e)).hidden_reason]).toEqual(['hidden', 'duplicate']);
  expect(await openSuspects(db)).toEqual([]);
  expect((await byId(db, d)).quality_score).toBe(0.8);   // 0.3 + 0.25 (two records) + 0.15 + 0.1
});
it('reviewCsv lists drafts with their sources and suspects', async () => {
  await ready(db);
  const rows = parseCsv(await reviewCsv(db, { city: 'hcm' }));
  expect(rows[0]).toEqual(['id', 'status', 'quality_score', 'name', 'address_line', 'area_code', 'lat', 'lng', 'phone',
    'website', 'facebook_url', 'specialties', 'sources', 'source_urls', 'suspect_of']);
  expect(rows).toHaveLength(6);
  const nang = rows.find((r) => r[3] === 'Nắng Studio')!;
  expect(nang[12]).toBe('manual');
  expect(nang[14]).toBe(await idOf(db, 'Nắng Studio 2'));
});
it('stats', async () => {
  await ready(db);
  expect(await listingStats(db)).toEqual({ byStatus: { draft: 5 }, bySource: { manual: 9, osm: 2 }, byCity: { hcm: 5 },
    rejected: { not_photo_studio: 2, no_location: 1, outside_area: 1 }, openSuspects: 1 });
});
// cli.test.ts: runCli with an in-memory io (out collects lines, readFile serves the fixtures)
it('the whole flow from the command line', async () => {
  expect(await cli('import', '--source', 'manual', '--file', 'manual-hcm.ndjson')).toBe(0);
  expect(await cli('collect', '--source', 'osm', '--area', 'hcm')).toBe(0);      // fetchFn answers with osm-hcm.json
  expect(await cli('normalize', '--area', 'hcm')).toBe(0);
  expect(await cli('merge')).toBe(0);
  expect(await cli('review', '--city', 'hcm', '--out', 'review.csv')).toBe(0);
  expect(await cli('publish', '--city', 'hcm', '--min-score', '0.7')).toBe(0);
  expect(await cli('stats')).toBe(0);
  expect(await namesByStatus(db, 'published')).toHaveLength(2);
  expect(written['review.csv']).toContain('Mimosa Wedding Studio');
});
it('command output carries no phone number', async () => {
  await runWholeFlow();
  expect(await cli('edit', await idOf(db, 'Nắng Studio'), '--set', 'phone=0999')).toBe(1);
  expect(out.at(-1)).toBe('error: invalid phone');
  const text = out.join('\n').replace(/[\s.\-()]/g, '');
  for (const digits of ['903123456', '2839301234', '911111111', '933333333', '912345678']) expect(text).not.toContain(digits);
});
it('usage errors and guards', async () => {
  expect(await cli()).toBe(2);
  expect(await cli('import', '--source', 'manual')).toBe(2);
  expect(await cli('normalize', '--area', 'nowhere')).toBe(2);
  expect(await cli('collect', '--source', 'facebook', '--area', 'hcm')).toBe(2);
  expect(await cli('publish', '--city', 'hcm', '--min-score', '2')).toBe(2);
  expect(await cliWithEnv({ NODE_ENV: 'production' }, 'merge')).toBe(2);
  expect(await cliWithEnv({ NODE_ENV: 'production' }, 'merge', '--yes-production')).toBe(0);
  expect(await cliWithEnv({ NODE_ENV: 'production' }, 'stats')).toBe(0);      // read-only commands are not guarded
});
```

- [ ] **Step 2: Run** `npx vitest run tools/studio-listings`. Expected: FAIL.

- [ ] **Step 3: Implement `staff.ts`.** Decisions:

  - `publishListings`: `status = 'draft'`, `city` equal, `quality_score >= minScore` → `status 'published'`, `published_at = now`. Nothing else is touched.
  - `hideListing`: sets `status 'hidden'` and the reason; allowed from any status except `claimed`.
  - `editListing`: editable keys are exactly the keys of `ListingFields` in snake_case as the CLI spells them: `name`, `address_line`, `lat`, `lng`, `website`, `phone`, `zalo`, `facebook_url`, `instagram_url`, `email`, `area_code`. Any other key throws `cannot edit <key>`. Values go through the same normalisers as source data (`cleanListingName`, `normalizeListingPhone`, `classifyListingUrl`, finite numbers inside the listing's city box); an invalid value throws `invalid <key>` without echoing the value; `''` stores `null`. The new overrides are merged into the stored `overrides`, then the listing is rebuilt with `mergeListing` exactly as in `runMerge` step 3, so the row and the override agree at once.
  - `mergeInto(keep, drop)`: move the records of `drop` to `keep`, rebuild `keep`, set `drop` to `hidden`/`duplicate`, delete the suspect row of the pair, recompute both scores. Refused when either listing is `claimed`.
  - `reviewCsv`: listings of the city in `draft` or `published`, ordered by `quality_score` ascending then name; `specialties` and `sources` joined with `|`; `suspect_of` = ids of open suspect partners joined with `|`.

- [ ] **Step 4: Implement `cli.ts`.** `runCli` parses `argv` and returns the exit code; the bottom of the file builds the real `io` (database from `DATABASE_URL`, `process.stdout`, `node:fs/promises`, global `fetch`) and sets `process.exitCode`. Commands and flags:

  ```
  listings import --source manual --file <path> [--dry-run]            format by extension: .csv, else NDJSON
  listings collect --source osm --area <city> [--dry-run]
  listings normalize --area <city> [--all] [--dry-run]
  listings merge [--dry-run]
  listings review --city <city> --out <path>
  listings publish --city <city> --min-score <0..1> [--dry-run]
  listings hide <id> [--reason staff|removal_request|duplicate|stale]   default staff
  listings edit <id> --set key=value [--set key=value …]
  listings merge-into <keepId> <dropId>
  listings dismiss <idA> <idB>
  listings stats
  ```
  Every command prints one short report through `io.out` (counts and ids only). A usage error prints the usage text and returns 2; a thrown error prints `error: <message>` and returns 1. Every command except `review` and `stats` returns 2 with `refusing to write with NODE_ENV=production (pass --yes-production)` when `io.env.NODE_ENV === 'production'` and the flag is absent. `collect` uses the box of the city from `LISTING_CITIES`.

- [ ] **Step 5: Add the npm script and the docs.** `AGENTS.md`: one line in Commands (`npm run listings -- import|collect|normalize|merge|review|publish|hide|edit|merge-into|dismiss|stats`) and a paragraph under **Tools** saying what the five stages are, that the rules are in `packages/domain/src/studio_listing*.ts`, that OpenStreetMap data is ODbL and must be credited ("© OpenStreetMap contributors") wherever a listing built from it is shown, and that phone numbers must not be printed. `README.md`: the pilot run as five commands.

- [ ] **Step 6: Run** `npm run typecheck && npm test` at the root, `npm run typecheck && npm run lint && npm test` in `packages/domain`. Expected: PASS.

- [ ] **Step 7: Commit** `feat(listings): staff commands and the listings CLI [#7]`.

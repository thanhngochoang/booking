# A1: Provider types (Photographer, Nhiếp ảnh gia, Studio) Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle or performance steps; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules` and adds Functions. Write the rules tests and the Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **Lanes:** Tasks 1–5 (domain, Functions, rules, self-hosted migration, `lib/data/**`, `lib/core/**`) are lane 2; Tasks 6–7 (`lib/features/**`, router, screen tests) are lane 1 and start after lane 2 merges Task 5 (gate **GA1**). Each lane step is its own unit on a `plan/a1-…` branch from `origin/develop`, claimed and run with the `run-next-plan` skill; ownership as in `RUN-ORDER.md` → "Two parallel lanes".

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** Every photographer profile has a provider type (`individual`, `artist` = the Nhiếp ảnh gia tier, `studio`); the app shows the matching mark and tag on cards, the profile and photo detail, the photographer chooses Cá nhân or Studio in setup step 1 (and a studio gives its address in step 4), and can switch later from Settings when nothing is in flight.

**Architecture:** `providerType` is a server-only field of `photographers/{uid}` (like `verified`): rules refuse it from clients and two callables write it, `setProviderType` and `setStudioAddress`, whose rules live in `packages/domain`. A missing field reads as `individual`, so no migration of Firestore data is needed. The `artist` value is never set here; plan B1 sets it from approved awards through the `recomputeArtistTier` hook this plan leaves. In the app, `PhotographerSummary` gains `providerType`, a pure `providerMarkOf` picks the mark, and core widgets `ProviderMark`, `ProviderTag` and `ProviderName` replace `VerifiedName` everywhere.

**Tech Stack:** TypeScript (domain, Functions v2), Firestore rules, Postgres migration (services/api, node-pg-migrate); Flutter, Riverpod 3, design tokens (`design-system/tokens.json` → `dart run tool/gen_tokens.dart`).

**Spec:** `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §1 (and §2.3 for what B1 adds later); `docs/superpowers/specs/screens/portfolio-awards.md` ("Thay đổi ở màn đã có": S02.06, S03.01 marks, S08.01); `docs/superpowers/specs/components/shared-components.md` → "Component của spec 10-05" (`ProviderMark`, `ProviderTag`); `docs/superpowers/specs/data-model/domain-model.md` §2.8 (`Photographer.providerType`, `StudioAddress`), §4 `ProviderType`; mock `docs/design/ui-mock.html` (block "Loại nhà cung cấp" in the design strip, `#S02.06-types`, `#S08.01-type`, `#S03.01-nag`).

**Prerequisite:** develop at or after PR #25 (spec 10-05). Nothing else.

## Contract with existing code

Task 1 Step 1 (lane 2) and Task 6 Step 1 (lane 1) check these exist; adapt and ledger any difference:

- Domain: `DomainError`, `ERROR_CODES` (`not_eligible`, `invalid_argument`, `permission_denied`, `not_found` exist), `Clock`, the booking statuses in `booking_machine.ts`, `EscrowStatus` codes, `packages/domain/src/index.ts` barrel, `test/purity.test.ts`.
- Functions: `CALLABLE_OPTIONS`, `REGION`, `toHttpsError`, `CallableInput`, `db()`, `callables/review.ts` as the pattern (handler `handleX(request, deps)` + `onCall(CALLABLE_OPTIONS, …)` in `index.ts`), `infra/live_*.ts` builders, `test/unit`, `test/integration` (project `demo-nag`), `seed/fixtures.ts`.
- Rules: `photographerClientFields()`, `photographerFieldsOk(uid)`, `verifiedUntouched()`, `hasPhotographerRole(uid)`, the `photographers/{uid}/private/{docId}` match (owner read; only `contact` writable), `rules-test/rules.test.mjs`.
- Self-hosted: `services/api/migrations/` (`<unix-seconds><seq>_<name>.sql`, `-- Up Migration` / `-- Down Migration`), `src/db/database.ts` `PhotographersTable`, `tools/firestore-import/map.ts` `mapPhotographer`, `test/migrations.test.ts` `EXPECTED`.
- App data: `PhotographerSummary` + `photographerSummaryFrom` (`lib/data/content/`), `PhotographerProfile` + `photographerProfileFrom` + `photographerProfileProvider` (`lib/data/photographer/`), `PhotographerIntro` + `SetupIntroController` (`lib/features/photographer_setup/`), the way existing app code calls a callable (find the booking or review repository's `FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable(...)` and copy it, including its error mapping to `DomainError`-like app errors).
- Core: `VerifiedMark`, `VerifiedName` (`lib/core/widgets/verified_mark.dart`), `PhotographerCard` (`lib/core/widgets/photographer_card.dart`), `AppOptionTile`, `showAppSheet`, `AppColors`, `core.dart` barrel, `scripts/tools/build_ui_components.py` + `docs/design/ui-components.html`.
- Features using `VerifiedName`: `features/photographer_profile/widgets/profile_header.dart`, `features/home/home_screen.dart`, `features/photo/photo_detail_screen.dart`; setup screens `setup_intro_screen.dart`, the S08.05 screen (find it under `features/photographer_setup/`); settings screen `features/settings/`.
- Screen codes: `ScreenCodes.setupProfile` (S08.01), `ScreenCodes.setupAreaContact` or the S08.05 constant, `ScreenCodes.settings` (S09.02).

## Global Constraints

- Types (spec 10-05 §1.1, verbatim): "`individual`" Photographer, "`artist`" Nhiếp ảnh gia — "**Chỉ server**, khi đủ điều kiện ở mục 2.3", "`studio`" Studio — "Tự chọn ở S08.01". "NAG là **hạng nâng cấp của `individual`**. Studio không lên NAG."
- Marks (verbatim): "Tích xanh tròn nếu đã xác minh (S21.02), không thì không có" / "Tích vàng tròn (thay tích xanh)" / "Con dấu viền răng cưa tích vàng, chỉ khi đã xác minh giấy phép kinh doanh". Tags: "Nhiếp ảnh gia" (vàng), trên thẻ kèm "· n giải"; "Studio" (kèm quận trên thẻ). Photographer: no tag.
- "Ba dấu khác nhau cả hình lẫn màu; nhãn chữ luôn đi kèm NAG và Studio để không chỉ dựa vào màu. `Semantics.label`: "Đã xác minh", "Nhiếp ảnh gia đã duyệt", "Studio đã xác minh"."
- Switching (verbatim): "Đổi Cá nhân ↔ Studio ở Cài đặt (S09.02 → "Hình thức nhận việc") **chỉ khi không còn booking chưa xong, báo giá đang mở hay tiền đang giữ**. Đổi sang Studio thì mất hạng NAG (giải thưởng vẫn giữ); đổi lại Cá nhân thì hạng NAG được tính lại ở mục 2.3."
- Studio (verbatim): "Chọn Studio thì "Tên hiển thị" thành "Tên studio" và S08.05 thêm **địa chỉ cơ sở** (bắt buộc, công khai tới mức quận; địa chỉ đầy đủ chỉ lộ sau khi đã đặt, như số điện thoại)."
- S08.01 copy (mock `#S08.01-type`): heading "Bạn nhận việc với tư cách"; "Cá nhân" — "Bạn tự chụp và nhận booking. Có giải thưởng? Thêm sau để lên hạng Nhiếp ảnh gia (NAG)."; "Studio" — "Cơ sở kinh doanh chụp ảnh, có địa chỉ. Thêm thành viên: sắp có."; note "Đổi Cá nhân ↔ Studio được trong Cài đặt khi không còn booking đang chạy."
- Gold tokens (mock CSS): dark `gold #E9C25A`, `goldSoft rgba(233,194,90,.12)`, `goldLine rgba(233,194,90,.5)`; light `gold #8A6410`, `goldSoft #FBF3DC`, `goldLine #D9B45A`; both `goldGradStart #F7D774`, `goldGradEnd #C9962B`, `goldInk #3A2A05`.
- Layering, strings (`app_vi.arb`, `flutter gen-l10n`), tokens (`AppColors`, never raw hex), imports (`package:photobooking/...`, features import `core/core.dart`), Firebase only in adapters, commit trailer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`; one primary action per screen; every `AsyncValue` through `AsyncView`.

## Decisions (where the spec is silent)

1. **Server-only field.** `providerType` is not in `photographerClientFields()`; a client write that sets, changes or removes it fails `hasOnly`. Absence means `individual` everywhere (rules, Functions, app, self-hosted import).
2. **`setProviderType({type})`** accepts `individual` or `studio` only (`artist` → `invalid_argument`). Same effective type (including `artist` asking for `individual`) → no-op, returns the current type. The caller must have no booking as photographer in `requested | accepted | upcoming` and no payment with `payeeId = caller` in `escrowStatus held | partially_refunded | disputed` — checked on every switch, setup included (ruling 2026-10-06 in unit 9a/1-L2: `onboardingComplete` is client-writable, so skipping the check during setup was a bypass; rules also refuse `onboardingComplete` true → false); otherwise `not_eligible` and nothing changes. (Open quotes join this check in plan D3.) To `studio`: writes `providerType: 'studio'`, deletes `artistSince`. To `individual` from `studio`: writes `individual`, then calls `recomputeArtistTier(uid)` (no-op hook here; plan B1 fills it).
3. **`setStudioAddress({line, ward?, district, city, lat?, lng?})`**: only when `providerType == 'studio'` (else `not_eligible`); `line` 5–120, `ward` ≤ 60, `district` and `city` 2–60 (trimmed), `lat`/`lng` both or neither, inside Vietnam's bounding box (lat 8–24, lng 102–110). Writes `photographers/{uid}/private/studioAddress` and public `studioDistrict`, `studioCity` on `photographers/{uid}`. Owner reads the private doc (existing match); the full address reaches customers later through the booking contact flow (not this plan).
4. **Finishing setup as a studio.** Rules: setting `onboardingComplete` to `true` while `providerType == 'studio'` needs `exists(private/studioAddress)`. S08.05 shows the address field and blocks "Hoàn tất" without it.
5. **Mark choice** `providerMarkOf(summary)`: `artist` → artist mark; `studio` and `verified` → studio seal; `verified` → blue tick; else no mark. A studio that is not verified shows only the tag.
6. **Name widget.** `ProviderName(summary-derived data)` replaces `VerifiedName`; `VerifiedName` stays as a thin wrapper `ProviderName(name, mark: verified ? ProviderMarkKind.verified : null)` for one release and is marked `@Deprecated`.
7. **Award count on tags** comes from `photographers/{uid}.approvedAwardCount` (written by plan B1; 0 or missing here → tag "Nhiếp ảnh gia" without "· n giải").
8. **Self-hosted parity.** The Postgres slice has `photographers`; this plan adds the columns and `studio_addresses` and maps them in the Firestore import. HTTP routes for the new callables are not added (the self-hosted API has no photographer write routes yet).
9. **Studio seal drawing.** 12-scallop path (same as the mock symbol `i-seal`): `M12 2.6Q15.21.02 16.7 3.86Q20.77 3.23 20.14 7.3Q23.98 8.79 21.4 12Q23.98 15.21 20.14 16.7Q20.77 20.77 16.7 20.14Q15.21 23.98 12 21.4Q8.79 23.98 7.3 20.14Q3.23 20.77 3.86 16.7Q.02 15.21 2.6 12Q.02 8.79 3.86 7.3Q3.23 3.23 7.3 3.86Q8.79.02 12 2.6Z` in a 24×24 box, filled with the gold gradient, check `m7.6 12.2 3 3 5.8-6.4` stroked `goldInk` width 2.4. Draw with `CustomPainter` (parse the path once with a small hand-written path builder; no SVG package).

## Review Focus

1. A client (or a tampered app) writes `providerType: 'artist'` or removes the field → the write is refused. Pinned by Task 2 rules tests ("owner cannot set providerType", "owner cannot remove providerType").
2. A photographer with a booking `accepted` (or money held) switches to Studio from Settings → refused with `not_eligible`, the profile keeps its type, and the sheet says why. Pinned by Task 1 ("an accepted booking blocks the switch", "held money blocks the switch") and Task 7 ("not eligible shows the reason and keeps the selection").
3. Old profiles without `providerType` → read as Photographer: blue tick when verified, no tag, no crash. Pinned by Task 4 ("missing providerType reads as individual") and Task 5 ("individual verified shows the blue tick only").
4. A studio tries to finish setup without an address (or the app crashes mid-flow and resumes at step 4) → "Hoàn tất" is blocked with the field error; the rules refuse `onboardingComplete: true` without the private address doc. Pinned by Task 2 ("studio cannot finish setup without an address") and Task 7 ("studio needs an address to finish").
5. After a switch the old mark lingers on the profile → the profile, card and own-profile providers refresh. Pinned by Task 7 ("switching invalidates the profile").

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/domain/src/provider_type.ts`, `provider_ports.ts`, `memory_provider_store.ts`, `set_provider_type.ts`, `studio_address.ts` (create) | types, ports, reference adapter, use cases |
| `packages/domain/test/provider_type.test.ts`, `set_provider_type.test.ts`, `studio_address.test.ts` | tests |
| `app_flutter/firebase/functions/src/infra/provider_firestore.ts`, `live_provider.ts`, `src/callables/provider.ts` (create); `src/index.ts` (modify) | adapters, wiring, callables |
| `app_flutter/firebase/functions/test/unit/provider_*.test.ts`, `test/integration/provider.test.ts` | tests |
| `app_flutter/firebase/firestore.rules`, `rules-test/rules.test.mjs` (modify) | server-only field, studio finish rule |
| `services/api/migrations/1791158400001_provider_type.sql` (create); `src/db/database.ts`, `tools/firestore-import/map.ts`, `test/migrations.test.ts`, map test (modify) | Postgres parity |
| `app_flutter/lib/data/content/provider_type.dart` (create); `photographer_summary.dart`, `firestore_photographer_repository.dart` (modify) | app enum, parsing |
| `app_flutter/lib/data/photographer/provider_repository.dart`, `callable_provider_repository.dart`, `provider_providers.dart` (create); `public_profile.dart`, `firestore_public_profile_repository.dart` (modify) | callables, studio fields |
| `design-system/tokens.json` (modify) → `lib/core/theme/tokens.g.dart` (generated) | gold tokens |
| `app_flutter/lib/core/widgets/provider_mark.dart` (create); `verified_mark.dart`, `photographer_card.dart`, `core.dart` (modify) | `ProviderMark`, `ProviderTag`, `ProviderName`, `providerMarkOf` |
| `scripts/tools/build_ui_components.py`, `docs/design/ui-components.html` (modify, regenerate) | gallery |
| `app_flutter/lib/features/photographer_profile/widgets/profile_header.dart`, `features/home/home_screen.dart`, `features/photo/photo_detail_screen.dart` (modify) | marks and tags |
| `app_flutter/lib/features/photographer_setup/setup_intro_screen.dart`, `setup_intro_controller.dart`, `intro_logic.dart`, the S08.05 screen/controller (modify) | type choice, studio address |
| `app_flutter/lib/features/settings/provider_type_sheet.dart` (create); settings screen (modify) | switch from Settings |
| `app_flutter/lib/l10n/app_vi.arb` (modify, one block at the end) | strings |
| tests under `test/data/**`, `test/core/widgets/**`, `test/features/**`; fakes in `lib/data/photographer/` and `test/support/` | |

---

### Task 1: Domain — provider type, `setProviderType`, `setStudioAddress`

**Files:**
- Create: `packages/domain/src/provider_type.ts`, `provider_ports.ts`, `memory_provider_store.ts`, `set_provider_type.ts`, `studio_address.ts`
- Modify: `packages/domain/src/index.ts`
- Test: `packages/domain/test/provider_type.test.ts`, `set_provider_type.test.ts`, `studio_address.test.ts`

**Interfaces:**
- Consumes: `DomainError`, `Clock`, booking status codes (`booking_machine.ts`), `EscrowStatus`.
- Produces:

```ts
export const PROVIDER_TYPES = ['individual', 'artist', 'studio'] as const;
export type ProviderType = (typeof PROVIDER_TYPES)[number];
/** Missing or unknown → 'individual'. */
export function providerTypeOf(raw: unknown): ProviderType;
/** 'artist' counts as 'individual' for choices and switches. */
export function chosenTypeOf(t: ProviderType): 'individual' | 'studio';

export interface ProviderProfile {
  readonly uid: string; readonly providerType: ProviderType; readonly onboardingComplete: boolean;
  readonly artistSince: Date | null; readonly studioDistrict: string | null; readonly studioCity: string | null;
}
export interface StudioAddress {
  readonly line: string; readonly ward: string | null; readonly district: string; readonly city: string;
  readonly lat: number | null; readonly lng: number | null;
}
export interface ProviderTx {
  getProfile(uid: string): Promise<ProviderProfile | null>;
  /** Bookings where photographerId = uid in requested | accepted | upcoming. */
  countActiveBookings(uid: string): Promise<number>;
  /** Payments where payeeId = uid in escrowStatus held | disputed. */
  countHeldPayments(uid: string): Promise<number>;
  setProviderType(uid: string, type: ProviderType, now: Date): void;     // also clears artistSince when type != 'artist'
  setStudioAddress(uid: string, a: StudioAddress, now: Date): void;      // private doc + public district/city
}
export interface ProviderStore { runTransaction<T>(fn: (tx: ProviderTx) => Promise<T>): Promise<T>; }
export interface ProviderDeps {
  readonly providers: ProviderStore; readonly clock: Clock;
  /** Plan B1 fills this; here a no-op. Runs after the transaction commits. */
  readonly recomputeArtistTier: (uid: string) => Promise<void>;
}

export function setProviderType(deps: ProviderDeps, callerId: string, raw: unknown): Promise<{ providerType: ProviderType }>;
/** invalid_argument per Decision 3. */
export function validateStudioAddress(raw: unknown): StudioAddress;
export function setStudioAddress(deps: ProviderDeps, callerId: string, raw: unknown): Promise<StudioAddress>;
```

`setProviderType` (sample, the order matters: all reads before writes, hook after commit):

```ts
const wanted = parseChoice(raw);                       // {type: 'individual' | 'studio'} else invalid_argument
const result = await deps.providers.runTransaction(async (tx) => {
  const p = await tx.getProfile(callerId);
  if (p === null) throw new DomainError('not_found');
  if (chosenTypeOf(p.providerType) === wanted) return { changed: false, type: p.providerType };
  const [bookings, held] = await Promise.all([tx.countActiveBookings(callerId), tx.countHeldPayments(callerId)]);
  if (bookings > 0 || held > 0) throw new DomainError('not_eligible');   // always, setup included (Decision 2)
  tx.setProviderType(callerId, wanted, deps.clock.now());
  return { changed: true, type: wanted as ProviderType };
});
if (result.changed && result.type === 'individual') await deps.recomputeArtistTier(callerId);
return { providerType: result.type };
```

- [ ] **Step 1: Contract check.** Confirm the names in "Contract with existing code" (domain part); ledger any difference and adapt the code below.
- [ ] **Step 2: Write the failing tests** (`node:test`, in-memory store from `memory_provider_store.ts`, a fixed clock):
  - `provider_type.test.ts`: "missing or unknown type reads as individual"; "artist is chosen as individual".
  - `set_provider_type.test.ts`: "a new profile with no open work switches"; "un-finishing setup does not bypass the check"; "the same choice is a no-op and writes nothing"; "artist asking for individual is a no-op"; "artist is refused as a choice" (`invalid_argument`); "an accepted booking blocks the switch" (`not_eligible`, type unchanged); "a requested booking blocks the switch"; "held money blocks the switch"; "a completed booking does not block"; "switching to studio clears artistSince"; "studio back to individual calls recomputeArtistTier once, after the write"; "unknown caller is not_found".
  - `studio_address.test.ts`: "a studio saves a trimmed address and the public district"; "an individual is not eligible"; "line shorter than 5 is invalid"; "lat without lng is invalid"; "a point outside Vietnam is invalid"; "ward is optional".
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → the new tests fail (modules missing).
- [ ] **Step 4: Implement** the five files and export them from `index.ts`. Keep `src/` free of Firebase and Node imports (`test/purity.test.ts`).
- [ ] **Step 5: Run** `(cd packages/domain && npm test && npm run lint)` → all pass.
- [ ] **Step 6: Commit** `feat(domain): provider types and studio address use cases [a1]`.

### Task 2: Functions callables and rules

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/provider_firestore.ts`, `src/infra/live_provider.ts`, `src/callables/provider.ts`
- Modify: `app_flutter/firebase/functions/src/index.ts`, `app_flutter/firebase/firestore.rules`, `app_flutter/firebase/rules-test/rules.test.mjs`, `app_flutter/firebase/functions/seed/fixtures.ts` (one studio and one artist photographer for later plans)
- Test: `app_flutter/firebase/functions/test/unit/provider_callables.test.ts`, `test/integration/provider.test.ts`

**Interfaces:**
- Consumes: Task 1 exports.
- Produces: callables `setProviderType` (`{type}` → `{providerType}`) and `setStudioAddress` (address → saved address), region `asia-southeast1`; Firestore fields `photographers/{uid}.providerType`, `.artistSince`, `.studioDistrict`, `.studioCity`; doc `photographers/{uid}/private/studioAddress {line, ward, district, city, lat, lng, updatedAt}`.

`FirestoreProviderStore` reads `photographers/{uid}`, counts with `where('photographerId','==',uid).where('status','in',['requested','accepted','upcoming']).limit(1)` on `bookings` and `where('payeeId','==',uid).where('escrowStatus','in',['held','disputed']).limit(1)` on `payments` (counts are 0/1; the use case only needs > 0), all inside `db().runTransaction`. Add the two composite indexes to `firestore.indexes.json` if the emulator asks for them (`bookings (photographerId, status)`, `payments (payeeId, escrowStatus)`).

Rules changes (sample):

```
// photographers/{uid}: server fields the client must never set, change or remove.
function photographerServerFieldsUntouched() {
  let changed = resource == null ? request.resource.data.keys()
                                 : request.resource.data.diff(resource.data).affectedKeys();
  return !changed.hasAny(['providerType', 'artistSince', 'studioDistrict', 'studioCity', 'approvedAwardCount']);
}
// A studio finishes setup only once its private address exists.
function studioFinishOk(uid) {
  let d = request.resource.data;
  return !(d.get('onboardingComplete', false) == true
           && d.get('providerType', 'individual') == 'studio'
           && (resource == null || resource.data.get('onboardingComplete', false) != true))
    || exists(/databases/$(database)/documents/photographers/$(uid)/private/studioAddress);
}
```

Add both to `match /photographers/{uid}` `create, update`. `photographerClientFields()` stays as is (the server fields are not in it, so `hasOnly` already refuses them; the explicit helper documents it and keeps the check if someone widens the list).

- [ ] **Step 1: Write the failing tests.**
  - Unit (`provider_callables.test.ts`, deps faked with the memory store): "unauthenticated is refused"; "domain errors map to HttpsError codes"; "setProviderType returns the new type".
  - Integration (`provider.test.ts`, emulator, do not run): "a photographer becomes a studio and the doc shows providerType"; "an accepted booking makes the switch failed-precondition"; "setStudioAddress writes the private doc and the public district".
  - Rules (`rules.test.mjs`, do not run): "owner cannot set providerType"; "owner cannot remove providerType"; "owner cannot set studioDistrict"; "studio cannot finish setup without an address"; "studio with an address can finish setup"; "individual finishes setup as before"; "others cannot read private/studioAddress".
- [ ] **Step 2: Run** `(cd app_flutter/firebase/functions && npm test)` → unit tests fail.
- [ ] **Step 3: Implement** the store, live deps (`recomputeArtistTier: async () => {}` with a comment pointing at plan B1), handlers and exports; the rules helpers.
- [ ] **Step 4: Run** `(cd app_flutter/firebase/functions && npm test && npm run build)` → pass. Ledger: integration and rules tests written, not run (CI).
- [ ] **Step 5: Commit** `feat(functions): setProviderType and setStudioAddress callables, server-only provider fields [a1]`.

### Task 3: Self-hosted parity (Postgres)

**Files:**
- Create: `services/api/migrations/1791158400001_provider_type.sql`
- Modify: `services/api/src/db/database.ts`, `services/api/tools/firestore-import/map.ts`, `services/api/test/migrations.test.ts`, the map test next to `map.ts`

**Interfaces:**
- Produces: columns `photographers.provider_type text not null default 'individual' check (provider_type in ('individual','artist','studio'))`, `artist_since timestamptz`, `studio_district text`, `studio_city text`, `approved_award_count int not null default 0`; table `studio_addresses (photographer_id text primary key references photographers(user_id) on delete cascade, line text not null, ward text, district text not null, city text not null, lat double precision, lng double precision, updated_at timestamptz not null default now())`. Down migration drops them. (DDL also in `relational-schema.md` §2.9.)

- [ ] **Step 1: Write the failing tests:** `migrations.test.ts` `EXPECTED` gains the columns and table ("photographers has provider_type …", existing structure); map test "a Firestore photographer without providerType maps to individual"; "studioAddress private doc maps to studio_addresses".
- [ ] **Step 2: Run** `(cd services/api && npm test)` → fail. (Testcontainers needs Docker; if the sandbox cannot run it, ledger it and run only the map unit test.)
- [ ] **Step 3: Implement** the migration, Kysely table types, `mapPhotographer` + a `mapStudioAddress`.
- [ ] **Step 4: Run** the tests → pass (or ledger the Docker skip).
- [ ] **Step 5: Commit** `feat(api): provider type columns and studio addresses [a1]`.

### Task 4: App data — `ProviderType`, summary fields, provider repository

**Files:**
- Create: `app_flutter/lib/data/content/provider_type.dart`, `app_flutter/lib/data/photographer/provider_repository.dart` (interface + `FakeProviderRepository`), `callable_provider_repository.dart`, `provider_providers.dart`
- Modify: `lib/data/content/photographer_summary.dart`, `firestore_photographer_repository.dart` (`photographerSummaryFrom`), `lib/data/photographer/public_profile.dart`, `firestore_public_profile_repository.dart`, `test/support/content_fixtures.dart` (`fixturePhotographer(..., providerType, approvedAwards, studioDistrict)`)
- Test: `test/data/content/provider_type_test.dart`, `test/data/content/firestore_photographer_repository_test.dart` (extend), `test/data/photographer/callable_provider_repository_test.dart`

**Interfaces:**
- Produces:

```dart
enum ProviderType {
  individual('individual'), artist('artist'), studio('studio');
  const ProviderType(this.code);
  final String code;
  /// Missing or unknown → individual.
  static ProviderType fromCode(Object? raw);
  /// artist is an individual for choices.
  ProviderChoice get choice;
}
enum ProviderChoice { individual, studio }

// PhotographerSummary gains (constructor defaults keep every existing call site compiling):
final ProviderType providerType;      // default ProviderType.individual
final int approvedAwardCount;         // default 0
final String? studioDistrict;

class StudioAddressInput { final String line; final String? ward; final String district; final String city; final double? lat; final double? lng; }

abstract class ProviderRepository {
  /// Throws ProviderError(code) with the server code ('not_eligible', 'invalid_argument', ...).
  Future<ProviderType> setType(ProviderChoice choice);
  Future<void> setStudioAddress(StudioAddressInput address);
  /// The owner's saved address (private doc), null when none.
  Future<StudioAddressInput?> myStudioAddress(String uid);
}
class ProviderError implements Exception { const ProviderError(this.code); final String code; }
final providerRepositoryProvider = Provider<ProviderRepository>(...);
```

- [ ] **Step 1: Contract check** (app data part, including how existing repositories call callables and map `FirebaseFunctionsException.details`/`code` to app errors).
- [ ] **Step 2: Write the failing tests:** "missing providerType reads as individual"; "unknown providerType reads as individual"; "artist reads with its award count"; "studio reads its district"; "setType sends the choice and returns the server type" (fake callable); "not_eligible from the server becomes ProviderError('not_eligible')".
- [ ] **Step 3: Run** `flutter test test/data` → fail.
- [ ] **Step 4: Implement.** `myStudioAddress` reads `photographers/{uid}/private/studioAddress` (owner rule).
- [ ] **Step 5: Run** `flutter analyze && flutter test test/data` → pass.
- [ ] **Step 6: Commit** `feat(data): provider type on photographer summaries and provider repository [a1]`.

### Task 5: Core — gold tokens, `ProviderMark`, `ProviderTag`, `ProviderName`, `PhotographerCard`

**Files:**
- Modify: `design-system/tokens.json` (then `dart run tool/gen_tokens.dart`), `app_flutter/lib/core/widgets/verified_mark.dart`, `photographer_card.dart`, `app_flutter/lib/core/core.dart`, `scripts/tools/build_ui_components.py` (+ regenerate `docs/design/ui-components.html`)
- Create: `app_flutter/lib/core/widgets/provider_mark.dart`
- Test: `test/core/widgets/provider_mark_test.dart`, `test/core/widgets/photographer_card_test.dart` (extend), `test/core/widgets/verified_mark_test.dart` (keep passing)

**Interfaces:**
- Consumes: Task 4 `ProviderType`, `PhotographerSummary.providerType/approvedAwardCount/studioDistrict/verified`.
- Produces:

```dart
enum ProviderMarkKind { verified, artist, studio }
/// Decision 5.
ProviderMarkKind? providerMarkOf({required ProviderType type, required bool verified});

class ProviderMark extends StatelessWidget {
  const ProviderMark(this.kind, {super.key, this.size});   // verified/artist 14, studio 16 by default
  final ProviderMarkKind kind; final double? size;
}
/// Pill under the name: artist "Nhiếp ảnh gia" (+ " · {n} giải" when awards > 0 and [showAwards]),
/// studio "Studio" (+ " · {district}" when [district] given). Renders SizedBox.shrink for individual.
class ProviderTag extends StatelessWidget {
  const ProviderTag({super.key, required this.type, this.awards = 0, this.district, this.showAwards = true});
}
/// Name + mark raised 3dp above the baseline (same layout as VerifiedName).
class ProviderName extends StatelessWidget {
  const ProviderName(this.name, {super.key, this.mark, this.style});
  final String name; final ProviderMarkKind? mark; final TextStyle? style;
}
```

Tokens: add the colours of Global Constraints as semantic tokens for both themes; `AppColors.gold`, `goldSoft`, `goldLine`, `goldInk`, `goldGradStart`, `goldGradEnd` (follow the existing token layout and generator; never hand-edit `tokens.g.dart`).

`PhotographerCard`: the name uses `ProviderName(mark: providerMarkOf(...))`, a `ProviderTag` line under the name for artist/studio (studio shows `studioDistrict`), and the semantics header reads the mark label ("Lê Hoàng Vũ, Nhiếp ảnh gia đã duyệt, 7 giải").

- [ ] **Step 1: Write the failing tests:** "individual verified shows the blue tick only"; "individual not verified shows no mark"; "artist shows the gold mark and the tag with awards"; "artist with no award count shows the tag without a count"; "verified studio shows the seal and the Studio tag with district"; "unverified studio shows only the tag"; "marks announce their labels" (`Đã xác minh`, `Nhiếp ảnh gia đã duyệt`, `Studio đã xác minh`); "mark kinds differ in shape" (golden-free check: the studio mark paints with the seal painter, the others with a circle); `PhotographerCard`: "card reads type and awards to screen readers"; "VerifiedName still renders the blue tick" (deprecated wrapper).
- [ ] **Step 2: Run** `flutter test test/core/widgets` → fail.
- [ ] **Step 3: Implement** tokens, widgets (seal per Decision 9), card change, exports, gallery entries (one tile per mark and tag in both themes).
- [ ] **Step 4: Run** `flutter analyze && flutter test test/core` → pass; regenerate the gallery with `python3 scripts/tools/build_ui_components.py`.
- [ ] **Step 5: Commit** `feat(core): provider marks and tags, gold tokens [a1]`. **Gate GA1.**

### Task 6: Lane 1 — marks on profile, home and photo detail

**Files:**
- Modify: `app_flutter/lib/features/photographer_profile/widgets/profile_header.dart`, `features/home/home_screen.dart`, `features/photo/photo_detail_screen.dart`
- Test: `test/features/photographer_profile/photographer_profile_screen_test.dart`, `test/features/home/…`, `test/features/photo/…` (extend the existing screen tests)

**Interfaces:**
- Consumes: Task 5 widgets, Task 4 summary fields.

Profile header (mock `#S03.01-nag`): name row `ProviderName` + `ProviderTag` on the line under the name (artist: "Nhiếp ảnh gia"; studio: "Studio"); the meta line keeps specialties · area, studio shows `studioDistrict`. The awards strip and the "giải thưởng" stat come with plan B1.

- [ ] **Step 1: Contract check** (lane 1 part) and replace every `VerifiedName(` call in features (`git grep -n "VerifiedName(" app_flutter/lib/features` must be empty after this task).
- [ ] **Step 2: Write the failing tests:** "artist profile shows the gold mark and the Nhiếp ảnh gia tag"; "studio profile shows the Studio tag and district"; "home free-this-week card shows the artist mark"; "photo detail author line shows the studio seal for a verified studio".
- [ ] **Step 3: Implement.** **Step 4: Run** `flutter analyze && flutter test test/features` → pass.
- [ ] **Step 5: Commit** `feat(profile): provider marks on profile, home and photo detail [a1]`.

### Task 7: Lane 1 — S08.01 type choice, S08.05 studio address, S09.02 switch

**Files:**
- Modify: `features/photographer_setup/setup_intro_screen.dart`, `setup_intro_controller.dart`, `intro_logic.dart`, `setup_draft_store.dart` (remember the choice in the draft), the S08.05 screen and controller; the settings screen (`features/settings/`)
- Create: `features/settings/provider_type_sheet.dart`
- Modify: `app_flutter/lib/l10n/app_vi.arb` (one block at the end)
- Test: `test/features/photographer_setup/setup_intro_screen_test.dart`, the S08.05 test, `test/features/settings/provider_type_sheet_test.dart`

**Interfaces:**
- Consumes: `ProviderRepository.setType/setStudioAddress/myStudioAddress`, `ProviderChoice`, `photographerProfileProvider`, `myIntroProvider` (or the own-profile provider S08.01 reads).
- Produces: `IntroInput.choice` (`ProviderChoice`, default from the profile, else individual); `SetupIntroController.save` calls `setType(choice)` first when it differs from the stored type, then the existing intro save; after any successful `setType` the controller invalidates `photographerProfileProvider(uid)` and the own-profile providers.

Behaviour:
- S08.01 (mock `#S08.01-type`): section "Bạn nhận việc với tư cách" with two `AppOptionTile`s (leading icon user / briefcase, title + body from Global Constraints), above the name field; Studio selected → label "Tên studio"; the note line under the fields. Errors from `setType` show under the section (`not_eligible`: "Còn booking chưa xong hoặc tiền đang giữ. Hoàn tất chúng trước khi đổi.").
- S08.05: when the stored type is `studio`, a required "Địa chỉ cơ sở" block (fields line, ward optional, district, city; district/city prefilled from the service area city when empty) above the contact block; "Hoàn tất" saves the address through `setStudioAddress` before the existing finish write; missing fields show inline errors and block finishing.
- S09.02: photographers see a row "Hình thức nhận việc · {Cá nhân | Studio}" (an artist shows "Cá nhân · Nhiếp ảnh gia") that opens `ProviderTypeSheet` (two `AppOptionTile`s, primary "Lưu", busy state on the button); `not_eligible` keeps the sheet open with the reason; a switch away from artist asks first with `showConfirmSheet` ("Đổi sang Studio sẽ bỏ hạng Nhiếp ảnh gia. Giải thưởng vẫn giữ.", red confirm "Đổi sang Studio").
- Strings (one arb block): `providerArtist` "Nhiếp ảnh gia", `providerStudio` "Studio", `providerArtistMark` "Nhiếp ảnh gia đã duyệt", `providerStudioMark` "Studio đã xác minh", `providerArtistAwards` "Nhiếp ảnh gia · {n} giải", `providerStudioDistrict` "Studio · {district}", `setupTypeHeading`, `setupTypeIndividual`, `setupTypeIndividualBody`, `setupTypeStudio`, `setupTypeStudioBody`, `setupTypeNote`, `setupStudioName` "Tên studio", `setupStudioAddress` "Địa chỉ cơ sở", `setupStudioLine` "Số nhà, đường", `setupStudioWard` "Phường / xã", `setupStudioDistrict` "Quận / huyện", `setupStudioCity` "Tỉnh / thành phố", `providerNotEligible`, `settingsProviderType` "Hình thức nhận việc", `settingsProviderArtist` "Cá nhân · Nhiếp ảnh gia", `providerLoseArtistBody`, `providerLoseArtistConfirm` "Đổi sang Studio". (`ProviderMark` labels in Task 5 use the first four; Task 5 adds those keys in its own arb block if lane 2 lands first — whichever task lands first adds them, the other reuses.)

- [ ] **Step 1: Write the failing tests:** S08.01 "choice defaults to Cá nhân"; "choosing Studio relabels the name field"; "saving calls setType only when the choice changed"; "not eligible shows the reason under the choice"; S08.05 "studio needs an address to finish"; "individual finishes without the address block"; settings "switching invalidates the profile"; "not eligible shows the reason and keeps the selection"; "an artist is asked before switching to Studio".
- [ ] **Step 2: Run** → fail. **Step 3: Implement** (strings in `app_vi.arb`, `flutter gen-l10n`). **Step 4: Run** `flutter analyze && flutter test` → pass.
- [ ] **Step 5: Update** the status cells for S08.01 and S03.01 in `remaining-screens.md` §2 ("loại nhà cung cấp: đã làm (a1)").
- [ ] **Step 6: Commit** `feat(setup): Cá nhân or Studio in setup, studio address, switch in settings [a1]`.

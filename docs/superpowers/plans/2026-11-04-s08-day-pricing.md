# S08 · Bảng giá theo ngày (S08.08–S08.10) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In this repo the unit runs through the `run-next-plan` skill (claim #316, branch `plan/316-…`, PR into `develop`).

**Goal:** Packages get a price per weekday (entered as weekday/weekend by default), an optional special-day price for public holidays and the photographer's own date ranges, and a redesigned package editor. A booking is priced by its day and keeps that price.

**Architecture:**
- **One pricing rule.** `priceForDay` lives in `packages/domain/src/day_pricing.ts`, with a Dart port in `lib/data/pricing/day_pricing.dart`. Both run the same case table (`packages/domain/test/fixtures/day_pricing_cases.json`), so they cannot drift apart.
- **Server.** `createBooking` reads the holidays and the provider's special days in its transaction, re-prices the service for the booking day, and everything downstream (snapshot, `expectedPrice`, add-on total, milestones) uses that price.
- **Data writes.** Packages and special days stay client-written under Firestore rules. Public holidays are server-only, written by a staff CLI.

**Tech Stack:** TypeScript domain (`node:test`), Cloud Functions (Firestore adapters, `tsx` CLI), Firestore rules + `@firebase/rules-unit-testing`, Flutter (Riverpod, go_router), `flutter_test` + `mocktail` + the fakes in `test/support/`.

**Spec:** `docs/superpowers/specs/2026-11-04-day-pricing-design.md` (approved by the owner 2026-11-04). Mock: `docs/design/ui-mock.html` (`#S08.08`, `#S08.09`, `#S08.09-perday`, `#S08.10`, `#S08.10-edit`, `#S08.01-packages`, `#S03.01-prices`, `#S04.01-dayprice`, `#S04.02-dayprice`, `#S04.03-dayprice`). Per-screen specs: `docs/superpowers/specs/screens/photographer.md` (S08.08–S08.10), `screens/booking.md` ("Giá theo ngày ở luồng đặt lịch").

## Global Constraints

**Data and pricing**
- `price` stays required and keeps its meaning: the weekday price, and the price of all 7 days when there is no `dayPrices`. No data migration (P8).
- `dayPrices`: a map with exactly the 7 keys `mon tue wed thu fri sat sun`. `specialPrice`: optional. `priceMode`: `two_levels` | `per_day`. `order`: optional, 0–999.
- Every price is an integer VND from 1 to 1,000,000,000.
- Days are `yyyy-MM-dd` in Asia/Ho_Chi_Minh. The weekday of a `LocalDate` uses the Gregorian calendar, never the machine's time zone.
- Price for a day: if the package has `specialPrice` and the day is special, `specialPrice`; otherwise the price of that weekday (P3).
- A day is special when it is in `holidays/{year}.days` or inside one of the provider's own `special_days` ranges.
- "từ {giá}" (`startingPrice`), the price filter and `SpotSchedule.priceFrom` use the lowest weekday price, **never** `specialPrice` (P6).
- Rescheduling keeps the paid price (P5).
- Add-ons, slot offers (S29), instant booking and quotes are unchanged (P7).

**Special days**
- `special_days` ranges: name 2–40 characters; `to ≥ from`; at most 60 days per range; `to` at most 365 days ahead; at most 20 ranges per provider (the app enforces this one).
- `holidays/{year}`: `{days: [{day, name}], updatedAt}`. Only the server writes it.

**Errors and money rules**
- Error codes come from the existing set: `price_changed`, `invalid_argument` (with field), `not_found`.
- Money rules are unchanged: 100% up front, held by the intermediary, released in two milestones.

**Project rules**
- Firebase only in data adapters. Imports `package:photobooking/...` and `core/core.dart`. Strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`. Tokens via `AppColors`/`AppSpace`/`AppRadius`. One primary action per screen.
- Commits end with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Rules tests are written but not run locally (CI runs them).
- No Blaze-only deploy steps.

## Review Focus

1. **Old app client books a weekend day** of a package that has a different weekend price. It sends `expectedPrice = price` and must get `price_changed`, never a booking at the wrong price. The test lives in Task 2.
2. **A booking made before the provider edits prices or adds a special range** keeps its `serviceSnapshot.price`, including after a reschedule. Tests in Task 2.
3. **Day near midnight or a year boundary:** 31/12 and 1/1, and a range that crosses into the next year, are priced from the right year's `holidays` doc. Task 1 covers this in the case table, Task 4 in the reader test.
4. **A package with all 7 day prices equal** is saved without `dayPrices` and shows a single price everywhere, not "1,5M–1,5M". Tests in Task 1 (`priceSummary`) and Task 8 (save).
5. **The editor's preview equals what the server charges** for the same day. Both sides run the shared case table, and Task 9 has a flow test where the `expectedPrice` sent equals the fake's priced day.

---

## File map

| Area | Create | Modify |
|---|---|---|
| Domain | `packages/domain/src/day_pricing.ts`, `packages/domain/test/day_pricing.test.ts`, `packages/domain/test/fixtures/day_pricing_cases.json` | `booking_ports.ts` (`ServiceRecord`, `SpecialDayReader`, `BookingDeps.specialDays`), `create_booking.ts`, `discovery_stats.ts`, `discovery_use_cases.ts`, `discovery_ports.ts`, `memory_discovery_store.ts`, `spot_schedule.ts` (`priceFromOf`), memory booking deps, `index.ts` |
| Functions | `src/infra/special_days_firestore.ts`, `tools/holidays.ts`, `test/unit/special_days_firestore.test.ts`, `test/unit/holidays_tool.test.ts` | `src/infra/booking_readers.ts` (`serviceRecordOf`), `src/infra/discovery_firestore.ts`, the wiring of `createBooking` deps, `package.json` (`holidays` script), `seed/fixtures.ts` (+ README), `seed_fixtures.test.ts` |
| Rules | — | `firestore.rules` (`validService`, `special_days`, `holidays`, server fields on `photographers`), `rules-test` S08 block |
| App data | `lib/data/pricing/day_pricing.dart`, `lib/data/pricing/special_days.dart` (models + `HolidayRepository`, `SpecialDayRepository`, fakes), `lib/data/pricing/firestore_special_days_repository.dart`, `lib/data/pricing/pricing_providers.dart`, `test/data/pricing/day_pricing_test.dart` | `lib/data/photographer/service_package.dart` (+ `firestore_service_package_repository.dart`), `photographer_summary.dart`, `firestore_photographer_repository.dart` |
| App screens | `lib/features/packages/` (S08.08 `my_packages_screen.dart`, S08.09 `package_edit_screen.dart` + controller, S08.10 `special_days_screen.dart` + `special_day_sheet.dart`, `widgets/package_price_line.dart`, `widgets/price_table_sheet.dart`) | `app/router.dart`, `photographer_setup/setup_packages_screen.dart` (+ controller, `package_logic.dart`), profile "Sửa gói" entries, `work/work_screen.dart` (entry row), `addons/addons_screen.dart` (link), `booking/steps/service_step.dart`, `datetime_step.dart`, `review_step.dart`, `booking_flow_controller.dart`/`booking_flow_state.dart`, `core/widgets/photographer_card.dart`, `lib/core/screen_codes.dart` (already has S08.08–S08.10), `app_vi.arb` |
| Docs | `docs/superpowers/handover/ledger-day-pricing.md` | `docs/superpowers/specs/2026-10-01-remaining-screens.md` (status cells S08.08–S08.10) |

---

### Task 1: Domain pricing rule and shared case table

**Files:**
- Create: `packages/domain/src/day_pricing.ts`, `packages/domain/test/day_pricing.test.ts`, `packages/domain/test/fixtures/day_pricing_cases.json`
- Modify: `packages/domain/src/booking_ports.ts` (`ServiceRecord`), `packages/domain/src/index.ts`

**Interfaces:**
- Produces:
  ```ts
  export type Weekday = 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat' | 'sun';
  export const WEEKDAYS: readonly Weekday[];                 // mon … sun
  export interface PricedService { readonly price: number; readonly dayPrices?: Readonly<Record<Weekday, number>>; readonly specialPrice?: number }
  export interface SpecialDays { readonly holidays: readonly string[]; readonly ranges: readonly { from: string; to: string }[] }
  export const NO_SPECIAL_DAYS: SpecialDays;
  export type DayPriceKind = 'weekday' | 'weekend' | 'special';
  export function weekdayOf(day: string): Weekday;
  export function isSpecialDay(day: string, special: SpecialDays): boolean;
  export function weekPrices(s: PricedService): Record<Weekday, number>;
  export function priceForDay(s: PricedService, day: string, special: SpecialDays): { amount: number; kind: DayPriceKind };
  export function priceRange(s: PricedService): { min: number; max: number };
  export type PriceSummary =
    | { kind: 'single'; min: number; max: number; special?: number }
    | { kind: 'two_levels'; weekday: number; weekend: number; min: number; max: number; special?: number }
    | { kind: 'per_day'; min: number; max: number; special?: number };
  export function priceSummary(s: PricedService): PriceSummary;
  export function normalizeDayPrices(p: Record<Weekday, number>): { price: number; dayPrices?: Record<Weekday, number> }; // drops dayPrices when all 7 equal
  export function validateServicePrices(input: { price: unknown; dayPrices?: unknown; specialPrice?: unknown }): void; // DomainError('invalid_argument', 'price' | 'dayPrices' | 'specialPrice')
  export const MAX_PRICE = 1_000_000_000;
  ```
- `ServiceRecord` gains `readonly dayPrices?: Readonly<Record<Weekday, number>>; readonly specialPrice?: number`, so it satisfies `PricedService`.

**Rules the code must follow:**
- `kind` of `priceForDay` is `'special'` only when `specialPrice` is set and the day is special. Otherwise it is `'weekend'` for sat/sun and `'weekday'` for the rest.
- `priceSummary` returns `two_levels` when mon–fri are equal, sat = sun, and the two values differ; `single` when all 7 are equal; `per_day` otherwise.
- `weekdayOf` uses `Date.UTC(y, m-1, d)` and `getUTCDay()`.

- [ ] **Step 1: Write the case table** `day_pricing_cases.json`, an array of `{name, service, special, day, amount, kind}`. Include at least these cases:
  - a single price on Monday and on Sunday;
  - two levels: Friday 13/11/2026 → 1,500,000 `weekday`; Saturday 14/11/2026 → 1,800,000 `weekend`;
  - per day: Friday 3,500,000;
  - a holiday with `specialPrice` → `special`; a holiday without `specialPrice` → that weekday's price;
  - a range: first day, last day, the day after;
  - 31/12/2026 (Thursday) and 1/1/2027 (Friday);
  - 29/02/2028 (Tuesday).
- [ ] **Step 2: Write `day_pricing.test.ts`.** It loops over the JSON and asserts `priceForDay(...)` deep-equals `{amount, kind}`. Add named tests:
  - `weekdayOf covers all seven days of 9–15/11/2026`;
  - `priceRange ignores specialPrice`;
  - `priceSummary single when 7 equal`;
  - `priceSummary two_levels for 1.5M/1.8M`;
  - `priceSummary per_day when Friday differs`;
  - `normalizeDayPrices drops dayPrices when equal and sets price = mon`;
  - `validateServicePrices rejects a missing key, 0, 1.5, 1_000_000_001, a non-object dayPrices`.
- [ ] **Step 3: Run** `(cd packages/domain && npm test -- --test-name-pattern=day_pricing)`. Expected: FAIL (module missing).
- [ ] **Step 4: Implement** `day_pricing.ts`; add the `ServiceRecord` fields; export everything from `index.ts`.
- [ ] **Step 5: Run** `npm test && npm run lint && npm run typecheck` in `packages/domain`. Expected: all pass.
- [ ] **Step 6: Commit** `feat(domain): day pricing rule and shared case table [#316]`

### Task 2: Domain booking uses the day price

**Files:**
- Modify: `packages/domain/src/booking_ports.ts`, `packages/domain/src/create_booking.ts`, the memory booking deps used by `create_booking.test.ts` (and `reschedule` tests if they build deps), `packages/domain/src/index.ts`
- Test: `packages/domain/test/create_booking.test.ts`, `packages/domain/test/reschedule.test.ts`

**Interfaces:**
- Consumes: `priceForDay`, `SpecialDays`, `NO_SPECIAL_DAYS` (Task 1).
- Produces:
  - `export interface SpecialDayReader { specialDays(providerId: string, day: string): Promise<SpecialDays> }`. It returns the holidays of `day`'s year and the provider's ranges with `to ≥ day`.
  - `BookingDeps.specialDays: SpecialDayReader`.
  - A memory implementation, `MemorySpecialDayReader` (`setHolidays(year, days)`, `addRange(providerId, from, to)`).

**Change in `createBooking`:**
- On the package path (not the slot-offer path), after the service read, set `service = { ...s, price: priceForDay(s, input.day, await deps.specialDays.specialDays(input.photographerId, input.day)).amount }`. Do this before the `expectedPrice` and add-on checks.
- `buildBookingDraft` is unchanged: it already snapshots `service.price`.

- [ ] **Step 1: Write the failing tests** in `create_booking.test.ts`:
  - `prices a Saturday booking with the weekend price` (service 1.5M/1.8M, day 2026-11-14 → `serviceSnapshot.price === 1_800_000`, `deposit === 1_800_000`);
  - `prices a holiday with specialPrice` (2,200,000);
  - `expectedPrice equal to the weekday price on a weekend day is price_changed`;
  - `add-on total is checked against the day price` (`expectedTotal` = 1.8M + add-on passes);
  - `a slot-offer booking ignores dayPrices and special days`.
  In `reschedule.test.ts`: `rescheduling a weekday booking to Saturday keeps serviceSnapshot.price and deposit`.
- [ ] **Step 2: Run** the domain tests. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the port, the `createBooking` change and the memory reader. Pass `specialDays` in every place that builds `BookingDeps` (tests and memory composition).
- [ ] **Step 4: Run** `npm test && npm run lint && npm run typecheck`. Expected: pass.
- [ ] **Step 5: Commit** `feat(domain): booking priced by its day [#316]`

### Task 3: Domain starting price, weekend-from and spot price-from

**Files:**
- Modify: `packages/domain/src/discovery_ports.ts`, `discovery_use_cases.ts`, `discovery_stats.ts`, `memory_discovery_store.ts`, `spot_schedule.ts`
- Test: `packages/domain/test/discovery_use_cases.test.ts`, `discovery_stats.test.ts`, `spot_schedule.test.ts`

**Interfaces:**
- Consumes: `priceRange`, `priceSummary`, `PricedService` (Task 1).
- Produces:
  - Port: `activeServicePrices(uid): Promise<number[]>` is replaced by `activeServicePricings(uid): Promise<PricedService[]>`.
  - `computePriceStats(services: readonly PricedService[]): { startingPrice: number | null; weekendFrom: number | null; hasSpecialPrices: boolean }`:
    - `startingPrice` = min of `priceRange(s).min`;
    - `weekendFrom` = min over services of `min(weekPrices.sat, weekPrices.sun)`, but only when that is greater than `startingPrice`, else `null`;
    - `hasSpecialPrices` = any `specialPrice`.
  - `refreshStartingPrice` writes all three through `statsPatch`. `PhotographerStatsSnapshot` and the patch gain `weekendFrom` and `hasSpecialPrices`.
  - `priceFromOf` uses `priceRange(s).min` instead of `s.price`.

- [ ] **Step 1: Write the failing tests:**
  - `computePriceStats: 1.5M/1.8M and 3.2M single → startingPrice 1.5M, weekendFrom 1.8M`;
  - `weekendFrom null when every weekend equals the lowest weekday`;
  - `specialPrice never lowers startingPrice`;
  - `refreshStartingPrice writes weekendFrom and hasSpecialPrices only when changed`;
  - `priceFromOf uses the lowest weekday price of a per-day package`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement**, keeping `computeStartingPrice` (other callers) as a thin wrapper.
- [ ] **Step 4: Run** domain `npm test && npm run lint && npm run typecheck`. Expected: pass.
- [ ] **Step 5: Commit** `feat(domain): starting price and weekend-from from day prices [#316]`

### Task 4: Functions adapters, wiring and rules

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/special_days_firestore.ts`, `test/unit/special_days_firestore.test.ts`
- Modify: `src/infra/booking_readers.ts` (`serviceRecordOf` reads `dayPrices` when it has exactly 7 numeric keys, and `specialPrice` when it is a positive int; anything else is ignored, so a malformed doc falls back to `price`), `src/infra/discovery_firestore.ts` (`activeServicePricings`: `select('price','dayPrices','specialPrice')`), the place that builds `createBooking` deps (pass `new FirestoreSpecialDayReader(db)`), `test/unit/booking_readers.test.ts`, `test/unit/discovery_firestore.test.ts`
- Modify: `app_flutter/firebase/firestore.rules`, `app_flutter/firebase/rules-test/` (new S08 day-pricing block)

**Interfaces:**
- Consumes: `SpecialDayReader`, `SpecialDays` (Task 2); `activeServicePricings` (Task 3).
- Produces: `class FirestoreSpecialDayReader implements SpecialDayReader`. It reads `holidays/{yyyy}` (missing doc → no holidays) and `photographers/{uid}/special_days` where `to >= day`, limit 20, keeping only ranges with `from <= day`. It runs inside the booking transaction when the caller passes a transaction (follow how `FirestoreServiceCatalog` is used there).

**Rules:**
- `validService` allows the extra keys `dayPrices`, `specialPrice`, `priceMode`, `order`:
  - `dayPrices` is a map with `keys().hasOnly([...7])` and `size() == 7`, each value `is int` and in 1..1000000000;
  - `specialPrice` is int, 1..1000000000;
  - `priceMode` is in `['two_levels','per_day']`;
  - `order` is int, 0..999.
- `match /photographers/{uid}/special_days/{id}`: read if signed in; create/update if `isOwner(uid) && hasPhotographerRole(uid)` and:
  - the keys are only `name, from, to, createdAt, updatedAt`;
  - `name` is 2–40 characters;
  - `from` and `to` are strings matching `^\d{4}-\d{2}-\d{2}$`, with `to >= from` (string compare);
  - the range is at most 60 days, checked with `timestamp.date(...)`;
  - `to` is at most 365 days ahead.

  Delete if owner.
- `match /holidays/{year}`: read if signed in; write false.
- `photographerServerFieldsUntouched()` adds `weekendFrom` and `hasSpecialPrices`.

- [ ] **Step 1: Write the failing unit tests:**
  - `serviceRecordOf keeps a 7-key dayPrices and drops a 6-key one`;
  - `serviceRecordOf ignores specialPrice 0`;
  - `FirestoreSpecialDayReader returns the year's holidays and only ranges covering the day` (fake Firestore as in the other infra tests);
  - `FirestoreSpecialDayReader reads holidays/2026 for 2026-12-31 and holidays/2027 for 2027-01-01`;
  - `activeServicePricings maps dayPrices`.
- [ ] **Step 2: Write the rules tests** in the S08 block (not run locally):
  - owner writes a package with 7 `dayPrices`;
  - a 6-key `dayPrices` is denied; a `specialPrice` of 0 is denied;
  - another user cannot write `special_days`; a 61-day range is denied;
  - no client writes `holidays`;
  - the owner cannot write `weekendFrom`.
- [ ] **Step 3: Run** `(cd app_flutter/firebase/functions && npm run lint && npm run typecheck && npm test)`. Expected: the new unit tests FAIL.
- [ ] **Step 4: Implement** the adapters, the wiring and the rules.
- [ ] **Step 5: Run** the same command, plus `npm run build`. Expected: pass. Say in the PR that the rules tests run in CI.
- [ ] **Step 6: Commit** `feat(functions): day-priced bookings, special-day reader and rules [#316]`

### Task 5: Holidays CLI and seed

**Files:**
- Create: `app_flutter/firebase/functions/tools/holidays.ts`, `test/unit/holidays_tool.test.ts`
- Modify: `app_flutter/firebase/functions/package.json` (script `"holidays": "tsx tools/holidays.ts"`), `seed/fixtures.ts`, `seed/README.md`, `test/unit/seed_fixtures.test.ts`

**Interfaces:**
- Produces:
  - `npm run holidays -- set <year> --file <path.json>` (JSON `[{day, name}]`; every `day` must be in `<year>`, valid, unique; sorted on write);
  - `npm run holidays -- list <year>`.

  Follow `tools/spots.ts` for argument parsing, the emulator/Admin guard and output style. Export the pure `parseHolidayFile(year: number, raw: unknown): {day: string; name: string}[]` for the test.
- Seed:
  - `holidays/2026` and `holidays/2027`: Tết, Giỗ Tổ, 30/4–1/5, 2/9–3/9 with the dates in the mock;
  - the seed photographer An's "Chân dung 2 giờ" gets `dayPrices` 1.5M/1.8M, `priceMode: 'two_levels'`, `specialPrice: 2_200_000`;
  - one `special_days` range "Mùa cưới tháng 11" 2026-11-14 → 2026-11-22.

- [ ] **Step 1: Write the failing tests:**
  - `parseHolidayFile rejects a day from another year, duplicates and a bad date, and sorts`;
  - seed tests: `holidays/2026 has Tết`, `An's portrait package has two-level dayPrices`.

  Update any earnings or totals assertion that a changed seed price breaks: the seed's existing bookings keep their stored snapshots, so they should not change.
- [ ] **Step 2: Run** `npm test`. Expected: FAIL.
- [ ] **Step 3: Implement** the tool, the script and the seed.
- [ ] **Step 4: Run** `npm run lint && npm run typecheck && npm test`. Expected: pass.
- [ ] **Step 5: Commit** `feat(functions): holidays CLI and day-pricing seed [#316]`

### Task 6: App data: package model, pricing port and special days

**Files:**
- Create:
  - `app_flutter/lib/data/pricing/day_pricing.dart` (Dart port of Task 1: `Weekday` enum `mon…sun`, `PricedService`, `SpecialDays`, `weekdayOf(DateTime day)` on the date part, `priceForDay`, `weekPrices`, `priceRange`, `PriceSummary` sealed class, `normalizeDayPrices`);
  - `lib/data/pricing/special_days.dart` (`Holiday {day, name}`, `SpecialDayRange {id, name, from, to}`, `abstract class HolidayRepository { Future<List<Holiday>> forYear(int year); }`, `abstract class SpecialDayRepository { Stream<List<SpecialDayRange>> watch(String uid); Future<void> save(String uid, SpecialDayRange r); Future<void> delete(String uid, String id); }`, plus `FakeHolidayRepository` and `FakeSpecialDayRepository`);
  - `lib/data/pricing/firestore_special_days_repository.dart`;
  - `lib/data/pricing/pricing_providers.dart` (`holidaysProvider(year)`, `specialDaysProvider(uid)`, `specialDaysForBookingProvider((providerId, year))` returning `SpecialDays`);
  - `test/data/pricing/day_pricing_test.dart`, `test/data/pricing/special_days_repository_test.dart`.
- Modify:
  - `lib/data/photographer/service_package.dart`: `ServicePackage` and `ServicePackageInput` gain `Map<Weekday,int>? dayPrices`, `int? specialPrice`, `PriceMode priceMode` (enum `PriceMode { twoLevels, perDay }`, codes `two_levels`/`per_day`, default `twoLevels`), `int? order`. `ServicePackage` implements `PricedService`. The map↔doc conversions handle these fields. `ServicePackageRepository` gains `Future<void> reorder(String uid, List<String> idsInOrder)`, and the fake implements it.
  - `firestore_service_package_repository.dart`: writes `normalizeDayPrices` output (all equal → no `dayPrices`); `watchMine` sorts by `order` then `createdAt`; `reorder` uses one batch.
  - `lib/data/content/photographer_summary.dart` + `firestore_photographer_repository.dart`: add `weekendFromVnd`, `hasSpecialPrices`.

**Interfaces:**
- Consumes: the Firestore shapes from Tasks 4–5.
- Produces: the names above, used by Tasks 7–9.

- [ ] **Step 1: Write the failing tests:**
  - `day_pricing_test.dart` loads `../packages/domain/test/fixtures/day_pricing_cases.json` (path relative to `app_flutter/`, read with `File`) and asserts every case;
  - `servicePackageFromMap reads dayPrices and specialPrice`;
  - `toMap drops dayPrices when all equal`;
  - `FakeServicePackageRepository.reorder sets order 0..n-1`;
  - `firestore special days repository maps from/to strings` (with `fake_cloud_firestore` if the project already uses it, else through the fake).
- [ ] **Step 2: Run** `flutter test test/data/pricing test/data/photographer` (env from AGENTS.md). Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter analyze` and the same tests. Expected: pass.
- [ ] **Step 5: Commit** `feat(data): day prices on packages, special days and pricing port [#316]`

### Task 7: S08.08 Gói dịch vụ của tôi and S08.10 Ngày đặc biệt

**Files:**
- Create: `lib/features/packages/my_packages_screen.dart`, `lib/features/packages/special_days_screen.dart`, `lib/features/packages/special_day_sheet.dart`, `lib/features/packages/widgets/package_price_line.dart`, tests in `test/features/packages/`
- Modify: `lib/app/router.dart` (`/me/packages`, `/me/special-days`); the profile "Sửa gói" entry (`photographer_profile_screen.dart` `edit-packages`, `widgets/profile_sections.dart`) → `/me/packages`; `work/work_screen.dart` (row "Gói và bảng giá"); `addons/addons_screen.dart` (link "Gói dịch vụ"); `app_vi.arb`

**Interfaces:**
- Consumes: `ServicePackageRepository.watchMine/update/reorder` (Task 6), `priceSummary`, `holidaysProvider`, `specialDaysProvider`, `SpecialDayRepository`.
- Produces: `PackagePriceLine(ServicePackage p)`, the widget that renders the summary line. It is used again in Tasks 8 and 9.

**Behaviour:** as in `screens/photographer.md` S08.08 and S08.10, and the mock frames `#S08.08`, `#S08.10`, `#S08.10-edit`.
- Turning off the last active package asks first.
- Drag to reorder calls `reorder`.
- The S08.10 sheet validates against the global constraints (60 days, 365 days ahead, 20 ranges) and deletes after a red confirmation sheet.

- [ ] **Step 1: Write the failing widget tests:**
  - `PackagePriceLine renders "1.500.000₫", "T2–T6 1,5M · T7–CN 1,8M · Lễ 2,2M" and "3,2M–4M · theo ngày"`;
  - `S08.08 lists packages with switches and shows the special-days row counts`;
  - `turning off the last active package asks first`;
  - `reorder by drag calls reorder with the new ids`;
  - `S08.10 shows the year's holidays and the user's ranges`;
  - `the sheet rejects a 61-day range and a range beyond 365 days`;
  - `delete asks with a red button`.

  Wrap each screen in `ScreenCode(ScreenCodes.myPackages/specialDays, …)`.
- [ ] **Step 2: Run** the tests. Expected: FAIL.
- [ ] **Step 3: Implement** the screens, routes, entry points and strings (`s0808_*`, `s0810_*` from `screens/photographer.md`), then `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter analyze` and the tests. Expected: pass.
- [ ] **Step 5: Commit** `feat(packages): S08.08 my packages and S08.10 special days [#316]`

### Task 8: S08.09 Thêm/sửa gói and S08.01 step 2

**Files:**
- Create: `lib/features/packages/package_edit_screen.dart`, `lib/features/packages/package_edit_controller.dart`, tests in `test/features/packages/`
- Modify: `lib/app/router.dart` (`/me/packages/new`, `/me/packages/:id`, query `from=setup`); `photographer_setup/setup_packages_screen.dart` (remove the inline form, list with `PackagePriceLine`, "Thêm gói" → S08.09 `?from=setup`); `setup_packages_controller.dart` and `package_logic.dart` (move validation to the edit controller; keep the draft store for the edit screen); `app_vi.arb`; the existing setup-packages tests

**Interfaces:**
- Consumes: Task 6 models and `normalizeDayPrices`, `priceForDay`, `PackagePriceLine` (Task 7).
- Produces: `PackageEditController` (Riverpod `AsyncNotifier`) with the state `{name, durationMinutes, editedCount, deliveryDays, mode, weekday, weekend, perDay: Map<Weekday,int?>, specialOn, specialPrice}` and the methods:
  - `setMode(PriceMode)` — returns `needsCollapseConfirm` when per-day values are not two levels;
  - `setWeekday(int)` — also fills `weekend` when it is still untouched;
  - `setDay(Weekday,int)`, `setSpecial(bool,int?)`, `save()`.

**Behaviour:** `screens/photographer.md` S08.09 and the mock `#S08.09`, `#S08.09-perday`, `#S08.01-packages`.
- The 7-day preview uses `priceForDay` with the user's own special days and holidays.
- The tab label is "Hai mức giá".
- Saving stores `price` = Monday, `dayPrices` through `normalizeDayPrices`, `specialPrice` only when the switch is on, and `priceMode`.

- [ ] **Step 1: Write the failing tests:**
  - `typing the weekday price first fills the weekend`;
  - `two levels → per day fills 7 values`;
  - `per day with Friday 3.5M → two levels asks and uses Monday/Saturday`;
  - `all seven equal saves without dayPrices`;
  - `special switch off saves without specialPrice`;
  - `preview marks 14/11 weekend 1,8M and 17/11 Lễ 2,2M` (fake holidays);
  - `errors: name length, price 0, price > 1e9`;
  - `from=setup returns to /setup/2 after save`;
  - `setup step 2 needs ≥ 1 package to continue and opens S08.09 for add`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement** with strings `s0809_*`, then `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter analyze` and `dart run tool/affected_test.dart origin/develop --run`. Expected: pass.
- [ ] **Step 5: Commit** `feat(packages): S08.09 package editor with day prices; setup step 2 uses it [#316]`

### Task 9: Customer side: profile, S04.01–S04.03 and cards

**Files:**
- Create: `lib/features/packages/widgets/price_table_sheet.dart` (S03.01-prices), tests
- Modify: the S03.01 package tab card (in `photographer_profile/widgets/…`), `booking/steps/service_step.dart`, `booking/steps/datetime_step.dart`, `booking/steps/review_step.dart`, `booking_flow_state.dart` / `booking_flow_controller.dart` (day price, `priceKind`, `expectedPrice` from `priceForDay`), `core/widgets/photographer_card.dart` (`· T7–CN từ {weekendFrom}`, dropped first when narrow), `app_vi.arb`, the existing booking-flow and card tests

**Interfaces:**
- Consumes: `priceForDay`, `priceRange`, `priceSummary`, `specialDaysForBookingProvider` (Task 6); `PackagePriceLine` (Task 7); `PhotographerSummary.weekendFromVnd`.
- Produces: `BookingFlowState.dayPrice` (`({int amount, DayPriceKind kind, String? specialName})?`).
  - It is recomputed when the package or the day changes.
  - The flow sends `expectedPrice = dayPrice.amount` and `expectedTotal = dayPrice.amount + add-ons`.
  - Before a day is chosen, S04.01 shows "Tiếp tục · từ {min}".

**Behaviour:** `screens/booking.md` "Giá theo ngày ở luồng đặt lịch" and the mock `#S03.01-prices`, `#S04.01-dayprice`, `#S04.02-dayprice`, `#S04.03-dayprice`. Calendar cells show the short price only when it differs from the weekday price; special days show "Lễ {giá}". The existing `price_changed` bar is reused.

- [ ] **Step 1: Write the failing tests:**
  - `S04.01 shows 1,5M–1,8M and "T7–CN 1,8M" and the button "Tiếp tục · từ 1.500.000₫"`;
  - `entering with a chosen Saturday shows 1.800.000₫`;
  - `S04.02 shows 1,8M under weekend days and "Lễ 2,2M" under 17/11, nothing for a single-price package`;
  - `S04.02 button follows the selected day + add-ons`;
  - `S04.03 line reads "Gói Chân dung 2 giờ · T7 14/11 (cuối tuần)"`;
  - `createBooking receives expectedPrice 1_800_000 for 14/11`;
  - `price table sheet groups equal weekdays ("Thứ 2 – Thứ 6")`;
  - `PhotographerCard shows "· T7–CN từ 1,8M" when weekendFrom is set and wide enough`.
- [ ] **Step 2: Run** them. Expected: FAIL.
- [ ] **Step 3: Implement** with the strings listed in `screens/booking.md`, then `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter analyze` and the affected tests. Expected: pass.
- [ ] **Step 5: Commit** `feat(booking): day prices in S03.01 and S04.01–S04.03 [#316]`

### Task 10: Handover

**Files:**
- Create: `docs/superpowers/handover/ledger-day-pricing.md` (rulings, deferred items, cross-unit notes for #169 S28.06 and #299/booking-be: new fields, the `special_days`/`holidays` collections, the `holidays` CLI)
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md`: status cells of S08.08–S08.10, and the S08.01, S03.01, S04.01–S04.03 notes linking the PR.

- [ ] **Step 1:** Run the full checks. Expected: all pass.
  - From `app_flutter/`: `flutter analyze && dart run tool/affected_test.dart origin/develop --run`.
  - `(cd ../packages/domain && npm test && npm run lint && npm run typecheck)`.
  - `(cd firebase/functions && npm run lint && npm run typecheck && npm test && npm run build)`.
- [ ] **Step 2:** Write the ledger and the status cells.
- [ ] **Step 3: Commit** `docs(packages): day pricing ledger and screen status [#316]`

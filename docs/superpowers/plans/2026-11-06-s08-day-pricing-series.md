# S08 · Price series with lunar calendar (S08.08–S08.10, #316 redo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. In this repo the unit runs through the `run-next-plan` skill (claim #316, branch `plan/316-day-pricing-series` in **both** repos, booking-be PR lands first, then the app PR into `develop`).

**Goal:** Replace the #326 day-pricing model (`dayPrices`, `specialPrice`, `priceMode`, `holidays/{year}`, `special_days`) with one base price per package plus recurring **price series** (`price_rules`) that work like Google Calendar events: a one-off range, weekly, or yearly by solar or lunar date, with per-day exceptions and "this day / this and following / whole series" edits. Add a shared `AppCalendar` that always shows the lunar day, and use it on every screen that has a calendar or date picker.

**Spec:** `docs/superpowers/specs/2026-11-06-day-pricing-redesign.md` (R1–R14, §4 data, §5 screens, §6 tests). Mock: `docs/design/ui-mock.html` ids `#S08.08`, `#S08.08-sort`, `#S08.09`, `#S08.10`, `#S08.10-new`, `#S08.10-repeat`, `#S08.10-day`, `#S08.10-list`, `#S08.01-packages`, `#S03.01-prices`, `#S04.01-dayprice`, `#S04.02-dayprice`, `#S04.03-dayprice`. Per-screen specs: `docs/superpowers/specs/screens/photographer.md` (S08.08–S08.10), `screens/booking.md` ("Giá theo ngày ở luồng đặt lịch (#316)"). Read the mock section of a screen before building it: `grep -n 'id="S08.10' docs/design/ui-mock.html`.

**Architecture:**
- **One pricing rule, two languages.** `packages/domain/src/lunar.ts` + `day_pricing.ts` (TS) and `lib/core/lunar.dart` + `lib/data/pricing/price_rules.dart` (Dart) implement the same functions and run the same case table (`packages/domain/test/fixtures/day_pricing_cases.json`, copied to `app_flutter/test/data/contracts/day_pricing_cases.json`).
- **Price is computed on read** (R13). Nothing stores a price per day. The only stored derived value is `photographers/{uid}.startingPrice` (+ `hasDayPricing`), written by the domain use case `refreshPriceSummary`.
- **Server-only writes** (R10). The app never writes `price_rules`. It calls four callables (`savePriceRule`, `splitPriceRule`, `setPriceRuleException`, `deletePriceRule`) that run domain use cases inside one Firestore transaction each. Rules deny every client write.
- **Ports, not Firestore.** `PriceRuleReader` (createBooking, discovery) and `PriceRuleStore` (use cases) are domain ports; Firestore adapters live in `firebase/functions/src/infra`. The Phase 2 Kysely adapters will implement the same ports (spec §4.6; no SQL migration in this unit).

**Tech stack:** TypeScript domain (vitest/node:test as the package already uses), Cloud Functions v2 (`onCall`, `onDocumentWritten`, `onSchedule`, region `asia-southeast1`), Firestore rules + `@firebase/rules-unit-testing`, Flutter (Riverpod, go_router, freezed), `flutter_test` + `mocktail` + fakes in `test/support/`.

## Global Constraints

**Data (spec §4.1)**
- `photographers/{uid}/price_rules/{id}`: `serviceId`, `price` (int 1–1,000,000,000), `name?` (≤ 40), `repeat` ∈ `none|weekly|yearly`, `lunar?` (only `yearly`), `from`/`to` (`none`: `yyyy-MM-dd`; `yearly`: `MM-dd`, lunar main month when `lunar`; `to < from` = crosses the year; `weekly`: absent), `weekdays?` (`mon`…`sun`, 1–7, only `weekly`), `start?`/`until?` (`yyyy-MM-dd`), `exceptions?` (map `yyyy-MM-dd` → int | null, ≤ 50), `template?`, `createdAt`, `updatedAt`.
- Server-only helper field `endsOn?` (`yyyy-MM-dd`): the last day the rule can apply (`to` for `none`, `until` when set, the smaller of both). Written by the store on every write, read only by the daily job. Not part of the domain `PriceRule` and not in the Postgres target (a SQL job can compute it). **Ruling of the plan writer.**
- Packages keep only `price` for pricing. `validService` (rules) and the domain refuse `dayPrices`, `specialPrice`, `priceMode`, `occasionPrices`. `order` stays.
- Gone for good (R1): `holidays/{year}`, `photographers/{uid}/special_days`, CLI `holidays`, `SEED_HOLIDAYS`, `weekendFrom`, `hasSpecialPrices`. No compatibility path (#326 never reached `main`).

**Pricing (R3, R5, R9, R14)**
- Price of a day: the package's rules that cover the day after `start`/`until` and exceptions; tier `none` > `yearly` > `weekly`; highest tier wins; same tier → highest price; none → `price`. An exception with a price uses that price at its rule's tier; an exception `null` removes the day from that rule. Invalid exception values (not an int 1–1e9 and not null) are ignored when reading.
- Lunar: Hồ Ngọc Đức algorithm, time zone +7. `solarToLunar` returns `{day, month, year, leap}`. Yearly lunar rules match the **main** month only; days in a leap month never belong to a lunar rule. A lunar range may cross the lunar year (12-23 → 01-05). Convert each day to lunar **once**, then compare against every lunar rule.
- `startingPrice(services, rules)` = min over active packages of min(`price`, price of every rule of that package that still has a next occurrence from today, including exception prices that are still ahead). Drop `none` rules whose `to` has passed and rules whose `until` has passed. The same number is the lower bound of the price range on S03.01 and S04.01 and `SpotSchedule.priceFrom`.
- Booking keeps `serviceSnapshot.price` (day price), adds `priceKind` (`base` | `rule`) and `ruleName?`, server-written. Reschedule keeps the price.
- Limits: ≤ 30 rules per package (`failed_precondition` `rule_limit`), ≤ 50 exceptions per rule (`exception_limit`); `none`/`yearly` span ≤ 92 days; `none`: `to ≥ from`, `to ≥ today` on create, `from ≤ today + 730`; `until ≥ start`; `weekdays` 1–7 distinct; `serviceId` must be one of the caller's packages. Errors: `DomainError('invalid_argument', <field>)` or `DomainError('failed_precondition', 'rule_limit' | 'exception_limit')`.
- R8 "Mọi gói, cùng tỉ lệ": for each other package, `price = ceil(otherPrice × input / currentPrice / 10_000) × 10_000`, capped at 1,000,000,000. Exceptions are not copied.

**Days and time**
- Days are `yyyy-MM-dd` strings in Asia/Ho_Chi_Minh; weekday from the Gregorian date, never the machine time zone. "Today" comes from the domain `Clock` (server) or the app clock provider.

**Project rules (both repos)**
- Commits: Conventional Commits, each ending with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never a Claude co-author line).
- booking-be: `packages/domain` has no Firebase or Node imports. Callables are thin: auth check, call the domain use case, map errors through `handleCallableError`.
- App: imports `package:photobooking/...`; features import `core/core.dart`; Firebase only in `lib/data/**` adapters; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; tokens `AppColors`/`AppSpace`/`AppRadius`; icons `AppIcons`; one primary action per screen; mock wins for layout and copy, spec for behaviour.
- Rules tests are written, not run locally (CI runs them). No deploys, no `firebase` CLI against real projects, no device builds.
- Never commit `scripts/start-emulator.sh`, `app_flutter/firebase/` or `packages/` from the main booking checkout (other work). Work only in the unit worktrees.

## Review Focus

1. **Server and app agree on every day's price.** Both run `day_pricing_cases.json`; Task A6 has a flow test where `expectedPrice` sent equals the domain's price for a Tết day, a weekend day, and a weekend day removed from the weekend series by an exception.
2. **Lunar correctness**: Tết 2024–2033, Giỗ Tổ, leap month 2025 (month 6, 2025-07-25 = 1/6 nhuận) excluded from lunar rules, a lunar range crossing the lunar new year maps to the right solar range of each year, a solar range crossing 31/12 gives two ranges in one year.
3. **Split keeps the past**: `splitPriceRule` never changes the price of a day before `day`; a booking made before any edit keeps its snapshot.
4. **No client write path**: rules deny create/update/delete on `price_rules` for the owner too; callables refuse a `serviceId` or `ruleId` of another provider.
5. **startingPrice** goes down when a cheaper weekly rule is added and back up the day after a cheaper one-off rule ends (daily job).
6. **Every calendar shows the lunar day**: the 16 screens of spec §5.7 still pick dates and show the lunar number.

---

## File map

| Area | Create | Modify | Delete |
|---|---|---|---|
| Domain (booking-be) | `packages/domain/src/lunar.ts`, `price_rule_ports.ts`, `price_rule_use_cases.ts`, `memory_price_rules.ts`, tests `lunar.test.ts`, `price_rule_use_cases.test.ts` | `day_pricing.ts` (rewrite), `test/day_pricing.test.ts`, `test/fixtures/day_pricing_cases.json` (rewrite), `booking_ports.ts`, `booking.ts` (snapshot), `create_booking.ts`, `discovery_stats.ts`, `discovery_ports.ts`, `discovery_use_cases.ts`, `memory_discovery_store.ts`, `spot_schedule.ts`, spot use cases that call `priceFromOf`, `index.ts`, `test/support/booking_world.ts` and tests that build `ServiceRecord`s with `dayPrices`/`specialPrice` | `memory_special_days.ts` |
| Functions | `src/infra/price_rules_firestore.ts`, `src/infra/live_price_rules.ts`, `src/callables/price_rule.ts`, `src/triggers/price_rule_write.ts`, `src/scheduled/expire_price_rules.ts`, `tools/cleanup_day_pricing_v1.ts`, tests `price_rules_firestore.test.ts`, `price_rule_callables.test.ts` | `src/index.ts`, `src/infra/live_booking.ts`, `booking_readers.ts` (`serviceRecordOf`), `discovery_firestore.ts`, `src/triggers/service_write.ts`, `seed/fixtures.ts` + `seed/README.md` + `seed_fixtures.test.ts`, `package.json`, `firebase/firestore.indexes.json` | `src/infra/special_days_firestore.ts`, `tools/holidays.ts`, `test/unit/special_days_firestore.test.ts`, `test/unit/holidays_tool.test.ts` |
| Rules | — | `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs` (S08 block) | — |
| App data | `lib/core/lunar.dart`, `lib/data/pricing/price_rules.dart` (model + pure functions + templates), `lib/data/pricing/price_rule_repository.dart` (interface + fake), `lib/data/pricing/firestore_price_rule_repository.dart`, tests `test/core/lunar_test.dart`, `test/data/pricing/price_rules_test.dart`, `test/data/pricing/firestore_price_rule_repository_test.dart` | `lib/data/pricing/pricing_providers.dart`, `lib/data/pricing/day_pricing.dart` (keeps only `Weekday`, `weekdayOf`, `kMaxPriceVnd` at the end), `lib/data/photographer/service_package.dart` + firestore repo, `lib/data/content/service_summary.dart`, `photographer_summary.dart`, `firestore_photographer_repository.dart`, `lib/data/booking/booking.dart` (snapshot `priceKind`, `ruleName`), `test/data/contracts/day_pricing_cases.json` + README | `lib/data/pricing/special_days.dart`, `firestore_special_days_repository.dart` (Task A9) |
| App widgets | `lib/core/widgets/app_calendar.dart` (+ `showAppDatePicker`, `showAppDateRangePicker`), `test/core/widgets/app_calendar_test.dart` | `lib/core/core.dart` (exports), `lib/core/widgets/availability_calendar.dart` (built on `AppCalendar`) | — |
| App screens | `lib/features/day_pricing/` (`day_pricing_screen.dart` S08.10, `price_rule_sheet.dart` S08.10-new/repeat, `price_day_sheet.dart` S08.10-day, `price_rules_screen.dart` S08.10-list, `day_pricing_controller.dart`, `rule_text.dart`) | `lib/features/packages/my_packages_screen.dart` (S08.08 + sort mode), `package_edit_screen.dart` + controller (S08.09), `widgets/package_price_line.dart`, `widgets/price_table_sheet.dart` (S03.01), `photographer_setup/setup_packages_screen.dart`, `app/router.dart`, booking flow (`booking_flow_state.dart`, `booking_flow_controller.dart`, `booking_day_price.dart`, `steps/service_step.dart`, `steps/datetime_step.dart`, `steps/review_step.dart`), booking detail price line, `core/widgets/photographer_card.dart`, the 15 calendar screens of spec §5.7, `lib/l10n/app_vi.arb`, `lib/core/screen_codes.dart` | `lib/features/packages/special_days_screen.dart`, `special_day_sheet.dart`, `special_day_rules.dart` |
| Docs | `docs/superpowers/handover/ledger-day-pricing-series.md` | `docs/superpowers/specs/2026-10-01-remaining-screens.md` (S08.08–S08.10 status), `docs/superpowers/specs/data-model/domain-model.md` (price rules paragraph, no SQL change) | — |

Order: B1 → B2 → B3 → B4 → B5 (booking-be), then A1 … A9 (app). A1 needs B2's case table. A3 is independent of A2 and can run in parallel with it.

---

## Part B · booking-be (`plan/316-day-pricing-series` from booking-be `origin/develop`)

### Task B1: Lunar calendar (TS)

**Files:** create `packages/domain/src/lunar.ts`, `packages/domain/test/lunar.test.ts`; modify `index.ts`.

**Produces:**
```ts
export interface LunarDate { readonly day: number; readonly month: number; readonly year: number; readonly leap: boolean }
export function solarToLunar(day: string): LunarDate;                       // day 'yyyy-MM-dd'
export function lunarToSolar(day: number, month: number, year: number, leap?: boolean): string | null; // null: no such leap month
export function lunarLabel(day: string): string;                            // "6"; "1/10" on the 1st of a month
export function leapMonthOf(lunarYear: number): number | null;              // 2025 → 6, 2028 → 5, 2031 → 3
export function lunarMonthLength(month: number, year: number, leap?: boolean): 29 | 30;
```

- [ ] Port the algorithm from the reference implementation below (Hồ Ngọc Đức, tz = 7). It is the one the spec was checked with; keep integer math (`Math.floor`) exactly where it floors.

  Reference (Python, the session's verified copy): `jd_from_date`, `jd_to_date`, `new_moon(k)`, `sun_longitude(jdn)`, `get_sun_longitude(dayNumber, tz) = floor(sun_longitude(dayNumber - 0.5 - tz/24) / π * 6)`, `get_new_moon_day(k, tz) = floor(new_moon(k) + 0.5 + tz/24)`, `get_lunar_month11(yy, tz)`, `get_leap_month_offset(a11, tz)`, `solar_to_lunar`, `lunar_to_solar`. The well-known published JS version of the same algorithm (`amlich.js`, function names `jdFromDate`, `jdToDate`, `NewMoon`, `SunLongitude`, `getSunLongitude`, `getNewMoonDay`, `getLunarMonth11`, `getLeapMonthOffset`, `convertSolar2Lunar`, `convertLunar2Solar`) is equivalent; Python `int()` truncates toward zero, JS `Math.floor` floors: all inputs here are positive, so they agree.
- [ ] Tests (from the case table, Task B2 adds the JSON; here assert directly): Tết (1/1) = 2024-02-10, 2025-01-29, 2026-02-17, 2027-02-06, 2028-01-26, 2029-02-13, 2030-02-02, 2031-01-23, 2032-02-11, 2033-01-31; Giỗ Tổ (10/3) 2025-04-07, 2026-04-26; 23/12 before Tết 2026 = 2026-02-10; mùng 5 Tết 2026 = 2026-02-21; `solarToLunar('2025-07-25')` is in leap month 6 (`leap: true`); `lunarToSolar(1, 6, 2025, true)` is not null and `lunarToSolar(1, 7, 2025, true)` is null; round trip solar → lunar → solar for every day 2024-01-01 … 2033-12-31; `lunarLabel('2026-11-09')` = "1/10", `lunarLabel('2026-11-23')` = "15"; `lunarLabel` on a non-first day is the bare number.
- [ ] `npm test` in `packages/domain`. Commit `feat(domain): lunar calendar (Hồ Ngọc Đức, UTC+7) [#316]`.

### Task B2: Price rules pure functions and the shared case table

**Files:** rewrite `packages/domain/src/day_pricing.ts`, `test/day_pricing.test.ts`, `test/fixtures/day_pricing_cases.json`; modify `index.ts`.

**Produces:**
```ts
export type Weekday = 'mon'|'tue'|'wed'|'thu'|'fri'|'sat'|'sun'; export const WEEKDAYS; export const MAX_PRICE = 1_000_000_000;
export function weekdayOf(day: string): Weekday;                 // keep
export type Repeat = 'none' | 'weekly' | 'yearly';
export interface PriceRule {
  readonly id: string; readonly serviceId: string; readonly price: number; readonly name?: string;
  readonly repeat: Repeat; readonly lunar?: boolean; readonly from?: string; readonly to?: string;
  readonly weekdays?: readonly Weekday[]; readonly start?: string; readonly until?: string;
  readonly exceptions?: Readonly<Record<string, unknown>>; readonly template?: string;
}
export interface PricedService { readonly id: string; readonly price: number; readonly active?: boolean }
export type DayPrice = { amount: number; kind: 'base' | 'rule'; rule?: PriceRule };
export function parsePriceRule(id: string, raw: unknown): PriceRule | null;   // tolerant read: null when unusable
export function ruleRanges(rule: PriceRule, year: number): { from: string; to: string }[];
export function ruleCoversDay(rule: PriceRule, day: string, lunar?: LunarDate): { covers: boolean; price?: number };
export function priceForDay(service: PricedService, rules: readonly PriceRule[], day: string): DayPrice;
export function monthPrices(service: PricedService, rules: readonly PriceRule[], year: number, month: number): Record<string, DayPrice>;
export function nextOccurrence(rule: PriceRule, today: string): { from: string; to: string } | null; // running or next range; null when ended
export function priceBounds(service: PricedService, rules: readonly PriceRule[], today: string): { min: number; max: number };
export function startingPrice(services: readonly PricedService[], rules: readonly PriceRule[], today: string): number | null;
export function splitRule(rule: PriceRule, day: string, newPrice: number | null, newId: string): { before: PriceRule; after: PriceRule | null };
export function withException(rule: PriceRule, day: string, price: number | null | 'clear'): PriceRule;
export function scaledPrice(input: number, fromServicePrice: number, toServicePrice: number): number; // R8 rounding
export function scaledRule(rule: PriceRule, fromService: PricedService, toService: PricedService, newId: string): PriceRule;
export function validatePriceRule(rule: PriceRule, ctx: { today: string; serviceIds: readonly string[]; creating: boolean }): void;
export const MAX_RULES_PER_SERVICE = 30; export const MAX_EXCEPTIONS = 50; export const MAX_SPAN_DAYS = 92; export const MAX_AHEAD_DAYS = 730;
export interface PriceRuleTemplate { readonly code: string; readonly name: string; readonly repeat: 'yearly'; readonly lunar: boolean; readonly from: string; readonly to: string; readonly group: 'holiday' | 'occasion' }
export const PRICE_RULE_TEMPLATES: readonly PriceRuleTemplate[];   // spec §4.3, 11 entries, in that order
```

Semantics:
- `ruleRanges(yearly, year)`: solar → `[{from: year-from, to: year-to}]`, or two ranges when `to < from` (`year-01-01 … year-to` and `year-from … year-12-31`). Lunar → convert the lunar `from`/`to` of the lunar years that overlap the Gregorian `year` (lunar year `year-1` and `year`), clip to `[year-01-01, year-12-31]`, drop empty; a lunar day that does not exist (30 in a 29-day month) uses the last day of that month. `none` → the range if it touches `year`. `weekly` → `[]` (not range-based).
- `ruleCoversDay`: outside `[start, until]` → not covered; exception key present: `null` → not covered, valid int → covered with that price, invalid value → ignore the exception; otherwise `weekly` by weekday, `none` by range, `yearly` solar by `MM-dd` within from…to (wrap when `to < from`), `yearly` lunar by `lunar.month/day` (main month only: `leap` → not covered) within from…to with wrap. Accept a precomputed `lunar` to avoid converting per rule.
- `priceForDay`: compute `solarToLunar(day)` once; tiers `none` 3, `yearly` 2, `weekly` 1; pick highest tier, then highest price; ties on price → the earlier rule in input order. Only rules with `serviceId === service.id`.
- `splitRule(rule, day, newPrice, newId)`: `before = {...rule, until: day - 1}` and exceptions on or after `day` move out of `before`; `after = newPrice === null ? null : {...rule, id: newId, price: newPrice, start: day, until: rule.until, exceptions: exceptions on/after day}`. If `day` ≤ `rule.start` (or the first occurrence) the caller deletes `before` instead (use case decides, see B3).
- `withException`: `'clear'` removes the key; drop the `exceptions` field when empty. Cap is checked by the use case.

Case table (`day_pricing_cases.json`): a JSON object `{ lunar: [...], ranges: [...], priceForDay: [...], startingPrice: [...], split: [...], scaled: [...], invalid: [...] }`. Every case is data, no code, so Dart can run the same file. Include at least: every lunar date listed in Task B1; leap month 2025 day mapped to `leap: true`; `ruleRanges` of Tết (lunar 12-23 → 01-05) for 2026 = `[{2026-02-10, 2026-02-21}]` (the next one starts 2027-01-30, outside 2026) and for 2027 = `[{2027-01-30, 2027-02-10}]`; a solar yearly range crossing the year (12-24 → 01-02); weekly T7–CN; exception `null` on a Saturday inside a yearly rule falling back to the weekly rule; exception price; `start`/`until`; tier `none` > `yearly` > `weekly`; same tier highest; invalid exception value ignored; `startingPrice` with a weekly rule cheaper than `price`; `startingPrice` ignoring a passed `none` rule and an ended `until`; `scaledPrice(1_800_000, 1_500_000, 3_200_000)` = 3_840_000 rounded up to 3_840_000 (already a multiple) and `scaledPrice(1_700_000, 1_500_000, 2_000_000)` = 2_270_000; `validatePriceRule` failures (93-day span, `none` in the past on create, `from` > today + 730, empty `weekdays`, unknown `serviceId`, `lunar` on weekly, `until < start`, price 0 and 1e9 + 1).

- [ ] Write the table first, then the TS test that runs it (one `describe` per section), then the code. Remove the old exports (`SpecialDays`, `NO_SPECIAL_DAYS`, `isSpecialDay`, `weekPrices`, `priceRange`, `priceSummary`, `normalizeDayPrices`, `validateServicePrices`, `DayPriceKind`) **only in Task B3** together with their callers, so this task keeps the package compiling: in B2 add the new API next to them in the same file.
- [ ] Commit `feat(domain): price series, exceptions and the shared case table [#316]`.

### Task B3: Domain ports, use cases, booking and discovery

**Files:** create `price_rule_ports.ts`, `price_rule_use_cases.ts`, `memory_price_rules.ts`, `test/price_rule_use_cases.test.ts`; modify `booking_ports.ts`, `booking.ts`, `create_booking.ts`, `discovery_stats.ts`, `discovery_ports.ts`, `discovery_use_cases.ts`, `memory_discovery_store.ts`, `spot_schedule.ts` and its callers, `index.ts`, `test/support/booking_world.ts`, every test that builds `dayPrices`/`specialPrice`; delete `memory_special_days.ts` and the old `day_pricing.ts` exports.

**Produces:**
```ts
// price_rule_ports.ts
export interface PriceRuleReader { rulesForService(providerId: string, serviceId: string): Promise<PriceRule[]>; rulesForProvider(providerId: string): Promise<PriceRule[]> }
export interface PriceRuleTx {
  get(providerId: string, ruleId: string): Promise<PriceRule | null>;
  listForService(providerId: string, serviceId: string): Promise<PriceRule[]>;
  put(providerId: string, rule: PriceRule, at: string /* ISO */): void;     // create or replace; adapter sets createdAt on create, updatedAt always, endsOn
  delete(providerId: string, ruleId: string): void;
}
export interface PriceRuleStore { runTransaction<T>(fn: (tx: PriceRuleTx) => Promise<T>): Promise<T> }
export interface PriceRuleDeps { readonly rules: PriceRuleStore; readonly services: ProviderServices; readonly clock: Clock; readonly ids: IdGenerator }
export interface ProviderServices { listServices(providerId: string): Promise<PricedService[]> }   // all packages of the provider (active or not)
// price_rule_use_cases.ts — each validates input with validatePriceRule and runs one transaction
export function savePriceRule(deps, callerId, raw): Promise<{ ruleIds: string[] }>;
export function splitPriceRule(deps, callerId, raw /* {ruleId, day, price?} */): Promise<{ ruleIds: string[] }>;
export function setPriceRuleException(deps, callerId, raw /* {ruleId, day, price: int|null|'clear'} */): Promise<Record<string, never>>;
export function deletePriceRule(deps, callerId, raw /* {ruleId} */): Promise<Record<string, never>>;
export function refreshPriceSummary(deps: DiscoveryDeps, providerId: string): Promise<RefreshOutcome>;   // replaces refreshStartingPrice
```
Reuse existing `Clock`/id generator ports (look at `addon_use_cases.ts` and `addon_ports.ts` for the shape and follow it).

Use case rules:
- Inputs are `unknown`; parse strictly (field errors `invalid_argument` with the field name: `price`, `from`, `to`, `weekdays`, `repeat`, `lunar`, `name`, `day`, `ruleId`, `serviceId`).
- `savePriceRule`: `ruleId` absent → create with `ids.newId()`; present → the rule must exist under the caller (else `not_found`) and keeps its `serviceId`, `start`, `until`, `exceptions`, `createdAt`. Count rules of the service in the transaction (create: `count + 1 > 30` → `rule_limit`). `applyToAll` only on create: for each other package of the caller, `scaledRule` with its own new id, each checked against its own 30 limit, all in the same transaction. Returns the written ids, the edited/created rule first.
- `splitPriceRule`: `day` must be a day the rule can cover (inside `[start, until]`); if `day` ≤ the rule's first possible day (`start`, or `from` for `none`) then "this and following" = the whole series: replace the rule (with `price`) or delete it (without `price`). Otherwise write `before` and, with `price`, `after` (counts toward 30).
- `setPriceRuleException`: `day` must be covered by the rule's pattern (ignoring existing exceptions) else `invalid_argument` `day`; > 50 keys → `exception_limit`.
- `refreshPriceSummary`: reads active services + `rulesForProvider`, computes `{ startingPrice, hasDayPricing }` and applies `statsPatch`. `hasDayPricing` = any rule of an active package with a next occurrence.
- `createBooking`: `BookingDeps.specialDays` → `BookingDeps.priceRules: PriceRuleReader`; read before the transaction as today; `priceForDay(service, rules, input.day)`; the snapshot gets `priceKind` and, when `kind === 'rule'` and the rule has a name, `ruleName`. Update `BookingServiceSnapshot` (`priceKind?: 'base' | 'rule'; ruleName?: string`) and every place that builds it (`buildBookingDraft`, quotes, spot/slot paths default to `base`).
- `ServiceRecord`: drop `dayPrices`, `specialPrice`. `DiscoveryStatsStore.activeServicePricings` → `activeServices(uid): Promise<PricedService[]>` plus `PriceRuleReader` in `DiscoveryDeps` (or a `rules(uid)` method on the stats store: pick the smaller change and say which in the commit). `PriceStats` = `{ startingPrice, hasDayPricing }`; `statsPatch` drops `weekendFrom`/`hasSpecialPrices`, adds `hasDayPricing`; also patch `weekendFrom: FieldValue.delete()` is an adapter concern (B4).
- `priceFromOf(active, serviceIds, windowMinutes, rules, today)`: uses `startingPrice` per package. Update its callers to read rules through `PriceRuleReader`.
- Memory adapters: `MemoryPriceRuleStore` implements `PriceRuleStore` + `PriceRuleReader` (map per provider; transaction = run fn, then apply buffered writes).
- [ ] Tests (`price_rule_use_cases.test.ts`, `create_booking.test.ts`, `discovery_*`): owner-only (another caller's `ruleId` → `not_found`; another provider's `serviceId` → `invalid_argument` `serviceId`); 31st rule → `rule_limit`; 51st exception → `exception_limit`; `applyToAll` writes one rule per package with scaled prices; split keeps prices before `day` (check `priceForDay` on day-1 before and after); split at the first day replaces the series; booking on a Tết day of a year that has no data still gets the Tết price (lunar rule); `ruleName` in the snapshot; a booking made before the rule is deleted keeps its price (memory store); booking on a Saturday removed from the "Mùa cưới" yearly rule by an exception gets the weekend weekly price; `expectedPrice` mismatch → `price_changed`; `refreshPriceSummary` with a weekly rule cheaper than `price`.
- [ ] Remove the old day-pricing exports and `memory_special_days.ts`; `npm test` and `npm run lint` (or the package's typecheck) green. Commit `feat(domain): price rule use cases, booking and discovery on price series [#316]`.

### Task B4: Functions: adapters, callables, trigger, daily job, seed

**Files:** see the file map (Functions row).

- [ ] `FirestorePriceRuleReader` (`photographers/{uid}/price_rules` where `serviceId ==` …, limit 30; `rulesForProvider` reads the whole subcollection, limit 30 × package count is fine: just no limit, documents are tiny) using `parsePriceRule`. Plain reads, outside transactions.
- [ ] `FirestorePriceRuleStore`: `runTransaction` over `firestore.runTransaction`; all reads before writes (buffer `put`/`delete` and flush at the end, as other stores here do); `put` writes the domain fields + `endsOn` + `updatedAt` (and `createdAt` on create), and removes absent optional fields with `FieldValue.delete()` on replace.
- [ ] `ProviderServices` adapter (reuse `serviceRecordOf`; drop its `dayPrices`/`specialPrice` mapping).
- [ ] Callables in `src/callables/price_rule.ts` like `addon.ts` (`requireUid`, `handleCallableError`), exported in `src/index.ts` with `CALLABLE_OPTIONS`: `savePriceRule`, `splitPriceRule`, `setPriceRuleException`, `deletePriceRule`. Each calls `refreshPriceSummary` after the transaction (outside it; a failure there is logged, not thrown).
- [ ] Trigger `onPriceRuleWritten` on `photographers/{uid}/price_rules/{id}` → `refreshPriceSummary` (covers writes from tools and the seed). `handleServiceDiscovery` calls `refreshPriceSummary` instead of `refreshStartingPrice`.
- [ ] Scheduled `expirePriceRules` daily at 00:05 Asia/Ho_Chi_Minh: collection group `price_rules` where `endsOn == yesterday`, distinct `uid`s, `refreshPriceSummary` each. Add the collection-group single-field override for `endsOn` in `firebase/firestore.indexes.json` (`fieldOverrides`, `queryScope: COLLECTION_GROUP`, ascending). Behind the same Blaze switch as the other scheduled functions (it is just another export in `index.ts`; check how the existing scheduled ones are exported and follow that).
- [ ] Discovery adapter: `activeServices` + rules; write `hasDayPricing`, delete `weekendFrom` and `hasSpecialPrices` fields when present.
- [ ] Delete `special_days_firestore.ts`, `tools/holidays.ts`, the `holidays` npm script and their tests. Add `tools/cleanup_day_pricing_v1.ts` (run by hand with `tsx`, `--project <id>` required, `--dry-run` default true): deletes `holidays/*`, every `photographers/*/special_days/*`, and the fields `weekendFrom`, `hasSpecialPrices` on photographers and `dayPrices`, `specialPrice`, `priceMode`, `occasionPrices` on services. Unit-test the plan builder with a fake (no real project).
- [ ] Seed (`seed/fixtures.ts`, README, `seed_fixtures.test.ts`): drop `SEED_HOLIDAYS`, special days and package `dayPrices`/`specialPrice`; An's portrait package (the one priced 1.5M) gets three rules: "Cuối tuần" weekly sat+sun 1,800,000; "Mùa cưới" yearly 11-14 → 11-22 2,000,000 with exception `2026-11-15: 1_500_000`; "Tết Nguyên đán" yearly lunar 12-23 → 01-05 2,500,000 (`template: 'tet'`). The seed uses fixed ids (follow the fixture id style). Note: `firebase/functions/seed/*` has **uncommitted changes in the main booking-be checkout** that belong to someone else; work only in the unit worktree and expect a rebase conflict later; never copy those changes in.
- [ ] Tests: `price_rules_firestore.test.ts` (adapter mapping, `endsOn`, field deletes) and `price_rule_callables.test.ts` (unauthenticated → `permission_denied`; errors mapped; refresh called) using the existing unit-test helpers; integration tests only if the existing pattern runs them in CI (write them, say if not run locally).
- [ ] `npm test` (unit) in `firebase/functions`; `npm run build`. Commit `feat(functions): price rule callables, trigger, daily refresh and seed [#316]`.

### Task B5: Rules and rules tests

- [ ] `firebase/firestore.rules`: remove `match /holidays/{year}` and `match /special_days/{id}`; add `match /photographers/{uid}/price_rules/{id} { allow read: if signedIn(); allow write: if false; }`; `validService` key list drops `dayPrices`, `specialPrice`, `priceMode` (and refuses `occasionPrices`); the server-only photographer field list replaces `weekendFrom`, `hasSpecialPrices` with `hasDayPricing`.
- [ ] `rules-test/rules.test.mjs` S08 block rewritten: signed-in read of `price_rules` succeeds, unauthenticated fails; owner create/update/delete fail; another user fails; a service with `dayPrices` or `specialPrice` fails, with only `price` succeeds; `holidays/2026` and `special_days` reads fail; a photographer cannot write `hasDayPricing`. Do not run (CI runs it).
- [ ] Commit `feat(rules): price_rules server-only, packages keep only price [#316]`.

**Finish booking-be:** push the branch, open the PR `feat(pricing): price series with lunar calendar in domain, functions and rules [#316]` with body `thanhngochoang/booking#316` and the usual headings. The app PR waits for it.

---

## Part A · app (`plan/316-day-pricing-series`)

Env for every task (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`; `flutter analyze` and the affected tests must be green at each commit.

### Task A1: Dart lunar calendar and price rules

**Files:** create `lib/core/lunar.dart` (export from `core/core.dart`), `lib/data/pricing/price_rules.dart`, `test/core/lunar_test.dart`, `test/data/pricing/price_rules_test.dart`; copy B2's `day_pricing_cases.json` over `test/data/contracts/day_pricing_cases.json` and update the contracts README line.

**Produces (Dart names mirror TS):**
```dart
class LunarDate { final int day, month, year; final bool leap; }
LunarDate solarToLunar(DateTime day);                    // date part only, no time zone math
DateTime? lunarToSolar(int day, int month, int year, {bool leap = false});
String lunarLabel(DateTime day);                         // "6", "1/10"
int? leapMonthOf(int lunarYear);
// price_rules.dart
enum PriceRepeat { none, weekly, yearly }
class PriceRule { id, serviceId, price, name, repeat, lunar, from, to, weekdays (Set<Weekday>), start, until, exceptions (Map<String, Object?>), template; factory PriceRule.fromMap(String id, Map<String, Object?>) returning null-safe parse via `static PriceRule? tryParse` }
class DayPrice { final int amount; final bool isRule; final PriceRule? rule; }
List<({DateTime from, DateTime to})> ruleRanges(PriceRule r, int year);
({bool covers, int? price}) ruleCoversDay(PriceRule r, DateTime day, {LunarDate? lunar});
DayPrice priceForDay(int basePrice, String serviceId, List<PriceRule> rules, DateTime day);
Map<DateTime, DayPrice> monthPrices(int basePrice, String serviceId, List<PriceRule> rules, int year, int month);
({DateTime from, DateTime to})? nextOccurrence(PriceRule r, DateTime today);
({int min, int max}) priceBounds(int basePrice, String serviceId, List<PriceRule> rules, DateTime today);
int scaledPrice(int input, int fromPrice, int toPrice);
const kMaxRulesPerService = 30, kMaxExceptions = 50, kMaxSpanDays = 92, kMaxAheadDays = 730;
const priceRuleTemplates = <PriceRuleTemplate>[...];      // same 11 entries and order as TS
String? validatePriceRuleField(...)                        // returns the field name that fails, for inline errors
```
- [ ] Port from B1/B2 TS (not from memory). `DateTime` values are local dates at midnight (`DateTime(y, m, d)`), keys `yyyy-MM-dd` via the existing date-key helper in `core` (find it: `grep -rn "dayKey\|toDayKey" lib/core`).
- [ ] Tests run every section of the copied case table plus the B1 lunar list. Commit `feat(data): lunar calendar and price series port [#316]`.

### Task A2: Price rule repository and model changes (add first)

**Files:** create `lib/data/pricing/price_rule_repository.dart`, `firestore_price_rule_repository.dart`, tests; modify `pricing_providers.dart`, `lib/data/booking/booking.dart` (+ generated code via the existing build step the repo uses for `booking.g.dart`; check `pubspec.yaml`/`README` for the command), `photographer_summary.dart`, `firestore_photographer_repository.dart`, `test/support/` (fake + world hooks).

```dart
abstract class PriceRuleRepository {
  Stream<List<PriceRule>> watchProviderRules(String providerId);              // live query, sorted
  Future<List<PriceRule>> rulesForService(String providerId, String serviceId);
  Future<List<String>> saveRule(PriceRuleInput input, {String? ruleId, bool applyToAll = false});  // savePriceRule
  Future<List<String>> splitRule(String ruleId, DateTime day, {int? price});                        // splitPriceRule
  Future<void> setException(String ruleId, DateTime day, PriceException value);                    // setPriceRuleException
  Future<void> deleteRule(String ruleId);                                                          // deletePriceRule
}
sealed class PriceException { custom(int price), skip(), clear() }   // → int | null | "clear"
class FakePriceRuleRepository implements PriceRuleRepository   // in-memory, applies the same pure functions, records calls
```
- [ ] Firestore adapter: reads `photographers/{uid}/price_rules`; writes only through `FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable(...)`, following `firestore_addon_repository.dart` (`_call`, error mapping to the repo's typed errors with `field`, `rule_limit`, `exception_limit`).
- [ ] Providers: `priceRuleRepositoryProvider`, `providerPriceRulesProvider(providerId)` (StreamProvider.autoDispose.family), `servicePriceRulesProvider((providerId, serviceId))`.
- [ ] `BookingServiceSnapshot` gets `priceKind` (`base` default) and `ruleName`. `PhotographerSummary` gets `hasDayPricing`; keep `weekendFromVnd`/`hasSpecialPrices` until A9.
- [ ] Commit `feat(data): price rule repository over callables [#316]`.

### Task A3: `AppCalendar` (can run in parallel with A2)

**Files:** create `lib/core/widgets/app_calendar.dart`, `test/core/widgets/app_calendar_test.dart`; export from `core/core.dart`; strings in `app_vi.arb` (`appCalendar_*`).

```dart
enum AppCalendarSelection { none, single, range }
class AppCalendar extends StatefulWidget {
  const AppCalendar({required DateTime month, ValueChanged<DateTime>? onMonthChanged, AppCalendarSelection selection = AppCalendarSelection.none,
    DateTime? selected, DateTimeRange? range, ValueChanged<DateTime>? onDayTap, ValueChanged<DateTimeRange>? onRangeChanged,
    bool Function(DateTime)? disabledDay, Widget? Function(BuildContext, DateTime)? dayBuilder, Set<DateTime> markers = const {},
    Color? Function(DateTime)? dayOutline, bool Function(DateTime)? emphasized, DateTime? today, bool showHeader = true, DateTime? first, DateTime? last});
}
Future<DateTime?> showAppDatePicker(BuildContext context, {required DateTime initial, required DateTime first, required DateTime last, String? title});
Future<DateTimeRange?> showAppDateRangePicker(BuildContext context, {DateTimeRange? initial, required DateTime first, required DateTime last, String? title});
```
- [ ] Layout per spec §5.7 and the mock's calendar in `#S08.10`/`#S04.02-dayprice`: 7 columns, week starts Monday, cell ≥ 44 dp; solar number with the lunar number small **on the same row, right next to its foot**; on the 1st of a lunar month "1/M" in the accent colour; optional `dayBuilder` line under the numbers; selected day/range filled with accent; `dayOutline` draws a warning outline (exceptions); disabled days dimmed. Header "Tháng 11 / 2026" with ‹ › (hidden when `showHeader: false`).
- [ ] Range selection: tap start then tap end (second tap before start restarts), **and** long-press then drag across cells. Both required.
- [ ] Pickers: bottom sheet with `AppCalendar` and a primary "Chọn" button.
- [ ] Semantics: each cell label "Thứ Bảy 21 tháng 11, mùng 1 tháng 10 âm lịch, …" plus the builder text.
- [ ] Tests: lunar numbers for 2026-11-01 … 2026-11-30 match `lunarLabel` (mùng 1 and 15 of month 10); tap-tap and long-press-drag ranges; 320 dp width and text scale 1.3 without overflow; light and dark theme pump; picker returns the chosen day. Commit `feat(core): AppCalendar with lunar days and date pickers [#316]`.

### Task A4: S08.10 Giá theo ngày and its sheets

**Files:** `lib/features/day_pricing/*` (see file map), route `/me/day-pricing?service=:id` and `/me/day-pricing/rules` in `app/router.dart` (replace `/me/special-days`; keep a redirect from `/me/special-days` to `/me/day-pricing`), `screen_codes.dart` (S08.10 name), strings `s0810_*` (replace the old S08.10 strings), tests `test/features/day_pricing/*`.

- [ ] Build exactly the mock `#S08.10`, `#S08.10-new`, `#S08.10-repeat`, `#S08.10-day`, `#S08.10-list` with spec §5.3–§5.6 (package chips with active first, month nav, `AppCalendar` with short price line per day via `monthPrices`; base price dim; rule days bold; selected range accent; exception days outlined in warning colour; one-line legend; "Chuỗi của gói" card ordered weekly first then by next occurrence; primary "＋ Đặt giá").
- [ ] Interactions: tap a day covered by a rule → S08.10-day; otherwise S08.10-new with from = to = that day; range select then "Đặt giá" → S08.10-new with the range; card row → S08.10-new editing the whole series.
- [ ] S08.10-new: price, from/to (`showAppDatePicker`), "Lặp lại" switch (off = `none`), on reveals indented "Chu kỳ" dropdown (Hằng tuần / Hằng năm), yearly shows "Theo âm lịch" switch with the helper line ("14/11 – 22/11 mỗi năm" or "6/10 – 14/10 âm lịch mỗi năm · năm sau là T4 3/11 – T5 11/11/2027") and the leap-month note (R14); weekly shows seven round day toggles prefilled from the range and hides from/to; "Tên (tuỳ chọn)"; "Áp cho" dropdown only on create; "Lưu"; on edit a red "Xoá chuỗi" with confirmation "Booking đã đặt giữ giá cũ". Template chips only when opened from the button with no selection; existing templates dimmed. Editing a yearly series shows the next occurrence (or the running one) in from/to. Lunar from/to are written from the lunar day–month of the picked solar dates (main month). Inline errors from spec §5.4 (validation in Dart first, server field errors mapped to the same lines).
- [ ] S08.10-day: title "{Thứ} {ngày}" + package; applied-rule line; "{other} bị {winner} thay" when two rules cover the day; "Giá ngày này" prefilled; three radios (R4); "Lưu" → `setException(custom)` / `splitRule(day, price)` / `saveRule(whole series with new price)`; red action text changes with the radio: "Bỏ ngày này khỏi chuỗi" → `setException(skip)`, "Kết thúc chuỗi từ ngày này" → `splitRule(day)` without price, "Xoá chuỗi" → `deleteRule` with confirmation.
- [ ] S08.10-list: grouped by package "Chân dung · giá thường 1,5M", rows like the card, exceptions listed when ≤ 2 ("CN 15/11: 1,5M"), passed `none` rules hidden; calendar icon back to S08.10; primary "＋ Đặt giá".
- [ ] Analytics: reuse the event names already listed for S08.10 in `screens/photographer.md` if any; otherwise none.
- [ ] Widget tests with `FakePriceRuleRepository`: prices per day equal `monthPrices`; exception outline; tapping a rule day opens S08.10-day; repeat switch yearly + lunar writes lunar `MM-dd`; "Mọi gói" calls `saveRule(applyToAll: true)` and the fake creates one rule per package rounded per R8; the three S08.10-day choices call the right method; list hides a passed one-off. Commit `feat(day-pricing): S08.10 price calendar, series sheets and list [#316]`.

### Task A5: S08.08 and S08.09 on the new model

- [ ] S08.08 (`my_packages_screen.dart`) per mock `#S08.08`, `#S08.08-sort`: "Giá theo ngày" summary row (names of up to three rules + "· {n} chuỗi", or the empty text + "Đặt giá") → S08.10; "{n} gói đang bật · giá dưới là giá ngày thường"; cards: name, "2 giờ · 40 ảnh chỉnh · giao 3 ngày", base price bold then " · cuối tuần 1,8M · Tết 2,5M" (the weekly rule if any and the nearest upcoming other rule, computed with `nextOccurrence`), switch; no drag handle. "Sắp xếp" (≥ 2 packages) enters sort mode: title "Sắp xếp gói", "Xong", each card with drag handle and "Lên"/"Xuống" (disabled at ends), switch; "Xong" writes `order` in one batch (existing repository method). Empty state and "turn off last package" sheet unchanged.
- [ ] S08.09 (`package_edit_screen.dart` + controller): one "Giá ngày thường" field; read-only series card on edit when the package has rules (row texts from `rule_text.dart` shared with A4) with link "Giá theo ngày" → `/me/day-pricing?service=<id>`; otherwise the single line "Cuối tuần, ngày lễ: đặt ở Giá theo ngày sau khi lưu"; hidden with `?from=setup`; helper "Booking đã đặt giữ giá cũ."; "Lưu gói"; "Ẩn gói" on edit; "Bỏ thay đổi?" sheet on exit with changes. Remove the price mode table, special price switch and 7-day preview. Saving writes `price` and deletes `dayPrices`, `specialPrice`, `priceMode`, `occasionPrices` with `FieldValue.delete()` in the Firestore adapter.
- [ ] `PackagePriceLine` shows base price + the same extras as the S08.08 card; S08.01 step 2 keeps using S08.09 (`?from=setup`).
- [ ] Remove `special_days_screen.dart`, `special_day_sheet.dart`, `special_day_rules.dart` and their tests and strings; the Work row and S08.06 link that pointed to special days point to `/me/day-pricing`.
- [ ] Tests updated/added (sort mode up/down and batch write; S08.09 single price field and delete of old fields; card extras text). Commit `feat(packages): S08.08 and S08.09 on price series [#316]`.

### Task A6: Booking flow, S03.01, booking detail, PhotographerCard

- [ ] `BookingFlowState`/controller: load `servicePriceRulesProvider` for the chosen package (one query); `dayPrice` = `priceForDay` (always available once rules load; a failed read blocks the day with retry as today); drop holidays/special days; `price_changed` invalidates the rules provider. `expectedPrice` = day price, `expectedTotal` = that + add-ons.
- [ ] S04.01 (`service_step.dart`): range "1,5M–2,5M" from `priceBounds` (single price when equal) and "Tiếp tục · từ {min}".
- [ ] S04.02 (`datetime_step.dart`): `AppCalendar` with availability states (through the A7 version of `AvailabilityCalendar` or directly with `dayBuilder`) and under days whose price differs from base the short price, with the rule name abbreviated ("Tết 2,5M") in accent; header line on a chosen day "T3 17/2 · Tết · 2.500.000₫". Abbreviation: the first word of the name if the whole name does not fit (ruling; spec §9 leaves it to the builder).
- [ ] S04.03 (`review_step.dart`): "(Tết)" after the package price from the chosen day's rule name; "(giá theo ngày)" when the rule has no name; nothing for base.
- [ ] Booking detail (the screen that shows `serviceSnapshot.price`; find it with `grep -rn "serviceSnapshot.price" lib/features`): same suffix from `serviceSnapshot.ruleName` / `priceKind`.
- [ ] S03.01 price sheet (`price_table_sheet.dart`, opened from `profile_sections.dart`): "Giá thường {giá}" then one row per rule "{tên} · {quy tắc} — {giá}" (passed one-offs hidden), per mock `#S03.01-prices`; "Đặt gói này" books.
- [ ] `PhotographerCard`: "từ {startingPrice}" only; remove "· T7–CN từ …".
- [ ] `ServiceSummary` drops `dayPrices`/`specialPrice`; `firestore_photographer_repository.dart` stops reading them.
- [ ] Flow test (Review Focus 1): seed the fake with the three An rules; pick a Tết day, a Saturday, and 2026-11-15 (exception 1.5M inside "Mùa cưới" → 1,500,000); assert the sent `expectedPrice` equals `priceForDay`. Commit `feat(booking): day price from price series in S03.01 and S04.01–S04.03 [#316]`.

### Task A7: AppCalendar on the calendar screens

- [ ] `core/widgets/availability_calendar.dart`: keep its public API (states, notes, selection, legend, skeleton) but render through `AppCalendar` (`dayBuilder` for state dots and notes), so every caller gets lunar days. Then check each caller still works: `features/calendar/my_calendar_screen.dart`, `features/photographer_profile/widgets/profile_sections.dart` (`CalendarSliver`), `features/spots/spot_screen.dart`, `features/spots/spot_schedule_edit_screen.dart`, `features/chat/widgets/reschedule_sheet.dart`, `features/booking/steps/datetime_step.dart`. Where a screen uses `showDatePicker`/`showDateRangePicker`, replace with `showAppDatePicker`/`showAppDateRangePicker`.
- [ ] Update golden/widget tests that count cells or find texts (lunar numbers add text nodes: prefer finders by key). Commit `refactor(core): availability calendar on AppCalendar with lunar days [#316]`.

### Task A8: AppCalendar date pickers on the remaining screens

- [ ] Replace `showDatePicker`/`showDateRangePicker` with the app pickers in: `features/collab/collab_paid_sheet.dart`, `features/entry/entry_buy_screen.dart`, `features/event_create/create_event_screen.dart`, `features/event_manage/entry_days_tab.dart`, `features/find/find_sheets.dart`, `features/job_market/quote_sheet.dart`, `features/jobs/job_post_sheets.dart`, `features/organizer/entry_tickets_edit_screen.dart`, `features/organizer/widgets/resident_sheet.dart`. Keep each screen's bounds (`first`/`last`) and initial value.
- [ ] `grep -rn "showDatePicker\|showDateRangePicker\|CalendarDatePicker" lib` must return nothing. Fix the tests that drove the Material picker (tap the day cell by key, then "Chọn"). Commit `refactor(app): app date pickers with lunar days on every screen [#316]`.

### Task A9: Cleanup, docs, verification

- [ ] Delete `lib/data/pricing/special_days.dart`, `firestore_special_days_repository.dart`, holiday/special-day providers, `weekendFromVnd`, `hasSpecialPrices`, old `day_pricing.dart` functions (keep `Weekday`, `weekdayOf`, `kMaxPriceVnd`), `PriceMode`, `dayPrices`/`specialPrice` on `ServicePackage`, unused strings (`s0808_specialDays*`, `s0402_holidayPrice`, `s0402_weekdayPrice` if unused), test support (`day_price_packages.dart`, booking world holidays). `flutter gen-l10n`.
- [ ] Docs: `docs/superpowers/handover/ledger-day-pricing-series.md` (rulings: `endsOn`, sheet abbreviation rule, drag and tap ranges, lunar picker choice, rules order in the card, the discovery port choice from B3, anything else decided); status cells S08.08–S08.10 in `2026-10-01-remaining-screens.md`; a short "Chuỗi giá" paragraph in `data-model/domain-model.md` (no SQL file change, spec §4.6.5).
- [ ] Verification: `flutter analyze && flutter test` (full), booking-be `npm test` in `packages/domain` and `firebase/functions` (unit), `npm run build` in functions. Record the real output in the PR.
- [ ] Commit `chore(packages): remove v1 day pricing and record rulings [#316]`.

**Finish app:** rebase on `origin/develop` (the branch starts from the spec branch `docs/316-day-pricing-series`; if PR #328 is merged first, the rebase drops those commits, otherwise the app PR carries them), push, open `feat(packages): S08.08–S08.10 price series and lunar AppCalendar [#316]`, move #316 to In Review with the PR number. Do not merge without the owner.

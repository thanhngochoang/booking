# S03.01 "Chưa nhận đơn": acceptingOrders, server block and profile variant Implementation Plan

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`. Write the rules test; do not run it, CI runs it. Functions integration tests are not added. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Issue:** #133 (S03 · Xem hồ sơ nhiếp ảnh gia), only the item "Bản 'Chưa nhận đơn' (S03.01-new); server chặn đặt lịch/mời báo giá với thợ chưa xác minh". The user decided on 2026-10-07 to keep the other two items out of this unit: the % cà chua tile, reviews tab and "Được đánh giá cao" by % go to #130 (they need the tomato/brick backend), the studio variant goes to #136 (it needs `studio_members`).

**Goal:** A customer who opens the profile of a provider that cannot take orders yet sees the "Chưa nhận đơn" variant of S03.01 (dashed lock tag, quiet note, locked outline button, no "book this package"), can still send an inquiry, never finds that provider in S02.06 Tìm thợ, and the server refuses to create a booking for them whatever the client does.

**Architecture:** One pure domain rule `acceptsOrders({verified, onboardingComplete})` decides. The server uses it twice: `createBookingDraft` asks a new `ProviderOrderGate` port (reads `photographers/{uid}` source fields, never the derived flag, so there is no trigger lag) and throws the new error code `not_accepting_orders`; the `onPhotographerWrite` trigger keeps the public, server-only field `photographers/{uid}.acceptingOrders` equal to the rule. The app reads `acceptingOrders` (falling back to the same rule when the field is absent, so no backfill is needed) into `PhotographerSummary`, and S03.01, the services tab, S06 photo detail and the Find filter react to it. S21 (#135) later sets `verified` through the paid verification flow; until then `verified` stays the admin/seed-set flag it is today.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 trigger + callable adapters, `node --test`), Firestore rules; Flutter, Riverpod 3, go_router, `flutter_test`, `mocktail`-free fakes in `test/support/`.

**Spec:** `docs/superpowers/specs/2026-10-06-identity-verification-design.md` §3 (state), §4 (profile behaviour, Find), §7 (server block), §10 (tests); mock `docs/design/ui-mock.html#S03.01-new` (layout and copy); `docs/superpowers/specs/screens/discovery.md` S03.01; main spec `2026-10-01-remaining-screens.md` §3d.1 (tick = verified).

**Branch:** `plan/133-s03-orders-closed` (claimed with `project.py claim 133`), PR into `develop` titled `feat(profile): S03.01 orders-closed variant and server booking block [#133]`.

## Contract with existing code

Checked 2026-10-07 on `develop` 347326a. Task 1 Step 1 and Task 3 Step 1 re-check; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `DomainError`, `ERROR_CODES` (`errors.ts`; `not_eligible` exists and is already used for other refusals, including "payments off" on the app side, so it is **not** reused here), `createBookingDraft(deps: BookingDeps, rawInput)` (`create_booking.ts`; steps: validate → `deps.services.getService` → `price_changed` → `requireCustomerPhone` → `computeDeposit` → transaction), `BookingDeps { store, services, contacts, gateway, clock, ids }` (`booking_ports.ts:108`), `ServiceCatalog`, `CustomerContactReader`, `index.ts` export list. Test support `test/support/booking_world.ts` `createBookingWorld()` builds `BookingDeps` from in-memory maps. No `acceptsOrders`, no `acceptingOrders` anywhere.
- Functions (`app_flutter/firebase/functions/src`): `handleCreateBooking(request, deps)` (`callables/booking.ts`), `liveBookingDeps()` (`infra/live_booking.ts`), Firestore readers in `infra/booking_readers.ts`, `toHttpsError` + the code→status table (`callables/errors.ts`, `not_eligible: 'failed-precondition'`), `onPhotographerWrite` (`index.ts:134`) → `handlePhotographerEvent(input, deps, now)` → `handlePhotographerWrite(input, deps)` (`triggers/photographer_write.ts`, skills scoring only; `PhotographerWriteInput {uid, before, after}`), `db()` (`infra/admin.ts`). Seed `seed/fixtures.ts`: An (`an.verified@seed.test`, verified), Bình (`binh.unverified@seed.test`, `verified: false`), photographer docs written with `verified: p.verified` (~line 292). Tests that build `BookingDeps`: `test/unit/booking_callables.test.ts`, `booking_clock_ticket_release.test.ts`, `event_payment_callables.test.ts`.
- Rules (`app_flutter/firebase/firestore.rules`): `verifiedUntouched()` (~line 32), `photographerServerFieldsUntouched()` (`['providerType', 'artistSince', 'studioDistrict', 'studioCity', 'approvedAwardCount']`), `match /photographers/{uid}` (~line 422). Rules tests in `app_flutter/firebase/rules-test/`.
- App data: `PhotographerSummary` (`lib/data/content/photographer_summary.dart`; `verified` bool default false), `photographerSummaryFrom({id, user, photographer})` (`firestore_photographer_repository.dart`; the only production constructor), `PhotographerProfile{summary, intro}` + `photographerProfileProvider(uid)`, `BookingErrorCode` + `bookingErrorOf` + `_codeToBookingError` (`lib/data/booking/booking_repository.dart`; `notEligible` exists), `PostDetail.photographer` (`PhotographerSummary?`, `lib/features/photo/photo_detail_controller.dart:20`).
- App features: `ProfileHeader(profile, owner)` (`features/photographer_profile/widgets/profile_header.dart`; `providerMarkOf`, `ProviderName`, `ProviderTag`, `StatTileRow`, `_BadgesRow`, `AwardsStrip`), `ProfileBottomBar({photographerId, owner, onEdit})` (`profile_bottom_bar.dart`; visitor: `PhotographerContactAction` + `AppButton.primary` `Key('profile-book')`), `ServicesSliver({photographerId, owner})` (`profile_sections.dart:~380`; visitor tap = `startBooking`), `PhotographerProfileScreen._loaded`, photo detail `bookButton` (`features/photo/photo_detail_screen.dart:~213`, `Key('photo-book')`), `BookingFlowController._handleError` (`booking_flow_controller.dart:~306`) and `BookingSheetPage._handleError` (`booking_sheet_page.dart:~119`; `notEligible` → `l10n.bookPaymentsOff`), `FindResultsController` + `_byRating` (`features/find/find_controller.dart:~206`; the empty-page look-ahead `maxEmptyPages = 4`).
- Core: `AppButton.primary/outline/text/danger` (`onPressed: null` = disabled), `AppIcons.lock`, `AppIcons.info`, `AppIcon`, `AppColors`/`AppColorsDark` (`foregroundSecondary`, `foregroundTertiary` if present, `outlineVariant` via theme), `AppSpace`, `AppRadius`, `ProviderTag` (individual → `SizedBox.shrink()`), `context.l10n`.
- Test support: `fixturePhotographer(id, {name, verified, …, providerType, approvedAwards, studioDistrict})` (`test/support/content_fixtures.dart:~60`), `ProfileWorld` (`test/support/profile_world.dart`; stub routes for `/u/:uid/book`, `/u/:uid/ask`), `discoveryPhotographers()` (p1 Minh Trí verified, p2–p4), `bookingProfileSummary` (`test/support/booking_world.dart:92`), `event_world.dart:415`.

## Global Constraints

- Spec §3: "`photographers/{uid}` (công khai): `verified: bool`, `verifiedAt?`, `acceptingOrders: bool` (= `verified` và hồ sơ đủ để đặt). Chỉ server ghi." "Hồ sơ đủ để đặt" = `onboardingComplete == true` (Decision 1).
- Spec §4: "Khách mở hồ sơ thợ chưa nhận đơn thấy nhãn "Chưa nhận đơn", vẫn nhắn hỏi được; nút đặt lịch và mời báo giá không có. Thợ chưa nhận đơn không hiện trong S02.06 Tìm thợ (bài đăng vẫn hiện trên feed)."
- Spec §7: "`acceptingOrders`/`verified` được kiểm tra trên server ở: tạo booking (`createBookingDraft`, …) … Rules: client không ghi được các trường này." (Chụp ngay, quotes and `assignBooking` do not exist yet; their plans add the same gate — Decision 5.)
- Mock `#S03.01-new` copy, verbatim: tag "Chưa nhận đơn" (icon `lock`, dashed outline, under the name); note "{name} chưa mở nhận đơn nên chưa đặt lịch hay xin báo giá được. Bạn vẫn nhắn hỏi được." (icon `info`, quiet tertiary text, between the stats row and the tabs); bottom button "Chưa nhận đặt lịch" (outline, disabled, `aria-disabled`), no gradient button; the inquiry button stays; packages have no "Đặt gói này"; no verified tick.
- CLAUDE.md: business rules in `packages/domain` (no Firebase/Node imports); Functions thin; Firebase only in `lib/data/**` adapters; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; `package:photobooking/...` imports, features import `core/core.dart`; one primary action per screen; commits are Conventional Commits ending with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never the Claude line).
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.

## Decisions (where the spec is silent)

1. **"Hồ sơ đủ để đặt" = `onboardingComplete`.** It is the existing "published" flag (`PhotographerProfile.published`); an unpublished profile is already hidden from visitors. Having no active package is not part of the rule: S03.01 already disables booking with "Nhiếp ảnh gia chưa đăng gói", and `createBookingDraft` already refuses an inactive service.
2. **New error code `not_accepting_orders`** (domain `ERROR_CODES`, Functions → `failed-precondition`, app `BookingErrorCode.notAcceptingOrders`). `not_eligible` already means "payments off" in the booking sheet; reusing it would show the wrong message.
3. **The server gate reads source fields, the client reads the derived flag.** `createBookingDraft` computes `acceptsOrders` from `verified` + `onboardingComplete` of `photographers/{uid}` at request time, so approval/revocation takes effect immediately. The trigger keeps `acceptingOrders` in sync for clients and future queries. The app maps a missing `acceptingOrders` to `verified && onboardingComplete` so existing dev data needs no backfill.
4. **Owner view unchanged.** The owner of a closed profile sees no tag, note or lock (their bar is "Chỉnh sửa hồ sơ"); the owner card "Còn {n} bước để nhận đơn" belongs to S21 (#135).
5. **Scope of the gate:** only `createBookingDraft` exists today. Chụp ngay (#140), quote send/invite (#139) and `assignBooking` (#136) must call the same `ProviderOrderGate`; Task 5 writes that into the issue comments and the ledger.
6. **Find:** filtered client-side in `FindResultsController` together with the rating filter (same empty-page look-ahead). Home shelves are not filtered (spec names only S02.06). The remote recommender contract (`services/recommender/api/openapi.yaml`) gets a deferred note, not a change.
7. **S06 photo detail ("Đặt lịch" under a post):** a closed provider shows the same locked outline "Chưa nhận đặt lịch" instead of the primary button; "Xem hồ sơ" stays. The spec says posts stay on the feed; booking from them must not.
8. **Stat tiles and badge row are unchanged.** The mock's "Mới / 0 đánh giá" tile is the tomato rule (#130); its "3 gói" tile is not in any spec; the badge row already hides when there are no earned badges.
9. **Test fixtures:** `PhotographerSummary.acceptingOrders` defaults to `false` (safe in production); `fixturePhotographer(..., acceptingOrders = true)` defaults to `true` so existing booking tests keep their meaning; the const summaries in `booking_world.dart` and `event_world.dart` set `acceptingOrders: true` explicitly.

## Review Focus

1. A verified photographer who has not finished setup (`onboardingComplete` false) — must not be bookable on the server, and the trigger must write `acceptingOrders: false`.
2. Verification revoked after the client loaded the profile (stale `acceptingOrders: true` in the app) — the server still refuses with `not_accepting_orders` and the booking sheet shows "Nhiếp ảnh gia này chưa nhận đặt lịch." instead of a payments or network message.
3. The trigger re-firing on its own write — `acceptingOrders` equal to the rule must produce no write (no infinite loop), and a deleted document must produce no write.
4. A client trying to set `acceptingOrders: true` on its own `photographers/{uid}` (create or update) — denied by rules.
5. A Find page whose 20 results are all closed providers — the look-ahead loads the next page instead of showing an empty list.

---

### Task 1: Domain rule, gate port and booking block

**Files:**
- Create: `packages/domain/src/provider_orders.ts`, `packages/domain/test/provider_orders.test.ts`
- Modify: `packages/domain/src/errors.ts`, `packages/domain/src/booking_ports.ts`, `packages/domain/src/create_booking.ts`, `packages/domain/src/index.ts`, `packages/domain/test/support/booking_world.ts`, `packages/domain/test/create_booking.test.ts`

**Interfaces:**
- Produces:
  ```ts
  // provider_orders.ts
  export interface OrderEligibilityFields { readonly verified?: unknown; readonly onboardingComplete?: unknown }
  /** True only when both are literally `true`; any other value (missing, string, null) is false. */
  export function acceptsOrders(fields: OrderEligibilityFields | null | undefined): boolean;
  /** The patch the trigger writes, or null when the stored flag already matches (or the doc is gone). */
  export function acceptingOrdersPatch(after: (OrderEligibilityFields & { readonly acceptingOrders?: unknown }) | null | undefined): { acceptingOrders: boolean } | null;
  // booking_ports.ts
  export interface ProviderOrderGate { acceptsOrders(photographerId: string): Promise<boolean> }
  // BookingDeps gains: readonly providers: ProviderOrderGate;
  // errors.ts ERROR_CODES gains 'not_accepting_orders'
  ```
- `BookingWorld` (test support) gains `providers: Map<string, OrderEligibilityFields>`; its gate returns `acceptsOrders(map.get(id))`. Seed the world's default photographer as `{ verified: true, onboardingComplete: true }` so the existing tests stay green.

- [ ] **Step 1:** Contract check: open the files above, confirm the names in "Contract with existing code"; ledger any difference.
- [ ] **Step 2: Failing tests** in `test/provider_orders.test.ts`:
  - `acceptsOrders: true only when verified and onboardingComplete are both true` (table: `{true,true}`→true; `{true,false}`, `{false,true}`, `{}`, `null`, `undefined`, `{verified:'true', onboardingComplete:true}`→false).
  - `acceptingOrdersPatch: writes when the stored flag differs or is missing` (`{verified:true,onboardingComplete:true}` → `{acceptingOrders:true}`; `{verified:false,onboardingComplete:true,acceptingOrders:true}` → `{acceptingOrders:false}`).
  - `acceptingOrdersPatch: null when the stored flag already matches` (both directions) and `null for a deleted document` (`undefined`).
  In `test/create_booking.test.ts`:
  - `refuses a provider that is not verified with not_accepting_orders` (no booking, no availability day written).
  - `refuses a verified provider that has not finished setup with not_accepting_orders`.
  - `checks the service before the provider` (unknown service on a closed provider → `not_found`).
  - `checks the provider before price and phone` (closed provider + stale `expectedPrice` + customer without phone → `not_accepting_orders`).
- [ ] **Step 3:** Run `cd packages/domain && npm test` — the new tests fail (missing exports / no gate).
- [ ] **Step 4: Implement.** `provider_orders.ts` as above (use `=== true`). Add `'not_accepting_orders'` to `ERROR_CODES`. Add `ProviderOrderGate` and `providers` to `BookingDeps`. In `createBookingDraft`, right after the service check:
  ```ts
  if (!(await deps.providers.acceptsOrders(input.photographerId))) {
    throw new DomainError('not_accepting_orders');
  }
  ```
  Export the new names from `index.ts`. Update `booking_world.ts`.
- [ ] **Step 5:** `npm test` green (all domain tests, including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): providers must accept orders before a booking draft [#133]` (TonyH trailer).

### Task 2: Functions, seed and rules

**Files:**
- Modify: `app_flutter/firebase/functions/src/infra/booking_readers.ts`, `src/infra/live_booking.ts`, `src/callables/errors.ts`, `src/triggers/photographer_write.ts`, `src/index.ts` (only if the trigger wiring needs a new dep), `seed/fixtures.ts`, `seed/README.md`, `test/unit/booking_callables.test.ts`, `test/unit/booking_clock_ticket_release.test.ts`, `test/unit/event_payment_callables.test.ts`, `test/unit/photographer_write.test.ts`, `test/unit/photographer_event.test.ts`, `test/unit/errors.test.ts`, `test/unit/seed_fixtures.test.ts`; `app_flutter/firebase/firestore.rules`; the photographers rules test file in `app_flutter/firebase/rules-test/` (find the one that covers `verified`).
- Create: none required (put the reader beside the others).

**Interfaces:**
- Consumes: `acceptsOrders`, `acceptingOrdersPatch`, `ProviderOrderGate`, `'not_accepting_orders'` (Task 1).
- Produces:
  ```ts
  // infra/booking_readers.ts
  export class FirestoreProviderOrderGate implements ProviderOrderGate {
    constructor(private readonly firestore = db()) {}
    async acceptsOrders(photographerId: string): Promise<boolean> // reads photographers/{id}; missing doc → false
  }
  // triggers/photographer_write.ts
  export interface AcceptingOrdersWriter { set(uid: string, acceptingOrders: boolean): Promise<void> }
  export async function syncAcceptingOrders(input: PhotographerWriteInput, writer: AcceptingOrdersWriter): Promise<'written' | 'unchanged' | 'deleted'>;
  ```
  `handlePhotographerEvent` runs `syncAcceptingOrders` after the skills step for every handled event, under the same expiry and permanent-error policy (an expired event writes nothing; a permanent Firestore error is logged with the uid only). The live writer does `photographers/{uid}.update({acceptingOrders})` with the Admin SDK. Keep the existing return value of `handlePhotographerEvent` for skills; add the sync outcome to the log line, not to the return type, unless the existing tests make another shape simpler (ledger it).
- Error table: `not_accepting_orders: 'failed-precondition'`, with `details.code` = `'not_accepting_orders'` like the other codes.

- [ ] **Step 1:** Contract check of the Functions files above; ledger differences.
- [ ] **Step 2: Failing tests:**
  - `booking_callables.test.ts`: `createBooking refuses a closed provider with failed-precondition and details.code not_accepting_orders`; existing cases get an open provider in their fake deps.
  - `photographer_write.test.ts`: `syncAcceptingOrders writes true for a verified, finished profile`; `writes false when verified is removed`; `writes nothing when the stored flag already matches` (the re-fire case); `writes nothing for a deleted document`.
  - `photographer_event.test.ts`: `an expired event does not sync acceptingOrders`.
  - `errors.test.ts`: `not_accepting_orders maps to failed-precondition`.
  - `seed_fixtures.test.ts`: `seed photographers carry acceptingOrders equal to the rule` (An true, Bình false).
- [ ] **Step 3:** Run `cd app_flutter/firebase/functions && npm test`; the new tests fail.
- [ ] **Step 4: Implement** the reader, `liveBookingDeps().providers`, the error mapping, `syncAcceptingOrders` + wiring, and `acceptingOrders: acceptsOrders(p)` in the seed photographer docs (computed, not hand-written). Fix every other `BookingDeps` literal in tests (TypeScript lists them). In `seed/README.md`, add one line: Bình shows the S03.01 "Chưa nhận đơn" variant and cannot be booked.
- [ ] **Step 5: Rules.** Add `'acceptingOrders'` to `photographerServerFieldsUntouched()`; add a sibling of `verifiedUntouched()`'s create branch only if needed — the "changed keys" check already covers create because `changed` = all keys on create. Write the rules tests (not run): `owner cannot create photographers/{uid} with acceptingOrders`, `owner cannot update acceptingOrders`, `owner can still update bio when acceptingOrders is stored` (unchanged key passes).
- [ ] **Step 6:** `npm test` (functions) and `cd packages/domain && npm test` green; `npm run build` (functions) compiles. Ledger: rules tests written, not run (CI).
- [ ] **Step 7: Commit** `feat(functions): gate createBooking and sync acceptingOrders on photographers [#133]`.

### Task 3: App data, booking error and Find filter

**Files:**
- Modify: `app_flutter/lib/data/content/photographer_summary.dart`, `lib/data/content/firestore_photographer_repository.dart`, `lib/data/booking/booking_repository.dart`, `lib/features/booking/booking_flow_controller.dart`, `lib/features/booking/booking_sheet_page.dart`, `lib/features/find/find_controller.dart`, `lib/l10n/app_vi.arb`, `test/support/content_fixtures.dart`, `test/support/booking_world.dart`, `test/support/event_world.dart`
- Test: `test/data/content/` (the existing mapping test of `photographerSummaryFrom`; create `photographer_summary_mapping_test.dart` there if none exists), `test/data/booking/` (error mapping test), `test/features/booking/` (sheet test), `test/features/find/find_controller_test.dart` (or the existing find test file)

**Interfaces:**
- Produces: `PhotographerSummary.acceptingOrders` (`final bool`, constructor `this.acceptingOrders = false`); `BookingErrorCode.notAcceptingOrders`; l10n `bookNotAcceptingOrders` = "Nhiếp ảnh gia này chưa nhận đặt lịch."; `fixturePhotographer(..., bool acceptingOrders = true)`.
- Mapping rule in `photographerSummaryFrom`:
  ```dart
  acceptingOrders: photographer['acceptingOrders'] is bool
      ? photographer['acceptingOrders'] as bool
      : photographer['verified'] == true &&
          photographer['onboardingComplete'] == true,
  ```

- [ ] **Step 1:** Contract check (app side); ledger differences.
- [ ] **Step 2: Failing tests:**
  - mapping: `acceptingOrders comes from the stored flag`; `missing flag falls back to verified and onboardingComplete` (true/true → true, true/false → false); `a non-bool flag falls back too`.
  - `bookingErrorOf maps not_accepting_orders to notAcceptingOrders`.
  - booking sheet: `a closed provider refused by the server shows "Nhiếp ảnh gia này chưa nhận đặt lịch."` (fake repository throws the code at submit; snackbar text; no retry action; `bookPaymentsOff` not shown).
  - find: `closed providers are left out of the results`; `a page of only closed providers loads the next page` (look-ahead, Review Focus 5); `the rating filter and the closed filter combine`.
- [ ] **Step 3:** Run the new tests; they fail.
- [ ] **Step 4: Implement.** In `find_controller.dart` replace `_byRating` with one `_visible(items, filters)` that drops `!photographer.acceptingOrders` and applies the rating floor, used wherever `_byRating` was (keep the look-ahead counting on the filtered list). `BookingFlowController._handleError`: `notAcceptingOrders` → `phase idle`, `error: notAcceptingOrders`, `bookingId: null`. `BookingSheetPage._handleError`: snackbar `l10n.bookNotAcceptingOrders`. Add the arb key, run `flutter gen-l10n`. Update fixtures (Decision 9).
- [ ] **Step 5:** `flutter analyze` clean; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit** `feat(data): acceptingOrders on photographer summaries, booking refusal and Find filter [#133]`.

### Task 4: S03.01 "Chưa nhận đơn" variant and photo detail

**Files:**
- Create: `app_flutter/lib/core/widgets/orders_closed_tag.dart` (export from `lib/core/core.dart`), `test/core/widgets/orders_closed_tag_test.dart`
- Modify: `lib/features/photographer_profile/widgets/profile_header.dart`, `widgets/profile_bottom_bar.dart`, `widgets/profile_sections.dart` (`ServicesSliver`), `photographer_profile_screen.dart` (pass the flag), `lib/features/photo/photo_detail_screen.dart`, `lib/l10n/app_vi.arb`, `test/support/profile_world.dart` (only if a helper is needed)
- Test: `test/features/photographer_profile/photographer_profile_screen_test.dart` (new group `orders closed (S03.01-new)`), `test/features/photo/photo_detail_screen_test.dart` (or the existing photo detail test)

**Interfaces:**
- Consumes: `PhotographerSummary.acceptingOrders` (Task 3).
- Produces:
  ```dart
  /// The dashed "Chưa nhận đơn" tag of S03.01 (mock `.ptag.off`).
  class OrdersClosedTag extends StatelessWidget { const OrdersClosedTag({super.key}); }
  // ProfileBottomBar gains: required bool acceptingOrders
  // ServicesSliver gains: required bool acceptingOrders
  ```
- l10n (verbatim from the mock): `profileOrdersClosedTag` "Chưa nhận đơn"; `profileOrdersClosedNote` "{name} chưa mở nhận đơn nên chưa đặt lịch hay xin báo giá được. Bạn vẫn nhắn hỏi được." (placeholder `name`, String); `profileOrdersClosedButton` "Chưa nhận đặt lịch".
- `OrdersClosedTag`: `AppIcon(AppIcons.lock)` + text, secondary foreground colour, pill radius, **dashed** 1px outline in the theme's `outlineVariant`. Flutter has no dashed border: draw it with a small private `CustomPainter` over an `RRect` (dash ~3, gap ~2) — `PathMetric.extractPath` along the rounded rect path. Semantics label = the tag text.
- Header (visitor and `!acceptingOrders`): the tag sits under the name (where `ProviderTag` sits; for a studio/artist both show, `ProviderTag` first); the note row (`AppIcons.info` + `profileOrdersClosedNote(displayName)`, tertiary text, caption size) sits right after the `StatTileRow`, before the bio. The verified mark already hides when `verified` is false (`providerMarkOf`); do not change it.
- Bottom bar (visitor and `!acceptingOrders`): `PhotographerContactAction` unchanged + `Expanded(AppButton.outline(l.profileOrdersClosedButton, key: Key('profile-book-closed'), onPressed: null))`; no `AppButton.primary` in the visitor bar. "no packages" text logic stays for open providers only.
- `ServicesSliver` (visitor and `!acceptingOrders`): tiles are shown but not tappable (`onTap: null`); owner tap unchanged.
- Photo detail: when `detail.photographer?.acceptingOrders == false`, `bookButton` becomes `AppButton.outline(l.profileOrdersClosedButton, key: Key('photo-book-closed'), onPressed: null)`; null photographer keeps today's behaviour (server still guards).

- [ ] **Step 1:** Contract check; ledger differences.
- [ ] **Step 2: Failing tests** (`ProfileWorld`, a fixture with `verified: false, acceptingOrders: false`):
  - `a closed provider shows the dashed tag "Chưa nhận đơn" under the name and no verified mark`.
  - `the note names the provider: "{name} chưa mở nhận đơn nên chưa đặt lịch hay xin báo giá được. Bạn vẫn nhắn hỏi được."`.
  - `the bottom bar has a disabled outline "Chưa nhận đặt lịch" and no primary button` (find by key; `tester.widget<AppButton>` `onPressed == null`; `find.byKey(Key('profile-book'))` finds nothing).
  - `the inquiry button still opens /u/:uid/ask`.
  - `tapping a package on the Gói tab does not open booking` (router stays on `/u/p9`).
  - `the owner of a closed profile sees "Chỉnh sửa hồ sơ" and no tag or note` (Decision 4).
  - `an open provider shows no tag, no note and the primary "Đặt lịch · từ …"` (regression).
  - `closed variant fits 320dp at 1.3x text` (no overflow; same helper as the existing 320dp test).
  - `OrdersClosedTag` test: renders the text and lock icon, light and dark, semantics label "Chưa nhận đơn".
  - photo detail: `a post by a closed provider shows a disabled "Chưa nhận đặt lịch" instead of "Đặt lịch"`; `"Xem hồ sơ" still works`.
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement** as above; arb keys + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit** `feat(profile): S03.01 orders-closed variant and locked booking on photo detail [#133]`.

### Task 5: Specs, data model, docs and ledger

**Files:**
- Modify: `docs/superpowers/specs/screens/discovery.md` (S03.01: a "Thợ chưa nhận đơn (S03.01-new)" paragraph with the copy and behaviour above; strings list gains the three keys), `docs/superpowers/specs/data-model/domain-model.md` (photographer `acceptingOrders: bool`, derived, server-only), `docs/superpowers/specs/data-model/relational-schema.md` (`photographers.accepting_orders boolean not null default false` in the alter section next to `provider_type`, with the derivation comment), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (S03.01 "Trạng thái" cell: add "bản chưa nhận đơn: ✅ (#133)"; error codes list if the spec keeps one), `docs/superpowers/specs/components/shared-components.md` (`OrdersClosedTag`), `services/recommender/api/openapi.yaml` (a description note only: candidates must have `acceptingOrders == true` for Find; no schema change), `docs/superpowers/specs/2026-10-06-identity-verification-design.md` §7 (one line: the gate is `ProviderOrderGate` / `not_accepting_orders`; later gates reuse it)
- Create: `docs/superpowers/handover/ledger-s03-orders-closed.md` (rulings, deferred items, the rules test not run)

- [ ] **Step 1:** Edit the docs; keep the house style (Vietnamese specs, English code names).
- [ ] **Step 2:** Check that every string in `discovery.md` matches `app_vi.arb` and the mock.
- [ ] **Step 3: Commit** `docs(spec): S03.01 orders-closed variant, acceptingOrders in the data model [#133]`.

Deferred (record in the ledger and the PR): % cà chua tile, reviews tab and "Được đánh giá cao" by % → #130; studio variant and "Thành viên của {Studio}" → #136 (the label is not in the mock: design gap); owner card "Còn {n} bước để nhận đơn" → #135; the same gate in Chụp ngay (#140), quotes (#139), `assignBooking` (#136); remote recommender filtering; Home shelves filtering (spec silent).

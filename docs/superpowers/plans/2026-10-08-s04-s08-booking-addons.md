# S04/S08 Add-on services at booking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests and Functions integration tests (standing rule):** write them, do not run them; CI runs them. Record the skip in the ledger. No battery/performance, device build or iOS steps.

> **Detail level ("ở giữa", owner):** exact interfaces, tests listed by name with expected behaviour, sample code only for the hard parts.

**Goal:** Photographers and studios declare up to 10 active add-on services (makeup, extra retouching, transport, outfits, other) priced per booking, per person or per item (S08.06 list, S08.07 sheet). On S04.01 the customer adds them under the chosen package; a transport add-on makes S04.06 ask for a pickup point; S04.03 lists every line and charges the total. The server prices the add-ons from the provider's data (the app sends only `addonId` + `qty`), snapshots them on the booking, and every money path (100% upfront payment, refund table, two milestones, withholding, platform fee) runs on the total. S05.02 and S06.01 show what was bought.

**Architecture:** Rules in `packages/domain`: `addon.ts` (model, input validation with #139's `findContactLeak`), `addon_use_cases.ts` (`saveAddon`, `deleteAddon` in one transaction port with a per-provider lock document), `addon_pricing.ts` (`priceAddonLines`, `bookingTotal`, `requirePickup`). The booking gains `addons` and `pickup` through #199's `slot #190 (add-ons)` in `create_booking.ts` (`BookingDraftInput.addons?`/`pickup?`, `...addonDraftFields(i)`), and the money changes only by replacing the one-line body of #199's `draftTotal` with `bookingTotal(i.service, i.addons ?? [])`, so `deposit = computeDeposit(draftTotal(i)).deposit`. Because every later money step reads `booking.deposit` → `payment.amount` (refunds, #199's `milestoneAmounts` and #152's split, #134's payout lines), changing that one line is the only money change; Task 2 pins it with tests. Functions: two callables (`saveAddon`, `deleteAddon`), a Firestore catalogue reader for `createBooking`, booking mapping, seed. Firestore: `photographers/{uid}/addons/{addonId}` (public read when `active`, owner reads all, no client write). Flutter: `lib/data/addons/`, `lib/features/addons/` (S08.06, S08.07), the S04 flow (block on S04.01, pickup on S04.06, lines on S04.03), S05.02 block, S06.01 summary line.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 `onCall`, `node --test`), Firestore rules; Flutter, Riverpod 3, go_router, freezed (`build_runner`), `fake_cloud_firestore`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-08-booking-addons-design.md` (all; approved by the owner 2026-10-08, binding); mock `docs/design/ui-mock.html` frames `#S04.01-addons`, `#S04.06`, `#S04.03-addons`, `#S05.02-addons`, `#S08.06`, `#S08.07` (added together with the code-table rows, `lib/core/screen_codes.dart`, `specs/screens/booking.md` and `specs/screens/photographer.md` before this plan runs; treat them as done); `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` (100% upfront, two milestones); `docs/superpowers/specs/data-model/` (`README.md` conventions, `domain-model.md`, `relational-schema.md`); `docs/superpowers/plans/2026-10-08-s04-reconciliation.md` (real S04 names); cost unit prices `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`.

**Issue:** #190 (S04/S08 · Dịch vụ đi kèm khi đặt lịch). Phase 2 partner services are #191 (out of scope).

**Branch:** `plan/190-booking-addons` from `origin/develop`; PR into `develop` titled `feat(booking): S04 add-on services and S08.06–S08.07 [#190]`.

**Execution wave:** 5 (after the 2026-10-07 INDEX waves). **Blocked by:** #199 only (re-planned 2026-10-08; `2026-10-08-n2-booking-draft.md`: `BookingDraftInput`, `buildBookingDraft`, the `slot #190 (add-ons)` markers and `draftTotal` in `create_booking.ts`, `milestoneAmounts` in `milestones.ts`; this used to be "#152 Task 2 / Task 3", the only thing this plan needed from #152). **Not blockers:** #152 (its `splitMilestones` is built on `milestoneAmounts` and reads `payment.amount`, so a total flows through it with no code here; the one test that needs `shot` runs only if #152 has merged, else it is ledgered) and #139 (only `findContactLeak` and `DomainError.field` + `details.field`, which are create-if-absent, Decision 1; no file overlap otherwise). #198 (order gate) is not needed either: this plan leaves the gate call in `createBookingDraft` where it is, whichever unit put it there. Already merged on develop: #129, #134 (S06 payout lines, withholding, `platformFee`), #148 (S09 canonical settings order), #138 (S17), #147 (S10). Soft: #151 (S27, same wave 5) for the S27.07 line, Decision 18. Not needed: #136 (studio add-ons need nothing from S26, Decision 15).

**Owns (others consume):** `ServiceAddon`, `AddonInput`, `AddonLine`, `AddonPick`, `priceAddonLines`, `bookingTotal`, `requirePickup`, `addonsOf`, `saveAddon`/`deleteAddon` (domain and callables), `photographers/{uid}/addons`, Dart `lib/data/addons/`, core `QtyStepper`, `AppIcons.car`/`checkroom`/`addCircle`. **Reuses without redefining:** `buildBookingDraft` + `BookingDraftInput` (#199, extended only in its `slot #190 (add-ons)` markers and the `draftTotal` body), `milestoneAmounts` (#199) and `splitMilestones` (#152, when merged), `payoutLineOf` and the payout policy (#134), `findContactLeak` + `DomainError(code, field)` (#139), `computeDeposit`/`computeRefund` (#129), notifications (#138: no new type).

## Contract with existing code

Checked 2026-10-08 on `develop` 9d1b7f4. Task 1 Step 1 and Task 2 Step 1 re-check the names that #199 brings (merged before this plan) and whether #139's and #152's names are on develop yet (not blockers: Decision 1); adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- **Exists today (develop 9d1b7f4).**
  - Domain: `createBookingDraft(deps, raw)` (`create_booking.ts`: validate → `deps.services.getService` → `acceptsOrders` → `price_changed` against `expectedPrice` → `requireCustomerPhone` → `computeDeposit(service.price)` → transaction that replaces the customer's own draft for the same photographer and day); `validateCreateBookingDraftInput(raw, now)` and `CreateBookingDraftInput` (`booking_requests.ts`; `place {name, point?}` 3–120 graphemes, `graphemeCount`); `Booking` (`booking.ts`: `serviceSnapshot {name, price, durationMinutes}`, `place`, `deposit` = whole price, `remaining` 0, `checkout?`, `payableUntil?`); `BookingDeps {store, services, providers, contacts, gateway, clock, ids}` and `ServiceCatalog.getService(photographerId, serviceId)` → `ServiceRecord {id, photographerId, name, price, durationMinutes, active}` (`booking_ports.ts`); `computeDeposit(price)` → `{deposit, remaining}` and `computeRefund(deposit, percent)` (`booking_policy.ts`, `MIN_PLACE_LENGTH` 3, `MAX_PLACE_LENGTH` 120); `createPayment` charges `booking.deposit` (`create_payment.ts`); `commitTransition` refunds from `deposit`; `earningItemOf` reads `payment.amount`; `DomainError(code)`, `ERROR_CODES` (`errors.ts`); `isId` (`ids.ts`); the album CRUD pattern to copy (`album_ports.ts` `AlbumTx`/`AlbumStore`/`AlbumDeps`, `album_use_cases.ts`, `memory_album_store.ts`); `purity.test.ts`; `test/support/booking_world.ts`.
  - Functions: `handleCreateBooking(request, deps)` passes `{...request.data, customerId}` to `createBookingDraft` (`callables/booking.ts`, so new input fields need no adapter change); `liveBookingDeps()` (`infra/live_booking.ts`); `FirestoreServiceCatalog` (`infra/booking_readers.ts`); `bookingToFirestore`/`bookingFromFirestore` (`infra/booking_firestore.ts`) and the shared test `round-trips Booking through Firestore conversion` (`test/unit/booking_firestore.test.ts`); `toHttpsError` + `TRANSPORT_CODE` (`callables/errors.ts`); `CALLABLE_OPTIONS` (`config.ts`, region `asia-southeast1`); album callables as the CRUD pattern (`callables/album.ts`, `infra/album_firestore.ts`, `infra/live_album.ts`); seed `seed/fixtures.ts` (An `seed-photographer-an` with `seed-service-portrait` 1.500.000₫/120 min; Cúc `seed-photographer-cuc` studio) and `seed/README.md`.
  - Rules: `match /photographers/{uid}` with `match /services/{serviceId}` (client-written packages) and `match /private/{docId}` (owner reads; client writes only `contact`); `match /bookings/{bookingId}` read by the two parties, `write: if false`. Rules tests in `app_flutter/firebase/rules-test/rules.test.mjs`.
  - App: `BookingFlowState`/`BookingFlowController`/`BookingFlowArgs`, `BookingStep {service, datetime, place, review}`, `SubmitPhase`, outcomes `GoToPayment`/`NeedPhone` (`lib/features/booking/booking_flow_*.dart`); steps `service_step.dart` (`_PackageTile`, primary `bookContinuePrice`), `place_step.dart` (text field + suggestion chips, no map; wraps itself in `ScreenCode(ScreenCodes.bookReview)` today), `review_step.dart` (`MoneyBreakdown` with `bookPackageLine` + `bookDepositToday`, `bookPolicy`); `booking_sheet_page.dart` (`_handleError`); `profilePackagesProvider(uid)` → `List<ServiceSummary>`; `Booking` freezed (`lib/data/booking/booking.dart`, `bookingFromFirestore`, `const Booking._()`), `BookingRepository.createBooking({photographerId, serviceId, day, start, place, note, expectedPrice})`, `BookingErrorCode` + `bookingErrorOf` (`booking_repository.dart`), `FirestoreBookingRepository` (callable `createBooking`); `depositFor` (`booking_rules.dart`); `BookingDetailScreen` (S05.02), `CancelSheet` (S05.03, refund from `b.deposit`), `WorkScreen._RequestCard` (S06.01, shows `serviceSnapshot.price`), `workDashboard(mine, now)` month sum in `booking_view_rules.dart` (`serviceSnapshot.price`); `SetupPackagesScreen` (`/setup/2`, S08.01); owner menu in `photographer_profile_screen.dart` (`('edit-packages', l.profileEditPackages, AppIcons.tag, '/setup/2')`); `SettingsScreen`; `MoneyBreakdown`/`MoneyLine`, `AppBottomSheet`, `ConfirmSheet`, `SegmentedTabs`, `AppChip`, `GlassCard`, `EmptyState`, `ErrorState`, `AsyncView`, `AppSkeleton`, `SectionHeader`, `formatMoney`, `newUlid`; `functionsRegion` (`lib/data/backend/backend_config.dart`); a private `_Stepper` in `lib/features/events/register_sheet.dart` (keys `register-minus`, `register-quantity`, `register-plus`); `AppIcons.face` (`face_retouching_natural`), `AppIcons.autoAwesome`, `AppIcons.add`, `AppIcons.remove`, `AppIcons.tag`, `AppIcons.lock`, `AppIcons.info`, `AppIcons.place` (`location_on`); icon gallery built by `scripts/tools/build_ui_components.py` from the "Icons" table of `docs/superpowers/specs/components/shared-components.md`.
- **Added by the blocking plan #199 (verify in Step 1).** `BookingDraftCore {id, customerId, photographerId, service: ServiceRecord, day, start, place, note?, now}`, `BookingDraftInput extends BookingDraftCore` with one slot marker per unit (`// slot #139 (quotes)`, `// slot #136 (studio)`, `// slot #190 (add-ons)`) in the import block, the interface and the spread of `buildBookingDraft`; `draftTotal(i)` (body `return i.service.price; // slot #190 (add-ons): bookingTotal(i.service, i.addons ?? [])`); pure `buildBookingDraft(i): Booking` with `{deposit, remaining} = computeDeposit(draftTotal(i))`; `milestones.ts` `milestoneAmounts(net, percents?)`, `DEFAULT_MILESTONE_PERCENTS`. **From #152 if merged (not a blocker):** `splitMilestones(net, shotAt, percents?)` in the same `milestones.ts`, `net = payment.amount − escrowRefundedTotal(refunds)`. #134: `payoutLineOf(gross, payeeType, policy)`, `DEFAULT_PAYOUT_POLICY` (withholding and `platformFeeBp`). #139 (create-if-absent, Decision 1): `packages/domain/src/contact_filter.ts` `findContactLeak(text): 'phone' | 'email' | 'link' | 'zalo' | null`, `DomainError(code, field?)`, `toHttpsError` sets `details.field`. The order gate inside `createBookingDraft` (today `acceptsOrders`; #198's `assertOrderAllowed` once it lands) is left untouched. #148: S09.02 canonical group/row order (Decision 12 of its plan).
- **Not anywhere yet:** any add-on name, `pickup`, `AppIcons.car`/`checkroom`/`addCircle`, a core quantity stepper, `MapPreview` (#140 owns it, blocked by V1).

## Global Constraints

- Spec D6: "Server tính giá từ dữ liệu của nhà cung cấp; app chỉ gửi `addonId` + `qty`. Booking lưu bản chụp dịch vụ." The app's own sum is display only; `expectedTotal` is a staleness check, never a price source (Decision 4).
- Spec D7 / CLAUDE.md money rules: customers pay 100% up front; money held, released in two milestones; refund table S05.03, withholding and `platformFeeBp` all apply to the **total** (package + add-ons). Fake rails only (`PAYMENTS_MODE`, `confirmFakePayment`); no real intermediary.
- Spec D5: no adding or removing add-ons after payment (Phase 1). Spec D8: quotes (S15–S16) and Chụp ngay (S13–S14) have no add-ons (`buildBookingDraft` gets `addons = []`).
- Invariant (domain, tested): `deposit + remaining == bookingTotal(serviceSnapshot, addons) == serviceSnapshot.price + Σ addons.amount`; `amount = unitPrice × qty`.
- Limits (spec §3.1, mock `#S08.07`): ≤ 10 `active` add-ons per provider; name 2–60 graphemes; description ≤ 200; price integer VND 10.000–50.000.000; `maxQty` 1–10 (`per_booking` always 1); kinds `makeup | retouch | transport | outfit | other`; units `per_booking | per_person | per_item`; ≤ 10 lines per booking.
- `pickup` lives only in `bookings/{id}` (two parties read); never copied to a public document, a notification body or a chat message.
- CLAUDE.md: business rules only in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; `cloud_firestore`/`cloud_functions` only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; imports `package:photobooking/...`, features import `core/core.dart`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only (Material Symbols Rounded, 60-30-10); one primary action per screen (S04.01 "Tiếp tục · {tổng}", S04.03 "Thanh toán {tổng}", S08.06 "Thêm dịch vụ", S08.07 "Lưu"; delete is red text + red button in a confirm sheet); strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`.
- Data model (`data-model/README.md`): ULID ids (`deps.ids.newId()`), UTC ISO instants in the domain, Firestore `Timestamp` only in adapters, integer VND, string enum codes.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time, never the whole suite in one command; bounded pumps (`pump(Duration)`), no `pumpAndSettle` on screens with `DotRingLoader`/`SignatureLoader`.
- Domain: `(cd packages/domain && npm test && npm run lint)`. Functions: `(cd app_flutter/firebase/functions && npm test && npm run build)`. Rules tests and Functions integration tests are written, not run.
- Commits: Conventional Commits, subject ends with `[#190]`, body ends with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (owner's rule; never the Claude line).

## Decisions

1. **Blockers (re-planned 2026-10-08).** `buildBookingDraft` belongs to #199 (hard blocker: this plan fills only its `slot #190 (add-ons)` markers and the `draftTotal` body; if they are missing, Step 1 stops and reports). `findContactLeak` and `DomainError.field` belong to #139, which is **not** a blocker: if they are on develop, import them; if not, create them exactly as #139's plan specifies (`2026-10-07-s15-s16-job-posts.md` Decision 15 and its regex sample: `packages/domain/src/contact_filter.ts` with the same signature and its `contact_filter.test.ts` table; `DomainError(code, field?)`; `toHttpsError` adds `details.field`) and ledger it; #139 (and #151, which has the same rule) then consume them instead of creating a second copy. #152's `splitMilestones` is not needed (Decision 2).
2. **The amount source is the only money change.** Today and after #152/#134 every money step reads `booking.deposit` (→ `payment.amount` → refunds, `escrowRefundedTotal`, `splitMilestones(net, …)`, `payoutLineOf(milestone.amount, …)`, earnings). So the one-line body of #199's `draftTotal` becomes `return bookingTotal(i.service, i.addons ?? []);` (`buildBookingDraft` already sets `{deposit, remaining} = computeDeposit(draftTotal(i))`; the add-on slot never sets `deposit`/`remaining`) and no other money call site changes; Task 2 pins refund, milestone and payout-line amounts on the total with tests. If Step 1 finds a call site that reads `serviceSnapshot.price` as money (a regression from #152/#134), switch it to `bookingTotal(...)` there and ledger it.
3. **Error codes follow the spec** (`addon_changed`, `addon_not_applicable`, `pickup_required`, `addon_limit`, `contact_leak`), with #139's `field` for form errors (`name`, `description`, `price`, `maxQty`, `serviceIds`, `kind`, `unit`). The spec's `contact_leak` wins over #139's `invalid_argument` + `<field>.contact` convention for these callables (the spec is newer and owner-approved); the app maps both shapes to the same message so either works.
4. **Staleness check.** The app sends `expectedPrice` (package, existing) and new `expectedTotal`. Server order: package price differs → `price_changed` (existing); then priced lines; then `expectedTotal` present and ≠ `bookingTotal` → `addon_changed`. A `qty` above the add-on's current `maxQty` is also `addon_changed` (the app showed an older maximum); a non-integer, < 1 qty, or `per_booking` with qty ≠ 1 is `invalid_argument`.
5. **Line order.** `priceAddonLines` returns lines sorted by `ADDON_KINDS` order, then by the order of the picks; S04.03, S05.02 and S06.01 show them in that order.
6. **Booking fields are written only when used.** `addons` is written when non-empty and `pickup` when present; readers default to `[]`/absent. Old bookings, quotes and instant bookings stay byte-identical.
7. **Pickup without transport is dropped.** `requirePickup` returns `undefined` when no `transport` line exists, so a stray address is never stored; with a transport line and no pickup → `pickup_required`. Pickup shape = `place` (`name` 3–120 graphemes, optional `point {lat, lng}`).
8. **The 10-active limit is race-proof.** Every `saveAddon`/`deleteAddon` transaction reads and writes the lock document `photographers/{uid}/private/addons` (`{activeCount, updatedAt}`), so two concurrent "turn on" calls conflict and retry instead of both passing a count of 9. Rules already block client writes there (only `contact` is client-writable) and let the owner read it.
9. **Edits go through the callable with the full record**; the S08.06 switch calls `saveAddon` with the add-on's current fields and `active` flipped. `serviceIds` must name existing packages of the caller (active or hidden; hidden packages simply match nothing at booking). Unknown id → `invalid_argument` field `serviceIds`. Delete is a hard delete of the add-on document; bookings keep their snapshot lines.
10. **Customer reads are one-shot.** S04.01 loads active add-ons with a `get` (`activeAddonsProvider`, `FutureProvider.autoDispose.family`), not a listener; a change between load and pay is caught by `addon_changed`, which invalidates the provider and returns to S04.01. S08.06 (owner) uses a listener (`myAddonsProvider`).
11. **Entering with a preselected package** ("Đặt gói này", `args.serviceId`): today the flow skips S04.01. If that package has at least one applicable active add-on, the flow opens on S04.01 with the package selected so the "Thêm dịch vụ" block is seen; otherwise it skips as today. The decision is taken once, when packages and add-ons have both loaded, and never after the user has acted (Needs the owner 1).
12. **Any change to the package, picks or pickup clears `bookingId`.** Otherwise the sheet would reuse an earlier draft (created before a failed payment) whose add-ons differ from what the customer now sees; the next submit creates a fresh draft, which replaces the old one server-side (existing same-day draft replacement).
13. **S04.06 has no map in this plan.** The place step has none today, there is no point picker or geocoding, and `MapPreview` belongs to #140 (blocked by V1). The "Điểm đón" field copies the place field (text + the same suggestion chips + the lock note); the `place` step finally gets its own screen code `S04.06`. Map parity for both fields is Deferred (Needs the owner 2).
14. **Entry points to S08.06.** S09's canonical order (#148 Decision 12) has no "Nhận việc" group and no "Gói dịch vụ" row; packages are edited at `/setup/2` from the S03.01 owner menu (`edit-packages`). So: (a) settings row "Dịch vụ đi kèm" (`settings-addons`, photographers only) in the Tài khoản group right after "Hình thức nhận việc" (`profile-provider-type`); if the merged #148 screen has a "Nhận việc" group or a "Gói dịch vụ" row, put it next to that instead and ledger it; (b) owner menu entry `edit-addons` right after `edit-packages`; (c) S08.01 text button "Thêm dịch vụ đi kèm" under the package cards when at least one active package exists. All open `/me/addons`.
15. **Studios.** A studio's add-ons live under the studio account (`providerId` = studio uid = `booking.photographerId`); only the studio account edits them. Members and collaborators see the lines on S05.02 like the photographer side; their pay is unchanged (spec §6.4).
16. **Unit nouns.** `per_person` → "người"; `per_item` by kind: `retouch` → "ảnh", `outfit` → "bộ", others → "lần" (mock `#S08.07` caption: the spec has no unit field). `per_booking` prices read "{price} · một lần" and S04.03/S06.01 show the name only.
17. **Quantity stepper.** The private `_Stepper` of `register_sheet.dart` moves to core as `QtyStepper` (keys keep their `register-` prefix through a `keyPrefix` parameter, so S11.03 tests stay green) and serves S04.01; added to `shared-components.md` and the gallery.
18. **S27.07.** If #151 has merged when Task 7 runs, its offer sheet adds one line with the add-on names only (no prices, spec §6.4); if not, Task 7 comments the rule on #151 ("S27.07 shows add-on names from `booking.addons`, never prices or `pickup`") and ledgers it.
19. **S06.01 card amount.** The request card shows the booking total (`Booking.totalVnd`) instead of the package price, and the work dashboard's month sum uses the total, since the provider is paid on the total. Summary line: "+ " then each line's name, "×{qty}" when qty > 1, joined with " · ", one line with ellipsis.
20. **No new notification type.** Booking notices keep their content (#138); none of them mentions add-ons or the pickup. The S03.01 read-only add-on list (spec §11 default) waits for a mock frame (Deferred).

## Needs the owner

1. Entering from "Đặt gói này" with a package that has add-ons: open on S04.01 so the customer sees "Thêm dịch vụ", or keep skipping S04.01 (add-ons then cannot be added)? Default: open on S04.01 (Decision 11).
2. S04.06 shows a small map for the shoot place and the pickup in the mock; the app has no map or point picker yet. Default: text fields now, map with the location-picker work (Decision 13).
3. Settings entry: the spec says "nhóm Nhận việc, cạnh Gói dịch vụ", which S09.02 does not have. Default: row in Tài khoản after "Hình thức nhận việc" plus the S03.01 owner menu (Decision 14).

## Contract

### Firestore

`photographers/{uid}/addons/{addonId}` (ULID; server-only writes): `kind` (string code), `name`, `description` (absent when empty), `price` (int VND), `unit` (string code), `maxQty` (int), `serviceIds` (string[]; `[]` = every package), `active` (bool), `createdAt`, `updatedAt` (`Timestamp`). `providerId` is the path's `uid` (not stored; mapped from the path).

`photographers/{uid}/private/addons` (server-only lock, Decision 8): `activeCount` (int), `updatedAt`.

`bookings/{id}` adds (only when used, Decision 6): `addons: [{addonId, kind, name, unit, unitPrice, qty, amount}]`, `pickup: {name, point?: {lat, lng}}`. Mapping like `place`.

Rules (inside `match /photographers/{uid}`):
```
// Add-ons (spec 2026-10-08 §6.3): written only by saveAddon/deleteAddon. Anyone signed in reads an
// active one (a customer query must filter active == true); the owner reads all of theirs.
match /addons/{addonId} {
  allow get, list: if signedIn() && (resource.data.active == true || isOwner(uid));
  allow write: if false;
}
```
`bookings/{id}` rules are unchanged (two parties read, server writes). No new composite index (equality on `active` and document-id order use automatic indexes).

### Domain (`packages/domain/src`)

```ts
// addon.ts
export const ADDON_KINDS = ['makeup', 'retouch', 'transport', 'outfit', 'other'] as const;
export type AddonKind = (typeof ADDON_KINDS)[number];
export const ADDON_UNITS = ['per_booking', 'per_person', 'per_item'] as const;
export type AddonUnit = (typeof ADDON_UNITS)[number];
export const MAX_ACTIVE_ADDONS = 10;
export const ADDON_PRICE_MIN = 10_000;
export const ADDON_PRICE_MAX = 50_000_000;
export const ADDON_MAX_QTY = 10;
export const ADDON_NAME_MIN = 2;
export const ADDON_NAME_MAX = 60;
export const ADDON_DESCRIPTION_MAX = 200;
export const MAX_ADDON_SERVICE_IDS = 20;
export const MAX_BOOKING_ADDON_LINES = 10;
export interface ServiceAddon {
  readonly id: string; readonly providerId: string; readonly kind: AddonKind; readonly name: string;
  readonly description?: string; readonly price: number; readonly unit: AddonUnit; readonly maxQty: number;
  readonly serviceIds: readonly string[]; readonly active: boolean; readonly createdAt: string; readonly updatedAt: string;
}
export interface AddonInput {
  readonly addonId?: string; readonly kind: AddonKind; readonly name: string; readonly description?: string;
  readonly price: number; readonly unit: AddonUnit; readonly maxQty: number; readonly serviceIds: readonly string[];
  readonly active: boolean;
}
/** Trims, checks every limit, runs findContactLeak on name and description; `per_booking` → maxQty 1.
 *  Throws DomainError('invalid_argument', field) or DomainError('contact_leak', 'name' | 'description'). */
export function validateAddonInput(raw: unknown): AddonInput;
export function isAddonKind(v: unknown): v is AddonKind;
export function isAddonUnit(v: unknown): v is AddonUnit;

// addon_ports.ts
export interface AddonTx {
  /** photographers/{uid} exists and users/{uid}.role == 'photographer'. */
  isProvider(uid: string): Promise<boolean>;
  /** All add-ons of the provider, active or not, ordered by id. */
  listAddons(providerId: string): Promise<ServiceAddon[]>;
  /** Reads then writes photographers/{uid}/private/addons (Decision 8). Call before any write. */
  lockProvider(providerId: string): Promise<void>;
  putAddon(a: ServiceAddon): void;
  deleteAddon(providerId: string, addonId: string): void;
  setActiveCount(providerId: string, n: number, now: string): void;
}
export interface AddonStore { runTransaction<T>(fn: (tx: AddonTx) => Promise<T>): Promise<T>; }
/** Read side used by createBookingDraft (outside its transaction, like ServiceCatalog). */
export interface AddonCatalog { listAddons(providerId: string): Promise<ServiceAddon[]>; }
export interface AddonDeps {
  readonly addons: AddonStore; readonly services: ServiceCatalog; readonly clock: Clock; readonly ids: IdGenerator;
}

// addon_use_cases.ts
export async function saveAddon(deps: AddonDeps, callerId: string, raw: unknown): Promise<{ addonId: string }>;
export async function deleteAddon(deps: AddonDeps, callerId: string, raw: unknown): Promise<Record<string, never>>;

// memory_addon_store.ts
export class MemoryAddonStore implements AddonStore, AddonCatalog { /* providers: Set<string>; addons: Map; lock counts */ }

// addon_pricing.ts
export interface AddonPick { readonly addonId: string; readonly qty: number; }
export interface AddonLine {
  readonly addonId: string; readonly kind: AddonKind; readonly name: string; readonly unit: AddonUnit;
  readonly unitPrice: number; readonly qty: number; readonly amount: number;
}
export type BookingPickup = Booking['place'];
export function priceAddonLines(addons: readonly ServiceAddon[], picks: readonly AddonPick[], serviceId: string): AddonLine[];
export function bookingTotal(serviceSnapshot: { readonly price: number }, addons: readonly AddonLine[]): number;
export function requirePickup(addons: readonly AddonLine[], pickup: BookingPickup | undefined): BookingPickup | undefined;
export function addonsOf(b: Booking): readonly AddonLine[];   // b.addons ?? []
/** Throws Error('total_invariant') unless deposit + remaining == bookingTotal(b.serviceSnapshot, addonsOf(b)). */
export function assertBookingTotal(b: Booking): void;

// booking.ts: Booking adds
readonly addons?: readonly AddonLine[];
readonly pickup?: { readonly name: string; readonly point?: { readonly lat: number; readonly lng: number } };

// booking_ports.ts: BookingDeps adds
readonly addons: AddonCatalog;

// booking_requests.ts: CreateBookingDraftInput adds
readonly addons: readonly AddonPick[];        // [] when absent
readonly pickup?: BookingPickup;
readonly expectedTotal?: number;

// create_booking.ts (#199's builder): edit only the three `// slot #190 (add-ons)` markers and the draftTotal body.
// import block marker: import { bookingTotal, addonDraftFields } from './addon_pricing.js'; (+ AddonLine, BookingPickup types)
// BookingDraftInput marker:
readonly addons?: readonly AddonLine[];       // absent = []
readonly pickup?: BookingPickup;
// draftTotal body (the one money change): return bookingTotal(i.service, i.addons ?? []);
// buildBookingDraft spread marker: ...addonDraftFields(i),
// addon_pricing.ts: addonDraftFields(i): Partial<Booking> → {} when no add-on lines and no pickup;
//   else { addons } only when non-empty and { pickup } only when present. Never deposit/remaining.
// Every other order path (#139 quotes, #136 studio, #151) passes nothing, so draftTotal = service.price for them.

// errors.ts: ERROR_CODES adds
'addon_changed', 'addon_not_applicable', 'pickup_required', 'addon_limit', 'contact_leak'
```

### Callables (Functions, `asia-southeast1`, `CALLABLE_OPTIONS`)

| Callable | Input | Output | Errors (`details.code`, `details.field` when a field is wrong) |
|---|---|---|---|
| `saveAddon` | `{addonId?, kind, name, description?, price, unit, maxQty, serviceIds, active}` | `{addonId}` | `invalid_argument` (field), `contact_leak` (field `name`/`description`), `addon_limit`, `permission_denied` (not a provider), `not_found` (unknown `addonId` of the caller) |
| `deleteAddon` | `{addonId}` | `{}` | `invalid_argument`, `not_found`, `permission_denied` |
| `createBooking` (exists) | adds `addons?: [{addonId, qty}]`, `pickup?: {name, point?}`, `expectedTotal?` | unchanged (`Booking`) | adds `addon_changed`, `addon_not_applicable`, `pickup_required` |

Transport codes (`callables/errors.ts`): `addon_changed`, `addon_not_applicable`, `pickup_required` → `failed-precondition`; `addon_limit` → `resource-exhausted`; `contact_leak` → `invalid-argument`.

### App (`app_flutter/lib`)

```dart
// lib/data/addons/service_addon.dart
enum AddonKind { makeup, retouch, transport, outfit, other; String get code; static AddonKind? fromCode(String? c); }
enum AddonUnit { perBooking('per_booking'), perPerson('per_person'), perItem('per_item'); final String code; static AddonUnit? fromCode(String? c); }
const kMaxActiveAddons = 10; const kAddonPriceMin = 10000; const kAddonPriceMax = 50000000; const kAddonMaxQty = 10;
@immutable class ServiceAddon {
  const ServiceAddon({required this.id, required this.providerId, required this.kind, required this.name, this.description,
    required this.priceVnd, required this.unit, required this.maxQty, this.serviceIds = const [], this.active = true});
  bool appliesTo(String serviceId) => serviceIds.isEmpty || serviceIds.contains(serviceId);
}
ServiceAddon? serviceAddonFromFirestore(String id, String providerId, Map<String, dynamic>? data);
@immutable class AddonInput { /* addonId?, kind, name, description?, priceVnd, unit, maxQty, serviceIds, active; toCallable() */ }
@immutable class AddonPick { const AddonPick(this.addonId, this.qty); final String addonId; final int qty; }
/// Same rules as the server, for errors under the fields before calling.
Map<AddonField, AddonFieldError> validateAddonInput(AddonInput input);
enum AddonField { kind, name, description, price, unit, maxQty, serviceIds }
enum AddonFieldError { nameLength, descriptionLength, priceRange, maxQtyRange, contact, packagesEmpty }

// lib/data/addons/addon_repository.dart
abstract class AddonRepository {
  Future<List<ServiceAddon>> activeFor(String providerId);   // where active == true, ordered by kind then id
  Stream<List<ServiceAddon>> watchMine(String uid);          // all of the owner's, ordered by id
  Future<String> save(AddonInput input);                     // callable saveAddon → addonId
  Future<void> delete(String addonId);                       // callable deleteAddon
}
enum AddonErrorCode { invalidArgument, contactLeak, addonLimit, notFound, permissionDenied, network, unknown }
class AddonError { const AddonError(this.code, {this.field}); final AddonErrorCode code; final AddonField? field; }
AddonError addonErrorOf(Object error);   // reads details.code/details.field; "<field>.contact" also → contactLeak

// lib/data/addons/firestore_addon_repository.dart: FirestoreAddonRepository({FirebaseFirestore? db, FirebaseFunctions? functions})
// lib/data/addons/addon_providers.dart
final addonRepositoryProvider = Provider<AddonRepository>((ref) => FirestoreAddonRepository());
final activeAddonsProvider = FutureProvider.autoDispose.family<List<ServiceAddon>, String>(...);   // providerId
final myAddonsProvider = StreamProvider.autoDispose.family<List<ServiceAddon>, String>(...);       // uid

// lib/data/booking/booking.dart
@freezed abstract class BookingAddonLine with _$BookingAddonLine {
  const factory BookingAddonLine({required String addonId, required String kind, required String name,
    required String unit, required int unitPrice, required int qty, required int amount}) = _BookingAddonLine;
}
// Booking adds: @Default(<BookingAddonLine>[]) List<BookingAddonLine> addons, BookingPlace? pickup,
// and `int get totalVnd => serviceSnapshot.price + addons.fold(0, (s, l) => s + l.amount);`

// lib/data/booking/booking_repository.dart
// createBooking adds: List<AddonPick> addons = const [], BookingPlace? pickup, int? expectedTotal
// BookingErrorCode adds: addonChanged, addonNotApplicable, pickupRequired

// lib/core/widgets/qty_stepper.dart (exported from core.dart)
class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.min, required this.max, required this.onChanged,
    required this.decrementLabel, required this.incrementLabel, required this.valueLabel, this.keyPrefix = 'qty'});
}
// lib/core/theme/app_icons.dart adds
static const IconData car = Symbols.directions_car_rounded;
static const IconData checkroom = Symbols.checkroom_rounded;
static const IconData addCircle = Symbols.add_circle_rounded;

// lib/features/addons/addon_format.dart
IconData addonKindIcon(AddonKind k);                 // makeup→face, retouch→autoAwesome, transport→car, outfit→checkroom, other→addCircle
String addonKindLabel(AppLocalizations l, AddonKind k);
String addonUnitNoun(AppLocalizations l, AddonKind kind, AddonUnit unit);   // Decision 16
String addonPriceLabel(AppLocalizations l, {required AddonKind kind, required AddonUnit unit, required int priceVnd});
String addonLineLabel(AppLocalizations l, BookingAddonLine line);           // S04.03 "Trang điểm · 2 người" / name only
String addonsSummary(AppLocalizations l, List<BookingAddonLine> lines);     // S06.01 "+ Trang điểm ×2 · Xe đón"
```

Routes: `/me/addons` → `AddonsScreen()` (S08.06); S08.07 is a sheet `showAddonEditSheet(context, {ServiceAddon? addon})`.

Screen codes (already in `lib/core/screen_codes.dart`, added with the mock): `ScreenCodes.bookPlace` (S04.06), `ScreenCodes.myAddons` (S08.06), `ScreenCodes.editAddon` (S08.07).

### l10n keys (`lib/l10n/app_vi.arb`, exact text)

- Kinds and units: `addonKindMakeup` "Trang điểm"; `addonKindRetouch` "Chỉnh ảnh"; `addonKindTransport` "Đưa đón"; `addonKindOutfit` "Trang phục"; `addonKindOther` "Khác"; `addonUnitPerBooking` "Một lần"; `addonUnitPerPerson` "Theo người"; `addonUnitPerItem` "Theo số lượng"; `addonNounPerson` "người"; `addonNounPhoto` "ảnh"; `addonNounOutfit` "bộ"; `addonNounTime` "lần"; `addonPriceOnce` "{price} · một lần"; `addonPricePer` "{price} / {unit}"; `addonOnce` "Một lần".
- S04.01: `bookAddonsTitle` "Thêm dịch vụ"; `bookAddonsOptional` "Không bắt buộc"; `bookAddonLess` "Bớt một {unit}"; `bookAddonMore` "Thêm một {unit}"; `bookAddonQty` "{name}: {qty} {unit}"; `bookAddonDropped` "Đã bỏ {names} vì không áp dụng cho gói này"; `bookAddonsChanged` "Dịch vụ đi kèm vừa thay đổi, kiểm tra lại trước khi thanh toán".
- S04.06: `bookPickupTitle` "Điểm đón"; `bookPickupHint` "Tên điểm đón (tối thiểu 3 ký tự)"; `bookPickupPrivate` "Chỉ thợ chụp cho bạn thấy điểm đón."; `bookPickupRequired` "Nhập điểm đón cho xe đưa đón".
- S04.03: `bookAddonLineQty` "{name} · {qty} {unit}"; `bookPickupLine` "Điểm đón: {name}".
- S05.02: `detailAddonsTitle` "Dịch vụ đi kèm"; `detailAddonQtyPrice` "{qty} {unit} × {price}"; `detailPickupTitle` "Điểm đón".
- S06.01: `workAddonsSummary` "+ {items}"; `workAddonItemQty` "{name} ×{qty}".
- S08.06: `addonsTitle` "Dịch vụ đi kèm"; `addonsActiveCount` "{n}/{max} dịch vụ đang bật"; `addonsAdd` "Thêm dịch vụ"; `addonsEmptyTitle` "Chưa có dịch vụ đi kèm"; `addonsEmptyBody` "Thêm trang điểm, chỉnh ảnh hay xe đưa đón để khách chọn khi đặt lịch."; `addonsAppliesAll` "Áp dụng: mọi gói"; `addonsAppliesSome` "Áp dụng: {names}"; `addonsToggle` "Bật {name}"; `addonsLimitReached` "Bạn đã bật đủ 10 dịch vụ. Tắt bớt một dịch vụ để bật dịch vụ này."; `addonsLoadError` "Không tải được dịch vụ đi kèm."
- S08.07: `addonNewTitle` "Thêm dịch vụ đi kèm"; `addonEditTitle` "Sửa dịch vụ đi kèm"; `addonKindField` "Loại"; `addonNameField` "Tên dịch vụ"; `addonDescriptionField` "Mô tả · không bắt buộc"; `addonUnitField` "Cách tính"; `addonPriceField` "Giá (₫)"; `addonPricePerField` "Giá / {unit} (₫)"; `addonMaxQtyField` "Tối đa"; `addonMaxQtyValue` "{n} {unit}"; `addonAppliesTo` "Áp dụng cho"; `addonAppliesAll` "Mọi gói"; `addonAppliesPick` "Chọn gói"; `addonResponsibility` "Bạn chịu trách nhiệm với khách về dịch vụ này, kể cả khi thuê người ngoài."; `addonSave` "Lưu"; `addonDelete` "Xoá dịch vụ"; `addonDeleteTitle` "Xoá {name}?"; `addonDeleteBody` "Booking đã đặt vẫn giữ dịch vụ này."; `addonDeleteConfirm` "Xoá"; `addonErrorName` "Tên 2–60 ký tự"; `addonErrorDescription` "Mô tả tối đa 200 ký tự"; `addonErrorPrice` "Giá từ 10.000₫ tới 50.000.000₫"; `addonErrorMaxQty` "Tối đa từ 1 tới 10"; `addonErrorContact` "Bỏ số điện thoại, Zalo hoặc link ra khỏi nội dung"; `addonErrorPackages` "Chọn ít nhất một gói"; `addonErrorGeneric` "Không lưu được. Thử lại."; `addonSaved` "Đã lưu dịch vụ"; `addonDeleted` "Đã xoá dịch vụ".
- Entry points: `settingsAddons` "Dịch vụ đi kèm"; `settingsAddonsBody` "Trang điểm, chỉnh ảnh, xe đưa đón khi khách đặt lịch"; `profileEditAddons` "Sửa dịch vụ đi kèm"; `setupAddAddons` "Thêm dịch vụ đi kèm". (The last four are not in the mock; ledger them.)

## Review Focus

1. **The customer pays an amount the app computed.** A modified client sends a lower `expectedTotal` or forged prices; the server must charge `bookingTotal` from Firestore data only. Pinned: Task 2 `createBookingDraft charges the server total whatever expectedTotal says` (mismatch → `addon_changed`, no draft), Task 3 `createBooking prices add-ons from Firestore, not from the request`.
2. **Paying for a stale draft.** The customer changes add-ons after a draft was created (failed payment, back, edit): the sheet must not reuse the old `bookingId`. Pinned: Task 6 `changing picks after a draft clears bookingId and the next submit creates a new draft with the new picks`.
3. **11 add-ons switched on at once.** Two quick toggles from two devices both read 9 active. Pinned: Task 1 `two concurrent turn-on transactions cannot both pass` (memory store serializes on the lock and the second sees 10), Task 3 `the Firestore store reads and writes private/addons in every transaction`.
4. **The pickup address leaks.** Pinned: Task 3 rules tests (`a third user cannot read a booking with pickup`; no public path stores it), Task 2 `pickup is dropped when no transport line exists`, Task 7 `notification content for a booking with pickup contains no pickup text` (render the `booking_request` and `booking_accepted` notices and assert).
5. **Refund or milestone on the package price only.** A cancellation 24–48 h before refunds 50% of the package instead of the total, or milestone 2 misses the add-ons. Pinned: Task 2 `refund at 24–48 h is 50% of the total`, `milestones of a booking with add-ons sum to the total`, `payout line gross for the shoot milestone is half the total`; Task 7 `S05.03 shows the refund of the total`.

## Chi phí Google

Unit prices from `2026-10-07-google-cloud-costs.md`: Firestore upper bound nam5 $0.06/100K reads, $0.18/100K writes (Singapore **chưa xác nhận**); Functions Tier 2, 2M calls and 180K vCPU-s free per month. Assumptions: 20% of MAU are providers; a customer opens 2 booking sheets a month; 300 bookings/month at 1,000 MAU, 3,000 at 10,000 MAU; a provider saves add-ons 3 times a month; 4 active add-ons on average.

- **Per user action.** S04.01 open: one `get` of `addons where active == true` ≈ 4 reads (≤ 10). `createBooking`: + one `listAddons` query ≈ 4 reads, no extra write (the lines ride in the booking write). S08.06 open: listener ≈ 4 reads + 1 per change while open. `saveAddon`: lock read+write, `listAddons` ≈ 4 reads, ≤ 20 package reads (usually 0–3) → ≈ 8 reads, 2 writes. `deleteAddon`: ≈ 6 reads, 2 writes.
- **New callables:** `saveAddon`, `deleteAddon`: 600 calls/month at 1,000 MAU, 6,000 at 10,000 MAU (inside the free 2M; ≈ 0.2 vCPU-s each → 1,200 vCPU-s, inside 180K). No new trigger.
- **Scheduled jobs:** none. **Storage:** none. **Paid APIs:** none (no map, Decision 13).
- **Monthly totals.** (b) 1,000 MAU: reads ≈ 6,400 (sheets) + 1,200 (bookings) + 1,600 (S08.06) + 4,800 (saves) ≈ 14K → $0.008; writes ≈ 1,200 → $0.002; **≈ +$0.01/month**. (c) 10,000 MAU: ≈ 140K reads → $0.08; 12K writes → $0.02; **≈ +$0.10/month**. Below $5 at (c); no mitigation needed. Matches spec §9 (≈ +$0).

## Tasks

### Task 1: Domain — add-on catalogue, `saveAddon`, `deleteAddon`

**Files:**
- Create: `packages/domain/src/addon.ts`, `packages/domain/src/addon_ports.ts`, `packages/domain/src/addon_use_cases.ts`, `packages/domain/src/memory_addon_store.ts`; tests `packages/domain/test/addon.test.ts`, `packages/domain/test/addon_use_cases.test.ts`.
- Modify: `packages/domain/src/errors.ts` (five codes), `packages/domain/src/index.ts` (exports); `docs/superpowers/specs/data-model/domain-model.md` (§2.2 entity `ServiceAddon`; §4 enums `AddonKind`, `AddonUnit`, the five error codes; §6 invariant "tối đa 10 dịch vụ đi kèm đang bật mỗi nhà cung cấp"), `docs/superpowers/specs/data-model/relational-schema.md` (`service_addons(id, provider_id, kind, name, description, price_vnd, unit, max_qty, active, created_at, updated_at)`, `service_addon_services(addon_id, service_id)`; Vietnamese prose like the rest of the file).

**Interfaces:**
- Consumes: `findContactLeak` (`contact_filter.ts`, #139; create-if-absent, Decision 1), `DomainError(code, field?)` (#139; create-if-absent), `ServiceCatalog`, `Clock`, `IdGenerator`, `graphemeCount` (`booking_requests.ts`), `isId`.
- Produces: Contract → Domain `addon.ts`, `addon_ports.ts`, `addon_use_cases.ts`, `memory_addon_store.ts`, the five `ERROR_CODES`.

- [ ] **Step 1: Contract check.** Confirm #199's `buildBookingDraft` and its `slot #190 (add-ons)` markers exist on `origin/develop` (stop if not). Check #139's `findContactLeak` and the `DomainError` `field` constructor: present → use them; absent → create them exactly as #139 Decision 15 specifies (with its `contact_filter.test.ts` table) and ledger it (Decision 1).
- [ ] **Step 2: Failing tests.**
  - `addon.test.ts`: `validateAddonInput trims name and accepts 2 and 60 graphemes`; `refuses 1 and 61 graphemes with field name`; `refuses a 201-grapheme description with field description; an empty description becomes absent`; `refuses price 9_999, 50_000_001 and 10_000.5 with field price; accepts 10_000 and 50_000_000`; `refuses maxQty 0, 11 and 2.5 with field maxQty for per_person and per_item`; `per_booking stores maxQty 1 whatever was sent`; `refuses an unknown kind (field kind) and unit (field unit)`; `refuses serviceIds that are not ids, duplicated, or more than 20 (field serviceIds)`; `refuses "Gọi 0903 123 456" in the name with contact_leak field name`; `refuses "zalo.me/0912345678" in the description with contact_leak field description`; `accepts "Chỉnh thêm 10 ảnh, giao trong 3 ngày"` (digits that are not a phone); `active must be a boolean`; `addonId when present must be an id`.
  - `addon_use_cases.test.ts` (memory store, fake clock and ids): `saveAddon creates an add-on with a new id, providerId = caller, createdAt = updatedAt = now`; `saveAddon updates the caller's add-on and keeps createdAt`; `an unknown addonId is not_found and writes nothing`; `another provider's addonId is not_found (paths are per provider)`; `a caller without a provider profile is permission_denied`; `serviceIds naming a package the caller does not have is invalid_argument field serviceIds`; `a hidden package is accepted in serviceIds`; `creating the 11th active add-on is addon_limit`; `creating an 11th inactive add-on succeeds`; `turning on an inactive add-on while 10 are active is addon_limit`; `editing an already active add-on while 10 are active succeeds`; `turning off then on again counts correctly (activeCount written each time)`; `two concurrent turn-on transactions cannot both pass` (start two `saveAddon` calls with 9 active; exactly one resolves, the other rejects `addon_limit`; the memory store runs transactions one at a time and `lockProvider` is required before writes); `deleteAddon removes the add-on and updates activeCount`; `deleteAddon of an unknown id is not_found`; `deleteAddon by a non-provider is permission_denied`.
- [ ] **Step 3:** `cd packages/domain && npm test` → the new tests fail.
- [ ] **Step 4: Implement.** `MemoryAddonStore` follows `memory_album_store.ts` (refuse a read after a write inside a transaction; serialize transactions with a promise chain so the concurrency test is deterministic). Hard part, `saveAddon`:
  ```ts
  export async function saveAddon(deps: AddonDeps, callerId: string, raw: unknown): Promise<{ addonId: string }> {
    const input = validateAddonInput(raw);
    for (const sid of input.serviceIds) {
      if (!(await deps.services.getService(callerId, sid))) throw new DomainError('invalid_argument', 'serviceIds');
    }
    const now = deps.clock.now().toISOString();
    return deps.addons.runTransaction(async (tx) => {
      if (!(await tx.isProvider(callerId))) throw new DomainError('permission_denied');
      await tx.lockProvider(callerId);                        // Decision 8: serializes concurrent saves
      const all = await tx.listAddons(callerId);
      const existing = input.addonId === undefined ? null : all.find((a) => a.id === input.addonId) ?? null;
      if (input.addonId !== undefined && existing === null) throw new DomainError('not_found');
      const othersActive = all.filter((a) => a.active && a.id !== existing?.id).length;
      const turningOn = input.active && !(existing?.active ?? false);
      if (turningOn && othersActive >= MAX_ACTIVE_ADDONS) throw new DomainError('addon_limit');
      const id = existing?.id ?? deps.ids.newId();
      tx.putAddon({
        id, providerId: callerId, kind: input.kind, name: input.name,
        ...(input.description ? { description: input.description } : {}),
        price: input.price, unit: input.unit, maxQty: input.unit === 'per_booking' ? 1 : input.maxQty,
        serviceIds: input.serviceIds, active: input.active,
        createdAt: existing?.createdAt ?? now, updatedAt: now,
      });
      tx.setActiveCount(callerId, othersActive + (input.active ? 1 : 0), now);
      return { addonId: id };
    });
  }
  ```
  `deleteAddon`: parse `{addonId}` (`isId` else `invalid_argument`), same provider check and lock, `not_found` when absent, `deleteAddon` + `setActiveCount`. Export everything from `index.ts`. Update the two data-model files.
- [ ] **Step 5:** `cd packages/domain && npm test && npm run lint` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): service add-ons with saveAddon and deleteAddon [#190]`.

### Task 2: Domain — pricing, total and pickup on the booking draft

**Files:**
- Create: `packages/domain/src/addon_pricing.ts`; tests `packages/domain/test/addon_pricing.test.ts`, `packages/domain/test/booking_addons_money.test.ts`.
- Modify: `packages/domain/src/booking.ts` (`addons?`, `pickup?`), `booking_ports.ts` (`BookingDeps.addons: AddonCatalog`), `booking_requests.ts` (parse `addons`, `pickup`, `expectedTotal`), `create_booking.ts` (only #199's three `slot #190 (add-ons)` markers and the `draftTotal` body; wire `createBookingDraft`), `index.ts`, `test/support/booking_world.ts` (a `MemoryAddonStore` as `addons`, helper `withAddons(world, providerId, addons)`), `test/create_booking.test.ts`, and every other `BookingDeps` literal in domain tests (TypeScript lists them); `docs/superpowers/specs/data-model/domain-model.md` (§2.4 booking fields `addons`, `pickup`; §6 invariant "tổng booking = giá gói + Σ dịch vụ đi kèm; mọi khoản tiền tính trên tổng"), `relational-schema.md` (`booking_addons(booking_id, addon_id, kind, name, unit, unit_price_vnd, qty, amount_vnd)`, `bookings.pickup_name`, `bookings.pickup_point`).

**Interfaces:**
- Consumes: Task 1 (`ServiceAddon`, `AddonCatalog`, `MemoryAddonStore`, error codes); #199 `BookingDraftInput`, `buildBookingDraft`, `draftTotal`, `milestoneAmounts`; #152 `splitMilestones` only if merged; #134 `payoutLineOf`, `DEFAULT_PAYOUT_POLICY`; #129 `computeDeposit`, `computeRefund`, `createPayment`, `FakePaymentGateway.pushTransfer`; the order gate call in `createBookingDraft` (`acceptsOrders` today, #198's `assertOrderAllowed` once merged) stays where it is.
- Produces: Contract → Domain `addon_pricing.ts` (with `addonDraftFields`), the `Booking`/`BookingDeps`/`CreateBookingDraftInput`/`BookingDraftInput` additions.

- [ ] **Step 1: Contract check.** Read #199's `buildBookingDraft`, its slot markers and `draftTotal`, and the current `createBookingDraft` order (gate, `price_changed`, phone, transaction); list every money call site that reads `deposit`, `payment.amount` or `serviceSnapshot.price` (`grep -rn "serviceSnapshot.price\|\.deposit\b" packages/domain/src`) and ledger it; Decision 2 applies.
- [ ] **Step 2: Failing tests.**
  - `addon_pricing.test.ts` (fixtures: makeup `per_person` 800.000 max 4 all packages; retouch `per_item` 20.000 max 10; transport `per_booking` 300.000 only `svc-portrait`; outfit inactive):
    - `per_booking line: qty 1, amount = price`; `per_person 2 → 1.600.000`; `per_item 10 → 200.000`.
    - `lines are sorted by kind order then pick order` (picks transport, makeup → makeup first).
    - `an unknown addonId is addon_changed`; `an inactive add-on is addon_changed`; `qty above the current maxQty is addon_changed`.
    - `transport on svc-family is addon_not_applicable`; `serviceIds [] applies to every package`.
    - `qty 0, -1, 1.5 is invalid_argument`; `per_booking with qty 2 is invalid_argument`; `a duplicated addonId is invalid_argument`; `11 picks are invalid_argument`; `[] picks give []`.
    - `bookingTotal = price + Σ amount` and `bookingTotal(…, []) = price`.
    - `total invariant holds for 200 random baskets` (seeded generator: random prices in range, random picks within limits; `computeDeposit(bookingTotal).deposit + remaining == bookingTotal` and `assertBookingTotal` passes on the built draft).
    - `requirePickup: transport without pickup is pickup_required`; `transport with pickup returns it`; `pickup is dropped when no transport line exists`.
  - `create_booking.test.ts` (additions): `buildBookingDraft with addons sets deposit to the total and remaining 0`; `buildBookingDraft without addons writes no addons field and no pickup` (#199's key-set test stays green); `addonDraftFields returns {} without add-ons and pickup`; `draftTotal is the package price without add-ons and the total with them`; `createBookingDraft prices picks from the catalogue and stores the lines`; `createBookingDraft charges the server total whatever expectedTotal says` (expectedTotal lower → `addon_changed`, no booking, no day hold); `matching expectedTotal succeeds`; `a changed package price is still price_changed before any add-on check`; `pickup_required without pickup when transport is picked`; `the pickup is stored when transport is picked`; `a closed provider is still refused before add-ons are read` (order unchanged: gate first).
  - `booking_addons_money.test.ts` (booking world, fake gateway): basket portrait 1.500.000 + makeup ×2 1.600.000 + transport 300.000 = 3.400.000.
    - `createPayment charges the total` (payment.amount 3.400.000; checkout.amount 3.400.000).
    - `cancel ≥ 48 h before refunds 100% of the total`; `refund at 24–48 h is 50% of the total` (1.700.000).
    - `milestone amounts of a booking with add-ons sum to the total` (#199's `milestoneAmounts(payment.amount)`: shoot 1.700.000, delivery 1.700.000). Only if #152 has merged, also `milestones after shot sum to the total` through #152's `splitMilestones`; otherwise ledger it as deferred to #152.
    - `payout line gross for the shoot milestone is half the total` (`payoutLineOf(milestoneAmounts(3_400_000).shoot, 'individual', DEFAULT_PAYOUT_POLICY).gross === 1_700_000`).
- [ ] **Step 3:** `npm test` → new tests fail.
- [ ] **Step 4: Implement.** Hard part, pricing and the total invariant:
  ```ts
  export function priceAddonLines(addons: readonly ServiceAddon[], picks: readonly AddonPick[], serviceId: string): AddonLine[] {
    if (picks.length > MAX_BOOKING_ADDON_LINES) throw new DomainError('invalid_argument');
    const seen = new Set<string>();
    const lines = picks.map((p, i) => {
      if (seen.has(p.addonId) || !Number.isInteger(p.qty) || p.qty < 1) throw new DomainError('invalid_argument');
      seen.add(p.addonId);
      const a = addons.find((x) => x.id === p.addonId);
      if (!a || !a.active) throw new DomainError('addon_changed');
      if (a.serviceIds.length > 0 && !a.serviceIds.includes(serviceId)) throw new DomainError('addon_not_applicable');
      if (a.unit === 'per_booking' && p.qty !== 1) throw new DomainError('invalid_argument');
      if (p.qty > a.maxQty) throw new DomainError('addon_changed');            // Decision 4
      return { order: i, line: { addonId: a.id, kind: a.kind, name: a.name, unit: a.unit,
                                 unitPrice: a.price, qty: p.qty, amount: a.price * p.qty } };
    });
    return lines
      .sort((x, y) => ADDON_KINDS.indexOf(x.line.kind) - ADDON_KINDS.indexOf(y.line.kind) || x.order - y.order)
      .map((x) => x.line);
  }
  export const bookingTotal = (s: { readonly price: number }, addons: readonly AddonLine[]): number =>
    addons.reduce((sum, l) => sum + l.amount, s.price);
  ```
  `createBookingDraft` order after validation: service → (order gate, unchanged: `acceptsOrders` or #198's `assertOrderAllowed`) → `price_changed` → `const addons = priceAddonLines(await deps.addons.listAddons(input.photographerId), input.addons, input.serviceId)` (skip the read when `input.addons` is empty) → `const pickup = requirePickup(addons, input.pickup)` → `expectedTotal` check (`addon_changed`) → phone → transaction writing `buildBookingDraft({..., addons, pickup})`. `create_booking.ts`: `draftTotal` body → `return bookingTotal(i.service, i.addons ?? []);` and the spread marker → `...addonDraftFields(i),` (`addons` only when non-empty, `pickup` only when present, `{}` otherwise); nothing else in the builder or the other slots changes. Request parsing: `addons` absent → `[]`, not an array → `invalid_argument`, each `{addonId: isId, qty: number}`; `pickup` parsed exactly like `place`; `expectedTotal` a non-negative integer when present.
- [ ] **Step 5:** `npm test && npm run lint` green.
- [ ] **Step 6: Commit** `feat(domain): price add-ons on the booking draft and charge the total [#190]`.

### Task 3: Functions, rules and seed

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/addon_firestore.ts`, `src/infra/live_addon.ts`, `src/callables/addon.ts`; tests `test/unit/addon_callables.test.ts`, `test/unit/addon_firestore.test.ts`.
- Modify: `src/index.ts` (exports `saveAddon`, `deleteAddon`), `src/callables/errors.ts` (five codes), `src/infra/booking_firestore.ts` (map `addons`, `pickup`), `src/infra/live_booking.ts` (`addons: new FirestoreAddonCatalog(firestore)`), `seed/fixtures.ts`, `seed/README.md`, `test/unit/booking_firestore.test.ts`, `test/unit/booking_callables.test.ts`, `test/unit/errors.test.ts`, `test/unit/seed_fixtures.test.ts`, every test that builds `BookingDeps` (TypeScript lists them); `app_flutter/firebase/firestore.rules`; `app_flutter/firebase/rules-test/rules.test.mjs`.

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:
  ```ts
  // infra/addon_firestore.ts
  export function addonToFirestore(a: ServiceAddon): DocumentData;            // no providerId, Timestamps
  export function addonFromFirestore(providerId: string, id: string, d: DocumentData | undefined): ServiceAddon | null;
  export class FirestoreAddonStore implements AddonStore { constructor(firestore: Firestore = db()) }
  export class FirestoreAddonCatalog implements AddonCatalog { constructor(firestore: Firestore = db()) }
  // infra/live_addon.ts
  export function liveAddonDeps(): AddonDeps;   // services: FirestoreServiceCatalog
  // callables/addon.ts
  export async function handleSaveAddon(request: CallableInput, deps: AddonDeps): Promise<{ addonId: string }>;
  export async function handleDeleteAddon(request: CallableInput, deps: AddonDeps): Promise<Record<string, never>>;
  // index.ts
  export const saveAddon = onCall(CALLABLE_OPTIONS, (request) => handleSaveAddon(request, liveAddonDeps()));
  export const deleteAddon = onCall(CALLABLE_OPTIONS, (request) => handleDeleteAddon(request, liveAddonDeps()));
  ```
  `FirestoreAddonStore.isProvider(uid)`: `photographers/{uid}` exists and `users/{uid}.role == 'photographer'` (both read in the transaction). `lockProvider`: `tx.get(photographers/{uid}/private/addons)` then `tx.set(..., {activeCount, updatedAt}, {merge: true})` (the set happens in `setActiveCount`; every use case calls both). Reads all happen before writes (Admin SDK rule).

- [ ] **Step 1:** Contract check (callable patterns of `callables/album.ts`, `details.field` in `toHttpsError` from #139; if absent, add it here as #139 specifies, create-if-absent); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `addon_firestore.test.ts`: `addon round-trips through Firestore conversion` (every field; description absent stays absent; `providerId` from the path); `a document with an unknown kind or unit maps to null`; `FirestoreAddonStore reads and writes private/addons in every transaction` (fake Firestore records the lock path on save and delete).
  - `addon_callables.test.ts`: `saveAddon without auth is unauthenticated with code permission_denied`; `saveAddon returns {addonId} and passes the caller uid`; `contact_leak maps to invalid-argument with details.code contact_leak and details.field name`; `addon_limit maps to resource-exhausted`; `deleteAddon of an unknown id is not-found`; `a customer calling saveAddon is permission-denied`.
  - `booking_firestore.test.ts`: extend the shared `round-trips Booking through Firestore conversion` with `addons` (two lines) and `pickup {name, point}`; `a booking without add-ons writes neither addons nor pickup`.
  - `booking_callables.test.ts`: `createBooking prices add-ons from Firestore, not from the request` (request carries `unitPrice: 1` and `amount: 1` on a pick → ignored; stored lines use the catalogue price; deposit = total); `createBooking with a deactivated add-on is failed-precondition addon_changed`; `createBooking with transport and no pickup is failed-precondition pickup_required`; `a closed provider is still refused with not_accepting_orders`.
  - `errors.test.ts`: the five codes map as in the Contract.
  - `seed_fixtures.test.ts`: `An has three add-ons (makeup per_person, retouch per_item, transport per_booking only for seed-service-portrait) and Cúc one studio add-on; private/addons activeCount matches`.
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` → new tests fail.
- [ ] **Step 4: Implement** the adapters, callables (copy `callables/album.ts`'s `requireUid` + `handleCallableError` shape), exports, error rows, booking mapping (write `addons` as an array of plain maps only when non-empty; `pickup` like `place`; readers default `[]`), `liveBookingDeps().addons`. Seed (ids are seed strings, accepted by `isId`): An `seed-addon-makeup` (makeup, "Trang điểm", "Trang điểm tự nhiên, làm tóc cơ bản", 800.000, per_person, max 4, all packages), `seed-addon-retouch` (retouch, "Chỉnh thêm ảnh", "Hậu kỳ thêm ngoài số ảnh của gói", 20.000, per_item, max 10), `seed-addon-car` (transport, "Xe đón trong nội thành", "Đón đi và đưa về, xe 4 chỗ", 300.000, per_booking, `serviceIds: ['seed-service-portrait']`); Cúc `seed-addon-outfit` (outfit, "Thuê áo dài", 250.000, per_item, max 4); `private/addons` docs with the counts. README: one table row per add-on and the line "Đặt An · Chân dung 2 giờ để thử khối Thêm dịch vụ (S04.01) và điểm đón (S04.06)".
- [ ] **Step 5: Rules.** Add the `match /addons/{addonId}` block of the Contract inside `match /photographers/{uid}`. Rules tests (written, not run): `a signed-in customer reads an active add-on`; `a customer cannot read another provider's inactive add-on`; `the owner reads their inactive add-on`; `a customer list query filtered by active == true succeeds; unfiltered fails`; `the owner cannot create, update or delete an add-on directly`; `nobody writes private/addons from a client; the owner reads it`; `a third user cannot read a booking that has a pickup` (existing booking rule, new fixture).
- [ ] **Step 6:** `npm test && npm run build` (functions) and `cd packages/domain && npm test` green. Ledger: rules tests and integration tests written, not run.
- [ ] **Step 7: Commit** `feat(functions): saveAddon, deleteAddon and server-priced add-ons on createBooking [#190]`.

### Task 4: App data, icons and `QtyStepper`

**Files:**
- Create: `app_flutter/lib/data/addons/service_addon.dart`, `lib/data/addons/addon_repository.dart`, `lib/data/addons/firestore_addon_repository.dart`, `lib/data/addons/addon_providers.dart`, `lib/core/widgets/qty_stepper.dart`, `lib/features/addons/addon_format.dart`, `test/support/fake_addon_repository.dart`; tests `test/data/addons/service_addon_test.dart`, `test/data/addons/firestore_addon_repository_test.dart`, `test/data/addons/addon_errors_test.dart`, `test/core/widgets/qty_stepper_test.dart`, `test/features/addons/addon_format_test.dart`.
- Modify: `lib/data/booking/booking.dart` (+ regenerate `booking.freezed.dart`, `booking.g.dart` with `dart run build_runner build --delete-conflicting-outputs`), `lib/data/booking/booking_repository.dart`, `lib/data/booking/firestore_booking_repository.dart`, `lib/core/theme/app_icons.dart`, `lib/core/core.dart` (export `qty_stepper.dart`), `lib/features/events/register_sheet.dart` (use `QtyStepper(keyPrefix: 'register', …)`, delete `_Stepper`), `lib/l10n/app_vi.arb` (kinds, units, nouns, `addonPriceOnce`, `addonPricePer`, `addonOnce`) + `flutter gen-l10n`, `test/support/fake_booking_repository.dart` (records `addons`, `pickup`, `expectedTotal`; can throw a given code), `test/data/booking/` mapping test, `docs/superpowers/specs/components/shared-components.md` (section "QtyStepper · Mới" under §2; Icons table rows `AppIcons.car` `directions_car`, `AppIcons.checkroom` `checkroom`, `AppIcons.addCircle` `add_circle`, all "có trong mock"), `docs/design/ui-components.html` (regenerated: `python3 scripts/tools/build_ui_components.py` from the repo root).

**Interfaces:**
- Consumes: callables of Task 3; `functionsRegion`.
- Produces: Contract → App (data, `QtyStepper`, `AppIcons`, `addon_format.dart`).

- [ ] **Step 1:** Contract check of `Booking`, `bookingFromFirestore`, `BookingRepository.createBooking`, `FakeBookingRepository`, the Icons table format of `shared-components.md`; ledger differences.
- [ ] **Step 2: Failing tests.**
  - `service_addon_test.dart`: `serviceAddonFromFirestore maps every field and providerId from the argument`; `unknown kind or unit → null`; `appliesTo: empty serviceIds applies to all`; `validateAddonInput mirrors the server limits` (name 1/61 → nameLength; price 9.999/50.000.001 → priceRange; maxQty 0/11 → maxQtyRange for per_person; per_booking ignores maxQty; "0903 123 456" in name → contact (a local phone/link/zalo regex is enough here; the server is the authority)); `Chọn gói with no package → packagesEmpty`.
  - `firestore_addon_repository_test.dart` (`fake_cloud_firestore`, fake callable): `activeFor returns only active add-ons ordered by kind then id`; `watchMine returns inactive ones too`; `save sends the callable payload with snake-case codes and returns addonId`; `delete sends {addonId}`.
  - `addon_errors_test.dart`: `details {code: contact_leak, field: description} → contactLeak/description`; `details {code: invalid_argument, field: name.contact} → contactLeak/name`; `addon_limit → addonLimit`; `unavailable → network`.
  - booking mapping test: `bookingFromFirestore reads addons and pickup`; `missing addons → []`; `totalVnd = price + Σ amount`; `remaining falls back to totalVnd − deposit, not price − deposit`.
  - booking repository test: `createBooking sends addons [{addonId, qty}], pickup and expectedTotal only when given`; `bookingErrorOf maps addon_changed, addon_not_applicable, pickup_required`.
  - `qty_stepper_test.dart`: `minus disabled at min, plus disabled at max`; `taps call onChanged with value ∓ 1`; `keys use keyPrefix (register-minus, register-quantity, register-plus)`; `value is announced through valueLabel`. Existing S11.03 register sheet tests stay green unchanged.
  - `addon_format_test.dart`: `addonKindIcon maps the five kinds (transport → AppIcons.car, outfit → checkroom, other → addCircle)`; `addonPriceLabel: "800.000₫ / người", "20.000₫ / ảnh", "250.000₫ / bộ", "300.000₫ · một lần"`; `addonLineLabel: "Trang điểm · 2 người", "Chỉnh thêm ảnh · 10 ảnh", per_booking → name`; `addonsSummary: "+ Trang điểm ×2 · Xe đón trong nội thành"` (qty 1 shows no ×).
- [ ] **Step 3:** Run `flutter test --no-pub --timeout 60s test/data/addons`, then `test/core/widgets/qty_stepper_test.dart`, then `test/features/addons` → fail.
- [ ] **Step 4: Implement.** Firebase only in `firestore_addon_repository.dart` (`FirebaseFunctions.instanceFor(region: functionsRegion)`); `activeFor` = `collection('photographers').doc(uid).collection('addons').where('active', isEqualTo: true).get()` (Decision 10), sorted client-side by `AddonKind.index` then id. `addonErrorOf` reads `details.code`/`details.field` like `bookingErrorOf`. Add the l10n keys of this task, run `flutter gen-l10n`, regenerate freezed and the gallery.
- [ ] **Step 5:** Re-run the three test folders above plus `test/data/booking` and `test/features/events` (one command each); `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(app): add-on data layer, booking add-on fields, QtyStepper and three icons [#190]`.

### Task 5: S08.06 Dịch vụ đi kèm and S08.07 sheet

**Files:**
- Create: `app_flutter/lib/features/addons/addons_screen.dart`, `lib/features/addons/addons_controller.dart`, `lib/features/addons/addon_edit_sheet.dart`, `lib/features/addons/addon_edit_controller.dart`; tests `test/features/addons/addons_screen_test.dart`, `test/features/addons/addon_edit_sheet_test.dart`.
- Modify: `lib/app/router.dart` (`/me/addons`), `lib/features/settings/settings_screen.dart` (row `settings-addons`, Decision 14a), `lib/features/photographer_profile/photographer_profile_screen.dart` (owner entry `edit-addons`, Decision 14b), `lib/features/photographer_setup/setup_packages_screen.dart` (text button `setup-addons`, Decision 14c), `lib/l10n/app_vi.arb` (S08.06, S08.07 and entry-point keys) + `flutter gen-l10n`; tests in `test/features/settings/`, `test/features/photographer_profile/`, `test/features/photographer_setup/` (one case each).

**Interfaces:**
- Consumes: `myAddonsProvider`, `addonRepositoryProvider`, `AddonInput`, `validateAddonInput`, `addonErrorOf`, `myPackagesProvider` (package names for "Áp dụng" and "Chọn gói"), `addon_format.dart`, `ConfirmSheet`, `AppBottomSheet`, `SegmentedTabs`, `AppChip`, `EmptyState`, `ErrorState`, `AsyncView`.
- Produces: `AddonsScreen()` (ScreenCode S08.06), `Future<void> showAddonEditSheet(BuildContext context, {ServiceAddon? addon})` (ScreenCode S08.07), `AddonsController` (`toggle(ServiceAddon, bool)` → `saveAddon` with the full record, Decision 9; on `addonLimit` the switch returns off and a SnackBar shows `addonsLimitReached`).

**Backend wiring:** reads `photographers/{uid}/addons` (listener, owner rule) and the owner's packages; writes only through `saveAddon`/`deleteAddon` (Task 3); no direct Firestore write.

**Mock parity:** `#S08.06` — app bar "Dịch vụ đi kèm" with back; first line "{n}/10 dịch vụ đang bật" (`addonsActiveCount`); groups in kind order with a section label per kind present (Trang điểm, Chỉnh ảnh, Đưa đón, Trang phục, Khác); each row in a `GlassCard`: round icon cell (`addonKindIcon`), name, price + unit ("800.000₫ / người", "300.000₫ · một lần"), "Áp dụng: mọi gói" or the package names (ellipsis), trailing `Switch` (semantics `addonsToggle`); tap row → S08.07 edit; sticky footer primary "Thêm dịch vụ" → S08.07 empty; empty state title/body from the spec; skeleton rows while loading. `#S08.07` — sheet title "Thêm dịch vụ đi kèm" / "Sửa dịch vụ đi kèm" + close; "Loại" single-choice chips (horizontal scroll, five kinds); "Tên dịch vụ"; "Mô tả · không bắt buộc"; "Cách tính" `SegmentedTabs` (Một lần · Theo người · Theo số lượng); row price field ("Giá / người (₫)", "Giá / ảnh (₫)", "Giá (₫)" for một lần) + "Tối đa" (hidden for Một lần, value "{n} {unit}"); "Áp dụng cho" chips Mọi gói / Chọn gói (Chọn gói opens a checklist of the provider's packages); info note `addonResponsibility` (icon `info`); primary "Lưu"; edit mode adds red text "Xoá dịch vụ" → `ConfirmSheet` with red "Xoá" and body "Booking đã đặt vẫn giữ dịch vụ này."; errors under the fields with the exact copy of the Contract.

- [ ] **Step 1:** Contract check of `SettingsScreen` after #148 (group and row keys), the owner menu entries, `SetupPackagesScreen` layout, `myPackagesProvider`; ledger where the settings row went (Decision 14).
- [ ] **Step 2: Failing tests** (`FakeAddonRepository`, bounded pumps):
  - `addons_screen_test.dart`: `shows "4/10 dịch vụ đang bật" and groups by kind in kind order`; `row shows price label and "Áp dụng: Chân dung 2 giờ, Cặp đôi nửa ngày"`; `switch off calls save with active false and the other fields unchanged`; `switching on the 11th returns the switch to off and shows the limit SnackBar`; `tap row opens S08.07 in edit mode`; `"Thêm dịch vụ" opens S08.07 empty`; `empty state title and body`; `load error shows ErrorState with retry`; `320 dp width and text scale 1.3 have no overflow`; `renders in dark and light theme`; `exactly one AppButton.primary`.
  - `addon_edit_sheet_test.dart`: `Một lần hides Tối đa`; `Theo số lượng with kind Chỉnh ảnh labels the price "Giá / ảnh (₫)" and Tối đa "{n} ảnh"`; `invalid name shows "Tên 2–60 ký tự" and does not call save`; `price 5.000 shows "Giá từ 10.000₫ tới 50.000.000₫"`; `server contact_leak on description shows the contact message under Mô tả`; `server addon_limit shows the limit message`; `Chọn gói with nothing ticked shows "Chọn ít nhất một gói"`; `Lưu sends kind, name, description, price, unit, maxQty, serviceIds and closes with "Đã lưu dịch vụ"`; `edit mode shows "Xoá dịch vụ"; confirming calls delete and closes with "Đã xoá dịch vụ"`; `cancelling the confirm sheet deletes nothing`; `Lưu is disabled while saving (AppButton.loading)`.
  - settings: `a photographer sees "Dịch vụ đi kèm" and it opens /me/addons`; `a customer does not`. Profile owner menu: `edit-addons opens /me/addons`. Setup: `"Thêm dịch vụ đi kèm" shows once a package exists and opens /me/addons`.
- [ ] **Step 3:** `flutter test --no-pub --timeout 60s test/features/addons` → fail.
- [ ] **Step 4: Implement** the screens; add the l10n keys of this task; run `flutter gen-l10n`.
- [ ] **Step 5:** Run `test/features/addons`, `test/features/settings`, `test/features/photographer_profile`, `test/features/photographer_setup` (one command each); `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(addons): S08.06 add-on list and S08.07 add/edit sheet [#190]`.

### Task 6: S04.01 "Thêm dịch vụ", S04.06 pickup, S04.03 lines

**Files:**
- Create: `app_flutter/lib/features/booking/widgets/addon_pick_block.dart`; tests `test/features/booking/addon_pick_block_test.dart`, `test/features/booking/booking_flow_addons_test.dart`.
- Modify: `lib/features/booking/booking_flow_state.dart`, `lib/features/booking/booking_flow_controller.dart`, `lib/features/booking/steps/service_step.dart`, `lib/features/booking/steps/place_step.dart`, `lib/features/booking/steps/review_step.dart`, `lib/features/booking/booking_sheet_page.dart` (`_handleError`, dropped-add-on bar), `lib/l10n/app_vi.arb` (S04.01, S04.06, S04.03 keys) + `flutter gen-l10n`; tests `test/features/booking/service_step_test.dart`, `place_step_test.dart`, `review_step_test.dart`, `booking_flow_controller_test.dart`, `submit_test.dart`, `booking_flow_e2e_test.dart`; `test/support/booking_world.dart` (add-on fixtures).

**Interfaces:**
- Consumes: `activeAddonsProvider`, `ServiceAddon`, `AddonPick`, `QtyStepper`, `addon_format.dart`, `BookingRepository.createBooking(addons:, pickup:, expectedTotal:)`, `BookingErrorCode.addonChanged|addonNotApplicable|pickupRequired`.
- Produces: `BookingFlowState` adds `List<ServiceAddon> addons` (all active add-ons of the provider), `Map<String, int> picks` (addonId → qty > 0), `String pickupName`, `List<String> droppedAddonNames` (consumed once by the sheet), getters `applicableAddons`, `addonsVnd`, `totalVnd`, `needsPickup`, `transportAddon`; `payVnd` = `depositFor(totalVnd)`; `canContinue` for `place` also needs `pickupName ≥ 3` when `needsPickup`. Controller adds `setAddonQty(String addonId, int qty)`, `toggleAddon(String addonId)`, `setPickup(String name)`, `applyAddons(List<ServiceAddon>)`, `consumeDropped()`.

**Backend wiring:** S04.01 add-on list from `activeAddonsProvider(photographerId)` (one `get`, Decision 10); submit through `createBooking` with `addons`, `pickup`, `expectedPrice` (package) and `expectedTotal`; `addon_changed`/`addon_not_applicable` → back to S04.01, `ref.invalidate(activeAddonsProvider(photographerId))`, bar `bookAddonsChanged`; `pickup_required` → back to the place step with the field error.

**Mock parity:** `#S04.01-addons` — under the package tiles: header row "Thêm dịch vụ" + "Không bắt buộc"; rows: round icon cell, bold name, one-line description (ellipsis), price label; `per_booking` → trailing checkbox (semantics label = name); others → `QtyStepper` 0…`maxQty` (labels "Bớt một người" / "Thêm một người"); block hidden when no add-on applies; the only primary button "Tiếp tục · {package + add-ons}". `#S04.06` — "Địa điểm chụp" field + suggestion chips as today; with transport: header row "Điểm đón" + the transport add-on's name in meta, field "Điểm đón" (same suggestions), lock note `bookPickupPrivate` (icon `lock`); "Tiếp tục · {tổng}" disabled until the pickup has ≥ 3 characters; no map (Decision 13); step wrapped in the S04.06 `ScreenCode`. `#S04.03-addons` — summary card adds "Điểm đón: {name}" when present; `MoneyBreakdown`: "Gói {package}" then one line per add-on (`addonLineLabel`) then strong "Thanh toán 100%" = total; policy text unchanged; primary "Thanh toán {total}".

- [ ] **Step 1:** Contract check of the flow files (they may have changed since #129); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `addon_pick_block_test.dart`: `per_booking row toggles with the checkbox`; `stepper goes 0 → maxQty and stops; minus disabled at 0`; `block is absent when no add-on applies`; `rows are grouped in kind order`; `320 dp and text scale 1.3 without overflow`; `dark and light theme`.
  - `booking_flow_addons_test.dart` (controller, `ProviderContainer`):
    - `total = package + Σ unitPrice × qty and the continue label shows it`.
    - `switching package keeps applicable picks, drops the others and reports their names once` (`droppedAddonNames` = ["Xe đón trong nội thành"], then `consumeDropped` → []).
    - `dropping the transport pick clears pickupName`.
    - `applyAddons removes picks whose add-on disappeared and clamps qty to the new maxQty`.
    - `entering with a preselected package that has add-ons opens on S04.01` and `without add-ons opens on S04.02` (Decision 11); `the entry decision is not retaken after the user acted` (user picks a day, add-ons then load → stays on S04.02).
    - `changing picks after a draft clears bookingId and the next submit creates a new draft with the new picks` (fake repo records two createBooking calls; the second has the new picks).
    - `place step cannot continue without a pickup when transport is picked`; `can continue without pickup when no transport`.
    - `submit sends addons with qty > 0 only, pickup only with transport, expectedPrice = package and expectedTotal = total`.
    - `addon_changed returns to S04.01, invalidates the add-on list and shows bookAddonsChanged`; `pickup_required returns to the place step`.
  - `service_step_test.dart`: `the dropped bar text is "Đã bỏ Xe đón trong nội thành vì không áp dụng cho gói này"`; `one AppButton.primary`.
  - `place_step_test.dart`: `pickup field and lock note show only with transport`; `pickup shorter than 3 characters shows bookPlaceTooShort`; `the step reports screen code S04.06`.
  - `review_step_test.dart`: `money lines: Gói Chân dung 2 giờ 1.500.000₫, Trang điểm · 2 người 1.600.000₫, Xe đón trong nội thành 300.000₫, Thanh toán 100% 3.400.000₫`; `summary card shows "Điểm đón: Ga Sài Gòn, Quận 3"`; `pay button "Thanh toán 3.400.000₫"`; `without add-ons the lines are as before`.
  - `booking_flow_e2e_test.dart`: one happy path with makeup ×2 + transport through S04.01 → S04.02 → S04.06 → S04.03 → `GoToPayment` with the fake repo.
- [ ] **Step 3:** `flutter test --no-pub --timeout 60s test/features/booking` → new tests fail.
- [ ] **Step 4: Implement.** Hard part, the add-on state when the package or the list changes:
  ```dart
  // BookingFlowController
  ({Map<String, int> picks, List<String> dropped}) _fit(Map<String, int> picks, List<ServiceAddon> addons, String? serviceId) {
    final kept = <String, int>{};
    final dropped = <String>[];
    for (final MapEntry(key: id, value: qty) in picks.entries) {
      final a = addons.where((x) => x.id == id).firstOrNull;
      if (a == null) continue;                                   // gone: removed silently, server would say addon_changed
      if (serviceId == null || !a.appliesTo(serviceId)) { dropped.add(a.name); continue; }
      kept[id] = a.unit == AddonUnit.perBooking ? 1 : qty.clamp(1, a.maxQty);
    }
    return (picks: kept, dropped: dropped);
  }

  void selectService(ServiceSummary s) {
    final fit = _fit(state.picks, state.addons, s.id);
    _userActed = true;
    state = state.copyWith(
      serviceId: s.id, priceVnd: s.priceVnd, durationMinutes: s.durationMinutes, serviceName: s.name,
      clearStart: state.durationMinutes != null && state.durationMinutes != s.durationMinutes,
      priceChanged: false, picks: fit.picks, droppedAddonNames: fit.dropped,
      pickupName: _hasTransport(fit.picks) ? state.pickupName : '',
      clearBookingId: true,                                      // Decision 12
    );
  }

  void applyAddons(List<ServiceAddon> list) {
    final fit = _fit(state.picks, list, state.serviceId);
    var step = state.step;
    if (!_entryResolved && state.serviceId != null) {           // Decision 11, once
      _entryResolved = true;
      final has = list.any((a) => a.appliesTo(state.serviceId!));
      if (!_userActed && has && args.serviceId != null && step == BookingStep.datetime) step = BookingStep.service;
    }
    final changed = !mapEquals(fit.picks, state.picks);
    state = state.copyWith(addons: list, picks: fit.picks, step: step,
        clearBookingId: changed ? true : null);
  }
  ```
  `build()` listens to `activeAddonsProvider(args.photographerId)` like it listens to `profilePackagesProvider` and calls `applyAddons`; every user-facing mutator (`selectService`, `setAddonQty`, `toggleAddon`, `selectDay`, `selectStart`, `setPlace`, `setPickup`) sets `_userActed = true`; `setAddonQty`, `toggleAddon`, `setPickup` clear `bookingId`. `copyWith` gains `clearBookingId` handling for `null` (keep). The sheet listens to `droppedAddonNames` and shows the bar (`bookAddonDropped`, names joined with ", ") then calls `consumeDropped()`. Add the l10n keys of this task; run `flutter gen-l10n`.
- [ ] **Step 5:** `flutter test --no-pub --timeout 60s test/features/booking` green; `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(booking): S04.01 add-on block, S04.06 pickup and S04.03 add-on lines [#190]`.

### Task 7: After booking — S05.02 block, S06.01 summary, total everywhere

**Files:**
- Create: `app_flutter/lib/features/booking/widgets/booking_addons_block.dart`; test `test/features/booking/booking_addons_block_test.dart`.
- Modify: `lib/features/booking/booking_detail_screen.dart` (block under the booking card), `lib/features/work/work_screen.dart` (`_RequestCard`: total + summary line), `lib/features/booking/booking_view_rules.dart` (month sum uses `totalVnd`, Decision 19), any other `serviceSnapshot.price` used as booking money in `lib/features` (`grep -rn "serviceSnapshot.price" lib/features`; package-name displays stay), `lib/l10n/app_vi.arb` (S05.02, S06.01 keys) + `flutter gen-l10n`; tests `test/features/booking/booking_detail_screen_test.dart`, `cancel_sheet_test.dart`, `booking_view_rules_test.dart`, `test/features/work/` (the work screen test); `packages/domain/test/booking_notifications.test.ts` (pickup never in notices); if #151 has merged: its S27.07 offer sheet file and test (Decision 18).

**Interfaces:**
- Consumes: `Booking.addons`, `Booking.pickup`, `Booking.totalVnd`, `addon_format.dart`, `addonKindIcon`.
- Produces: `BookingAddonsBlock({required Booking booking})` (renders nothing when `addons` is empty and `pickup` is null).

**Backend wiring:** reads only the existing booking listener (`bookingProvider`, two-party rule); no new read or write.

**Mock parity:** `#S05.02-addons` — section title "Dịch vụ đi kèm" under the booking card; one `GlassCard` with rows: round icon cell, bold name, meta "{qty} {unit} × {unitPrice}" (or "Một lần" for `per_booking`), trailing amount; then "Điểm đón" row (icon `AppIcons.place`, meta = pickup name) only when `pickup` exists; same block for the customer and the photographer/studio side; the paid toast and timeline amounts already read `deposit` (= total). S06.01 request card: amount = total, extra meta line `addonsSummary` ("+ Trang điểm ×2 · Xe đón trong nội thành"), ellipsis on one line.

- [ ] **Step 1:** Contract check of `BookingDetailScreen` (where the card ends), `_RequestCard`, `CancelSheet`, `workDashboard`; check whether #151 has merged; ledger.
- [ ] **Step 2: Failing tests.**
  - `booking_addons_block_test.dart`: `rows show "2 người × 800.000₫" and 1.600.000₫`; `per_booking shows "Một lần"`; `pickup row only when pickup exists`; `nothing rendered for a booking without add-ons`; `320 dp, text scale 1.3, dark and light`.
  - `booking_detail_screen_test.dart`: `the photographer sees the same block and the pickup`; `the paid toast shows "Đã thanh toán 3.400.000₫…"`.
  - `cancel_sheet_test.dart`: `S05.03 shows the refund of the total` (50% at 24–48 h → 1.700.000₫).
  - work screen test: `request card shows the total 3,4M and "+ Trang điểm ×2 · Xe đón trong nội thành"`; `no summary line without add-ons`.
  - `booking_view_rules_test.dart`: `the month sum counts the total of completed bookings with add-ons`.
  - domain `booking_notifications.test.ts`: `notification content for a booking with pickup contains no pickup text` (render `booking_request` and `booking_accepted` with `renderNotification`; assert the pickup name is absent).
  - if #151 merged: `S27.07 shows add-on names and no add-on price or pickup`.
- [ ] **Step 3:** Run the affected folders (one command each) → new tests fail.
- [ ] **Step 4: Implement**; if #151 has not merged, comment on #151 (Decision 18) with `gh issue comment 151 -R thanhngochoang/booking` and ledger it.
- [ ] **Step 5:** `flutter test --no-pub --timeout 60s test/features/booking`, then `test/features/work`; `(cd packages/domain && npm test)`; `flutter analyze` clean.
- [ ] **Step 6: Commit** `feat(booking): S05.02 add-on block, S06.01 summary line and totals on add-on bookings [#190]`.

### Task 8: Ledger, spec status, issue

**Files:**
- Create: `docs/superpowers/handover/ledger-booking-addons.md`.
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (status/"Làm bởi" cells of S04.01-addons, S04.06, S04.03-addons, S05.02-addons, S08.06, S08.07: link the PR of #190, per the "Issue status = links" rule; no prose status), `docs/superpowers/specs/2026-10-08-booking-addons-design.md` header "Trạng thái" → "đang làm (#190)" with the PR link.

- [ ] **Step 1: Ledger** (English prose, Vietnamese copy verbatim): Step 1 findings of every task (the real names of #199's builder and slots, #139's filter and field or that this plan created them, #148's settings slot); Decisions 1–20 as taken; the copy not in the mock (`settingsAddons`, `settingsAddonsBody`, `profileEditAddons`, `setupAddAddons`, `addonErrorDescription`, `addonErrorMaxQty`, `addonErrorPackages`, `bookPickupRequired`); skipped suites (rules tests, Functions integration tests: written, not run); deploy order (Functions `saveAddon`/`deleteAddon` and the new `createBooking` before rules, rules before the app release; the dev project is on Spark, so emulators only); Decision 18 outcome; Deferred list below.
- [ ] **Step 2: Spec status.** Fill the §2 cells and the spec header; tick the issue checklist items of #190 that this PR closes (`gh issue edit` is done by `run-next-plan` at hand-in; here only the docs).
- [ ] **Step 3:** `git diff --stat` shows only docs in this task.
- [ ] **Step 4: Commit** `docs(addons): handover ledger and screen status for add-on services [#190]`.

## Deferred

- Phase 2 partner services with their own accounts, verification, reviews and split payouts (#191, spec §10).
- Adding or removing add-ons after payment (top-up payment, partial refund) — spec D5, Phase 2.
- Add-ons in quotes (S15–S16) and Chụp ngay (S13–S14) — spec D8.
- S03.01 read-only add-on list under the packages (spec §11 default "có") — needs a mock frame first.
- Map and point picker on S04.06 for the shoot place and the pickup (Decision 13; `MapPreview` is #140's, blocked by V1).
- Self-hosted parity: `services/api` routes and PostgreSQL migration for `service_addons`, `service_addon_services`, `booking_addons` (the data-model docs are updated in Tasks 1–2; code is phase 2, #90).
- Staff tooling for add-on disputes (S18 handles "dịch vụ không được làm" through the normal dispute flow; no add-on-specific reason code).
- Real payment intermediary, real payouts and invoices (fake rails only, owner ruling 2026-10-07).

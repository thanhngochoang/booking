# Handover ledger: booking add-ons (#190, S04/S08)

Unit: #190 (S04.01 / S04.03 / S04.06 / S05.02 / S06.01 add-on lines, S08.06 and S08.07 add-on management)
Branch: `plan/190-s04-s08-dich-vu-di-kem-khi-dat-lich` (from `origin/develop` 2e9017c), target `develop`
PR: https://github.com/thanhngochoang/booking/pull/232
Plan: `docs/superpowers/plans/2026-10-08-s04-s08-booking-addons.md`
Spec: `docs/superpowers/specs/2026-10-08-booking-addons-design.md`

## Scope delivered

- Domain (Task 1-2): add-on catalogue (`addon.ts`, `saveAddon`, `deleteAddon`, in-memory store), pricing (`priceAddonLines`, `bookingTotal`, `requirePickup`, `addonDraftFields`), `Booking.addons` / `Booking.pickup`, `expectedTotal` staleness check, five error codes (`addon_changed`, `addon_not_applicable`, `pickup_required`, `addon_limit`, `contact_leak`).
- Functions and rules (Task 3): Firestore adapters, `saveAddon` / `deleteAddon` callables, `createBooking` with add-ons, `details.field` in `toHttpsError`, seed data, `firestore.rules` add-on block.
- App data (Task 4): `lib/data/addons`, `Booking.addons/pickup/totalVnd`, `createBooking` params, `QtyStepper` moved to core, icons.
- S08.06 / S08.07 (Task 5), S04.01 / S04.06 / S04.03 (Task 6), S05.02 / S06.01 / work dashboard (Task 7).

## Step 1 findings (real names)

- #199 builder: `buildBookingDraft` in `packages/domain/src/create_booking.ts` existed on 2e9017c with four `// slot #190 (add-ons)` markers (import block; `BookingDraftInput.addons?` / `pickup?`; `draftTotal` body `bookingTotal(i.service, i.addons ?? [])`; `...addonDraftFields(i)`). This plan only filled the markers.
- #139: `findContactLeak` and `DomainError.field` were absent. This plan created them per #139 Decision 15 (`src/contact_filter.ts`, `test/contact_filter.test.ts` with the 16-row table, `DomainError(code, field?)`, exported from `index.ts`). #139 and #151 must consume them, not recreate. `toHttpsError` now adds `details.field` only when `DomainError.field` is set (Task 3).
- #148: S09 has no "Nhận việc" group and no "Gói dịch vụ" row. The settings entry `settings-addons` sits after `profile-provider-type` (Decision 14a), without a subtitle (a subtitle pushed the mode card out of the default test window). Other entries: `edit-addons` after `edit-packages` in the S03.01 owner menu, `setup-addons` on S08.01. If #148 later adds a "Nhận việc" group or a "Gói dịch vụ" row, move the row next to it.
- Money call sites (Task 2): the only reader of `booking.deposit` as an amount is `create_payment.ts` (two places); nothing reads `serviceSnapshot.price` as money, so Decision 2 holds and no other money site changed. Refund (S05.03) reads `deposit`, which equals the total; a refund test of 1.700.000₫ was added in Task 7.
- #152 `splitMilestones` was not merged: the test "milestones after shot sum to the total" is left for #152 to add. `milestoneAmounts` and `payoutLineOf` tests on the total are present.
- Task 3: transport codes `failed-precondition` for `addon_changed` / `addon_not_applicable` / `pickup_required`, `resource-exhausted` for `addon_limit`, `invalid-argument` for `contact_leak`. `photographers/{uid}/private/addons` (lock doc) needed no rules change (client writes already blocked except `contact`, owner read). Photographer "Cúc" has no seeded packages, so `seed-addon-outfit` has `serviceIds: []`.
- Task 6: screen code `S04.06` already existed for the place step; nothing added to `screen_codes.dart`. `copyWith(clearBookingId)` became `bool?`. Core `BookingSummary` had no slot for the pickup line, so `extraLine` was added (see Rulings).
- Task 7: remaining `serviceSnapshot.price` uses in `lib/features` are name displays only, none as money.

## Decisions 1-20 as taken

Taken as written in the plan (Global Constraints), with these outcomes:

1. Blockers: #199 builder present; #139 helpers created here (above). 2. Only the amount source changed (`draftTotal`). 3. Error codes per spec, `field` on form errors. 4. Order: `price_changed`, priced lines, then `addon_changed` on `expectedTotal` mismatch; qty above `maxQty` is `addon_changed`. 5. Lines in `ADDON_KINDS` order. 6. Booking fields written only when used. 7. Pickup without transport dropped; transport without pickup is `pickup_required`. 8. Lock doc `private/addons` makes the 10-active limit race-proof. 9. Edits send the full record. 10. Customer reads are one-shot (`activeAddonsProvider`); owner uses a listener (`myAddonsProvider`). 11. Preselected package opens S04.01 when an applicable add-on exists (see Deferred minors). 12. Any change to package, picks or pickup clears `bookingId`. 13. S04.06 has no map. 14. Entry points (a)(b)(c) done. 15. Studio add-ons live under the studio uid. 16. Unit nouns: person `người`, items `ảnh` / `bộ` / `lần`. 17. `QtyStepper` in core with `keyPrefix`. 18. See below. 19. S06.01 card amount and month sum use `Booking.totalVnd`; summary line `addonsSummary`. 20. No new notification type; test confirms no pickup text in notices.

Decision 18 outcome: #151 was not merged when Task 7 ran, so no S27.07 code was touched. The rule ("S27.07 shows add-on names from `booking.addons`, never prices or `pickup`") was posted on #151: https://github.com/thanhngochoang/booking/issues/151#issuecomment-6191159267

## Rulings (controller, for the owner; each costs a small change if wrong)

- Branch: use the claimed `plan/190-s04-s08-dich-vu-di-kem-khi-dat-lich` instead of the plan's `plan/190-booking-addons` (project.py names claim branches, the push is the lock; the branch name is cosmetic).
- Needs-the-owner items 1-3 take the plan's defaults (Decisions 11, 13, 14); the owner approved the spec and the defaults are recorded there.
- S08.06: rows of one kind share one `GlassCard` with dividers, as in mock `#S08.06` (overrides the brief's "each row in a GlassCard"). Mock is the layout authority. Cost: a visual tweak if card-per-row is preferred.
- S08.07: "Tối đa" is a numeric field with the unit noun next to the price, as in mock `#S08.07`, not a minus/plus stepper. Keeps `addonErrMaxQty` reachable. Cost: a small UI swap if a stepper is preferred.
- S04.02 "Tiếp tục · {tổng}" shows the total; mock S04.01 and S04.06 show it, and the label is the same without add-ons. Cost: a label revert.
- `expectedTotal` is sent only when add-ons are picked: the domain treats it as optional, `expectedPrice` already guards the package, and the no-add-on payload stays byte-identical (Decision 6 spirit). Cost: one field if the owner wants it always.
- `pickup_required` while the app sees no transport pick is handled as `addon_changed` (back to S04.01, list reloaded); only reachable with a stale list (Decision 10). Cost: a different error bar.
- New core `BookingSummary.extraLine` (nullable, additive, documented in `shared-components.md`) for the S04.03 "Điểm đón" line; `BookingCard` had no slot.
- S05.02: the pickup shows as meta "Điểm đón: {name}" under the transport row, as in mock `#S05.02-addons` (overrides the brief's separate row); a standalone row only when a pickup exists without a transport line. Cost: a layout revert.

## Copy not in the mock (Vietnamese verbatim) and the real l10n keys

Brief names that differ from what was implemented are marked.

- `settingsAddons` = "Dịch vụ đi kèm"
- `settingsAddonsBody`: not created (settings row has no subtitle).
- `profileEditAddons` = "Dịch vụ đi kèm"
- `setupAddAddon` (brief: `setupAddAddons`) = "Thêm dịch vụ đi kèm"
- `addonErrDescription` (brief: `addonErrorDescription`) = "Mô tả tối đa 200 ký tự"
- `addonErrMaxQty` (brief: `addonErrorMaxQty`) = "Tối đa từ 1 tới 10"
- `addonErrPackages` (brief: `addonErrorPackages`) = "Chọn ít nhất một gói"
- `bookPickupRequired` = "Nhập điểm đón cho xe đưa đón"
- Other keys added without a mock string: `bookAddonDropped` = "Đã bỏ {names} vì không áp dụng cho gói này"; `bookAddonsChanged` = "Dịch vụ đi kèm vừa thay đổi, kiểm tra lại trước khi thanh toán"; `bookPickupHint` = "Tên điểm đón (tối thiểu 3 ký tự)"; `bookPickupPrivate` = "Chỉ thợ chụp cho bạn thấy điểm đón."; `addonsLimitReached`, `addonsSaveFailed`, `addonsLoadError`.
- Reuse: `bookPickupLine` ("Điểm đón: {name}") serves S04.03 and S05.02, so no `addonPickupMeta` key. `addonLineQty` (read through `addonLineLabel`) serves S04.03, so no `bookAddonLineQty` key. `addonBlockMeta` ("{qty} {noun} × {price}") was added for S05.02.

## Skipped suites

Written, not run (the sandbox cannot run the emulators; CI does): Firestore rules tests (add-on block) and Functions integration tests (`saveAddon`, `deleteAddon`, `createBooking` with add-ons). Everything else was run: domain 1129 pass plus lint, Functions unit 410 pass plus build, Flutter folder-by-folder suites and `flutter analyze` clean. TDD RED output was not captured for Tasks 2, 4, 6 and 7 (tests written with or after the code; reviewers checked the tests fail without the code).

## Deploy order

1. Cloud Functions: `saveAddon`, `deleteAddon` and the updated `createBooking`.
2. Firestore rules (add-on block).
3. App release.

The dev project `booking-c1922` is on the Spark plan and `BLAZE_ENABLED` is off, so Functions do not deploy there; the app and dashboard run on the emulators (`../scripts/backend-local.sh`, seed accounts in `app_flutter/firebase/functions/seed/README.md`, add-on seed `SEED_ADDONS`). Nothing in this unit adds a deploy step outside the Blaze switch.

## Deferred minors (from task reviews)

- Task 1: `cleanText` collapses newlines in the description (`addon.ts:62`); `serviceIds` aliases the input array (`addon.ts:126`); relational schema lacks a check `per_booking` implies `max_qty = 1`; `deleteAddon` with a non-object raw input (field `addonId`) is untested (`addon_use_cases.ts:47`).
- Task 2: no `validateCreateBookingDraftInput` table for add-on / pickup / `expectedTotal` parse errors; duplicated `addonDraftFields` test (the brief lists it twice); the relational-schema replacement check is weak (the total is enforced in the use case).
- Task 3: `addonFromFirestore` drops malformed docs, so they do not count toward the 10 limit (`addon_firestore.ts:52`); `FirestoreAddonCatalog` returns inactive add-ons, filtered in the domain (tested).
- Task 4: client contact regex is broad (any "@", "facebook"); it is a hint only, the server is authoritative. Untested: pickup with a `{lat,lng}` map point in the callable result, and a `createBooking` payload without pickup coordinates.
- Task 5: settings add-ons row has no subtitle; `settings_mode_test.dart` uses a local `_tall` viewport helper; S08.06 row padding not pixel-matched to the mock's `0 10px`.
- Task 6: Decision 11 entry flags survive a `build()` re-run (contact or today providers), so the sheet can jump S04.01 to S04.02 without user action (`booking_flow_controller.dart:142-148`, `:203`); marked "fix in final wave", check the final-wave result. No test that a package change clears `bookingId` (the test with that name checks pickup only); the `pickup_required`-without-transport branch is untested (`:473`); `back()` / `next()` do not set `_userActed`; duplicate kind sort in `addon_pick_block`; an empty description renders an empty `Text`.
- Task 6 concern: if `build()` re-runs, existing choices including picks reset (pre-existing behaviour).

## Deferred (not in this unit)

- Phase 2 partner services with their own accounts, verification, reviews and split payouts (#191, spec §10).
- Adding or removing add-ons after payment (top-up payment, partial refund): spec D5, Phase 2.
- Add-ons in quotes (S15-S16) and Chụp ngay (S13-S14): spec D8.
- S03.01 read-only add-on list under the packages (spec §11 default "có"): needs a mock frame first.
- Map and point picker on S04.06 for the shoot place and the pickup (Decision 13; `MapPreview` is #140's, blocked by V1).
- Self-hosted parity: `services/api` routes and PostgreSQL migration for `service_addons`, `service_addon_services`, `booking_addons` (data-model docs updated in Tasks 1-2; code is phase 2, #90).
- Staff tooling for add-on disputes (S18 handles "dịch vụ không được làm" through the normal dispute flow; no add-on-specific reason code).
- Real payment intermediary, real payouts and invoices (fake rails only, owner ruling 2026-10-07).

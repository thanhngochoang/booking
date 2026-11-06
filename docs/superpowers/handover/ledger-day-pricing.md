# Ledger: S08 day pricing (#316)

Plan: `docs/superpowers/plans/2026-11-04-s08-day-pricing.md`. Spec: `docs/superpowers/specs/2026-11-04-day-pricing-design.md`.

The unit ran on two repositories, with the same branch name `plan/316-day-pricing` in each:

- **booking-be** [PR #4](https://github.com/thanhngochoang/booking-be/pull/4), merged first. It covers Tasks 1–5: the domain rule, `createBooking` priced by its day, price stats, the Functions adapters, rules, the `holidays` CLI and the seed.
- **booking**: this PR. It covers Tasks 6–10: app data, S08.08–S08.10, the S08.01 step 2 editor, and the customer side.

The plan was written before #299 moved the backend. Its `packages/domain/…` and `app_flutter/firebase/…` paths now live in booking-be (`packages/domain`, `firebase/`).

## What exists now

- **Package doc** `photographers/{uid}/services/{id}`:
  - `price` (required): the Monday price.
  - `dayPrices` (optional): `{mon..sun}`, exactly 7 keys. It is left out when all 7 days are equal.
  - `specialPrice` (optional).
  - `priceMode`: `two_levels` | `per_day`.
  - `order` (optional): 0–999. Only `reorder` writes it.
  - Every price is an int from 1 to 1,000,000,000.
- **Special days** `photographers/{uid}/special_days/{id}`:
  - Fields: `{name 2–40, from, to (yyyy-MM-dd), createdAt, updatedAt}`.
  - A range is at most 60 days, counting both ends.
  - `to` is at most 365 days ahead. The rules allow 366 days, to absorb UTC+7.
  - A provider has at most 20 ranges. The app enforces this; the rules do not.
- **Holidays** `holidays/{yyyy}`:
  - Shape: `{days: [{day, name}], updatedAt}`.
  - Server-only; set it with `npm run holidays -- set|list <year>` in booking-be `firebase/functions`.
  - A missing doc means no holidays.
- **Server fields** on `photographers/{uid}`: `weekendFrom` (int|null) and `hasSpecialPrices` (bool). The discovery trigger keeps them up to date. Clients cannot write them.
- **One rule, two ports.** `priceForDay` is in booking-be `packages/domain/src/day_pricing.ts`; the Dart port is in `app_flutter/lib/data/pricing/day_pricing.dart`.
  - Both run the same case table. The app's copy is `app_flutter/test/data/contracts/day_pricing_cases.json`, a copy of booking-be `packages/domain/test/fixtures/day_pricing_cases.json`. Copy it again whenever the rule changes.

## Rulings

**Backend (booking-be #4)**
- `FirestoreSpecialDayReader` uses plain reads. `createBooking` reads special days before its transaction, as it already does for the service catalog.
- The domain index exports `weekdayOf` as `weekdayKeyOf`, because `entry_tickets` already exports a `weekdayOf`.
- `startingPrice` is the lowest of the 7 day prices. `weekendFrom` is set only when the cheapest weekend day costs more than that.
- The 2027 holiday dates in the seed are sample values. The 2026 dates follow the mock.

**App data and S08.08–S08.10**
- The case table is a snapshot inside the app, as with `openapi.yaml`. The app imports no backend code.
- An edit clears `dayPrices`, `specialPrice` and `priceMode` before it writes the new values, so no stale price survives.
- `ServicePackageRepository.setActive` was added because S08.08 must be able to switch a package back on.
- S08.08 meta line: it reuses the shared package meta ("40 ảnh"). The mock says "40 ảnh chỉnh".
- S08.08 package tiles: plain muted surfaces, not `GlassCard`, inside the reorderable list.
- S08.08 dates: printed with `formatDay`, zero-padded ("26/04").
- S08.08 reorder: long-press drag on the handle. There is no "…" menu fallback yet, so a screen-reader user cannot reorder (see Deferred).
- S08.10 holiday lines: consecutive holidays with the same name show as one line. The count "{n} ngày lễ chung" counts days, not lines.
- S08.10 sheet:
  - The calendar can pick up to 2 years ahead, so the "within 365 days" error can appear.
  - A new range cannot start in the past.
  - With 20 ranges, the sheet opens with Save disabled.
- Turning off the last active package asks first, with a red "Tắt gói".

**S08.09 editor and S08.01 step 2**
- Setup packages were already real repository packages, so the editor saves through the repository in both entries. The setup draft store keeps only the form typed so far for a new package.
- "Ẩn gói" moved from the setup list into S08.09.
- When all 7 prices are equal, the editor saves no `dayPrices` and sets `priceMode = two_levels`.
- Turning the special switch off drops `specialPrice` on save.
- The preview note ("Khách đặt …") names the dearest of the next 7 days, as the mock caption says. The mock's example text names a different day than its own strip.
- "Xem" opens S08.10.
- The copy follows the mock: "Số ảnh chỉnh", "Tên 2–60 ký tự", "Giá phải lớn hơn 0", "Giá tối đa 1.000.000.000₫".
- A legacy duration that is not in `kPackageDurationsMinutes` shows no chip selected and must be picked again.

**Customer side (S03.01, S04.01–S04.03, cards)**
- `ServiceSummary` now carries `dayPrices` and `specialPrice`, and `startingPriceOf` uses the lowest weekday price (P6).
- `dayPrice` is computed from the package and the day.
- The flow never guesses a price. For a package with a `specialPrice`, "Tiếp tục" stays disabled until the holidays of that day's year have loaded. A failed load shows "Thử lại".
- After `price_changed`, the cached special days are read again.
- The special-day name comes from the holiday first, then from the provider's range.
- The "cuối tuần" tag and the S04.03 reason appear only when the package's prices vary by day.
- In S04.02, a day shows a short price when it differs from `price` (Monday's price).
- The "Ngày thường {giá}" line sits under the month header. The legend already fills the header row the mock uses.
- S03.01: a package priced by day opens the read-only price table when tapped. A single-price package still books straight away.
- `PhotographerCard` adds "· T7–CN từ {weekendFrom}" only when the card is at least 340dp wide and the text scale is normal. This is not in the mock; the spec wording places it in the meta line.

## Deferred

- The self-hosted API (booking-be `src/`) does not price by day yet. It does not run `createBooking` today.
- S28.06 web studio packages (#169) need the same price model, `dayPrices`, `specialPrice` and special days.
- S08.08 reorder has no menu fallback for screen readers.
- Nothing was checked on a device. The widget tests cover 320dp at 1.3× text in light and dark.

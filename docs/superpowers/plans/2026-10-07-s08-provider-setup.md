# S08 · Thiết lập hồ sơ nhiếp ảnh gia (mock parity, studio variant) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The four setup steps (S08.01 steps 1–2, S08.02/S08.03 skills, S08.04 evidence, S08.05 area & contact) match the mock, the mock shows what the spec added since it was drawn (avatar, equipment, city + radius, the "Chỉ nhận tin nhắn trong app" card, the privacy line) and gains the missing studio variant of S08.05 (address block), and the Cá nhân / Studio choice uses the mock's option tile (icon tile on the left, radio on the right). **Architecture:** UI and mock only. The backend already exists and runs on the real adapters: `setProviderType` and `setStudioAddress` callables (`CallableProviderRepository`), `photographers/{uid}` + `services` + `private/contact` writes (`FirestorePhotographerIntroRepository`, `FirestoreServicePackageRepository`, `FirestorePhotographerContactRepository`), skills through `FirestoreSkillsRepository` and the `onPhotographerWrite` trigger. One shared widget change: `AppOptionTile` gets an optional icon-tile variant. **Tech Stack:** Flutter, Riverpod 3, go_router, `flutter_test`; HTML mock. **Spec:** mock `docs/design/ui-mock.html` `#S08.01-type`, `#S08.01`, `#S08.02`, `#S08.03`, `#S08.04`, `#S08.05`; `docs/superpowers/specs/screens/photographer.md` (S08.01–S08.05); `docs/superpowers/specs/screens/portfolio-awards.md` ("S08.01 · bước 1: Hình thức"); `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §1–2 (types, studio address); main spec §2 and §3e.2; `docs/superpowers/handover/ledger-mock-parity-1.md` (Task 7 rulings on S08.05); audit 2026-10-06 (S08 "chưa xác minh"). **Issue:** #146

**Branch:** `plan/146-s08-provider-setup` from `origin/develop` (claimed with `scripts/project.py claim 146`), PR into `develop` titled `fix(setup): S08 setup steps match the mock, studio variant [#146]`.

**Execution wave:** 1 (cross-plan review 2026-10-07). **Blocked by:** none.

## Global Constraints

- CLAUDE.md "UI matches the mock": the mock is the authority for layout, section order, copy, component types and states; the spec for behaviour; when the spec is newer, update the mock and say so (each such case is listed in Decisions).
- One primary action per screen: "Tiếp tục" (steps 1–3), "Hoàn tất" (step 4), "Xong" (S08.04 sheet). "Quay lại" is `AppButton.outline` at 36% width in the footer; "Thêm gói này" is `AppButton.outline` small.
- Imports `package:photobooking/...`; features import `core/core.dart`; `AppOptionTile` changes live in `lib/core/widgets/app_option_tile.dart` and are exported by `core.dart` already.
- Tokens only: `AppColors`/`AppColorsDark` (`primarySubtle`, `glass`, `foregroundMuted`), `AppSpace`, `AppRadius` (`lg` = 12, `xl`, `card`), `colorScheme` (`primary`, `onPrimary`, `secondary` = the mock's `--field`, `outline`, `outlineVariant`); icons via `AppIcons` (`profile` = person, `work`).
- Strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; no hard-coded text.
- No server code: callables `setProviderType`/`setStudioAddress` (region `asia-southeast1`) are used as they are; ids/time/money per `docs/superpowers/specs/data-model/README.md` (package price integer VND > 0, duration in minutes from the fixed list) unchanged.
- Firebase isolation: no Firebase import outside `lib/data/**`, `main.dart`, `firebase_options.dart` (this plan adds none).
- Env for Flutter commands, from `app_flutter/`: `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: `flutter test --no-pub --timeout 60s <file or folder>` one folder at a time; bounded pumps; `flutter analyze` clean before each commit. No rules, functions or domain change, so no rules-test or Functions suite.
- Commits: Conventional Commits, subject ends with `[#146]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Decisions

Mock parity check done for this plan on 2026-10-07 (develop `812afd6`), app vs mock. Concrete differences and rulings:

| # | Screen | Mock | App | Ruling |
|---|---|---|---|---|
| D1 | S08.01 step 1 | bar title "Thiết lập hồ sơ" | "Hồ sơ nhiếp ảnh gia" (`setupFlowTitle`) | **Mock fixed**: its own steps 2 and 4 say "Hồ sơ nhiếp ảnh gia" (and the mock-parity-1 ruling chose it); one title for the whole flow. |
| D2 | S08.01 step 1 | starts with "Bạn nhận việc với tư cách" | starts with heading "Giới thiệu bản thân" + hint + avatar, then the type | **App fixed**: type section first; heading and hint removed (the bio field keeps its hint). |
| D3 | S08.01 step 1 | no avatar, no equipment | `AvatarEditor` and equipment chips (≤ 8) | **Mock fixed** (spec newer: avatar plan 2d2, equipment in `photographer.md` S08.01). Order: type → avatar → name → bio → equipment → note. |
| D4 | S08.01 step 1 | bio label "Giới thiệu" | "Giới thiệu ngắn" | **App fixed** (mock copy is newer than the `s24_bio` string). |
| D5 | S08.01 step 1 | `.opt` with a 40 dp rounded icon tile on the left (accent fill when selected) and the radio on the right | `AppOptionTile`: radio left, bare 18 dp icon | **App fixed**: `AppOptionTile.icon` variant (Contract); used by S08.01 and the Settings `ProviderTypeSheet` (same choice). Other `AppOptionTile` callers unchanged. |
| D6 | S08.01 step 2 | package card has a 52 dp thumbnail | no thumbnail | **Mock fixed**: packages have no cover in the data model (`ServicePackage` has none; `ServiceSummary.coverUrl` is never written). Package covers are Deferred. |
| D7 | S08.01 step 2 | no hide action on a package | eye-off button per package ("Ẩn gói …") | **Mock fixed** (spec: packages are hidden, never deleted). |
| D8 | S08.01 step 2 | field "Giao sau" with value "5 ngày" | label "Giao sau (ngày)" | **App fixed**: label "Giao sau", suffix "ngày". |
| D9 | S08.01 step 2 | meta "40 ảnh · 1 địa điểm · giao 3 ngày" | `packageMeta`: "2 giờ · 40 ảnh · giao 3 ngày" | **Mock fixed**: "địa điểm" is not a package field; the duration is. |
| D10 | S08.02–S08.04 | — | — | **Match** (title "Kỹ năng" + "3 / 4", completeness card, "Thể loại chụp" "n / 6", levels with "Chuyên sâu tối đa 3", evidence row + "Chỉnh", S08.03 sections with a count only on "Phong cách", years field, evidence sheet "Minh chứng · {name}" + "n / 3" + 3-column grid + "Xong"). No change; Task 3 adds no test for them. |
| D11 | S08.05 | one "Khu vực phục vụ" field | city field + radius chips 5/10/20/30/50/100 km | **Mock fixed** (spec newer; mock-parity-1 C5 kept the app and left the mock; owner ruling 2026-10-07 "mock is the authority" means the mock must now show it). |
| D12 | S08.05 | three channel cards | four: + "Chỉ nhận tin nhắn trong app" | **Mock fixed** (spec S08.05 "Trạng thái"; mock-parity-1 C8). |
| D13 | S08.05 | no privacy line | "Số của bạn không hiện công khai. Khách chỉ dùng được các kênh này sau khi đã đặt lịch." | **Mock fixed** (mock-parity-1 C11). |
| D14 | S08.05 studio | no frame | address block "Địa chỉ cơ sở" (4 fields + note) above the area | **New mock frame `#S08.05-studio`** (brief rule 4); app unchanged, pinned by tests. |
| D15 | S08.05 | Zalo/WhatsApp icons are `chat_bubble` | brand glyphs (`assets/social/zalo.svg`, `whatsapp.svg`) | **Mock caption** notes the brand glyphs; no app change. |

Other rulings:

1. **"`setStudioAddress` has no screen" (issue text) is stale.** S08.05 already shows the address block for a studio and calls `setStudioAddress` before `completeContactSetup` (`SetupContactController.save`), and Settings → "Hình thức nhận việc" → Studio opens `/setup/4?from=settings`. What is missing is (a) the mock frame (D14) and (b) a way for an existing studio to edit its address later. (b) is a row in S09.02, which plan `2026-10-07-s09-profile-settings.md` (#148) rebuilds; that plan adds the row "Địa chỉ studio" → `/setup/4?from=settings`. This plan does not touch `settings_screen.dart`, so the two can run in parallel.
2. **The studio address stays required on the server** (finishing refuses without it, `SetupContactController` comment); no change.
3. **`AppOptionTile.icon` variant draws the radio on the right** only when `icon` is given; with `leading`/no icon the tile is unchanged (radio left), so `reason_picker`, `find_sheets`, `area_picker_sheet`, `album_picker_sheet`, `create_post_screen`, `place_field`, `setup_packages_screen` (duration sheet) render exactly as before.

## Needs the owner

None (D6 package covers are a product feature, listed under Deferred, not a question for this unit).

## Contract

- **`AppOptionTile`** (`lib/core/widgets/app_option_tile.dart`) gains:
  ```dart
  /// Mock `.opt .oi` (S08.01-type): a 40dp rounded tile on the left holding
  /// this icon — field colour, or primary with an onPrimary icon when
  /// selected — and the radio moves to the right end. Mutually exclusive
  /// with [leading].
  final IconData? icon;
  ```
  Constructor `this.icon` with `assert(icon == null || leading == null)`. Tile: `Container(key: const ValueKey('option-icon-tile'), width: 40, height: 40, decoration: BoxDecoration(color: selected ? scheme.primary : scheme.secondary, borderRadius: BorderRadius.circular(AppRadius.lg)), child: Center(child: AppIcon(icon!, size: 20, color: selected ? scheme.onPrimary : scheme.onSurface)))` (`AppRadius.lg` = 12, the mock's `.oi` `border-radius:12px`). Semantics unchanged (radio semantics on the whole tile).
- **S08.01 step 1** (`lib/features/photographer_setup/setup_intro_screen.dart`): body order: `setupTypeHeading` section with two `AppOptionTile(icon: AppIcons.profile | AppIcons.work, label, description, keys type-individual/type-studio)` → `_notEligible` error → `AvatarEditor` → name `TextField` (`Key('setup-name')`, label `displayNameLabel` / `setupStudioName`) → bio (`Key('setup-bio')`, label `setupBioLabel`) → equipment block → info note `setupTypeNote` → footer primary `setup-next`. Keys `setupIntroHeading`, `setupIntroHint` removed from the screen (delete from the arb if `grep -rn "setupIntroHeading\|setupIntroHint" lib` finds no other use).
- **ProviderTypeSheet** (`lib/features/settings/provider_type_sheet.dart`): same two tiles with `icon:` instead of `leading:`.
- **S08.01 step 2** (`lib/features/photographer_setup/setup_packages_screen.dart`): the delivery field `Key('package-delivery')` gets `labelText: l.packageDeliveryLabel` ("Giao sau") and `suffixText: l.packageDeliverySuffix` ("ngày").
- **l10n** (`lib/l10n/app_vi.arb`): change `setupBioLabel` "Giới thiệu ngắn" → "Giới thiệu"; change `packageDeliveryLabel` "Giao sau (ngày)" → "Giao sau"; add `packageDeliverySuffix` = "ngày". (Grep both changed keys for other screens first; if another screen uses them, add new keys `setupBioLabelShort`/`packageDeliveryField` instead and ledger it.)
- **Mock edits** (`docs/design/ui-mock.html`):
  - `#S08.01-type`: `.bar .t` text → "Hồ sơ nhiếp ảnh gia"; after the `.optc` block insert `<div style="display:flex;flex-direction:column;align-items:center;gap:6px"><span class="av l"></span><div class="btn out sm"><span class="ms" style="font-size:16px">photo_library</span>Đổi ảnh đại diện</div></div>`; the bio field's `<small>` stays "Giới thiệu"; after it insert `<div class="meta x">Thiết bị (không bắt buộc)</div><div class="chips wrap"><span class="chip">Sony A7 IV ✕</span><span class="chip">35mm f/1.4 ✕</span></div><div class="row" style="gap:8px"><div class="field grow"><small>Thiết bị</small><span class="meta">Ví dụ: Sony A7 IV</span></div><div class="ic" style="background:var(--field)" aria-label="Thêm thiết bị"><span class="ms">add</span></div></div>`. Caption `<span>` appends: ` Ảnh đại diện và thiết bị (tối đa 8) có từ kế hoạch 2d; thứ tự: hình thức → ảnh → tên → giới thiệu → thiết bị.`
  - `#S08.01`: package card → `<div class="card"><div class="t"><b>Chân dung 2 giờ</b><span class="meta">2 giờ · 40 ảnh · giao 3 ngày</span></div><b class="tn" style="font-size:12px">1,5M</b><div class="ic" aria-label="Ẩn gói Chân dung 2 giờ"><span class="ms">visibility_off</span></div></div>`. Caption appends: ` Gói không xoá mà ẩn (nút mắt gạch). Gói chưa có ảnh bìa.`
  - `#S08.05`: replace `<div class="field"><small>Khu vực phục vụ</small>TP.HCM · bán kính 15 km</div>` with `<div class="sec"><b style="font-size:14px">Khu vực phục vụ</b></div><div class="field"><small>Thành phố</small>TP.HCM</div><div class="meta x">Bán kính phục vụ</div><div class="chips wrap"><span class="chip">5 km</span><span class="chip">10 km</span><span class="chip on">20 km</span><span class="chip">30 km</span><span class="chip">50 km</span><span class="chip">100 km</span></div>`; after the WhatsApp card add `<div class="card"><div class="ic" style="background:var(--field)"><span class="ms">chat_bubble</span></div><div class="t"><b>Chỉ nhận tin nhắn trong app</b><span class="meta">Khách chỉ nhắn được trong ứng dụng. Bạn có thể bật gọi, Zalo hay WhatsApp sau.</span></div>` + the off-switch markup used by the WhatsApp card + `</div>`, then `<div class="meta x">Số của bạn không hiện công khai. Khách chỉ dùng được các kênh này sau khi đã đặt lịch.</div>`. Caption `<span>` becomes: `Cần ít nhất một kênh bật, hoặc bật "Chỉ nhận tin nhắn trong app" (bật nó thì tắt ba kênh kia). Zalo và WhatsApp dùng biểu tượng thương hiệu. Bước này thay cho phần "Khu vực" ở S08.01. Studio: xem S08.05-studio.`
  - New frame after `#S08.05`: `<div class="step" id="S08.05-studio"><div class="phone" data-code="S08.05">` … same status bar, `.bar` (back, "Hồ sơ nhiếp ảnh gia", "4 / 4"), `.prog` 4/4, `<div class="h3">Khu vực và liên hệ</div>`, `<div class="sec"><b style="font-size:14px">Địa chỉ cơ sở</b></div>`, fields `<small>Số nhà, đường</small>12 Nguyễn Đình Chiểu`, `<small>Phường / xã</small>Đa Kao`, row `<small>Quận / huyện</small>Quận 1` + `<small>Tỉnh / thành phố</small>TP.HCM`, `<div class="meta x">Khách chỉ thấy tới quận; địa chỉ đầy đủ hiện sau khi đã đặt.</div>`, then `<div class="sec"><b style="font-size:14px">Khu vực phục vụ</b></div>` + city field "TP.HCM" + the radius chips (20 km on) + phone field "0938 000 001", footer "Quay lại" (out, 36%) + "Hoàn tất" (pri). Caption: `<div class="cap"><span class="n new">Mới</span><span class="n">S08.05 · bản Studio</span><b>Địa chỉ cơ sở đứng trước khu vực</b><span>Chỉ hiện khi hình thức là Studio (S08.01 hoặc Cài đặt → Hình thức nhận việc). Bắt buộc: số nhà/đường (5–120 ký tự), quận/huyện, tỉnh/thành (2–60); phường tuỳ chọn. Công khai chỉ quận và thành phố; địa chỉ đầy đủ nằm ở tài liệu riêng và hiện cho khách sau khi đặt. Lưu địa chỉ trước (<code>setStudioAddress</code>), rồi mới hoàn tất; thiếu địa chỉ thì server từ chối. Phần kênh liên hệ giống S08.05.</span></div>`.
- No data model, callable, rules, index or route change. Routes used (exist): `/setup`, `/setup/1`, `/setup/2`, `/setup/3`, `/setup/4` (`?from=settings`), `/profile/skills`, `/profile/skills/evidence`.

## Review Focus

1. An artist (NAG) switching to Studio on step 1 must still get the confirmation sheet ("lose the tier") after the reorder: the type section moved, the `_next` logic must not. Pinned in Task 2 (existing `an artist switching to Studio is asked first…` must stay green; add `the confirm still shows after the reorder` if the existing test finds widgets by position).
2. `AppOptionTile` regressions in the other eight callers (radio side, row height, semantics). Pinned in Task 2 (`without icon the radio stays on the left`, existing `app_option_tile_test.dart`).
3. Step 1 at 320 dp × 1.3 text with the avatar moved below the options: the footer button still reachable and nothing overflows, for both Cá nhân and Studio. Pinned in Task 2 (existing `fits 320dp at 1.3x text (${b.name})` loop).
4. A studio finishing S08.05 without an address is refused locally (errors under the four fields) and never calls `completeContactSetup`. Pinned in Task 3 (existing `studio needs an address to finish`; extend it to assert the order "Địa chỉ cơ sở" above "Khu vực phục vụ").
5. Dark/light: the selected icon tile uses `primary`/`onPrimary` (violet is the 10%: only the selected tile), the unselected one `secondary`. Pinned in Task 2 (both brightness).

## Chi phí Google

- Firestore reads/writes per action: unchanged (step 1 still reads `users/{uid}` once and `photographers/{uid}` intro once with `get`; saves are the existing writes; no listener added).
- **Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s. This plan adds no Functions work.
- Scheduled jobs, Storage paths, paid APIs: none added.
- Conclusion: **+$0/month at (b) 1,000 MAU and (c) 10,000 MAU.**

## Tasks

### Task 1: Mock frames and specs for S08

**Files:**
- Modify: `docs/design/ui-mock.html` (`#S08.01-type`, `#S08.01`, `#S08.05`, new `#S08.05-studio`), `docs/superpowers/specs/screens/photographer.md` (S08.01: "Bố cục bước 1" order type → avatar → name → bio (≤ 300) → equipment (≤ 8) → note; "Chuỗi": `setupBioLabel` "Giới thiệu", `packageDeliveryLabel` "Giao sau"; S08.05: add "Studio: khối Địa chỉ cơ sở đứng đầu (mock `#S08.05-studio`)"), `docs/superpowers/specs/screens/portfolio-awards.md` ("S08.01 · bước 1": the option tiles have an icon tile left and the radio right)

- [ ] **Step 1:** Apply the mock edits exactly as in Contract. Keep the existing classes (`.step`, `.phone`, `.cap`, `.opt`, `.ic`, `.chip`, `.field`, `.foot`, `.btn`); no new CSS.
- [ ] **Step 2:** Edit the two spec files as listed.
- [ ] **Step 3:** Check: every `id="S08…"` is unique (`grep -o 'id="S08[^"]*"' docs/design/ui-mock.html | sort | uniq -d` prints nothing); `flutter test --no-pub --timeout 60s test/core/screen_codes_test.dart` green (codes unchanged; variants are not in the table).
- [ ] **Step 4: Commit** `docs(mock): S08 frames show avatar, equipment, radius, in-app card; S08.05 studio variant [#146]`.

### Task 2: `AppOptionTile` icon variant and S08.01 step 1 order

**Files:**
- Modify: `app_flutter/lib/core/widgets/app_option_tile.dart`, `app_flutter/lib/features/photographer_setup/setup_intro_screen.dart`, `app_flutter/lib/features/settings/provider_type_sheet.dart`, `app_flutter/lib/l10n/app_vi.arb`
- Test: `app_flutter/test/core/widgets/app_option_tile_test.dart`, `app_flutter/test/features/photographer_setup/setup_intro_screen_test.dart`, `app_flutter/test/features/settings/provider_type_sheet_test.dart`

**Interfaces:**
- Produces: `AppOptionTile({…, IconData? icon})` (Contract).
- Consumes: `storedProviderTypeProvider`, `setupIntroControllerProvider`, `setupDraftStoreProvider`, `AvatarEditor`, `validateIntro` (unchanged).

**Mock parity:** `#S08.01-type` (after Task 1): bar "Hồ sơ nhiếp ảnh gia" · "1 / 4"; progress 1/4; section "Bạn nhận việc với tư cách"; tiles "Cá nhân" (person) / "Studio" (work) with descriptions, icon tile left, radio right; avatar + "Đổi ảnh đại diện"; "Tên hiển thị" (Studio: "Tên studio"); "Giới thiệu"; "Thiết bị (không bắt buộc)" chips + field + add; info note "Đổi Cá nhân ↔ Studio được trong Cài đặt khi không còn booking đang chạy."; footer primary "Tiếp tục" only.

**Backend wiring:** unchanged: "Tiếp tục" → `SetupIntroController.save` → `CallableProviderRepository.setType` (callable `setProviderType`, only when the choice changed) + `FirestorePhotographerIntroRepository` (`photographers/{uid}` name/bio/equipment) + `users/{uid}.displayName`; avatar → `AvatarController` (Storage `avatars/{uid}/…`, `users/{uid}.avatarUrl`).

- [ ] **Step 1: Failing tests.**
  - `app_option_tile_test.dart`: `with icon: a 40dp tile on the left and the radio on the right` (`getTopLeft(option-icon-tile).dx < getTopLeft(label).dx < getTopLeft(radio ring).dx`); `selected icon tile is primary with an onPrimary icon, unselected is secondary` (dark and light); `without icon the radio stays on the left` (regression); `icon and leading together assert`.
  - `setup_intro_screen_test.dart`: `the type choice comes first, before the avatar and the name` (vertical order of `Key('type-individual')`, `Key('change-avatar')`, `Key('setup-name')`, `Key('setup-bio')`, `Key('setup-equipment-field')`); `no "Giới thiệu bản thân" heading` (`find.text('Giới thiệu bản thân')` nothing); `the bio field is labelled "Giới thiệu"`; `type tiles use the icon variant` (`find.byKey(ValueKey('option-icon-tile'))` finds two).
  - `provider_type_sheet_test.dart`: `the sheet's tiles use the icon variant` (two icon tiles).
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/core/widgets/app_option_tile_test.dart`, then `… test/features/photographer_setup/`, then `… test/features/settings/` — the new tests fail.
- [ ] **Step 3: Implement.** `AppOptionTile`: when `icon != null`, the `Row` children are `[iconTile, SizedBox(width: AppSpace.s2h), Expanded(texts), SizedBox(width: AppSpace.s2), _Radio]`; else as today. Reorder `setup_intro_screen.dart` per Contract (move the `Semantics(header) setupTypeHeading` + `AsyncView` + `_notEligible` block to the top of the scroll column; then `AvatarEditor`; delete the heading/hint widgets). Switch both screens' tiles from `leading: AppIcon(…)` to `icon: AppIcons.profile` / `AppIcons.work`. arb: `setupBioLabel` → "Giới thiệu" (grep first, Contract note); delete unused `setupIntroHeading`/`setupIntroHint`; `flutter gen-l10n`.
- [ ] **Step 4: Run** the three test targets again, plus `flutter test --no-pub --timeout 60s test/features/find/` and `… test/features/create_post/` (other `AppOptionTile` users); `flutter analyze`. Green.
- [ ] **Step 5: Commit** `fix(setup): S08.01 step 1 order and option tiles as in the mock [#146]`.

### Task 3: S08.01 step 2 field label and S08.05 pins (individual and studio)

**Files:**
- Modify: `app_flutter/lib/features/photographer_setup/setup_packages_screen.dart`, `app_flutter/lib/l10n/app_vi.arb`
- Test: `app_flutter/test/features/photographer_setup/setup_packages_screen_test.dart`, `app_flutter/test/features/photographer_setup/contact_setup_screen_test.dart`

**Interfaces:**
- Produces: l10n `packageDeliverySuffix` "ngày"; `packageDeliveryLabel` value "Giao sau".
- Consumes: `myPackagesProvider`, `ServicePackageRepository` (Firestore adapter in production), `contactSetupPrefillProvider`, `setupContactControllerProvider`, `validateStudioAddress` (unchanged).

**Mock parity:**
- `#S08.01` (after Task 1): bar "Hồ sơ nhiếp ảnh gia" · "2 / 4"; h3 "Gói dịch vụ"; hint "Khách đặt theo gói. Cần ít nhất một gói để hồ sơ hiện trong Tìm thợ ảnh."; package cards (name, "2 giờ · 40 ảnh · giao 3 ngày", "1,5M", eye-off); form "Tên gói", row "Giá (₫)" + "Thời lượng", row "Số ảnh hậu kỳ" + "Giao sau" (suffix "ngày"); small outline "Thêm gói này"; footer "Quay lại" + "Tiếp tục".
- `#S08.05` / `#S08.05-studio` (after Task 1): h3 "Khu vực và liên hệ"; studio only: "Địa chỉ cơ sở" + "Số nhà, đường", "Phường / xã", "Quận / huyện", "Tỉnh / thành phố" + note; "Khu vực phục vụ" city + radius chips; "Số điện thoại · bắt buộc"; "Chọn kênh khách được dùng để liên hệ bạn."; four channel cards; privacy line; footer "Quay lại" + "Hoàn tất".

**Backend wiring:** packages → `FirestoreServicePackageRepository` (`photographers/{uid}/services`, hide = `active: false`); S08.05 → `CallableProviderRepository.setStudioAddress` (studio, first) then `FirestorePhotographerContactRepository.completeContactSetup` (batch: `serviceArea`, `contactChannels`, `private/contact`, `onboardingComplete`).

- [ ] **Step 1: Failing tests.**
  - `setup_packages_screen_test.dart`: `the delivery field reads "Giao sau" with the unit "ngày"` (`InputDecoration.labelText == 'Giao sau'`, `suffixText == 'ngày'`); `each package row has a hide button "Ẩn gói {name}"` (pins D7; may pass already).
  - `contact_setup_screen_test.dart` (group `studio`): `the address block comes before the service area` (`getTopLeft(find.text('Địa chỉ cơ sở')).dy < getTopLeft(find.text('Khu vực phục vụ')).dy`); `an individual has no address block` (exists as `an individual finishes without the address block`; add the `find.text('Địa chỉ cơ sở')` nothing assertion if missing); `the studio form fits 320dp at 1.3x with every channel open` (copy of the existing 320 test with a studio prefill).
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/features/photographer_setup/` — the delivery-label test fails; the S08.05 pins may already pass (they guard the new mock frame).
- [ ] **Step 3: Implement** the label/suffix and the arb change (grep `packageDeliveryLabel` first, Contract note); `flutter gen-l10n`.
- [ ] **Step 4: Run** the folder and `flutter analyze`; green.
- [ ] **Step 5: Commit** `fix(setup): S08.01 "Giao sau" field and S08.05 studio pins [#146]`.

### Task 4: Status table and ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 rows S08.01–S08.05
- Create: `docs/superpowers/handover/ledger-s08-provider-setup.md`

- [ ] **Step 1:** Status cells: S08.01 "✅ đã làm (2d1, a1) · khớp mock (#146)"; S08.02, S08.03, S08.04 "✅ đã làm (2c) · khớp mock (#146)"; S08.05 "✅ đã làm · khớp mock, có bản studio (#146)".
- [ ] **Step 2:** Ledger: the D1–D15 table (one line each, "cost if wrong"), rulings 1–3, the note for #148 ("S09.02 must add 'Địa chỉ studio' → `/setup/4?from=settings` for a studio"), "no rules/functions changed; no emulator suite skipped".
- [ ] **Step 3: Commit** `docs(spec): S08 status and ledger [#146]`.

## Deferred

- Editing the studio address after setup from Settings: the row "Địa chỉ studio" is built by #148 (S09.02 rebuild), which owns `settings_screen.dart`.
- Package cover images (mock thumbnail, D6): needs a `services.coverUrl` writer and an upload purpose; a later portfolio/package unit.
- Studio members ("Thêm thành viên: sắp có") and business verification of studios: #136 (S26) and #135 (S21.04).
- Map pin / coordinates for the studio address (`lat`/`lng` accepted by `setStudioAddress` but never sent): needs the location picker; no Maps SKU planned (cost spec §9).

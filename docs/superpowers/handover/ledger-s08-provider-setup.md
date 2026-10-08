# Handover ledger — plan S08 provider setup: mock parity of the four setup steps (issue #146)

Plan: `docs/superpowers/plans/2026-10-07-s08-provider-setup.md`, Tasks 1–4. Branch `plan/146-s08-thiet-lap-ho-so-nhiep-anh-gia`. Merge base 4a9767e; commits 6625990 (mock frames), 2750582 (step 1 order and option tiles), 1523bbc (S08.01 "Giao sau" and S08.05 studio pins), then the docs commit of Task 4.

## Built
- Mock (Task 1): `#S08.01-type`, `#S08.01` and `#S08.05` show what the spec added since they were drawn (avatar, equipment, delivery field, city + radius chips, the "Chỉ nhận tin nhắn trong app" card, the privacy line); new frame `#S08.05-studio` (address block "Địa chỉ cơ sở" above the area). `screens/photographer.md` and `screens/portfolio-awards.md` updated to match.
- App step 1 (Task 2): `AppOptionTile.icon` variant (40 dp rounded icon tile on the left, radio on the right; primary/onPrimary when selected, `secondary` otherwise), used by S08.01 and `ProviderTypeSheet`. Step 1 order: type → not-eligible error → avatar → name → bio → equipment → note. Heading and hint removed (`setupIntroHeading`, `setupIntroHint` deleted from the arb). `setupBioLabel` is now "Giới thiệu". `_next` and the artist confirm sheet are untouched.
- App step 2 and S08.05 (Task 3): delivery field "Giao sau" with suffix "ngày" (`packageDeliverySuffix`); tests pin the hide-package button, the studio address above the area, the studio at 320 dp × 1.3x text and an individual without the address block.
- Docs (Task 4): main spec §2 rows S08.01–S08.05 (status "khớp mock (#146)"; S08.05 "có bản studio").
- No rules, index, callable, trigger, data-model or route change; no emulator suite was skipped (none applies: nothing in `firebase/`, `packages/domain` or `services/` changed).

## Decisions of the plan
Mock parity check on 2026-10-07 (develop 812afd6), app vs mock. "Cost if wrong" is what it costs to undo the ruling.

| # | Screen | Ruling | Cost if wrong |
|---|---|---|---|
| D1 | S08.01 step 1 | Mock fixed: title "Hồ sơ nhiếp ảnh gia" (its own steps 2 and 4 say so; one title for the whole flow). | One mock string and one test; app already used `setupFlowTitle`. |
| D2 | S08.01 step 1 | App fixed: the type section comes first; the heading "Giới thiệu bản thân" and its hint are removed. | Re-add two arb keys and two widgets, update the order test. |
| D3 | S08.01 step 1 | Mock fixed: avatar and equipment (≤ 8) added to the frame (spec newer: avatar plan 2d2, equipment in `photographer.md`). Order: type → avatar → name → bio → equipment → note. | Remove the mock block; the app and its tests keep the fields. |
| D4 | S08.01 step 1 | App fixed: bio label "Giới thiệu" (the mock copy is newer than the old "Giới thiệu ngắn"). | One arb value and one test. |
| D5 | S08.01 step 1 | App fixed: option tile with a 40 dp rounded icon tile on the left and the radio on the right (`AppOptionTile.icon`, used by S08.01 and `ProviderTypeSheet`; other callers unchanged). | Drop the `icon` parameter and go back to `leading:` in two callers; nothing else depends on it. |
| D6 | S08.01 step 2 | Mock fixed: no 52 dp thumbnail on a package card (the data model has no package cover; `ServiceSummary.coverUrl` is never written). | Package covers become a feature (writer, upload purpose); see Deferred. |
| D7 | S08.01 step 2 | Mock fixed: the eye-off "Ẩn gói …" button is drawn (packages are hidden, never deleted). | One mock line. |
| D8 | S08.01 step 2 | App fixed: field label "Giao sau" with suffix "ngày". | One arb key and one test. |
| D9 | S08.01 step 2 | Mock fixed: package meta "2 giờ · 40 ảnh · giao 3 ngày" ("địa điểm" is not a package field; the duration is). | One mock string. |
| D10 | S08.02–S08.04 | Match; no change and no new test. | None; a later mock edit would reopen the check. |
| D11 | S08.05 | Mock fixed: city field + radius chips 5/10/20/30/50/100 km (spec newer; owner ruling 2026-10-07 "the mock is the authority" means the mock now shows what the app already does). | Revert the mock block; the app stays. |
| D12 | S08.05 | Mock fixed: fourth card "Chỉ nhận tin nhắn trong app". | One mock block. |
| D13 | S08.05 | Mock fixed: the privacy line "Số của bạn không hiện công khai. Khách chỉ dùng được các kênh này sau khi đã đặt lịch." | One mock line. |
| D14 | S08.05 studio | New mock frame `#S08.05-studio` (address block above the area); app unchanged and pinned by tests. | Delete the frame; screen code `S08.05` is shared, so no renumbering. |
| D15 | S08.05 | Mock caption notes the brand glyphs for Zalo and WhatsApp (`assets/social/zalo.svg`, `whatsapp.svg`); no app change. | One mock sentence. |

## Rulings
1. **"`setStudioAddress` has no screen" (issue text) is stale.** S08.05 already shows the address block for a studio and calls `setStudioAddress` before `completeContactSetup` (`SetupContactController.save`); Settings → "Hình thức nhận việc" → Studio opens `/setup/4?from=settings`. What was missing: the mock frame (D14) and a way for an existing studio to edit its address later (a row in S09.02, owned by #148; see the note below). This plan does not touch `settings_screen.dart`, so it and #148 can run in parallel.
2. **The studio address stays required on the server** (finishing refuses without it; comment in `SetupContactController`); no change.
3. **`AppOptionTile.icon` draws the radio on the right only when `icon` is given.** With `leading` or no icon the tile is unchanged (radio left), so `reason_picker`, `find_sheets`, `area_picker_sheet`, `album_picker_sheet`, `create_post_screen`, `place_field` and `setup_packages_screen` (duration sheet) render as before.

## Note for #148 (S09.02 rebuild)
S09.02 must add the row **"Địa chỉ studio" → `/setup/4?from=settings`** for a studio. #148 owns `settings_screen.dart`; until it lands, an existing studio can change the address only by re-running Settings → "Hình thức nhận việc" → Studio.

## Needs the owner
None. Package covers (D6) are a product feature under Deferred, not a question for this unit.

## Review notes
From the SDD progress ledger (`.superpowers/sdd/2026-10-07-s08-provider-setup/progress-plan-146-s08-thiet-lap-ho-so-nhiep-anh-gia.md`):
- Pre-flight scan: no cross-task findings (T1 mock frames → T2/T3 parity; the `AppOptionTile` icon variant of T2 is not used by T3).
- Task 1 (4a9767e..6625990): review approved.
- Task 2 (6625990..2750582): review approved.
- Task 2: minor (deferred): raw 40/20 sizes in AppOptionTile icon tile; no direct narrow-width test for icon variant; radioRing finder tied to 18dp; long doc comment; order test misses info note/heading
- Task 3 (2750582..1523bbc): review approved.
- Final check (Task 2 run): `flutter analyze --no-pub` clean; full `flutter test --no-pub` 3294 passed, 42 skipped. No rules, functions or domain change, so no rules-test or Functions suite; none skipped.

## Not run
- No emulator walkthrough, device build or iOS step (outside this plan's scope; UI and mock only).

## Deferred
- Editing the studio address after setup from Settings: the row "Địa chỉ studio" is built by #148 (S09.02 rebuild), which owns `settings_screen.dart`.
- Package cover images (mock thumbnail, D6): needs a `services.coverUrl` writer and an upload purpose; a later portfolio/package unit.
- Studio members ("Thêm thành viên: sắp có") and business verification of studios: #136 (S26) and #135 (S21.04).
- Map pin / coordinates for the studio address (`lat`/`lng` accepted by `setStudioAddress` but never sent): needs the location picker; no Maps SKU planned (cost spec §9).
- Minors from Task 2 review (verbatim above): raw 40/20 sizes in the `AppOptionTile` icon tile (move to tokens); no direct narrow-width test for the icon variant; the `radioRing` finder is tied to 18 dp; long doc comment; the order test misses the info note and the heading.

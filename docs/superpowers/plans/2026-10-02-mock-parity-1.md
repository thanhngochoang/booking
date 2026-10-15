# Mock parity 1: make the built screens match the UI mock

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The screens and shared widgets built so far (tab bar, S13, S35, S36, S33, S34, S42, S31, S30, core widgets) look and read like the committed mock `docs/design/ui-mock.html` (published artifact LptNpoqnt5KjQ5tUaPjYDM). User requirement, 2026-10-02: "giao diện phải giống artifact đã commit".

**Spec:** the mock itself is the authority for layout, order, copy, component type and states; `docs/superpowers/specs/2026-10-01-remaining-screens.md` and `specs/screens/*.md` stay the authority for behaviour. The audit `docs/superpowers/handover/mock-parity-audit.md` lists every deviation with mock/app/file:line (row ids such as E3, C1, N4 below refer to it). Where the spec is newer than the mock (Task 11), the mock is updated instead of the app.

**User rulings (2026-10-02):**
- PhotographerCard shows a small gradient "Đặt …" button (`AppButton.primary`, small size) on every card, as in the mock. "One primary action per screen" means the screen's main CTA; per-item card actions styled primary in the mock are allowed. Record this in CLAUDE.md and `specs/components/shared-components.md`.
- `PhoneField` is two boxes, as in the mock: a fixed "Mã" box showing `+84` (not editable, 72dp) and the "Số điện thoại" box. Behaviour (normalisation, validation, international mode) is unchanged.

**Controller rulings:** S35 date toggles ("Tuần này", "Cuối tuần", "Không thu phí") use the context chip style, the radius chip the filter style (mock N4). `AppChip` drops the automatic check icon (mock); the selected state stays exposed through semantics and the fill/border change.

## Global Constraints

- Everything in the earlier plans' constraints still holds: package imports, tokens only (`AppColors`/`AppSpace`/`AppRadius`/`AppText`), strings in `app_vi.arb` + `flutter gen-l10n`, 48dp hit areas, 320dp × 1.3 text scale in light and dark, no deprecated API, blur budget (≤4 `BackdropFilter`, none in list items), battery (no new tickers/listeners), `dart format`, `flutter analyze` clean, full `flutter test` green with no warnings.
- For every task: open the mock section for each screen code you touch and match it; list any remaining difference in the report with a reason.
- Do not change behaviour, routes or data flow except where a task says so. Existing tests that assert old visuals are updated to the mock; tests that assert behaviour must keep passing unchanged.
- Commits use Conventional Commits with the environment's Co-Authored-By trailer.

---

### Task 1: `AppButton` sizes
Files: `lib/core/widgets/app_button.dart`, `test/core/widgets/app_button_test.dart`.
- [ ] Add `size: AppButtonSize.regular | small | xsmall` to every constructor: regular = current (`controlHeight`), small = 38dp, xsmall = 30dp with intrinsic width (not stretched). Visual height follows the size; the hit area stays ≥ 48dp (`MaterialTapTargetSize.padded` or an outer `ConstrainedBox`). Loading keeps the label semantics.
- [ ] Tests: each size's visual height, 48dp hit area via `tester.getSize` of the tappable region / `tapAt` on the margin, xsmall not stretched in a wide parent, 320dp × 1.3.

### Task 2: Tab bar states
Files: `lib/core/theme/app_theme.dart` (`navigationBarTheme`), `lib/features/shell/tab_shell.dart`, tests in `test/features/shell/`. Audit T1–T3.
- [ ] Selected icon and label in the primary/accent colour, unselected in the tertiary grey (from tokens), top hairline as in the mock; the middle action as in the mock if it differs.
- [ ] Tests: selected/unselected icon colours from the theme in light and dark.

### Task 3: Chips, tags, stat tiles, PhotoPill
Files: `lib/core/widgets/app_chip.dart`, `free_tag.dart`, `stat_tile.dart`, `photo_card.dart` (PhotoPill), callers in `photographer_card.dart`, `lib/features/explore/explore_screen.dart` (S35 chip kinds), tests. Audit N4, N7, StatTile, PhotoPill.
- [ ] `AppChip`: no automatic check icon; unselected text secondary weight 500; selected state still in semantics.
- [ ] S35: radius chips `filter`, "Tuần này"/"Cuối tuần"/"Không thu phí" `context`.
- [ ] `FreeTag`: pill radius, 10px, letter-spacing per mock.
- [ ] `StatTile`: left-aligned, value pinned to the bottom, radius 16.
- [ ] `PhotoPill`: white 94% pill with dark text and an availability-dot colour parameter (ok / warn); fix the doc comment; check contrast on a light photo in a test (text colour vs pill).
- [ ] Update tests that asserted the old visuals.

### Task 4: PhotographerCard buttons and avatar
Files: `lib/core/widgets/photographer_card.dart`, tests. Audit PhotographerCard rows; user ruling.
- [ ] "Hồ sơ" = `AppButton.outline(size: small)`, "Đặt …" = `AppButton.primary(size: small)` (gradient), both 38dp visual, ≥48dp hit area. Avatar 40dp (`AppAvatarSize` closest to mock; add a 40dp size if missing).
- [ ] Tests: button kinds and sizes; card still has one outer button node plus two button nodes.

### Task 5: `PhoneField` two boxes
Files: `lib/core/widgets/phone_field.dart`, callers S33/S34/S42, tests. Audit P2; user ruling.
- [ ] A fixed "Mã" box (label "Mã", value "+84", read-only, excluded from focus traversal, 72dp) followed by the "Số điện thoại" field with no prefix icon. International mode keeps working (the code box shows the dial code or is hidden in international mode — follow the existing `international` behaviour and say which).
- [ ] Tests: both boxes render, typing and validation unchanged, 320dp × 1.3 no overflow.

### Task 6: S33 as a bottom sheet
Files: `lib/features/contact/add_phone_screen.dart`, the callers that push `/profile/phone`, `lib/app/router.dart`, tests. Audit P1, P4.
- [ ] Callers open S33 with `showAppSheet` over the current screen; the route `/profile/phone?returnTo=` stays as a deep-link fallback that renders the same content. Save behaviour and `returnTo` unchanged; closing without saving returns without a number (the booking flow stays blocked, per spec).
- [ ] Privacy line matches the mock (icon or not, per mock).
- [ ] Tests: opening from the booking gate shows the sheet; save closes and continues; dismiss leaves no number; deep link still works.

### Task 7: S34 layout
Files: `lib/features/photographer_setup/contact_setup_screen.dart`, `lib/core/widgets/step_progress.dart` (or a new `StepScaffold` in `lib/core/widgets/step_scaffold.dart` if it keeps the code smaller), `app_vi.arb`, tests. Audit C1–C4, C6, C7, C9.
- [ ] App bar title "Hồ sơ nhiếp ảnh gia", "4 / 4" at the right, progress bar under the bar; body heading "Khu vực và liên hệ".
- [ ] Sticky footer with "Quay lại" (36%) + "Hoàn tất"; no outer `GlassCard` around the channel cards; `AppChip(kind: context)` instead of `ChoiceChip`.
- [ ] Channel hint copy as in the mock.
- [ ] Tests updated; behaviour tests unchanged.

### Task 8: S42 and S31
Files: `lib/features/settings/edit_profile_screen.dart`, `settings_screen.dart`, `app_vi.arb`, tests. Audit R2–R4, G1, G2.
- [ ] S42: hint "Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc." (new key), sticky "Lưu" footer, fields on the page without a `GlassCard`.
- [ ] S31: small-caps tertiary group labels, dividers between rows; preview button `small`.

### Task 9: S13 and S35 layout
Files: `lib/features/explore/explore_screen.dart`, `lib/core/widgets/location_prompt_card.dart`, `lib/features/explore/widgets/event_tile.dart`, tests. Audit E3, E4, E6, E7, E10, N2, N6.
- [ ] Category tiles: 2-column grid of short 21:9 tiles on phones (4 from 600dp), only the first 4 on S13 with the rest reachable (follow the mock: if the mock shows exactly 4, show 4 and keep the others behind the tab's full list — say how). Text-tile visuals stay (accepted ruling) but size/aspect/grid match. "N gói" line deferred to the taxonomy plan (accepted).
- [ ] `LocationPromptCard`: compact `xsmall` buttons inside the text column, title 13px bold body, 36dp icon circle.
- [ ] Section headers per mock (serif 17, accent "Xem tất cả" link style).
- [ ] Event tile quick wins: day number in accent, type as a tag pill, price + seats in a right column.
- [ ] Tests: the location card and events section are reachable without scrolling past more than one screen at 390×844; existing behaviour tests unchanged.

### Task 10: S36 options and S30
Files: `lib/features/explore/area_picker_sheet.dart`, `lib/features/shell/placeholder_tabs.dart`, tests. Audit A1, A2, A4, H1–H3.
- [ ] S36: bordered option cards (new shared `AppOptionTile` in `lib/core/widgets/app_option_tile.dart`: border, radius 16, glass fill without BackdropFilter, selected = accent border + accent-soft fill + filled radio, radio semantics). "Mở Cài đặt để bật vị trí" below the list, above the primary button, `outline` `small`.
- [ ] S30: "Chuyển qua chế độ …" `AppButton.primary(size: small)`, `AppAvatar` large, h3 card title.

### Task 11: Low-priority polish and mock updates
Files as listed in audit group 11 and `docs/design/ui-mock.html`. Audit group 11 and 12.
- [ ] App-bar title sizes/centring for sub-screens, S35 pin colour, ContactDial radius 16/14 with the visible "Gọi" label, PhotoCard small-card radius 16, AppAvatar default 40dp in cards, lock icons (match the mock).
- [ ] Mock updates where the spec is newer (no app change): S34 city + radius chips (C5), the in-app-only fourth card and privacy line (C8, C11), S35 radius chips 10/25/50 (N3), S36 "Dùng vị trí của tôi" row and search (A3); captions recording the two user rulings. Bump the mock header version comment. The controller republishes the artifact.

### Task 12: Battery and performance check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-02-mock-parity-1.md"). Nothing to do here.

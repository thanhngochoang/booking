# Mock parity audit: built Flutter screens vs `docs/design/ui-mock.html`

Date: 2026-10-02 · Branch `flutter-rewrite` · Read-only audit (no files changed).

Sources: mock `docs/design/ui-mock.html` (S13 l.605–626, S30 l.908, S31 l.927–947, S42 l.968–981, S32 l.988, S33 l.1000–1016, S34 l.1018–1033, S35 l.1040–1053, S36 l.1055–1071, CSS l.87–254, component rules l.1441–1461). Specs `docs/superpowers/specs/screens/{discovery,booking,account,photographer}.md`. App paths below are relative to `app_flutter/lib/`.

Severity: **High** = wrong structure, wrong component or wrong copy. **Medium** = clearly visible layout or style difference. **Low** = polish. **Accepted** = covered by a ruling or by the spec (the spec is newer than the mock). **Mock stale** = the spec changed it and the mock should be updated, not the app.

---

## Tab shell / bottom navigation (`features/shell/tab_shell.dart`, `app/tabs.dart`, `core/theme/app_theme.dart`)

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| T1 | Selected tab: icon and label in `--accent` (primary), weight 600. Unselected: `--ink-3` (tertiary grey), weight 500 (`.tab`, `.tab.on`, l.88–90) | `navigationBarTheme` sets only label weight. No `iconTheme`, and the label colour is always `foreground`. M3 defaults then resolve selected and unselected icons to near-identical foreground colours, so the active tab is only visible from a font-weight change | `core/theme/app_theme.dart:173-187` | **High** (state not visible) |
| T2 | Bar has a 1px top hairline (`border-top:1px solid var(--line)`, l.87) | No top border on `NavigationBar` | `features/shell/tab_shell.dart:25-55` | Low |
| T3 | Middle tab: 36dp gradient disc lifted 3dp (`translateY(-3px)`), purple glow `0 6px 16px rgba(138,63,252,.45)`; when active its label is `--ink`, not accent (l.91–94) | 36dp `CtaSurface` disc, no lift and no glow; label follows the shared label style | `features/shell/tab_shell.dart:41-51` | Low |
| T4 | Count badge: small red pill (14dp, 9px text) on the icon's top right (`.tab .dot`, l.95) | M3 `Badge` with `scheme.error`, close enough | `core/widgets/tab_badge.dart:18-23` | OK |
| T5 | Labels Trang chủ / Khám phá / Tìm thợ ảnh (Đăng bài) / Đặt lịch (Công việc) / Hồ sơ | Same | `app/tabs.dart:45-79`, `l10n/app_vi.arb:10-16` | OK |

## S13 · Khám phá, no location yet (`features/explore/explore_screen.dart`)

Mock order: title + bell → search box → `seg` (4 tabs) → **2-column grid of four 21:9 photo tiles, each with name + "N gói"** → spectrum location card → "Sự kiện chụp ảnh" + "Xem tất cả" → horizontal row of 176dp 4:3 event photo cards.

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| E1 | Bell with count at top right | No action | `explore_screen.dart:118` | **Accepted** (S63–S65 not built) |
| E2 | Search box "Tìm dịch vụ, địa điểm, tên thợ ảnh" | Missing | `explore_screen.dart:95-108` | **Accepted** (plan 3b4) |
| E3 | Category entries are a **2-column grid** of 4 short tiles (21:9, roughly 70dp tall) | `SliverAdaptiveRows` gives **1 column** under 600dp, with one full-width 64dp+ tile per taxonomy entry: 12+ specialties on "Dịch vụ" and every area on "Địa điểm". On a phone this pushes the location card and events far below the fold, which inverts the mock's hierarchy | `explore_screen.dart:454-457`, `core/widgets/sliver_adaptive_rows.dart:25` | **High** (structure; not covered by the "text tiles" ruling, which is only about the missing images) |
| E4 | Each tile shows a package count ("128 gói") under the name | Name only | `explore_screen.dart:498-533` | Medium (spec: `exploreCategoriesProvider(tab)` "kèm số gói"; may wait for the taxonomy plan, needs a ruling) |
| E5 | Tile: photo with a dark bottom gradient and white bold name (`.ph .ov`) | Flat `primarySubtle` fill with serif `titleLarge` text | `explore_screen.dart:513-527` | **Accepted** (text tiles until the taxonomy plan) |
| E6 | Location card buttons are **compact** (`btn xs`: 30dp, 11px, not stretched), left-aligned **inside the text column** under the body | Two full-width 52dp buttons in a row under the whole icon+text row | `core/widgets/location_prompt_card.dart:50-60,108-126` | Medium |
| E7 | Card title "Sự kiện gần bạn" is bold 13px body text; icon is a 36dp accent-soft circle | Title `titleMedium` (16/600), icon circle 40dp | `location_prompt_card.dart:71-97` | Low |
| E8 | "Để sau" collapses the card into a chip that picks an area | Denied/later gives the `AppChip` "Chọn khu vực" with a pin icon | `location_prompt_card.dart:33-44` | OK |
| E9 | Events: horizontal row of photo cards (176dp, 4:3, date pill, title, "Còn 6 chỗ · 250K") | Vertical list of `NearbyEventTile` rows, at most 5 | `explore_screen.dart:348-377` | **Accepted** (stand-in until `EventCard`) |
| E10 | Section header: serif 17px title, accent 12px "Xem tất cả" link, baseline aligned | `titleLarge` (serif 20) + `TextButton` ("Xem tất cả" hidden until event routes exist) | `explore_screen.dart:242-266` | Low |
| E11 | Copy: "Khám phá", "Dịch vụ / Địa điểm / Phong cách / Thợ ảnh", "Sự kiện gần bạn", body, "Cho phép", "Để sau", "Sự kiện chụp ảnh", "Xem tất cả" | All match | `l10n/app_vi.arb:189-192,236-244` | OK |
| E12 | Segmented control: selected segment `accent-soft` + 1px accent inset + accent text; 11.5px | Same look; 14px text, 48dp tall | `core/widgets/segmented_tabs.dart:56-87` | Low |

## S35 · Khám phá with location or area (`explore_screen.dart` nearby branch, `widgets/event_tile.dart`)

Mock order: title + bell → location line (accent pin + "Quanh Quận 1, TP.HCM · vị trí gần đúng" + "Đổi") → chips → "Sự kiện gần bạn" + "Xem tất cả" → **featured 16:9 event photo** (pill "1,2 km · Còn 6 chỗ") → event row cards.

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| N1 | Order: location line, chips, events; spec adds "các khối Khám phá còn lại cuộn bên dưới" | Location, chips, events, then the category section | `explore_screen.dart:96-101` | OK (matches spec) |
| N2 | Pin icon in accent, 15dp | Default foreground icon, 18dp | `explore_screen.dart:171` | Low |
| N3 | A single radius chip "25 km" | One chip per radius 10 / 25 / 50 km | `explore_screen.dart:194-202`, `nearby_events.dart:12` | **Mock stale** (spec S35 asks for 10/25/50 chips) |
| N4 | Radius chip is a solid primary filter chip (`.chip.ac`); "Tuần này" selected shows the **context** style (`.chip.on`: accent-soft fill, accent border and text); no check icon | Every chip uses `AppChipKind.filter` (solid primary when selected), and `AppChip` adds a check icon whenever selected | `explore_screen.dart:195-222`, `core/widgets/app_chip.dart:74-79` | Medium (check icon not in mock; whether date toggles are "filter" or "context" needs a ruling, since the component rule says filters use solid fill) |
| N5 | Featured first event as a 16:9 photo card with a distance + seats pill, then rows | All rows, no featured card | `explore_screen.dart:334-339` | **Accepted** (EventCard stand-in) |
| N6 | Event row (`card` + `.date`): date block with **day and month both in accent**; title; "3,4 km · Công viên Bạch Đằng"; type as a **`.tag` pill**; **right column** with price (bold, tabular) over "Còn 3 chỗ" | Day number in foreground (only the month is primary); type as primary-coloured plain text; price and seats wrap under the title instead of a right column | `features/explore/widgets/event_tile.dart:74-92,109-141` | Low (stand-in; fold into the EventCard task, but the day colour and the tag pill are cheap to fix now) |
| N7 | Free event shows a green pill "Không thu phí" (`.tag.free`: radius 999, 10px, letter-spacing .04em) | `FreeTag` with radius 4 (`AppRadius.sm`) and 12px text: a square chip, not a pill | `core/widgets/free_tag.dart:33-48` | Medium |
| N8 | Copy "Quanh {area} · vị trí gần đúng", "Đổi", "Tuần này", "Cuối tuần", "Không thu phí", "Sự kiện gần bạn" | All match; device fix reads "Quanh bạn · vị trí gần đúng" | `app_vi.arb:220-237` | OK |
| N9 | Empty state (spec only): "Chưa có sự kiện gần bạn" + "Tăng bán kính" | Present; widen is an `AppButton.primary` | `explore_screen.dart:381-411` | OK |

## S36 · Chọn khu vực (sheet) (`features/explore/area_picker_sheet.dart`)

Mock order: grab handle → h3 "Chọn khu vực của bạn" → body → **bordered option cards** (`.opt`: border, radius 16, glass fill; selected = accent border + accent-soft fill + filled radio) → **outline sm "Mở Cài đặt để bật vị trí"** → primary "Dùng khu vực này".

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| A1 | Options are bordered cards with a custom radio; selected card tinted | Plain `InkWell` rows with M3 radio icons, no border or fill | `area_picker_sheet.dart:245-300` | Medium |
| A2 | "Mở Cài đặt để bật vị trí" sits **after** the list, just above the primary button, as a small outline button | Placed **before** the list (under the title), full-size outline with a gear icon, and only when the permission is denied forever | `area_picker_sheet.dart:111-129` | Medium (position). Showing it only when denied forever is reasonable behaviour (Low) |
| A3 | Only areas listed | Extra "Dùng vị trí của tôi" row and a search field when there are more than 8 areas | `area_picker_sheet.dart:95-107,130-140` | OK (sensible additions) |
| A4 | Body "Vị trí đang tắt. …" fits the denied state | The same body also shows when the sheet is opened from S35 "Đổi" with location on | `area_picker_sheet.dart:94` | Low (copy fits only one entry state) |
| A5 | Title is h3 (serif 17) | `titleLarge` (serif 20) | `area_picker_sheet.dart:88-91` | Low |
| A6 | Sheet: radius 28, blur 24, grab 36×4, max 88% height | `showAppSheet` matches | `core/widgets/app_bottom_sheet.dart` | OK |

## S33 · Thêm số điện thoại (`features/contact/add_phone_screen.dart`, route `/profile/phone`)

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| P1 | A **bottom sheet** over the screen the customer was on (dimmed). The code table says "(sheet)" | Full-screen route with an empty `AppBar` and a `GlassCard`. Spec: "bản đầu là trang đầy đủ, chuyển vào `AppBottomSheet` khi widget đó có", and `showAppSheet` now exists | `app/router.dart:124-126`, `add_phone_screen.dart:69-151` | **High** (the spec's own trigger has been met) |
| P2 | Phone input is **two fields**: a 72dp "Mã" field showing "+84", then "Số điện thoại" with no icon | One field with a `+84 ` prefixText and a phone prefix icon | `core/widgets/phone_field.dart:65-72` | Medium (spec text only says "tiền tố +84", so the single field may be acceptable; needs a ruling, and if kept the mock should change) |
| P3 | Order: title, body, phone, example, Zalo switch (on), WhatsApp switch (off), privacy, "Lưu và tiếp tục" | Same order and defaults | `add_phone_screen.dart:86-143` | OK |
| P4 | Privacy line is plain meta text | Has a lock icon in front | `add_phone_screen.dart:124-136` | Low |
| P5 | Copy: all S33 strings | Exact match (`addPhone*`, `allow*Label`, `phonePrivacy`) | `app_vi.arb:144-150` | OK |

## S34 · Thiết lập hồ sơ, bước 4/4 (`features/photographer_setup/contact_setup_screen.dart`, route `/setup/4`)

Mock order: bar (back · **"Hồ sơ nhiếp ảnh gia"** · "4 / 4" on the right) → 4-segment progress → h3 **"Khu vực và liên hệ"** → field "Khu vực phục vụ" → field "Số điện thoại · bắt buộc" → "Chọn kênh khách được dùng để liên hệ bạn." → 3 channel cards (icon in a field-coloured circle, title, hint, switch) → **sticky footer**: "Quay lại" (36%) + "Hoàn tất".

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| C1 | App bar title "Hồ sơ nhiếp ảnh gia"; "Khu vực và liên hệ" is the step heading (h3) in the body | App bar title is "Khu vực và liên hệ"; there is no flow title and no step heading | `contact_setup_screen.dart:25` | **High** (copy/hierarchy; the arb also lacks a "Hồ sơ nhiếp ảnh gia" key) |
| C2 | "4 / 4" sits in the app bar's right slot, with the progress bar under the bar (component rule "Bước nhiều trang": indicator and bar at the top) | `StepProgress` inside the glass card: count right-aligned above the bar | `contact_setup_screen.dart:206` | Medium |
| C3 | "Quay lại" / "Hoàn tất" in a **sticky footer** (`.foot`, surface background, top hairline), back at 36% width | Inline at the end of the scrolling card, 50/50 | `contact_setup_screen.dart:356-375` | Medium |
| C4 | Content sits directly on the page (fields, cards) | Whole form wrapped in one `GlassCard`, with the channel cards nested inside it (card in card) | `contact_setup_screen.dart:199-203` | Medium |
| C5 | Area is one field: "TP.HCM · bán kính 15 km" | City text field + radius chips | `contact_setup_screen.dart:208-241` | **Mock stale** (spec: "thành phố + bán kính km") |
| C6 | Radius chips (if kept) should be `AppChip` (`context` kind, single choice) | Material `ChoiceChip` (off-system look) | `contact_setup_screen.dart:231-239` | Medium |
| C7 | Channel hints: Gọi điện "Dùng số trên"; Zalo "Dùng số trên"; WhatsApp "Nhập số riêng nếu khác" | "Dùng số điện thoại ở trên"; "Dùng số ở trên hoặc nhập số riêng"; "Nhập số quốc tế riêng, hoặc dùng số ở trên" | `app_vi.arb:173,175,178` | Medium (copy; the spec wording sits between the two, so align mock and arb) |
| C8 | Three channel cards | A fourth card "Chỉ nhận tin nhắn trong app" | `contact_setup_screen.dart:315-327` | **Mock stale** (spec S34 "Trạng thái" defines this switch) |
| C9 | Channel card icon in a 36dp `--field` circle; card radius 20 | Bare 24dp glyph as `SwitchListTile.secondary`; border radius 12 | `contact_setup_screen.dart:142-156,194-195` | Low |
| C10 | Defaults in mock: Gọi on, Zalo on, WhatsApp off | All off for a new profile | `contact_setup_screen.dart:68-70` | Low (mock shows a filled state; no spec rule) |
| C11 | No privacy line | Extra lock + "Số của bạn không hiện công khai…" | `contact_setup_screen.dart:342-354` | Low (useful; add to mock) |
| C12 | Screen-level wait uses `ApertureLoader` (component rule) | `CircularProgressIndicator` while the prefill loads | `contact_setup_screen.dart:30` | Low (loader not built yet) |
| C13 | Copy "Khu vực phục vụ", "Số điện thoại · bắt buộc", channels line, "Quay lại", "Hoàn tất" | Match | `app_vi.arb:161-184` | OK |

## S42 · Chỉnh sửa hồ sơ (`features/settings/edit_profile_screen.dart`)

Mock order: bar (back · "Chỉnh sửa hồ sơ") → **76dp avatar centred** → "Tên hiển thị" (focused) → "Số điện thoại" → Zalo switch → WhatsApp switch → hint → **sticky footer "Lưu"**.

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| R1 | Avatar at the top | Missing | `edit_profile_screen.dart:103-121` | **Accepted** (spec: "Đổi ảnh đại diện làm ở kế hoạch 2d") |
| R2 | Hint copy "**Số điện thoại** chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc." (spec key `s42_phoneHint`) | Reuses the S33 string `phonePrivacy`: "**Số của bạn** chỉ hiện…" | `edit_profile_screen.dart:151-154`, `app_vi.arb:149` | Medium (copy) |
| R3 | "Lưu" in a sticky footer | Inline at the end of the card | `edit_profile_screen.dart:156-161` | Medium |
| R4 | Fields directly on the page | Wrapped in a `GlassCard` | `edit_profile_screen.dart:97-100` | Low |
| R5 | Name field has no icon; phone field has no icon and no "+84" adornment visible | Person icon on the name field; phone icon + "+84 " prefix (see P2) | `edit_profile_screen.dart:114-119` | Low |
| R6 | Spec: photographers (NAG) also get links "Kỹ năng" (S38) and "Kênh liên hệ" (S34) | Missing | `edit_profile_screen.dart` | Low (spec, not mock; check which plan owns it) |
| R7 | Title "Chỉnh sửa hồ sơ", labels, Zalo/WhatsApp switch copy | Match | `app_vi.arb:91-92,147-148` | OK |

## S31 · Cài đặt (`features/settings/settings_screen.dart`)

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| G1 | Group labels are small caps: 10.5px, uppercase, letter-spacing .08em, `--ink-3` | `titleMedium` (16/600, foreground, sentence case) | `settings_screen.dart:147-158` | Medium (visual hierarchy: the labels currently outweigh the rows) |
| G2 | Theme rows and button-style rows sit inside one card with hairline dividers; selected row = accent text + check | `ListTile`s inside `GlassCard` with no dividers; `selected` gives primary + check | `settings_screen.dart:54-111` | Low |
| G3 | "Xem trước nút" is a small primary button (`btn pri sm`, 38dp) | Full 52dp primary | `settings_screen.dart:113-121` | Low |
| G4 | Order: Tài khoản → Giao diện → Kiểu nút chính → preview | Same, plus a debug-only "Dành cho nhà phát triển" group | `settings_screen.dart:40-137` | OK (spec asks for the debug switch) |
| G5 | Copy | All match | `app_vi.arb:75-90` | OK |

## S30 · Hồ sơ tab (bonus: `features/shell/placeholder_tabs.dart`, seen while reading the shell)

| # | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| H1 | Switch-mode button is the screen's **primary** (`btn pri sm` with swap icon); "Đăng xuất" is outline | Switch is `AppButton.outline`, so the screen has no primary action | `placeholder_tabs.dart:177-196` | Medium |
| H2 | Card title is h3 (serif 17); no leading icon in the card | `titleMedium` + a leading primary icon | `placeholder_tabs.dart:143-174` | Low |
| H3 | Avatar is the shared avatar (64dp, ring) | `CircleAvatar` (not `AppAvatar`) | `placeholder_tabs.dart:111-121` | Low |
| H4 | Badge row "Khách thân thiết" / "Người chia sẻ" | Missing | — | Accepted (badges S37, later plan) |

---

## Shared widgets (`core/widgets/`) vs the mock's components

| Widget | Mock says | App does | File:line | Severity |
|---|---|---|---|---|
| **PhotoPill** | `.pill`: **white 94% fill, dark text (#1B1A18)**, 10.5px/600, green dot = available; a `--warn` dot variant ("Còn buổi chiều", S04) | **Black 55% fill, white text**; only a green dot, whose doc comment says it means "free" | `photo_card.dart:204-256` (fill l.218) | **High** (colour role inverted on every photo card) |
| PhotoCard | 4:5 / 3:4, overlay text only at the bottom, gradient `rgba(0,0,0,.72)→0`, no border or shadow, radius 16 (`--r2`) for small cards and 20 (`--r3`) for the big feed card | Same structure; radius always 20 | `photo_card.dart:49,72` | Low |
| **PhotographerCard** | S04: buttons "Hồ sơ" (outline sm) + "Đặt T7" (**`btn pri sm`, gradient**), both 38dp | Both outline (Book is a primary-tinted outline), 52dp | `photographer_card.dart:77-93` | Medium (needs a ruling: one-primary-per-screen vs the mock's primary on each card) |
| PhotographerCard | Avatar 40dp (`av.m`); meta "Chân dung · 1,2 km · ★ 4.9 · 112 buổi"; price + "từ" on the right | Default `AppAvatarSize.md` = 48dp; meta and price match | `photographer_card.dart:143-147` | Low |
| AppChip | Unselected: glass fill, `line-2` border, **ink-2** text, weight 500, 11.5px. Selected: no icon | Unselected text is full foreground at weight 600; **check icon added when selected** | `app_chip.dart:40-44,74-79,86-90` | Medium (check icon) / Low (colour) |
| SegmentedTabs | See E12 | — | `segmented_tabs.dart` | Low |
| LocationPromptCard | See E6, E7 | — | `location_prompt_card.dart` | Medium |
| FreeTag | See N7 (pill shape) | Radius 4 | `free_tag.dart:35` | Medium |
| FreeBanner | `.fbanner`: radius 16, padding 10×12, check icon, inset block | Square-cornered full-width strip (doc says "under an event cover (S16)") | `free_tag.dart:66-67` | Low (confirm against S16 when it is built) |
| ContactDial | Button radius 16 (48dp square) / 14 (38dp pill); tray item **visible** label "Gọi" (aria "Gọi điện"), Zalo, WhatsApp | Radius 12; tray label "Gọi điện" (same string for label and semantics) | `contact_dial.dart:37,273,283,579` | Low |
| PhoneField | See P2 (separate "Mã +84" box, no icon) | Prefix text + phone icon | `phone_field.dart:65-72` | Medium |
| StatTile (KPI) | `.kpi`: radius 16, **left-aligned** number and label, content pinned to the bottom (`justify-content:flex-end`) | Radius 12, **centred** column | `stat_tile.dart:26,36-38` | Medium |
| StepProgress | `.prog` 4dp segments, gradient fill, gap 4; count "n / N" in the app bar (see C2) | Bar matches; count drawn above the bar | `step_progress.dart:35-54` | Medium (placement, see C2) |
| VerifiedMark | 14dp `#3D63FF` disc, white check, raised 3dp, no text | Match (`ctaStart`) | `verified_mark.dart` | OK |
| AppAvatar | `.av` sizes 22/28/40/64, ring 2dp (3dp at 64) in the background colour | Sizes 32/40/48/64/96, ring 2dp + 2dp padding, gradient initial fallback | `app_avatar.dart:6-11,57-64` | Low (default `md` 48dp vs the mock's common 40dp) |
| ErrorState | No mock (component rules only: "lỗi theo quy ước") | Icon + message + "Thử lại" outline | `error_state.dart` | No reference |
| AppSkeleton | No mock; the rules name `ApertureLoader` for screen-level waits | Pulse skeletons | `app_skeleton.dart` | No reference (ApertureLoader not built) |
| ReasonChips | No mock found in the recommender section | — | `reason_chips.dart` | No reference |
| AppButton | Mock uses three heights: 48 (`btn`), 38 (`btn sm`), 30 (`btn xs`, not stretched) | One size (52dp, `controlHeight`); no `sm`/`xs` variants, which causes E6, G3, A2, H1 and the PhotographerCard button size | `app_button.dart`, `core/theme/app_theme.dart:8` | Medium (root cause) |
| App bar (all sub-screens) | Sub-screens: back · title (17px serif, **centred**) · empty slot; tab roots: 22px serif title, left | Default `AppBar`: `titleLarge` 20px, platform alignment (left on Android) | `core/theme/app_theme.dart:113-123` | Low |

---

## Prioritised fix list (each group could be one implementation task)

**1. Bottom navigation states (High, small).** Add `iconTheme` and a selected/unselected label colour to `navigationBarTheme`: primary when selected, tertiary grey when not. Add the top hairline. Optionally lift the middle disc and give it the purple glow. Files: `core/theme/app_theme.dart:173-187`, `features/shell/tab_shell.dart`. (T1–T3)

**2. PhotoPill colour role (High, small).** Switch to the mock's white 94% pill with dark text, add an availability-dot colour parameter (ok / warn), and fix the doc comment ("available", not "free"). Check contrast on light photos. Files: `core/widgets/photo_card.dart:204-256`, callers in `photographer_card.dart`. (PhotoPill)

**3. S13 category grid (High).** Render the category tiles as a 2-column grid on phones (4 columns, or 2 and wider, from 600dp), short 21:9 tiles, and cap or scroll the list so the location card and events stay near the fold. Add the "N gói" line when counts exist (or ask for a ruling to defer it with the taxonomy plan). Files: `features/explore/explore_screen.dart:413-533`. (E3, E4)

**4. S34 header and step layout (High + Medium).** App bar title "Hồ sơ nhiếp ảnh gia" (new arb key), step heading "Khu vực và liên hệ" in the body, "4 / 4" in the app bar actions with the progress bar under it. Move "Quay lại"/"Hoàn tất" into a sticky footer (36% / rest). Drop the outer `GlassCard` so the channel cards are not nested. Replace `ChoiceChip` with `AppChip(kind: context)`. Align the three channel hints with the mock (or update the mock and spec together). Consider a shared `StepScaffold` (app bar count + bar + footer) since S05–S07 and S25–S26 need the same thing. Files: `features/photographer_setup/contact_setup_screen.dart`, `core/widgets/step_progress.dart`, `l10n/app_vi.arb:173-178`. (C1–C4, C6, C7, C9)

**5. S33 as a bottom sheet (High).** Open add-phone through `showAppSheet` over the calling screen, keeping `/profile/phone?returnTo=` as the deep-link fallback. Keep the save → `returnTo` behaviour, and closing without saving cancels the booking flow (spec). Decide on the "Mã +84" split field (P2) at the same time, since `PhoneField` is shared with S34 and S42. Files: `features/contact/add_phone_screen.dart`, `app/router.dart:124-126`, `core/widgets/phone_field.dart`. (P1, P2, P4)

**6. AppButton size variants (Medium, enables 7–9).** Add `size: AppButtonSize.{regular, small(38), xsmall(30, intrinsic width)}` keeping a 48dp hit area. Then use `xs` in `LocationPromptCard` (inside the text column), `sm` for the S31 preview, the S36 settings button, the S30 switch button and the PhotographerCard buttons. Files: `core/widgets/app_button.dart`, `location_prompt_card.dart:50-126`. (E6, G3, A2, H1)

**7. S42 and S31 polish (Medium).** S42: new arb key for "Số điện thoại chỉ hiện với nhiếp ảnh gia sau khi bạn đặt cọc." (`s42_phoneHint`), a sticky "Lưu" footer, fields on the page without a GlassCard. S31: small-caps tertiary group labels, dividers between rows. Files: `features/settings/edit_profile_screen.dart`, `features/settings/settings_screen.dart:147-158`, `l10n/app_vi.arb`. (R2–R4, G1, G2)

**8. S36 sheet options (Medium).** Bordered option cards with a tinted selected state (reuse for S06/S47 options later as an `AppOptionTile`). Move "Mở Cài đặt để bật vị trí" below the list, above the primary button, as a small outline. Pick a body text that fits the "Đổi" entry state. File: `features/explore/area_picker_sheet.dart:76-129,245-300`. (A1, A2, A4)

**9. Chips, tags and KPI tiles (Medium).** `AppChip`: drop the selected check icon (or make it opt-in), unselected text in secondary at weight 500. Get a ruling on whether S35's date toggles use the filter or the context style. `FreeTag`: pill radius, 10px, tracking. `StatTile`: left-aligned, bottom-pinned, radius 16. Event tile quick wins: day number in primary, type as a tag pill, price and seats in a right column (or leave these for EventCard). Files: `core/widgets/app_chip.dart`, `free_tag.dart`, `stat_tile.dart`, `features/explore/widgets/event_tile.dart`. (N4, N6, N7, StatTile)

**10. S30 primary action (Medium, small).** Make "Chuyển qua chế độ …" `AppButton.primary` (sm), use `AppAvatar` (lg) and an h3 card title. File: `features/shell/placeholder_tabs.dart:111-196`. (H1–H3)

**11. Low-priority polish (batch).** App-bar title sizes and centring for sub-screens; pin icon colour on S35; section header 17px; ContactDial radius 16/14 and the visible "Gọi" label; PhotoCard small-card radius 16; AppAvatar default 40dp in cards; lock icons on privacy lines (keep them and add to the mock, or remove); `ApertureLoader` once built (S34 prefill). (T2, T3, E7, E10, N2, A5, C9–C12, R5, ContactDial, App bar)

**12. Mock updates (no app change).** Update `docs/design/ui-mock.html` (S34, S35) to match the newer spec: city + radius chips instead of one area field (C5); the "Chỉ nhận tin nhắn trong app" fourth card and the privacy line (C8, C11); 10/25/50 km radius chips (N3); the extra "Dùng vị trí của tôi" row and search in S36 (A3). Also record the PhotographerCard primary-button ruling and the PhoneField "+84" ruling in the mock captions.

### Accepted, not defects
S13 search box (plan 3b4) · S13/S35 events as a `NearbyEventTile` list, no featured card or horizontal row (events plan) · S13 category tiles as text, not photos (taxonomy plan) · bell on S13/S35 (S63–S65) · S42 avatar (plan 2d) · S30 badge row (S37).

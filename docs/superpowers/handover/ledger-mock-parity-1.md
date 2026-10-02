# SDD ledger — plan: docs/superpowers/plans/2026-10-02-mock-parity-1.md
Spec: docs/design/ui-mock.html (layout authority) + specs (behaviour). Audit: audit.md in this workspace.
## Preflight
| Pair/Task | Shared | Finding |
|---|---|---|
| T1 → T4,T8,T9,T10 | AppButtonSize | consumed by name |
| T3 AppChip ↔ T7 S34, T9 S35 | chip kinds | T3 sets S35 chip kinds; T7 uses context chips |
| T5 PhoneField ↔ T6 S33, T7 S34, T8 S42 | two boxes | T5 before T6–T8 |
| T10 AppOptionTile | new widget | reused later by S06/S47 |
| T11 mock edit | docs only | controller republishes artifact |
Ruling: commit trailer per environment, not reviewed. 2c paused after Task 6 (complete 620b768); resume at Task 7 after this plan.
Task 1: first commit (sizes) done
Ruling: controlHeight 52→48 (mock .btn); add tokens radius xl16/card20/sheet28/control14, text xs2 11 — exact mock parity — many visual tests updated
Task 1: fix round 1 dispatched
Task 1: complete c54eaae (controller-checked stat + tokens regenerated)
Ruling: batch Tasks 2+3 (small visual widget fixes)
Tasks 2+3: 4646a91, 68f7809 — review needs fixes (glass fill, free-ink, tag border, pill offset, middle tab label)
Tasks 2+3: fix round 1 dispatched
Tasks 2+3: fix a648b6b — 5 items reported; complete
Carry to Task 11: glass fill candidates photographer_card:96, event_tile:40, role_screen:129, reason_chips:36, segmented_tabs:39 (check vs mock); contact_dial_test.dart:671 tap() hit-test warning
Ruling: batch Tasks 4+5
Tasks 4+5: 3691bea, 9970c13 — review needs fixes (48dp layout box inflates card row)
Ruling: AppButton tapAlignment; compact buttons absorb adjacent padding into the 48dp tap box so layout equals the mock
Tasks 4+5: fix round 1 dispatched (+ contact_dial_test warning)
Tasks 4+5: fix d66dc1a — complete (841 tests, no warnings)
Carry to Task 11: stacked card buttons gap 18 → drop SizedBox (10)
NOTE: another session edits l10n/core.dart/splash/aperture_loader in the working tree — implementers stage only their own hunks
USER 2026-10-02: battery/perf moved to final plan (947dd10); no device rebuild per plan — only in the final plan
USER: every screen shows its code — codes default ON in debug, placeholders tagged (1d7b8dc); splash/session error have no code per spec §2 — ask user
Resumed 2026-10-02 (inline executing-plans) from handover copy; Tasks 1-5 complete
Task 6: reviewed parallel-session code (707d0d1): sheet via showAppSheet, deep-link /profile/phone renders AddPhoneContent, privacy line plain meta (P4), copy and order match mock S33; tests for sheet open/save/dismiss/deep link present
Task 6: Ruling: no caller to switch — nothing in lib/ navigates to /profile/phone yet (booking gate S03/S04/S02 → S05 is unplanned); showAddPhoneSheet is the API the booking-flow plan must call — cost if wrong: that plan forgets and pushes the route (still works, full page)
Task 6: Ruling: save error moved from SnackBar to inline live-region text — SnackBar sat under the sheet barrier, invisible — cost if wrong: copy position differs from a future mock error state
ENV: .flutter was upgraded (pull stable) by another session; Dart SDK re-downloaded outside sandbox (sysctl blocked → x64 guess); run flutter with --no-pub (pub.dev blocked in sandbox)
Task 6: complete (commits f442726..d6f27f1, tests: bash -c 'cd app_flutter && ../scripts/bin/flutter test --no-pub test/features/contact' → 00:04 +27: All tests passed!)
Task 7: Ruling: new shared AppFooterBar (core) for the sticky footer instead of a StepScaffold — S42 (Task 8) needs the same footer without a step bar — cost if wrong: one more widget to merge later
Task 7: Ruling: StepProgress gains showCount (default true); S34 puts "4 / 4" in the AppBar (ExcludeSemantics, StepProgress keeps the "Bước 4 trên 4" semantics) — cost if wrong: none for other callers
Task 7: Ruling: channel hints take the mock copy ("Dùng số trên" ×2, "Nhập số riêng nếu khác") — mock is the UI authority (C7) — cost if wrong: WhatsApp hint no longer says "quốc tế"; the field's own error text still asks for the country code
Task 7: remaining S34 differences (mock stale, spec newer; app kept): city field + radius chips (C5), 4th card "Chỉ nhận tin nhắn trong app" (C8), privacy line with lock (C11); defaults all-off (C10, no spec rule). Mock is NOT changed (user, handover)
Task 7: complete (commits d6f27f1..4dfb8eb, tests: bash -c 'cd app_flutter && ../scripts/bin/flutter test --no-pub test/features/photographer_setup test/core' → 00:15 +338: All tests passed!)
Task 8: Ruling: new key editProfilePhoneHint (arb is camelCase, spec name s42_phoneHint not used) — cost if wrong: rename
Task 8: Ruling: S31 label 10.5px → AppText.xs2 (11, nearest token); uppercase shown, semantics label in sentence case — cost if wrong: 0.5px
Task 8: remaining: S42 avatar (R1 accepted, plan 2d), name/phone icons (R5, not in task), NAG links (R6, other plan)
Task 8: complete (commits 4dfb8eb..455780f, tests: bash -c 'cd app_flutter && ../scripts/bin/flutter test --no-pub test/features/settings' → 00:05 +16: All tests passed!)
Task 9: Ruling: category grid shows the first 4 entries in catalogue order (portrait, wedding, couple, family; mock shows Chân dung/Cưới/Gia đình/Kỷ yếu) and a "Xem tất cả" link (not in mock) expands the tab in place — keeps every entry reachable — cost if wrong: one extra link vs mock; order could follow a curated list later
Task 9: Ruling: event type is the #tag text (`EventType.tag`, '#'+code without '_'), not a pill — committed mock 7030253 and events.md changed to .etag after the plan was written; semantics read the Vietnamese label — cost if wrong: none (mock is the authority)
Task 9: Ruling: event-row right column capped at 32% of the row width so long prices/"Không thu phí" never squeeze the title at 1.3x — cost if wrong: tag wraps in very narrow rows
Task 9: remaining (accepted): tile photos and "N gói" (E4/E5, taxonomy plan), bell + search (E1/E2), horizontal event cards and featured card (E9/N5, EventCard), SegmentedTabs text size (E12, not in task)
Task 9: complete (commits 455780f..822d7d1, tests: bash -c 'cd app_flutter && ../scripts/bin/flutter test --no-pub test/features/explore test/core' → 00:22 +414: All tests passed!)
Task 10: Ruling: "Mở Cài đặt" still only for denied-forever (A2 behaviour kept, position/size moved per mock) — cost if wrong: denied-once users get no shortcut
Task 10: Ruling: new key areaPickerBodyOn "Chọn khu vực để xem sự kiện quanh đó." when permission granted (A4) — cost if wrong: copy tweak
Task 10: Ruling: also did A5 (S36 title serif 17) — one-line, same file — cost if wrong: none
Task 10: Ruling: AppOptionTile semantics are radio (checked + mutually exclusive + selected), not button — cost if wrong: TalkBack says "radio" instead of "button"
Task 10: remaining: S30 badges (H4, S37 plan)
Task 10: complete (commits 822d7d1..4134b6f, tests: bash -c 'cd app_flutter && ../scripts/bin/flutter test --no-pub test/core test/features/explore test/features/shell' → 00:23 +433: All tests passed!)
Task 11: Ruling: "Mock updates" bullet NOT done — user (handover 2026-10-02) does not want the agreed mock changed; stale-mock items C5, C8, C11, N3, A3 stay as app-ahead-of-mock — cost if wrong: mock and app keep differing there until the user decides
Task 11: Ruling: app-bar style moved into the theme (centred serif 17 for sub-screens) + tabRootTitleStyle() for the 5 tab roots — fewer call sites — cost if wrong: a future root screen forgets the override and gets the sub-screen style
Task 11: Ruling: S36 "Mở Cài đặt" hidden while the keyboard is open — Task 10 put it in the fixed footer, which hid the search field at 320x568 with keys up (test now asserts hitTestable) — cost if wrong: shortcut unavailable while typing
Task 11: Ruling: AppAvatar default left at 48 (md) — both card callers pass 40/64 explicitly — cost if wrong: future callers get 48
Task 11: Ruling: glass fill applied to PhotographerCard and NearbyEventTile (mock .card); SegmentedTabs keeps field fill (mock .seg uses --field); reason_chips (no mock) and role_screen (not in plan) unchanged — cost if wrong: small light-theme tint differences
Task 11: not touched: login/register password lock icons (S28/S41, outside plan)
Task 11: complete (commits 4134b6f..8e5d94b, tests: bash -c 'cd app_flutter && ../scripts/bin/flutter analyze --no-pub && ../scripts/bin/flutter test --no-pub' → 00:36 +881: All tests passed!)
Final review: opus reviewer, 0 Critical, 6 Important, 12 Minor
Final: fixed compact button font (primary ignored size; outline/text lost family) — "compact text and shape follow the size … brand font" RED→GREEN, suite 893/893
Final: fixed gradient radius ignoring size — "… the gradient has radius" RED→GREEN, suite 893/893
Final: fixed S34 footer above home indicator — "the footer reaches the bottom edge over the gesture bar" RED→GREEN, suite 893/893
Final: fixed FreeTag wrapping at 320dp — '"Không thu phí" stays on one line at 320dp' RED→GREEN, suite 893/893
Final: fixed S33 sheet without screen code — "the sheet carries the S33 screen code" RED→GREEN, suite 893/893
Final: Ruling: Important 6 (missing keyboard/320x1.3 tests) — added S33/S34/S42 keyboard and S42 320x1.3 tests; all passed first run, so coverage only, no defect — cost if wrong: none
Final: Ruling: AppButton precedence changed so a caller `style` now wins over the primary base (before, base won) — no caller passes style to primary today — cost if wrong: a future style override on primary behaves differently than before
Final: Ruling: event right column cap 32%→45%, FreeTag maxLines 1 with ellipsis — cost if wrong: very long seat text could ellipsize the tag in tiny rows
Final: Ruling: declined items (avatar-blur per card → perf plan; tab bar tappable under sheets, pre-existing; dismiss mid-save on S33 → booking-flow plan; unused arb keys pre-date plan; login/register icons out of scope) — stand as reviewer noted
Final: minor (deferred): compact buttons' semantics node stays 38/30dp, no ripple in tap slack
Final: minor (deferred): S34 centred title may ellipsize at 320x1.3
Final: minor (deferred): S30 switch label may ellipsize at 320x1.3; compact buttons clip 2-line labels
Final: minor (deferred): two identical "Xem tất cả" labels on S13; expanding grid does not announce
Final: minor (deferred): AppOptionTile announces checked and selected; minHeight 48 → AppSpace.s12
Final: minor (deferred): raw numbers where tokens exist (stat_tile, event_tile 20/9.5, explore Size(48,48))
Final: minor (deferred): tab_shell middle-tab doc comment wrong about hit area
Final: minor (deferred): shared-components.md:49 still says 52dp / 38dp only in cards
Final: minor (deferred): S42 lost left/right safe-area in landscape
Final: minor (deferred): Explore private _SectionTitle instead of shared SectionHeader
Final: minor (deferred): category first-4 order vs mock, extra "Xem tất cả"
Final: minor (deferred): EventType.tag is UI formatting in the data layer

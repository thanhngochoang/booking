# Handover ledger — plan S09 profile and settings: S09.01 own-posts grid, S09.02 rebuilt (issue #148)

Plan: `docs/superpowers/plans/2026-10-07-s09-profile-settings.md`, Tasks 1–5. Branch `plan/148-s09-profile-settings`. Merge base 6e95637; commits f582a76 (mock frames and spec), 022aae3 (posts by author, disabled segments), 1e3fc6f and 358a935 (S09.02 and its review fix), 97fda45 and fa51921 (S09.01 and its review fix), then the docs commit of Task 5.

## Built
- Mock (Task 1): new frames `#S09.01-photographer` and `#S09.02-photographer`, the "Thông báo" group in the customer `#S09.02`, `.body.sc` (frames taller than a phone scroll). `screens/account.md` and `screens/portfolio-awards.md` updated.
- Data (Task 2): `PostRepository.byAuthor(uid, {kind, cursor, limit})` and `countByAuthor(uid, {kind})` (Firestore adapter with `count()` aggregation, fake, failing stub); `SegmentOption.enabled` in `SegmentedTabs`; two composite indexes on `posts`: `(authorId ASC, createdAt DESC)` and `(authorId ASC, kind ASC, createdAt DESC)`.
- S09.02 (Task 3): `settings_screen.dart` rebuilt with `settingsGroupOrder` (Decision 12), `RoleModeCard` (`role_mode_card.dart`), the three ready flags (`settings_links.dart`), appearance and button style as `SegmentedTabs`, studio address row, flagged rows for verify and studio. `CompletenessMeter` header became a `Wrap` (a narrow Kỹ năng row overflowed at 1.3x text; outside the plan's file list).
- S09.01 (Task 4): `lib/features/profile/profile_tab.dart` (moved out of `placeholder_tabs.dart`, which keeps `ActionTab` and `BookingsTab`) and `profile_posts_controller.dart`: header, notifications row, counts, badges, photographer extras, kind chips, 3-column grid, paging, empty and error states.
- Docs (Task 5): main spec §2 rows S09.01 ("✅ làm lại theo mock (#148)") and S09.02 ("✅ khớp mock (#148)"), one line each in the identity-verification and studio-members specs, a note under S19 in §3i.2, the ledger.
- Code names as built (the plan's Contract says `OwnPosts*`, renamed by Ruling 4): `ProfilePostsState`, `ProfilePostsController`, `profilePostsProvider` (family by `PostKind?`, autoDispose), `ProfilePostCounts` (with `of(kind)` and `present`), `profilePostCountsProvider`, all in `lib/features/profile/profile_posts_controller.dart`. `ProfilePostsController.refresh()` returns `Future<bool>` (false = reload failed while posts are shown), not the Contract's `Future<void>`.
- Indexes added (deployed by CI with the rules job); no rules or functions changed; no emulator suite skipped (nothing in `firebase/` rules, `packages/domain` or `services/` changed).

## Decisions of the plan
"Cost if wrong" is what it costs to undo the ruling.

| # | Ruling | Cost if wrong |
|---|---|---|
| 1 | The grid shows every post whose `authorId` is the user, all kinds, newest first, whatever mode is active. A pending `event_share` still shows on its author's profile. | One `where` on `kind`/mode in the query and a spec line. |
| 2 | Counts come from `count()` aggregations (all, `work`, `real_shoot`, `event_share`, in parallel), at open and after a refresh; chips show only kinds with count > 0, hidden with fewer than two kinds. | Replace four calls by a read of the posts (cost spec §13.3 forbids it). |
| 3 | The "đang theo dõi" and "đã lưu" tiles are hidden until S19 exists (`savedListsReadyProvider`). | None: flipping the flag shows them. |
| 4 | Header shows "{role} · {area}", area from the device's saved Explore area. **Not built**: see Ruling 3 below; the header shows the role only. | One missing word; the follow-up is reading the area from `SharedPreferences`. |
| 5 | Photographer extras stay on S09.01, below the badges and above the chips (setup card, Album của tôi, Thu nhập, awards nudge); the grid is the same in both modes. | Move four rows to another screen. |
| 6 | The role switch moved to S09.02 and keeps today's order: set the role first (rules need `hasPhotographerRole` to write `photographers/{uid}`), then open setup if unfinished; any other finished switch goes to `/profile`. The spec line "mở S08.01 thay vì đổi ngay" is not followed, for that technical reason (spec and mock captions now say so). | A role write moved after setup breaks the `photographers/{uid}` write; undoing means a rules change. |
| 7 | Ready flags in `lib/features/settings/settings_links.dart`, all default `false`; the rows and their copy ship now. | None: a row without its flag never shows. |
| 8 | "Quản lý sự kiện" stays staff-only (spec). It opens `/events/mine` (S12.03 list). | One role check. |
| 9 | "Địa chỉ studio" (studio only) opens `/setup/4?from=settings`; subtitle is the public district from `photographerProfileProvider(uid)` or "Chưa có địa chỉ". | One row. |
| 10 | "Kiểu nút chính" is a `SegmentedTabs` with a disabled "Ảnh đại diện làm mờ" segment while there is no avatar (`SegmentOption.enabled`), hint `buttonStyleAvatarNeedsPhoto`, new short key `settingsButtonGradientShort` "Gradient". | Remove a bool and a key. |
| 11 | Sign-out confirm copy unchanged (`signOut`, `settingsSignOutConfirmBody`, "Ở lại", red "Đăng xuất"); it is outside the mock and already tested. | None. |

Decision 12 (canonical S09.02 order, cross-plan review 2026-10-07): the eight plans that edit `settings_screen.dart` use one order, declared once as `settingsGroupOrder = ['account', 'mode', 'appearance', 'buttonStyle', 'notifications', 'paymentsData', 'support', 'debug', 'signOut']` with `settings-group-<name>` keys; the order test skips absent groups, so a later plan adds its group without editing the test. Slots: "Thanh toán và dữ liệu" (S22, #141) and "Hỗ trợ" (S18, #142) sit between Thông báo and the debug group. Within Tài khoản: after "Xác minh & nhận đơn" and the studio row come "Cộng tác" (photographers) and "Tin tuyển" (studios) from #151, then "Xem hồ sơ công khai", then "Người đã chặn" (#144), then staff "Quản lý sự kiện".

## Rulings made during execution
1. **Role switch to an unfinished photographer: go to `/profile`, then push `/setup`** (Back returns to Hồ sơ), instead of the plan snippet's `context.go('/setup')`, which left a new photographer in setup with no back. Cost if wrong: one extra page under setup. Review fix 358a935 also folded in a `PopScope` that blocks leaving Settings while the switch runs, and a test that the SnackBar names the mode from the controller's value, not from the profile stream.
2. Review minors 1 and 2 of Task 3 (back during switch, controller value in the SnackBar) went into the same fix round; cost if wrong: a few lines.
3. **S09.01 header shows the role only, no area.** `LocationController.build` schedules a GPS refresh when permission is granted, which is the side effect Decision 4 said to avoid, so `profileRoleWithArea` was not added to `app_vi.arb`. Cost if wrong: one missing word. Follow-up: read the saved area straight from `SharedPreferences` (`LocationController.areaKey` and `SavedArea.fromJson`) without the controller.
4. **Renamed the profile set to `ProfilePosts*` / `profilePostsProvider` / `ProfilePostCounts` / `profilePostCountsProvider`.** The plan's `OwnPosts*` names collide with `features/skills/own_posts_controller.dart` (the S08.04 evidence sheet), added after the plan. Cost if wrong: a rename.
5. **Load-more as built: driven by scroll position** (`extentAfter < 200` px on the tab's vertical scroll) plus a post-layout check that fills a short screen (tall or tablet views). The plan's footer trigger chained reads through every page on open, and an `itemBuilder` or lazy-sliver trigger still fired on open because the last row sat inside the 250 px cache extent. The controller's `loadingMore` guard and a generation counter (a page from before a refresh never lands) stay. Cost if wrong: none (same pattern as Home and Find).

## Needs the owner
1. Should photographers also see "Quản lý sự kiện" in Cài đặt (they already have "Sự kiện của tôi" under Công việc)? **Default: no, staff only**, as the spec says (`settings-manage-events` is behind the staff role).

## Ready flags (all in `lib/features/settings/settings_links.dart`, default `false`)
| Flag | Hides | Who flips it, and when |
|---|---|---|
| `verifyStartReadyProvider` | S09.02 row "Xác minh & nhận đơn" (`settings-verify` → `/verify/start`) | #135 (S21), when `/verify/start` (S21.02) exists; it may also add the status subtitle "Còn {n} bước". |
| `studioRoutesReadyProvider` | S09.02 rows "Studio của tôi" (`settings-my-studio` → `/me/studio`, individual and artist) and "Thành viên studio" (`settings-studio-members` → `/studio/members`, studio) | #136 (S26), when both routes exist. The "Studio của tôi" icon is `AppIcons.people` (the mock is silent); change it if the mock gets one. |
| `savedListsReadyProvider` | S09.01 tiles "đang theo dõi" and "đã lưu" | The S19 plan, when `/me/following` and `/me/saved` exist. The tiles show "—" with no tap target because no count source exists yet; S19 must wire real values and links when it flips the flag. |

## Review notes
From the SDD progress ledger (a local, untracked folder; the rulings are copied above):
- Pre-flight scan: no cross-task findings (T1 mock frames → T3/T4 parity; T2 data → T3/T4; T3 and T4 both edit `placeholder_tabs.dart`, run sequentially).
- Task 1 (6e95637..f582a76): review clean.
- Task 2 (f582a76..022aae3): review clean.
- Task 3 (022aae3..358a935): one Important finding (Ruling 1), fixed in round 1; review clean afterwards.
- Task 4 (358a935..fa51921): one Critical finding (chained page reads on open, Ruling 5) and one Important (name clash, Ruling 4), fixed in round 1 with the refresh-error minor; review clean afterwards.
- Task 5 also fixed Task 1's review minors in the mock and `screens/account.md`.

## Not run
- No emulator walkthrough, device build or iOS step (outside this plan's scope). `byAuthor` against real Firestore needs the two new indexes, which only CI deploys; `fake_cloud_firestore` does not check indexes, so nothing in the unit tests proves them.

## Deferred
From the plan:
- "đang theo dõi" and "đã lưu" counts and their lists: S19 (no mock yet); the tiles appear when `savedListsReadyProvider` is flipped.
- S21.02 "Xác minh & nhận đơn" screen and its status subtitle: #135 flips `verifyStartReadyProvider`.
- S26.01 and S26.03 studio screens: #136 flips `studioRoutesReadyProvider`.
- Thumbnails for grid tiles (egress): a follow-up of #147 (upload-time thumbnail purpose).
- Deleting a post from S02.02 (spec acceptance "xoá một bài ở S02.02 thì bài biến khỏi lưới"): no delete flow exists yet. When it lands, counts must exclude soft-deleted posts (`count()` cannot filter on a missing field; it needs a `deleted: false` field or a server counter).
- Privacy group (saved location, clear area) and "Trợ giúp & điều khoản": S22 and S18 plans.

Follow-ups:
- Move the S08.04 skills evidence sheet (`features/skills/own_posts_controller.dart`) onto `PostRepository.byAuthor`; it still has its own query.
- Read the saved area from `SharedPreferences` for the S09.01 header (Ruling 3).

Minors from the execution ledger (all "minor (deferred)" lines):
- Task 2: a disabled segment that is also the selected value keeps the selected background (S09 never does this: the avatar segment is forced to gradient without an avatar); the `authorId`/`kind` query is built twice in the adapter; the fake mirrors `_validId`.
- Task 3: dead `ConstrainedBox`/`IntrinsicHeight` in the old `ProfileTab` (gone with Task 4's rewrite); a redundant `setMockInitialValues` in the 320 dp test; overlapping sign-out tests; the RED-run load failure of `provider_type_sheet_test` (passes alone) is unexplained; in the window after the switch while the intro fetch runs, Settings can be left and the user is still moved to `/profile` (+ `/setup`); the go-then-push helper is more defensive than needed (2 s timeout); the real `/setup` route's `photographersOnly()` guard reads the profile stream, so a lagging stream could bounce `push('/setup')` (pre-existing; Firestore latency compensation makes it unlikely).
- Task 4: a filtered list that comes back empty (stale chip before the counts refresh) is blank until the counts-driven fallback returns to "Tất cả"; raw paddings in the tile tag and `_CountTile`; `_LinkRow` is not mock-styled (icon circle, compact padding); tile radius `AppRadius.md` (8) vs the mock's 6; a failed refresh during an in-flight next page leaves `loadingMore` stuck (spinner forever); two `NotificationListener`s duplicate the scroll listener (the house pattern is `_scroll.addListener`); `refresh()` is `Future<bool>`, not the Contract's `Future<void>`; the tab's own `ScrollController` loses iOS status-bar tap-to-top (same as Home, Find, Events; fix by looking up `PrimaryScrollController.of(context)`).
- Task 4 report: at 390 dp four chips ("Tất cả · 6 … Sự kiện · 2") overflow the width, so the chip row scrolls sideways (the mock's three-chip rows fit); the tile tag uses `surface` fill, `border` and `foreground` because no `glass-hi` token exists.
- Task 1: badge labels in the `#S09.01-photographer` frame ("100+ buổi chụp", "Phản hồi nhanh") are example copy; customer `#S09.02` now scrolls a little to reach Đăng xuất.

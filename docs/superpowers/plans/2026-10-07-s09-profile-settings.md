# S09 · Hồ sơ cá nhân & cài đặt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** S09.01 Hồ sơ becomes what the mock draws: the user's own posts in a 3-column grid with kind filters and counts, for customers and photographers alike, with the role switch and sign-out moved to S09.02. S09.02 Cài đặt matches the mock: "Tài khoản" rows, a "Chế độ" card that switches role, "Giao diện" and "Kiểu nút chính" as `SegmentedTabs`, "Xem trước nút", "Thông báo", and a red "Đăng xuất" at the bottom; photographers also get "Địa chỉ studio" (studio), "Xác minh & nhận đơn" (→ S21.02), "Studio của tôi" / "Thành viên studio" (→ S26); staff keep "Quản lý sự kiện" (→ S12.03 list). Rows whose screens do not exist yet are hidden behind ready flags, never dead links. **Architecture:** One new read path in the content data layer: `PostRepository.byAuthor` (cursor pages on `posts` where `authorId == uid`, optional `kind`) and `PostRepository.countByAuthor` (Firestore `count()` aggregation), with two composite indexes. `ProfileTab` moves from `features/shell/placeholder_tabs.dart` to `features/profile/` with a `MyPostsController`. Settings is rebuilt in place; the role-switch listener (`roleSwitchControllerProvider`, setup redirect) moves with the card. Ready flags are plain `Provider<bool>`s that the plans owning those routes flip. **Tech Stack:** Flutter, Riverpod 3, go_router, `cloud_firestore` (adapter only), Firestore indexes, `flutter_test`. **Spec:** mock `docs/design/ui-mock.html` `#S09.01`, `#S09.02` (+ new `#S09.01-photographer`, `#S09.02-photographer`); `docs/superpowers/specs/screens/account.md` (S09.01, S09.02); `docs/superpowers/specs/screens/portfolio-awards.md` (S09.01 Thông báo row, award nudge); main spec `2026-10-01-remaining-screens.md` §2, §3d.3, §3i (S19 lists, S21, S26), spec `2026-10-06-identity-verification-design.md` §4 and "Thay đổi màn cũ" (S09.02 row), `2026-10-06-studio-members-design.md` (S09.02 rows), `2026-10-05-provider-types-portfolio-jobs-design.md` §1 (Hình thức nhận việc); plan `2026-10-07-s08-provider-setup.md` ruling 1 (studio address row). **Issue:** #148

**Branch:** `plan/148-s09-profile-settings` from `origin/develop` (claimed with `scripts/project.py claim 148`), PR into `develop` titled `feat(profile): S09.01 own-posts grid and S09.02 settings per mock [#148]`.

## Global Constraints

- CLAUDE.md "UI matches the mock" (layout, order, copy, components, states); specs for behaviour. New variants get mock frames first (Task 1).
- One primary action per screen: S09.01 has none (spec "Không có nút chính"; the empty state's "Đăng bài đầu tiên" for photographers is the only primary when the grid is empty); S09.02's primary is "Xem trước nút"; the role switch is `AppButton.outline` small; sign-out is red text that opens a confirm sheet with a red button.
- Firebase isolation: `cloud_firestore` only in `lib/data/content/firestore_post_repository.dart`; features use `PostRepository`.
- Imports `package:photobooking/...`; features import `core/core.dart`.
- Tokens: `AppColors`/`AppColorsDark`, `AppSpace`, `AppRadius`, `AppText`; icons `AppIcons` (`settings`, `profile`, `phone`, `autoAwesome`, `work`, `place`, `award`, `verified`, `people`, `store`, `celebration`, `notifications`, `swap`, `album`, `wallet`, `chevron`, `pin`).
- Strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`.
- Ids/time: post ids opaque; `createdAt` UTC (`data-model/README.md`); kinds as string codes `work` / `real_shoot` / `event_share` (`PostKind.code`).
- No server code or rules change (region `asia-southeast1` untouched); only `firestore.indexes.json` gains two indexes.
- Reads: `get` + cursor pages of 20 for the grid; no listener on `posts`; counts by `count()` aggregation, never by reading documents (cost spec §13.3).
- Env for Flutter commands, from `app_flutter/`: `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time; bounded pumps (no endless animations: the grid skeleton must not loop forever in tests — use `AppSkeleton` which is static under `TickerMode(false)` or pump bounded durations). `flutter analyze` clean before each commit. Index file changes are deployed by CI; no emulator suite is run here.
- Commits: Conventional Commits, subject ends with `[#148]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Decisions

1. **The grid shows every post whose `authorId` is the user**, all kinds, newest first, whatever mode is active (spec). `event_share` posts have `photographerId: ''` and `serviceId: ''`; `postFromFirestore` accepts empty strings, so they map. A pending `event_share` (moderation on the event timeline) still shows on its author's own profile: it is their post.
2. **Counts come from `count()` aggregations**: one for all posts, one per kind (`work`, `real_shoot`, `event_share`), fetched together when S09.01 opens and after a refresh. Chips show only kinds with count > 0; with one kind or none the chip row is hidden (spec). The post count tile shows the total.
3. **"đang theo dõi" and "đã lưu" tiles are hidden until S19 exists** (`savedListsReadyProvider`, false). The spec already says so ("trước đó ẩn").
4. **Header layout follows the mock row**: avatar left (`AppAvatarSize.lg`), name (display font) and "{role} · {area}" right. Area = the area saved on this device for Explore (`locationControllerProvider` state `area?.name`), shown only when set; no Firestore read. If `LocationController.build` has side effects (permission request, GPS), drop the area and ledger it (cost if wrong: one missing word).
5. **Photographer extras stay on S09.01, below the badges and above the chips**: the unfinished-setup card, "Album của tôi" (the S24.02 caption says it opens from S09.01), "Thu nhập" (kept from 10b; the mock is silent), the awards nudge (S25.01 caption). They are drawn in the new `#S09.01-photographer` frame. The grid itself is identical in both modes.
6. **Role switch keeps today's behaviour, moved to S09.02**: switching to photographer sets the role first (rules need `hasPhotographerRole` to write `photographers/{uid}`), then opens `/setup` when setup is unfinished; any other finished switch goes to `/profile` (spec "Đổi xong về S09.01 ở chế độ mới"). The spec line "mở S08.01 thay vì đổi ngay" is not followed for that technical reason (ledger it).
7. **Ready flags** live in `lib/features/settings/settings_links.dart`: `verifyStartReadyProvider` (flip in #135 when `/verify/start` exists), `studioRoutesReadyProvider` (flip in #136 when `/me/studio` and `/studio/members` exist), `savedListsReadyProvider` (flip in the S19 plan). All default `false`. The row widgets and their copy ship now so #135/#136 only flip the flag (and may refine the subtitle with status).
8. **"Quản lý sự kiện" stays staff-only** (spec S09.02 "Staff thêm"; photographers manage their events from Công việc → "Sự kiện của tôi"). It opens `/events/mine` (`MyEventsScreen`, the S12.03 list; no longer a placeholder).
9. **"Địa chỉ studio"** (studio only, from the S08 plan ruling 1) opens `/setup/4?from=settings` (the existing S08.05 form with `popOnDone`); its subtitle is the public district from `photographerProfileProvider(uid)` (`PhotographerSummary.studioDistrict`; there is no public city field), else "Chưa có địa chỉ".
10. **"Kiểu nút chính" as `SegmentedTabs`** needs a disabled segment (avatar style without an avatar): `SegmentOption` gains `enabled` (default `true`); a disabled segment is greyed, not tappable, and announced as disabled; the hint "Thêm ảnh đại diện trong hồ sơ để dùng kiểu này." shows under the tabs while no avatar exists. The short label "Gradient" is a new key (the long `buttonStyleGradient` stays for other uses).
11. **Sign-out confirm copy unchanged** (`signOut` title, `settingsSignOutConfirmBody`, keep "Ở lại", red "Đăng xuất"); it is outside the mock and already tested.
12. **Other units touching the same files:** the S18 plan (`2026-10-07-s18-disputes-help.md`) adds a "Hỗ trợ" group with `Key('settings-help')` to `settings_screen.dart`, and the S15/S16 plan edits `BookingsTab` in `placeholder_tabs.dart`. If either has landed first, keep its additions: the "Hỗ trợ" group sits after "Thông báo" and before "Đăng xuất" (spec S09.02: "Trợ giúp & điều khoản … đặt giữa Kiểu nút chính và Đăng xuất"); `BookingsTab` stays in `placeholder_tabs.dart` untouched by the `ProfileTab` move. Ledger the merge.

## Needs the owner

1. Should photographers also see "Quản lý sự kiện" in Cài đặt (they already have "Sự kiện của tôi" under Công việc)? Default: no, staff only, as the spec says.

## Contract

- **Data** (`lib/data/content/content_repositories.dart`, `PostRepository` gains):
  ```dart
  /// Posts whose `authorId` is [uid], newest first (`createdAt` desc, then id
  /// desc); [kind] narrows to one kind. Same clamping and cursor rules as [feed].
  Future<PostPage> byAuthor(String uid, {PostKind? kind, String? cursor, int limit = 20});

  /// How many posts [uid] authored (all kinds, or one [kind]), counted by the
  /// server (`count()` aggregation, about one read per 1000 posts). Throws on
  /// transport failure.
  Future<int> countByAuthor(String uid, {PostKind? kind});
  ```
  `FirestorePostRepository.byAuthor` = `_page(_posts.where('authorId', isEqualTo: uid)[.where('kind', isEqualTo: kind.code)], cursor, limit)`; `countByAuthor` = `(await q.count().get()).count ?? 0`. Invalid uid (`!_validId`) → empty page / 0. `FakePostRepository` implements both over its list; `_FailingPosts` in `test/features/photographer_profile/profile_providers_test.dart` gets throwing stubs.
- **Indexes** (`app_flutter/firebase/firestore.indexes.json`): `posts (authorId ASC, createdAt DESC)`; `posts (authorId ASC, kind ASC, createdAt DESC)`. (`posts (authorId ASC, kind ASC)` exists and serves the per-kind counts.)
- **Profile feature** (new folder `lib/features/profile/`):
  ```dart
  // my_posts_controller.dart
  @immutable class MyPostsState {
    const MyPostsState({this.posts = const [], this.nextCursor, this.loadingMore = false, this.moreError = false});
    final List<PostSummary> posts; final String? nextCursor; final bool loadingMore; final bool moreError;
  }
  /// One page list per filter (null = all kinds). autoDispose: re-read on each visit.
  final myPostsProvider = AsyncNotifierProvider.autoDispose.family<MyPostsController, MyPostsState, PostKind?>(MyPostsController.new);
  class MyPostsController extends AsyncNotifier<MyPostsState> { Future<void> loadMore(); Future<void> refresh(); }

  @immutable class MyPostCounts { const MyPostCounts({required this.total, required this.byKind}); final int total; final Map<PostKind, int> byKind; }
  final myPostCountsProvider = FutureProvider.autoDispose<MyPostCounts>(…); // 4 count() calls in parallel (Future.wait)

  // profile_tab.dart — moved from features/shell/placeholder_tabs.dart
  class ProfileTab extends ConsumerStatefulWidget { const ProfileTab({super.key}); } // holds the selected PostKind? filter
  ```
  `lib/app/router.dart` imports `ProfileTab` from the new file; `placeholder_tabs.dart` keeps `ActionTab`, `BookingsTab` and loses `_openSetupIfUnfinished` (moved to `lib/features/settings/role_mode_card.dart`).
- **S09.01 layout** (top to bottom): AppBar (`tabRootTitleStyle`, "Hồ sơ", gear `Key('open-settings')` → `/settings`) · header row (`AppAvatar` lg, name, `profileRoleWithArea` or role) · `_NotificationsRow` (unchanged) · counts row: `profilePostsCount` with the total (+ following/saved tiles only when `savedListsReadyProvider`) · `_BadgesRow` (unchanged) · photographer extras (Decision 5) · chip row `AppChip(kind: AppChipKind.filter)` keys `profile-filter-all|work|real_shoot|event_share` · `SliverGrid` 3 columns, square tiles (`NetworkPhoto(url: post.cover.url)`), corner tag `profileTagEventShare` / `profileTagRealShoot` when the filter is "all" (no tag for `work`), tap → `context.push('/p/${post.id}')`, key `profile-post-${post.id}` · load-more when the last row builds (`loadMore`), error row "Không tải thêm được. Thử lại" (`profilePostsMoreError`) tappable · empty: photographer `EmptyState(title: profileEmptyPhotographerTitle, actionLabel: profileEmptyPhotographerAction, onAction: () => context.go('/action'))`, customer `EmptyState(title: profileEmptyCustomerTitle, body: profileEmptyCustomerBody)` · first-load error: `ErrorState(message: profilePostsError, onRetry: refresh)`. The whole tab is one `CustomScrollView` with `RefreshIndicator` (refresh = invalidate posts + counts).
- **S09.02** (`lib/features/settings/settings_screen.dart`, rebuilt; new helpers `lib/features/settings/role_mode_card.dart`, `lib/features/settings/settings_links.dart`):
  - Group "Tài khoản" (`_SectionLabel(settingsAccount)` + `GlassCard`): Chỉnh sửa hồ sơ (`settings-edit-profile` → `/settings/profile`) · Số điện thoại (`profile-phone` → `/profile/phone`, unchanged `_PhoneTile`) · photographer: Kỹ năng (`profile-skills`, unchanged) · Hình thức nhận việc (`profile-provider-type`, unchanged) · studio only: Địa chỉ studio (`settings-studio-address` → `/setup/4?from=settings`) · Giải thưởng (`profile-awards`) · flag `verifyStartReadyProvider`: Xác minh & nhận đơn (`settings-verify` → `/verify/start`) · flag `studioRoutesReadyProvider`: individual/artist "Studio của tôi" (`settings-my-studio` → `/me/studio`), studio "Thành viên studio" (`settings-studio-members` → `/studio/members`) · Xem hồ sơ công khai (`profile-public` → `/u/$uid`) · staff: Quản lý sự kiện (`settings-manage-events` → `/events/mine`).
  - Group "Chế độ" (`settingsMode`): `RoleModeCard` = `GlassCard` with title `profileOfferPhotographerTitle`/`profileOfferCustomerTitle`, body `profileOffer…Body`, `AppButton.outline(…, key: Key('switch-role'), size: AppButtonSize.small, icon: AppIcon(AppIcons.swap), loading: switching)`; owns the `ref.listen(roleSwitchControllerProvider, …)` (SnackBars `profileSwitchedTo*` / `profileSwitchError`, then setup redirect or `context.go(AppTab.profile.path)`, Decision 6). While switching, the rest of the screen is `AbsorbPointer`ed.
  - Group "Giao diện": `SegmentedTabs<ThemeMode>(key: Key('settings-theme'), options: [dark "Tối", light "Sáng", system "Theo hệ thống"])` → `themeModeProvider.notifier.set`.
  - Group "Kiểu nút chính": `SegmentedTabs<ButtonStyleMode>(key: Key('settings-button-style'), options: [gradient settingsButtonGradientShort, avatar buttonStyleAvatar (enabled: hasAvatar)])` + hint `buttonStyleAvatarNeedsPhoto` when `!hasAvatar` + `AppButton.primary(settingsButtonPreview, size: small)` (unchanged preview).
  - Group "Thông báo": the existing row (`settings-notifications` → `/settings/notifications`).
  - Debug group (only `kDebugMode`): unchanged switch.
  - Bottom: red `TextButton` `settings-sign-out` → confirm sheet (unchanged).
  - `SegmentOption` (`lib/core/widgets/segmented_tabs.dart`) gains `final bool enabled;` (`const SegmentOption({required this.value, required this.label, this.enabled = true})`); disabled: label in `foregroundDisabled`, no `onTap`, `Semantics(enabled: false)`.
- **Ready flags** (`lib/features/settings/settings_links.dart`):
  ```dart
  /// #135 flips this when `/verify/start` (S21.02) exists.
  final verifyStartReadyProvider = Provider<bool>((ref) => false);
  /// #136 flips this when `/me/studio` (S26.03) and `/studio/members` (S26.01) exist.
  final studioRoutesReadyProvider = Provider<bool>((ref) => false);
  /// The S19 plan flips this when `/me/following` and `/me/saved` exist.
  final savedListsReadyProvider = Provider<bool>((ref) => false);
  ```
- **l10n** (new keys, exact text):
  - S09.01: `profilePostsCount` "bài đăng"; `profileFollowingCount` "đang theo dõi"; `profileSavedCount` "đã lưu"; `profileRoleWithArea` "{role} · {area}" (`role`, `area`: String); `profileFilterAll` "Tất cả · {n}"; `profileFilterWork` "Tác phẩm · {n}"; `profileFilterRealShoot` "Buổi chụp · {n}"; `profileFilterEventShare` "Sự kiện · {n}" (`n`: int each); `profileTagRealShoot` "Buổi chụp"; `profileTagEventShare` "Sự kiện"; `profileEmptyPhotographerTitle` "Chưa có bài đăng"; `profileEmptyPhotographerAction` "Đăng bài đầu tiên"; `profileEmptyCustomerTitle` "Chưa có ảnh nào"; `profileEmptyCustomerBody` "Ảnh bạn chia sẻ sau buổi chụp sẽ hiện ở đây"; `profilePostsError` "Không tải được bài đăng."; `profilePostsMoreError` "Không tải thêm được. Thử lại"; `profilePostTile` "Bài đăng {n}" (`n`: int, spoken label of a tile without caption).
  - S09.02: `settingsMode` "Chế độ"; `settingsButtonGradientShort` "Gradient"; `settingsStudioAddress` "Địa chỉ studio"; `settingsStudioAddressEmpty` "Chưa có địa chỉ"; `settingsVerify` "Xác minh & nhận đơn"; `settingsVerifyBody` "Xác minh danh tính để bắt đầu nhận đơn"; `settingsMyStudio` "Studio của tôi"; `settingsMyStudioBody` "Studio đang ở, việc được giao, lời mời"; `settingsStudioMembers` "Thành viên studio"; `settingsStudioMembersBody` "Mời thợ, giao việc cho thành viên".
  - Existing keys reused: `tabProfile`, `profileRoleCustomer`, `profileRolePhotographer`, `profileOffer*`, `profileSwitch*`, `profileSetup*`, `profileMyAlbums*`, `profileEarnings*`, `settings*`, `theme*`, `buttonStyle*`, `signOut`.
- **Routes** used: `/profile`, `/settings`, `/settings/profile`, `/settings/notifications`, `/profile/phone`, `/profile/skills`, `/setup`, `/setup/4?from=settings`, `/me/awards`, `/me/albums`, `/work/earnings`, `/u/:uid`, `/u/:uid/badges`, `/p/:postId`, `/events/mine`, `/action`, `/notifications` (all exist); `/verify/start`, `/me/studio`, `/studio/members` (not yet; behind flags).
- **Rules:** none (posts are readable by any signed-in user: `match /posts/{postId} allow read: if signedIn()`).

## Review Focus

1. A user with 0 posts of a kind but a stale chip selected (e.g. "Sự kiện" chosen, then the only event share is gone after refresh): the filter must fall back to "Tất cả" instead of showing an empty grid under a missing chip. Pinned in Task 4 (`a selected kind that disappears falls back to all`).
2. Switching role from S09.02 while the profile stream is still on the old role: the SnackBar names the new mode from the controller's value, not the stream; an unfinished photographer is sent to `/setup`, not to `/profile`. Pinned in Task 3 (`switching to photographer with setup unfinished opens /setup`, `switching to customer goes back to /profile`).
3. Ready-flag rows never appear with the flag off, so no tap can reach a missing route (GoRouter error page). Pinned in Task 3 (`flagged rows are hidden while their routes do not exist`, and `with the flags on they open their routes`).
4. Load-more at the end of the grid fires once per page (no request storm while the last row rebuilds) and a failed page keeps the posts shown with a retry row. Pinned in Task 4 (`load more runs once per page`, `a failed next page keeps the grid and offers retry`).
5. 320 dp × 1.3 text: S09.01 header (long Vietnamese name + "Nhiếp ảnh gia · Thành phố Hồ Chí Minh") and S09.02 `SegmentedTabs` labels ("Ảnh đại diện làm mờ") fit without overflow (labels scale down). Pinned in Task 4 (S09.01) and Task 3 (S09.02).

## Chi phí Google

- **S09.01 open:** `byAuthor` first page = 21 document reads (20 + 1 look-ahead, `get`, no listener) + 4 `count()` aggregations (1 read each while a user has < 1,000 posts) = **25 reads**; "load more" = 21 reads per page. The existing notification row (1 doc listener) and badges are unchanged. Assume 8 profile-tab opens/MAU/month (autoDispose re-reads each visit): 200 reads/MAU/month → **200K reads/month at 1,000 MAU, 2M at 10,000 MAU**. At the nam5 upper bound $0.06/100K ("chưa xác nhận" for Singapore): $0.12 (b), within the free 50K/day anyway; $1.20 (c).
- **S09.02 open:** 3 reads (contact doc listener while open, skills snapshot, provider profile `get`), ~2 opens/MAU/month → 6K (b) / 60K (c) reads → < $0.05.
- **Indexes:** 2 new composite indexes on `posts`; index storage is a few bytes per post, negligible.
- **Egress (Storage):** the grid shows each post's cover at full size (no thumbnails yet; #147 compresses portfolio covers to 2048 px q82, ~500 KB). A photographer's first view of 20 tiles ≈ 10 MB, then `cached_network_image` serves from disk. Assume one cold view/month per photographer (10% of MAU): 1 GB (b) / 10 GB (c) × $0.12/GB (assumed, "chưa xác nhận") = **$0.12 (b) / $1.20 (c)**. Customers' grids are small (a few shares).
- **Functions, scheduled jobs, new Storage paths, paid APIs:** none.
- **Conclusion:** **+$0.25/month at (b) 1,000 MAU, +$2.50/month at (c) 10,000 MAU** (under $5). The largest part is egress from full-size covers; thumbnails (deferred in #147) would cut it ~10×.

## Tasks

### Task 1: Mock frames for the photographer variants and the spec

**Files:**
- Modify: `docs/design/ui-mock.html` (`#S09.01` caption, `#S09.02` frame: add a "Thông báo" group; new frames `#S09.01-photographer`, `#S09.02-photographer` after `#S09.02`), `docs/superpowers/specs/screens/account.md` (S09.01, S09.02 sections: photographer extras order, flagged rows, studio address row, chip labels "Tác phẩm/Buổi chụp/Sự kiện", Decisions 2–4, 6–10 in Vietnamese), `docs/superpowers/specs/screens/portfolio-awards.md` (S09.01 note: extras sit between badges and chips)

- [ ] **Step 1:** In `#S09.02` (customer frame) insert before the `flex:1` spacer: `<div class="meta x" style="text-transform:uppercase;letter-spacing:.08em;font-size:10.5px">Thông báo</div><div class="card" style="flex-direction:column;align-items:stretch;padding:2px 10px;gap:0"><div class="row" style="padding:8px 0"><div class="ic"><span class="ms">notifications</span></div><div class="grow"><b style="font-size:13px">Thông báo</b><div class="meta x">Push, giờ yên lặng, nhắc buổi chụp</div></div><div class="ic"><span class="ms" style="transform:scaleX(-1)">arrow_back</span></div></div></div>`; segment label "Gradient" stays.
- [ ] **Step 2:** New frame `#S09.01-photographer` (`data-code="S09.01"`), same structure as `#S09.01` with: name "Minh Trí", meta "Nhiếp ảnh gia · TP.HCM"; Thông báo row "Lan Anh gửi yêu cầu đặt lịch" badge 2; counts row with only "24 bài đăng"; badges row; three link cards (same `.card` markup as the Thông báo row, chevron right): `album` "Album của tôi" / "Gom bài thành album, sắp xếp thứ tự trên hồ sơ"; `account_balance_wallet` "Thu nhập" / "Tiền đang giữ, sắp nhận và đã nhận"; `workspace_premium` "Có giải thưởng? Lên hạng Nhiếp ảnh gia" with a text button "Để sau"; chips "Tất cả · 24" (on), "Tác phẩm · 22", "Sự kiện · 2"; grid of 6 `ph` tiles, one with the "Sự kiện" tag; tab bar with "Đăng bài" in the middle (photographer). Caption: `<span class="n new">Mới</span><span class="n">S09.01 · Hồ sơ (nhiếp ảnh gia)</span><b>Cùng lưới bài đăng, thêm lối vào việc của thợ</b><span>Dưới huy hiệu: thẻ "Hoàn thiện hồ sơ nhiếp ảnh gia" khi thiết lập chưa xong (→ S08.01), "Album của tôi" (→ S24.02), "Thu nhập" (→ S06.05), dòng nhắc giải thưởng khi hồ sơ là Cá nhân (→ S25.01, ẩn sau "Để sau"). "đang theo dõi · đã lưu" chỉ hiện khi S19 xong. Chip chỉ hiện loại có bài; chỉ một loại thì ẩn hàng chip. Trống: "Chưa có bài đăng" + nút "Đăng bài đầu tiên" (→ S10.01).</span>`.
- [ ] **Step 3:** New frame `#S09.02-photographer` (`data-code="S09.02"`): "Tài khoản" card rows (icon, title, sub, chevron): `person` "Chỉnh sửa hồ sơ" / "Minh Trí"; `call` "Số điện thoại" / "•••• 0001"; `auto_awesome` "Kỹ năng" / a `.cbar` 72%; `work` "Hình thức nhận việc" / "Studio"; `place` "Địa chỉ studio" / "Quận 1"; `workspace_premium` "Giải thưởng" / "Khai giải để lên hạng Nhiếp ảnh gia"; `verified` "Xác minh & nhận đơn" / "Xác minh danh tính để bắt đầu nhận đơn"; `groups` "Thành viên studio" / "Mời thợ, giao việc cho thành viên"; `storefront` "Xem hồ sơ công khai" / "Hồ sơ như khách nhìn thấy". "Chế độ" card: "Tôi cần đặt lịch" / "Tìm nhiếp ảnh gia, đặt lịch và nhắn tin. Bạn vẫn đổi lại được bất cứ lúc nào." / `btn out sm` with `swap_horiz` "Chuyển qua chế độ đặt lịch". Then the same Giao diện / Kiểu nút / Xem trước nút / Thông báo / Đăng xuất as `#S09.02`. Caption: `<span class="n new">Mới</span><span class="n">S09.02 · Cài đặt (nhiếp ảnh gia, studio)</span><b>Mọi lối vào việc của thợ ở một nhóm</b><span>Thứ tự trong Tài khoản: Chỉnh sửa hồ sơ, Số điện thoại, Kỹ năng, Hình thức nhận việc, Địa chỉ studio (chỉ Studio, mở S08.05), Giải thưởng (S25.01), Xác minh &amp; nhận đơn (S21.02), Studio của tôi (Cá nhân, S26.03) hoặc Thành viên studio (Studio, S26.01), Xem hồ sơ công khai (S03.01); staff thêm Quản lý sự kiện (S12.03). Dòng nào có màn chưa làm thì ẩn, không để link chết.</span>`.
- [ ] **Step 4:** `#S09.01` caption: replace "<b>Tác phẩm</b> (<code>work</code>, nhiếp ảnh gia)" sentence unchanged but append ` Bản nhiếp ảnh gia: S09.01-photographer.`; spec edits in `account.md` and `portfolio-awards.md`.
- [ ] **Step 5:** `grep -o 'id="S09[^"]*"' docs/design/ui-mock.html | sort | uniq -d` prints nothing; `flutter test --no-pub --timeout 60s test/core/screen_codes_test.dart` green.
- [ ] **Step 6: Commit** `docs(mock): S09 photographer variants and the Thông báo group [#148]`.

### Task 2: Own posts by author (data, indexes) and `SegmentOption.enabled`

**Files:**
- Modify: `app_flutter/lib/data/content/content_repositories.dart`, `app_flutter/lib/data/content/firestore_post_repository.dart`, `app_flutter/lib/data/content/fake_content_repositories.dart`, `app_flutter/firebase/firestore.indexes.json`, `app_flutter/lib/core/widgets/segmented_tabs.dart`, `app_flutter/test/features/photographer_profile/profile_providers_test.dart` (`_FailingPosts` stubs)
- Test: `app_flutter/test/data/content/fake_post_repository_by_author_test.dart` (create), `app_flutter/test/core/widgets/segmented_tabs_test.dart` (extend)

**Interfaces:**
- Produces: `PostRepository.byAuthor`, `PostRepository.countByAuthor` (Contract); `SegmentOption.enabled`.

- [ ] **Step 1: Failing tests.**
  - Fake repo (`FakePostRepository` seeded with posts by `u1`: 3 `work`, 1 `real_shoot`, 2 `event_share`, and 2 by `u2`): `byAuthor returns only u1's posts newest first`; `byAuthor with kind returns only that kind`; `byAuthor pages by cursor with the feed rules` (limit 2 → cursor non-null, last page cursor null); `countByAuthor counts all and per kind` (6; work 3, real_shoot 1, event_share 2; unknown uid 0); `an id with '/' yields an empty page and 0`.
  - `segmented_tabs_test.dart`: `a disabled segment cannot be tapped` (onChanged not called); `a disabled segment is announced as disabled` (`tester.getSemantics(...)` has `isEnabled` false / `hasEnabledState` true); `enabled defaults to true`.
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/data/content/` and `… test/core/widgets/segmented_tabs_test.dart` — fail (missing members).
- [ ] **Step 3: Implement** per Contract. Firestore adapter: reuse `_page`; `countByAuthor`:
  ```dart
  @override
  Future<int> countByAuthor(String uid, {PostKind? kind}) async {
    if (!_validId(uid)) return 0;
    Query<Map<String, dynamic>> q = _posts.where('authorId', isEqualTo: uid);
    if (kind != null) q = q.where('kind', isEqualTo: kind.code);
    final snap = await q.count().get();
    return snap.count ?? 0;
  }
  ```
  Indexes: add the two composite indexes (Contract) to `firestore.indexes.json`, keeping the file's existing ordering style.
- [ ] **Step 4: Run** the two targets + `flutter test --no-pub --timeout 60s test/features/photographer_profile/` (the `_FailingPosts` stub compiles) + `flutter analyze`; green. `node -e 'JSON.parse(require("fs").readFileSync("firebase/firestore.indexes.json","utf8"))'` parses.
- [ ] **Step 5: Commit** `feat(data): own posts by author with server counts; disabled segments [#148]`.

### Task 3: S09.02 settings per mock with the mode card and flagged rows

**Files:**
- Create: `app_flutter/lib/features/settings/role_mode_card.dart`, `app_flutter/lib/features/settings/settings_links.dart` (all three flags), `app_flutter/test/features/settings/settings_mode_test.dart`
- Modify: `app_flutter/lib/features/settings/settings_screen.dart`, `app_flutter/lib/l10n/app_vi.arb`, `app_flutter/test/features/settings/settings_test.dart`, `app_flutter/test/features/settings/settings_awards_test.dart` (keys unchanged; fix finders only if the layout moved them), `app_flutter/lib/features/shell/placeholder_tabs.dart` (remove from `ProfileTab` the mode card, its `ref.listen(roleSwitchControllerProvider…)`, `_openSetupIfUnfinished` and the sign-out button, so only S09.02 switches and signs out: no double SnackBar while Settings is pushed over Hồ sơ), `app_flutter/test/features/shell/placeholder_tabs_test.dart` (move `profile tab signs out`, `photographer switches to customer and back from profile`, `a failed switch keeps the role and says so`, `S09.01: switch is the small primary…`, `switching to photographer opens setup while it is unfinished` into `settings_mode_test.dart`, rewritten for S09.02)

**Interfaces:**
- Consumes: `roleSwitchControllerProvider` (`lib/features/onboarding/role_controller.dart`), `photographerIntroRepositoryProvider` (setup check, as `_openSetupIfUnfinished` did), `themeModeProvider`, `buttonStyleProvider`, `currentProfileProvider`, `liveProviderTypeProvider`, `photographerProfileProvider(uid)` (studio district), `staffRoleProvider`, `photographerSkillsSnapshotProvider`, `currentContactProvider`, `pushRegistrationProvider`, `SegmentedTabs`/`SegmentOption.enabled` (Task 2), ready flags.
- Produces: `RoleModeCard`, the three ready-flag providers (Contract).

**Mock parity:** `#S09.02` and `#S09.02-photographer`: back · "Cài đặt"; "TÀI KHOẢN" card rows in the Contract order; "CHẾ ĐỘ" card with the two-line copy and a small outline "Chuyển qua chế độ …" with `swap_horiz`; "GIAO DIỆN" `SegmentedTabs` Tối / Sáng / Theo hệ thống; "KIỂU NÚT CHÍNH" `SegmentedTabs` Gradient / Ảnh đại diện làm mờ (+ hint when locked); primary "Xem trước nút"; "THÔNG BÁO" row; red "Đăng xuất" at the bottom.

**Backend wiring:** role switch → `RoleSwitchController.switchTo` → `UserRepository.setRole` (Firestore `users/{uid}` batch, `photographers/{uid}` on first switch; rules `hasPhotographerRole`); setup check → `FirestorePhotographerIntroRepository.get`; studio address subtitle → `FirestorePublicProfileRepository.load` (`photographers/{uid}` public `studioDistrict`); the address form itself is S08.05 (`setStudioAddress` callable); everything else is local (`SharedPreferences` for theme and button style).

- [ ] **Step 1: Failing tests.**
  - `settings_mode_test.dart`:
    - `a customer sees "Tôi là nhiếp ảnh gia" and an outline "Chuyển qua chế độ nhiếp ảnh"` (button is `AppButton` with `variant`/type outline — use the same finder style as the old S09.01 test; not `AppButton.primary`).
    - `switching to photographer with setup unfinished opens /setup` (fake intro `onboardingComplete: false`; SnackBar "Đã chuyển qua chế độ nhiếp ảnh.").
    - `switching to photographer with setup complete goes back to /profile`.
    - `switching to customer goes back to /profile` (SnackBar "Đã chuyển qua chế độ đặt lịch.").
    - `a failed switch keeps the role and says so` ("Không đổi được chế độ. Kiểm tra mạng rồi thử lại.").
    - `while switching, the other rows do not react to taps` (tap Chỉnh sửa hồ sơ during loading → no navigation).
  - `settings_test.dart` (update/add):
    - `appearance is a SegmentedTabs Tối / Sáng / Theo hệ thống and applies at once` (replaces the three `theme-*` ListTile tests).
    - `button style is a SegmentedTabs; avatar is disabled with the hint until there is an avatar`.
    - `groups appear in the mock order: Tài khoản, Chế độ, Giao diện, Kiểu nút chính, Thông báo` (vertical order of the section labels) `and Đăng xuất is last`.
    - `photographer rows in order: Kỹ năng, Hình thức nhận việc, Giải thưởng, Xem hồ sơ công khai` (flags off).
    - `a studio has "Địa chỉ studio" showing its district; it opens /setup/4?from=settings`; `an individual has no address row`; `a studio without district reads "Chưa có địa chỉ"`.
    - `flagged rows are hidden while their routes do not exist` (no `settings-verify`, `settings-my-studio`, `settings-studio-members`).
    - `with the flags on they open their routes` (override flags true; individual → `settings-my-studio` → `/me/studio`; studio → `settings-studio-members` → `/studio/members`; both → `settings-verify` → `/verify/start`; router stubs).
    - `staff see "Quản lý sự kiện" opening /events/mine; others do not` (existing test, keep).
    - `sign-out asks first and the confirm button is red` (existing, keep).
    - `fits 320dp at 1.3x text` for a studio photographer with all flags on.
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/features/settings/` — fails.
- [ ] **Step 3: Implement** per Contract. `RoleModeCard`:
  ```dart
  ref.listen(roleSwitchControllerProvider, (prev, next) async {
    if (next.isLoading || !(prev?.isLoading ?? false)) return; // only a finished switch the user started
    final messenger = ScaffoldMessenger.of(context);
    if (next.hasError) { messenger..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(l.profileSwitchError))); return; }
    final role = next.value;
    messenger..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(role == UserRole.photographer ? l.profileSwitchedToPhotographer : l.profileSwitchedToCustomer)));
    if (role == UserRole.photographer && await _setupUnfinished(ref)) { if (context.mounted) context.go('/setup'); return; }
    if (context.mounted) context.go(AppTab.profile.path);
  });
  ```
  (`_setupUnfinished` = the old `_openSetupIfUnfinished` read: `photographerIntroRepositoryProvider.get(uid)`, offline → false.) Build the screen from `_SectionLabel` + `GlassCard` groups as today; replace the theme and button-style `ListTile`s with `SegmentedTabs`; add the rows with keys from the Contract. arb keys + `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter test --no-pub --timeout 60s test/features/settings/`, `… test/features/shell/`, `flutter analyze`; green.
- [ ] **Step 5: Commit** `feat(settings): S09.02 per mock with mode card, segmented appearance and flagged rows [#148]`.

### Task 4: S09.01 own-posts grid

**Files:**
- Create: `app_flutter/lib/features/profile/profile_tab.dart`, `app_flutter/lib/features/profile/my_posts_controller.dart`, `app_flutter/test/features/profile/profile_tab_test.dart`, `app_flutter/test/features/profile/my_posts_controller_test.dart`
- Modify: `app_flutter/lib/features/shell/placeholder_tabs.dart` (remove `ProfileTab` and its private rows; keep `ActionTab`, `BookingsTab`), `app_flutter/lib/app/router.dart` (import), `app_flutter/lib/l10n/app_vi.arb`, `app_flutter/test/features/shell/placeholder_tabs_test.dart` (move the remaining S09.01 tests to the new file)

**Interfaces:**
- Consumes: `PostRepository.byAuthor/countByAuthor` (Task 2), `postRepositoryProvider`, `currentProfileProvider`, `myIntroProvider`, `badgeChipsProvider`, `unreadCountProvider`, `latestNotificationProvider`, `AwardNudgeRow`, `locationControllerProvider` (area name, Decision 4), `savedListsReadyProvider`.
- Produces: `myPostsProvider`, `myPostCountsProvider`, `MyPostsController`, `ProfileTab` (Contract).

**Mock parity:** `#S09.01` (customer) and `#S09.01-photographer`: bar "Hồ sơ" + gear; row avatar · name · "{role} · {area}"; Thông báo card with unread pill; counts row ("9 bài đăng"; following/saved hidden); badges row with "Tất cả"; (photographer: setup card, Album của tôi, Thu nhập, award nudge); chips "Tất cả · n" + present kinds; 3-column square grid, "Sự kiện"/"Buổi chụp" tags on "Tất cả"; no primary button; tab bar unchanged.

**Backend wiring:** `FirestorePostRepository.byAuthor` (Firestore `posts` where `authorId == uid` [and `kind`], ordered `createdAt desc, __name__ desc`, indexes from Task 2) and `countByAuthor` (`count()` aggregation); rules `match /posts/{postId}` read for signed-in users. Taps open `/p/:postId` (S02.02, existing `PhotoDetailScreen`).

- [ ] **Step 1: Failing tests.**
  - `my_posts_controller_test.dart` (fake repo): `first build loads one page of 20 for the filter`; `loadMore appends the next page and clears the cursor at the end`; `load more runs once per page` (two `loadMore` calls before the first resolves → one repo call); `a failed next page keeps the posts and sets moreError`; `refresh reloads from the first page`.
  - `profile_tab_test.dart` (`ProviderScope` with `FakePostRepository`, fake auth/profile as the old placeholder tests do; `GoRouter` stubs for `/p/:postId`, `/settings`, `/action`, `/me/albums`, `/work/earnings`, `/u/:uid/badges`, `/notifications`):
    - `header is a row: avatar left, name and "Khách hàng · Quận 3" right` (area set in a fake location state; without area: just "Khách hàng").
    - `shows the user's own posts in three columns, newest first` (6 posts → 6 tiles keyed `profile-post-<id>`; first tile is the newest).
    - `chips show only kinds the user has, with counts` ("Tất cả · 6", "Tác phẩm · 3", "Buổi chụp · 1", "Sự kiện · 2"); `one kind only hides the chip row`.
    - `choosing "Sự kiện" shows only event shares; tags hide on a single kind` and `on "Tất cả" event shares carry the tag "Sự kiện" and real shoots "Buổi chụp"; work has none`.
    - `the posts count shows the total; following and saved stay hidden` (and appear when `savedListsReadyProvider` is overridden to true, still without links).
    - `a selected kind that disappears falls back to all` (counts refresh to 0 for the chosen kind).
    - `tapping a tile opens /p/<id>`.
    - `a failed next page keeps the grid and offers retry` (`profilePostsMoreError` row; tap → loadMore again).
    - `empty for a photographer: "Chưa có bài đăng" and "Đăng bài đầu tiên" opens /action`; `empty for a customer: "Chưa có ảnh nào" and the explanation, no button`.
    - `no switch-role button and no sign-out button here` (keys `switch-role`, `sign-out` absent; already true after Task 3, pinned here).
    - moved tests (unchanged expectations): Album của tôi / Thu nhập for photographers only, award nudge cases, setup card shows while unfinished and is gone once complete.
    - `fits 320dp at 1.3x text` for customer and photographer (long name "Nguyễn Thị Phương Thảo", area "Thành phố Hồ Chí Minh").
- [ ] **Step 2: Run** `flutter test --no-pub --timeout 60s test/features/profile/` — fails.
- [ ] **Step 3: Implement.** `MyPostsController.loadMore` guards with `loadingMore`; `myPostCountsProvider` runs the four counts with `Future.wait`. The tab is a `CustomScrollView`: `SliverToBoxAdapter`s for header items, `SliverGrid` (`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: AppSpace.s1, crossAxisSpacing: AppSpace.s1)`), a footer sliver for loading-more / retry; trigger `loadMore` from the footer's first build when `nextCursor != null && !moreError`. Tiles: `Semantics(button: true, label: caption first line or profilePostTile(index + 1))`. Move `_BadgesRow`, `_MyAlbumsRow`, `_EarningsRow`, `_LinkRow`, `_NotificationsRow` unchanged into `profile_tab.dart`. Fallback filter: when counts load and the selected kind's count is 0, set the filter to null. arb keys + `flutter gen-l10n`.
- [ ] **Step 4: Run** `flutter test --no-pub --timeout 60s test/features/profile/`, `… test/features/shell/`, `… test/app/` (router compiles), `flutter analyze`; green.
- [ ] **Step 5: Commit** `feat(profile): S09.01 own-posts grid with kind filters [#148]`.

### Task 5: Status table, notes for #135/#136/S19 and ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S09.01 "✅ làm lại theo mock (#148) · lưới bài đăng, chip theo loại"; S09.02 "✅ khớp mock (#148) · dòng xác minh/studio ẩn tới #135/#136"), `docs/superpowers/specs/2026-10-06-identity-verification-design.md` (one line under S09.02: "dòng có sẵn, bật `verifyStartReadyProvider` khi có `/verify/start`"), `docs/superpowers/specs/2026-10-06-studio-members-design.md` (same for `studioRoutesReadyProvider`)
- Create: `docs/superpowers/handover/ledger-s09-profile-settings.md`

- [ ] **Step 1:** Edit the status cells and the two spec lines.
- [ ] **Step 2:** Ledger: Decisions 1–11 (one line each, cost if wrong), the owner question with its default, the three flags and who flips them, "indexes added (deployed by CI with the rules job); no rules or functions changed; no emulator suite skipped".
- [ ] **Step 3: Commit** `docs(spec): S09 status, ready flags for #135/#136/S19, ledger [#148]`.

## Deferred

- "đang theo dõi" / "đã lưu" counts and their lists: S19 (no mock yet); the tiles appear when `savedListsReadyProvider` is flipped.
- S21.02 "Xác minh & nhận đơn" screen and its status subtitle ("Còn {n} bước"): #135 flips `verifyStartReadyProvider`.
- S26.01/S26.03 studio screens: #136 flips `studioRoutesReadyProvider`.
- Thumbnails for grid tiles (egress): a follow-up of #147 (upload-time thumbnail purpose).
- Deleting a post from S02.02 (spec acceptance "xoá một bài ở S02.02 thì bài biến khỏi lưới"): no delete flow exists yet; when it lands, counts must exclude soft-deleted posts (`count()` cannot filter on a missing field; it will need a `deleted: false` field or a server counter).
- Privacy group (saved location, clear area) and "Trợ giúp & điều khoản": S22 / S18 plans.

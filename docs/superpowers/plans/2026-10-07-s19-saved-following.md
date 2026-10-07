# S19 · Lưu & theo dõi (S19.01–S19.03) Implementation Plan

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules` and `firestore.indexes.json` and adds a Firestore trigger. Write the rules tests and the Functions integration test; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** Everyone finds again what they saved (posts, and photographers they bookmarked on S03.01) on S19.01, manages who they follow on S19.02 (unfollow with undo), and a photographer sees who follows them on S19.03; S09.01 shows the counts and opens these lists; posts of followed photographers come first in the home feed; the public follower count is written by the server.

**Architecture:** The markers already exist and are written by the client under the marker rules: `saves/{uid}_{postId}`, `follows/{uid}_{photographerId}` (`FirestoreEngagementRepository`). This plan adds one marker collection `savedPhotographers/{uid}_{photographerId}` (same rules shape), list rules and indexes for the three lists, and a server-written public counter `photographers/{uid}.followerCount` kept by a new trigger `onFollowWrite` that **recounts** with a Firestore `count()` aggregation and writes only when its event is newer than the stored count (idempotent, self-healing; the pure decision lives in `packages/domain/src/counters.ts`, shared with #132's `likeCount`/`saveCount`). Lists are cursor pages (`get`, 20–30 markers, then the targets by id in chunks of 30). The app gets a `SavedFollowRepository` (Firestore adapter + fake), feature folder `features/saved/` (S19.01–S19.03), a bookmark on S03.01, the S09.01 counts row and a follow boost in `LocalRecommender.recommendPosts`.

**Tech Stack:** TypeScript (domain helper, Functions v2 `onDocumentWritten`, Admin SDK `count()`), Firestore rules and indexes; Flutter, Riverpod 3, go_router, `cloud_firestore` aggregate queries, existing core widgets (`SegmentedTabs`, `PhotographerCard`, `PhotoCard`/grid tiles, `AppAvatar`, `EmptyState`, `AsyncView`, `AppSkeleton`).

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S19 rows), §3i.2 (S19), §3e.7 (signals); mock `docs/design/ui-mock.html` `#S09.01` (counts row "bài đăng · đang theo dõi · đã lưu"), `#S03.01` (follow button), `#S02.06` (PhotographerCard), frames added by Task 1; `docs/superpowers/specs/data-model/domain-model.md` (`Like`, `Save`, `Follow`), `relational-schema.md` (`saves`, `follows`; mapping row "Khoá ghép"); `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` §13.3 (paginate, `get`, no counting by reads).

**Issue:** #143. **Blocked by:** none hard; soft: #148 (Task 6 wires its counts row), #132 (shared counter helper). **Branch:** `plan/143-s19-saved-following`, PR into `develop` titled `feat(saved): S19 saved, following and followers [#143]`.

**Coordination:** #132 (S02, `docs/superpowers/plans/2026-10-07-s02-discover.md`) writes `posts.likeCount` / `saveCount` as recounts (`EngagementStore.recount(kind, postId)` in `packages/domain/src/discovery_ports.ts`, adapter `infra/discovery_firestore.ts`, trigger `triggers/engagement_write.ts`). Same principle here (a `count()` recount, never `+1/-1`). If #132 has landed when Task 2 starts, put the follower trigger beside its engagement trigger (`triggers/engagement_write.ts` gains `handleFollowWrite`; the adapter goes in `infra/discovery_firestore.ts`) and keep this plan's `counterPatch` event-time guard (it protects against reordered events, which a single-document post recount does not need); otherwise create the files named in this plan. Ledger which. #148 (S09.01/S09.02 rework, `docs/superpowers/plans/2026-10-07-s09-profile-settings.md`) moves `ProfileTab` to `lib/features/profile/profile_tab.dart`, builds the counts row with the "bài đăng" tile and hides the "đang theo dõi" / "đã lưu" tiles behind `savedListsReadyProvider` (`lib/features/settings/settings_links.dart`, default `false`, its Decisions 3 and 7); **this plan flips that flag to `true`** and wires the tiles (Task 6). If #148 has not landed, Task 6 builds its own row in the old `ProfileTab` and #148 later absorbs it (ledger). #144 (S20) blocks: if it landed, these lists drop hidden users (Task 3 Step 4).

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6. The first step of every task re-checks the names it uses; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Firestore markers: `likes|saves|follows/{uid}_{targetId}` `{userId, postId|photographerId, createdAt}`; rules `markerId`, `ownMarkerName`, `ownMarkerDoc`, `validMarker(docId, targetField)` and the three `match` blocks (`firestore.rules:286-310, 586-604`); list rule today: `resource.data.userId == request.auth.uid` only. `photographerServerFieldsUntouched()` (`firestore.rules:172`, list ends with `'acceptingOrders'`). Indexes: none on `saves`, `follows`.
- Domain: no counter helper (`packages/domain/src`); `review_stats.ts` is the closest pattern for derived numbers. Functions: no trigger on `follows`/`saves`/`likes` (audit: "không ai ghi `likeCount`/`saveCount`"); `TRIGGER_OPTIONS` (`config.ts`), `db()` (`infra/admin.ts`), trigger export style `onDocumentWritten({ ...TRIGGER_OPTIONS, document: '…' }, …)` (`index.ts:135`); seed `seed/fixtures.ts`, `seed/README.md`, `test/unit/seed_fixtures.test.ts`.
- App data: `PostEngagementRepository` (`engagementFor`, `savedAmong`, `setLiked`, `setSaved`, `isFollowing`, `setFollowing`) in `lib/data/content/content_repositories.dart:53`, `FirestoreEngagementRepository` (`firestore_post_repository.dart:236`), `FakePostEngagementRepository` (`lib/data/content/fake_content_repositories.dart:124`); `PostRepository.byId` (no `byIds`), `FirestorePostRepository`, `FakePostRepository`; `PhotographerRepository.summaries(ids)` (chunks of 30), `PhotographerSummary` (`acceptingOrders`, `verified`, `providerType`); `postEngagementRepositoryProvider`, `photographerRepositoryProvider`, `postRepositoryProvider` (`content_providers.dart`); `UserRepository.watch(uid)` (no batch read); `PostRecommendationQuery {specialtyId, geohash6, limit, cursor}`, `LocalRecommender.recommendPosts` (`local_recommender.dart:396`), `ReasonCode` (`lib/data/content/reason.dart`; no `following`).
- App features: `EngagementController` / `engagementProvider`, `FollowController` / `followProvider` (`features/discovery/engagement_controller.dart`; optimistic toggles, `resetOnUserChange`); S03.01 `PhotographerProfileScreen._loaded` AppBar (leading back only, `photographer_profile_screen.dart:~115`), `ProfileHeader` + `_FollowButton` (`widgets/profile_header.dart:307`); S02.02 save/follow (`features/photo/photo_detail_screen.dart`); `ProfileTab` (`features/shell/placeholder_tabs.dart:112`; `_NotificationsRow`, `_BadgesRow`); `HomeController` (`features/home/home_controller.dart:65,163` build the query); `startBooking` (`features/discovery/book_entry.dart`); `lib/app/router.dart` (`/me/albums`, `/me/awards` pattern).
- Core: `ScreenCodes.saved` (S19.01), `following` (S19.02), `followers` (S19.03) exist (`lib/core/screen_codes.dart:106-108`); `PhotographerCard({data, reasons, distanceKm, availabilityLabel, required onProfile, onBook, bookLabel})` (no save control); `SegmentedTabs`/`SegmentOption`; `AppIcons.save` (bookmark), `AppIcon(selected:)`; `EmptyState`, `AsyncView`, `AppAvatar`, `VerifiedMark`/`providerMarkOf`.

## Global Constraints

- Spec §3i.2, verbatim: "lưu bài và lưu nhiếp ảnh gia là hai danh sách riêng; theo dõi chỉ áp dụng cho nhiếp ảnh gia; bài mới của người mình theo dõi ưu tiên trong feed "Dành cho bạn"; danh sách người theo dõi chỉ chủ hồ sơ xem; số đếm công khai."
- Spec §3i.2: "S09.01 có hàng số "đang theo dõi · đã lưu" đang ẩn vì chưa có danh sách; nút lưu ở S02.02 và tín hiệu "đã lưu" của gợi ý (mục 3e.7) cần nơi xem lại."
- Rules: counters are server-only ("Rules cấm client ghi `stats.*`"); `followerCount` joins `photographerServerFieldsUntouched()`.
- Cost spec §13.3: lists use `get` with a cursor of 20–30 documents, `limit()` on every query, no counting by reading documents (aggregate `count()` or a server counter).
- CLAUDE.md: rules in `packages/domain` (no Firebase/Node imports); Functions thin, region `asia-southeast1`; Firebase only in `lib/data/**`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons`; `package:photobooking/...` imports, features import `core/core.dart`; one `AppButton.primary` per screen (the small "Đặt lịch" on each `PhotographerCard` is the allowed list-card exception); every screen in `ScreenCode`; `AsyncView` for every `AsyncValue`.
- Ids/time (`data-model/README.md`): marker ids `{uid}_{targetId}`; UTC `Timestamp`s; integer counts.
- Commits: Conventional Commits, subject ends with `[#143]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time; bounded pumps; domain `cd packages/domain && npm test && npm run lint`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; rules-test and Functions integration suites are written, not run.

## Decisions (where the spec is silent)

1. **Where a photographer is saved.** A bookmark button in the S03.01 app bar (visitors only, overlay circle like the back button, `AppIcons.save`, filled when saved), plus the bookmark on each card of S19.01's "Nhiếp ảnh gia" tab to remove it. No bookmark on S02.06 cards (not in any mock).
2. **Storage of saved photographers.** New client-written marker `savedPhotographers/{uid}_{photographerId}` `{userId, photographerId, createdAt}`, exactly the `saves` rules with target field `photographerId`. No public count for it (spec makes only follower counts public).
3. **Follower count.** `photographers/{pid}.followerCount` (int) + `followerCountAt` (timestamp), server-only. Trigger `onFollowWrite` on `follows/{docId}` (create or delete): recount `follows where photographerId == pid` with `count()`, then in a transaction write the count only when `event.time` is newer than `followerCountAt` (`counterPatch`). A duplicated or reordered event never leaves a stale number for long: the newest event's recount runs after its own write. Missing photographer document → no write. A follow marker updated in place (same target) is ignored.
4. **Own counts on S09.01.** Aggregation `count()` queries on `follows`/`saves`/`savedPhotographers where userId == uid` (1 read each per ≤ 1000 entries), fetched once per session and refreshed after a toggle in this app run; "đã lưu" = saved posts + saved photographers. Photographers also see "người theo dõi" from their own `followerCount`.
5. **List order and paging.** Newest marker first (`createdAt desc`, then document id desc). S19.01 posts 30 per page, photographer lists 20, followers 30. Cursor = `"{createdAtMicros}_{docId}"` of the last marker. A target that no longer exists (deleted post, unpublished or closed photographer profile, deleted user) is skipped; when a whole page is skipped and a cursor remains, the controller loads up to 3 more pages (look-ahead, ledger-3b1 rule).
6. **Unfollow on S19.02.** Instant toggle (no confirm sheet): the row's outline button turns "Đang theo dõi" ↔ "Theo dõi" and a SnackBar "Đã bỏ theo dõi {name}" offers "Hoàn tác" (re-follow). The row stays until the screen is reopened, so an accidental tap is visible and undoable. Same on the S19.01 photographer bookmark ("Đã bỏ lưu {name}" + "Hoàn tác").
7. **Followers list (S19.03).** Only the photographer (`/me/followers`, own uid; route refuses other roles by redirect to `/profile`). Rule: `follows` list allowed when `resource.data.photographerId == request.auth.uid` as well. Rows show avatar, display name and "Theo dõi từ {d/M}", not tappable (customers have no public profile page). Names come from `users/{uid}` read in chunks of 30 by id (`whereIn` on `FieldPath.documentId`).
8. **Feed boost.** `PostRecommendationQuery.followedIds` (set of photographer ids, up to 100, from the user's newest follows, cached per app run). `LocalRecommender.recommendPosts` puts posts of followed authors created in the last 7 days first within the page (before the "free soon" boost), with reason `ReasonCode.following` "Bạn đang theo dõi". The remote recommender contract gets a description note only (Deferred).
9. **Routes.** `/me/saved` (`?tab=photographers` opens the second tab), `/me/following`, `/me/followers`, outside the tab shell, like `/me/albums`.
10. **Mock changes.** S03.01 gains the bookmark left of the share icon (mock) in the main frame; the caption says every S03.01 variant has it for visitors. S09.01 caption names the destinations of the counts.

## Needs the owner

1. **Should the follower count show on S03.01?** Spec: "số đếm công khai", but no S03.01 mock shows it. Default: shown on S19.03 and on the photographer's own S09.01 only; adding a public stat tile is a one-line follow-up.
2. **Save photographers at all?** The issue asks for a "Nhiếp ảnh gia" tab; default: yes, through the S03.01 bookmark (Decision 1).

## Contract

### Data

- `savedPhotographers/{uid}_{photographerId}`: `{userId, photographerId, createdAt}` (client, marker rules).
- `photographers/{pid}.followerCount: int`, `followerCountAt: Timestamp` (server-only).
- Unchanged: `saves/{uid}_{postId}`, `follows/{uid}_{photographerId}`.

### Domain (`packages/domain/src/counters.ts`)

```ts
export interface StoredCounter { readonly value: number | null; readonly at: string | null }   // ISO
/**
 * The write after a recount: null when a newer recount already landed (stored.at > eventAt)
 * or when both value and freshness are unchanged. Negative or non-integer recounts throw invalid_argument.
 */
export function counterPatch(stored: StoredCounter, recount: number, eventAt: string): { value: number; at: string } | null;
```

### Functions

- `src/triggers/engagement_counters.ts`: `export interface FollowerCounter { recount(photographerId: string): Promise<number>; apply(photographerId: string, eventAt: string, recount: number): Promise<'written' | 'unchanged' | 'stale' | 'missing'> }`; `export async function handleFollowWrite(input: { before?: Record<string, unknown>; after?: Record<string, unknown>; time: string }, counter: FollowerCounter): Promise<'written' | 'unchanged' | 'stale' | 'missing' | 'ignored'>` (`ignored` when before and after name the same photographer, i.e. an in-place update, or neither names one).
- `src/infra/follower_counter.ts`: `FirestoreFollowerCounter implements FollowerCounter` (`recount` = `db.collection('follows').where('photographerId','==',pid).count().get()`; `apply` = transaction reading `photographers/{pid}` and writing `{followerCount, followerCountAt}` via `counterPatch`).
- `index.ts`: `export const onFollowWrite = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'follows/{docId}' }, (event) => handleFollowWrite({...}, new FirestoreFollowerCounter(db())))`.

### Rules and indexes

```
// in match /follows/{docId}
allow list: if signedIn() && (resource.data.userId == request.auth.uid
                              || resource.data.photographerId == request.auth.uid);
match /savedPhotographers/{docId} {
  allow get: if ownMarkerName(docId) && (resource == null || ownMarkerDoc());
  allow list: if signedIn() && resource.data.userId == request.auth.uid;
  allow create, update: if ownMarkerName(docId) && validMarker(docId, 'photographerId');
  allow delete: if ownMarkerName(docId) && ownMarkerDoc();
}
// photographerServerFieldsUntouched(): add 'followerCount', 'followerCountAt'
```
Indexes: `saves (userId ASC, createdAt DESC)`, `follows (userId ASC, createdAt DESC)`, `follows (photographerId ASC, createdAt DESC)`, `savedPhotographers (userId ASC, createdAt DESC)`.

### App (Dart)

```dart
// lib/data/content/saved_follow.dart
@immutable class MarkerPage<T> { const MarkerPage({required this.items, this.cursor}); final List<T> items; final String? cursor; }
@immutable class Follower { const Follower({required this.userId, required this.displayName, this.avatarUrl, required this.since}); }
@immutable class SocialCounts { const SocialCounts({this.following = 0, this.savedPosts = 0, this.savedPhotographers = 0});
  int get saved => savedPosts + savedPhotographers; }

// lib/data/content/saved_follow_repository.dart
abstract class SavedFollowRepository {
  Future<MarkerPage<PostSummary>> savedPosts(String uid, {String? cursor, int limit = 30});
  Future<MarkerPage<PhotographerSummary>> savedPhotographers(String uid, {String? cursor, int limit = 20});
  Future<MarkerPage<PhotographerSummary>> following(String uid, {String? cursor, int limit = 20});
  Future<MarkerPage<Follower>> followers(String photographerId, {String? cursor, int limit = 30});
  Future<bool> isPhotographerSaved(String uid, String photographerId);
  Future<void> setPhotographerSaved(String uid, String photographerId, bool saved);
  Future<Set<String>> followingIds(String uid, {int limit = 100});
  Future<SocialCounts> counts(String uid);
  Future<int?> followerCount(String photographerId);         // photographers/{id}.followerCount, null when absent
}
// firestore_saved_follow_repository.dart: FirestoreSavedFollowRepository({FirebaseFirestore? db,
//   required PostRepository posts, required PhotographerRepository photographers})
// fake: FakeSavedFollowRepository in lib/data/content/fake_content_repositories.dart (beside the other fakes)
// PostRepository gains: Future<Map<String, PostSummary>> byIds(Iterable<String> ids);   // chunks of 30, missing ids absent

// lib/data/content/saved_follow_providers.dart
final savedFollowRepositoryProvider = Provider<SavedFollowRepository>(...);
final socialCountsProvider = FutureProvider<SocialCounts>(...);            // keyed on the signed-in uid; invalidated by toggles
final followingIdsProvider = FutureProvider<Set<String>>(...);             // same
final myFollowerCountProvider = FutureProvider<int?>(...);                 // photographers only

// lib/features/discovery/engagement_controller.dart
// FollowController.toggle and EngagementController.toggleSave invalidate socialCountsProvider / followingIdsProvider on success.
class SavedPhotographerController extends Notifier<Map<String, bool>> { Future<void> load(String id); Future<bool> toggle(String id); }
final savedPhotographerProvider = NotifierProvider<SavedPhotographerController, Map<String, bool>>(...);

// lib/core/widgets/photographer_card.dart gains: final bool? saved; final VoidCallback? onToggleSave;
//   (bookmark overlay on the hero's top-right when onToggleSave != null; semantics "Bỏ lưu {name}" / "Lưu {name}")

// lib/data/recommendation/recommendation_models.dart: PostRecommendationQuery gains `this.followedIds = const {}`
// lib/data/content/reason.dart: ReasonCode gains following('following')
```

Routes: `/me/saved` → `SavedScreen(initialTab:)` (`ScreenCodes.saved`), `/me/following` → `FollowingScreen` (`ScreenCodes.following`), `/me/followers` → `FollowersScreen` (`ScreenCodes.followers`).

### Strings (`app_vi.arb`, exact)

`savedTitle` "Đã lưu"; `savedTabPosts` "Bài · {count}"; `savedTabPhotographers` "Nhiếp ảnh gia · {count}"; `savedPostsEmptyTitle` "Chưa lưu bài nào"; `savedPostsEmptyBody` "Bấm biểu tượng lưu trên ảnh để xem lại ở đây."; `savedPhotographersEmptyTitle` "Chưa lưu nhiếp ảnh gia nào"; `savedPhotographersEmptyBody` "Bấm biểu tượng lưu trên hồ sơ nhiếp ảnh gia để so sánh và đặt lịch sau."; `savedUnsaved` "Đã bỏ lưu {name}"; `savedUndo` "Hoàn tác"; `savedBook` "Đặt lịch"; `savedToggleOn` "Lưu {name}"; `savedToggleOff` "Bỏ lưu {name}"; `followingTitle` "Đang theo dõi"; `followingCount` "{count} nhiếp ảnh gia"; `followingButton` "Đang theo dõi"; `followButton` "Theo dõi"; `followingUnfollowed` "Đã bỏ theo dõi {name}"; `followingEmptyTitle` "Bạn chưa theo dõi ai"; `followingEmptyBody` "Theo dõi nhiếp ảnh gia để thấy bài mới của họ trước."; `followingEmptyAction` "Khám phá"; `followersTitle` "Người theo dõi"; `followersCount` "{count} người theo dõi · chỉ bạn xem được danh sách này"; `followersSince` "Theo dõi từ {date}"; `followersEmptyTitle` "Chưa có người theo dõi"; `followersEmptyBody` "Đăng bài thường xuyên để có thêm người theo dõi."; `profileCountFollowing` "đang theo dõi"; `profileCountSaved` "đã lưu"; `profileCountFollowers` "người theo dõi"; `profileSavePhotographer` "Lưu nhiếp ảnh gia"; `profileUnsavePhotographer` "Bỏ lưu nhiếp ảnh gia"; `reasonFollowing` "Bạn đang theo dõi"; `socialToggleFailed` "Chưa lưu được. Thử lại."

## Review Focus

1. **Follower count drift.** Two follows at once, a retried event and an unfollow arriving before an older follow event must all end at the true count. Pinned by Task 2 tests `a stale event does not overwrite a newer recount` and `a retried event writes nothing new`.
2. **Who can list follows.** A user lists their own follows and their own followers, never someone else's; nobody writes `followerCount`; a `savedPhotographers` marker under another uid is refused. Pinned by Task 2 rules tests.
3. **Holes in lists.** Saved posts that were deleted and photographers that were unpublished are skipped without an empty first page or a crash. Pinned by Task 3 `a page whose targets are all gone loads the next page`.
4. **Undo and double taps.** Unfollow, undo, unfollow again quickly ends in the state of the last tap, and the S09.01 count follows. Pinned by Task 5 `unfollow then Hoàn tác re-follows once` and `two quick taps end unfollowed`.
5. **Feed boost leaks old posts.** Only posts of the last 7 days by followed authors move up; unknown authors and old posts keep their order. Pinned by Task 6 `followed authors' posts of the last 7 days come first with "Bạn đang theo dõi"`.

## Chi phí Google

Unit prices (cost spec): Firestore $0.06/100K reads, $0.18/100K writes (nam5 upper bound, **chưa xác nhận** for Singapore); Functions free to 2M invocations then $0.40/M; Tier 2 $0.0000336/vCPU-s (180K free); aggregation `count()` = 1 read per up to 1,000 index entries. Assumptions: S09.01 opened in 10 sessions/MAU/month; S19.01 posts tab 2 opens, photographers tab 1, S19.02 1, S19.03 2 opens per photographer (10% of MAU); 3 follow/unfollow toggles per MAU/month; average 10 follows per user.

| Action | Reads | Writes | Notes |
|---|---|---|---|
| Open S09.01 (counts) | 3 aggregations ≈ 3 | 0 | once per session, cached; photographers +0 (own photographer doc already read) |
| Open S19.01 posts page | 30 markers + ≤ 30 posts = 60 | 0 | `get`, cursor, chunks of 30 |
| Open S19.01 photographers / S19.02 page | 20 markers + ~40 summaries = 60 | 0 | `summaries` reads photographers + users |
| Open S19.03 page | 30 markers + 30 users = 60 | 0 | photographers only |
| Follow / unfollow | 1 (state already loaded) | 1 marker | + trigger: 1 aggregation + 1 photographer read, 1 write |
| Save photographer | 0 | 1 | no trigger |
| Feed boost | ≤ 100 (avg 10) per app run | 0 | `followingIds`, cached for the run |

New functions: 1 trigger (`onFollowWrite`), 256 MiB, ~0.1 s; calls/month = follow toggles: (b) 3,000, (c) 30,000 — inside the free 2M. No callable, no scheduled job, no Storage path, no paid API.

Reads/month: (b) S09.01 30K + S19.01 120K + photographers tab 60K + S19.02 60K + S19.03 12K + feed boost 200K + triggers 6K ≈ 490K → **$0.29**; writes ≈ 10K → $0.02. (c) ≈ 4.9M reads → **$2.94**; writes ≈ 100K → $0.18.

**Conclusion:** adds about **$0.31/month at (b)** and **$3.1/month at (c)**, under $5. Biggest item is the feed boost; if it grows, store the newest 100 followed ids in `users/{uid}/private/following` (1 read per run) — noted in Deferred.

## Tasks

### Task 1: Mock frames, mock edits, screen codes and screen spec

**Files:**
- Modify: `docs/design/ui-mock.html` (new section `<h2 id="S19">` placed before `<h2 id="S24">`, after the S18 section if present, else after S17; S03.01 main frame; S09.01 caption; code table; progress table), `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S19 rows, §3i.2 paragraph), `docs/superpowers/specs/screens/README.md`
- Create: `docs/superpowers/specs/screens/saved-following.md`
- Check only: `app_flutter/lib/core/screen_codes.dart` (S19.01–S19.03 exist)

**Interfaces:** Produces frame ids `S19.01`, `S19.01-photographers`, `S19.02`, `S19.03`.

- [ ] **Step 1:** Section head, verbatim:
  ```html
  <h2 id="S19">S19 · Lưu & theo dõi</h2>
  <p>Xem lại bài và nhiếp ảnh gia đã lưu, quản lý người mình theo dõi; nhiếp ảnh gia xem ai theo dõi mình. Mở từ hàng số ở <a href="#S09.01" style="color:var(--accent)">S09.01</a>.</p>
  <div class="rail">
  ```
  Every frame starts with `<div class="sb"><span>9:41</span><span>●●● ▮</span></div>` and `.bar` = back icon (`role="button" tabindex="0" aria-label="Quay lại"`), title (`style="font-size:17px"`), `<div class="ic" style="opacity:0"></div>`.
- [ ] **Step 2: `S19.01`**: title "Đã lưu"; `<div class="seg"><span class="on">Bài · 12</span><span>Nhiếp ảnh gia · 3</span></div>`; `.grid3` with nine `ph` tiles (`p3 p1 p6 p2 p4 p5 p1 p3 p2`, each `role="img" aria-label="Bài đã lưu {n}"`). Cap: `<span class="n new">Mới</span><span class="n">S19.01 · Đã lưu</span><b>Hai danh sách riêng: bài và người</b><span><code>/me/saved</code>, mở từ "đã lưu" ở S09.01. Tab Bài: lưới 3 cột, bài lưu mới nhất trước, chạm → S02.02; bỏ lưu ở S02.02. Bài đã bị xoá tự biến mất. Trống: "Chưa lưu bài nào" / "Bấm biểu tượng lưu trên ảnh để xem lại ở đây."</span>`
- [ ] **Step 3: `S19.01-photographers`** (`data-code="S19.01"`): same bar and seg with the second segment `on`; two cards copied from `#S02.06` (Minh Trí, Hồng Nhung) with these changes: inside each hero `ph` add `<div class="ic dk" style="position:absolute;top:8px;right:8px" role="button" tabindex="0" aria-label="Bỏ lưu Minh Trí"><span class="ms">bookmark</span></div>` (and "Bỏ lưu Hồng Nhung"); the pill reads "Rảnh 12/10" / "Còn buổi chiều" as in S02.06; the first card's buttons are `btn out sm` "Hồ sơ" and `btn pri sm` "Đặt lịch"; the second card has its buttons row too. Cap: `<span class="n new">Mới</span><span class="n">S19.01 · Nhiếp ảnh gia đã lưu</span><b>So sánh rồi đặt</b><span>Thẻ nhiếp ảnh gia như S02.06, thêm nút lưu ở góc ảnh để bỏ lưu (thanh báo "Đã bỏ lưu {tên}" có "Hoàn tác"). Lưu nhiếp ảnh gia bằng nút lưu ở S03.01. Thợ chưa nhận đơn không có nút "Đặt lịch". Trống: "Chưa lưu nhiếp ảnh gia nào".</span>`
- [ ] **Step 4: `S19.02`**: title "Đang theo dõi"; meta "4 nhiếp ảnh gia"; `<div class="card" style="flex-direction:column;align-items:stretch;padding:4px 12px;gap:0">` with four `.irow2` rows: `<span class="av m"></span><div class="grow"><b>Minh Trí <span class="vf" role="img" aria-label="Đã xác minh"><span class="ms">check</span></span></b><span class="meta">Chân dung · Quận 3</span></div><div class="btn out xs">Đang theo dõi</div>`; Hồng Nhung ("Cưới · Quận 7", `--p2`), Quốc Bảo ("Gia đình · Thủ Đức", `--p4`, button `btn out xs` "Theo dõi"), Thu Hà ("Kỷ yếu · Quận 1", `--p6`); then `<div class="toast" style="margin-top:auto"><span class="grow">Đã bỏ theo dõi Quốc Bảo</span><span class="tlink" style="padding:0">Hoàn tác</span></div>`. Cap: `<span class="n new">Mới</span><span class="n">S19.02 · Đang theo dõi</span><b>Bỏ theo dõi một chạm, hoàn tác được</b><span><code>/me/following</code>. Mới theo dõi trước. Chạm hàng → S03.01. "Đang theo dõi" → bỏ theo dõi ngay, hàng ở lại với nút "Theo dõi" và thanh "Hoàn tác". Bài mới của người bạn theo dõi lên trước ở Trang chủ. Trống: "Bạn chưa theo dõi ai" + "Khám phá".</span>`
- [ ] **Step 5: `S19.03`**: title "Người theo dõi"; meta "128 người theo dõi · chỉ bạn xem được danh sách này"; card with five `.irow2` rows (avatar m, `<b>Lan Anh</b><span class="meta">Theo dõi từ 12/10</span>`; Minh Khoa 11/10 `--p2`; Thảo Vy 09/10 `--p5`; Quang Huy 02/10 `--p4`; Thu Hà 28/9 `--p6`), no buttons. Cap: `<span class="n new">Mới</span><span class="n">S19.03 · Người theo dõi</span><b>Chỉ chủ hồ sơ thấy danh sách</b><span><code>/me/followers</code>, mở từ "người theo dõi" ở S09.01 của nhiếp ảnh gia. Số người theo dõi là công khai, danh sách thì không. Hàng không bấm được (khách không có trang hồ sơ công khai).</span>`
- [ ] **Step 6:** `#S03.01` main frame: inside the hero `ph p1` add `<div style="position:absolute;top:30px;right:54px" class="ic dk" role="button" tabindex="0" aria-label="Lưu nhiếp ảnh gia"><span class="ms">bookmark</span></div>`; append to its caption: "Nút lưu (khách xem hồ sơ, mọi biến thể S03.01) cho vào danh sách Nhiếp ảnh gia ở S19.01." `#S09.01` caption: append "Chạm "đang theo dõi" → S19.02, "đã lưu" → S19.01; nhiếp ảnh gia có thêm "người theo dõi" → S19.03." Code table: S19.01–S19.03 "Chưa có mock" → "Có". Progress table: `<tr><td>Lưu & theo dõi</td><td>S19.01–S19.03, nút lưu ở S03.01, hàng số ở S09.01</td><td>Có mock, có plan (#143)</td></tr>`. The code-table line is also edited by #142/#144: on a rebase conflict re-apply only the S19 cells.
- [ ] **Step 7:** Spec §2: S19 status cells "⬜ có mock, có plan (#143)"; §3i.2 one paragraph "Đã chốt khi viết plan #143" (Decisions 1, 3, 6, 8). Create `screens/saved-following.md` (README template, S19.01–S19.03, strings of the Contract) and its index row.
- [ ] **Step 8:** Parse check as in other mock tasks (`python3 -c "import html.parser; html.parser.HTMLParser().feed(open('docs/design/ui-mock.html').read())"`; balanced `div`s in the new section).
- [ ] **Step 9: Commit** `docs(mock): S19 saved and following frames, S03.01 save button [#143]`.

### Task 2: Backend — follower counter, saved-photographer marker, rules, indexes, seed

**Files:**
- Create: `packages/domain/src/counters.ts`, `packages/domain/test/counters.test.ts`; `app_flutter/firebase/functions/src/triggers/engagement_counters.ts`, `src/infra/follower_counter.ts`, `test/unit/engagement_counters.test.ts`; integration `test/integration/follower_count.test.ts` (written, not run)
- Modify: `packages/domain/src/index.ts`; `functions/src/index.ts`; `seed/fixtures.ts`, `seed/README.md`, `test/unit/seed_fixtures.test.ts`; `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`

**Interfaces:** Produces `counterPatch`, `handleFollowWrite`, `FollowerCounter`, `FirestoreFollowerCounter`, `onFollowWrite`, the rules and indexes of the Contract.

- [ ] **Step 1:** Contract check: rules lines, `TRIGGER_OPTIONS`, and whether #132 already added a counter helper or `engagement_counters.ts`; if so extend those instead of creating them (ledger it).
- [ ] **Step 2: Failing tests.** `counters.test.ts`: `writes the recount when nothing is stored`; `writes when the event is newer`; `a stale event does not overwrite a newer recount` (stored.at later → null); `same value and same time → null`; `same value, newer time → writes (freshness)`; `negative or fractional recount → invalid_argument`. `engagement_counters.test.ts` (fake counter): `a created follow recounts its photographer and applies with the event time`; `a deleted follow recounts from before`; `an in-place update of the same marker is ignored`; `a retried event writes nothing new` (`apply` returns unchanged); `a missing photographer document returns missing`. `seed_fixtures.test.ts`: `seed follows give An followerCount 2 and Dũng 1, equal to the follows`; `Lan has saved posts seed-post-an-1, -2 and saved photographer Cúc`.
  Rules tests (written, not run): `a user lists their own follows`; `a photographer lists follows of themselves`; `a user cannot list follows of another photographer`; `owner creates and deletes a savedPhotographers marker`; `a marker under another uid is refused`; `a marker with an extra field is refused`; `a photographer cannot write followerCount or followerCountAt on create or update`; `an unchanged followerCount passes a bio update`.
  Integration (written, not run): `two follows and one unfollow leave followerCount 1`.
- [ ] **Step 3:** Run domain and functions unit tests; the new ones fail.
- [ ] **Step 4: Implement.** The apply transaction:
  ```ts
  async apply(pid: string, eventAt: string, recount: number) {
    return this.db.runTransaction(async (tx) => {
      const ref = this.db.collection('photographers').doc(pid);
      const snap = await tx.get(ref);
      if (!snap.exists) return 'missing' as const;
      const d = snap.data() ?? {};
      const stored = { value: typeof d.followerCount === 'number' ? d.followerCount : null,
                       at: d.followerCountAt instanceof Timestamp ? d.followerCountAt.toDate().toISOString() : null };
      const patch = counterPatch(stored, recount, eventAt);
      if (patch === null) return stored.at !== null && stored.at > eventAt ? 'stale' as const : 'unchanged' as const;
      tx.update(ref, { followerCount: patch.value, followerCountAt: Timestamp.fromDate(new Date(patch.at)) });
      return 'written' as const;
    });
  }
  ```
  The recount runs before the transaction (aggregations are not needed inside it: the event-time guard decides). Wire `onFollowWrite` in `index.ts` with `event.time`. Rules + indexes per Contract. Seed: follows Lan→An, Minh→An, Lan→Dũng; saves Lan→`seed-post-an-1`, `seed-post-an-2`; `savedPhotographers` Lan→Cúc; `followerCount` written with the same recount (computed from the seeded follows, not by hand); README table rows.
- [ ] **Step 5:** `cd packages/domain && npm test && npm run lint`; `cd app_flutter/firebase/functions && npm test && npm run build` green. Ledger: rules and integration tests written, not run.
- [ ] **Step 6: Commit** `feat(functions): server follower count, saved-photographer marker, list rules and indexes [#143]`.

### Task 3: App data — saved/follow repository, counts, providers

**Files:**
- Create: `app_flutter/lib/data/content/saved_follow.dart`, `saved_follow_repository.dart`, `firestore_saved_follow_repository.dart`, `saved_follow_providers.dart`; tests `test/data/content/saved_follow_repository_test.dart` (against the fake and the pure cursor/merge helpers), `test/data/content/saved_follow_paging_test.dart`
- Modify: `lib/data/content/content_repositories.dart` (`PostRepository.byIds`), `firestore_post_repository.dart` (`byIds`), `fake_content_repositories.dart` (`FakePostRepository.byIds`, new `FakeSavedFollowRepository`), `test/features/photographer_profile/profile_providers_test.dart` (`_FailingPosts.byIds`), `lib/features/discovery/engagement_controller.dart` (invalidate counts/ids on toggles; `SavedPhotographerController`), its test

**Interfaces:** Produces the Dart contract (`SavedFollowRepository`, `MarkerPage`, `Follower`, `SocialCounts`, providers, `SavedPhotographerController`). Pure helpers exported for tests: `String markerCursor(DateTime createdAt, String docId)`, `(DateTime, String)? parseMarkerCursor(String? cursor)`, `List<T> keepOrder<T>(List<String> ids, Map<String, T> found)`.

**Backend wiring:** Firestore `saves|follows|savedPhotographers where userId == uid orderBy createdAt desc, __name__ desc startAfter cursor limit n` (indexes of Task 2); `follows where photographerId == uid …` for followers; targets by `posts`/`photographers`/`users` `whereIn FieldPath.documentId` chunks of 30; counts with `query.count().get()`; markers written with the existing `_set` (set with `createdAt: serverTimestamp()`, delete on off).

- [ ] **Step 1:** Contract check (repositories, fakes, engagement controller); ledger differences.
- [ ] **Step 2: Failing tests:** `markerCursor round-trips and a malformed cursor reads as no cursor`; `keepOrder keeps marker order and drops missing targets`; `savedPosts returns newest saved first and a cursor only when more follow`; `a page whose targets are all gone loads the next page` (fake with 30 deleted posts then 2 live ones → items 2); `look-ahead stops after 3 extra pages`; `savedPhotographers drops profiles that are not published`; `followers maps display name, avatar and since`; `counts sums saved posts and saved photographers`; `setPhotographerSaved writes then removes the marker`; `SavedPhotographerController toggles optimistically and rolls back on failure`; `a successful follow toggle invalidates socialCountsProvider and followingIdsProvider`.
- [ ] **Step 3:** Run `test/data/content` and `test/features/discovery`; new tests fail.
- [ ] **Step 4: Implement.** If S20 (#144) is merged, also drop items whose author/photographer/follower id is in `hiddenUsersProvider` in the list controllers of Tasks 4–5 (not in the repository); else ledger "apply when #144 lands".
- [ ] **Step 5:** `flutter analyze` clean; the two folders green.
- [ ] **Step 6: Commit** `feat(data): saved and follow lists with cursors and counts [#143]`.

### Task 4: S19.01 saved screen and the S03.01 save button

**Files:**
- Create: `app_flutter/lib/features/saved/saved_screen.dart`, `saved_controller.dart` (`SavedPostsController`, `SavedPhotographersController`: `AsyncNotifier` with `items`, `cursor`, `loadingMore`, `moreFailed`, `loadMore()`, `refresh()`, `removeLocally(id)`, `restore(item, index)`); tests `test/features/saved/saved_screen_test.dart`, `test/support/saved_world.dart`
- Modify: `lib/core/widgets/photographer_card.dart` (`saved`, `onToggleSave`), `test/core/widgets/photographer_card_test.dart`, `lib/features/photographer_profile/photographer_profile_screen.dart` (visitor bookmark action, `Key('profile-save')`), its test, `lib/app/router.dart` (`/me/saved`), `lib/l10n/app_vi.arb`

**Interfaces:** Consumes `SavedFollowRepository`, `savedPhotographerProvider`, `socialCountsProvider`, `startBooking`. Produces `SavedScreen({SavedTab initialTab = SavedTab.posts})`, `enum SavedTab { posts, photographers }`.

**Backend wiring:** `savedPosts` / `savedPhotographers` pages (Task 3); bookmark writes `savedPhotographers/{uid}_{pid}` (rules of Task 2).

**Mock parity:** `#S19.01` (title "Đã lưu", `SegmentedTabs` "Bài · {n}" / "Nhiếp ảnh gia · {n}", 3-column square grid, no primary button), `#S19.01-photographers` (`PhotographerCard` list, bookmark overlay top-right of the hero, "Hồ sơ" outline + small primary "Đặt lịch" only for providers accepting orders), `#S03.01` (bookmark left of where the mock shows share; visitors only).

- [ ] **Step 1:** Contract check (PhotographerCard API, profile AppBar).
- [ ] **Step 2: Failing tests:** `posts tab shows the saved posts newest first in a 3-column grid and opens /p/:id`; `scrolling near the end loads the next page; a failed page shows the retry link`; `empty posts tab shows "Chưa lưu bài nào" and its body`; `?tab=photographers opens the second tab`; `photographer cards show the bookmark; tapping it removes the card's saved state and shows "Đã bỏ lưu Minh Trí" with "Hoàn tác" that restores it`; `a provider not accepting orders has no "Đặt lịch"`; `"Đặt lịch" goes through startBooking`; `tab labels show the counts from socialCountsProvider`; `S03.01 visitor sees the save button with tooltip "Lưu nhiếp ảnh gia"; tapping fills it; the owner does not see it`; `PhotographerCard without onToggleSave renders no bookmark (regression)`; `saved screen fits 320dp at 1.3x text`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement.** Grid tiles: the post's first image (`NetworkPhoto`, 1:1, `AppRadius` small) with `Semantics(label: caption or "Bài đã lưu")`; skeleton = 9 square `AppSkeleton` tiles; photographer list skeleton = `PhotographerCard` skeleton if it exists, else two card-shaped skeletons. The S03.01 bookmark sits in `AppBar.actions` with the same overlay circle decoration as the back button. Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/saved`, `test/core/widgets`, `test/features/photographer_profile` green (one per command).
- [ ] **Step 6: Commit** `feat(saved): S19.01 saved posts and photographers, save button on S03.01 [#143]`.

### Task 5: S19.02 following and S19.03 followers

**Files:**
- Create: `app_flutter/lib/features/saved/following_screen.dart`, `followers_screen.dart`, `follow_list_controller.dart` (`FollowingController`, `FollowersController`, same paging shape as Task 4); tests `test/features/saved/following_screen_test.dart`, `followers_screen_test.dart`
- Modify: `lib/app/router.dart` (`/me/following`, `/me/followers` with the role redirect), `lib/l10n/app_vi.arb`

**Interfaces:** Consumes `SavedFollowRepository.following/followers`, `followProvider` (`FollowController.toggle`), `myFollowerCountProvider`, `currentProfileProvider`.

**Backend wiring:** `follows where userId == uid` and `follows where photographerId == uid` pages; unfollow/follow writes the existing `follows` marker; the trigger of Task 2 updates the count.

**Mock parity:** `#S19.02` (title, "{n} nhiếp ảnh gia", rows avatar + name + provider mark + genre · area + outline "Đang theo dõi"/"Theo dõi", SnackBar with "Hoàn tác"), `#S19.03` (title, "{n} người theo dõi · chỉ bạn xem được danh sách này", rows avatar + name + "Theo dõi từ {d/M}", no buttons).

- [ ] **Step 1:** Contract check (FollowController, router redirect helpers).
- [ ] **Step 2: Failing tests:** `following lists photographers newest followed first with "Đang theo dõi"`; `tapping a row opens /u/:uid`; `unfollow keeps the row with "Theo dõi" and shows "Đã bỏ theo dõi Quốc Bảo"`; `unfollow then Hoàn tác re-follows once` (one write each way); `two quick taps end unfollowed` (busy guard); `a failed toggle shows "Chưa lưu được. Thử lại." and restores the button`; `empty following shows "Bạn chưa theo dõi ai" and "Khám phá" goes to /explore`; `followers shows "128 người theo dõi · …" and rows with "Theo dõi từ 12/10"`; `followers rows are not tappable`; `a customer opening /me/followers is sent to /profile`; `empty followers state`; `both fit 320dp at 1.3x text`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement** (`AsyncView`, paging on scroll like `timeline_tab.dart` `_nearEnd`). Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/saved` green.
- [ ] **Step 6: Commit** `feat(saved): S19.02 following with undo, S19.03 followers [#143]`.

### Task 6: S09.01 counts row and the follow boost in the home feed

**Files:**
- If #148 landed (Step 1 decides): Modify `lib/features/settings/settings_links.dart` (`savedListsReadyProvider` → `true`), `lib/features/profile/profile_tab.dart` (the "đang theo dõi" / "đã lưu" tiles read `socialCountsProvider` and open `/me/following` / `/me/saved`; photographers get a third tile "người theo dõi" → `/me/followers` from `myFollowerCountProvider`), its test (`following and saved tiles show counts and open the lists`; the #148 test "hidden while the flag is false" keeps passing with an override to `false`).
- If #148 has not landed: Create `app_flutter/lib/features/shell/profile_counts_row.dart` (`ProfileCountsRow({required bool photographer})`) and its test `test/features/shell/profile_counts_row_test.dart`; Modify `lib/features/shell/placeholder_tabs.dart` (`ProfileTab`: the row right under `_NotificationsRow`, before the badges). Ledger it so #148 replaces the row with its tiles and only keeps the flag on.
- Modify in both cases: `lib/data/recommendation/recommendation_models.dart` (`followedIds`), `lib/data/content/reason.dart` (`ReasonCode.following`), `lib/data/recommendation/local_recommender.dart` (`recommendPosts` boost + `reasonFollowing` text), `lib/features/home/home_controller.dart` (pass `followedIds` from `followingIdsProvider`), `services/recommender/api/openapi.yaml` (description note only: "followedIds: optional; posts of followed authors from the last 7 days rank first"), tests `test/data/recommendation/local_recommender_test.dart`, `test/features/home/home_controller_test.dart`, `test/features/shell/` (existing ProfileTab tests), `lib/l10n/app_vi.arb`

**Interfaces:** Consumes `socialCountsProvider`, `myFollowerCountProvider`, `followingIdsProvider`. Row: tappable counters (≥ 48dp each, `Semantics(button: true, label: "{n} đang theo dõi")`), number in the display face (`tn`) over the label, like the mock.

**Backend wiring:** aggregation counts (Task 3); `photographers/{uid}.followerCount` (Task 2).

**Mock parity:** `#S09.01` counts row (numbers over "đang theo dõi" / "đã lưu"; photographers also "người theo dõi"); "bài đăng" is added by #148.

- [ ] **Step 1:** Contract check: does `lib/features/settings/settings_links.dart` with `savedListsReadyProvider` exist (#148 landed)? Pick the matching file list above. Also check the home controller query sites and LocalRecommender test helpers.
- [ ] **Step 2: Failing tests:** `customer row shows "4 đang theo dõi" and "12 đã lưu" and opens /me/following and /me/saved`; `photographer row adds "128 người theo dõi" → /me/followers`; `while loading the row shows skeleton numbers, on error it shows "—" and stays tappable`; `followed authors' posts of the last 7 days come first with "Bạn đang theo dõi"`; `an 8-day-old post of a followed author keeps its place`; `no followedIds keeps today's order (regression)`; `home passes the followed ids to recommendPosts`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement.** In `recommendPosts`: `final followed = known.where((p) => q.followedIds.contains(p.photographerId) && now.difference(p.createdAt) <= const Duration(days: 7))`; order `[...followed, ...boosted not followed, ...rest not followed]`; add `Reason(code: ReasonCode.following, text: _l.reasonFollowing)` first for followed posts. Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/shell`, `test/data/recommendation`, `test/features/home` green; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit** `feat(profile): S09.01 follow and saved counts, followed authors first in the feed [#143]`.

### Task 7: Docs, data model, ledger and status

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S19 cells → "✅ đã làm (#143)"; §3e.7 one line: "theo dõi" is a feed signal), `docs/superpowers/specs/data-model/domain-model.md` (`SavedPhotographer` row; `Photographer.followerCount` derived, server-only), `relational-schema.md` (`saved_photographers` table, `photographers.follower_count int not null default 0` with "trigger đếm lại", mapping rows), `docs/superpowers/specs/screens/saved-following.md` (status "Đã có")
- Create: `docs/superpowers/handover/ledger-s19-saved-following.md`

- [ ] **Step 1:** Edit the docs; check every S19 string against `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: rulings, rules and integration tests written not run, deploy order (indexes before the app release; trigger before the app shows counts — the app shows "—" while `followerCount` is absent), the #132 counter coordination outcome, the #144 hidden-users filter (applied or pending).
- [ ] **Step 3: Commit** `docs(spec): S19 saved and following in the data model, ledger [#143]`.

## Deferred

- Public follower count on S03.01 (Needs the owner 1).
- Remote recommender support for `followedIds` (contract note only; the service is not wired, `LocalRecommender` ranks today).
- A stored list of followed ids (`users/{uid}/private/following`) if the feed boost reads grow (cost conclusion).
- Notifications "new post from someone you follow" (no S17 type yet).
- Self-hosted parity (`services/api` has no saves/follows routes; Go backend phase 2 #90).
- Analytics events (no analytics layer).

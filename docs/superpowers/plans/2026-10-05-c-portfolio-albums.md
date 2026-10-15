# C1–C3: Portfolio albums (S24, S03.01 Portfolio tab, S10.01 album field) Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle or performance steps; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`, indexes and adds Functions. Write the rules tests and the Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **Lanes:** Tasks 1–4 (domain, Functions, rules, indexes, `lib/data/**`, `lib/core/widgets/**`) are lane 2; Tasks 5–7 are lane 1: Task 5 is unit **C1**, Task 6 **C2**, Task 7 **C3**, each after lane 2 merges Task 4 (gate **GC1**). C1, C2 and C3 touch different feature folders and can run on three machines at once (the router and the arb file are append-only between them). Independent of plans A1 and B1.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** Photographers group their posts into ordered albums (each post in at most one album), pick the album while posting, and visitors see a Portfolio tab with an Album / Dòng thời gian toggle and an album detail page; photos only for now, with the model ready for video.

**Architecture:** `albums/{id}` and the album fields on posts (`albumId`, `albumPosition`) are written by the server only, except that a new post may carry the `albumId` of one of the author's albums: a Firestore trigger on post creation then appends it to the album in a transaction. All other album changes (create, edit, delete, reorder albums, move posts, reorder posts) are callables whose rules live in `packages/domain`. The server keeps `postCount`, `mediaCount` and `visible` (= has posts) on each album, so public queries read only `visible` albums. The app gets an `AlbumRepository`, four core widgets and the S24 screens.

**Tech Stack:** TypeScript (domain, Functions v2: callables and `onDocumentCreated`), Firestore rules and indexes; Flutter, Riverpod 3, `ReorderableListView` for drag-to-reorder, existing `showAppSheet`, `AppOptionTile`, `SegmentedTabs`, `AsyncView`, `NetworkPhoto`.

**Spec:** `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §3 (all of it), §6.1–6.3 (album rows), §10; `docs/superpowers/specs/screens/portfolio-awards.md` (S03.01 tab Portfolio, S10.01 ô Album, S09.01, S24.01–S24.05); `docs/superpowers/specs/components/shared-components.md` → `PortfolioViewToggle`, `AlbumTile`, `ReorderableRow`, `PostPickerGrid`; `docs/superpowers/specs/data-model/domain-model.md` §2.8 (`Album`, `Post.albumId/albumPosition`, `PostMedia`), §6 invariant 17; `relational-schema.md` §2.9 (target DDL; the self-hosted API has no posts tables yet, so no migration here); mock `docs/design/ui-mock.html` `#S03.01-nag`, `#S24.01`–`#S24.05`, `#S10.01`.

**Prerequisite:** develop at or after PR #25 (spec 10-05).

## Contract with existing code

Task 1 Step 1 (lane 2) and the first step of Tasks 5–7 (lane 1) check these; adapt and ledger any difference:

- Domain/Functions: `DomainError` (`invalid_argument`, `permission_denied`, `not_found`, `conflict`, `limit_exceeded`), `Clock`, `IdGenerator`, `isId`, `CALLABLE_OPTIONS`, `TRIGGER_OPTIONS`, `toHttpsError`, `CallableInput`, `db()`, the `callables/review.ts` + `triggers/review_write.ts` patterns, `index.ts` exports.
- Rules: `validPostCreate()` (its `hasOnly` key list), `match /posts/{postId}` (`update, delete: if false`), the catch-all deny.
- Indexes: `firestore.indexes.json` posts `(photographerId, createdAt desc)`.
- App data: `PostSummary` + `postFromFirestore` (`lib/data/content/`), `PostRepository.byPhotographer`, `PostDraft`, `PostPublisher` + `FirestorePostPublisher` (client `WriteBatch`, `_alreadyLanded` retry), `content_providers.dart`, `test/support/content_fixtures.dart` `fixturePost`.
- Features: `features/create_post/` (`CreatePostScreen`, `PostComposerController`, `ComposerState` and its `with*` copies, the `SwitchListTile(key: Key('create-portfolio'))`, `_pickService` sheet pattern, SharedPreferences draft `postDraft:<uid>`), `features/photographer_profile/` (`PortfolioSliver`, `portfolioProvider`, `PortfolioState`, `ProfileSection`), `features/profile/` S09.01 screen, `lib/app/router.dart`, `ScreenCodes.albumDetail/myAlbums/editAlbum/addPostsToAlbum/pickAlbum` (S24.01–S24.05, added by PR #25).
- Core: `showAppSheet`, `AppSheetFrame`, `AppOptionTile`, `SegmentedTabs`, `AppButton`, `AsyncView`, `AppSkeleton`, `NetworkPhoto`, `EmptyState`, `showConfirmSheet`, `core.dart`.

## Global Constraints

- "Mỗi bài thuộc tối đa một album (đã chốt). Bài chưa xếp album chỉ hiện ở Dòng thời gian."
- "Dòng thời gian: mọi bài `work` và `real_shoot` của thợ ảnh, mới nhất trước."
- "Mặc định của nút gạt: Album nếu có ≥ 1 album không trống, nếu không thì Dòng thời gian. Không có album nào không trống thì ẩn nút gạt."
- "Tên album 1–40 ký tự, không trùng tên album khác của cùng người (không phân biệt hoa thường). Mô tả ≤ 300 ký tự." "Tối đa 30 album mỗi người, 200 bài mỗi album."
- "Thứ tự album (`position`) và thứ tự bài trong album (`albumPosition`) do chủ hồ sơ đặt. Album đầu tiên hiện rộng hết hàng trên hồ sơ."
- "Ảnh bìa: mặc định ảnh đầu của bài đầu tiên; chọn được một ảnh bất kỳ trong album. Bìa trỏ tới bài bị gỡ khỏi album hoặc bị xoá → quay về mặc định."
- "Album trống không hiện công khai. Xoá album không xoá bài; bài về "Chưa xếp album"." "Bài bị xoá hoặc gỡ khỏi album thì các bài sau trong album dồn lên (không để lỗ hổng `albumPosition`)."
- "Kéo thả để sắp xếp luôn có cách không cần kéo: "…" → Chuyển lên / Chuyển xuống / Lên đầu / Xuống cuối (WCAG 2.2 "dragging movements")."
- S10.01: "Công tắc "Thêm vào portfolio" bỏ, thay bằng ô **Album · tuỳ chọn** (mặc định album dùng gần nhất, chưa có album thì "Không xếp album") mở sheet S24.05. Bài mới thêm vào cuối album."
- "Bản đầu chỉ chấp nhận `image`." (no video picker, no `PostMedia` rename in this plan).
- Strings and copy: the `s24xx_…` lists in `screens/portfolio-awards.md` (use camelCase app keys, e.g. `albumCounts` for `s2401_counts`; keep the Vietnamese text verbatim).
- Layering, strings, tokens, imports, Firebase only in adapters, `AsyncView` for every `AsyncValue`, one primary action per screen, commit trailer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Decisions (where the spec is silent)

1. **Who writes.** Rules: `albums` read if signed in, write false. Posts keep `update, delete: false`; `validPostCreate()` accepts an optional `albumId` (string matching `[A-Za-z0-9_-]{1,64}`) when the album does not exist **or** `get(albums/{albumId}).data.photographerId == request.auth.uid` (a missing album must not block the publish: the trigger detaches it, Review Focus 4 — ruling 2026-10-06 in unit 9b/1-L2), and never `albumPosition`.
2. **New post into an album.** Trigger `onPostCreated` (`posts/{postId}`): if `albumId` is set, in one transaction read the album; if it is gone, belongs to someone else, or has 200 posts, remove `albumId` from the post (it stays in the timeline) and stop; else set `albumPosition = postCount + 1`, `postCount + 1`, `mediaCount + imageUrls.length`, `visible = true`, `updatedAt`. Idempotent: a post that already has `albumPosition` is skipped.
3. **Album doc** `albums/{id}`: `photographerId`, `title`, `titleKey` (lower-cased, trimmed, for uniqueness), `description`, `cover?: {postId, imageIndex}`, `position` (1-based), `postCount`, `mediaCount`, `visible`, `createdAt`, `updatedAt`. Ids are ULIDs from the server.
4. **Callables** (`asia-southeast1`, caller must own every album and post named):
   - `createAlbum({title, description?})` → `{albumId}`; appended at `position = count + 1`; `limit_exceeded` at 30; `conflict` on a duplicate title.
   - `updateAlbum({albumId, title?, description?, cover?: {postId, imageIndex} | null})`; cover must point at a post in the album and an existing image index.
   - `deleteAlbum({albumId})`: clears `albumId`/`albumPosition` on its posts, deletes the album, renumbers the remaining albums.
   - `reorderAlbums({albumIds})`: must be exactly the caller's album ids; rewrites `position`.
   - `movePostsToAlbum({albumId: string | null, postIds})`: `postIds` 1–50, all the caller's `work` posts; each post leaves its old album (that album compacts, its cover resets if it pointed at the post) and is appended in the given order; `albumId: null` = remove from albums; `limit_exceeded` if the target would pass 200.
   - `reorderAlbumPosts({albumId, postIds})`: exactly the album's post ids; rewrites `albumPosition`.
   All run in one Firestore transaction. A move can touch every source album of the moved posts (up to 29 albums × 199 renumbered posts); Firestore has no 500-write cap any more (limits are 10 MiB per commit and 270 s per transaction), so this succeeds, but large moves lock many posts — the app sends at most 50 posts per call (corrected 2026-10-06 in unit 9b/1-L2).
5. **Public reads.** Profile albums: `albums where photographerId == uid and visible == true orderBy position`. Owner: same without `visible`. Album posts: `posts where albumId == x orderBy albumPosition` (page 24). Indexes: `albums (photographerId, visible, position)`, `albums (photographerId, position)`, `posts (albumId, albumPosition)`.
6. **Cover.** No `cover` → the first image of the post at `albumPosition == 1`. The app resolves it from the first page of album posts; `AlbumSummary.coverUrl` is filled by the repository with that rule (album docs do not copy URLs).
7. **`inPortfolio`.** The publisher keeps writing `inPortfolio: true` (rules unchanged for it) and keeps the `photographers/{uid}.portfolio` arrayUnion; nothing reads it for the Portfolio tab any more (the timeline is `byPhotographer`, which already ignores it). Removing the field is left for a later clean-up.
8. **Last used album.** The composer stores `lastAlbum:<uid>` in SharedPreferences after a publish with an album; on a new draft it preselects that album if it still exists in `myAlbums`, else "Không xếp album".
9. **In-album swipe on S02.02** ("vuốt trong phạm vi album") is **deferred**: S24.01 opens `/p/:id` like the timeline. Ledger it; a later S02.02 plan adds `?album=` paging.
10. **Arranging posts inside an album** (S24.01 owner "Sắp xếp bài"): a list mode of `ReorderableRow`s (thumb, caption first line, "{n} ảnh") instead of dragging grid tiles; saves with `reorderAlbumPosts` on drop (undo SnackBar).

## Review Focus

1. Two quick publishes into the same album (or a trigger retry) → positions 1, 2 with no gap or duplicate, count 2. Pinned by Task 2 ("concurrent creates get consecutive positions", "a retried trigger does not count twice").
2. Moving a post that is the cover of its old album → the old album's cover falls back to its new first post; the old album compacts its positions. Pinned by Task 1 ("moving the cover post resets the old cover", "the old album closes the gap").
3. A tampered client creates a post with `albumId` of someone else's album, or with `albumPosition` → refused by rules. Pinned by Task 2 rules tests.
4. Last album deleted while the composer still preselects it → publishing works and the post lands unsorted. Pinned by Task 5 ("a deleted last album falls back to none") and Task 2 ("a post naming a missing album stays unsorted").
5. Screen-reader / no-drag user reorders albums → menu moves work and announce the new position. Pinned by Task 4 ("menu moves call onMove with the new index", "row announces n of m") and Task 7 ("move up saves the new order").

---

## File Structure

| File | Responsibility |
|---|---|
| `packages/domain/src/album.ts`, `album_ports.ts`, `memory_album_store.ts`, `album_use_cases.ts` (create) | rules, ports, reference adapter, use cases |
| `packages/domain/test/album*.test.ts` | tests |
| `app_flutter/firebase/functions/src/infra/album_firestore.ts`, `live_album.ts`, `src/callables/album.ts`, `src/triggers/post_created.ts` (create); `src/index.ts` (modify) | adapters, callables, trigger |
| `app_flutter/firebase/functions/test/unit/album_*.test.ts`, `test/integration/album.test.ts` | tests |
| `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs` (modify) | albums read, post albumId, indexes |
| `app_flutter/lib/data/album/album.dart`, `album_repository.dart` (interface + fake), `firestore_album_repository.dart`, `album_providers.dart` (create) | app data |
| `app_flutter/lib/data/content/post_summary.dart`, `firestore_post_repository.dart`, `post_publisher.dart`, `firestore_post_publisher.dart` (modify) | album fields, `byAlbum`, draft `albumId` |
| `app_flutter/lib/core/widgets/album_tile.dart`, `portfolio_view_toggle.dart`, `reorderable_row.dart`, `post_picker_grid.dart` (create); `core.dart` (modify) | widgets |
| `app_flutter/lib/features/create_post/…` (modify), `features/create_post/album_picker_sheet.dart` (create) | C1: S10.01, S24.05 |
| `app_flutter/lib/features/photographer_profile/…` (modify), `features/album/album_detail_screen.dart`, `album_detail_controller.dart` (create) | C2: S03.01 tab, S24.01 |
| `app_flutter/lib/features/album/my_albums_screen.dart`, `my_albums_controller.dart`, `edit_album_sheet.dart`, `add_posts_sheet.dart` (create); S09.01 screen (modify) | C3: S24.02–S24.04 |
| `app_flutter/lib/app/router.dart`, `lib/l10n/app_vi.arb` (modify, append-only) | routes, strings |

---

### Task 1: Domain — album rules and use cases

**Files:**
- Create: `packages/domain/src/album.ts`, `album_ports.ts`, `memory_album_store.ts`, `album_use_cases.ts`; modify `src/index.ts`
- Test: `packages/domain/test/album.test.ts`, `album_use_cases.test.ts`

**Interfaces:**
- Produces:

```ts
export const ALBUM_TITLE_MAX = 40, ALBUM_DESC_MAX = 300, ALBUMS_PER_PHOTOGRAPHER = 30, POSTS_PER_ALBUM = 200, MOVE_BATCH_MAX = 50;
export interface AlbumCover { readonly postId: string; readonly imageIndex: number; }
export interface Album {
  readonly id: string; readonly photographerId: string; readonly title: string; readonly titleKey: string;
  readonly description: string; readonly cover: AlbumCover | null; readonly position: number;
  readonly postCount: number; readonly mediaCount: number; readonly visible: boolean;
  readonly createdAt: Date; readonly updatedAt: Date;
}
export interface AlbumPost {           // the album-relevant slice of a post
  readonly id: string; readonly authorId: string; readonly kind: string; readonly imageCount: number;
  readonly albumId: string | null; readonly albumPosition: number | null;
}
export function titleKeyOf(title: string): string;            // trim, collapse spaces, lower-case (vi locale-insensitive)
export function validateAlbumFields(raw: unknown, partial: boolean): { title?: string; description?: string; cover?: AlbumCover | null };

export interface AlbumTx {
  listAlbums(photographerId: string): Promise<Album[]>;              // ordered by position
  getAlbum(id: string): Promise<Album | null>;
  getPosts(ids: readonly string[]): Promise<(AlbumPost | null)[]>;
  listAlbumPosts(albumId: string): Promise<AlbumPost[]>;            // ordered by albumPosition
  putAlbum(a: Album): void;
  deleteAlbum(id: string): void;
  setPostAlbum(postId: string, albumId: string | null, position: number | null): void;
}
export interface AlbumStore { runTransaction<T>(fn: (tx: AlbumTx) => Promise<T>): Promise<T>; }
export interface AlbumDeps { readonly albums: AlbumStore; readonly clock: Clock; readonly ids: IdGenerator; }

export function createAlbum(deps: AlbumDeps, callerId: string, raw: unknown): Promise<{ albumId: string }>;
export function updateAlbum(deps: AlbumDeps, callerId: string, raw: unknown): Promise<void>;
export function deleteAlbum(deps: AlbumDeps, callerId: string, raw: unknown): Promise<void>;
export function reorderAlbums(deps: AlbumDeps, callerId: string, raw: unknown): Promise<void>;
export function movePostsToAlbum(deps: AlbumDeps, callerId: string, raw: unknown): Promise<void>;
export function reorderAlbumPosts(deps: AlbumDeps, callerId: string, raw: unknown): Promise<void>;
/** Trigger use case (Decision 2). Returns what happened, for logs and tests. */
export function appendNewPost(deps: AlbumDeps, postId: string): Promise<'appended' | 'skipped' | 'detached'>;
```

The hard part is `movePostsToAlbum`; write it as pure planning over the read state, then apply (sample):

```ts
// after reading: target (or null), the posts, and every source album with its ordered posts
const moving = new Set(postIds);
for (const src of sourceAlbums) {
  const kept = srcPosts.get(src.id)!.filter((p) => !moving.has(p.id));
  kept.forEach((p, i) => { if (p.albumPosition !== i + 1) tx.setPostAlbum(p.id, src.id, i + 1); });
  const coverGone = src.cover !== null && moving.has(src.cover.postId);
  tx.putAlbum({ ...src, postCount: kept.length, mediaCount: sum(kept), visible: kept.length > 0,
                cover: coverGone ? null : src.cover, updatedAt: now });
}
if (target !== null) {
  const base = targetPosts.filter((p) => !moving.has(p.id));          // a post already in target is re-appended
  if (base.length + postIds.length > POSTS_PER_ALBUM) throw new DomainError('limit_exceeded');
  base.forEach((p, i) => { if (p.albumPosition !== i + 1) tx.setPostAlbum(p.id, target.id, i + 1); });
  postIds.forEach((id, i) => tx.setPostAlbum(id, target.id, base.length + i + 1));
  tx.putAlbum({ ...target, postCount: base.length + postIds.length, mediaCount: …, visible: true, updatedAt: now });
} else {
  postIds.forEach((id) => tx.setPostAlbum(id, null, null));
}
```

(Check the `limit_exceeded` before any write; the sample shows the order of writes only.)

- [ ] **Step 1: Contract check** (domain/Functions part).
- [ ] **Step 2: Write the failing tests:**
  - `album.test.ts`: "title is trimmed and 1–40 characters"; "title key ignores case and extra spaces"; "description over 300 is invalid"; "cover needs a post id and a non-negative index".
  - `album_use_cases.test.ts`: "create appends at the next position"; "the 31st album is limit_exceeded"; "a duplicate title is a conflict"; "update renames and keeps the position"; "cover must be a post in the album"; "delete clears its posts and renumbers the others"; "reorder needs exactly the caller's albums"; "move into an empty album makes it visible"; "move appends in the given order"; "the old album closes the gap"; "moving the cover post resets the old cover"; "moving to null removes from albums"; "moving someone else's post is permission_denied"; "moving a real_shoot post is invalid"; "passing 200 posts is limit_exceeded and writes nothing"; "reorder posts needs exactly the album's posts"; "appendNewPost puts the post last"; "appendNewPost detaches when the album is full or missing"; "appendNewPost skips a post that already has a position".
- [ ] **Step 3: Run** `(cd packages/domain && npm test)` → fail. **Step 4: Implement.** **Step 5: Run** `npm test && npm run lint` → pass.
- [ ] **Step 6: Commit** `feat(domain): portfolio albums [c]`.

### Task 2: Functions, trigger, rules, indexes

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/album_firestore.ts`, `live_album.ts`, `src/callables/album.ts`, `src/triggers/post_created.ts`; modify `src/index.ts`, `seed/fixtures.ts` (two albums for the seeded photographer)
- Modify: `app_flutter/firebase/firestore.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`
- Test: `test/unit/album_callables.test.ts`, `test/integration/album.test.ts`

**Interfaces:**
- Produces: callables `createAlbum`, `updateAlbum`, `deleteAlbum`, `reorderAlbums`, `movePostsToAlbum`, `reorderAlbumPosts`; trigger `onPostCreated`; Firestore shapes per Decisions 2–3.

Rules (sample):

```
match /albums/{albumId} {
  allow read: if signedIn();
  allow write: if false;                    // callables only
}
// in validPostCreate(): add 'albumId' to the hasOnly list, then
&& (!('albumId' in d) || (d.albumId is string
     && d.albumId.matches('[A-Za-z0-9_-]{1,64}')
     && (!exists(/databases/$(database)/documents/albums/$(d.albumId))
         || get(/databases/$(database)/documents/albums/$(d.albumId)).data.photographerId == request.auth.uid)))
```

- [ ] **Step 1: Write the failing tests.** Unit: "unauthenticated is refused"; "domain errors map to HttpsError". Integration (do not run): "a post created with albumId lands last in the album"; "concurrent creates get consecutive positions"; "a retried trigger does not count twice"; "a post naming a missing album stays unsorted"; "movePostsToAlbum moves and compacts". Rules (do not run): "albums are readable by signed-in users"; "nobody writes albums"; "a post may name the author's own album"; "a post may not name another photographer's album"; "a post may name a missing album (the trigger detaches it)"; "a post may not name an album id with a slash"; "a post may not set albumPosition"; "posts still cannot be updated".
- [ ] **Step 2: Run** `(cd app_flutter/firebase/functions && npm test)` → fail. **Step 3: Implement** (store maps `albums/{id}` and the post slice; trigger uses `TRIGGER_OPTIONS`). **Step 4: Run** `npm test && npm run build` → pass; ledger the skipped emulator suites.
- [ ] **Step 5: Commit** `feat(functions): album callables and post-created trigger [c]`.

### Task 3: App data — albums and album fields on posts

**Files:**
- Create: `app_flutter/lib/data/album/album.dart`, `album_repository.dart` (interface + `FakeAlbumRepository`), `firestore_album_repository.dart`, `album_providers.dart`
- Modify: `lib/data/content/post_summary.dart` (`albumId`, `albumPosition`), `firestore_post_repository.dart` (parse; `byAlbum`), `content_repositories.dart` (`PostRepository.byAlbum`), `fake_content_repositories.dart`, `post_publisher.dart` (`PostDraft.albumId`), `firestore_post_publisher.dart` (write `albumId` when set), `test/support/content_fixtures.dart` (`fixtureAlbum`, `fixturePost(albumId:, albumPosition:)`)
- Test: `test/data/album/firestore_album_repository_test.dart`, `test/data/content/firestore_post_repository_test.dart` (extend), `test/data/content/post_publisher_test.dart` (extend)

**Interfaces:**
- Produces:

```dart
@immutable
class AlbumSummary {
  const AlbumSummary({required this.id, required this.photographerId, required this.title, this.description = '',
    required this.position, required this.postCount, required this.mediaCount, required this.visible,
    this.coverPostId, this.coverImageIndex, this.coverUrl});
  final String id, photographerId, title, description; final int position, postCount, mediaCount; final bool visible;
  final String? coverPostId; final int? coverImageIndex; final String? coverUrl;   // coverUrl resolved by the repository (Decision 6)
}
abstract class AlbumRepository {
  Stream<List<AlbumSummary>> watchAlbums(String photographerId, {required bool includeEmpty});
  Future<AlbumSummary?> album(String albumId);
  Future<String> create({required String title, String description = ''});
  Future<void> update(String albumId, {String? title, String? description, AlbumCoverChoice? cover});
  Future<void> delete(String albumId);
  Future<void> reorder(List<String> albumIds);
  Future<void> movePosts(String? albumId, List<String> postIds);
  Future<void> reorderPosts(String albumId, List<String> postIds);
}
sealed class AlbumCoverChoice { const AlbumCoverChoice(); }   // AlbumCoverAuto() | AlbumCoverPick(postId, imageIndex)
class AlbumError implements Exception { const AlbumError(this.code); final String code; }  // 'conflict', 'limit_exceeded', ...
// PostRepository gains:
Future<PostPage> byAlbum(String albumId, {String? cursor, int limit = 24});
// providers
final albumRepositoryProvider = Provider<AlbumRepository>(...);
final profileAlbumsProvider = StreamProvider.autoDispose.family<List<AlbumSummary>, String>(...);   // visible only
final myAlbumsProvider = StreamProvider.autoDispose<List<AlbumSummary>>(...);                        // owner, includes empty
```

- [ ] **Step 1: Write the failing tests:** "an album doc parses with counts and cover"; "a missing cover resolves to the first post's first image"; "watchAlbums for visitors asks only visible albums ordered by position"; "a post reads its album fields"; "byAlbum orders by albumPosition"; "a draft with albumId writes albumId and no albumPosition"; "a draft without albumId writes no album field"; callable errors "a duplicate title becomes AlbumError('conflict')".
- [ ] **Step 2: Run** `flutter test test/data` → fail. **Step 3: Implement** (callables through the same helper other repositories use). **Step 4: Run** `flutter analyze && flutter test test/data` → pass.
- [ ] **Step 5: Commit** `feat(data): album repository and album fields on posts [c]`.

### Task 4: Core widgets — `AlbumTile`, `PortfolioViewToggle`, `ReorderableRow`, `PostPickerGrid`

**Files:**
- Create: `app_flutter/lib/core/widgets/album_tile.dart`, `portfolio_view_toggle.dart`, `reorderable_row.dart`, `post_picker_grid.dart`; modify `core.dart`; gallery (`scripts/tools/build_ui_components.py`, regenerate `docs/design/ui-components.html`)
- Test: `test/core/widgets/album_tile_test.dart`, `portfolio_view_toggle_test.dart`, `reorderable_row_test.dart`, `post_picker_grid_test.dart`

**Interfaces:**
- Produces:

```dart
class AlbumTile extends StatelessWidget {        // square cover with two stacked edges above (mock .alb), title 1–2 lines, "{n} ảnh"
  const AlbumTile({super.key, required this.title, required this.photoCount, this.coverUrl, this.featured = false, this.dimmedNote, required this.onTap});
  const AlbumTile.skeleton({super.key, this.featured = false});
  final bool featured;          // 16:7, full row, photo count pill on the cover
  final String? dimmedNote;     // owner view of an empty album: "Trống · chưa hiện công khai", tile at 70% opacity
}
enum PortfolioView { albums, timeline }
class PortfolioViewToggle extends StatelessWidget {   // pill toggle with icons; Semantics role tab + selected
  const PortfolioViewToggle({super.key, required this.value, required this.onChanged});
}
class ReorderableRow extends StatelessWidget {        // for use inside ReorderableListView
  const ReorderableRow({super.key, required this.index, required this.count, required this.title, this.subtitle,
    this.leading, this.dimmed = false, required this.onMove, this.extraMenu = const []});
  final int index, count;
  final void Function(int newIndex) onMove;           // from the "…" menu: up, down, to top, to bottom
  final List<PopupMenuEntry<VoidCallback>> extraMenu; // e.g. Sửa, Xoá
}
class PostPickerGrid extends StatelessWidget {        // 3 columns; selected tiles show their order number
  const PostPickerGrid({super.key, required this.items, required this.selected, required this.onToggle, this.maxSelected});
  final List<PostPickItem> items; final List<String> selected;   // order = selection order
}
@immutable class PostPickItem { const PostPickItem({required this.postId, required this.thumbUrl, this.imageCount = 1, this.albumTitle}); }
```

`ReorderableRow` drag handle: `ReorderableDelayedDragStartListener(index: index, child: handle)` (long press, so scrolling does not start a drag); 48dp hit area; the row's semantics value "{index+1} trên {count}"; after a menu move the parent announces the new position (`SemanticsService.announce`).

- [ ] **Step 1: Write the failing tests:** "featured tile is full width 16:7 with the count pill"; "empty album tile is dimmed with its note"; "skeleton has the tile's shape"; "toggle marks the selected view for screen readers"; "menu moves call onMove with the new index" (up from 0 disabled, down from last disabled); "row announces n of m"; "picker numbers tiles in selection order"; "picker disables extra tiles at the maximum"; "picker labels a tile with its current album".
- [ ] **Step 2: Run** `flutter test test/core/widgets` → fail. **Step 3: Implement** (+ exports, gallery tiles). **Step 4: Run** `flutter analyze && flutter test test/core` → pass.
- [ ] **Step 5: Commit** `feat(core): album tile, portfolio toggle, reorderable row, post picker [c]`. **Gate GC1.**

### Task 5 (unit C1): S10.01 album field and S24.05 album picker

**Files:**
- Modify: `features/create_post/post_composer.dart` (`ComposerState.albumId` in the constructor, `copyWith` and every `with*`; `setAlbum`; publish passes `albumId`; remove `inPortfolio` from the UI but keep sending `true`), `create_post_screen.dart` (replace the `create-portfolio` switch with the album field `Key('create-album')`), `create_post_providers.dart` (`lastAlbumProvider` read/write of `lastAlbum:<uid>`)
- Create: `features/create_post/album_picker_sheet.dart` (`ScreenCode(ScreenCodes.pickAlbum, …)`)
- Modify: `lib/l10n/app_vi.arb` (block), `test/support/create_post_world.dart` (album fakes)
- Test: `test/features/create_post/create_post_screen_test.dart`, `post_composer_test.dart`, `album_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `myAlbumsProvider`, `AlbumRepository.create`, `PostDraft.albumId`, `AppOptionTile`, `showAppSheet`.
- Produces: `PostComposerController.setAlbum(String? albumId)`; `showAlbumPicker(BuildContext, {String? selected}) → Future<AlbumPick?>` where `AlbumPick` is `AlbumPick.none()` or `AlbumPick.album(id)`.

Behaviour (mock `#S24.05`): sheet title "Xếp vào album"; first option "Không xếp album" with sub "Chỉ hiện ở Dòng thời gian"; then albums (cover 40, title, "{n} bài", "dùng gần nhất" on the last used); outline "Album mới" opens the S24.03 sheet from C3 if present, else a minimal inline title prompt using `AlbumRepository.create` (Decision: C1 must not wait for C3; when C3 lands, it replaces the prompt with its sheet). Choosing closes the sheet.

- [ ] **Step 1: Contract check** (create-post part). **Step 2: Write the failing tests:** "the album field replaces the portfolio switch"; "new draft preselects the last used album"; "a deleted last album falls back to none"; "choosing an album fills the field and closes the sheet"; "publishing sends albumId and remembers it"; "publishing with none sends no albumId"; "Album mới creates an album and selects it"; "the draft keeps the album across restarts".
- [ ] **Step 3: Run** → fail. **Step 4: Implement.** **Step 5: Run** `flutter analyze && flutter test test/features/create_post` → pass.
- [ ] **Step 6: Commit** `feat(create-post): album field and album picker S24.05 [c1]`.

### Task 6 (unit C2): S03.01 Portfolio toggle and S24.01 album detail

**Files:**
- Modify: `features/photographer_profile/widgets/profile_sections.dart` (`PortfolioSliver`), `profile_providers.dart` (`portfolioViewProvider(uid)`: default per Global Constraints, then the visitor's choice for the session), `photographer_profile_screen.dart` (owner "Sắp xếp" link → `/me/albums`)
- Create: `features/album/album_detail_screen.dart`, `album_detail_controller.dart` (`ScreenCode(ScreenCodes.albumDetail, …)`); route `/u/:uid/albums/:albumId` in `lib/app/router.dart`
- Modify: `lib/l10n/app_vi.arb` (block), `test/support/profile_world.dart` (albums)
- Test: `test/features/photographer_profile/photographer_profile_screen_test.dart`, `profile_providers_test.dart`, `test/features/album/album_detail_screen_test.dart`

**Interfaces:**
- Consumes: `profileAlbumsProvider`, `PostRepository.byAlbum`, `AlbumTile`, `PortfolioViewToggle`, `ReorderableRow`, `AlbumRepository.reorderPosts/delete/update`, existing `PortfolioSliver` timeline grid and `ProfileBottomBar` (reuse its inquiry + book buttons on S24.01).

Behaviour:
- Portfolio tab (mock `#S03.01-nag`): row with `PortfolioViewToggle` + "{n} album" (and "Sắp xếp" for the owner); Albums view = first album `AlbumTile(featured: true)` then a 2-column grid; Timeline view = the existing grid (keep its paging and "Xem thêm ảnh"). No visible album → no toggle, timeline only. Switching keeps each view's scroll offset (`PageStorageKey` per view).
- S24.01 (mock `#S24.01`): back, share (`share_plus` already used by S03.01? if not, copy the link to the clipboard with a SnackBar, ledger), "…"; title (display font), author row (`ProviderName` if plan A1 has landed, else `VerifiedName`), "{posts} bài · {photos} ảnh", description, 2-column grid in `albumPosition` order (tile shows "n" images badge when > 1), paging 24; bottom bar = the profile's inquiry + "Đặt lịch · từ {giá}". Empty/gone states and owner menu per `screens/portfolio-awards.md` S24.01; "Sắp xếp bài" switches to the list mode of Decision 10.

- [ ] **Step 1: Contract check** (profile part). **Step 2: Write the failing tests:** profile "no visible album hides the toggle and shows the timeline"; "with albums the toggle defaults to Albums"; "the first album is featured"; "switching views keeps each scroll position"; "owner sees Sắp xếp"; album detail "posts appear in album order"; "an empty album shows its owner the add action"; "a missing album shows Album này không còn"; "arranging saves the new order and offers undo"; "the bottom bar books this photographer".
- [ ] **Step 3: Run** → fail. **Step 4: Implement.** **Step 5: Run** `flutter analyze && flutter test test/features` → pass.
- [ ] **Step 6: Commit** `feat(profile): Album / Dòng thời gian toggle and album detail S24.01 [c2]`.

### Task 7 (unit C3): S24.02 Album của tôi, S24.03 edit sheet, S24.04 add posts, S09.01 entry

**Files:**
- Create: `features/album/my_albums_screen.dart`, `my_albums_controller.dart` (`ScreenCode(ScreenCodes.myAlbums, …)`), `edit_album_sheet.dart` (`ScreenCodes.editAlbum`), `add_posts_sheet.dart` (`ScreenCodes.addPostsToAlbum`); route `/me/albums`
- Modify: the S09.01 screen (photographers: "Album của tôi" row → `/me/albums`), `features/create_post/album_picker_sheet.dart` ("Album mới" now opens `showEditAlbumSheet`), `lib/l10n/app_vi.arb` (block)
- Test: `test/features/album/my_albums_screen_test.dart`, `edit_album_sheet_test.dart`, `add_posts_sheet_test.dart`

**Interfaces:**
- Consumes: `myAlbumsProvider`, `AlbumRepository.*`, `PostRepository.byPhotographer`, `ReorderableRow`, `PostPickerGrid`, `AlbumTile`, `showConfirmSheet`, `SegmentedTabs`.
- Produces: `showEditAlbumSheet(BuildContext, {AlbumSummary? album}) → Future<String?>` (album id created or edited); `showAddPostsSheet(BuildContext, {required AlbumSummary album}) → Future<int?>` (posts added).

Behaviour (mock `#S24.02`–`#S24.04`, strings and states in `screens/portfolio-awards.md`):
- S24.02: hint line; `ReorderableListView` of `ReorderableRow`s (drag on drop → `reorder`; undo SnackBar 5 s re-sends the old order); empty albums dimmed; the fixed last row "Chưa xếp album · {n} bài" opens S24.04 in "sort unsorted" mode; primary "Album mới"; "+" disabled with a reason at 30 albums; empty state with the primary action.
- S24.03: fields and errors per spec (`conflict` → "Bạn đã có album tên này" under the title field); create → opens S24.04 for the new album; edit mode "Lưu" + red text "Xoá album" → `showConfirmSheet` (red "Xoá album", body "Bài trong album không bị xoá, chuyển về Chưa xếp album."); closing with edits asks "Bỏ thay đổi?". Cover picker: "Chọn ảnh" opens a grid of the album's images (disabled when the album is empty).
- S24.04: `SegmentedTabs` "Chưa xếp · {n}" / "Tất cả bài · {n}" (unsorted = `byPhotographer` filtered to `albumId == null`, page 30), `PostPickerGrid` (max = 200 − album count, and ≤ 50 per call; selecting past 50 sends in batches of 50 in order), move warning line when a selected post has another album, primary "Thêm {n} bài" → `movePosts`.

- [ ] **Step 1: Contract check** (S09.01 part). **Step 2: Write the failing tests:** "albums list in position order"; "drop saves the new order and undo restores it"; "move up saves the new order"; "the unsorted row opens the picker"; "the 30th album disables +"; edit sheet "duplicate title shows the error under the field"; "creating opens the add-posts sheet"; "deleting asks first and uses the red confirm"; "closing with changes asks to discard"; add posts "unsorted tab lists only posts without an album"; "selecting a post from another album shows the move warning"; "more than 50 selected are sent in ordered batches"; S09.01 "photographers see Album của tôi".
- [ ] **Step 3: Run** → fail. **Step 4: Implement.** **Step 5: Run** `flutter analyze && flutter test` → pass.
- [ ] **Step 6: Update** the S24.01–S24.05 status cells in `remaining-screens.md` §2 ("✅ đã làm (c1/c2/c3)") and add the deferred in-album swipe (Decision 9) to the S02.02 cell.
- [ ] **Step 7: Commit** `feat(album): Album của tôi, edit and add-posts sheets S24.02–S24.04 [c3]`.

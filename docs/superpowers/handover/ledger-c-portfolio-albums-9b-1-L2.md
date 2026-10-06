# Handover ledger — 9b/1-L2 (plan C portfolio albums: domain, Functions, rules, data, core widgets)

Unit: `9b/1-L2` (plan `docs/superpowers/plans/2026-10-05-c-portfolio-albums.md`, Tasks 1–4). Branch `plan/9b-1-L2-albums-core` from `c818314`. Opens gate **GC1** for the screen units C1 (Task 5), C2 (Task 6), C3 (Task 7).

## What landed

| Task | Commits | Summary |
|---|---|---|
| 1 | 6c7fe89, ba2762d | `packages/domain`: album rules (`titleKeyOf` with NFC, limits 30/200/50), ports, memory store, use cases `createAlbum`, `updateAlbum`, `deleteAlbum`, `reorderAlbums`, `movePostsToAlbum`, `reorderAlbumPosts`, `appendNewPost` |
| 2 | 1a94a6f, 7f857ba | Functions callables (6) + `onPostCreated` trigger; rules: `albums` read-only for clients, posts may carry `albumId` (format `[A-Za-z0-9_-]{1,64}`; a missing album is allowed and the trigger detaches it); indexes; seed 5 posts + 2 albums for AN; real emulator integration tests |
| 3 | 22a4e50 | App data: `AlbumSummary`, `AlbumRepository` (Firestore reads, callables), `PostRepository.byAlbum`, `PostSummary.albumId/albumPosition`, `PostDraft.albumId` |
| 4 | 51042aa | Core widgets: `AlbumTile` (+ featured, skeleton), `PortfolioViewToggle`, `ReorderableRow` (long-press drag + "…" move menu), `PostPickerGrid`; gallery tiles |
| final fixes | 6b25db2, 2e7a832, a11a000 | non-work posts detached by the trigger; trigger skips posts without albumId; seed title keys; cover read failure keeps the album (coverUrl null); auth-reactive `myAlbumsProvider`; `AlbumSummary` equality; picker tiles always labelled; drag handle hidden from semantics; album-owned `albumPhotoCount` key |

## Rulings

- **Plan sample rule was wrong (Decision 1 corrected):** a post naming a missing album must be allowed (spec Review Focus 4); rule `!exists(album) || get(album).photographerId == uid` plus the id format check.
- **Plan Decision 4 corrected:** Firestore has no 500-write cap; a move can touch every source album; the app sends ≤ 50 posts per call.
- Functions integration tests are real emulator cases (not skipped placeholders); not run locally, CI runs them.
- `AlbumError` falls back to the error message when `details.code` is missing, as the provider/booking repositories do.

## Deferred (minor)

- No post deletion yet, so no compaction-on-delete use case and no test for the deleted-cover-post fallback.
- `watchAlbums` re-resolves covers on every snapshot (≤ 30 albums; equality now avoids rebuilds).
- `albums` readable by any signed-in user incl. `visible: false` (non-sensitive; public queries filter `visible`).
- Raw `Colors.white`/`transparent` and a few literal sizes in the new widgets; skeleton edges use border colours.
- `PostPickerGrid` lays out every tile (shrinkWrap); fine for 30-post pages.
- Test helper `test/data/album/firestore_post_seed.dart` imports another test file; `_validId` copied in three repositories; unused arb key `reorderHandle`.
- `updateAlbum` with an empty patch only bumps `updatedAt`; album descriptions are not NFC-normalized.

## For the screen units (C1–C3)

- Use `myAlbumsProvider` (owner, includes empty albums; empty list when signed out) and `profileAlbumsProvider(uid)` (visible only).
- `AlbumTile(dimmedNote: l.albumEmptyNote)` for empty albums in the owner list.
- Pass `PostPickItem(label: <caption first line>)` so tiles read well; otherwise they fall back to "Bài {i} trên {n}".
- `movePosts` accepts ≤ 50 ids per call — batch larger selections in order.

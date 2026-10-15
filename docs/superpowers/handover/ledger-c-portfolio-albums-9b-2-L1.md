# Handover ledger — plan C (portfolio albums), units C1, C2, C3

Plan: `docs/superpowers/plans/2026-10-05-c-portfolio-albums.md`, Tasks 5–7 (lane 1). Tasks 1–4 in 9b/1-L2 (`ledger-c-portfolio-albums-9b-1-L2.md`).
Shipped in the batch branch `plan/9abc-L1-provider-portfolio-awards` (one PR with 9a/2-L1 and 9c/2-L1).

## Built
- C1: S10.01 album field (replaces the portfolio switch; `inPortfolio` still sent `true`), last-used album per uid, S24.05 picker.
- C2: S03.01 Album / Dòng thời gian toggle (featured first album, 2-column grid), S24.01 album detail `/u/:uid/albums/:albumId` (album order, paging 24, arrange with undo, profile bottom bar).
- C3: S24.02 Album của tôi `/me/albums` (reorder with undo, 30-album cap, "Chưa xếp album" row), S24.03 edit sheet, S24.04 add posts (batches of ≤ 50 in order, 200 cap), S09.01 "Album của tôi" row, S24.01 owner menu "Sửa album" / "Thêm bài".

## Rulings
- S24.01 shows the album only when `album.photographerId == uid` from the URL and (owner or visible); ownership never comes from the URL.
- Share on S24.01 copies the in-app path to the clipboard (`share_plus` is not a dependency; no public web host yet).
- Per-view scroll offsets are remembered by the profile's scroll controller (single scroll view, so `PageStorageKey` cannot do it).
- `PortfolioViewToggle` (core) segments are `Flexible` with ellipsis and stay ≥ 48 dp at 320 dp × 1.3.
- "Chưa xếp album" row opens the album picker (without "Không xếp album") and then S24.04 for the chosen album: S24.04 needs a target and the mock is silent.
- Unsorted / all-post counts are read in pages (max 3 per read, no count API): "30+" while more pages exist, "…" / a count-less line when nothing unsorted was found yet.
- Edit sheet uses `enableDrag: false` so a drag cannot skip "Bỏ thay đổi?".
- A stale album id at publish is re-checked against the user's albums and dropped if gone; if the albums can't be read the id is sent and the rule (`!exists(album) || owner`) + `onPostCreated` trigger handle a deleted album.
- Visitors get no "…" menu on S24.01 until "Báo cáo" (S20.01) exists.

## Deferred
- Explicit "Không xếp album" in an otherwise empty draft is not persisted (after restart the last album is preselected again).
- `withAlbum` extension instead of a `copyWith` sentinel in `ComposerState`.
- Delete paths from the edit sheet and S24.01 invalidate unsorted posts without their own tests.
- In-album swipe on S02.02 (Decision 9) — see the S02.02 status cell.

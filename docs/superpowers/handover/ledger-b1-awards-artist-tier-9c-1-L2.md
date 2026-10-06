# Handover ledger — 9c/1-L2 (plan B1 awards and NAG tier: domain, Functions, rules, CLI, data, core widgets)

Unit: `9c/1-L2` (plan `docs/superpowers/plans/2026-10-05-b1-awards-artist-tier.md`, Tasks 1–4). Branch `plan/9c-1-L2-awards-core` from `e999f3f`. Opens gate **GB1** for the lane-1 unit (Tasks 5–6: S25.01, S25.02, S09.01/S09.02 entries, S03.01 NAG variant and awards strip).

## What landed

| Task | Commits | Summary |
|---|---|---|
| 1 | 784cbb5, 3efcc4b | `packages/domain`: award validation (proof folder, https links, limits), review machine, `tierFor` (≥ 3 approved → artist; studio never), `recomputeTier` (idempotent, writes only on change), `purgeDueProofs`; side effects best-effort after the tier recompute; re-queue only on content change |
| 2 | 7772208, ba81a13 | Functions: `createAward`/`updateAward`/`deleteAward`/`reviewAward` (admin claim), `onAwardWrite` trigger, daily `purgeAwardProofs`, A1 hook `recomputeArtistTier` wired (logs, never throws), staff CLI `npm run awards` (bucket from `STORAGE_BUCKET`), rules (approved public, owner reads all, proofs owner-only, audit closed), raster-only storage, indexes, seed (DUNG with 3 approved awards, a pending award, an admin user) |
| 3 | 956fe59 | App data: `Award`, `AwardResult`/`AwardStatus`, `AwardRepository` (+ fake, Firestore/callables), `myAwardsProvider`, `approvedAwardsProvider` |
| 4 | c6755fe, 9bbb096 | Core widgets: `AwardChip`, `AwardRow`, `AwardDisc`, label helpers; `StatusBadge.custom` (one badge look; award statuses use the mock's colours) |
| final fixes | 0c8d072, 3f56dcc, 4e4f3cf | create-only proof uploads with ULID names; edit/delete recompute best-effort; usable `FakeAwardRepository`; staff cannot review their own award; year bound in Asia/Ho_Chi_Minh |

## Rulings

- Resubmission after rejection is allowed only when the content changes; an unchanged save is a no-op.
- After commit, `recomputeTier` runs first; file deletes and notifications are best-effort.
- `createAward` also requires `users/{uid}.role == 'photographer'`.
- Proof images: raster only (jpeg/png/webp/heic/heif), create-only, fresh ULID file names (`proofPath(uid, awardId, fileId)`); plan B1 text updated. The storage rule also requires `resource == null` on create: CI showed the Storage emulator reports an overwrite as a create.
- `AwardResult.fromCode` is nullable so unknown results skip the doc; unknown status reads as pending.
- Staff cannot review their own award.
- Emulator integration and rules tests are real cases, run by CI only.

## Deferred (minor)

- Purge does not re-check `purgeAfter` inside its transaction and deletes by listed paths, not by prefix (race with an edit between listing and delete; never-referenced uploads stay).
- `reviewedBy` (staff uid) is stored on public approved awards (plan Decision 1); consider keeping it only in `awardAudit`.
- Best-effort catches swallow errors (no domain logger); purge adapter and CLI `main()` untested; integration tests share state.
- No object-count cap under `awardProofs/{uid}/` in storage (≤ 3 enforced by the domain).
- Formatting nits (`_time`, some tests), import order in `content_fixtures`, `StatusBadge` ignore_for_file, `AwardDisc` raw sizes.

## For the lane-1 unit (Tasks 5–6)

- Upload proofs with `repository.proofPath(uid, awardId, newUlid())`; never reuse a path (the storage rule refuses overwrites).
- `FakeAwardRepository(uid: …)` serves test worlds; `watchMine` is newest first.
- Use `AwardRow(status: …)` with `awardStatusLabel`; `StatusBadge.custom` for any other non-booking badge.
- The staff side (S23.07) is the CLI for now: `STORAGE_BUCKET=… npm run awards -- list` in `app_flutter/firebase/functions`.

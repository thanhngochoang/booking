# Handover ledger — plan B1 (awards, NAG tier), unit 9c/2-L1

Plan: `docs/superpowers/plans/2026-10-05-b1-awards-artist-tier.md`, Tasks 5–6 (lane 1). Tasks 1–4 in 9c/1-L2 (`ledger-b1-awards-artist-tier-9c-1-L2.md`).
Shipped in the batch branch `plan/9abc-L1-provider-portfolio-awards` (one PR with 9a/2-L1 and C1–C3).

## Built
- Task 5: S25.01 Giải thưởng của tôi `/me/awards` (tier card {approved}/3, live switch to "Bạn là Nhiếp ảnh gia"), S25.02 award sheet (result chips, "Tác phẩm" picker, proofs: ≤ 3 images + ≤ 2 https links), S09.02 "Giải thưởng" row, S09.01 nudge for individuals with "Để sau" (`awardNudgeDismissed:<uid>`).
- Task 6: S03.01 Nhiếp ảnh gia variant (stats rating · giải thưởng · buổi chụp · kinh nghiệm), awards strip (≤ 2 chips, "Xem cả {n} giải", read-only sheet of `AwardRow`s).

## Rulings
- Live tier: added `AwardTier`, `AwardRepository.watchTier(uid)` (Firestore adapter listens to `photographers/{uid}`), `myTierProvider`; `photographerProfileProvider` is one-shot.
- "Tác phẩm" picker reuses `PostPickerGrid` (plan C is in the same branch).
- Proof uploads follow the review-controller pattern: a fresh `newUlid()` per attempt (Storage refuses overwrites), uploads still running when a tile is removed or the sheet closes are deleted when they finish, unsaved uploads are deleted on dispose. Dropped proofs of an existing award are removed by the server (`updateAward` → `files.delete`).
- The artist tag on the profile stays "Nhiếp ảnh gia" without a count (mock `#S03.01-nag`); the giải thưởng stat carries the number.
- No badges row exists yet (S03.02 not built): for an artist the strip sits under the stats, above the bio.
- An awards fetch error hides the strip silently (secondary content, the mock has no error row).

## Deferred
- The "stream ended without done or error" branch in proof upload has no own test.

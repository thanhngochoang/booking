# Handover ledger — plan S25 awards: local review of award proofs, S25.01 header (issue #145)

Plan: `docs/superpowers/plans/2026-10-07-s25-awards.md`, Tasks 1–3. Branch `plan/145-s25-giai-thuong-hang-nag`. Merge base a70f722; commits b38e781 and f097bf1 (CLI and wrapper), 63f9be3 (S25.01 header), then the docs commit of Task 3.

## Built
- CLI (Task 1): `app_flutter/firebase/functions/tools/awards.ts` works against the local emulators. `proofModeFromEnv` picks emulator mode when `FIREBASE_STORAGE_EMULATOR_HOST` is set; `show` then downloads the proof files with the Admin SDK to `$TMPDIR/awards/<awardId>/` (files named `<index>-<basename>`, awardId reduced to a safe basename) and prints `file: <path>`; against a real project it prints 15-minute signed URLs (`file (15 min): <url>`). The bucket is resolved only when the proof has files (`show` of the seeded award needs none). `list` prints `waiting 3d 4h` per award (`formatWaiting`, oldest first). `guardEnv` refuses a mixed environment (any emulator host set but another one missing or not local).
- Wrapper (Task 1): `scripts/awards-local.sh` sets the three emulator hosts, `GCLOUD_PROJECT` and `STORAGE_BUCKET`, unsets `GOOGLE_APPLICATION_CREDENTIALS`, then runs `npm run awards`. `--help` prints its own usage plus the CLI's.
- App (Task 2): S25.01 header as in the mock: "Đã khai" on the left, "{n} giải" on the right in the muted ink, not a link. `s2501Listed` is replaced by `s2501ListedTitle` and `s2501ListedCount`; the width/text-scale loop (320 dp, 1.3x) covers the header.
- Docs (Task 3): the seed README section "Staff CLI for awards" (what the CLI does, local walkthrough with `scripts/awards-local.sh`, real-project notes); main spec §2 rows S25.01 ("khớp mock (#145)") and S23.07 ("duyệt bằng CLI … tới khi có dashboard (#83)"); `screens/portfolio-awards.md` S25.01 header, strings and a "Duyệt" line.
- No rules, index, callable, trigger or data-model change; no new Functions work.

## Decisions of the plan
1. Keep the CLI for phase 1; no staff callable change and no in-app staff screen. `reviewAward` is already a callable (claim `staffRole == 'admin'`) and the CLI drives the same use case. An in-app screen would add a staff-only surface to the consumer app, needs signed proof URLs and an audit view, and would be thrown away when S23.07 lands in the web dashboard (phase 1.5, #83). What blocked review was that `show` could not run on the emulators and nobody documented a one-command local run.
2. Emulator `show` downloads the proof files to `$TMPDIR/awards/<awardId>/` with the Admin SDK (bypasses Storage rules) and prints local paths; against a real project it keeps 15-minute signed URLs. Mode = emulator when `FIREBASE_STORAGE_EMULATOR_HOST` is set.
3. Bucket on the emulator: `STORAGE_BUCKET`, else `FIREBASE_STORAGE_BUCKET`, else (wrapper only) `project_info.storage_bucket` of `app_flutter/android/app/google-services.json`, else `<project>.appspot.com` (the app's default bucket comes from the same file).
4. The wrapper refuses real credentials: it unsets `GOOGLE_APPLICATION_CREDENTIALS`, and the CLI calls `assertLocalEmulators({ allowAnyProject: true })` whenever any of the three emulator hosts is set, so a half-set environment cannot touch a real project.
5. `list` shows how long each award has waited (`waiting 3d 4h`), oldest first, so the 3-business-day promise of S25.02 ("Duyệt trong 3 ngày làm việc") can be checked by eye. Pure formatter, unit-tested.
6. S25.01 header copy: the mock wins ("Đã khai" left, "{n} giải" right in tertiary ink, count not a link).

## Needs the owner
1. Before the web dashboard (#83) exists, is review by CLI acceptable for the production launch (someone with the admin claim runs `npm run awards` against prod with a service-account key)? **Default: yes**; S25.02 keeps promising "Duyệt trong 3 ngày làm việc". If no, S23.07 moves ahead of the launch.

## Review notes
From the SDD progress ledger (`.superpowers/sdd/2026-10-07-s25-awards/progress-plan-145-s25-giai-thuong-hang-nag.md`):
- Pre-flight scan: no cross-task findings (T1 usage → T3 README, T2 status → T3 rows).
- Task 1 review 1 (b38e781): one Important finding, the "bucket needed" logic lived in `main()` and was untested; fix round 1 (b38e781..f097bf1) resolves the bucket only for files and pins it in tests, and folded in the minors: awardId basename, index-prefixed file names, mixed-mode refusal (`guardEnv`), header comment. Review clean afterwards.
- Task 2 (f097bf1..63f9be3): review approved.
- Final check: no rules, index or function changed; no emulator suite skipped.

## Not run
- Manual emulator walkthrough (Review Focus 4: `approve seed-award-binh-1`, then Bình's S25.01 flips the row to "Đã duyệt", `award_reviewed` arrives, `onAwardWrite` recomputes the tier, the tier card says "Còn 2 giải đã duyệt nữa để nhận tích vàng") was **not run in the sandbox** (it needs the running emulators). Run it when merging, with the steps of `app_flutter/firebase/functions/seed/README.md` "Staff CLI for awards". Also try `show` on an award created in the app with proof photos (files land in `$TMPDIR/awards/<id>/`).

## Deferred
- S23.07 staff award review screen with proof viewer and identity check on tier grant: web dashboard, phase 1.5 (#83).
- Reminders or escalation when an award waits longer than 3 business days: needs the staff operations queue (S23, #83).
- Real-project review runs (service-account key, prod bucket): operational, outside the sandbox; documented in the README.

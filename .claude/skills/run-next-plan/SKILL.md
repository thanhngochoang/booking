---
name: run-next-plan
description: Pick up the next implementation plan from docs/superpowers/plans/RUN-ORDER.md and execute it on this machine while other machines work in parallel — claim it on the shared claim board (status "in progress" on the `board` branch, so no two computers take the same plan), create a branch from develop, implement it task by task following the plan and the specs, then open a PR into develop; in continuous mode it also lands its own PR when the safety gates pass (CI green, up to date, no overlap with another machine's branch) and keeps taking units until the feature or lane is finished. Use this whenever the user says things like "làm task tiếp theo", "nhận plan tiếp", "chạy plan kế tiếp trong run order", "máy này làm gì tiếp", "start the next plan", "pick up work", "continue the plan in progress on this machine", "what's free in the run order", or names a run-order row ("làm 8b", "run plan 9"), or wants the machine to work on its own until done ("làm liên tục", "tự merge rồi làm tiếp", "làm hết lane 2", "chạy đến hết 8e", "keep going until the feature is done"). Also use it to resume a plan this machine already claimed, to move a claim to "in review"/"done", or to release a claim.
---

# Run the next plan (parallel, many machines)

**Base branch: `develop`, always.** Every plan branch is created from `origin/develop` and every PR targets `develop`. Never base work on `flutter-rewrite`, `main`, a lane branch or a stale local `develop`.

Several computers implement this project at the same time. They coordinate through two things:

- **What to do, in which order**: `docs/superpowers/plans/RUN-ORDER.md` on `origin/develop` (the "To run" table, its dependency notes, the lane split and the standing rules). `develop` is protected, so this file only changes through PRs.
- **Who is doing what right now**: `CLAIMS.md` on the branch **`board`**, a branch that holds nothing else. A unit is claimed by pushing a commit to `board`; git rejects the second of two simultaneous pushes, so that rejection is the lock. This is why the board is only changed through `scripts/board.py` (never by hand, never from a plan branch).

`board.py` lives next to this file: `python3 .claude/skills/run-next-plan/scripts/board.py <cmd>` from the repo root. It builds its commits with git plumbing and never touches your checkout. Inside the Claude sandbox SSH to github.com is blocked: prefix it with `BOARD_GH=1` (HTTPS through `gh auth git-credential`) and pass `allowed_domains: ["github.com", "api.github.com"]`. Other `git fetch`/`push` calls in this skill use the same trick: `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push https://github.com/thanhngochoang/booking.git <branch>`.

## 1. Read the board

```bash
BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/board.py show
```

It prints this machine's name, the active claims and the "To run" table from `origin/develop`. Also read the whole `RUN-ORDER.md` (`git show origin/develop:docs/superpowers/plans/RUN-ORDER.md`): the standing rules, the lane table and the notes in each State cell decide dependencies, and they change as plans finish.

Then, in this order:

1. **Clean up finished reviews.** For each claim `in review (PR #n)`, run `gh pr view <n> --json state`. If it is `MERGED`, run `board.py set <id> done --force` (any machine may do this: a merged PR is a fact, not a takeover).
2. **Resume before claiming.** If an `in progress` claim belongs to this machine, continue that unit: check out its branch and read its ledger. Check the ledger against the branch (`git log origin/develop..<branch>`, the files the finished tasks should have created) before trusting it; if they disagree, continue from what the branch really contains and tell the user. One machine works on one unit at a time.
3. **Choose the next unit.** Go down the "To run" table and take the first row that is runnable:
   - its State is `not started` (or the part it says remains), and it has no active claim on the board;
   - every plan it `needs` is `done` ("needs X" in its State cell, or "every plan above it", the file's default rule). A dependency that is claimed or in review is not done yet;
   - it shares no files with a unit that is claimed by another machine, unless RUN-ORDER says they are parallel-safe (e.g. "can run as a third lane", or the lane table's ownership split);
   - it is not marked stale, blocked on something from the user (sandbox keys, approval of a spec), or "last" while feature work remains.

   When a row is split across lanes, the unit is one lane step: id `<#>/<step>-L<lane>` (e.g. `8a2/2-L1`); the gate in the lane table is a dependency like any other. If the user named a unit ("làm 8b"), check it is runnable the same way; if it isn't, say what blocks it instead of starting anyway.

   The State cells can lag behind the code (a PR merged but its row wasn't updated). Before claiming, compare the row with `git log origin/develop` and the plan's tasks: if part of it is already merged, claim only what remains and tell the user the row is stale. Redoing merged work is the most expensive mistake here.

   If nothing is runnable, stop and tell the user which units are held by whom and what each free one waits on. Don't invent work and don't run a plan out of order. Claims older than ~2 days whose branch has no new commits are probably abandoned, but only the user can say so: report them, don't take them over.

## 2. Claim it

Branch name: `plan/<id>-<short-slug>`, with `/` in the id replaced by `-`: `plan/8b-booking-sheet`, `plan/8a2-2-L1-asyncview-migration`.

```bash
BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/board.py claim 8b --branch plan/8b-booking-sheet
```

- exit 0: the unit is yours.
- exit 3: another machine got it first (the output says who). Go back to step 1.3 and pick again; this is the lock working, not an error.
- anything else: report it to the user. Never fall back to editing `CLAIMS.md` or `RUN-ORDER.md` by hand, and never push to `develop` directly (it is protected; the push fails anyway).

## 3. Branch from develop

```bash
git fetch origin develop        # with the gh credential helper inside the sandbox
git switch -c plan/8b-booking-sheet origin/develop
git push -u <remote-or-https-url> plan/8b-booking-sheet
```

If the working tree is dirty, stop and ask; it may be another session's work. Pushing the empty branch right away lets other machines see where the work lives. RUN-ORDER's lane section may still name fixed lane branches (`lane/ui`, `lane/core`); with the board each unit gets its own `plan/…` branch from `develop` instead, while the lane table's file ownership still applies.

## 4. Implement, following the plan and the specs

Read these before writing code, because they are what reviewers hold the work to:

- the plan file named in the row (`docs/superpowers/plans/…`); for a lane step, only the tasks that step lists;
- `CLAUDE.md` (the "Flutter rewrite" part: rules, commands, sandbox and env setup) and RUN-ORDER's standing rules: UI matches `docs/design/ui-mock.html`, specs decide behaviour; no battery/performance work, device builds or iOS-only steps inside feature plans (iOS steps go under "Deferred iOS steps" in `2026-10-01-ios-enablement.md`); Firestore/Storage rules tests are written but not run locally;
- the specs the plan points to: `docs/superpowers/specs/2026-10-01-remaining-screens.md`, `specs/screens/`, `specs/components/shared-components.md`, `specs/data-model/`;
- the ledgers in `docs/superpowers/handover/` for rulings earlier plans settled.

Execute the plan with the **superpowers:subagent-driven-development** skill (the run order says plans run that way): one implementer subagent per task, a review after each, one commit per task with a Conventional Commit message ending in the co-author line. Keep the SDD ledger at `.superpowers/sdd/<plan-file-stem>/progress-<branch-with-dashes>.md` (one per branch, so two machines on the same plan never write the same ledger), update it after every task with the commit id, and push the branch after each task so work never lives on one laptop only.

When the plan and a spec or the mock disagree, follow CLAUDE.md (mock wins for layout/copy, spec for behaviour), record the ruling in the ledger and the PR. When a task needs a file that RUN-ORDER gives to another lane, or that a unit claimed by another machine is changing, don't edit it: write the request in the ledger and in the PR description.

## 5. Finish: PR into develop

1. Verify on the branch with real output before claiming anything passes (superpowers:verification-before-completion): from `app_flutter/`, `flutter analyze && flutter test`; `(cd ../packages/domain && npm test)` if the domain changed; `(cd firebase/functions && npm test)` if Functions changed (integration tests run outside the sandbox; say so if you could not run them).
2. In the branch, update what the plan says to update: the "Trạng thái" cells of `remaining-screens.md` for the screens it built, a handover ledger `docs/superpowers/handover/ledger-<plan>.md` (rulings, deferred items), and **its own row** in RUN-ORDER.md's "To run" table: `done <date> (PR #n)` for a whole row, or the step's cell / a "remaining: …" note for a lane step. Touch only that row, so PRs from other machines don't conflict.
3. Rebase onto the latest `origin/develop`, push, and open the PR:
   ```bash
   gh pr create --base develop --head plan/8b-booking-sheet --title "feat(booking): S04.01–S04.04 booking sheet [8b]" --body "…"
   ```
   **PR title convention.** Every plan PR is titled `<type>(<scope>): <summary> [<unit-id>]`, because the title becomes the merge commit message on `develop`, and the `[id]` ties the history back to RUN-ORDER and the board.
   - `type`: `feat` for new screens or behaviour, `fix`, `refactor` (e.g. migrating screens to AsyncView), `perf`, `test`, `docs`, `chore`, `build`, `ci`. Choose by what the PR mostly does.
   - `scope`: one lowercase area, matching the commit scopes already in the log. Examples: `booking`, `chat`, `review`, `explore`, `profile`, `core`, `data`, `domain`, `functions`, `rules`, `api`, `l10n`. If the PR spans several areas, use the one the plan is named after.
   - `summary`: English, imperative or noun phrase, no final period. Put the screen codes first when the plan builds screens (`S05.01–S05.03 booking detail and lists`).
   - `[unit-id]`: exactly the board id, e.g. `[8b]`, `[9]`, `[8a2/2-L1]`.
   - Keep it to about 90 characters. Examples:
     - `refactor(core): move existing screens to AsyncView and component skeletons [8a2/2-L1]`
     - `feat(core): ReasonPicker, ProviderPicker, ConfirmSheet and chat widgets [8a2/2-L2]`
     - `feat(api): self-hosted API and PostgreSQL backend, phase 2 [9]`

   `land.py` refuses a title that doesn't follow this (exit 6). Fix it with `gh pr edit <n> --title "…"` and land again.

   The body uses these headings: **Unit** (RUN-ORDER row/step and plan file), **Tasks done**, **Tests** (commands and results), **Rulings** (mock vs spec decisions), **Deferred**, **Cross-lane requests**. It ends with the Claude Code attribution line. If you only know the PR number after creating it, amend the row in a follow-up commit.
4. Move the claim to review:
   ```bash
   BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/board.py set 8b "in review" --pr 123
   ```
   In single mode, merging is the user's call: stop here. After the merge, the next `show` on any machine marks it `done` (step 1.1). In continuous mode, go on to step 6.

Tell the user, in Vietnamese: the unit, the branch, the PR link, the test results, and anything left for them.

## 6. Landing (continuous mode only)

Merge your own PR only when nothing about it can hurt another machine's work. `scripts/land.py` checks this and does the merge. It refuses on its own if anything is off, so don't merge any other way and never use `gh pr merge --admin`.

```bash
BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/land.py 8b --pr 123
```

The gates, in order:
1. the PR is yours: open, `plan/…` → `develop`, and the claim on the board belongs to this machine;
2. the branch contains the latest `origin/develop`;
3. no file it changes is also changed on another machine's active claim branch. RUN-ORDER.md, `app_vi.arb`, generated l10n and `pubspec.lock` are exempt, because they are append-only or regenerated;
4. every CI check on the PR passed (it waits while they run);
5. GitHub says it is mergeable and not blocked.

Then it merges with a merge commit (the repo's style), deletes the branch, and marks the claim `done (PR #n)`.

What each exit code means and what to do:
- **2, behind or conflicting with develop**: `git fetch`, `git rebase origin/develop`, then resolve.
  - Conflicts in your own RUN-ORDER row, or in another lane's block of `app_vi.arb`: keep both sides, then run `flutter gen-l10n`.
  - Conflicts in real code that came from another lane's merged work: resolve them the way that lane's code now expects. If you can't do that without changing that lane's files, stop and ask.

  Re-run `flutter analyze && flutter test`, `git push --force-with-lease` (your own branch only), and land again.
- **3, CI failed**: read the log (`gh run view --log-failed`), fix it with a new commit, push, and land again. After three failed fixes, stop and report.
- **4, overlap with another machine's branch**: don't merge, and don't edit their files. Usually the other unit has to land first.
  1. Note the overlap in your PR and ledger.
  2. Set the claim to `in review (PR #n)`.
  3. Wait with `board.py watch` until that unit is done.
  4. Rebase onto develop and land again.

  If the overlap means the plans themselves collide (both really change the same logic), stop and ask the user.
- **6, the title doesn't follow the convention**: run `gh pr edit <n> --title "<type>(<scope>): <summary> [<id>]"`, then land again.
- **5, blocked by branch rules or the merge was refused** (e.g. a review is now required): stop. Tell the user the PR link and leave the claim `in review`.

## Continuous mode: keep going until the feature is done

Use this when the user asks for it: "làm liên tục", "chạy tự động đến hết", "tự merge rồi làm tiếp", "làm hết lane 2", "làm đến hết 8e", or similar. The user may give a scope, which can be a lane, a range of rows, or a feature like the booking flow 8a2–8e. With no scope, keep going until nothing runnable is left in the "To run" table. Rows that are stale, blocked on the user, or marked "last" (iOS 15, final battery 16) are never taken automatically.

The loop:
1. Run steps 1–5, then land the PR (step 6).
2. Once it has merged, go back to step 1 on the fresh `develop`. Prefer the next unit in the same lane, so file ownership stays stable, then the next runnable row in the scope.
3. **If nothing in scope is runnable yet but other machines still hold claims** (typically a lane-1 step waiting for a lane-2 gate): don't stop and don't take work out of order. Wait for the board or develop to change:
   ```bash
   BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/board.py watch --timeout 1800
   ```
   Run it in the background and act when it exits. On a timeout, check the board again. After about 3 hours with no change, stop and report who holds what.
4. Stop and report when any of these happens:
   - the scope is finished, or nothing is runnable and no other machine holds a claim;
   - a plan needs something only the user can give (keys, a spec or mock decision, a device);
   - the plan and the spec/mock disagree in a way CLAUDE.md does not settle;
   - tests keep failing after three real attempts;
   - a landing exits with 5.

After each landed unit, post a short progress line in Vietnamese: unit, PR link, tests, and what comes next. When stopping, give a summary: what landed (with PR links), what is left and who holds it, and why you stopped.

Keep each unit's work inside subagents (subagent-driven development) and keep the main thread to the board, git and short summaries. That lets one session carry many units without running out of context. Re-read RUN-ORDER.md from `origin/develop` at the start of every unit: other machines' PRs change it.

## Other board commands

- Give a unit up (the user stopped it, or it was claimed by mistake): `board.py release <id> --note "<what is half done, where the branch is>"`. It moves to the board's "Finished" list and becomes free again.
- `set`/`release` refuse another machine's claim without `--force`. Use `--force` only for a merged PR (step 1.1) or when the user explicitly says to.
- `BOARD_MACHINE=<name>` overrides the machine name, e.g. to run two sessions on one computer as separate machines.

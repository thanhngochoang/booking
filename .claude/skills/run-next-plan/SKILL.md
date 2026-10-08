---
name: run-next-plan
description: Pick up the next unit of work from GitHub Project 4 (https://github.com/users/thanhngochoang/projects/4) and execute it on this machine while other machines work in parallel — claim the issue (a new branch plan/<issue>-<slug> pushed from develop is the lock; Status moves to In Progress), implement the plan named in the issue task by task with subagent-driven development, then open a PR into develop and move the issue to In Review; in continuous mode it also lands its own PR when the safety gates pass (CI green, up to date, no overlap with another machine's branch), marks the issue Done and keeps taking units until the milestone or scope is finished. Use this whenever the user says things like "làm task tiếp theo", "nhận việc tiếp", "nhận issue tiếp", "máy này làm gì tiếp", "start the next plan", "pick up work", "continue the unit in progress on this machine", "what's free in the project", or names an issue ("làm #35", "run issue 41"), or wants the machine to work on its own until done ("làm liên tục", "tự merge rồi làm tiếp", "làm hết Phase 1", "chạy đến hết cà chua/gạch", "keep going until the milestone is done"). Also use it to resume a unit this machine already holds, to move an issue to In Review/Done, or to give a unit up.
---

# Run the next unit (GitHub Project, many machines)

**Base branch: `develop`, always.** Every unit branch is created from `origin/develop` and every PR targets `develop`. Never base work on `flutter-rewrite`, `main` or a stale local `develop`. (Exception the owner may ask for: a long-lived stack branch such as `plan/stack-2026-10` that collects several units before one PR; see "Stack branch" below.)

Several computers implement this project at the same time. Since 2026-10-06 they coordinate through **GitHub Project 4** (owner `thanhngochoang`), not through `RUN-ORDER.md` and the `board` branch (both kept only as history):

- **What to do, in which order**: one issue per unit in the project, grouped by milestone (`Phase 1 · App trên Firebase`, `Phase 1.5 · Dashboard web`, `Phase 2 · Backend Go + PostgreSQL`, `Phase 3 · Tự host hoàn toàn & scale`) and ordered by the item's position on the board (the owner reorders priorities by dragging). Parent issues titled `[Phase …] …` only group units; they are never claimed. Dependencies are GitHub's "Blocked by" links. A unit is **runnable** when its issue is open, Status = Todo, it has the label **`plan-ready`** (its body names the plan: `Plan: docs/superpowers/plans/…`), and no issue blocking it is open. `needs-plan` (no plan yet: the plan-writing session handles it) and `non-code` (legal, partners, accounting) are never taken.
- **Who is doing what**: claiming pushes a **new** branch `plan/<issue>-<slug>` with `--force-with-lease=<branch>:`, which git refuses when the branch already exists; that refusal is the lock. The script then sets Status = In Progress and writes a machine-readable claim comment on the issue (machine name + branch). Later events (In Review with the PR, Done, release) are comments too, so the issue history is the board.

`project.py` lives next to this file: `python3 .claude/skills/run-next-plan/scripts/project.py <cmd>` from the repo root. It uses `gh` (the token needs the `project` scope: `gh auth refresh -s project`) and git plumbing; it never touches your checkout. It names the machine from `git config board.machine`, else macOS `LocalHostName`, else the hostname; `show` prints the name, and it must stay the same inside and outside the sandbox. If it prints something generic, set it once: `git config board.machine <name>`. Inside the Claude sandbox SSH to github.com is blocked: prefix it with `BOARD_GH=1` (HTTPS through `gh auth git-credential`) and pass `allowed_domains: ["github.com", "api.github.com"]`. Other `git fetch`/`push` calls in this skill use the same trick: `git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push https://github.com/thanhngochoang/booking.git <branch>`.

## 1. Read the project

```bash
BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/project.py show
```

It prints this machine's name, the active units (In Progress / In Review, with holder and branch) and the next runnable units. Also read the standing rules at the top of `docs/superpowers/plans/RUN-ORDER.md` on `origin/develop`.

Then, in this order:

1. **Clean up finished reviews.** For each issue In Review, look at its PR (`gh pr view <n> --json state`, the PR number is in the last run-next-plan comment). If it is `MERGED`, run `project.py set <issue> done --pr <n> --force` (any machine may do this: a merged PR is a fact, not a takeover).
2. **Resume before claiming.** If an In Progress issue is held by this machine, continue that unit: check out its branch and read its ledger. Check the ledger against the branch (`git log origin/develop..<branch>`, the files the finished tasks should have created) before trusting it; if they disagree, continue from what the branch really contains and tell the user. One machine works on one unit at a time.
3. **Choose the next unit.** Take the first runnable issue (`project.py next`, optionally `--milestone <n>`). If the user named an issue ("làm #35"), check it is runnable the same way; if it isn't, say what blocks it (label, Status, "Blocked by", holder) instead of starting anyway.

   Before claiming, compare the issue with `git log origin/develop` and the plan's tasks: if part of it is already merged, claim it but do only what remains, and say so in a comment. Redoing merged work is the most expensive mistake here.

   If nothing is runnable, stop and tell the user which units are held by whom and what the free ones wait on (`needs-plan`, blocked by #…). Don't invent work and don't take an issue without `plan-ready`. Claims older than ~2 days whose branch has no new commits are probably abandoned, but only the user can say so: report them, don't take them over.

## 2. Claim it

```bash
BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/project.py claim 35
```

The branch defaults to `plan/<issue>-<slug of the title>` (pass `--branch` to choose another).

- exit 0: the unit is yours; the output names the branch, which now exists on origin at `origin/develop`.
- exit 3: another machine got it first (the output says who). Go back to step 1.3 and pick again; this is the lock working, not an error.
- anything else: report it to the user. Never edit the project by hand to "fix" a claim, and never push to `develop` directly.

A released unit can be claimed again: its branch already exists, so the script continues on it and locks with the claim comment instead.

**Stack branch.** When the owner asked to collect units on one long-lived branch (memory: `plan/stack-2026-10`, CI through a draft PR), claim with `--stack --branch plan/stack-2026-10`: no new branch is pushed and the earliest claim comment wins a race. Commit each unit onto the stack branch, set the issue In Review with the stack PR number after the unit's final review, and Done when the stack PR merges.

## 3. Branch from develop

```bash
git fetch origin develop        # with the gh credential helper inside the sandbox
git switch -c plan/35-ca-chua-gach-domain origin/plan/35-ca-chua-gach-domain
```

If the working tree is dirty, stop and ask; it may be another session's work. Push after every task so other machines can see where the work is.

## 4. Implement, following the plan and the specs

Read these before writing code, because they are what reviewers hold the work to:

- the plan file named in the issue body (`Plan: docs/superpowers/plans/…`); when the issue lists tasks, only those tasks;
- `CLAUDE.md` (the "Flutter rewrite" part: rules, commands, sandbox and env setup) and the standing rules (kept in `docs/superpowers/plans/RUN-ORDER.md`): UI matches `docs/design/ui-mock.html`, specs decide behaviour; no battery/performance work, device builds or iOS-only steps inside feature plans (iOS steps go under "Deferred iOS steps" in `2026-10-01-ios-enablement.md`); Firestore/Storage rules tests are written but not run locally;
- the specs the plan points to: `docs/superpowers/specs/2026-10-01-remaining-screens.md`, `specs/screens/`, `specs/components/shared-components.md`, `specs/data-model/`;
- the ledgers in `docs/superpowers/handover/` for rulings earlier plans settled.

Execute the plan with the **superpowers:subagent-driven-development** skill (SDD; the run order says plans run that way): one implementer subagent per task, a review after each, one commit per task with a Conventional Commit message ending in `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (the owner's rule for every commit in this repo, instead of the Claude co-author line).

SDD is generic; inside a unit these points of this skill replace its defaults:

- **Workspace.** The `plan/…` branch from step 3 is the isolated workspace SDD's setup asks for; don't create another branch or worktree on top of it.
- **Ledger.** SDD's `sdd-workspace <plan>` prints `.superpowers/sdd/<plan-file-stem>/`. Inside it, name the ledger `progress-<branch-with-dashes>.md` instead of SDD's `progress.md` (one per branch, so two units of the same plan never share a ledger), with SDD's identity first line. Update it after every task with the commit ids. At the end, never `rm -rf` the workspace: it can hold another unit's ledger. Delete only your own files once the PR is open, after the rulings are copied into the handover ledger and the PR.
- **Unit scope.** When the issue names only some tasks of a plan, SDD's task list is only those tasks; the rest belong to other issues.
- **Commit trailer.** Plan snippets that end a commit with a `Co-Authored-By: Claude …` line are wrong for this repo: tell every implementer to use the TonyH line instead.
- **Pushing.** Pushing your own `plan/…` branch after each task is part of this skill, not a "push to a shared branch" that SDD stops for. Never push `develop` or `main`; the `board` branch is retired (read-only history).
- **Finish.** Step 5 below replaces `superpowers:finishing-a-development-branch`: don't offer its options (merge locally, keep, discard); the finish is always a PR into `develop`. SDD's "Rulings I made" list goes into the PR's **Rulings** section and the handover ledger.
- **What each implementer gets.** Subagents don't read CLAUDE.md by themselves, so every dispatch carries: the task text, the env setup from CLAUDE.md (`source ../scripts/env.sh`, project-local `HOME` and `PATH`, run from `app_flutter/`), the rules it touches (imports `package:photobooking/...` and `core/core.dart`; Firebase only in data adapters; strings in `app_vi.arb` + `flutter gen-l10n`; tokens via `AppColors`/`AppSpace`/`AppRadius`; one primary action per screen), the standing rules (no rules-emulator runs, no device builds, no battery work, iOS steps deferred), the commit trailer, and the skills from the next section that fit the task.

### Dart, Flutter and Firebase skills for implementers

The Dart and Firebase skills are installed in `.agents/skills/` (`skills-lock.json`); those that fit this project are linked into `.claude/skills/`, so subagents can load them with the Skill tool. Name the relevant ones in each implementer and reviewer dispatch:

| Task touches | Skill | Project rule that wins over the skill |
|---|---|---|
| any Dart/Flutter test | `dart-add-unit-test` | tests use `flutter_test`, `mocktail` and the fakes/worlds in `test/support/`; never add `mockito` or `build_runner` mocks |
| `flutter analyze` findings | `dart-run-static-analysis` | `dart fix --apply` is fine; don't change `analysis_options.yaml` |
| sealed types, JSON parsing, switch chains | `dart-use-pattern-matching` | — |
| public API doc comments | `dart-write-documentation` | match the surrounding comment density |
| `pub get` version conflicts | `dart-resolve-package-conflicts` | change `pubspec.yaml` only as the plan says; `pubspec.lock` is regenerated |
| Firestore queries, indexes, data adapters | `firebase-firestore` | Firestore code only in `lib/data/**` adapters and `firebase/functions`; never create databases or run `firebase` CLI commands against a real project |
| `firestore.rules` / `storage.rules` | `firestore-rules-creation`, then `firebase-security-rules-auditor` in the task review | write the rules tests, don't run them (CI does) |
| iOS project files (plan 15 only) | `xcode-project-setup` | iOS work stays in plan 15 |

Never deploy, log in to the Firebase CLI or create projects from a plan; CI deploys on merge. Not linked on purpose: `dart-generate-test-mocks` and `dart-migrate-to-checks-package` (they would rewrite the test style), `firebase-basics` and `firebase-auth-basics` (CLI login, project creation, `deploy --only auth`), `dart-fix-runtime-errors` (needs Dart MCP tools that aren't installed), and the FFI, CLI, Hosting, Data Connect, Crashlytics, Remote Config and AI Logic skills (not used by the app). Link one with `ln -s ../../.agents/skills/<name> .claude/skills/<name>` when a plan needs it.

When the plan and a spec or the mock disagree, follow CLAUDE.md (mock wins for layout/copy, spec for behaviour), record the ruling in the ledger and the PR. When a task needs a file that a unit held by another machine is changing (`project.py show` lists them with their branches), don't edit it: write the request in the ledger and in the PR description.

## 5. Finish: PR into develop

1. Verify on the branch with real output before claiming anything passes (superpowers:verification-before-completion): from `app_flutter/`, `flutter analyze && flutter test` (or `dart run tool/affected_test.dart origin/develop --run` for the affected tests first); `(cd ../packages/domain && npm test)` if the domain changed; `(cd firebase/functions && npm test)` if Functions changed (integration tests run outside the sandbox; say so if you could not run them).
2. In the branch, update what the plan says to update: the "Trạng thái" cells of `remaining-screens.md` for the screens it built and a handover ledger `docs/superpowers/handover/ledger-<plan>.md` (rulings, deferred items). Progress lives in the project now: don't edit `RUN-ORDER.md` rows.
3. Rebase onto the latest `origin/develop`, push, and open the PR:
   ```bash
   gh pr create --base develop --head plan/35-ca-chua-gach-domain --title "feat(review): tomato/brick domain, functions and SQL [#35]" --body "…"
   ```
   **PR title convention.** Every unit PR is titled `<type>(<scope>): <summary> [#<issue>]`, because the title becomes the squash commit's subject on `develop`, and `[#<issue>]` ties the history back to the project.
   - `type`: `feat` for new screens or behaviour, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `build`, `ci`. Choose by what the PR mostly does.
   - `scope`: one lowercase area, matching the commit scopes already in the log. Examples: `booking`, `chat`, `review`, `explore`, `profile`, `core`, `data`, `domain`, `functions`, `rules`, `api`, `l10n`.
   - `summary`: English, imperative or noun phrase, no final period. Put the screen codes first when the unit builds screens (`S05.01–S05.03 booking detail and lists`).
   - `[#<issue>]`: the issue number, e.g. `[#35]`. A stack PR that carries several issues lists them all in the body and uses the first in the title.
   - Keep it to about 90 characters.

   `land.py` refuses a title that doesn't follow this (exit 6). Fix it with `gh pr edit <n> --title "…"` and land again.

   The body uses these headings: **Unit** (`Closes #<issue>` plus the plan file; GitHub only auto-closes on the default branch, so `project.py` closes it on merge), **Tasks done**, **Tests** (commands and results), **Rulings** (mock vs spec decisions), **Deferred**, **Cross-unit requests**. It ends with the Claude Code attribution line.
4. Move the issue to review:
   ```bash
   BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/project.py set 35 review --pr 123
   ```
   In single mode, merging is the user's call: stop here. After the merge, the next `show` on any machine marks it Done (step 1.1). In continuous mode, go on to step 6.

Tell the user, in Vietnamese: the issue, the branch, the PR link, the test results, and anything left for them.

## 6. Landing (continuous mode only)

Merge your own PR only when nothing about it can hurt another machine's work. `scripts/land.py` checks this and does the merge. It refuses on its own if anything is off, so don't merge any other way and never use `gh pr merge --admin`.

```bash
BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/land.py 35 --pr 123
```

The gates, in order:
1. the PR is yours: open, `plan/…` → `develop`, and the issue's claim belongs to this machine on that branch;
2. the branch contains the latest `origin/develop`;
3. no file it changes is also changed on another machine's active branch (issues In Progress / In Review). `RUN-ORDER.md`, `app_vi.arb`, generated l10n and `pubspec.lock` are exempt, because they are append-only or regenerated;
4. every CI check on the PR passed (it waits while they run);
5. GitHub says it is mergeable and not blocked.

Then it squash-merges (the repository allows only squash merges), deletes the branch (not a stack branch), sets the issue Done and closes it.

What each exit code means and what to do:
- **2, behind or conflicting with develop**: `git fetch`, `git rebase origin/develop`, then resolve.
  - Conflicts in another unit's block of `app_vi.arb`: keep both sides, then run `flutter gen-l10n`.
  - Conflicts in real code that came from another unit's merged work: resolve them the way that code now expects. If you can't do that without changing that unit's files, stop and ask.

  Re-run `flutter analyze && flutter test`, `git push --force-with-lease` (your own branch only), and land again.
- **3, CI failed**: read the log (`gh run view --log-failed`), fix it with a new commit, push, and land again. After three failed fixes, stop and report.
- **4, overlap with another machine's branch**: don't merge, and don't edit their files. Usually the other unit has to land first.
  1. Note the overlap in your PR and ledger.
  2. Keep the issue In Review.
  3. Wait with `project.py watch` until that unit is done.
  4. Rebase onto develop and land again.

  If the overlap means the plans themselves collide (both really change the same logic), stop and ask the user.
- **6, the title doesn't follow the convention**: run `gh pr edit <n> --title "<type>(<scope>): <summary> [#<issue>]"`, then land again.
- **5, blocked by branch rules or the merge was refused** (e.g. a review is now required): stop. Tell the user the PR link and leave the issue In Review.

## Continuous mode: keep going until the scope is done

Use this when the user asks for it: "làm liên tục", "chạy tự động đến hết", "tự merge rồi làm tiếp", "làm hết Phase 1", "làm đến hết cà chua/gạch", or similar. The scope can be a milestone (`--milestone`), a parent issue (its sub-issues) or a list of issues. With no scope, keep going until nothing runnable is left. Issues without `plan-ready` are never taken automatically.

The loop:
1. Run steps 1–5, then land the PR (step 6).
2. Once it has merged, go back to step 1 on the fresh `develop`. Prefer the next sub-issue of the same parent, so the files you touch stay together, then the next runnable issue in the scope.
3. **If nothing in scope is runnable yet but other machines still hold units**: don't stop and don't take work out of order. Wait for the project or develop to change:
   ```bash
   BOARD_GH=1 python3 .claude/skills/run-next-plan/scripts/project.py watch --timeout 1800
   ```
   Run it in the background and act when it exits. On a timeout, check again. After about 3 hours with no change, stop and report who holds what.
4. Stop and report when any of these happens:
   - the scope is finished, or nothing is runnable and no other machine holds a unit;
   - a unit needs something only the user can give (keys, a spec or mock decision, a device);
   - the plan and the spec/mock disagree in a way CLAUDE.md does not settle;
   - tests keep failing after three real attempts;
   - a landing exits with 5.

After each landed unit, post a short progress line in Vietnamese: issue, PR link, tests, and what comes next. When stopping, give a summary: what landed (with PR links), what is left and who holds it, and why you stopped.

Keep each unit's work inside subagents (subagent-driven development) and keep the main thread to the project, git and short summaries. That lets one session carry many units without running out of context.

## Other commands

- Give a unit up (the user stopped it, or it was claimed by mistake): `project.py release <issue> --note "<what is half done, where the branch is>"`. Status goes back to Todo; the branch stays for whoever continues.
- `set`/`release` refuse another machine's unit without `--force`. Use `--force` only for a merged PR (step 1.1) or when the user explicitly says to.
- `BOARD_MACHINE=<name>` overrides the machine name, e.g. to run two sessions on one computer as separate machines.
- Plan writers mark a unit ready by adding `Plan: docs/superpowers/plans/<file>.md` to the issue body, the label `plan-ready` (removing `needs-plan`), and "Blocked by" links for its dependencies.

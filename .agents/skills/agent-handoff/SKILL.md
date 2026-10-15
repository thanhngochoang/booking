---
name: agent-handoff
description: Use at the start of any multi-step task in this repo (editing files, running several commands, executing a plan or issue), and whenever work may have been left half-done by another agent or session — the user says "tiếp tục", "làm tiếp phần agent trước", "agent kia bị dừng/crash/hết token", "continue where it stopped", "resume", "pick up the unfinished task", or a branch has uncommitted changes nobody explained. Works for Claude Code, Codex, Gemini, Cursor or any agent that can run Python 3 or edit Markdown.
---

# Agent handoff log

## Overview

Every agent keeps a step log for its task so that, if it is stopped mid-way (crash, token limit, user closes the session), another agent can read where it was and continue without redoing or breaking work. **Commits are the truth for what was done; the log is the truth for what was intended, decided and in flight.**

The log is one Markdown file per task in `<main checkout>/.agents/handoff/<branch-with-dashes>.md`, gitignored and shared by every worktree. The helper keeps the format; any agent can also read or edit the file by hand.

```bash
H=".agents/skills/agent-handoff/scripts/handoff.py"   # from the repo or worktree root
python3 $H --help
```

Set your name once: `export HANDOFF_AGENT=<tool>-<short-session-id>` (or pass `--agent`), so the next agent knows who wrote what.

## First: is there a log already?

```bash
python3 $H list      # all logs: status, steps done, owner, last update
python3 $H status    # log for the current branch + live git state
```

- Active log for your branch, written by someone else → **Take over** below.
- Nothing, or only `done` logs → **Keep the log** below.

## Keep the log

1. `start "<goal>" --step "..." --step "..." [--plan <plan or ledger path>] [--issue N]`. Steps = your task list, in order; add more later with `steps "..."`.
2. Before each step: `begin N --now "<the concrete action, and how to tell it finished>"`.
   Example: `begin 3 --now "add SpotRepository.watch + test; done when flutter test test/spots passes and is committed"`.
3. After the step has landed (committed, if it changed code): `done N --note "<result, test numbers>"`. The HEAD commit is recorded.
4. Right away, without waiting for the step to end:
   - `note "..."` for every decision, ruling, gotcha, or side effect that must not be repeated (pushed branch, opened PR #, ran a migration/seed, posted a comment, deployed).
   - `now "..."` before any long or irreversible command, so the next agent knows to check whether it ran.
5. At the end: `close` (finished) or `close --state paused --note "<why, what is next>"`.

Two tasks on one branch: give each its own `--task <slug>`. Never commit `.agents/handoff/`.

## Take over

1. `status` and read all of it: Steps, Now, Notes, Journal, then the live git state block.
2. If it prints `may still be running`: ask the user whether that agent has stopped. Do not run two agents on one checkout.
3. `resume` (add `--force` only after the user confirmed). This makes you the owner and logs the takeover.
4. **Reconcile before you continue.** The previous agent may have died between acting and logging, so the log lags reality:
   - The `[~]` step and the **Now** text tell you what was in flight. Check the evidence: uncommitted files (`git diff`), commits since start, the remote (`git log @{u}`, `gh pr list --head <branch>`).
   - Finished and its done-when check holds → `done N --note "found done on takeover"`.
   - Committed but the done-when is not met (e.g. code without its test) → leave it `[~]` and `note` what is left.
   - Half-done uncommitted changes → read the diff and finish them; discarding (`git restore`, deleting an untracked file) needs the user's OK.
   - Work already started on a later step → `note` it; `begin` that step only after the current one is done (one `[~]` at a time).
   - Claims you can check cheaply ("tests 3/3") → rerun them before building on them.
   - Every side effect in Notes/Now (push, PR, seed, deploy, comment) → confirm whether it happened before running it again.
5. Tell the user in two or three lines what was done, what you found half-done, and where you continue (if you run delegated with no user, put this and any questions in your report). Then keep the log as above; if you are not going to continue, `close --state paused --note "<next action>"` (the note becomes Now).

## Quick reference

| Situation | Command |
|---|---|
| New task | `start "goal" --step a --step b` |
| Starting step N | `begin N --now "action + done-when"` |
| Step N landed | `done N --note "..."` |
| Decision / side effect | `note "..."` |
| About to run something long or irreversible | `now "..."` |
| Anything else worth a line | `log "..."` |
| Stopping on purpose | `close --state paused --note "next: ..."` |

Steps use `- [ ]` todo, `- [~]` in progress, `- [x]` done (`_(sha)_` = HEAD then). Without Python, edit the file in that format and append a Journal line `- <UTC time> <agent> [<sha>] <text>`.

## With other project workflows

- **run-next-plan / subagent-driven-development**: the SDD ledger (`.superpowers/sdd/.../progress-<branch>.md`) stays the record of plan tasks and rulings. Pass its path with `--plan`; make the handoff steps the unit's phases (claim, tasks 1–N, PR, land) so the log says where in the unit you are.
- **Claude Code task list (`update_plan`/TodoWrite)**: mirror the same steps; the handoff log is the copy that survives the session.

## Common mistakes

- Logging only after a step: a crash between doing and logging leaves the next agent blind. Write `begin`/`now` first.
- Vague Now ("working on UI"): name the file, command and the done-when check.
- Trusting the log over git on takeover: always reconcile with the live state block.
- Taking over a log updated minutes ago without asking: two agents on one checkout overwrite each other.

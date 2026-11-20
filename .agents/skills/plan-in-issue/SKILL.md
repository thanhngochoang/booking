---
name: plan-in-issue
description: Where implementation plans live in this project — in their GitHub issue, never as files in the repo. Use whenever you write, update, publish or read a plan for a unit on Project 4 ("viết plan #175", "lên plan cho cụm tiền", "write the plan for issue 180", "đọc plan của #177"), including when superpowers:writing-plans tells you to save to docs/superpowers/plans/ — this skill overrides that location. Also use when run-next-plan needs the plan of the unit it claimed.
---

# Plans live in their issue

Since 2026-11-20 (owner) a plan is **not** a file in the repo. It lives in the issue of the unit it
implements, so it is in effect the moment it is published: no docs PR, no wait for a merge into
`develop`, and every machine and subagent reads the same text with `gh`. `docs/superpowers/plans/`
keeps only the plans written before that date (history, and the units still running from them).

Specs, the data model, mocks and ledgers stay in the repo as before; only plans moved.

## Writing a plan

1. Write it with **superpowers:writing-plans** as usual (header, Global Constraints, Review Focus,
   `### Task N:` sections). Override its "Save plans to": draft it in the session's scratchpad or
   `$TMPDIR` (outside the repo), e.g. `$TMPDIR/plan-175.md`. Never create it under `docs/`, never
   commit it. In the header, the **Spec:** line points to the spec in the repo (or to its issue), and
   add `**Issue:** #<n>`.
2. Check the split offline (no network):
   ```bash
   python3 .agents/skills/plan-in-issue/scripts/plan_issue.py check "$TMPDIR/plan-175.md"
   ```
   It splits the plan into the issue body (header + index) and one comment per task, splits a task
   longer than one comment at blank lines, and verifies the pieces join back to the exact file.
3. Publish (gh needs the sandbox off, it reads the keychain):
   ```bash
   python3 .agents/skills/plan-in-issue/scripts/plan_issue.py publish 175 "$TMPDIR/plan-175.md"
   ```
   The issue body keeps its text and gets `Plan: in this issue (plan-in-issue)` plus the plan block;
   each task becomes a comment starting with `<!-- plan-part {...} -->`. The label `plan-ready`
   replaces `needs-plan` (`--draft` keeps `needs-plan`, for a plan still under review). The script
   reads the plan back from GitHub and fails if it differs from the file.
4. Add the "Blocked by" links for the unit's dependencies (run-next-plan only takes unblocked
   units), then delete the draft file.

Several plans can be written in parallel by separate subagents: each publishes to its own issue,
and nothing waits on another plan's PR. When plans share interfaces (a table, an endpoint, a job
name), the shared names come from the spec, not from another plan still being written.

## Changing a published plan

Fetch it, edit the copy, publish again to the same issue:

```bash
python3 .agents/skills/plan-in-issue/scripts/plan_issue.py fetch 175 --out "$TMPDIR/plan-175.md"
# edit
python3 .agents/skills/plan-in-issue/scripts/plan_issue.py publish 175 "$TMPDIR/plan-175.md"
```

`publish` edits the existing plan comments in place, adds or deletes comments when the number of
pieces changes, and rewrites the index. GitHub keeps every comment's edit history. If the unit is
already claimed, say what changed in a normal comment on the issue as well, so the machine running
it notices. Never hand-edit a plan comment's first line (the marker).

## Reading a plan

```bash
python3 .agents/skills/plan-in-issue/scripts/plan_issue.py fetch 175                 # to stdout
python3 .agents/skills/plan-in-issue/scripts/plan_issue.py fetch 175 --out "$TMPDIR/plan-175.md"
```

The output is the whole plan, the same Markdown superpowers:writing-plans produced, so
subagent-driven development and executing-plans read it unchanged. Write it outside the repo
(scratchpad, `$TMPDIR`, or the SDD workspace if that is gitignored), never under `docs/`.

## Limits and rules

- GitHub refuses an issue body or comment over 65,536 characters; the script keeps every piece
  under 60,000 and refuses an issue body that would still be too long.
- The booking repo is **public**: plans are readable by anyone, as the old plan files were. A plan
  for a security fix or anything that describes an exploitable weakness goes in the private
  booking-be repo's issue instead (`PROJECT_REPO=thanhngochoang/booking-be`), like the security
  issues themselves.
- One plan per issue. A plan that covers several units goes in the first unit's issue; the other
  issues say `Plan: in #<n>, tasks …` in their body (run-next-plan then runs only those tasks).

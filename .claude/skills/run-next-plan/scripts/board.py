#!/usr/bin/env python3
"""Claim board for parallel plan execution across machines.

`develop` is protected (changes land only through PRs), so the board lives on
its own branch, `board`, which holds a single file, CLAIMS.md. Every write is
one commit built with git plumbing (no checkout, the working tree is never
touched) and pushed to origin/board. A push rejected because another machine
pushed first is retried on the fresh board; that rejection is the lock, so two
machines can never claim the same unit. The plan list itself (the "To run"
table of RUN-ORDER.md) is read from origin/develop.

Usage:
  board.py show                         claims (origin/board) + "To run" (origin/develop)
  board.py claim <id> --branch <b>      claim a unit (exit 3 if someone holds it)
  board.py set <id> <state> [--pr N]    change the state of a claim ("in review", "done")
  board.py release <id> [--note TEXT]   drop a claim (abandoned work)
  board.py watch [--timeout S]          wait until the board or develop changes (exit 1 on timeout)

<id> is the "#" of a row in the "To run" table (e.g. 8b, 9) or, for plans
split into lanes, "<#>/<step>-L<lane>" (e.g. 8a2/2-L1).

Env:
  BOARD_REMOTE   remote name (default origin)
  BOARD_BRANCH   board branch (default board)
  BOARD_BASE     branch holding RUN-ORDER.md (default develop)
  BOARD_MACHINE  machine name (default: macOS LocalHostName or hostname)
  BOARD_GH=1     fetch/push over HTTPS with gh's credential helper (use when
                 SSH to github.com is blocked, e.g. inside the Claude sandbox)
"""
import argparse
import datetime
import os
import re
import shutil
import socket
import subprocess
import sys

RUN_ORDER = "docs/superpowers/plans/RUN-ORDER.md"
FILE = "CLAIMS.md"
REMOTE = os.environ.get("BOARD_REMOTE", "origin")
BRANCH = os.environ.get("BOARD_BRANCH", "board")
BASE = os.environ.get("BOARD_BASE", "develop")
ACTIVE = ("in progress", "in review")
HEADER = f"""# Claims

Which machine is working on which unit of `{RUN_ORDER}` (on `{BASE}`).
Written only by `.claude/skills/run-next-plan/scripts/board.py`; do not edit by hand.
One line per unit: id · state · branch · machine · last update.

## Active
"""


def sh(*args, check=True, stdin=None):
    r = subprocess.run(args, text=True, capture_output=True, input=stdin)
    if check and r.returncode != 0:
        sys.exit(f"error: {' '.join(args)}\n{r.stdout}{r.stderr}")
    return r


def machine():
    if os.environ.get("BOARD_MACHINE"):
        return os.environ["BOARD_MACHINE"]
    if shutil.which("scutil"):
        r = sh("scutil", "--get", "LocalHostName", check=False)
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    return socket.gethostname().split(".")[0]


def auth():
    if os.environ.get("BOARD_GH") == "1":
        return ["-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential"]
    return []


def target():
    if os.environ.get("BOARD_GH") != "1":
        return REMOTE
    url = sh("git", "remote", "get-url", REMOTE).stdout.strip()
    m = re.match(r"git@([^:]+):(.+)", url)
    return f"https://{m.group(1)}/{m.group(2)}" if m else url


def fetch():
    """Refresh origin/<board> (may not exist yet) and origin/<base>."""
    sh("git", *auth(), "fetch", "-q", target(), f"+{BASE}:refs/remotes/{REMOTE}/{BASE}")
    r = sh("git", *auth(), "fetch", "-q", target(), f"+{BRANCH}:refs/remotes/{REMOTE}/{BRANCH}", check=False)
    if r.returncode != 0:
        if "couldn't find remote ref" not in r.stderr:
            sys.exit(f"error: fetch {BRANCH}\n{r.stderr}")
        sh("git", "update-ref", "-d", f"refs/remotes/{REMOTE}/{BRANCH}", check=False)
        return None
    return sh("git", "rev-parse", f"refs/remotes/{REMOTE}/{BRANCH}").stdout.strip()


def read_board(head):
    if not head:
        return HEADER + "\n## Finished\n"
    return sh("git", "show", f"{head}:{FILE}").stdout


def parse(text):
    """{id: dict(state, branch, machine, date)} from the Active section."""
    claims = {}
    active = text.split("## Active", 1)[1].split("## Finished", 1)[0] if "## Active" in text else ""
    for line in active.strip().splitlines():
        parts = [p.strip().strip("`") for p in line.lstrip("- ").split(" · ")]
        if len(parts) >= 5:
            cid, state, branch, mach, date = parts[:5]
            claims[cid] = dict(state=state, branch=branch, machine=mach, date=date)
    return claims


def line(cid, c):
    return f"- `{cid}` · {c['state']} · `{c['branch']}` · {c['machine']} · {c['date']}"


def render(text, claims, finished=None):
    old_finished = text.split("## Finished", 1)[1].strip() if "## Finished" in text else ""
    done = ([line(*finished)] if finished else []) + ([old_finished] if old_finished else [])
    body = "\n".join(line(cid, c) for cid, c in claims.items())
    return HEADER + (body + "\n" if body else "") + "\n## Finished\n" + ("\n".join(done) + "\n" if done else "")


def transact(mutate, message, attempts=8):
    """mutate(text) -> new text or None; commit on top of origin/board and push; retry on race."""
    for _ in range(attempts):
        head = fetch()
        text = read_board(head)
        new = mutate(text)
        if new is None or new == text:
            return False
        blob = sh("git", "hash-object", "-w", "--stdin", stdin=new).stdout.strip()
        tree = sh("git", "mktree", stdin=f"100644 blob {blob}\t{FILE}\n").stdout.strip()
        commit = sh("git", "commit-tree", tree, *(["-p", head] if head else []), "-m", message).stdout.strip()
        r = sh("git", *auth(), "push", "-q", target(), f"{commit}:refs/heads/{BRANCH}", check=False)
        if r.returncode == 0:
            fetch()
            return True
        if not re.search(r"rejected|fetch first|non-fast-forward|stale info|already exists", r.stderr):
            sys.exit(f"error: push to {BRANCH} failed\n{r.stderr}")
    sys.exit(f"error: {BRANCH} kept moving; gave up after {attempts} attempts")


def today():
    return datetime.date.today().isoformat()


def cmd_show(_):
    head = fetch()
    claims = parse(read_board(head))
    print(f"machine: {machine()}\n\nclaims on {REMOTE}/{BRANCH}:")
    for cid, c in claims.items():
        print(f"  {cid:12} {c['state']:24} {c['branch']:40} {c['machine']:20} {c['date']}")
    if not claims:
        print("  (none)" + ("" if head else f"  [{BRANCH} branch not created yet]"))
    runorder = sh("git", "show", f"{REMOTE}/{BASE}:{RUN_ORDER}").stdout
    m = re.search(r"## To run\n(.*?)(\n## |\Z)", runorder, re.S)
    if m:
        print(f"\nTo run ({REMOTE}/{BASE}):\n" + m.group(1).strip())


def guard(c, me, force):
    if c["machine"] != me and not force:
        sys.exit(f"error: held by {c['machine']}; pass --force only for a merged PR or when the user said so")


def cmd_claim(a):
    me, out = machine(), {}

    def mutate(text):
        claims = parse(text)
        held = claims.get(a.id)
        if held and held["state"].startswith(ACTIVE):
            out["held"] = held
            return None
        claims[a.id] = dict(state="in progress", branch=a.branch, machine=me, date=today())
        return render(text, claims)

    if transact(mutate, f"claim {a.id} on {me} ({a.branch})"):
        print(f"claimed {a.id} -> {a.branch} on {me}")
        return
    h = out.get("held")
    if h:
        print(f"already claimed: {a.id} is {h['state']} on {h['machine']} ({h['branch']}, {h['date']})")
        sys.exit(3)
    sys.exit("error: nothing changed")


def cmd_set(a):
    me = machine()
    state = a.state + (f" (PR #{a.pr})" if a.pr else "")

    def mutate(text):
        claims = parse(text)
        c = claims.get(a.id)
        if not c:
            sys.exit(f"error: no claim for {a.id}")
        guard(c, me, a.force)
        c.update(state=state, date=today())
        if state.startswith("done"):
            return render(text, {k: v for k, v in claims.items() if k != a.id}, (a.id, c))
        return render(text, claims)

    transact(mutate, f"{a.id}: {state}")
    print(f"{a.id}: {state}")


def cmd_release(a):
    me = machine()

    def mutate(text):
        claims = parse(text)
        c = claims.get(a.id)
        if not c:
            return None
        guard(c, me, a.force)
        c.update(state="released" + (f": {a.note}" if a.note else ""), date=today())
        return render(text, {k: v for k, v in claims.items() if k != a.id}, (a.id, c))

    print(f"released {a.id}" if transact(mutate, f"release {a.id}") else f"{a.id} was not claimed")


def cmd_watch(a):
    """Block until origin/board or origin/<base> moves (exit 0) or the timeout passes (exit 1)."""
    import time

    def heads():
        b = fetch()
        return b, sh("git", "rev-parse", f"refs/remotes/{REMOTE}/{BASE}").stdout.strip()

    start, deadline = heads(), time.time() + a.timeout
    while time.time() < deadline:
        time.sleep(a.every)
        now = heads()
        if now != start:
            print(f"changed: board {start[0]} -> {now[0]}, {BASE} {start[1][:7]} -> {now[1][:7]}")
            return
    print(f"no change in {a.timeout}s")
    sys.exit(1)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("show")
    w = sub.add_parser("watch"); w.add_argument("--timeout", type=int, default=1800); w.add_argument("--every", type=int, default=60)
    c = sub.add_parser("claim"); c.add_argument("id"); c.add_argument("--branch", required=True)
    s = sub.add_parser("set"); s.add_argument("id"); s.add_argument("state"); s.add_argument("--pr"); s.add_argument("--force", action="store_true")
    r = sub.add_parser("release"); r.add_argument("id"); r.add_argument("--note"); r.add_argument("--force", action="store_true")
    a = p.parse_args()
    {"show": cmd_show, "watch": cmd_watch, "claim": cmd_claim, "set": cmd_set, "release": cmd_release}[a.cmd](a)


if __name__ == "__main__":
    main()

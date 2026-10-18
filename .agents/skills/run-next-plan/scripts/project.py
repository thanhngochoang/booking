#!/usr/bin/env python3
"""Work queue for parallel plan execution, backed by GitHub Project 4.

What to do and in which order lives in the GitHub Project (owner
thanhngochoang, number 4): one issue per unit, ordered by milestone (Phase 1,
1.5, 2, 3) and then by the item's position on the board. A unit is runnable
when its issue is open, its Status is Todo, it carries the label `plan-ready`,
and no issue it is "blocked by" is still open.

Who holds what: claiming a unit
  * pushes a new branch plan/<issue>-<slug> created from origin/develop with
    --force-with-lease=<branch>: (the push only succeeds when the branch does
    not exist yet, so a second machine is refused: that refusal is the lock), or
    with --stack, reuses an existing long-lived branch (e.g. plan/stack-2026-10)
    and locks with a claim comment that is re-read to break races;
  * sets the item's Status to In Progress;
  * writes a machine-readable claim comment on the issue
    (<!-- run-next-plan {"event": "claim", ...} -->).
Every later event (review, done, release) is another such comment, so the issue
history is the board.

Usage:
  project.py show                          this machine, active units, next runnable units
  project.py next [--milestone N]          print the first runnable issue number (exit 1 if none)
  project.py claim <issue> [--branch B] [--stack]
                                           claim a unit (exit 3 if someone holds it)
  project.py set <issue> review --pr N     Status In Review
  project.py set <issue> done --pr N       Status Done, close the issue
  project.py release <issue> [--note T]    Status Todo, branch kept
  project.py watch [--timeout S]           wait until the project or develop changes (exit 1 on timeout)

Env: same as the old board.py: BOARD_REMOTE (origin), BOARD_BASE (develop),
BOARD_MACHINE, BOARD_GH=1 (git over HTTPS through gh, needed inside the Claude
sandbox). PROJECT_OWNER / PROJECT_NUMBER / PROJECT_REPO override the defaults.
"""
import argparse
import datetime
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time

REMOTE = os.environ.get("BOARD_REMOTE", "origin")
BASE = os.environ.get("BOARD_BASE", "develop")
OWNER = os.environ.get("PROJECT_OWNER", "thanhngochoang")
NUMBER = int(os.environ.get("PROJECT_NUMBER", "4"))
REPO = os.environ.get("PROJECT_REPO", "thanhngochoang/booking")
READY = "plan-ready"
MARK = "<!-- run-next-plan "
ACTIVE = ("In Progress", "In Review")


def sh(*args, check=True, stdin=None):
    r = subprocess.run(args, text=True, capture_output=True, input=stdin)
    if check and r.returncode != 0:
        sys.exit(f"error: {' '.join(args[:6])}\n{r.stdout}{r.stderr}")
    return r


def machine():
    if os.environ.get("BOARD_MACHINE"):
        return os.environ["BOARD_MACHINE"]
    r = sh("git", "config", "--get", "board.machine", check=False)
    if r.returncode == 0 and r.stdout.strip():
        return r.stdout.strip()
    # Inside the Claude sandbox scutil cannot reach configd and prints "Unknown".
    if shutil.which("scutil"):
        r = sh("scutil", "--get", "LocalHostName", check=False)
        name = r.stdout.strip()
        if r.returncode == 0 and name and name != "Unknown":
            return name
    name = socket.gethostname().split(".")[0]
    if not name or name in ("localhost", "Unknown"):
        sys.exit("error: cannot tell this machine's name; set it once with "
                 "git config board.machine <name> (or BOARD_MACHINE=<name>)")
    return name


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


def fetch_base():
    sh("git", *auth(), "fetch", "-q", target(), f"+{BASE}:refs/remotes/{REMOTE}/{BASE}")
    return sh("git", "rev-parse", f"refs/remotes/{REMOTE}/{BASE}").stdout.strip()


def gh_json(*args):
    for attempt in range(3):
        r = sh("gh", *args, check=False)
        if r.returncode == 0:
            return json.loads(r.stdout or "null")
        if not re.search(r"502|Bad Gateway|timeout|EOF|unknown owner type", r.stderr):
            break
        time.sleep(2 + 3 * attempt)
    sys.exit(f"error: gh {' '.join(args[:4])}\n{r.stderr}")


def graphql(query, **variables):
    args = ["api", "graphql", "-f", f"query={query}"]
    for k, v in variables.items():
        args += ["-F" if isinstance(v, int) else "-f", f"{k}={v}"]
    return gh_json(*args)["data"]


ITEMS = """
query($owner: String!, $number: Int!, $after: String) {
  user(login: $owner) { projectV2(number: $number) {
    id
    field(name: "Status") { ... on ProjectV2SingleSelectField { id options { id name } } }
    items(first: 100, after: $after, orderBy: {field: POSITION, direction: ASC}) {
      pageInfo { hasNextPage endCursor }
      nodes { id updatedAt
        status: fieldValueByName(name: "Status") { ... on ProjectV2ItemFieldSingleSelectValue { name } }
        content { ... on Issue { number title state url
          milestone { number title }
          labels(first: 20) { nodes { name } }
          repository { nameWithOwner } } } } } } }
}"""


def project():
    """(project id, status field, [items in board order])."""
    items, after, proj = [], "", None
    while True:
        vars_ = dict(owner=OWNER, number=NUMBER)
        if after:
            vars_["after"] = after
        proj = graphql(ITEMS, **vars_)["user"]["projectV2"]
        for n in proj["items"]["nodes"]:
            c = n.get("content") or {}
            if not c.get("number") or c["repository"]["nameWithOwner"] != REPO:
                continue
            items.append(dict(
                item=n["id"], updated=n["updatedAt"], status=(n.get("status") or {}).get("name") or "",
                number=c["number"], title=c["title"], state=c["state"], url=c["url"],
                milestone=(c.get("milestone") or {}).get("number") or 99,
                labels=[x["name"] for x in c["labels"]["nodes"]]))
        page = proj["items"]["pageInfo"]
        if not page["hasNextPage"]:
            break
        after = page["endCursor"]
    return proj["id"], proj["field"], items


def find(items, number):
    for it in items:
        if it["number"] == number:
            return it
    sys.exit(f"error: issue #{number} is not in project {NUMBER}")


def set_status(pid, field, it, name):
    opt = next((o["id"] for o in field["options"] if o["name"] == name), None)
    if not opt:
        sys.exit(f"error: project Status has no option {name!r}")
    gh_json("project", "item-edit", "--id", it["item"], "--project-id", pid,
            "--field-id", field["id"], "--single-select-option-id", opt, "--format", "json")


def events(number):
    """run-next-plan events on an issue, oldest first."""
    comments = gh_json("api", f"repos/{REPO}/issues/{number}/comments?per_page=100")
    out = []
    for c in comments or []:
        body = c.get("body") or ""
        i = body.find(MARK)
        if i < 0:
            continue
        try:
            ev = json.loads(body[i + len(MARK):body.index("-->", i)].strip())
        except ValueError:
            continue
        ev["at"] = c["created_at"]
        ev["comment"] = c["id"]
        out.append(ev)
    return out


def holder(number):
    """The active claim of an issue (dict with machine, branch, ...) or None."""
    claim = None
    for ev in events(number):
        if ev.get("event") == "claim" and claim is None:
            claim = ev
        elif ev.get("event") in ("release", "done") and claim is not None:
            claim = None
    return claim


def comment(number, event, text, **fields):
    payload = json.dumps(dict(event=event, **fields), ensure_ascii=False)
    sh("gh", "issue", "comment", str(number), "--repo", REPO, "--body", f"{text}\n\n{MARK}{payload} -->")


def blockers(number):
    r = sh("gh", "api", f"repos/{REPO}/issues/{number}/dependencies/blocked_by", check=False)
    if r.returncode != 0:
        return []
    return [f"#{b['number']}" for b in json.loads(r.stdout or "[]") if b.get("state") == "open"]


def is_epic(it):
    """Parent issues group units ("[Phase 1] …"); they are never claimed."""
    return it["title"].startswith("[Phase")


def runnable(items, milestone=None):
    for it in sorted(items, key=lambda x: x["milestone"]):  # stable: keeps board order inside a milestone
        if is_epic(it) or (milestone and it["milestone"] != milestone):
            continue
        if it["state"] != "OPEN" or it["status"] != "Todo" or READY not in it["labels"]:
            continue
        if blockers(it["number"]):
            continue
        yield it


def slug(title):
    import unicodedata
    t = unicodedata.normalize("NFKD", title.replace("đ", "d").replace("Đ", "D"))
    t = "".join(ch for ch in t if not unicodedata.combining(ch)).lower()
    return "-".join(re.findall(r"[a-z0-9]+", t))[:40].strip("-")


def today():
    return datetime.date.today().isoformat()


def cmd_show(a):
    _, _, items = project()
    print(f"machine: {machine()}\nproject: https://github.com/users/{OWNER}/projects/{NUMBER}\n\nactive:")
    act = [it for it in items if it["status"] in ACTIVE and it["state"] == "OPEN" and not is_epic(it)]
    for it in act:
        h = holder(it["number"]) or {}
        print(f"  #{it['number']:<4} {it['status']:12} {h.get('branch', '?'):34} {h.get('machine', '?'):18} {it['title']}")
    if not act:
        print("  (none)")
    print("\nnext runnable (plan-ready, Todo, not blocked):")
    shown = 0
    for it in runnable(items):
        print(f"  #{it['number']:<4} M{it['milestone']}  {it['title']}")
        shown += 1
        if shown >= a.limit:
            break
    if not shown:
        todo = [it for it in items if it["status"] == "Todo" and it["state"] == "OPEN"]
        print(f"  (none; {len(todo)} Todo items lack the {READY} label or are blocked)")


def cmd_next(a):
    _, _, items = project()
    for it in runnable(items, a.milestone):
        print(it["number"])
        return
    sys.exit(1)


def cmd_claim(a):
    me = machine()
    pid, field, items = project()
    it = find(items, a.issue)
    h = holder(a.issue)
    if it["state"] != "OPEN" or it["status"] in ACTIVE or h:
        who = h["machine"] if h else "?"
        print(f"already taken: #{a.issue} is {it['state']}/{it['status']} (holder {who})")
        sys.exit(3)
    branch = a.branch or f"plan/{a.issue}-{slug(it['title'])}"
    if not a.stack:
        base = fetch_base()
        r = sh("git", *auth(), "push", "-q", f"--force-with-lease=refs/heads/{branch}:", target(),
               f"{base}:refs/heads/{branch}", check=False)
        if r.returncode != 0:
            if not re.search(r"stale info|rejected|already exists", r.stderr):
                sys.exit(f"error: push {branch}\n{r.stderr}")
            # The branch exists but nobody holds the issue (it was released):
            # continue on it, locked by the claim comment like a stack branch.
            print(f"branch {branch} already exists (released earlier); continuing on it")
    comment(a.issue, "claim", f"Máy **{me}** nhận việc này, nhánh `{branch}` ({today()}).",
            machine=me, branch=branch, stack=bool(a.stack))
    # Without a fresh git lock (stack branch, or a released unit's branch) the
    # earliest claim comment wins.
    h = holder(a.issue)
    if h and h.get("machine") != me:
        mine = [e for e in events(a.issue) if e.get("event") == "claim" and e.get("machine") == me][-1]
        sh("gh", "api", "-X", "DELETE", f"repos/{REPO}/issues/comments/{mine['comment']}", check=False)
        print(f"already taken: {h['machine']} claimed #{a.issue} first")
        sys.exit(3)
    set_status(pid, field, it, "In Progress")
    print(f"claimed #{a.issue} -> {branch} on {me}")


def guard(number, force):
    h = holder(number)
    if h and h.get("machine") != machine() and not force:
        sys.exit(f"error: #{number} is held by {h['machine']}; pass --force only for a merged PR "
                 "or when the user said so")
    return h


def cmd_set(a):
    pid, field, items = project()
    it = find(items, a.issue)
    h = guard(a.issue, a.force) or {}
    pr = f" (PR #{a.pr})" if a.pr else ""
    if a.state == "review":
        set_status(pid, field, it, "In Review")
        comment(a.issue, "review", f"Đã mở PR{pr}, chờ merge.", machine=machine(), pr=a.pr,
                branch=h.get("branch"))
    elif a.state == "done":
        set_status(pid, field, it, "Done")
        comment(a.issue, "done", f"Xong{pr}.", machine=machine(), pr=a.pr, branch=h.get("branch"))
        if it["state"] == "OPEN":
            sh("gh", "issue", "close", str(a.issue), "--repo", REPO, "--reason", "completed")
    else:
        sys.exit("error: state must be review or done (use release to give a unit up)")
    print(f"#{a.issue}: {a.state}{pr}")


def cmd_release(a):
    pid, field, items = project()
    it = find(items, a.issue)
    h = guard(a.issue, a.force)
    set_status(pid, field, it, "Todo")
    note = f": {a.note}" if a.note else ""
    comment(a.issue, "release", f"Trả việc{note}. Nhánh `{(h or {}).get('branch', '?')}` giữ nguyên.",
            machine=machine(), note=a.note or "")
    print(f"released #{a.issue}")


def cmd_watch(a):
    def snap():
        _, _, items = project()
        return max((it["updated"] for it in items), default=""), fetch_base()

    start, deadline = snap(), time.time() + a.timeout
    while time.time() < deadline:
        time.sleep(a.every)
        now = snap()
        if now != start:
            print(f"changed: project {start[0]} -> {now[0]}, {BASE} {start[1][:7]} -> {now[1][:7]}")
            return
    print(f"no change in {a.timeout}s")
    sys.exit(1)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("show"); s.add_argument("--limit", type=int, default=8)
    n = sub.add_parser("next"); n.add_argument("--milestone", type=int)
    c = sub.add_parser("claim"); c.add_argument("issue", type=int); c.add_argument("--branch")
    c.add_argument("--stack", action="store_true", help="reuse an existing shared branch (no git lock)")
    t = sub.add_parser("set"); t.add_argument("issue", type=int); t.add_argument("state", choices=["review", "done"])
    t.add_argument("--pr"); t.add_argument("--force", action="store_true")
    r = sub.add_parser("release"); r.add_argument("issue", type=int); r.add_argument("--note")
    r.add_argument("--force", action="store_true")
    w = sub.add_parser("watch"); w.add_argument("--timeout", type=int, default=1800); w.add_argument("--every", type=int, default=60)
    a = p.parse_args()
    {"show": cmd_show, "next": cmd_next, "claim": cmd_claim, "set": cmd_set,
     "release": cmd_release, "watch": cmd_watch}[a.cmd](a)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Keep an implementation plan in its GitHub issue instead of a file in the repo.

A plan is published as:
  * the issue body: whatever was there before (kept as is), then a block between
    <!-- plan:begin --> and <!-- plan:end --> holding the plan's header (everything
    before the first task) and an index linking each task's comment;
  * one comment per task (a task longer than one comment is split into parts at
    blank lines), each starting with a <!-- plan-part {...} --> marker line.
GitHub refuses bodies and comments over 65,536 characters; parts stay under LIMIT.

`fetch` puts the pieces back together. The result is byte-for-byte the file that
was published (`check` proves that offline before anything is sent).

Usage:
  plan_issue.py check <plan.md>                       split locally, print sizes, verify the round trip
  plan_issue.py publish <issue> <plan.md> [--draft]   post or update the plan; plan-ready unless --draft
  plan_issue.py fetch <issue> [--out FILE]            print the plan (or write it outside the repo)

<issue> is N (the repository in PROJECT_REPO, default thanhngochoang/booking), be#N or
booking-be#N (thanhngochoang/booking-be), booking#N (thanhngochoang/booking); #N also works.

Env: PROJECT_REPO (default thanhngochoang/booking). `gh` must be logged in; inside the
Claude sandbox gh cannot read the keychain, so run this script with the sandbox off.
"""
import argparse
import json
import os
import re
import subprocess
import sys

REPO = os.environ.get("PROJECT_REPO", "thanhngochoang/booking")
APP_REPO = "thanhngochoang/booking"
BE_REPO = "thanhngochoang/booking-be"
ISSUE = re.compile(r"^(?:(booking-be|booking|be)?#)?(\d+)$")
LIMIT = 60_000  # GitHub's hard limit is 65,536; leave room for the marker line
BEGIN, END = "<!-- plan:begin -->", "<!-- plan:end -->"
IDX_BEGIN, IDX_END = "<!-- plan:index -->", "<!-- plan:index-end -->"
PART = "<!-- plan-part "
# "### Task 3:", "### Task A1:", "#### Former task 14:"; plans without tasks split at "## ".
TASK = re.compile(r"^#{2,4} (?:Former )?[Tt]ask\s+[A-Z]*\d+\b.*$", re.M)
SECTION = re.compile(r"^## \S.*$", re.M)
FENCE = re.compile(r"^\s*(```|~~~)")


def parse_issue(text):
    """(repository, number): `N`/`#N` -> PROJECT_REPO, `booking#N`, `be#N`, `booking-be#N`."""
    m = ISSUE.match(str(text).strip())
    if not m:
        raise ValueError(f"not an issue reference: {text!r} (use N, be#N, booking#N or booking-be#N)")
    repo = {None: REPO, "booking": APP_REPO, "be": BE_REPO, "booking-be": BE_REPO}[m.group(1)]
    return repo, int(m.group(2))


def issue_arg(text):
    try:
        return parse_issue(text)
    except ValueError as e:
        raise argparse.ArgumentTypeError(str(e))


def ref_text(repo, number):
    """The form to type after `plan_issue.py fetch`: 42 for booking, be#42 for booking-be."""
    return f"be#{number}" if repo == BE_REPO else str(number)


# ── splitting (pure, no network) ─────────────────────────────────────────────

def heading_starts(text, pattern):
    """Heading offsets outside code fences."""
    fenced, in_fence, pos = set(), False, 0
    for line in text.splitlines(keepends=True):
        if FENCE.match(line):
            in_fence = not in_fence
        elif in_fence:
            fenced.add(pos)
        pos += len(line)
    return [m.start() for m in pattern.finditer(text) if m.start() not in fenced]


def split_plan(text):
    """Returns (header, [(title, chunk), ...]); header + all chunks == text."""
    starts = heading_starts(text, TASK) or heading_starts(text, SECTION)[1:]
    if not starts:
        return text, []
    header = text[:starts[0]]
    pieces = []
    for i, s in enumerate(starts):
        e = starts[i + 1] if i + 1 < len(starts) else len(text)
        title = text[s:text.index("\n", s) if "\n" in text[s:] else len(text)].lstrip("#").strip()
        pieces.append((title, text[s:e]))
    return header, pieces


def cut(chunk):
    """Splits one task into parts under LIMIT, preferring blank lines outside code fences."""
    if len(chunk) <= LIMIT:
        return [chunk]
    parts, start, best, in_fence, pos = [], 0, None, False, 0
    for line in chunk.splitlines(keepends=True):
        end = pos + len(line)
        if FENCE.match(line):
            in_fence = not in_fence
        if end - start > LIMIT:
            at = best if best and best > start else pos
            if at <= start:  # one line longer than LIMIT: cut it hard
                at = start + LIMIT
            parts.append(chunk[start:at])
            start, best = at, None
        if not in_fence and line.strip() == "":
            best = end
        pos = end
    parts.append(chunk[start:])
    # A hard cut inside one very long line may leave a remainder still over LIMIT.
    out = []
    for p in parts:
        while len(p) > LIMIT:
            out.append(p[:LIMIT])
            p = p[LIMIT:]
        out.append(p)
    return [p for p in out if p]


def build_parts(text):
    """[(meta, content)] for every comment, in order, plus the header."""
    header, tasks = split_plan(text)
    parts = []
    if len(header) > LIMIT - 5_000:  # keep the body small enough for the index too
        for i, c in enumerate(cut(header), 1):
            parts.append(({"title": "Phần đầu", "piece": i}, c))
        header = ""
    for title, chunk in tasks:
        pieces = cut(chunk)
        for i, c in enumerate(pieces, 1):
            meta = {"title": title}
            if len(pieces) > 1:
                meta["piece"] = i
                meta["pieces"] = len(pieces)
            parts.append((meta, c))
    for n, (meta, _) in enumerate(parts, 1):
        meta["n"], meta["of"] = n, len(parts)
    return header, parts


def comment_body(meta, content):
    return f"{PART}{json.dumps(meta, ensure_ascii=False)} -->\n{content}"


def parse_comment(body):
    if not body.startswith(PART):
        return None
    first, _, content = body.partition("\n")
    meta = json.loads(first[len(PART):-len(" -->")])
    return meta, content


def plan_block(header, links, ref="<issue>"):
    index = [IDX_BEGIN, "", "**Kế hoạch trong issue này** (đọc đủ bằng "
             f"`.agents/skills/plan-in-issue/scripts/plan_issue.py fetch {ref}`):", ""]
    for meta, url in links:
        label = meta["title"] + (f" (phần {meta['piece']}/{meta['pieces']})" if "pieces" in meta else "")
        if meta["title"] == "Phần đầu":
            label = f"Phần đầu (phần {meta['piece']})"
        index.append(f"{meta['n']}. [{label}]({url})")
    index += ["", IDX_END, ""]
    return f"{BEGIN}\n" + "\n".join(index) + header + f"\n{END}"


def unblock(body):
    """(outside text, plan header) from an issue body."""
    if BEGIN not in body:
        return body, ""
    pre, _, rest = body.partition(BEGIN)
    block, _, post = rest.partition(END)
    block = block[1:] if block.startswith("\n") else block
    block = block[:-1] if block.endswith("\n") else block
    if IDX_BEGIN in block:
        _, _, after = block.partition(IDX_END)
        block = after[1:] if after.startswith("\n") else after
    return pre.rstrip("\n") + post, block


def assemble(header, comments):
    parts = sorted((m for m in comments if m), key=lambda mc: mc[0]["n"])
    if parts and parts[-1][0]["of"] != len(parts):
        sys.exit(f"error: the issue has {len(parts)} plan parts but they say {parts[-1][0]['of']}")
    return header + "".join(c for _, c in parts)


# ── GitHub ───────────────────────────────────────────────────────────────────

def gh(*args, payload=None):
    r = subprocess.run(["gh", *args], text=True, capture_output=True,
                       input=json.dumps(payload) if payload is not None else None)
    if r.returncode != 0:
        sys.exit(f"error: gh {' '.join(args[:4])}\n{r.stderr}")
    return r.stdout


def api(method, path, payload=None):
    args = ["api", "-X", method, path]
    if payload is not None:
        args += ["--input", "-"]
    out = gh(*args, payload=payload)
    return json.loads(out) if out.strip() else None


def issue_comments(repo, issue):
    out = gh("api", "--paginate", f"repos/{repo}/issues/{issue}/comments", "--jq", ".[] | {id, body, html_url}")
    return [json.loads(line) for line in out.splitlines() if line.strip()]


# ── commands ─────────────────────────────────────────────────────────────────

def cmd_check(path):
    text = open(path, encoding="utf-8").read()
    header, parts = build_parts(text)
    print(f"header (issue body): {len(header):,} chars")
    for meta, c in parts:
        print(f"  {meta['n']:>3}/{meta['of']}  {len(c):>7,}  {meta['title'][:70]}"
              + (f" [{meta['piece']}/{meta.get('pieces', '?')}]" if "piece" in meta else ""))
    links = [(m, "https://example/#c") for m, _ in parts]
    _, back = unblock("intro\n\n" + plan_block(header, links))
    rebuilt = assemble(back, [parse_comment(comment_body(m, c)) for m, c in parts])
    if rebuilt != text:
        sys.exit("error: round trip differs from the file")
    biggest = max([len(header)] + [len(comment_body(m, c)) for m, c in parts])
    print(f"round trip ok; {len(parts)} comments, largest piece {biggest:,} chars (limit 65,536)")
    return header, parts


def cmd_publish(repo, issue, path, draft):
    header, parts = cmd_check(path)
    old = [(c, parse_comment(c["body"])) for c in issue_comments(repo, issue)]
    old = [(c, p) for c, p in old if p]
    old.sort(key=lambda cp: cp[1][0]["n"])
    links = []
    for i, (meta, content) in enumerate(parts):
        body = comment_body(meta, content)
        if i < len(old):
            c = api("PATCH", f"repos/{repo}/issues/comments/{old[i][0]['id']}", {"body": body})
        else:
            c = api("POST", f"repos/{repo}/issues/{issue}/comments", {"body": body})
        links.append((meta, c["html_url"]))
    for c, _ in old[len(parts):]:
        api("DELETE", f"repos/{repo}/issues/comments/{c['id']}")
    issue_json = api("GET", f"repos/{repo}/issues/{issue}")
    outside, _ = unblock(issue_json.get("body") or "")
    outside = re.sub(r"^Plan: .*\n?", "", outside, flags=re.M).rstrip("\n")
    new_body = (outside + "\n\n" if outside else "") + "Plan: in this issue (plan-in-issue)\n\n" + plan_block(header, links, ref_text(repo, issue))
    if len(new_body) > 65_536:
        sys.exit(f"error: the issue body would be {len(new_body):,} chars; shorten the text above the plan")
    api("PATCH", f"repos/{repo}/issues/{issue}", {"body": new_body})
    if not draft:
        gh("issue", "edit", str(issue), "--repo", repo, "--add-label", "plan-ready", "--remove-label", "needs-plan")
    # Read it back: what agents will fetch must be what was written.
    if cmd_fetch(repo, issue, None, quiet=True) != open(path, encoding="utf-8").read():
        sys.exit("error: the plan read back from the issue differs from the file")
    print(f"published {ref_text(repo, issue) if repo == BE_REPO else '#' + str(issue)}: {len(parts)} comments{'' if draft else ', label plan-ready'}; read back ok")


def cmd_fetch(repo, issue, out, quiet=False):
    issue_json = api("GET", f"repos/{repo}/issues/{issue}")
    _, header = unblock(issue_json.get("body") or "")
    comments = [parse_comment(c["body"]) for c in issue_comments(repo, issue)]
    if not any(comments) and not header:
        sys.exit(f"error: {repo}#{issue} has no plan in it")
    text = assemble(header, comments)
    if quiet:
        return text
    if out:
        with open(out, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"wrote {out} ({len(text):,} chars)", file=sys.stderr)
    else:
        sys.stdout.write(text)
    return text


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("plan")
    pu = sub.add_parser("publish")
    pu.add_argument("issue", type=issue_arg)
    pu.add_argument("plan")
    pu.add_argument("--draft", action="store_true", help="post without the plan-ready label")
    f = sub.add_parser("fetch")
    f.add_argument("issue", type=issue_arg)
    f.add_argument("--out")
    a = p.parse_args()
    if a.cmd == "check":
        cmd_check(a.plan)
    elif a.cmd == "publish":
        cmd_publish(*a.issue, a.plan, a.draft)
    else:
        cmd_fetch(*a.issue, a.out)


if __name__ == "__main__":
    main()

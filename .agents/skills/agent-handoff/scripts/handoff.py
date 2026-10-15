#!/usr/bin/env python3
"""Step log so another agent can take over work that stopped half-way.

One Markdown file per task in <main checkout>/.agents/handoff/ (gitignored,
shared by every worktree of the repository). The task id is the current branch
with "/" replaced by "-", or --task SLUG. The file is plain Markdown so an agent
without Python can read and edit it by hand; this script only keeps the format
consistent and adds the live git state when someone resumes.

  start GOAL [--step S]... [--plan P] [--issue N]   open a log for this branch
  steps S [S ...]                                   append steps to the plan
  begin N [--now TEXT]                              mark step N in progress
  done N [--note TEXT]                              mark step N done (HEAD recorded)
  now TEXT                                          what you are doing right now
  note TEXT                                         decision/gotcha for the next agent
  log TEXT                                          free journal line
  status                                            log + live git state
  resume                                            take the log over (prints status)
  close [--state done|paused] [--note TEXT]         finish or park the task
  list                                              every log, newest first

Agent name: --agent NAME, else $HANDOFF_AGENT, else guessed from the runtime.
"""
import argparse
import datetime
import os
import re
import socket
import subprocess
import sys

MARK = "<!-- handoff:v1 -->"
SECTIONS = ["Steps", "Now", "Notes for the next agent", "Journal"]
FRESH_MINUTES = 15  # an active log touched more recently may still have a live agent


def git(*args, cwd=None):
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def now_utc():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0)


def iso(t):
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s):
    try:
        return datetime.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=datetime.timezone.utc)
    except ValueError:
        return None


def agent_name(arg):
    if arg:
        return arg
    if os.environ.get("HANDOFF_AGENT"):
        return os.environ["HANDOFF_AGENT"]
    env = os.environ
    if env.get("CLAUDECODE"):
        tool = "claude-code"
    elif any(k.startswith("CODEX") for k in env):
        tool = "codex"
    elif any(k.startswith("GEMINI_CLI") for k in env):
        tool = "gemini"
    elif any(k.startswith("CURSOR") for k in env):
        tool = "cursor"
    else:
        tool = "agent"
    host = socket.gethostname().split(".")[0] or "host"
    return "%s@%s" % (tool, host)


def log_dir():
    common = git("rev-parse", "--path-format=absolute", "--git-common-dir")
    if not common:
        sys.exit("handoff: not inside a git repository")
    d = os.path.join(os.path.dirname(common), ".agents", "handoff")
    os.makedirs(d, exist_ok=True)
    return d


def task_id(arg):
    if arg:
        return re.sub(r"[^A-Za-z0-9._-]+", "-", arg).strip("-")
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    if not branch or branch == "HEAD":
        return "detached-" + git("rev-parse", "--short", "HEAD")
    return branch.replace("/", "-")


def head():
    return git("rev-parse", "--short", "HEAD") or "-"


class Log:
    """Header fields + named sections, rendered back in a fixed order."""

    def __init__(self, path):
        self.path = path
        self.title = ""
        self.fields = {}
        self.sections = {name: [] for name in SECTIONS}

    @classmethod
    def load(cls, path):
        log = cls(path)
        current = None
        with open(path, encoding="utf-8") as f:
            for line in f.read().splitlines():
                if line.startswith("# ") and not log.title:
                    log.title = line[2:]
                elif line.startswith("## ") and line[3:] in SECTIONS:
                    current = line[3:]
                elif current:
                    log.sections[current].append(line)
                else:
                    m = re.match(r"- \*\*(.+?):\*\* ?(.*)$", line)
                    if m:
                        log.fields[m.group(1)] = m.group(2)
        for name in SECTIONS:
            lines = log.sections[name]
            while lines and not lines[-1].strip():
                lines.pop()
            while lines and not lines[0].strip():
                lines.pop(0)
        return log

    def save(self):
        out = ["# " + self.title, "", MARK]
        out += ["- **%s:** %s" % (k, v) for k, v in self.fields.items()]
        for name in SECTIONS:
            out += ["", "## " + name, ""]
            out += self.sections[name] or ["_(none)_"]
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write("\n".join(out) + "\n")
        os.replace(tmp, self.path)  # atomic: a killed agent never leaves half a file

    def clean(self, name):
        self.sections[name] = [l for l in self.sections[name] if l != "_(none)_"]

    def journal(self, agent, text):
        self.clean("Journal")
        stamp = now_utc().strftime("%Y-%m-%d %H:%MZ")
        self.sections["Journal"].append("- %s %s [%s] %s" % (stamp, agent, head(), text))
        self.fields["Updated"] = iso(now_utc())

    def steps(self):
        found = []
        for i, line in enumerate(self.sections["Steps"]):
            m = re.match(r"- \[([ x~])\] (\d+)\. (.*)$", line)
            if m:
                found.append((i, m.group(1), int(m.group(2)), m.group(3)))
        return found

    def set_step(self, n, state, suffix=""):
        for i, _, num, text in self.steps():
            if num == n:
                text = re.sub(r" _\(.*\)_$", "", text)
                self.sections["Steps"][i] = "- [%s] %d. %s%s" % (state, n, text, suffix)
                return text
        sys.exit("handoff: no step %d (see `status`)" % n)

    def add_steps(self, texts):
        self.clean("Steps")
        start = max([s[2] for s in self.steps()] or [0])
        for k, t in enumerate(texts, start + 1):
            self.sections["Steps"].append("- [ ] %d. %s" % (k, t))


def open_log(args, must_exist=True):
    path = os.path.join(log_dir(), task_id(args.task) + ".md")
    if must_exist and not os.path.exists(path):
        sys.exit("handoff: no log %s — run `start` first (or `list`)" % path)
    return path


def freshness(log):
    """Minutes since anyone last touched the log (header stamp or hand edit)."""
    times = [parse_iso(log.fields.get("Updated", ""))]
    if os.path.exists(log.path):
        times.append(datetime.datetime.fromtimestamp(
            os.path.getmtime(log.path), datetime.timezone.utc))
    times = [t for t in times if t]
    if not times:
        return None
    return max(0, int((now_utc() - max(times)).total_seconds() // 60))


def live_state(log):
    lines = []
    branch = git("rev-parse", "--abbrev-ref", "HEAD")
    lines.append("branch here : %s @ %s" % (branch, head()))
    want = log.fields.get("Branch", "").split(" ")[0]
    if want and want != branch:
        lines.append("!! log is for branch %s — check it out (or its worktree) first" % want)
    wt = log.fields.get("Worktree", "")
    if wt and os.path.realpath(wt) != os.path.realpath(git("rev-parse", "--show-toplevel")):
        lines.append("!! log was written in worktree %s" % wt)
    dirty = "\n".join(l for l in git("status", "--porcelain").splitlines()
                      if ".agents/handoff/" not in l)
    lines.append("uncommitted : %d file(s)" % (len(dirty.splitlines()) if dirty else 0))
    for l in dirty.splitlines()[:15]:
        lines.append("    " + l)
    up = git("rev-parse", "--abbrev-ref", "@{u}")
    if up:
        ahead = git("rev-list", "--count", "@{u}..HEAD")
        lines.append("unpushed    : %s commit(s) ahead of %s" % (ahead or "0", up))
    else:
        lines.append("unpushed    : no upstream (branch never pushed?)")
    since = log.fields.get("Started at", "")
    if since:
        commits = git("log", "--oneline", "%s..HEAD" % since)
        lines.append("commits since start (%s):" % since)
        lines += ["    " + c for c in commits.splitlines()[:20]] or ["    (none)"]
    return lines


def show(log, agent=None):
    print(open(log.path, encoding="utf-8").read().rstrip())
    print("\n---- live git state (trust this over the log) ----")
    print("\n".join(live_state(log)))
    age = freshness(log)
    owner = log.fields.get("Owner", "?")
    if (log.fields.get("Status") == "active" and owner != agent and age is not None
            and age < FRESH_MINUTES):
        print("!! updated %d min ago by %s — that agent may still be running; ask the user"
              " before taking over" % (age, owner))


def cmd_start(a):
    path = open_log(a, must_exist=False)
    agent = agent_name(a.agent)
    if os.path.exists(path):
        old = Log.load(path)
        if old.fields.get("Status") != "done":
            sys.exit("handoff: %s already exists (status %s, owner %s). Use `resume`, or"
                     " `close` it first." % (path, old.fields.get("Status"), old.fields.get("Owner")))
        os.rename(path, path[:-3] + "." + iso(now_utc()).replace(":", "") + ".md")
    log = Log(path)
    log.title = a.goal
    upstream = git("rev-parse", "--abbrev-ref", "@{u}")
    log.fields = {
        "Status": "active",
        "Goal": a.goal,
        "Branch": git("rev-parse", "--abbrev-ref", "HEAD") + (" (upstream %s)" % upstream if upstream else ""),
        "Worktree": git("rev-parse", "--show-toplevel"),
        "Started at": head(),
        "Plan": a.plan or "-",
        "Issue": ("#%s" % a.issue) if a.issue else "-",
        "Owner": agent,
        "Updated": iso(now_utc()),
    }
    log.add_steps(a.step or [])
    log.journal(agent, "start: " + a.goal)
    log.save()
    print(path)


def mutate(a, fn):
    log = Log.load(open_log(a))
    agent = agent_name(a.agent)
    fn(log, agent)
    log.save()
    print(log.path)


def cmd_steps(a):
    mutate(a, lambda l, ag: (l.add_steps(a.text), l.journal(ag, "steps added: %d" % len(a.text))))


def cmd_begin(a):
    def f(log, agent):
        text = log.set_step(a.n, "~")
        if a.now:
            log.sections["Now"] = [a.now]
        log.journal(agent, "begin %d: %s" % (a.n, text))
    mutate(a, f)


def cmd_done(a):
    def f(log, agent):
        text = log.set_step(a.n, "x", " _(%s)_" % head())
        log.journal(agent, "done %d: %s%s" % (a.n, text, (" — " + a.note) if a.note else ""))
    mutate(a, f)


def cmd_now(a):
    def f(log, agent):
        log.sections["Now"] = [a.text]
        log.journal(agent, "now: " + a.text)
    mutate(a, f)


def cmd_note(a):
    def f(log, agent):
        log.clean("Notes for the next agent")
        log.sections["Notes for the next agent"].append("- " + a.text)
        log.journal(agent, "note: " + a.text)
    mutate(a, f)


def cmd_log(a):
    mutate(a, lambda l, ag: l.journal(ag, a.text))


def cmd_status(a):
    show(Log.load(open_log(a)), agent_name(a.agent))


def cmd_resume(a):
    log = Log.load(open_log(a))
    agent = agent_name(a.agent)
    age = freshness(log)
    prev = log.fields.get("Owner", "?")
    if (log.fields.get("Status") == "active" and prev != agent and age is not None
            and age < FRESH_MINUTES and not a.force):
        show(log)
        sys.exit("handoff: %s wrote to this log %d min ago. Confirm with the user that it"
                 " stopped, then rerun with --force." % (prev, age))
    log.fields["Status"] = "active"
    log.fields["Owner"] = agent
    log.journal(agent, "resume: took over from %s" % prev)
    log.save()
    show(log, agent)


def cmd_close(a):
    def f(log, agent):
        log.fields["Status"] = a.state
        if a.state == "done":
            log.sections["Now"] = ["_(done)_"]
        elif a.note:
            log.sections["Now"] = ["Paused. Next: " + a.note]
        log.journal(agent, "close (%s)%s" % (a.state, (": " + a.note) if a.note else ""))
    mutate(a, f)


def cmd_list(a):
    d = log_dir()
    rows = []
    for name in os.listdir(d):
        if name.endswith(".md") and name.count(".") == 1:
            log = Log.load(os.path.join(d, name))
            rows.append((log.fields.get("Updated", ""), name[:-3], log))
    if not rows:
        print("no handoff logs in %s" % d)
    for updated, tid, log in sorted(rows, key=lambda r: r[0], reverse=True):
        steps = log.steps()
        done = sum(1 for s in steps if s[1] == "x")
        print("%-8s %-40s %d/%d steps  %s  %s  %s" % (
            log.fields.get("Status", "?"), tid, done, len(steps), updated,
            log.fields.get("Owner", "?"), log.title))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--task", help="task id instead of the current branch")
    p.add_argument("--agent", help="who is writing (default: $HANDOFF_AGENT or guessed)")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("start"); s.add_argument("goal")
    s.add_argument("--step", action="append"); s.add_argument("--plan"); s.add_argument("--issue")
    s.set_defaults(fn=cmd_start)
    s = sub.add_parser("steps"); s.add_argument("text", nargs="+"); s.set_defaults(fn=cmd_steps)
    s = sub.add_parser("begin"); s.add_argument("n", type=int); s.add_argument("--now")
    s.set_defaults(fn=cmd_begin)
    s = sub.add_parser("done"); s.add_argument("n", type=int); s.add_argument("--note")
    s.set_defaults(fn=cmd_done)
    for name, fn in (("now", cmd_now), ("note", cmd_note), ("log", cmd_log)):
        s = sub.add_parser(name); s.add_argument("text"); s.set_defaults(fn=fn)
    sub.add_parser("status").set_defaults(fn=cmd_status)
    s = sub.add_parser("resume"); s.add_argument("--force", action="store_true")
    s.set_defaults(fn=cmd_resume)
    s = sub.add_parser("close"); s.add_argument("--state", choices=["done", "paused"], default="done")
    s.add_argument("--note"); s.set_defaults(fn=cmd_close)
    sub.add_parser("list").set_defaults(fn=cmd_list)

    # Allow --task/--agent after the subcommand too (agents put them anywhere).
    argv = sys.argv[1:]
    front = []
    for flag in ("--task", "--agent"):
        if flag in argv:
            i = argv.index(flag)
            front += argv[i:i + 2]
            del argv[i:i + 2]
    a = p.parse_args(front + argv)
    a.fn(a)


if __name__ == "__main__":
    main()

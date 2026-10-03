#!/usr/bin/env python3
"""Pick the Flutter test files a PR can affect.

Usage: scripts/ci-affected-tests.py <base-ref>      (run from the repo root)

Prints "ALL", "NONE", or one test path per line (relative to app_flutter/).
When unsure it answers ALL: a failed git diff, a config/tooling change, or a
changed file this script does not know how to map.

A test is selected when
  * it imports, directly or transitively (import/export/part), a changed Dart
    file in lib/ or test/ — this covers barrels like core/core.dart and
    shared helpers in test/support/;
  * it reads a path from disk with File('...') / Directory('...') and a
    changed file lives under that path (source-rule tests scanning lib/,
    platform-config tests reading android/ or ios/, ...).
"""
import os
import re
import subprocess
import sys

APP = "app_flutter"
PACKAGE = "photobooking"

# Changes that can affect every test: run them all.
GLOBAL_FILES = {
    f"{APP}/pubspec.yaml",
    f"{APP}/pubspec.lock",
    f"{APP}/analysis_options.yaml",
    f"{APP}/dart_test.yaml",
    f"{APP}/l10n.yaml",
    f"{APP}/build.yaml",
    ".github/workflows/flutter.yml",
    "scripts/ci-affected-tests.py",
}
GLOBAL_PREFIXES = (f"{APP}/tool/", f"{APP}/assets/", "design-system/")

# Paths outside lib/ and test/ that tests only see by reading them from disk;
# a change there selects only the tests that read it
# (relative to app_flutter/).
DISK_ONLY_PREFIXES = ("firebase/", "android/", "ios/", "macos/", ".claude/")

DIRECTIVE = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)
DISK_READ = re.compile(r"""\b(?:File|Directory)\(\s*['"]([^'"$]+)""")


def changed_files(base):
    for args in (["git", "diff", "--name-only", f"{base}...HEAD"],
                 ["git", "diff", "--name-only", base, "HEAD"]):
        r = subprocess.run(args, capture_output=True, text=True)
        if r.returncode == 0:
            return [l for l in r.stdout.splitlines() if l]
    return None  # unknown → caller runs everything


def dart_files(root):
    for d in ("lib", "test"):
        for dirpath, _, names in os.walk(os.path.join(root, d)):
            for n in names:
                if n.endswith(".dart"):
                    yield os.path.relpath(os.path.join(dirpath, n), root)


def resolve(src, uri):
    if uri.startswith("dart:"):
        return None
    if uri.startswith("package:"):
        pkg, _, rest = uri[len("package:"):].partition("/")
        return f"lib/{rest}" if pkg == PACKAGE else None
    return os.path.normpath(os.path.join(os.path.dirname(src), uri))


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "origin/develop"
    changed = changed_files(base)
    if changed is None:
        print("ALL")
        return

    seeds = set()        # changed lib/test paths, relative to app_flutter/
    disk_changed = []    # every changed path under app_flutter/, relative to it
    for path in changed:
        if path in GLOBAL_FILES or path.startswith(GLOBAL_PREFIXES):
            print("ALL")
            return
        if not path.startswith(f"{APP}/"):
            continue  # docs, packages/domain, other workflows: not Flutter tests
        rel = path[len(APP) + 1:]
        disk_changed.append(rel)
        if rel.endswith(".dart") and rel.startswith(("lib/", "test/")):
            seeds.add(rel)
        elif rel == "lib/l10n/app_vi.arb":
            seeds.add("lib/l10n/app_localizations.dart")
        elif rel.startswith("test/"):
            # fixture or other non-Dart test file: the tests next to it
            seeds.add(os.path.dirname(rel) + "/")
        elif rel.startswith("lib/") or rel.startswith(DISK_ONLY_PREFIXES) \
                or rel.endswith(".md") or "/" not in rel and rel.startswith("."):
            pass  # only disk-reading tests can see these
        else:
            print("ALL")
            return

    # Reverse dependency graph over lib/ and test/.
    rdeps = {}
    tests = []
    disk_reads = {}
    for f in dart_files(APP):
        with open(os.path.join(APP, f), encoding="utf-8") as fh:
            text = fh.read()
        for uri in DIRECTIVE.findall(text):
            target = resolve(f, uri)
            if target:
                rdeps.setdefault(target, set()).add(f)
        if f.startswith("test/") and f.endswith("_test.dart"):
            tests.append(f)
            reads = [p.rstrip("/") for p in DISK_READ.findall(text)]
            if reads:
                disk_reads[f] = reads

    affected = set()
    stack = [s for s in seeds if not s.endswith("/")]
    for prefix in (s for s in seeds if s.endswith("/")):
        stack += [t for t in tests if t.startswith(prefix)]
    while stack:
        node = stack.pop()
        if node in affected:
            continue
        affected.add(node)
        stack.extend(rdeps.get(node, ()))

    selected = {t for t in tests if t in affected}
    for t, reads in disk_reads.items():
        if any(c == r or c.startswith(r + "/") for c in disk_changed for r in reads):
            selected.add(t)

    if not selected:
        print("NONE")
    else:
        print("\n".join(sorted(selected)))


if __name__ == "__main__":
    main()

"""Offline tests for plan_issue.py: issue references and the publish/fetch round trip."""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import plan_issue as pi  # noqa: E402

APP, BE = pi.APP_REPO, pi.BE_REPO

PLAN = """# Plan X

**Issue:** #1

Header text.

### Task 1: First

Do a thing.

```
### Task 99: not a heading
```

### Task 2: Second

Do another.
"""


class Refs(unittest.TestCase):
    def test_forms(self):
        self.assertEqual(pi.parse_issue("175"), (pi.REPO, 175))
        self.assertEqual(pi.parse_issue("#175"), (pi.REPO, 175))
        self.assertEqual(pi.parse_issue("booking#175"), (APP, 175))
        self.assertEqual(pi.parse_issue("be#42"), (BE, 42))
        self.assertEqual(pi.parse_issue("booking-be#42"), (BE, 42))

    def test_project_repo_override_applies_to_bare_numbers_only(self):
        with mock.patch.object(pi, "REPO", "someone/else"):
            self.assertEqual(pi.parse_issue("7"), ("someone/else", 7))
            self.assertEqual(pi.parse_issue("be#7"), (BE, 7))

    def test_rejects(self):
        for bad in ("", "be", "x#1", "be#", "1a"):
            with self.assertRaises(ValueError, msg=bad):
                pi.parse_issue(bad)

    def test_ref_text(self):
        self.assertEqual(pi.ref_text(BE, 42), "be#42")
        self.assertEqual(pi.ref_text(APP, 42), "42")


class RoundTrip(unittest.TestCase):
    def publish_and_read(self, ref):
        """What publish writes (body block + comments), then what fetch assembles from it."""
        header, parts = pi.build_parts(PLAN)
        links = [(m, "https://example/#c") for m, _ in parts]
        body = "intro\n\nPlan: in this issue (plan-in-issue)\n\n" + pi.plan_block(header, links, ref)
        comments = [pi.comment_body(m, c) for m, c in parts]
        outside, back = pi.unblock(body)
        self.assertEqual(outside, "intro\n\nPlan: in this issue (plan-in-issue)")
        return body, pi.assemble(back, [pi.parse_comment(c) for c in comments])

    def test_round_trip_booking_and_backend(self):
        for ref in ("175", "be#42"):
            body, text = self.publish_and_read(ref)
            self.assertEqual(text, PLAN)
            self.assertIn(f"plan_issue.py fetch {ref}`", body)

    def test_default_index_placeholder(self):
        self.assertIn("fetch <issue>`", pi.plan_block("h", []))

    def test_split_ignores_fenced_headings(self):
        _, tasks = pi.split_plan(PLAN)
        self.assertEqual([t for t, _ in tasks], ["Task 1: First", "Task 2: Second"])

    def test_long_task_is_cut_and_rejoined(self):
        big = "### Task 1: Big\n\n" + "\n\n".join("para %d " % i + "x" * 900 for i in range(120)) + "\n"
        header, parts = pi.build_parts("# P\n\n" + big)
        self.assertGreater(len(parts), 1)
        self.assertTrue(all(len(c) <= pi.LIMIT for _, c in parts))
        text = pi.assemble(header, [pi.parse_comment(pi.comment_body(m, c)) for m, c in parts])
        self.assertEqual(text, "# P\n\n" + big)

    def test_api_paths_use_the_issues_repo(self):
        seen = []
        with mock.patch.object(pi, "gh", lambda *a, payload=None: seen.append(a) or ""):
            pi.issue_comments(BE, 42)
        self.assertIn(f"repos/{BE}/issues/42/comments", seen[0])


if __name__ == "__main__":
    unittest.main()

"""Offline tests for project.py and land.py: references, ordering, branch names, blockers."""
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import land  # noqa: E402
import project as p  # noqa: E402

APP, BE = p.REPO, p.BE_REPO


def item(ref, milestone="", title="Unit", status="Todo", labels=("plan-ready",), state="OPEN"):
    return dict(ref=ref, number=ref.number, milestone=milestone, title=title, status=status,
                labels=list(labels), state=state)


class RefParsing(unittest.TestCase):
    def test_forms(self):
        self.assertEqual(p.parse_ref("339"), p.Ref(APP, 339))
        self.assertEqual(p.parse_ref("#339"), p.Ref(APP, 339))
        self.assertEqual(p.parse_ref("booking#339"), p.Ref(APP, 339))
        self.assertEqual(p.parse_ref("be#42"), p.Ref(BE, 42))
        self.assertEqual(p.parse_ref("booking-be#42"), p.Ref(BE, 42))

    def test_rejects(self):
        for bad in ("", "be", "be#", "x#1", "be#x", "1.5", "be-42", "#"):
            with self.assertRaises(ValueError, msg=bad):
                p.parse_ref(bad)

    def test_output_form(self):
        self.assertEqual(str(p.Ref(APP, 339)), "#339")
        self.assertEqual(str(p.Ref(BE, 42)), "be#42")
        self.assertEqual(p.Ref(APP, 339).arg(), "339")  # shell-safe: a leading # would be a comment
        self.assertEqual(p.Ref(BE, 42).arg(), "be#42")
        for r in (p.Ref(APP, 7), p.Ref(BE, 7)):
            self.assertEqual(p.parse_ref(r.arg()), r)
            self.assertEqual(p.parse_ref(str(r)), r)


class Branches(unittest.TestCase):
    def test_names(self):
        self.assertEqual(p.branch_name(p.Ref(APP, 339), "Ca chua / gach: miền"), "plan/339-ca-chua-gach-mien")
        self.assertEqual(p.branch_name(p.Ref(BE, 42), "Đặt lịch API"), "plan/be42-dat-lich-api")

    def test_prefixes_never_collide(self):
        self.assertNotEqual(p.Ref(APP, 42).branch_prefix(), p.Ref(BE, 42).branch_prefix())
        self.assertFalse("plan/be42-x".startswith(p.Ref(APP, 42).branch_prefix()))
        self.assertFalse("plan/42-x".startswith(p.Ref(BE, 42).branch_prefix()))


class Ordering(unittest.TestCase):
    def test_phase_key(self):
        titles = ["Phase 3 · Tự host", "", "Phase 2 · Backend", "Weird", "Phase 1.5 · Dashboard", "Phase 1 · App"]
        got = sorted(titles, key=p.phase_key)
        self.assertEqual(got, ["Phase 1 · App", "Phase 1.5 · Dashboard", "Phase 2 · Backend",
                               "Phase 3 · Tự host", "", "Weird"])

    def test_phase_key_accepts_cli_values(self):
        self.assertEqual(p.phase_key("2"), p.phase_key("Phase 2 · Backend"))
        self.assertEqual(p.phase_key("1.5"), p.phase_key("Phase 1.5 · Dashboard"))
        self.assertLess(p.phase_key("1"), p.phase_key("1.5"))

    def test_phase_label(self):
        self.assertEqual(p.phase_label("Phase 2 · Backend Go"), "Phase 2")
        self.assertEqual(p.phase_label(""), "-")

    def test_ordered_by_title_then_board_position(self):
        items = [item(p.Ref(BE, 5), "Phase 2 · Backend"), item(p.Ref(APP, 9), "Phase 1.5 · Dashboard"),
                 item(p.Ref(BE, 1), "Phase 2 · Backend"), item(p.Ref(APP, 3), ""),
                 item(p.Ref(APP, 8), "Phase 1 · App"), item(p.Ref(APP, 2), "Phase 2 · Backend")]
        got = [str(i["ref"]) for i in p.ordered(items)]
        # milestone numbers differ per repository; titles decide, board order breaks ties
        self.assertEqual(got, ["#8", "#9", "be#5", "be#1", "#2", "#3"])

    def test_runnable_filters_and_blockers(self):
        items = [item(p.Ref(BE, 1), "Phase 2"), item(p.Ref(BE, 2), "Phase 2", status="In Progress"),
                 item(p.Ref(BE, 3), "Phase 2", labels=()), item(p.Ref(APP, 4), "Phase 2", title="[Phase 2] epic"),
                 item(p.Ref(APP, 5), "Phase 1"), item(p.Ref(APP, 6), "Phase 2", state="CLOSED")]
        blocked = {p.Ref(APP, 5): ["be#1"]}
        with mock.patch.object(p, "blockers", side_effect=lambda r: blocked.get(r, [])):
            self.assertEqual([str(i["ref"]) for i in p.runnable(items)], ["be#1"])
            self.assertEqual([str(i["ref"]) for i in p.runnable(items, "2")], ["be#1"])
            self.assertEqual([str(i["ref"]) for i in p.runnable(items, "1")], [])


class Blockers(unittest.TestCase):
    def test_cross_repo_blockers_use_their_own_repo_and_state(self):
        deps = [
            {"number": 10, "state": "open", "repository_url": f"https://api.github.com/repos/{BE}"},
            {"number": 11, "state": "closed", "repository_url": f"https://api.github.com/repos/{BE}"},
            {"number": 12, "state": "open", "repository_url": f"https://api.github.com/repos/{APP}"},
            {"number": 13, "state": "open"},
        ]
        got = p.open_blockers(deps, APP)
        self.assertEqual([str(r) for r in got], ["be#10", "#12", "#13"])
        self.assertEqual(p.open_blockers(None, APP), [])

    def test_blockers_calls_the_items_repo(self):
        calls = []

        def fake_sh(*args, check=True, stdin=None):
            calls.append(args)
            return mock.Mock(returncode=0, stdout='[{"number": 3, "state": "open", '
                             f'"repository_url": "https://api.github.com/repos/{APP}"}}]')

        with mock.patch.object(p, "sh", fake_sh):
            self.assertEqual(p.blockers(p.Ref(BE, 42)), ["#3"])
        self.assertIn(f"repos/{BE}/issues/42/dependencies/blocked_by", calls[0])


class Claims(unittest.TestCase):
    EV = [dict(event="claim", machine="a", branch="plan/be1-x"),
          dict(event="review", machine="a"),
          dict(event="done", machine="a")]

    def test_active_claim(self):
        self.assertEqual(p.fold_claim(self.EV[:2])["machine"], "a")
        self.assertIsNone(p.fold_claim(self.EV))

    def test_done_claim_still_visible_for_the_other_repos_pr(self):
        self.assertEqual(p.fold_claim(self.EV, include_done=True)["branch"], "plan/be1-x")
        released = [dict(event="claim", machine="a"), dict(event="release")]
        self.assertIsNone(p.fold_claim(released, include_done=True))

    def test_release_then_reclaim(self):
        evs = [dict(event="claim", machine="a"), dict(event="release"), dict(event="claim", machine="b")]
        self.assertEqual(p.fold_claim(evs)["machine"], "b")


class LandTitles(unittest.TestCase):
    def test_title_tags(self):
        ok = "feat(api): booking endpoints [be#42]"
        self.assertTrue(land.TITLE.match(ok) and ok.endswith(f"[{p.Ref(BE, 42)}]"))
        ok = "feat(review): domain [#35]"
        self.assertTrue(land.TITLE.match(ok) and ok.endswith(f"[{p.Ref(APP, 35)}]"))
        self.assertFalse(land.TITLE.match("feat(api): booking endpoints [x#42]"))
        self.assertFalse("feat(api): endpoints [be#42]".endswith(f"[{p.Ref(APP, 42)}]"))

    def test_side(self):
        self.assertTrue(land.Side(None).app)
        side = land.Side(BE)
        self.assertFalse(side.app)
        self.assertEqual(side.remote, "booking-be")


if __name__ == "__main__":
    unittest.main()

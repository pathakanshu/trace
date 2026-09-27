"""Fixture-only checks; this does not import or execute application status logic."""
import json
import unittest
from audit_checkpoints import recompute, rumor_conflicts, summarize
from generate_queries import ROOT, DATASET, read_catalog, at


def claim(kind, hour, ident="clm-000001", release=72):
    return {"id": ident, "kind": "claim", "subject": {"kind": "person", "id": "per-000001"},
            "assertion": {"type": kind}, "reported_at": {"value": at(hour) if hour is not None else None},
            "available_at": at(release), "source_id": "src-000001"}


class CheckpointTests(unittest.TestCase):
    def test_observation_time_controls_not_late_arrival(self):
        self.assertEqual(summarize([claim("MISSING", 11), claim("FOUND_SAFE", 23), claim("MISSING", 15)]), "FOUND_SAFE")

    def test_unknown_and_equal_time_opposition_stay_unresolved(self):
        for hour in (None, 23):
            self.assertEqual(summarize([claim("MISSING", hour), claim("FOUND_SAFE", 23)]), "UNRESOLVED")

    def test_unknown_time_is_not_replaced_by_release_time(self):
        self.assertEqual(summarize([claim("MISSING", None, release=12), claim("FOUND_SAFE", 71)]), "UNRESOLVED")

    def test_rumor_never_becomes_confirmed_death_and_details_are_not_statuses(self):
        self.assertEqual(summarize([claim("DECEASED", 71)]), "UNRESOLVED")
        self.assertEqual(summarize([claim("PERSON_DETAIL", 71)]), "NOT_YET_REPORTED")
        self.assertEqual(summarize([claim("MISSING", 11), claim("SEEN_AT_LOCATION", 71)]), "MISSING")

    def test_rumor_requires_visible_equal_or_unknown_time_opposition(self):
        group = [{"person_ids": ["per-000001"]}]
        rumor = claim("DECEASED", 35, release=36)
        self.assertEqual(len(rumor_conflicts([rumor, claim("MISSING", 23, release=24)], group)), 1)
        self.assertEqual(rumor_conflicts([rumor, claim("MISSING", None, release=24)], group), [])
        self.assertEqual(rumor_conflicts([rumor, claim("MISSING", 35, release=36)], group), [])
        self.assertEqual(len(rumor_conflicts([rumor, claim("MISSING", 35, release=48)], group)), 1)

    def test_recompute_hides_future_sources_and_groups_once(self):
        rows = [{"id": "per-000001", "kind": "person", "available_at": at(0)},
                {"id": "per-000002", "kind": "person", "available_at": at(0)},
                {"id": "src-000001", "kind": "source", "available_at": at(24)},
                claim("MISSING", 11, release=12)]
        groups = [{"person_ids": ["per-000001", "per-000002"]}]
        quota = {"exercise_clock_start": at(0), "identity_oracle": {"distinct_individuals": 1},
                 "checkpoint_oracle_targets": [{"hour": 12, "individuals": 0, "MISSING": 0, "FOUND_SAFE": 0, "INJURED": 0, "UNRESOLVED": 0}]}
        self.assertEqual(recompute(rows, groups, quota)[1], [])
        rows[2]["available_at"] = at(12)
        self.assertEqual(recompute(rows, groups, quota)[0][0]["observed"]["MISSING"], 1)
        with self.assertRaises(ValueError):
            recompute(rows, groups + groups, quota)
        with self.assertRaises(ValueError):
            recompute(rows, [{"person_ids": ["per-000001"]}], quota)

    def test_current_corpus_exposes_final_cohort_and_rumor_conflict_defects(self):
        # Characterization of the published partial fixture, not a passing quota gate.
        rows = list(read_catalog(ROOT).values())
        path = ROOT / "tests/fixtures" / DATASET / "oracle/identities.jsonl"
        groups = [json.loads(line) for line in path.read_text().splitlines()]
        quota = json.loads((ROOT / "demo/spec/quotas.json").read_text())
        checkpoints, errors = recompute(rows, groups, quota)
        self.assertEqual([row["hour"] for row in checkpoints], [0, 6, 12, 24, 36, 48, 72])
        self.assertEqual(checkpoints[-1]["observed"], {"NOT_YET_REPORTED": 0, "MISSING": 353, "FOUND_SAFE": 547, "INJURED": 50, "UNRESOLVED": 50})
        self.assertEqual(len(errors), 2)
        self.assertEqual(len(rumor_conflicts(rows, groups)), 6)
        self.assertTrue(all("T+72" in error for error in errors))


if __name__ == "__main__":
    unittest.main()

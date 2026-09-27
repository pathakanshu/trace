"""Offline unit checks for the supplementary corpus auditor; no app imports."""
import unittest
from tempfile import TemporaryDirectory
from pathlib import Path
from audit_contracts import shape_errors, references, reference_errors, lifecycle_errors, utc, read_jsonl


def record(ident, kind="person", available="2016-07-06T00:15:00Z", **extra):
    return {"id": ident, "kind": kind, "incident_id": "inc-000001",
            "available_at": available, **extra}


class ContractAuditTests(unittest.TestCase):
    def test_jsonl_rejects_blank_lines_and_nonfinite_numbers(self):
        with TemporaryDirectory() as folder:
            path = Path(folder) / "records.jsonl"
            for content in ('{ "value": NaN }\n', '{ "value": Infinity }\n', '\n'):
                path.write_text(content, encoding="utf-8")
                with self.subTest(content=content), self.assertRaises(ValueError):
                    read_jsonl(path)
            path.write_text('{"value":null}\n', encoding="utf-8")
            self.assertEqual(read_jsonl(path), [{"value": None}])

    def test_closed_shapes_reject_missing_extra_and_nonobjects(self):
        self.assertEqual(shape_errors({"id": "query-000001", "question": "Why?"}, "id question"), [])
        self.assertEqual(len(shape_errors({"id": "x", "runtime_answer": "invented"}, "id question")), 2)
        self.assertEqual(shape_errors([], "id"), ["expected an object"])

    def test_reference_fields_and_typed_refs_exclude_text_and_own_ids(self):
        value = {"id": "clm-000001", "subject": {"kind": "person", "id": "per-000001"},
                 "supporting_media_ids": ["med-000001"], "notes": "per-000002",
                 "identity_id": "gid-000001", "source_id": "src-000001"}
        self.assertEqual(set(references(value)), {("subject", "per-000001"),
                         ("supporting_media_ids", "med-000001"), ("source_id", "src-000001")})

    def test_same_batch_mutual_refs_are_allowed_and_future_ref_is_flagged(self):
        inc = record("inc-000001", "incident")
        person = record("per-000001", support_needs_claim_ids=["clm-000001"])
        claim = record("clm-000001", "claim", subject={"kind": "person", "id": person["id"]})
        self.assertEqual(reference_errors([inc, person, claim]), ([], [], []))
        claim["available_at"] = "2016-07-07T00:15:00Z"
        missing, cross, future = reference_errors([inc, person, claim])
        self.assertEqual(missing + cross, [])
        self.assertEqual(len(future), 1)
        self.assertIn("support_needs_claim_ids", future[0])

    def test_missing_and_cross_incident_references_are_distinct(self):
        inc = record("inc-000001", "incident")
        person = record("per-000001", location_id="loc-000001", source_id="src-899999")
        place = record("loc-000001", "location", incident_id="inc-900001")
        other = record("inc-900001", "incident", incident_id="inc-900001")
        missing, cross, future = reference_errors([inc, person, place, other])
        self.assertEqual(len(missing), 1)
        self.assertEqual(len(cross), 1)
        self.assertEqual(future, [])

    def test_actual_creation_time_and_unknown_observation_time_are_not_backdated(self):
        source = record("src-000001", "source", published_at={"value": None})
        claim = record("clm-000001", "claim", source_id=source["id"], reported_at={"value": None})
        media = record("med-000001", "media", actual_created_at="2026-09-27T07:06:00Z")
        self.assertEqual(lifecycle_errors([source, claim, media]), [])

    def test_release_batch_and_observation_publication_order_are_checked(self):
        source = record("src-000001", "source", published_at={"value": "2016-07-05T22:15:00Z"})
        claim = record("clm-000001", "claim", available="2016-07-06T01:15:00Z",
                       source_id=source["id"], reported_at={"value": "2016-07-05T23:15:00Z"})
        errors = lifecycle_errors([source, claim])
        self.assertEqual(len(errors), 2)
        self.assertTrue(any("different batches" in e for e in errors))
        self.assertTrue(any("observation follows" in e for e in errors))

    def test_saved_investigation_cannot_see_after_its_cutoff(self):
        source = record("src-000001", "source", published_at={"value": None})
        investigation = record("inv-000001", "investigation", available="2016-07-07T00:15:00Z",
            time_cutoff="2016-07-05T00:15:00Z", saved_at="2016-07-07T00:15:00Z",
            selected_claim_ids=[], selected_source_ids=[source["id"]])
        self.assertEqual(len(lifecycle_errors([source, investigation])), 1)

    def test_workflow_snapshot_cannot_precede_submission(self):
        contribution = record("con-000001", "contribution", submitted_at="2016-07-07T00:15:00Z")
        self.assertEqual(len(lifecycle_errors([contribution])), 1)

    def test_utc_parser_rejects_unknown_invalid_and_noncontract_precision(self):
        self.assertEqual(utc("2016-07-05T12:15:00Z").hour, 12)
        for value in (None, "", "2016-02-30T00:00:00Z", "2016-07-05", "2016-07-05T12:15:00+00:00", "2016-07-05T12:15:00.5Z"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                utc(value)


if __name__ == "__main__":
    unittest.main()

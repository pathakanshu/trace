"""Offline query-fixture checks; no model answers are generated or evaluated."""
import copy
import json
import unittest
from generate_queries import ROOT, DATASET, build_queries, read_catalog, validate_queries


class QueryFixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = read_catalog(ROOT)
        cls.queries = build_queries(cls.catalog)
        cls.quota = json.loads((ROOT / "demo/spec/quotas.json").read_text())["evaluation"]["query_types"]

    def test_exact_counts_closed_shapes_real_evidence_and_cutoffs(self):
        validate_queries(self.queries, self.catalog, self.quota)
        self.assertEqual(len(self.queries), 40)
        self.assertTrue(all(q["required_claim_ids"] for q in self.queries))

    def test_generation_is_deterministic_even_when_catalog_order_changes(self):
        reversed_catalog = dict(reversed(list(self.catalog.items())))
        self.assertEqual(self.queries, build_queries(reversed_catalog))

    def test_maya_baseline_hides_hospital_and_later_queries_include_it(self):
        self.assertEqual(self.queries[0]["required_claim_ids"], ["clm-000001"])
        self.assertIn("clm-001301", self.queries[1]["required_claim_ids"])
        self.assertIn("clm-001901", self.queries[2]["required_claim_ids"])

    def test_media_pair_requires_both_publication_sources(self):
        media_query = next(q for q in self.queries if q["query_type"] == "MEDIA_LINEAGE")
        for ident in ("med-000001", "med-000121"):
            self.assertIn(self.catalog[ident]["source_id"], media_query["required_source_ids"])

    def test_future_missing_and_wrong_kind_evidence_are_rejected(self):
        for bad_id in ("clm-001301", "clm-899999", "per-000001"):
            queries = copy.deepcopy(self.queries)
            queries[0]["required_claim_ids"] = [bad_id]
            with self.subTest(ident=bad_id), self.assertRaises(ValueError):
                validate_queries(queries, self.catalog, self.quota)

    def test_empty_citations_hidden_answer_fields_and_bad_timestamps_fail(self):
        mutations = [("required_claim_ids", []), ("runtime_answer", "not allowed"),
                     ("at", "2016-7-5T12:15:00Z"), ("at", "2016-07-05")]
        for key, value in mutations:
            queries = copy.deepcopy(self.queries)
            queries[0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_queries(queries, self.catalog, self.quota)

    def test_missing_catalog_evidence_blocks_generation(self):
        incomplete = {key: row for key, row in self.catalog.items() if row["kind"] != "claim"}
        with self.assertRaises(ValueError):
            build_queries(incomplete)


if __name__ == "__main__":
    unittest.main()

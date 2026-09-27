"""Validate control inputs without claiming the app's reset has executed."""
import hashlib
import json
import unittest
from collections import Counter
from pathlib import Path
from tempfile import TemporaryDirectory

import jsonschema
from audit_contracts import reference_errors, lifecycle_errors, shape_errors, run_audit
from generate_controls import ROOT, DATASET, RAW, build_controls, write_controls


class ControlPackTests(unittest.TestCase):
    def test_exact_quotas_schema_reserved_ids_and_closed_references(self):
        records, raw = build_controls()
        schema = json.loads((ROOT / "demo/spec/trace-record.schema.json").read_text())
        validator = jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker())
        quota = json.loads((ROOT / "demo/spec/quotas.json").read_text())["control_pack_excluded_from_primary"]
        self.assertEqual(dict(Counter(row["kind"] for row in records)), quota)
        self.assertEqual(len(raw), 2)
        self.assertEqual(len({row["id"] for row in records}), 26)
        for row in records:
            with self.subTest(record=row["id"]):
                validator.validate(row)
                self.assertGreaterEqual(int(row["id"][-6:]), 900001)
                self.assertLessEqual(int(row["id"][-6:]), 999999)
        self.assertEqual(reference_errors(records), ([], [], []))
        self.assertEqual(lifecycle_errors(records), [])

    def test_source_bytes_excerpts_entries_and_publisher_match(self):
        records, raw = build_controls()
        for source in [row for row in records if row["kind"] == "source"]:
            content = raw[source["raw_path"]]
            self.assertEqual(hashlib.sha256(content).hexdigest(), source["raw_sha256"])
            document = json.loads(content)
            self.assertEqual(shape_errors(document, "schema_version source_id report_reference publisher original_language published_time_text original_content entries"), [])
            self.assertEqual(document["publisher"], source["publisher"])
            self.assertEqual(document["report_reference"], source["report_reference"])
            claims = [row for row in records if row["kind"] == "claim" and row["source_id"] == source["id"]]
            self.assertEqual(len(claims), len(document["entries"]))
            self.assertEqual(len(claims), 5)
            for index, claim in enumerate(claims):
                self.assertEqual(claim["provenance"]["source_locator"], f"entries[{index}]")
                self.assertEqual(claim["assertion"]["text"], document["entries"][index]["assertion_text"])
                self.assertIn(claim["provenance"]["original_excerpt"], document["original_content"])

    def test_colliding_name_and_reference_stay_in_distinct_incidents(self):
        records, _ = build_controls()
        mayas = [r for r in records if r["kind"] == "person" and r["display_name"] == "Maya Gurung"]
        self.assertEqual(len(mayas), 2)
        self.assertEqual(len({r["incident_id"] for r in mayas}), 2)
        sources = [r for r in records if r["kind"] == "source"]
        self.assertEqual(len({r["report_reference"] for r in sources}), 1)
        self.assertEqual(len({(r["incident_id"], r["publisher"]["id"], r["report_reference"]) for r in sources}), 2)
        self.assertNotIn("inc-000001", {r["incident_id"] for r in records})

    def test_rerun_is_byte_identical_and_preserves_unrelated_files(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            unrelated = root / "untouched.txt"
            unrelated.write_text("preserve")
            self.assertEqual(write_controls(root), (26, 2))
            before = {p.relative_to(root): (p.read_bytes(), p.stat().st_mtime_ns) for p in root.rglob("*") if p.is_file()}
            self.assertEqual(write_controls(root), (26, 2))
            after = {p.relative_to(root): (p.read_bytes(), p.stat().st_mtime_ns) for p in root.rglob("*") if p.is_file()}
            self.assertEqual(before, after)

    def test_different_existing_fixture_blocks_all_writes(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            conflict = root / RAW / "src-900002.json"
            conflict.parent.mkdir(parents=True)
            conflict.write_text("already authored")
            with self.assertRaises(ValueError):
                write_controls(root)
            self.assertFalse((root / RAW / "src-900001.json").exists())
            self.assertEqual(conflict.read_text(), "already authored")

    def test_saved_control_audit_detects_tampered_raw_bytes(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            spec = root / "demo/spec"
            spec.mkdir(parents=True)
            for name in ("quotas.json", "trace-record.schema.json"):
                (spec / name).write_bytes((ROOT / "demo/spec" / name).read_bytes())
            write_controls(root)
            before = run_audit(root)
            control = next(c for c in before["checks"] if c["rule_id"] == "control_pack")
            self.assertEqual(control["status"], "pass")
            raw = root / RAW / "src-900001.json"
            raw.write_bytes(raw.read_bytes() + b" ")
            after = run_audit(root)
            control = next(c for c in after["checks"] if c["rule_id"] == "control_pack")
            self.assertEqual(control["status"], "fail")
            self.assertTrue(any("hash mismatch" in e for e in control["observed"]["examples"]))

    def test_saved_control_audit_reports_nonobject_without_crashing(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            spec = root / "demo/spec"
            spec.mkdir(parents=True)
            for name in ("quotas.json", "trace-record.schema.json"):
                (spec / name).write_bytes((ROOT / "demo/spec" / name).read_bytes())
            write_controls(root)
            path = root / f"tests/fixtures/{DATASET}/control/records.jsonl"
            path.write_text(path.read_text() + "null\n")
            result = run_audit(root)
            control = next(c for c in result["checks"] if c["rule_id"] == "control_pack")
            self.assertEqual(control["status"], "fail")
            self.assertTrue(any("fails catalog schema" in e for e in control["observed"]["examples"]))

    def test_symlink_escape_blocks_all_writes(self):
        with TemporaryDirectory() as folder, TemporaryDirectory() as outside:
            root = Path(folder)
            (root / "demo").symlink_to(outside, target_is_directory=True)
            with self.assertRaises(ValueError):
                write_controls(root)
            self.assertEqual(list(Path(outside).iterdir()), [])


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Strict supplementary audit of the partial corpus; never imports or repairs it.

The legacy validator covers catalog schemas and assets but not every support-file
contract or release dependency. This tool reports those gaps separately. Exit 1
means observed failures, 2 means only blocked checks, 0 means this limited audit
passed. None of these codes certifies runtime behavior or complete conformance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from importlib.metadata import version
from pathlib import Path

import jsonschema

ROOT = Path(__file__).resolve().parents[2]
DATASET = "bhotekoshi-2016-exercise-v1"
PREFIXES = "inc per org src clm med loc fac inf haz aid act con vot tsk sub inv".split()
ID_PATTERN = re.compile(r"(?:" + "|".join(PREFIXES) + r")-\d{6}$")

# Exact top-level shapes from record-contract.md. Nested semantics are audited
# separately where implemented, never implied by a top-level shape pass.
SHAPES = {
    "manifest.json": "schema_version dataset_id seed sampler generated_at generator asset_tools scenario_clock_start schema_path quota_path files profiles deviations limitations",
    "licenses.json": "dataset_id assets",
    "context/historical-references.jsonl": "id url title publisher publication_date retrieval_date supported_statement passage_or_figure event_time scope_and_uncertainty",
    "oracle/identities.jsonl": "id person_ids canonical_age primary_person_id initial_location_id initial_precision initial_cluster",
    "oracle/identity-pairs.jsonl": "id person_a_id person_b_id same_individual evidence_claim_ids rationale tags",
    "oracle/media-families.jsonl": "id base_media_id family_class content_category base_metadata members unrelated_lookalike_family_ids tags",
    "oracle/checkpoints.jsonl": "id hours_from_start at identity_summaries summary_counts required_assertions",
    "replay/scenarios.jsonl": "id title purpose tabs focal_refs action_ids required_capabilities expected_assertions",
    "replay/actions.jsonl": "id scenario_ids at actor_id operation payload requires_capabilities after_action_ids expected_assertions",
    "queries.jsonl": "id query_type question at required_claim_ids required_source_ids acceptable_uncertainty forbidden_conclusions",
    "invalid-inputs.jsonl": "id category description input_encoding input precondition_action_ids expected_error_class expected_record_delta required_capability",
    "validation-report.json": "dataset_id generated_at tools checks summary",
}
PRIVATE = {name for name in SHAPES if name.startswith(("oracle/", "replay/"))} | {"queries.jsonl", "invalid-inputs.jsonl"}


def shape_errors(value, fields):
    if not isinstance(value, dict):
        return ["expected an object"]
    required = set(fields.split())
    errors = []
    if required - value.keys():
        errors.append("missing: " + ", ".join(sorted(required - value.keys())))
    if value.keys() - required:
        errors.append("unexpected: " + ", ".join(sorted(value.keys() - required)))
    return errors


def reject_nonfinite(value):
    raise ValueError("non-JSON numeric constant: " + value)


def read_jsonl(path):
    rows = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            raise ValueError(f"blank line {number}")
        rows.append(json.loads(line, parse_constant=reject_nonfinite))
    return rows


def utc(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", value):
        raise ValueError("expected whole-second UTC timestamp ending Z")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def references(value, field=""):
    """Yield explicit catalog-ID references, excluding each object's own ID.

Private identity IDs, context IDs, arbitrary text and actual creation timestamps
are deliberately outside this traversal. Schema validation checks ref kind/prefix.
"""
    if isinstance(value, dict):
        if set(value) == {"kind", "id"} and isinstance(value["id"], str):
            if ID_PATTERN.fullmatch(value["id"]):
                yield field, value["id"]
            return
        for key, item in value.items():
            if key == "id":
                continue
            yield from references(item, key)
    elif isinstance(value, list):
        for item in value:
            yield from references(item, field)
    elif isinstance(value, str) and (field.endswith("_id") or field.endswith("_ids")) and ID_PATTERN.fullmatch(value):
        yield field, value


def reference_errors(records):
    catalog = {r["id"]: r for r in records}
    missing, cross_incident, future = [], [], []
    for row in records:
        for field, target_id in sorted(set(references(row))):
            target = catalog.get(target_id)
            label = f"{row['id']}.{field} -> {target_id}"
            if target is None:
                missing.append(label)
                continue
            if target["incident_id"] != row["incident_id"]:
                cross_incident.append(label)
            if utc(target["available_at"]) > utc(row["available_at"]):
                future.append(label + f" ({target['available_at']} > {row['available_at']})")
    return missing, cross_incident, future


def lifecycle_errors(records):
    catalog = {r["id"]: r for r in records}
    errors = []
    for row in records:
        available = utc(row["available_at"])
        for key in ("created_at", "updated_at", "submitted_at", "voted_at", "saved_at"):
            if row.get(key) and utc(row[key]) > available:
                errors.append(f"{row['id']}.{key} follows release")
        if row["kind"] == "source" and row["published_at"].get("value"):
            if utc(row["published_at"]["value"]) > available:
                errors.append(f"{row['id']} published after release")
        if row["kind"] == "claim":
            source = catalog.get(row["source_id"])
            if source and source["available_at"] != row["available_at"]:
                errors.append(f"{row['id']} and {source['id']} release in different batches")
            reported = row["reported_at"].get("value")
            published = source["published_at"].get("value") if source else None
            if reported and published and utc(reported) > utc(published):
                errors.append(f"{row['id']} observation follows source publication")
        if row["kind"] == "investigation":
            cutoff = utc(row["time_cutoff"])
            if cutoff > utc(row["saved_at"]):
                errors.append(f"{row['id']} cutoff follows saved time")
            for target_id in row["selected_claim_ids"] + row["selected_source_ids"]:
                if target_id in catalog and utc(catalog[target_id]["available_at"]) > cutoff:
                    errors.append(f"{row['id']} selects {target_id} after cutoff")
    return errors


def run_audit(root):
    root = root.resolve()
    data = root / "demo/datasets" / DATASET
    fixtures = root / "tests/fixtures" / DATASET
    checks = []

    def add(rule, errors, expected, paths, limitations=()):
        checks.append({"rule_id": rule, "status": "fail" if errors else "pass",
                       "observed": {"failure_count": len(errors), "examples": errors[:12]},
                       "expected": expected, "evidence_paths": paths,
                       "limitations": list(limitations)})

    def rel(path):
        return path.relative_to(root).as_posix()

    for name, fields in SHAPES.items():
        path = (fixtures if name in PRIVATE else data) / name
        errors = []
        try:
            values = read_jsonl(path) if path.suffix == ".jsonl" else [json.loads(path.read_text(encoding="utf-8"))]
            if not values:
                errors.append("file is empty")
            for number, value in enumerate(values, 1):
                problems = shape_errors(value, fields)
                if problems:
                    errors.append(f"row {number}: " + "; ".join(problems))
        except (OSError, ValueError) as error:
            errors.append(str(error).replace(str(root), "<repo>"))
        add("support_shape:" + name, errors, fields.split(), [rel(path)],
            ["Exact top-level fields only; a pass does not validate every nested value."])
        if name == "manifest.json" and path.is_file():
            checks[-1]["observed"]["manifest_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()

    schema_path = root / "demo/spec/trace-record.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    validator = jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker())
    records, schema_errors, parse_errors = [], [], []
    for path in sorted((data / "records").rglob("*.jsonl")):
        try:
            rows = read_jsonl(path)
        except (OSError, ValueError) as error:
            parse_errors.append(f"{rel(path)}: {error}")
            continue
        for number, row in enumerate(rows, 1):
            error = next(validator.iter_errors(row), None)
            if error:
                schema_errors.append(f"{rel(path)}:{number}: {error.message[:140]}")
            else:
                records.append(row)
    if not records:
        parse_errors.append("no schema-valid records found")
    add("catalog_schema", parse_errors + schema_errors, "All records pass Draft 2020-12 with format checking", [rel(data / "records"), rel(schema_path)])
    duplicate_ids = [key for key, count in Counter(r["id"] for r in records).items() if count > 1]
    add("catalog_unique_ids", duplicate_ids, "Every catalog ID occurs once", [rel(data / "records")])
    missing, cross_incident, future = reference_errors(records)
    add("catalog_reference_closure", missing, "Every catalog reference resolves", [rel(data / "records")])
    add("catalog_incident_isolation", cross_incident, "References remain inside the primary incident", [rel(data / "records")])
    add("catalog_release_closure", future, "A record never reveals a referenced record before its available_at", [rel(data / "records")])
    add("catalog_lifecycle_times", lifecycle_errors(records), "Workflow/report times respect release and publication cutoffs", [rel(data / "records")], ["Actual media creation time is deliberately not compared with the fictional exercise clock."])

    query_path = fixtures / "queries.jsonl"
    query_errors = []
    try:
        from generate_queries import validate_queries
        query_quota = json.loads((root / "demo/spec/quotas.json").read_text())["evaluation"]["query_types"]
        validate_queries(read_jsonl(query_path), {row["id"]: row for row in records}, query_quota)
    except (OSError, ValueError, KeyError, TypeError) as error:
        query_errors.append(str(error).replace(str(root), "<repo>"))
    add("query_evidence_and_cutoffs", query_errors, "40 distinct questions, exact category counts, real citations available by cutoff, no answer fields",
        [rel(query_path), rel(data / "records")], ["No query was answered or scored by an application/model."])

    control_path = fixtures / "control/records.jsonl"
    control_errors = []
    expected_controls = json.loads((root / "demo/spec/quotas.json").read_text())["control_pack_excluded_from_primary"]
    try:
        control_rows = read_jsonl(control_path)
        actual = dict(Counter(row.get("kind") for row in control_rows if isinstance(row, dict)))
        if actual != expected_controls:
            control_errors.append(f"counts {actual} != {expected_controls}")
        valid_controls = []
        for row in control_rows:
            if not validator.is_valid(row):
                control_errors.append("control record fails catalog schema")
                continue
            valid_controls.append(row)
            control_id = row["id"]
            if not ID_PATTERN.fullmatch(control_id) or not 900001 <= int(control_id[-6:]) <= 999999:
                control_errors.append("control ID is outside the reserved range")
        if len(valid_controls) == len(control_rows):
            control_ids = Counter(row["id"] for row in valid_controls)
            control_errors.extend("duplicate control ID: " + ident for ident, count in control_ids.items() if count > 1)
            missing_control, cross_control, future_control = reference_errors(valid_controls)
            control_errors.extend(missing_control + cross_control + future_control + lifecycle_errors(valid_controls))
            for source in [row for row in valid_controls if row["kind"] == "source"]:
                raw_path = root / source["raw_path"]
                if not raw_path.resolve().is_relative_to(root):
                    control_errors.append(source["id"] + " raw path escapes repository")
                    continue
                raw_bytes = raw_path.read_bytes()
                if hashlib.sha256(raw_bytes).hexdigest() != source["raw_sha256"]:
                    control_errors.append(source["id"] + " raw source hash mismatch")
                raw = json.loads(raw_bytes)
                control_errors.extend(source["id"] + ": " + issue for issue in shape_errors(raw,
                    "schema_version source_id report_reference publisher original_language published_time_text original_content entries"))
                claims = [row for row in valid_controls if row["kind"] == "claim" and row["source_id"] == source["id"]]
                if len(claims) != 5:
                    control_errors.append(source["id"] + " must assert exactly five control claims")
                if isinstance(raw, dict):
                    if raw.get("publisher") != source["publisher"] or raw.get("source_id") != source["id"]:
                        control_errors.append(source["id"] + " raw publisher/source mismatch")
                    text = raw.get("original_content")
                    for claim in claims:
                        if not isinstance(text, str) or claim["provenance"]["original_excerpt"] not in text:
                            control_errors.append(claim["id"] + " excerpt absent from original control source")
    except (OSError, ValueError) as error:
        control_errors.append(str(error).replace(str(root), "<repo>"))
    add("control_pack", control_errors, expected_controls, [rel(control_path)])

    quotas = json.loads((root / "demo/spec/quotas.json").read_text())
    locations = sum(row["kind"] == "location" for row in records)
    expected_locations = quotas["primary_catalog_counts"]["location"]
    for rule, reason in [
        ("complete_geographic_placement", f"{locations}/{expected_locations} location records present; this audit cannot approve geographic sampling or area inputs."),
        ("runtime_import_replay_reset", "No compatible corpus importer/replay runner was invoked; existing small-app smoke tests do not validate this corpus."),
    ]:
        checks.append({"rule_id": rule, "status": "blocked", "observed": reason,
                       "expected": "Independently validate before claiming complete", "evidence_paths": [rel(data / "README.md")],
                       "limitations": ["This audit does not run application walkers or load a runtime database."]})
    summary = dict(Counter(check["status"] for check in checks))
    summary = {status: summary.get(status, 0) for status in ("pass", "fail", "blocked")}
    return {"dataset_id": DATASET, "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "tools": [{"name": "tools/test_data/audit_contracts.py", "version": "1.1"}, {"name": "jsonschema", "version": version("jsonschema")}],
            "checks": checks, "summary": summary}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, help="Write the measured audit; omitted means stdout only")
    args = parser.parse_args()
    report = run_audit(args.root.resolve())
    if args.output:
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report["summary"]))
    else:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if report["summary"]["fail"] else (2 if report["summary"]["blocked"] else 0)


if __name__ == "__main__":
    sys.exit(main())

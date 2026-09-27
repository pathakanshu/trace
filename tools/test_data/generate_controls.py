#!/usr/bin/env python3
"""Author the specification's separate, fictional reset-isolation pack.

This creates inputs only. It does not run reset, create a shared relationship,
import into Jac, or change any primary record/asset. Refuse to overwrite differing
existing control data; stable IDs must not silently acquire different contents.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET = "bhotekoshi-2016-exercise-v1"
START = "2016-07-05T12:15:00Z"
RELEASE = "2016-07-06T00:15:00Z"
RAW = f"demo/datasets/{DATASET}/raw/reports"


def time_value(value=None, original=None):
    return {"value": value, "date": None, "precision": "minute" if value else "unknown",
            "original_text": original, "timezone": "Asia/Kathmandu" if value else None,
            "range_start": None, "range_end": None}


def common(kind, ident, incident, available=RELEASE):
    return {"schema_version": "1.0", "dataset_id": DATASET, "kind": kind,
            "id": ident, "incident_id": incident, "available_at": available,
            "is_synthetic": True}


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def build_controls():
    records, raw_files = [], {}
    # Reuse the SAME reference under separate incident/publisher scopes. One
    # name/age also collides with primary Maya, without establishing identity.
    report_reference = "CONTROL-SHARED-REFERENCE-001"
    for offset, letter in enumerate(("A", "B")):
        counter = 900001 + offset
        incident, organization, source = (f"{prefix}-{counter:06d}" for prefix in ("inc", "org", "src"))
        records.append({**common("incident", incident, incident, START),
            "name": f"Isolation Control Exercise {letter}",
            "description": "Entirely fictional control incident for reset isolation. Not part of the primary Bhote Koshi workload or a historical event count.",
            "event_time": time_value(), "exercise_clock_start": START,
            "display_timezone": "Asia/Kathmandu", "historical_reference_ids": []})
        records.append({**common("organization", organization, incident, START),
            "name": f"Control Search Desk Exercise {letter}", "organization_type": "POLICE_RESCUE",
            "description": "Fictional control institution; not an actual agency. Keep separate from the primary incident."})
        entries, claim_texts = [], []
        for index in range(5):
            number = 900001 + offset * 5 + index
            person, claim = f"per-{number:06d}", f"clm-{number:06d}"
            name = "Maya Gurung" if index == 0 else f"Control {letter} Person {index + 1:02d}"
            text = f"Control Exercise {letter} lists fictional {name} as not yet contacted. This report concerns only control incident {letter}; location and last-contact time are unknown."
            records.append({**common("person", person, incident), "display_name": name,
                "name_variants": [name], "reported_age": 24 if index == 0 else None,
                "description": "Fictional isolation-control person. A matching name or age does not establish identity across incidents.",
                "support_needs_claim_ids": []})
            records.append({**common("claim", claim, incident), "source_id": source,
                "subject": {"kind": "person", "id": person},
                "assertion": {"type": "MISSING", "text": text, "quantity": None, "unit": None, "related_subjects": []},
                "reported_at": time_value(),
                "provenance": {"extraction_method": "fixture_authored", "original_excerpt": text,
                               "source_locator": f"entries[{index}]"},
                "location_id": None, "supporting_media_ids": [], "corrects_claim_ids": [], "related_claim_ids": []})
            claim_texts.append(text)
            entries.append({"subject_label": name, "assertion_text": text,
                            "reported_time_text": None, "location_text": None})
        publisher = {"kind": "organization", "id": organization}
        raw = {"schema_version": "1.0", "source_id": source, "report_reference": report_reference,
               "publisher": publisher, "original_language": "en", "published_time_text": "2016-07-06 05:00 NPT (fictional exercise clock)",
               "original_content": f"FICTIONAL CONTROL EXERCISE {letter}.\n" + "\n".join(claim_texts), "entries": entries}
        path = f"{RAW}/{source}.json"
        raw_files[path] = encoded(raw)
        records.append({**common("source", source, incident), "title": f"Control Exercise {letter} intake bulletin",
            "publisher": publisher, "source_type": "POLICE_RESCUE", "report_reference": report_reference,
            "published_at": time_value("2016-07-05T23:15:00Z", raw["published_time_text"]),
            "original_language": "en", "raw_format": "structured_json", "raw_path": path,
            "raw_sha256": hashlib.sha256(raw_files[path]).hexdigest(), "dependencies": [],
            "dependency_disclosure": "no_dependency_declared"})
    records.sort(key=lambda row: row["id"])
    return records, raw_files


def write_controls(root):
    records, raw_files = build_controls()
    output = {**raw_files, f"tests/fixtures/{DATASET}/control/records.jsonl": b"".join(encoded(row) for row in records)}
    # Preflight every target before writing any; matching files are left intact.
    for name, content in output.items():
        path = root / name
        if not path.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Control path escapes root: {name}")
        if path.is_symlink() or (path.exists() and path.read_bytes() != content):
            raise ValueError(f"Refusing to replace different control fixture: {name}")
    for name, content in output.items():
        path = root / name
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    return len(records), len(raw_files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    count, sources = write_controls(args.root.resolve())
    print(json.dumps({"control_records": count, "raw_control_reports": sources,
                      "runtime_reset_executed": False, "primary_records_changed": 0}))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Author held-out research questions from existing public catalog evidence.

Only private query fixtures are written. No expected answer, identity truth,
model output, verification result or runtime trace is fabricated. Catalog IDs,
records and assets are unchanged. Original qry-* placeholders were not contract
IDs; this suite uses the specified query-* IDs, in the same category order.
"""
from __future__ import annotations
import argparse
import json
import re
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET = "bhotekoshi-2016-exercise-v1"
START = datetime(2016, 7, 5, 12, 15, tzinfo=timezone.utc)


def at(hour):
    return (START + timedelta(hours=hour)).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_catalog(root):
    rows = [json.loads(line) for path in sorted((root / "demo/datasets" / DATASET / "records").rglob("*.jsonl"))
            for line in path.read_text(encoding="utf-8").splitlines()]
    return {row["id"]: row for row in rows}


def build_queries(catalog):
    claims = [row for row in catalog.values() if row["kind"] == "claim"]
    output = []

    def add(kind, question, subjects, hour=72, uncertainty=(), forbidden=()):
        cutoff = at(hour)
        media = {ident for ident in subjects if catalog[ident]["kind"] == "media"}
        media_sources = {catalog[ident]["source_id"] for ident in media}
        evidence = sorted([c for c in claims if c["available_at"] <= cutoff and (
            c["subject"]["id"] in subjects or set(c["supporting_media_ids"]) & media or c["source_id"] in media_sources)], key=lambda c: c["id"])
        if not evidence:
            raise ValueError("Question has no available supporting catalog claims: " + question)
        sources = sorted({c["source_id"] for c in evidence})
        if any(catalog[s]["available_at"] > cutoff for s in sources):
            raise ValueError("Question requires a source released after its cutoff")
        output.append({"id": f"query-{len(output) + 1:06d}", "query_type": kind,
            "question": question, "at": cutoff, "required_claim_ids": [c["id"] for c in evidence],
            "required_source_ids": sources,
            "acceptable_uncertainty": list(uncertainty) + ["Only claims available at the query cutoff may be cited; source assertions can be wrong."],
            "forbidden_conclusions": list(forbidden) + ["Do not present fictional reports as historical victim facts or invent a successful agent trace."]})

    person_cases = [
        ("per-000001", 12, "What do the available reports say about Maya Gurung at the baseline, before later hospital updates?"),
        ("per-000001", 24, "What changed in the source reports about Maya Gurung between the baseline and this cutoff?"),
        ("per-000001", 72, "For Maya Gurung, distinguish the reported observation times from when late reports became available. Does later arrival alone justify replacing the latest dated status?"),
        ("per-000002", 72, "Compare all visible status and sighting reports for per-000002. Which claims are historical context and which support the latest dated summary?"),
        ("per-000041", 36, "What sources support the timeline of per-000041 at T+36, and what does a sighting fail to establish about safety?"),
        ("per-000057", 48, "Summarize the dated reports for per-000057 at T+48 without combining this record with another person's timeline."),
        ("per-000150", 36, "Which reports changed the account for per-000150 by T+36, and which source is responsible for each assertion?"),
        ("per-000300", 72, "For per-000300, explain any differences between a status claim and a location observation; retain both source histories."),
        ("per-000500", 72, "What is the source-supported change history for per-000500, and which details remain unknown?"),
        ("per-000700", 72, "What can the available reports establish about per-000700 by T+72, and is the absence of a later report evidence of safety?"),
    ]
    for ident, hour, question in person_cases:
        add("PERSON_CHANGE", question + f" Record: {ident}.", [ident], hour,
            ["Do not combine records without an attributed human identity review; unknown times remain unknown."],
            ["A later ingestion time alone does not reverse a newer dated report.", "A reported status is not a verified real-world outcome."])

    geographic = [
        ("inf-000001", "Compare the access and inspection reports for this asset. Does either demonstrate a safe evacuation route?"),
        ("inf-000002", "Who reported access restrictions for this asset, and when was that report available?"),
        ("inf-000011", "Explain the bridge-related claims while distinguishing a reported obstruction from an engineering inspection."),
        ("inf-000019", "What can be said about this power asset from the published reports, and what measurements are missing?"),
        ("haz-000001", "Summarize the flood observations at this subject without inferring depth, discharge, or measured inundation extent."),
        ("haz-000009", "Which sources describe this slope/debris observation, and do they establish whether access is safe now?"),
        ("haz-000015", "Describe the secondary/access hazard reports and the limitations of their location evidence."),
        ("inf-000025", "What is reported about this water/communications asset, and does an inspection request establish restored service?"),
    ]
    for ident, question in geographic:
        subject = catalog[ident]
        add("GEOGRAPHIC_ACCESS", f"{question} Subject: {subject['name']} ({ident}).", [ident],
            uncertainty=["Geographic placement is incomplete; mapped anchors are current context, not a measured 2016 flood boundary."],
            forbidden=["Do not infer a guaranteed safe route, measured flood depth, or exact live position from a pin."])

    aid_facility = [
        ("aid-000001", "What needs are reported, by whom, and in what units? Separate them from fulfilled deliveries."),
        ("aid-000021", "Compare any need, offer, and delivery assertions for this aid subject; do not silently reconcile differing reports."),
        ("aid-000033", "Which delivery-related statements are actually present, and what evidence would establish receipt?"),
        ("aid-000040", "Describe this aid subject's sourced history without treating repeated reports as independent inventory entries."),
        ("fac-000001", "What capacity and service claims are available for this treatment site? Can current occupancy be determined?"),
        ("fac-000009", "What do the shelter reports state, and can bed or space availability be calculated without an occupancy report?"),
        ("fac-000021", "Which services or capacities are reported for this distribution site, and which quantities are not comparable?"),
        ("fac-000029", "Summarize this coordination site's reports without treating its fictional name or operator as verified institutional authority."),
    ]
    for ident, question in aid_facility:
        add("AID_FACILITY", f"{question} Subject: {catalog[ident]['name']} ({ident}).", [ident],
            uncertainty=["Capacity, occupancy, needs, offers and deliveries have distinct meanings; absent counts stay unknown."],
            forbidden=["Do not subtract incompatible units, invent occupancy, or certify an aid delivery from an offer."])

    media_cases = [
        ("med-000001", "med-000121", "Compare publication and availability of these uploads. Explain why the first received copy need not be the earliest known publication."),
        ("med-000002", "med-000122", "Compare the captions and source context of these uploads. Do repeated images count as independent corroboration?"),
        ("med-000003", None, "What does this upload's caption claim, and can controlled metadata establish that the claimed location is correct?"),
        ("med-000041", "med-000161", "Compare the available source claims for these uploads. What must an actual byte or image check establish before calling them related?"),
        ("med-000061", "med-000181", "What provenance information is available for these uploads, and what remains unknown without running a media comparison?"),
        ("med-000071", "med-000191", "Separate the published context of these uploads from any unexecuted crop or similarity hypothesis."),
        ("med-000081", None, "What does this upload's source actually claim? Does a similar-looking scene elsewhere establish a common origin?"),
        ("med-000096", None, "Summarize the available media claims and identify the limits of capture-time or authenticity conclusions."),
    ]
    for first, second, question in media_cases:
        ids = [first] + ([second] if second else [])
        add("MEDIA_LINEAGE", question + " Uploads: " + ", ".join(ids) + ".", ids,
            uncertainty=["Media are controlled dummy illustrations. Hashes/metadata require real tool execution; fixture family truth is not an application input."],
            forbidden=["Do not invent a verification result, call the earliest known copy the definitive original, or count reposts as independent witnesses."])

    insufficient = [
        (["per-000001"], "Can these reports establish Maya Gurung's exact live whereabouts?", "Reported or historical locations are not live tracking."),
        (["per-000002", "per-000022"], "Do the similar names/ages in per-000002 and per-000022 prove that they are the same individual?", "Names and ages alone cannot establish identity; a human review must cite additional evidence."),
        (["haz-000001"], "What was the exact measured flood depth at haz-000001?", "These reports do not supply a validated hydrodynamic measurement."),
        (["fac-000009"], "How many people can safely be admitted to this shelter right now?", "Capacity without current verified occupancy and safety assessment does not establish available places."),
        (["med-000003"], "Can med-000003 prove a real historical event happened at its captioned coordinates?", "A controlled exercise image cannot certify documentary provenance or a real location."),
        (["inf-000001"], "Can a route across inf-000001 be guaranteed safe based on this corpus?", "Reports of access and inspection needs do not certify route safety."),
    ]
    for subjects, question, limitation in insufficient:
        add("INSUFFICIENT_EVIDENCE", question, subjects, uncertainty=[limitation],
            forbidden=["Do not guess the requested missing fact or convert absence of evidence into certainty."])
    return output


def validate_queries(queries, catalog, quota):
    fields = set("id query_type question at required_claim_ids required_source_ids acceptable_uncertainty forbidden_conclusions".split())
    if dict(Counter(q["query_type"] for q in queries)) != quota:
        raise ValueError("Query type counts differ from the specification")
    if len({q["id"] for q in queries}) != len(queries) or len({q["question"] for q in queries}) != len(queries):
        raise ValueError("Query IDs or questions repeat")
    for index, q in enumerate(queries, 1):
        if set(q) != fields or q["id"] != f"query-{index:06d}":
            raise ValueError("Query shape or ID differs from contract")
        if not isinstance(q["at"], str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", q["at"]):
            raise ValueError("Query cutoff must use whole-second UTC")
        datetime.strptime(q["at"], "%Y-%m-%dT%H:%M:%SZ")
        if not q["question"].strip() or not q["required_claim_ids"] or not q["required_source_ids"] or not q["acceptable_uncertainty"] or not q["forbidden_conclusions"]:
            raise ValueError("Query has unpopulated evidence or limitations")
        for field, kind in (("required_claim_ids", "claim"), ("required_source_ids", "source")):
            if len(q[field]) != len(set(q[field])):
                raise ValueError("Repeated query evidence ID")
            for ident in q[field]:
                row = catalog.get(ident)
                if not row or row["kind"] != kind or row["available_at"] > q["at"]:
                    raise ValueError("Missing, wrong-kind or future query evidence: " + ident)
        if {catalog[c]["source_id"] for c in q["required_claim_ids"]} != set(q["required_source_ids"]):
            raise ValueError("Required sources do not match the required claims")


def write_queries(root):
    catalog = read_catalog(root)
    queries = build_queries(catalog)
    quota = json.loads((root / "demo/spec/quotas.json").read_text())["evaluation"]["query_types"]
    validate_queries(queries, catalog, quota)
    path = root / "tests/fixtures" / DATASET / "queries.jsonl"
    path.write_text("".join(json.dumps(q, ensure_ascii=False, separators=(",", ":")) + "\n" for q in queries), encoding="utf-8")
    return queries


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    result = write_queries(args.root.resolve())
    print(json.dumps({"queries": len(result), "counts": dict(Counter(q["query_type"] for q in result)), "runtime_answers_generated": 0}))

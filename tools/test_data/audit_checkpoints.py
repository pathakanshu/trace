"""Private fixture diagnostics, not application status logic or identity decisions.

Group records using the held-out identity oracle solely to audit fixture design.
Compare latest known observation-time statuses plus undated competing statuses.
A DECEASED assertion is always an unverified rumor in this exercise, so it cannot
produce a confirmed-death summary. Separately require the specified equal-time
or unknown-time opposing evidence for each such rumor. No reports are rewritten.
"""
from collections import Counter, defaultdict
from datetime import timedelta

from audit_contracts import utc

STATUSES = {"MISSING", "FOUND_SAFE", "INJURED", "DECEASED"}
SUMMARIES = ("NOT_YET_REPORTED", "MISSING", "FOUND_SAFE", "INJURED", "UNRESOLVED")


def summarize(claims):
    status_claims = [c for c in claims if c["assertion"]["type"] in STATUSES]
    if not status_claims:
        return "NOT_YET_REPORTED"
    dated = [c for c in status_claims if c["reported_at"]["value"] is not None]
    latest = max((utc(c["reported_at"]["value"]) for c in dated), default=None)
    applicable = {c["assertion"]["type"] for c in status_claims
                  if c["reported_at"]["value"] is None or utc(c["reported_at"]["value"]) == latest}
    if len(applicable) > 1 or "DECEASED" in applicable:
        return "UNRESOLVED"
    return next(iter(applicable))


def recompute(records, groups, quotas):
    catalog = {r["id"]: r for r in records}
    persons = {r["id"] for r in records if r["kind"] == "person"}
    grouped = [pid for group in groups for pid in group["person_ids"]]
    if set(grouped) != persons or len(grouped) != len(set(grouped)):
        raise ValueError("Private identity groups must partition every Person exactly once")
    if len(groups) != quotas["identity_oracle"]["distinct_individuals"]:
        raise ValueError("Private identity count differs from quota")
    claims_by_person = defaultdict(list)
    for row in records:
        if row["kind"] == "claim" and row["subject"]["kind"] == "person":
            claims_by_person[row["subject"]["id"]].append(row)
    start = utc(quotas["exercise_clock_start"])
    checkpoints, errors = [], []
    for target in quotas["checkpoint_oracle_targets"]:
        cutoff = start + timedelta(hours=target["hour"])
        observed = Counter()
        for group in groups:
            visible = [c for pid in group["person_ids"] for c in claims_by_person[pid]
                       if utc(c["available_at"]) <= cutoff
                       and utc(catalog[c["source_id"]]["available_at"]) <= cutoff
                       and utc(catalog[pid]["available_at"]) <= cutoff]
            observed[summarize(visible)] += 1
        counts = {key: observed[key] for key in SUMMARIES}
        expected = {key: target[key] for key in SUMMARIES if key != "NOT_YET_REPORTED"}
        expected["NOT_YET_REPORTED"] = len(groups) - target["individuals"]
        checkpoints.append({"hour": target["hour"], "observed": counts, "expected": expected})
        for key in SUMMARIES:
            if counts[key] != expected[key]:
                errors.append(f"T+{target['hour']} {key}: observed {counts[key]}, expected {expected[key]}")
    return checkpoints, errors


def rumor_conflicts(records, groups):
    """Check the fixture's explicit temporal conflict rule; never judge truth."""
    by_person = defaultdict(list)
    for row in records:
        if row["kind"] == "claim" and row["subject"]["kind"] == "person" and row["assertion"]["type"] in STATUSES:
            by_person[row["subject"]["id"]].append(row)
    errors = []
    for group in groups:
        claims = [c for pid in group["person_ids"] for c in by_person[pid]]
        for rumor in [c for c in claims if c["assertion"]["type"] == "DECEASED"]:
            competing = [c for c in claims if c["assertion"]["type"] != "DECEASED"
                         and utc(c["available_at"]) <= utc(rumor["available_at"])
                         and (c["reported_at"]["value"] is None
                              or rumor["reported_at"]["value"] is None
                              or utc(c["reported_at"]["value"]) == utc(rumor["reported_at"]["value"]))]
            if not competing:
                errors.append(rumor["id"] + " has no available equal-time or unknown-time opposing status")
    return sorted(errors)

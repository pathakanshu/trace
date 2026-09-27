"""Pure map presentation: current person reports do not relocate a person."""
sv import from ...services.trace { PersonView, LocationView, ClaimView }

cl def:pub linked_people(place: LocationView, people: list[PersonView]) -> list[PersonView] {
    ids = [e.person_id for e in place.evidence if e.person_id];
    return [p for p in people if p.id in ids];
}

# One urgent label per place; identity candidates remain separate people.
cl def:pub pin_status(people: list[PersonView]) -> str {
    if any([p.latest_status == "MISSING" for p in people]) { return "MISSING"; }
    if any([p.has_conflict or p.latest_status in ["INJURED", "DECEASED"] for p in people]) { return "REVIEW"; }
    if any([p.latest_status == "FOUND_SAFE" for p in people]) { return "FOUND_SAFE"; }
    return "UNKNOWN";
}

cl def:pub pin_label(status: str) -> str {
    if status == "MISSING" { return "Missing"; }
    if status == "REVIEW" { return "Needs review"; }
    if status == "FOUND_SAFE" { return "Reported safe"; }
    return "No current status";
}

cl def:pub pin_dot(status: str) -> str {
    if status == "MISSING" { return "bg-status-missing"; }
    if status == "REVIEW" { return "bg-status-warning"; }
    if status == "FOUND_SAFE" { return "bg-status-safe"; }
    return "bg-status-neutral";
}

# Mirror the existing PersonView summary's time selection only for citations.
# Never derive a different person status or treat old reports as new conflicts.
cl def:pub current_reports(person: PersonView) -> list[ClaimView] {
    claims = [c for c in person.claims if c.claim_type in ["MISSING", "FOUND_SAFE", "INJURED", "DECEASED"]];
    if not claims { return []; }
    latest = claims[-1];
    if person.has_conflict {
        return [c for c in claims if not c.timestamp or not latest.timestamp or c.timestamp == latest.timestamp];
    }
    return [latest];
}

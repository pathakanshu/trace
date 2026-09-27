"""Read-only, cited person history. No model, matching, alert creation or writes.

The requested list response carries total_entries on every row (empty means 0).
Return the latest 50 entries in source-reported chronology. Linked alerts/runs
retain the claim's reported/ingested times and their own recorded_at separately.
"""
import json;
import from datetime { datetime, timezone }
import from graph.nodes { Incident, Person, Claim, Alert, InvestigationRun }
import from graph.edges { Involves, About, Asserts, HasSubscription, Receives, HasInvestigation }

obj TimelineEntry {
    has id: str, kind: str, person_id: str,
        claim_id: str = "", source_name: str = "", source_ids: list[str] = [],
        claim_type: str = "", reported_at: str = "", ingested_at: str = "",
        source_reference: str = "", recorded_at: str = "", text: str = "",
        status: str = "", mode: str = "", subscriber_names: list[str] = [],
        status_changed: bool = False, previous_claim_id: str = "",
        previous_claim_type: str = "", total_entries: int = 0;
}

def _time_key(value: str) -> tuple {
    if not value { return (1, ""); }
    try {
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"));
        if parsed.tzinfo is not None { parsed = parsed.astimezone(timezone.utc); }
        # Offset-bearing times compare in UTC; naive source times keep their
        # stated clock time. Never change or invent the displayed source value.
        return (0, parsed.strftime("%Y-%m-%dT%H:%M:%S.%f"));
    } except ValueError { return (1, value); }
}

def _order(row: TimelineEntry) -> tuple {
    ranks = {"claim": 0, "alert": 1, "investigation": 2};
    return (_time_key(row.reported_at), _time_key(row.ingested_at),
        row.source_name, row.source_reference, ranks.get(row.kind, 3),
        _time_key(row.recorded_at), row.claim_type, row.id);
}

def _entry(kind: str, record_id: str, person_id: str, claim: Claim | None) -> TimelineEntry {
    row = TimelineEntry(id=record_id, kind=kind, person_id=person_id);
    if claim is not None {
        sources = sorted([s for s in [claim <-:Asserts:<-]], key=lambda (s: any) -> str { return s.name; });
        row.claim_id = jid(claim);
        row.source_name = "; ".join([s.name for s in sources]);
        row.source_ids = [jid(s) for s in sources];
        row.claim_type = claim.claim_type;
        row.reported_at = claim.timestamp;
        row.ingested_at = claim.ingested_at;
        row.source_reference = claim.source_reference;
    }
    return row;
}

def _claim_entries(person: Person, incident_id: str) -> tuple {
    claims: dict[str, Claim] = {};
    entries: list[TimelineEntry] = [];
    for claim in [person <-:About:<-] {
        if claim.incident_id and claim.incident_id != incident_id { continue; }
        claims[jid(claim)] = claim;
    }
    for claim in claims.values() {
        row = _entry("claim", jid(claim), jid(person), claim);
        row.text = claim.value;
        row.status = claim.claim_type;
        entries.append(row);
    }
    entries.sort(key=_order);
    previous_id = "";
    previous_type = "";
    for row in entries {
        if previous_id {
            row.previous_claim_id = previous_id;
            row.previous_claim_type = previous_type;
            row.status_changed = row.claim_type != previous_type;
        }
        previous_id = row.claim_id;
        previous_type = row.claim_type;
    }
    return (claims, entries);
}

def _alert_entries(person: Person, claims: dict[str, Claim]) -> list[TimelineEntry] {
    found: dict[str, TimelineEntry] = {};
    for subscription in [person ->:HasSubscription:->] {
        for alert in [subscription ->:Receives:->] {
            # Exclude another person's/incident's claim. A legacy alert with no
            # claim ID remains visible through its subscription, without a citation.
            if alert.claim_id and alert.claim_id not in claims { continue; }
            key = jid(alert);
            if key not in found {
                row = _entry("alert", key, jid(person), claims.get(alert.claim_id));
                row.recorded_at = alert.created_at;
                row.text = alert.message;
                row.status = alert.severity;
                found[key] = row;
            }
            row = found[key];
            if subscription.subscriber_name not in row.subscriber_names {
                row.subscriber_names.append(subscription.subscriber_name);
            }
        }
    }
    return list(found.values());
}

def _run_entries(incident: Incident, person: Person, claims: dict[str, Claim]) -> list[TimelineEntry] {
    entries: list[TimelineEntry] = [];
    for run in [incident ->:HasInvestigation:->] {
        if run.person_id != jid(person) { continue; }
        result: dict = {};
        try {
            decoded = json.loads(run.result_json);
            if isinstance(decoded, dict) { result = decoded; }
        } except (ValueError, TypeError) { result = {}; }
        claim: Claim | None = None;
        citations = result.get("citations", []);
        if isinstance(citations, list) and citations and isinstance(citations[0], dict) {
            claim = claims.get(str(citations[0].get("claim_id", "")));
        }
        row = _entry("investigation", jid(run), jid(person), claim);
        row.status = str(result.get("status") or "");
        row.mode = run.mode or str(result.get("mode") or "");
        row.recorded_at = str(result.get("run_at") or run.created_at);
        row.text = str(result.get("message") or "Saved investigation details are unavailable.");
        entries.append(row);
    }
    return entries;
}

def:pub person_timeline(incident_id: str, person_id: str) -> list[TimelineEntry] {
    # Field filter forces real-edge traversal for the unindexed corpus incident.
    incidents = [i for i in [root -->[?:Incident, name != ""]] if jid(i) == incident_id];
    if not incidents { return []; }
    incident = incidents[0];
    people = [p for p in [incident ->:Involves:->] if jid(p) == person_id];
    if not people { return []; }
    person = people[0];
    pair = _claim_entries(person, incident_id);
    claims: dict[str, Claim] = pair[0];
    entries: list[TimelineEntry] = pair[1];
    entries += _alert_entries(person, claims);
    entries += _run_entries(incident, person, claims);
    entries.sort(key=_order);
    total = len(entries);
    visible = entries[-50:];
    for row in visible { row.total_entries = total; }
    return visible;
}

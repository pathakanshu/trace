"""Trace server endpoints - what the browser UI calls.

JAC 101: f"def:pub" makes a function a public HTTP endpoint
(POST /function/<name>). The UI calls these like normal async functions.
No login is needed for the starter.

The UI never sees raw nodes. f"get_dashboard()" walks the graph and packs
everything into small f"obj" "view" types below.
"""

import math;
import json;
import from features.media.media_upload { UploadRecord, list_incident_media }

import from graph.nodes {
    Incident, Person, Claim, Source, Media, Location,
    VerificationSignal, Subscription, Alert, ActivityEntry, Organization,
    InvestigationRun
}
import from graph.edges {
    Involves, Contains, Asserts, About, SupportedBy, Depicts,
    LocatedAt, HasSignal, HasSubscription, Receives, HasOrganization, Publishes,
    HasInvestigation, ReportedAt, HasSource
}
import from walkers.ingest { IngestWalker }
import from walkers.resolve { ResolveWalker, DuplicateCandidate }
import from walkers.watch { WatchWalker, STATUS_CLAIMS }
import from demo.seed { seed_demo, INCIDENT_NAME, PERSON_NAME, HOSPITAL_UPDATE }
import from features.graph.services { GraphSnapshot, build_graph_snapshot }
import from demo.corpus {
    CORPUS_INCIDENT_NAME, CORPUS_SCAN_CACHE, unmapped_counts, read_kind
}

# The corpus has 1,150 people; the browser gets a page of them plus counts.
glob CORPUS_PEOPLE_LIMIT: int = 100;
glob CORPUS_GRAPH_NODES: int = 400;

# ---------- View objects sent to the UI ----------

obj ClaimView {
    has id: str, claim_type: str, value: str, timestamp: str, notes: str,
        source_name: str, source_type: str, supporting_media: list[str] = [],
        source_id: str = "", organization_id: str = "", ingested_at: str = "",
        original_content: str = "", source_reference: str = "", extraction_method: str = "";
}

obj SubscriptionView {
    has subscriber_name: str, subscriber_contact: str, alert_count: int = 0;
}

obj PersonView {
    has id: str, name: str, age: int, notes: str,
        claims: list[ClaimView] = [],
        subscriptions: list[SubscriptionView] = [],
        latest_status: str = "UNKNOWN",
        has_conflict: bool = False, status_summary: str = "";
}

obj SignalView {
    has signal_type: str, value: str, confidence: str, explanation: str;
}

obj MediaView {
    has id: str, media_type: str, url: str, captured_at: str, description: str,
        earliest_known_copy: bool, location_name: str,
        depicts: list[str] = [], signals: list[SignalView] = [];
}

obj LocationEvidenceView {
    has claim_id: str, person_name: str, source_name: str, claim_type: str,
        summary: str, reported_at: str, source_reference: str, person_id: str = "";
}

obj LocationView {
    has name: str, latitude: float, longitude: float,
        id: str = "", media_ids: list[str] = [], evidence: list[LocationEvidenceView] = [],
        basis: str = "Reported media location; not independently verified";
}

obj OrganizationView {
    has id: str, name: str, organization_type: str, is_demo: bool = True,
        # Sources this organization published in the selected incident.
        report_count: int = 0;
}

# kind is "demo" (the Maya walkthrough) or "corpus" (the generated exercise).
obj IncidentOption {
    has id: str, name: str, kind: str, record_count: int = 0;
}

# Reports per place, split by the status they assert.
obj PlaceCount {
    has location_id: str, name: str, latitude: float, longitude: float,
        report_count: int, missing: int = 0, safe: int = 0, other: int = 0;
}

obj AlertView {
    has message: str, created_at: str, severity: str, subscriber_name: str,
        id: str = "", claim_id: str = "";
}

obj ActivityView {
    has walker_name: str, message: str, created_at: str;
}

obj InvestigationCitationView {
    has claim_id: str, source_name: str;
}

# One row per persisted InvestigationRun. Index 0 of citations is always the
# investigated report itself; later entries are sources Jac retrieved to compare.
obj InvestigationView {
    has id: str, claim_id: str, person_id: str, status: str, mode: str, model: str,
        run_at: str, message: str, trace: list[str] = [],
        citations: list[InvestigationCitationView] = [],
        usage_source: str = "", total_tokens: int = 0;
}

obj DashboardSnapshot {
    has seeded: bool = False,
        incident_id: str = "", organizations: list[OrganizationView] = [],
        incident_name: str = "",
        incident_description: str = "",
        incident_region: str = "",
        incident_start: str = "",
        people: list[PersonView] = [],
        media: list[MediaView] = [],
        locations: list[LocationView] = [],
        alerts: list[AlertView] = [],
        activity: list[ActivityView] = [],
        duplicates: list[DuplicateCandidate] = [],
        hospital_update_added: bool = False,
        graph: GraphSnapshot = GraphSnapshot(),
        media_records: list[UploadRecord] = [],
        investigations: list[InvestigationView] = [],
        is_corpus: bool = False,
        totals: dict[str, int] = {},
        not_imported: dict[str, int] = {},
        status_counts: dict[str, int] = {},
        # `people` holds at most CORPUS_PEOPLE_LIMIT records for the corpus.
        people_total: int = 0,
        place_counts: list[PlaceCount] = [],
        located_reports: int = 0,
        unlocated_reports: int = 0;
}

# ---------- Actions (the demo buttons) ----------

# Reset only the demo incident; preserve unrelated and shared data.
def:pub reset_demo() -> bool {
    seed_demo();
    return True;
}

# Add the Central Hospital FOUND_SAFE claim, then let WatchWalker react.
def:pub add_hospital_update() -> int {
    if not _incident() {
        seed_demo();
    }
    incident = _incident();
    if not incident { raise ValueError("Demo incident is unavailable."); }
    people = [p for p in [incident ->:Involves:->] if p.name == PERSON_NAME];
    if len(people) != 1 { raise ValueError("Select the person explicitly in Organizations."); }
    root spawn IngestWalker(
        incident_name=INCIDENT_NAME, selected_person_id=jid(people[0]),
        person_name=people[0].name, person_age=people[0].age,
        source_name=HOSPITAL_UPDATE["source_name"], source_type=HOSPITAL_UPDATE["source_type"],
        claim_type=HOSPITAL_UPDATE["claim_type"], claim_value=HOSPITAL_UPDATE["claim_value"],
        timestamp=HOSPITAL_UPDATE["timestamp"], notes=HOSPITAL_UPDATE["notes"],
        original_content=HOSPITAL_UPDATE["notes"], source_reference="HOSPITAL-DEMO-001",
        extraction_method="seeded_fixture"
    );
    watcher = root spawn WatchWalker(incident_id=jid(incident));
    return watcher.alerts_created;
}

# Run WatchWalker by hand (safe to repeat: already-seen claims are skipped).
def:pub run_watch() -> int {
    incident = _incident();
    if not incident { return 0; }
    watcher = root spawn WatchWalker(incident_id=jid(incident));
    return watcher.alerts_created;
}

# Run ResolveWalker: returns potential duplicates. Nothing is merged.
def:pub run_resolve() -> list[DuplicateCandidate] {
    incident = _incident();
    if not incident { return []; }
    resolver = incident spawn ResolveWalker();
    return resolver.candidates;
}

# ---------- Reading the graph for the UI ----------

# incident_id "" (or the demo's id) returns the Maya demo exactly as before.
def:pub get_dashboard(incident_id: str = "") -> DashboardSnapshot {
    if incident_id {
        chosen = _incident_by_id(incident_id);
        if chosen is not None and chosen.name == CORPUS_INCIDENT_NAME {
            return _corpus_snapshot(chosen);
        }
    }
    incident = _incident();
    if not incident {
        seed_demo();   # first run: build the demo automatically
        incident = _incident();
    }
    snap = DashboardSnapshot(seeded=True);
    if not incident {
        return snap;
    }
    snap.incident_id = jid(incident);
    for org in [incident ->:HasOrganization:->] {
        snap.organizations.append(OrganizationView(id=jid(org), name=org.name,
            organization_type=org.organization_type, is_demo=org.is_demo,
            report_count=len([org ->:Publishes:->])));
    }
    snap.media_records = list_incident_media(incident.name);
    snap.incident_name = incident.name;
    snap.incident_description = incident.description;
    snap.incident_region = incident.region;
    snap.incident_start = incident.start_time;

    for person in [incident ->:Involves:->] {
        view = _person_view(person, jid(incident));
        snap.people.append(view);
        for c in view.claims {
            if c.source_name == HOSPITAL_UPDATE["source_name"] {
                snap.hospital_update_added = True;
            }
        }
        for sub in [person ->:HasSubscription:->] {
            for a in [sub ->:Receives:->] {
                if a.claim_id and a.claim_id not in [c.id for c in view.claims] { continue; }
                snap.alerts.append(AlertView(
                    message=a.message, created_at=a.created_at,
                    severity=a.severity, subscriber_name=sub.subscriber_name, id=jid(a), claim_id=a.claim_id
                ));
            }
        }
    }

    places: dict[str, LocationView] = {};
    for m in [incident ->:Contains:->] {
        snap.media.append(_media_view(m));
        for loc in [m ->:LocatedAt:->] {
            # Legacy Location defaults are 0,0, representing unknown in this demo.
            if not math.isfinite(loc.latitude) or not math.isfinite(loc.longitude) { continue; }
            if abs(loc.latitude) > 90 or abs(loc.longitude) > 180 { continue; }
            if loc.latitude == 0 and loc.longitude == 0 { continue; }
            key = jid(loc);
            if key not in places {
                places[key] = LocationView(id=key, name=loc.name,
                    latitude=loc.latitude, longitude=loc.longitude);
            }
            location_view = places[key];
            location_view.media_ids.append(jid(m));
            existing = [e.claim_id for e in location_view.evidence];
            for claim in [m <-:SupportedBy:<-] {
                if claim.incident_id and claim.incident_id != jid(incident) { continue; }
                if jid(claim) in existing { continue; }
                sources = [claim <-:Asserts:<-];
                people = [claim ->:About:->];
                location_view.evidence.append(LocationEvidenceView(
                    claim_id=jid(claim), person_name=people[0].name if people else "Unknown",
                    source_name=sources[0].name if sources else "Unknown",
                    claim_type=claim.claim_type, summary=claim.value,
                    reported_at=claim.timestamp, source_reference=claim.source_reference,
                    person_id=jid(people[0]) if people else ""));
                existing.append(jid(claim));
            }
        }
    }
    snap.locations = list(places.values());

    for entry in [root -->[?:ActivityEntry]] {
        if entry.incident_id == jid(incident) {
            snap.activity.append(ActivityView(
                walker_name=entry.walker_name, message=entry.message, created_at=entry.created_at
            ));
        }
    }
    snap.activity.reverse();   # newest first
    snap.alerts.reverse();

    snap.duplicates = (incident spawn ResolveWalker(quiet=True)).candidates;
    snap.graph = build_graph_snapshot(incident, snap.duplicates);
    _fill_counts(snap, incident);
    for run in [incident ->:HasInvestigation:->] {
        inv_view = _investigation_view(run);
        if inv_view is not None {
            snap.investigations.append(inv_view);
        }
    }
    return snap;
}

# The incidents a viewer can switch between. Seeds the demo on first use.
def:pub list_incidents() -> list[IncidentOption] {
    if not _incident() { seed_demo(); }
    options: list[IncidentOption] = [];
    # The field filter makes Jac walk real edges; the corpus is not indexed.
    for incident in [root -->[?:Incident, name != ""]] {
        kind = "demo" if incident.name == INCIDENT_NAME else (
            "corpus" if incident.name == CORPUS_INCIDENT_NAME else "");
        if not kind { continue; }
        options.append(IncidentOption(id=jid(incident), name=incident.name, kind=kind,
            record_count=sum(_scan(incident).totals.values())));
    }
    options.sort(key=lambda (o: IncidentOption) -> int { return 0 if o.kind == "demo" else 1; });
    return options;
}

# Name search inside one incident, so the corpus People list can reach any of
# its 1,150 records without sending them all. Empty query = first `limit`.
def:pub search_people(incident_id: str, query: str, limit: int = 100) -> list[PersonView] {
    incident = _incident_by_id(incident_id) if incident_id else _incident();
    if incident is None { return []; }
    needle = query.strip().lower();
    limit = max(1, min(limit, 500));
    found: list[PersonView] = [];
    for person in [incident ->:Involves:->] {
        marker = "Also reported as:";
        variants = person.notes.split(marker)[1] if marker in person.notes else "";
        if needle and needle not in person.name.lower() and needle not in variants.lower()
            and needle != person.external_id.lower() {
            continue;
        }
        found.append(_person_view(person, jid(incident)));
        if len(found) >= limit { break; }
    }
    return found;
}

# ---------- Private helpers (underscore = not an endpoint) ----------

def _incident_by_id(incident_id: str) -> Incident | None {
    # Field filter: see demo/corpus.jac on why the corpus is not in the index.
    found = [i for i in [root -->[?:Incident, name != ""]] if jid(i) == incident_id];
    return found[0] if found else None;
}

# Same display rule as _person_view, on raw Claim nodes, so counting 1,150
# people does not build a ClaimView for every report.
def _status_of(claims: list[Claim]) -> str {
    ordered = sorted([c for c in claims if c.claim_type in STATUS_CLAIMS],
        key=lambda (c: Claim) -> str { return c.timestamp; });
    if not ordered { return "UNKNOWN"; }
    latest = ordered[-1];
    for c in ordered {
        if c.claim_type != latest.claim_type
            and (not c.timestamp or not latest.timestamp or c.timestamp == latest.timestamp) {
            return "UNKNOWN";
        }
    }
    return str(latest.claim_type);
}

obj IncidentScan {
    has people: list[Person] = [], organizations: list[Organization] = [],
        media: list[Media] = [], status_counts: dict[str, int] = {},
        places: list[PlaceCount] = [], located: int = 0, claim_count: int = 0,
        totals: dict[str, int] = {};
}

# One linear pass over an incident: totals, status per person, and reports per
# place. Place comes from a claim's ReportedAt location, else from the location
# of its supporting media (how the demo records place).
def _scan(incident: Incident) -> IncidentScan {
    inc_id = jid(incident);
    # The corpus only changes on import (which clears this cache), and a full
    # count is thousands of traversals on the persisted server, so reuse it.
    hit = CORPUS_SCAN_CACHE.get(inc_id) if incident.name == CORPUS_INCIDENT_NAME else None;
    if isinstance(hit, IncidentScan) {
        cached: IncidentScan = hit;
        return IncidentScan(people=[incident ->:Involves:->],
            organizations=[incident ->:HasOrganization:->], media=[incident ->:Contains:->],
            status_counts=cached.status_counts, places=cached.places, located=cached.located,
            claim_count=cached.claim_count, totals=cached.totals);
    }
    claims: dict = {};
    sources: dict = {};
    status_counts: dict[str, int] = {};
    subscriptions = 0;
    people = [incident ->:Involves:->];
    for person in people {
        mine = [c for c in [person <-:About:<-] if not c.incident_id or c.incident_id == inc_id];
        status = _status_of(mine);
        status_counts[status] = status_counts.get(status, 0) + 1;
        for c in mine { claims[jid(c)] = c; }
        subscriptions += len([person ->:HasSubscription:->]);
    }
    organizations = [incident ->:HasOrganization:->];
    listed: list = [incident ->:HasSource:->];
    for org in organizations { listed += [org ->:Publishes:->]; }
    for source in listed {
        sources[jid(source)] = source;
        for c in [source ->:Asserts:->] {
            if not c.incident_id or c.incident_id == inc_id { claims[jid(c)] = c; }
        }
    }
    places: dict = {};
    located = 0;
    for key in claims {
        claim = claims[key];
        if key not in sources {
            for source in [claim <-:Asserts:<-] { sources[jid(source)] = source; }
        }
        spots = [claim ->:ReportedAt:->];
        if not spots {
            for m in [claim ->:SupportedBy:->] { spots += [m ->:LocatedAt:->]; }
        }
        counted = False;
        for loc in spots {
            if loc.latitude == 0 and loc.longitude == 0 { continue; }
            place = places.get(jid(loc));
            if place is None {
                place = PlaceCount(location_id=jid(loc), name=loc.name,
                    latitude=loc.latitude, longitude=loc.longitude, report_count=0);
                places[jid(loc)] = place;
            }
            place.report_count += 1;
            if claim.claim_type == "MISSING" { place.missing += 1; }
            elif claim.claim_type == "FOUND_SAFE" { place.safe += 1; }
            else { place.other += 1; }
            counted = True;
        }
        if counted { located += 1; }
    }
    location_ids: dict = {};
    for key in places { location_ids[key] = True; }
    media = [incident ->:Contains:->];
    for m in media {
        for loc in [m ->:LocatedAt:->] { location_ids[jid(loc)] = True; }
    }
    result = IncidentScan(
        people=people, organizations=organizations, media=media,
        status_counts=status_counts, places=list(places.values()),
        located=located, claim_count=len(claims),
        totals={
            "people": len(people), "claims": len(claims), "sources": len(sources),
            "organizations": len(organizations), "media": len(media),
            "locations": len(location_ids), "subscriptions": subscriptions
        }
    );
    if incident.name == CORPUS_INCIDENT_NAME {
        CORPUS_SCAN_CACHE[inc_id] = IncidentScan(status_counts=result.status_counts,
            places=result.places, located=result.located, claim_count=result.claim_count,
            totals=result.totals);
    }
    return result;
}

def _fill_counts(snap: DashboardSnapshot, incident: Incident) -> IncidentScan {
    scan = _scan(incident);
    snap.totals = scan.totals;
    snap.status_counts = scan.status_counts;
    snap.people_total = len(scan.people);
    snap.place_counts = scan.places;
    snap.located_reports = scan.located;
    snap.unlocated_reports = scan.claim_count - scan.located;
    return scan;
}

# The generated corpus: counts over everything, detail for one page of people.
# Identity duplicate candidates are skipped here (pairwise over 1,150 people),
# so `duplicates` is empty on purpose.
def _corpus_snapshot(incident: Incident) -> DashboardSnapshot {
    snap = DashboardSnapshot(seeded=True, is_corpus=True);
    snap.incident_id = jid(incident);
    snap.incident_name = incident.name;
    snap.incident_description = incident.description;
    snap.incident_region = incident.region;
    snap.incident_start = incident.start_time;
    scan = _fill_counts(snap, incident);
    for org in scan.organizations {
        snap.organizations.append(OrganizationView(id=jid(org), name=org.name,
            organization_type=org.organization_type, is_demo=org.is_demo,
            report_count=len([org ->:Publishes:->])));
    }
    for person in scan.people[:CORPUS_PEOPLE_LIMIT] {
        view = _person_view(person, jid(incident));
        snap.people.append(view);
        for sub in [person ->:HasSubscription:->] {
            for a in [sub ->:Receives:->] {
                snap.alerts.append(AlertView(message=a.message, created_at=a.created_at,
                    severity=a.severity, subscriber_name=sub.subscriber_name,
                    id=jid(a), claim_id=a.claim_id));
            }
        }
    }
    for m in scan.media { snap.media.append(_media_view(m)); }
    snap.media_records = list_incident_media(incident.name);
    for entry in [root -->[?:ActivityEntry]] {
        if entry.incident_id == jid(incident) {
            snap.activity.append(ActivityView(walker_name=entry.walker_name,
                message=entry.message, created_at=entry.created_at));
        }
    }
    snap.activity.reverse();
    snap.not_imported = unmapped_counts();
    missing_subs = len(read_kind("subscription")) - snap.totals["subscriptions"];
    if missing_subs > 0 { snap.not_imported["subscription (subject is not a person)"] = missing_subs; }
    kinds = {
        "Incident": 1, "Person": snap.totals["people"], "Claim": snap.totals["claims"],
        "Source": snap.totals["sources"], "Organization": snap.totals["organizations"],
        "Media": snap.totals["media"], "Location": snap.totals["locations"],
        "Subscription": snap.totals["subscriptions"]
    };
    snap.graph = build_graph_snapshot(incident, [], CORPUS_GRAPH_NODES, kinds);
    return snap;
}

def _incident() -> Incident | None {
    found = [root -->[?:Incident, name == INCIDENT_NAME]];
    return found[0] if found else None;
}

def _person_view(person: Person, incident_id: str = "") -> PersonView {
    claims: list[ClaimView] = [];
    for c in [person <-:About:<-] {
        if incident_id and c.incident_id and c.incident_id != incident_id { continue; }
        sources = [c <-:Asserts:<-];
        organizations = [sources[0] <-:Publishes:<-] if sources else [];
        claims.append(ClaimView(
            id=jid(c), claim_type=c.claim_type, value=c.value,
            timestamp=c.timestamp, notes=c.notes,
            source_name=sources[0].name if sources else "Unknown",
            source_type=sources[0].source_type if sources else "",
            supporting_media=[m.description for m in [c ->:SupportedBy:->]],
            source_id=jid(sources[0]) if sources else "",
            organization_id=jid(organizations[0]) if organizations else "",
            ingested_at=c.ingested_at, original_content=c.original_content,
            source_reference=c.source_reference, extraction_method=c.extraction_method
        ));
    }
    claims.sort(key=lambda (x: ClaimView) -> str { return x.timestamp; });

    status_claims = [c for c in claims if c.claim_type in STATUS_CLAIMS];
    latest = status_claims[-1] if status_claims else None;
    # Differing claims at the same latest time, or an undated differing claim,
    # need review. Strictly earlier reports remain history, not a contradiction.
    unresolved = [c for c in status_claims if latest and c.claim_type != latest.claim_type
        and (not c.timestamp or not latest.timestamp or c.timestamp == latest.timestamp)];
    summary = "No status reports";
    if latest is not None {
        summary = "Dated or undated reports disagree; review sources" if unresolved else (
            "Latest dated source report; earlier reports retained" if latest.timestamp else "Source report; reported time unknown");
    }

    subs: list[SubscriptionView] = [];
    for s in [person ->:HasSubscription:->] {
        subs.append(SubscriptionView(
            subscriber_name=s.subscriber_name,
            subscriber_contact=s.subscriber_contact,
            alert_count=len([a for a in [s ->:Receives:->] if not a.claim_id or a.claim_id in [c.id for c in claims]])
        ));
    }

    current_status = "UNKNOWN";
    if status_claims and not unresolved { current_status = status_claims[-1].claim_type; }
    return PersonView(
        id=jid(person), name=person.name, age=person.age, notes=person.notes,
        claims=claims, subscriptions=subs,
        latest_status=current_status,
        has_conflict=bool(unresolved), status_summary=summary
    );
}

# A stored run's result_json carries its own status, model and citations, so
# the Graph and People views read the same saved answer instead of recomputing it.
def _investigation_view(run: InvestigationRun) -> InvestigationView | None {
    try {
        result = json.loads(run.result_json);
    } except Exception {
        return None;
    }
    citations = [InvestigationCitationView(claim_id=c.get("claim_id", ""), source_name=c.get("source_name", ""))
        for c in result.get("citations", [])];
    return InvestigationView(
        id=jid(run), claim_id=citations[0].claim_id if citations else "",
        person_id=run.person_id, status=result.get("status", ""), mode=run.mode,
        model=result.get("model", ""), run_at=result.get("run_at", run.created_at),
        message=result.get("message", ""), trace=result.get("trace", []),
        citations=citations, usage_source=result.get("usage_source", ""),
        total_tokens=int(result.get("usage", {}).get("total_tokens", 0))
    );
}

def _media_view(m: Media) -> MediaView {
    locs = [m ->:LocatedAt:->];
    return MediaView(
        id=jid(m), media_type=m.media_type, url=m.url,
        captured_at=m.captured_at, description=m.description,
        earliest_known_copy=m.earliest_known_copy,
        location_name=locs[0].name if locs else "Unknown",
        depicts=[p.name for p in [m ->:Depicts:->]],
        signals=[
            SignalView(signal_type=s.signal_type, value=s.value,
                       confidence=s.confidence, explanation=s.explanation)
            for s in [m ->:HasSignal:->]
        ]
    );
}

"""Trace server endpoints - what the browser UI calls.

JAC 101: f"def:pub" makes a function a public HTTP endpoint
(POST /function/<name>). The UI calls these like normal async functions.
No login is needed for the starter.

The UI never sees raw nodes. f"get_dashboard()" walks the graph and packs
everything into small f"obj" "view" types below.
"""

import math;

import from graph.nodes {
    Incident, Person, Claim, Source, Media, Location,
    VerificationSignal, Subscription, Alert, ActivityEntry, Organization
}
import from graph.edges {
    Involves, Contains, Asserts, About, SupportedBy, Depicts,
    LocatedAt, HasSignal, HasSubscription, Receives, HasOrganization, Publishes
}
import from walkers.ingest { IngestWalker }
import from walkers.resolve { ResolveWalker, DuplicateCandidate }
import from walkers.watch { WatchWalker, STATUS_CLAIMS }
import from demo.seed { seed_demo, INCIDENT_NAME, PERSON_NAME, HOSPITAL_UPDATE }

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
        summary: str, reported_at: str, source_reference: str;
}

obj LocationView {
    has name: str, latitude: float, longitude: float,
        id: str = "", media_ids: list[str] = [], evidence: list[LocationEvidenceView] = [],
        basis: str = "Reported media location; not independently verified";
}

obj OrganizationView {
    has id: str, name: str, organization_type: str, is_demo: bool = True;
}

obj AlertView {
    has message: str, created_at: str, severity: str, subscriber_name: str,
        id: str = "", claim_id: str = "";
}

obj ActivityView {
    has walker_name: str, message: str, created_at: str;
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
        hospital_update_added: bool = False;
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

def:pub get_dashboard() -> DashboardSnapshot {
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
            organization_type=org.organization_type, is_demo=org.is_demo));
    }
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
                    reported_at=claim.timestamp, source_reference=claim.source_reference));
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
    return snap;
}

# ---------- Private helpers (underscore = not an endpoint) ----------

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

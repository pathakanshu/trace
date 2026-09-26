"""Trace server endpoints - what the browser UI calls.

JAC 101: f"def:pub" makes a function a public HTTP endpoint
(POST /function/<name>). The UI calls these like normal async functions.
No login is needed for the starter.

The UI never sees raw nodes. f"get_dashboard()" walks the graph and packs
everything into small f"obj" "view" types below.
"""

import from graph.nodes {
    Incident, Person, Claim, Source, Media, Location,
    VerificationSignal, Subscription, Alert, ActivityEntry
}
import from graph.edges {
    Involves, Contains, Asserts, About, SupportedBy, Depicts,
    LocatedAt, HasSignal, HasSubscription, Receives
}
import from walkers.ingest { IngestWalker }
import from walkers.resolve { ResolveWalker, DuplicateCandidate }
import from walkers.watch { WatchWalker, STATUS_CLAIMS }
import from demo.seed { seed_demo, INCIDENT_NAME, PERSON_NAME, HOSPITAL_UPDATE }

# ---------- View objects sent to the UI ----------

obj ClaimView {
    has id: str, claim_type: str, value: str, timestamp: str, notes: str,
        source_name: str, source_type: str, supporting_media: list[str] = [];
}

obj SubscriptionView {
    has subscriber_name: str, subscriber_contact: str, alert_count: int = 0;
}

obj PersonView {
    has id: str, name: str, age: int, notes: str,
        claims: list[ClaimView] = [],
        subscriptions: list[SubscriptionView] = [],
        latest_status: str = "UNKNOWN",
        has_conflict: bool = False;
}

obj SignalView {
    has signal_type: str, value: str, confidence: str, explanation: str;
}

obj MediaView {
    has id: str, media_type: str, url: str, captured_at: str, description: str,
        earliest_known_copy: bool, location_name: str,
        depicts: list[str] = [], signals: list[SignalView] = [];
}

obj LocationView {
    has name: str, latitude: float, longitude: float;
}

obj AlertView {
    has message: str, created_at: str, severity: str, subscriber_name: str;
}

obj ActivityView {
    has walker_name: str, message: str, created_at: str;
}

obj DashboardSnapshot {
    has seeded: bool = False,
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

# Wipe the graph and rebuild the starting state.
def:pub reset_demo() -> bool {
    seed_demo();
    return True;
}

# Add the Central Hospital FOUND_SAFE claim, then let WatchWalker react.
def:pub add_hospital_update() -> int {
    if not _incident() {
        seed_demo();
    }
    root spawn IngestWalker(
        incident_name=INCIDENT_NAME,
        person_name=PERSON_NAME,
        source_name=HOSPITAL_UPDATE["source_name"],
        source_type=HOSPITAL_UPDATE["source_type"],
        claim_type=HOSPITAL_UPDATE["claim_type"],
        claim_value=HOSPITAL_UPDATE["claim_value"],
        timestamp=HOSPITAL_UPDATE["timestamp"],
        notes=HOSPITAL_UPDATE["notes"]
    );
    watcher = root spawn WatchWalker();
    return watcher.alerts_created;
}

# Run WatchWalker by hand (safe to repeat: already-seen claims are skipped).
def:pub run_watch() -> int {
    watcher = root spawn WatchWalker();
    return watcher.alerts_created;
}

# Run ResolveWalker: returns potential duplicates. Nothing is merged.
def:pub run_resolve() -> list[DuplicateCandidate] {
    resolver = root spawn ResolveWalker();
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
    snap.incident_name = incident.name;
    snap.incident_description = incident.description;
    snap.incident_region = incident.region;
    snap.incident_start = incident.start_time;

    for person in [incident ->:Involves:->] {
        view = _person_view(person);
        snap.people.append(view);
        for c in view.claims {
            if c.source_name == HOSPITAL_UPDATE["source_name"] {
                snap.hospital_update_added = True;
            }
        }
        for sub in [person ->:HasSubscription:->] {
            for a in [sub ->:Receives:->] {
                snap.alerts.append(AlertView(
                    message=a.message, created_at=a.created_at,
                    severity=a.severity, subscriber_name=sub.subscriber_name
                ));
            }
        }
    }

    seen_places: list[str] = [];
    for m in [incident ->:Contains:->] {
        mv = _media_view(m);
        snap.media.append(mv);
        for loc in [m ->:LocatedAt:->] {
            if loc.name not in seen_places {
                seen_places.append(loc.name);
                snap.locations.append(LocationView(
                    name=loc.name, latitude=loc.latitude, longitude=loc.longitude
                ));
            }
        }
    }

    for entry in [root -->[?:ActivityEntry]] {
        snap.activity.append(ActivityView(
            walker_name=entry.walker_name, message=entry.message, created_at=entry.created_at
        ));
    }
    snap.activity.reverse();   # newest first
    snap.alerts.reverse();

    snap.duplicates = (root spawn ResolveWalker(quiet=True)).candidates;
    return snap;
}

# ---------- Private helpers (underscore = not an endpoint) ----------

def _incident() -> Incident | None {
    found = [root -->[?:Incident, name == INCIDENT_NAME]];
    return found[0] if found else None;
}

def _person_view(person: Person) -> PersonView {
    claims: list[ClaimView] = [];
    for c in [person <-:About:<-] {
        sources = [c <-:Asserts:<-];
        claims.append(ClaimView(
            id=jid(c), claim_type=c.claim_type, value=c.value,
            timestamp=c.timestamp, notes=c.notes,
            source_name=sources[0].name if sources else "Unknown",
            source_type=sources[0].source_type if sources else "",
            supporting_media=[m.description for m in [c ->:SupportedBy:->]]
        ));
    }
    claims.sort(key=lambda (x: ClaimView) -> str { return x.timestamp; });

    status_claims = [c for c in claims if c.claim_type in STATUS_CLAIMS];
    distinct = [];
    for c in status_claims {
        if c.claim_type not in distinct {
            distinct.append(c.claim_type);
        }
    }

    subs: list[SubscriptionView] = [];
    for s in [person ->:HasSubscription:->] {
        subs.append(SubscriptionView(
            subscriber_name=s.subscriber_name,
            subscriber_contact=s.subscriber_contact,
            alert_count=len([s ->:Receives:->])
        ));
    }

    return PersonView(
        id=jid(person), name=person.name, age=person.age, notes=person.notes,
        claims=claims, subscriptions=subs,
        latest_status=status_claims[-1].claim_type if status_claims else "UNKNOWN",
        has_conflict=len(distinct) > 1
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

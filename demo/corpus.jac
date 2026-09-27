"""Import the generated Bhote Koshi exercise corpus as its own incident.

The corpus (demo/datasets/bhotekoshi-2016-exercise-v1/records) is a fictional
8,027-record workload used to show Trace at scale. It lives in a SEPARATE
incident so the Maya demo and its reset stay exactly as they were.

Records are written directly as graph nodes, not through IngestWalker or
WatchWalker: a bulk load of historical reports must not raise alerts or
identity proposals. Two passes: nodes first, then the edges between them.
Re-running the import matches on external_id and creates nothing new.
"""

import glob;
import json;
import os;
import from graph.nodes {
    Incident, Person, Claim, Source, Organization, Location, Media, Subscription
}
import from graph.edges {
    Involves, Contains, Asserts, About, SupportedBy, HasSubscription,
    HasOrganization, Publishes, ReportedAt, HasSource
}
import from graph.activity { now_iso }

glob CORPUS_INCIDENT_NAME: str = "Bhote Koshi exercise corpus (generated)";
glob CORPUS_DIR: str = "demo/datasets/bhotekoshi-2016-exercise-v1/records";
glob EXTRACTION_METHOD: str = "exercise_corpus_import";
# Counts per corpus incident id, filled by services/trace.jac; cleared on import.
glob CORPUS_SCAN_CACHE: dict = {};
# Kinds with a Trace rec type. Everything else is counted, never dropped silently.
glob MAPPED_KINDS: list[str] = [
    "incident", "organization", "source", "claim", "person", "location",
    "media", "subscription"
];

def read_kind(kind: str) -> list[dict] {
    rows: list[dict] = [];
    for path in sorted(glob.glob(os.path.join(CORPUS_DIR, kind, "*.jsonl"))) {
        with open(path) as handle {
            for line in handle {
                if line.strip() { rows.append(json.loads(line)); }
            }
        }
    }
    return rows;
}

def corpus_incident() -> Incident | None {
    found = [root -->[?:Incident, name == CORPUS_INCIDENT_NAME]];
    return found[0] if found else None;
}

# Jac's topology index re-encodes the whole index on every new edge, which
# makes a bulk import quadratic (minutes for this corpus, 0.4 s without it).
# The corpus is therefore written with the index off and stays out of it:
# traversals from unindexed nodes, or with a field filter, walk real edges.
# Look the corpus up with a field filter (as corpus_incident does), never with
# a bare [root -->[?:Incident]], which answers from the index.
def load_exercise_corpus() -> dict {
    previous = os.environ.get("JAC_TOPOLOGY_INDEX");
    os.environ["JAC_TOPOLOGY_INDEX"] = "0";
    CORPUS_SCAN_CACHE.clear();
    try {
        return _import_corpus();
    } finally {
        if previous is None { os.environ.pop("JAC_TOPOLOGY_INDEX", None); }
        else { os.environ["JAC_TOPOLOGY_INDEX"] = previous; }
    }
}

def _time(value: any) -> str {
    if isinstance(value, dict) { return str(value.get("value") or ""); }
    return "";
}

# Existing corpus nodes by external_id, found by walking the incident, so a
# second import only fills gaps instead of duplicating records.
def _existing(incident: Incident) -> dict {
    known: dict = {};
    for p in [incident ->:Involves:->] {
        known[p.external_id] = p;
        for s in [p ->:HasSubscription:->] { known[s.external_id] = s; }
    }
    for m in [incident ->:Contains:->] { known[m.external_id] = m; }
    for o in [incident ->:HasOrganization:->] {
        known[o.external_id] = o;
        for s in [o ->:Publishes:->] { _known_source(known, s); }
    }
    for s in [incident ->:HasSource:->] { _known_source(known, s); }
    return known;
}

def _known_source(known: dict, s: Source) -> None {
    known[s.external_id] = s;
    for c in [s ->:Asserts:->] {
        known[c.external_id] = c;
        for loc in [c ->:ReportedAt:->] { known[loc.external_id] = loc; }
    }
}

def _bump(counts: dict, kind: str) -> None {
    counts[kind] = counts.get(kind, 0) + 1;
}

# Record counts for corpus kinds that have no Trace rec type yet. Counting
# lines keeps this cheap enough for every dashboard read.
def unmapped_counts() -> dict[str, int] {
    counts: dict[str, int] = {};
    for path in sorted(glob.glob(os.path.join(CORPUS_DIR, "*"))) {
        kind = os.path.basename(path);
        if kind in MAPPED_KINDS { continue; }
        total = 0;
        for part in glob.glob(os.path.join(path, "*.jsonl")) {
            with open(part) as handle {
                total += len([line for line in handle if line.strip()]);
            }
        }
        counts[kind] = total;
    }
    return counts;
}

def _import_corpus() -> dict {
    incident = corpus_incident();
    if incident is None {
        meta = read_kind("incident");
        info: dict = meta[0] if meta else {};
        incident = Incident(name=CORPUS_INCIDENT_NAME,
            description=str(info.get("description", "")),
            start_time=_time(info.get("event_time")) or str((info.get("event_time") or {}).get("date") or ""),
            region="Sindhupalchok, Nepal (generated exercise)");
        root ++> incident;
    }
    known = _existing(incident);
    imported: dict = {};
    created: dict = {};
    ingested_at = now_iso();

    # ---------- pass 1: nodes ----------
    contributors: dict = {r["id"]: r for r in read_kind("contributor")};
    orgs: dict = {};
    for r in read_kind("organization") {
        rec = known.get(r["id"]);
        if rec is None {
            rec = Organization(name=r.get("name", ""), organization_type=r.get("organization_type") or "",
                is_demo=True, external_id=r["id"]);
            incident +>:HasOrganization():+> rec;
            _bump(created, "organization");
        }
        orgs[r["id"]] = rec;
        _bump(imported, "organization");
    }
    people: dict = {};
    for r in read_kind("person") {
        rec = known.get(r["id"]);
        if rec is None {
            name = r.get("display_name") or "";
            variants = [v for v in (r.get("name_variants") or []) if v != name];
            notes = r.get("description") or "";
            if variants { notes = notes + " Also reported as: " + ", ".join(variants) + "."; }
            age = r.get("reported_age");
            rec = Person(name=name, age=int(age) if isinstance(age, int) else 0,
                notes=notes, external_id=r["id"]);
            incident +>:Involves():+> rec;
            _bump(created, "person");
        }
        people[r["id"]] = rec;
        _bump(imported, "person");
    }
    locations: dict = {};
    for r in read_kind("location") {
        rec = known.get(r["id"]);
        if rec is None {
            coords: list = list((r.get("geometry") or {}).get("coordinates") or []);
            # Unknown coordinates stay 0,0, which the map already treats as unknown.
            rec = Location(name=r.get("name", ""),
                latitude=float(coords[1]) if len(coords) == 2 else 0.0,
                longitude=float(coords[0]) if len(coords) == 2 else 0.0,
                external_id=r["id"]);
            _bump(created, "location");
        }
        locations[r["id"]] = rec;
        _bump(imported, "location");
    }
    media: dict = {};
    for r in read_kind("media") {
        rec = known.get(r["id"]);
        if rec is None {
            caption = r.get("published_caption") or "";
            description = r.get("description") or "";
            if caption { description = description + " Published caption: " + caption; }
            # Asset bytes are not imported, so url stays empty rather than pointing
            # at a file this app does not serve.
            rec = Media(media_type=r.get("media_type") or "unknown", url="",
                captured_at=_time(r.get("reported_capture_time")), description=description,
                content_hash=r.get("sha256") or "", origin="exercise_corpus",
                external_id=r["id"]);
            incident +>:Contains():+> rec;
            _bump(created, "media");
        }
        media[r["id"]] = rec;
        _bump(imported, "media");
    }
    sources: dict = {};
    not_imported: dict = {};
    references: dict = {};
    for r in read_kind("source") {
        publisher = r.get("publisher") or {};
        rec = known.get(r["id"]);
        if rec is None {
            rec = Source(name=r.get("title") or r["id"], source_type=r.get("source_type") or "",
                external_id=r["id"]);
            if publisher.get("kind") == "organization" and publisher.get("id") in orgs {
                orgs[publisher["id"]] +>:Publishes():+> rec;
            } else {
                # Community contributors are people, not institutions, so their
                # reports hang off the incident instead of a made-up Organization.
                incident +>:HasSource():+> rec;
            }
            _bump(created, "source");
        }
        sources[r["id"]] = rec;
        references[r["id"]] = r.get("report_reference") or "";
        _bump(imported, "source");
    }

    # ---------- pass 2: claims and the edges that need both ends ----------
    unlinked_subjects: dict = {};
    incident_id = jid(incident);
    for r in read_kind("claim") {
        source = sources.get(r.get("source_id"));
        if source is None {
            _bump(not_imported, "claim (source not imported)");
            continue;
        }
        _bump(imported, "claim");
        if r["id"] in known { continue; }
        assertion = r.get("assertion") or {};
        provenance = r.get("provenance") or {};
        subject = r.get("subject") or {};
        text = assertion.get("text") or "";
        notes = "";
        if subject.get("kind") != "person" {
            notes = f"Subject: {subject.get('kind', 'unknown')} {subject.get('id', '')} (no Trace node type yet).";
        }
        claim = Claim(claim_type=str(assertion.get("type") or "UNKNOWN"), value=str(text),
            timestamp=_time(r.get("reported_at")), notes=notes,
            # Imported history, not a new arrival: WatchWalker must never alert on it.
            seen_by_watch=True, incident_id=incident_id, ingested_at=ingested_at,
            original_content=str(provenance.get("original_excerpt") or text),
            source_reference=str(references.get(r.get("source_id"), "")),
            extraction_method=EXTRACTION_METHOD, ingestion_key=r["id"],
            external_id=r["id"]);
        source +>:Asserts():+> claim;
        _bump(created, "claim");
        if subject.get("kind") == "person" and subject.get("id") in people {
            claim +>:About():+> people[subject["id"]];
        } else {
            _bump(unlinked_subjects, str(subject.get("kind") or "unknown"));
        }
        place = locations.get(r.get("location_id") or "");
        if place is not None { claim +>:ReportedAt():+> place; }
        for media_id in (r.get("supporting_media_ids") or []) {
            if media_id in media { claim +>:SupportedBy():+> media[media_id]; }
        }
    }

    for r in read_kind("subscription") {
        subject = r.get("subject") or {};
        person = people.get(subject.get("id")) if subject.get("kind") == "person" else None;
        if person is None {
            _bump(not_imported, f"subscription (subject is {subject.get('kind', 'unknown')})");
            continue;
        }
        _bump(imported, "subscription");
        if r["id"] in known { continue; }
        contributor = contributors.get(r.get("contributor_id") or "") or {};
        person +>:HasSubscription():+> Subscription(
            subscriber_name=str(contributor.get("display_name") or r.get("contributor_id") or ""),
            subscriber_contact="", external_id=r["id"]);
        _bump(created, "subscription");
    }

    # Kinds without a rec type yet: counted so the gap is visible.
    not_imported.update(unmapped_counts());
    return {
        "incident_id": incident_id, "imported": imported, "created": created,
        "not_imported": not_imported, "claims_without_person_subject": unlinked_subjects
    };
}

def:pub load_corpus() -> dict {
    return load_exercise_corpus();
}

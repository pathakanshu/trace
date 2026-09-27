"""Integration checks for Anshu's publish → persist → alert → reset flow."""
import from services.trace { reset_demo, get_dashboard }
import from features.organizations.services { publish_report, PublishResult }
import from walkers.ingest { IngestWalker }
import from walkers.watch { WatchWalker }
import from graph.nodes { Incident, Media, Location, VerificationSignal, ActivityEntry, Alert }
import from graph.edges { Involves, About, Contains, LocatedAt, HasSignal, HasSubscription, Receives }
import from demo.seed { INCIDENT_NAME }

def publish_example(reference: str = "TEST-HOSPITAL-001", status: str = "FOUND_SAFE",
    reported_at: str = "2026-09-21T09:15:00Z") -> PublishResult {
    snap = get_dashboard();
    org = [o for o in snap.organizations if o.organization_type == "HOSPITAL"][0];
    person = [p for p in snap.people if p.name == "Maya Gurung"][0];
    return publish_report(snap.incident_id, org.id, person.id, status,
        "Fictional structured report", reported_at, reference, "  Original supplied text\nwith a second line.  ");
}

test "publishing preserves provenance and identical retries" {
    reset_demo();
    first = publish_example();
    assert not first.duplicate and first.alerts_created == 1;
    again = publish_example();
    assert again.duplicate and again.claim_id == first.claim_id and again.alerts_created == 0;
    snap = get_dashboard();
    maya = [p for p in snap.people if p.name == "Maya Gurung"][0];
    assert len(maya.claims) == 2 and len(snap.alerts) == 1;
    claim = maya.claims[-1];
    assert claim.source_id and claim.organization_id and claim.ingested_at;
    assert claim.original_content == "  Original supplied text\nwith a second line.  ";
    assert claim.extraction_method == "structured_form";
    assert claim.timestamp == "2026-09-21T09:15:00+00:00";
    assert snap.alerts[0].claim_id == claim.id;
}

test "invalid and changed-reference submissions do not add records" {
    reset_demo();
    assert publish_example(status="TRUTH").error;
    assert publish_example(reported_at="not a date").error;
    assert publish_example(reference="   ").error;
    assert len(get_dashboard().people[0].claims) == 1;
    assert not publish_example().error;
    assert publish_example(status="INJURED").error;
    assert len(get_dashboard().people[0].claims) == 2;
}

test "chronology distinguishes updates historical reports and ambiguity" {
    reset_demo();
    publish_example();
    maya = get_dashboard().people[0];
    assert maya.latest_status == "FOUND_SAFE" and not maya.has_conflict;
    historical = publish_example(reference="OLD-001", status="INJURED", reported_at="2026-09-19T09:00:00Z");
    assert historical.alerts_created == 1;
    assert get_dashboard().people[0].latest_status == "FOUND_SAFE";
    ambiguous = publish_example(reference="SAME-TIME-001", status="MISSING");
    assert ambiguous.alerts_created == 1;
    maya = get_dashboard().people[0];
    assert maya.has_conflict and maya.latest_status == "UNKNOWN";
    reset_demo();
    publish_example(reported_at="");
    assert get_dashboard().people[0].has_conflict;
}

test "name-only reports create candidates not silent identity merges" {
    reset_demo();
    root spawn IngestWalker(incident_name=INCIDENT_NAME, person_name="Maya Gurung",
        source_name="Other volunteer", claim_type="MISSING", source_reference="VOL-001");
    assert len(get_dashboard().people) == 3;
}

test "stale and cross-incident person IDs are rejected" {
    reset_demo();
    stale = get_dashboard();
    reset_demo();
    result = publish_report(stale.incident_id, stale.organizations[0].id, stale.people[0].id,
        "FOUND_SAFE", "Summary", "", "STALE", "Original");
    assert result.error;
    other = root spawn IngestWalker(incident_name="Other incident", person_name="Other person",
        source_name="Other source", claim_type="MISSING", source_reference="OTHER-001");
    snap = get_dashboard();
    result = publish_report(snap.incident_id, snap.organizations[0].id, other.person_id,
        "FOUND_SAFE", "Summary", "", "CROSS", "Original");
    assert result.error;
}

test "reset preserves unrelated graph records shared places and evidence" {
    reset_demo();
    other = root ++> Incident(name="Reset isolation test");
    media = Media(media_type="image", description="Unrelated controlled image");
    other +>:Contains():+> media;
    signal = VerificationSignal(signal_type="TEST", value="keep me");
    media +>:HasSignal():+> signal;
    demo = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    demo_media = [demo ->:Contains:->][0];
    shared_place = [demo_media ->:LocatedAt:->][0];
    media +>:LocatedAt():+> shared_place;
    root ++> ActivityEntry(walker_name="Other", message="preserve", incident_id=jid(other));
    reset_demo();
    assert len([root -->[?:Incident, name == "Reset isolation test"]]) == 1;
    assert [media ->:LocatedAt:->][0].name == "Bhote Koshi Bridge";
    assert [media ->:HasSignal:->][0].value == "keep me";
    assert len([root -->[?:ActivityEntry, incident_id == jid(other)]]) == 1;
    assert len(get_dashboard().people) == 2;
    assert len(get_dashboard().alerts) == 0;
}

test "watch sees changes between claims batched before a run" {
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    person = [incident ->:Involves:->][0];
    for claim in [person <-:About:<-] { claim.seen_by_watch = False; }
    root spawn IngestWalker(incident_name=INCIDENT_NAME, person_name=person.name,
        selected_person_id=jid(person), source_name="Batch hospital", claim_type="FOUND_SAFE",
        timestamp="2026-09-21T09:15:00Z", source_reference="BATCH-001");
    watcher = root spawn WatchWalker(incident_id=jid(incident));
    assert watcher.alerts_created == 1;
    assert (root spawn WatchWalker(incident_id=jid(incident))).alerts_created == 0;
}

test "map evidence has real IDs and omits unknown and invalid coordinates" {
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    media = [incident ->:Contains:->][0];
    media +>:LocatedAt():+> Location(name="Unknown");
    media +>:LocatedAt():+> Location(name="Invalid", latitude=200.0, longitude=10.0);
    snap = get_dashboard();
    assert len(snap.locations) == 2;
    bridge = [p for p in snap.locations if p.name == "Bhote Koshi Bridge"][0];
    assert bridge.id and len(bridge.media_ids) == 1;
    assert bridge.evidence[0].claim_id == snap.people[0].claims[0].id;
    assert bridge.evidence[0].source_name == "Nepal Police Demo";
}


test "shared person does not leak another incident's claims or alerts" {
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    person = [incident ->:Involves:->][0];
    other = root ++> Incident(name="Shared person incident");
    other +>:Involves():+> person;
    other_report = root spawn IngestWalker(incident_name=other.name, person_name=person.name,
        selected_person_id=jid(person), source_name="Other institution", claim_type="DECEASED",
        timestamp="2026-09-22T10:00:00Z", source_reference="OTHER-SUBJECT-001");
    sub = [person ->:HasSubscription:->][0];
    sub +>:Receives():+> Alert(message="Other incident update", claim_id=other_report.created_claim_id);
    snap = get_dashboard();
    assert len(snap.people[0].claims) == 1;
    assert snap.people[0].latest_status == "MISSING";
    assert len(snap.alerts) == 0 and snap.people[0].subscriptions[0].alert_count == 0;
    reset_demo();
    assert len([other ->:Involves:->]) == 1;
}

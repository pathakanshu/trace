"""Offline timeline checks. Synthetic graph records below are unit fixtures only."""
import json;
import from unittest.mock { patch }
import from services.timeline { TimelineEntry, person_timeline }
import from services.trace { reset_demo, get_dashboard, add_hospital_update, run_watch }
import from demo.corpus { load_exercise_corpus }
import from graph.nodes { Incident, Person, Source, Claim, Alert, Subscription, InvestigationRun }
import from graph.edges { Involves, Asserts, About, HasSubscription, Receives, HasInvestigation }

def seeded_timeline() -> list[TimelineEntry] {
    snap = get_dashboard();
    maya = [p for p in snap.people if p.name == "Maya Gurung"][0];
    return person_timeline(snap.incident_id, maya.id);
}

# Reset regenerates graph IDs and ingestion times; compare the source history,
# source recording times and labels rather than pretending those new IDs persist.
def history_signature(rows: list[TimelineEntry]) -> list {
    return [(r.kind, r.source_name, r.claim_type, r.reported_at,
        r.source_reference, r.recorded_at, r.text, r.status, r.mode,
        r.status_changed, r.previous_claim_type, r.total_entries) for r in rows];
}

def fixture() -> tuple {
    incident = Incident(name="Timeline unit fixture (fictional)");
    person = Person(name="Timeline test person (fictional)");
    source = Source(name="Timeline test source (fictional)");
    root ++> incident;
    root ++> source;
    incident +>:Involves():+> person;
    return (incident, person, source);
}

def fixture_claim(incident: Incident, person: Person, source: Source, reference: str,
    reported: str = "2026-09-20T08:00:00Z", ingested: str = "2026-09-20T09:00:00Z",
    status: str = "MISSING") -> Claim {
    claim = Claim(claim_type=status, value="Fictional unit-test assertion",
        timestamp=reported, ingested_at=ingested, source_reference=reference,
        incident_id=jid(incident));
    source +>:Asserts():+> claim;
    claim +>:About():+> person;
    return claim;
}

test "timeline keeps police claim and exact Maya record separate after reset" {
    reset_demo();
    rows = seeded_timeline();
    claims = [r for r in rows if r.kind == "claim"];
    assert len(claims) == 1;
    assert claims[0].claim_type == "MISSING" and not claims[0].status_changed;
    assert claims[0].source_name == "Nepal Police Demo";
    assert claims[0].source_reference == "POLICE-DEMO-001";
    assert claims[0].reported_at and claims[0].ingested_at;
    assert len([r for r in rows if r.kind == "investigation" and r.mode == "REPLAYED"]) == 1;
    assert all(r.source_name != "Community Report Demo" for r in rows);
    assert all(r.total_entries == len(rows) for r in rows);
}

test "hospital is a cited status change while police and exactly one alert remain" {
    reset_demo();
    before = seeded_timeline();
    police_id = [r.claim_id for r in before if r.kind == "claim"][0];
    assert add_hospital_update() == 1;
    rows = seeded_timeline();
    claims = [r for r in rows if r.kind == "claim"];
    assert [r.claim_type for r in claims] == ["MISSING", "FOUND_SAFE"];
    assert claims[0].claim_id == police_id;
    assert claims[1].status_changed and claims[1].previous_claim_id == police_id;
    assert claims[1].previous_claim_type == "MISSING";
    assert claims[1].source_reference == "HOSPITAL-DEMO-001";
    alerts = [r for r in rows if r.kind == "alert"];
    assert len(alerts) == 1 and alerts[0].claim_id == claims[1].claim_id;
    assert alerts[0].recorded_at and alerts[0].subscriber_names;
    assert run_watch() == 0 and add_hospital_update() == 0;
    assert history_signature(seeded_timeline()) == history_signature(rows);
}

test "a second reset restores identical cited history without merging old IDs" {
    reset_demo();
    first = seeded_timeline();
    baseline = history_signature(first);
    add_hospital_update();
    reset_demo();
    second = seeded_timeline();
    assert history_signature(second) == baseline;
    assert {r.id for r in first}.isdisjoint({r.id for r in second});
    assert len([r for r in second if r.kind == "alert"]) == 0;
}

test "unindexed corpus person has a correct total and exact claim provenance" {
    cid = str(load_exercise_corpus()["incident_id"]);
    snap = get_dashboard(cid);
    person = snap.people[0];
    rows = person_timeline(cid, person.id);
    assert rows and all(r.kind == "claim" for r in rows);
    assert rows[0].total_entries == len(person.claims);
    assert {r.claim_id for r in rows} == {c.id for c in person.claims};
    assert all(r.source_reference and r.person_id == person.id for r in rows);
}

test "unknown IDs and a person outside the incident do not fall back to Maya" {
    reset_demo();
    snap = get_dashboard();
    pid = snap.people[0].id;
    assert person_timeline("not-an-incident", pid) == [];
    assert person_timeline(snap.incident_id, "not-a-person") == [];
    parts = fixture();
    other: Incident = parts[0];
    assert person_timeline(jid(other), pid) == [];
}

test "timeline reads do not call the network or create records" {
    reset_demo();
    add_hospital_update();
    snap = get_dashboard();
    with patch("socket.socket.connect", side_effect=AssertionError("Timeline must remain offline")) as network {
        first = seeded_timeline();
        second = seeded_timeline();
        network.assert_not_called();
    }
    assert history_signature(first) == history_signature(second);
    after = get_dashboard();
    assert [a.id for a in after.alerts] == [a.id for a in snap.alerts];
    assert [r.id for r in after.investigations] == [r.id for r in snap.investigations];
}

test "cap returns latest fifty and the true total with change context" {
    parts = fixture();
    incident: Incident = parts[0]; person: Person = parts[1]; source: Source = parts[2];
    for i in range(55) {
        fixture_claim(incident, person, source, f"fixture-{i}",
            reported=f"2026-09-20T08:{i:02d}:00Z", status="FOUND_SAFE" if i == 54 else "MISSING");
    }
    rows = person_timeline(jid(incident), jid(person));
    assert len(rows) == 50 and all(r.total_entries == 55 for r in rows);
    assert rows[0].source_reference == "fixture-5";
    assert rows[-1].source_reference == "fixture-54" and rows[-1].status_changed;
    assert rows[0].previous_claim_id and not rows[0].status_changed;
}

test "reported chronology takes priority then ingestion with unknown times last" {
    parts = fixture();
    incident: Incident = parts[0]; person: Person = parts[1]; source: Source = parts[2];
    fixture_claim(incident, person, source, "late-ingest", "2026-09-20T08:00:00Z", "2026-09-22T00:00:00Z");
    fixture_claim(incident, person, source, "early-ingest", "2026-09-20T10:00:00+02:00", "2026-09-21T00:00:00Z");
    fixture_claim(incident, person, source, "later-report", "2026-09-20T09:00:00Z", "2026-09-20T00:00:00Z");
    fixture_claim(incident, person, source, "unknown", "", "2026-09-19T00:00:00Z");
    rows = person_timeline(jid(incident), jid(person));
    assert [r.source_reference for r in rows] == ["early-ingest", "late-ingest", "later-report", "unknown"];
    assert rows[0].reported_at == "2026-09-20T10:00:00+02:00";
    assert not any(r.status_changed for r in rows);
}

test "foreign incident claims and their alerts are excluded for a shared person" {
    parts = fixture();
    incident: Incident = parts[0]; person: Person = parts[1]; source: Source = parts[2];
    own_claim = fixture_claim(incident, person, source, "own");
    other = Incident(name="Other timeline fixture (fictional)"); root ++> other;
    other +>:Involves():+> person;
    foreign = fixture_claim(other, person, source, "foreign");
    sub = Subscription(subscriber_name="Fictional follower"); person +>:HasSubscription():+> sub;
    sub +>:Receives():+> Alert(message="Foreign test alert", claim_id=jid(foreign));
    rows = person_timeline(jid(incident), jid(person));
    assert len(rows) == 1 and rows[0].claim_id == jid(own_claim);
}

test "multiple source edges and alert recipients remain attributed without duplicate rows" {
    parts = fixture();
    incident: Incident = parts[0]; person: Person = parts[1]; source: Source = parts[2];
    claim = fixture_claim(incident, person, source, "shared-test");
    second = Source(name="Another fictional test source"); root ++> second;
    second +>:Asserts():+> claim;
    alert = Alert(message="Fictional unit-test alert", claim_id=jid(claim));
    for name in ["Fictional follower A", "Fictional follower B"] {
        sub = Subscription(subscriber_name=name); person +>:HasSubscription():+> sub;
        sub +>:Receives():+> alert;
    }
    rows = person_timeline(jid(incident), jid(person));
    assert len(rows) == 2;
    assert len(rows[0].source_ids) == 2 and "Another fictional test source" in rows[0].source_name, [(r.kind, r.source_name, r.source_ids) for r in rows];
    assert len(rows[1].subscriber_names) == 2 and rows[1].kind == "alert";
}

test "unreadable saved run stays visible without an invented status or source" {
    parts = fixture();
    incident: Incident = parts[0]; person: Person = parts[1]; source: Source = parts[2];
    fixture_claim(incident, person, source, "test");
    run = InvestigationRun(person_id=jid(person), fingerprint="unit-fixture", result_json="{", mode="REPLAYED");
    incident +>:HasInvestigation():+> run;
    rows = person_timeline(jid(incident), jid(person));
    saved = [r for r in rows if r.kind == "investigation"][0];
    assert saved.id == jid(run) and saved.mode == "REPLAYED";
    assert saved.status == "" and saved.source_name == "" and saved.claim_id == "";
    assert saved.total_entries == 2;
}

test "legacy subscriber alert stays visible without an invented claim citation" {
    parts = fixture();
    incident: Incident = parts[0]; person: Person = parts[1];
    sub = Subscription(subscriber_name="Fictional legacy follower");
    person +>:HasSubscription():+> sub;
    alert = Alert(message="Fictional legacy unit-test alert", created_at="2026-09-20T12:00:00Z");
    sub +>:Receives():+> alert;
    rows = person_timeline(jid(incident), jid(person));
    assert len(rows) == 1 and rows[0].id == jid(alert);
    assert rows[0].kind == "alert" and rows[0].total_entries == 1;
    assert rows[0].claim_id == "" and rows[0].source_name == "";
    assert rows[0].recorded_at == "2026-09-20T12:00:00Z";
    assert not rows[0].status_changed;
}

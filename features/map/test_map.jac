"""Location projection regression checks; run in an isolated checkout/store."""
import from services.trace { reset_demo, get_dashboard, add_hospital_update }
import from graph.nodes { Incident, Location, Media, Claim, Source }
import from graph.edges { Involves, Contains, LocatedAt, About, Asserts, SupportedBy }
import from demo.seed { INCIDENT_NAME, HOSPITAL_UPDATE }
import from walkers.ingest { IngestWalker }

test "map omits nonfinite out-of-range and unknown coordinates" {
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    media = [incident ->:Contains:->][0];
    for pair in [[0.0, 0.0], [91.0, 10.0], [27.0, -181.0], [float("nan"), 85.0], [27.0, float("inf")]] {
        media +>:LocatedAt():+> Location(name="Invalid exercise coordinate", latitude=pair[0], longitude=pair[1]);
    }
    # Zero on one axis is a valid coordinate; only the legacy 0,0 pair is unknown.
    media +>:LocatedAt():+> Location(name="Equator", latitude=0.0, longitude=85.0);
    media +>:LocatedAt():+> Location(name="Prime meridian", latitude=27.0, longitude=0.0);
    places = get_dashboard().locations;
    assert len(places) == 4;
    assert "Equator" in [p.name for p in places];
    assert "Prime meridian" in [p.name for p in places];
}

test "map lists a report once at a place with multiple supporting media" {
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    photo = [m for m in [incident ->:Contains:->] if m.media_type == "image"][0];
    place = [photo ->:LocatedAt:->][0];
    claim = [photo <-:SupportedBy:<-][0];
    another = Media(media_type="image", description="Second exercise image at same place");
    incident +>:Contains():+> another;
    another +>:LocatedAt():+> place;
    claim +>:SupportedBy():+> another;
    projected = [p for p in get_dashboard().locations if p.id == jid(place)][0];
    assert len(projected.media_ids) == 2;
    assert [e.claim_id for e in projected.evidence] == [jid(claim)];
}

test "map excludes another incident's claim even on shared media" {
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    photo = [m for m in [incident ->:Contains:->] if m.media_type == "image"][0];
    person = [incident ->:Involves:->][0];
    other = root ++> Incident(name="Map projection isolation");
    foreign = Claim(claim_type="DECEASED", incident_id=jid(other), value="Unrelated report");
    source = root ++> Source(name="Another incident's source");
    source +>:Asserts():+> foreign;
    foreign +>:About():+> person;
    foreign +>:SupportedBy():+> photo;
    snap = get_dashboard();
    assert all([e.claim_id != jid(foreign) for p in snap.locations for e in p.evidence]);
    assert all([c.id != jid(foreign) for p in snap.people for c in p.claims]);
}

test "map person IDs resolve to current hospital reports without relocating anyone" {
    reset_demo();
    before = get_dashboard();
    bridge = [p for p in before.locations if p.name == "Bhote Koshi Bridge"][0];
    evidence = bridge.evidence[0];
    maya = [p for p in before.people if p.id == evidence.person_id][0];
    assert maya.name == evidence.person_name and maya.latest_status == "MISSING";
    assert add_hospital_update() == 1;
    after = get_dashboard();
    updated = [p for p in after.people if p.id == evidence.person_id][0];
    new_bridge = [p for p in after.locations if p.id == bridge.id][0];
    assert updated.latest_status == "FOUND_SAFE" and not updated.has_conflict;
    assert updated.claims[-1].source_name == "Central Hospital Demo";
    assert new_bridge.latitude == bridge.latitude and new_bridge.longitude == bridge.longitude;
    assert len(new_bridge.evidence) == 1;
    assert new_bridge.evidence[0].source_name == "Nepal Police Demo";
    assert new_bridge.evidence[0].claim_id == evidence.claim_id;
    assert len(after.alerts) == 1;
    assert add_hospital_update() == 0;
    reset_demo();
    assert len(get_dashboard().alerts) == 0;
}

test "map-linked person keeps conflicting current reports and separate candidates" {
    reset_demo();
    add_hospital_update();
    snap = get_dashboard();
    bridge = [p for p in snap.locations if p.name == "Bhote Koshi Bridge"][0];
    maya = [p for p in snap.people if p.id == bridge.evidence[0].person_id][0];
    root spawn IngestWalker(incident_name=INCIDENT_NAME, selected_person_id=maya.id,
        person_name=maya.name, source_name="Conflicting exercise report", claim_type="MISSING",
        timestamp=HOSPITAL_UPDATE["timestamp"], source_reference="MAP-CONFLICT-001");
    after = get_dashboard();
    updated = [p for p in after.people if p.id == maya.id][0];
    assert updated.has_conflict and updated.latest_status == "UNKNOWN";
    assert len(updated.claims) == 3;
    assert len(after.people) == 2;
    # The seeded market media have no About/SupportedBy person report.
    market = [p for p in after.locations if p.name == "Tatopani Market"][0];
    assert len(market.evidence) == 0;
}

test "report navigation requires its own media link and valid coordinates" {
    reset_demo();
    initial = get_dashboard();
    police = [c for p in initial.people for c in p.claims if c.source_name == "Nepal Police Demo"][0];
    community = [c for p in initial.people for c in p.claims if c.source_name == "Community Report Demo"][0];
    assert [e.claim_id for l in initial.locations for e in l.evidence] == [police.id];
    assert add_hospital_update() == 1;
    updated = get_dashboard();
    hospital = [c for p in updated.people for c in p.claims if c.source_name == "Central Hospital Demo"][0];
    # Same subject and even a newer status do not imply a location for this report.
    mapped_ids = [e.claim_id for l in updated.locations for e in l.evidence];
    assert mapped_ids == [police.id];
    assert hospital.id not in mapped_ids and community.id not in mapped_ids;

    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    maya = [p for p in [incident ->:Involves:->] if p.name == "Maya Gurung"][0];
    hospital_claim = [c for c in [maya <-:About:<-] if jid(c) == hospital.id][0];
    evidence = Media(media_type="image", description="Controlled report-navigation fixture");
    unknown = Location(name="No known location");
    incident +>:Contains():+> evidence;
    evidence +>:LocatedAt():+> unknown;
    hospital_claim +>:SupportedBy():+> evidence;
    assert hospital.id not in [e.claim_id for l in get_dashboard().locations for e in l.evidence];

    # The explicit media/location relationship makes this report navigable.
    unknown.latitude = 27.9486;
    unknown.longitude = 85.9442;
    located = get_dashboard();
    hospital_places = [l for l in located.locations if hospital.id in [e.claim_id for e in l.evidence]];
    assert len(hospital_places) == 1 and hospital_places[0].id == jid(unknown);
    assert hospital_places[0].evidence[0].person_id == jid(maya);
    assert hospital_places[0].evidence[0].source_reference == hospital.source_reference;
    assert community.id not in [e.claim_id for l in located.locations for e in l.evidence];
    assert len(located.alerts) == 1;
    reset_demo();
    restored = get_dashboard();
    assert hospital.id not in [e.claim_id for l in restored.locations for e in l.evidence];
    assert len(restored.locations) == 2 and len(restored.alerts) == 0;
}

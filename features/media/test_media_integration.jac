"""Integration checks for shared snapshots, exact copies, evidence scope, and reset."""
import from graph.nodes { Incident, MediaMetadata, MediaComment, MediaAssertion }
import from graph.edges { Contains, ExactCopyOf, HasSignal }
import from features.media.media_upload {
    upload_image, list_incident_media, add_media_comment, add_media_assertion, delete_media
}
import from services.trace { get_dashboard, reset_demo }
import from demo.seed { INCIDENT_NAME }
import from walkers.evidence { EvidenceWalker }

glob IMAGE: str = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/Z1sAAAAASUVORK5CYII=";

test "uploads refresh the shared snapshot without confusing capture time or fixture hashes" {
    reset_demo();
    before = get_dashboard();
    assert all([not r.sha256 for r in before.media_records]);
    first = upload_image(INCIDENT_NAME, "pixel.png", "Source A", IMAGE);
    retry = upload_image(INCIDENT_NAME, "pixel.png", "Source A", IMAGE);
    assert first.id == retry.id;
    second = upload_image(INCIDENT_NAME, "copy.png", "Source B", IMAGE);
    snap = get_dashboard();
    assert len(snap.media_records) == len(before.media_records) + 2;
    assert first.uploaded_at != "";
    assert [m for m in snap.media if m.id == first.id][0].captured_at == "";
    assert len([e for e in snap.graph.edges if e.kind == "ExactCopyOf" and e.from_id == second.id and e.to_id == first.id]) == 1;
    add_media_comment(first.id, INCIDENT_NAME, "Demo comment", "Volunteer");
    add_media_assertion(first.id, INCIDENT_NAME, "LOCATION", "Bridge", "Source A", "Reported only");
    row = [r for r in get_dashboard().media_records if r.id == first.id][0];
    assert len(row.comments) == 1 and len(row.assertions) == 1;
}

test "real upload checks are scoped and idempotent while seed checks stay simulated" {
    reset_demo();
    outside = root ++> Incident(name="Outside media incident");
    first = upload_image(INCIDENT_NAME, "one.png", "A", IMAGE);
    upload_image(INCIDENT_NAME, "two.png", "B", IMAGE);
    external = upload_image(outside.name, "other.png", "C", IMAGE);
    snap = get_dashboard();
    root spawn EvidenceWalker(incident_id=snap.incident_id);
    root spawn EvidenceWalker(incident_id=snap.incident_id);
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    media = [m for m in [incident ->:Contains:->] if jid(m) == first.id][0];
    signals = [s for s in [media ->:HasSignal:->] if s.method == "sha256"];
    assert len(signals) == 1 and signals[0].value == "1 exact matching media record(s).";
    external_media = [m for m in [outside ->:Contains:->] if jid(m) == external.id][0];
    assert len([external_media ->:HasSignal:->]) == 0;
}

test "reset clears demo uploads and contributions while retaining outside and shared media" {
    reset_demo();
    outside = root ++> Incident(name="Outside reset media");
    first = upload_image(INCIDENT_NAME, "local.png", "A", IMAGE);
    add_media_comment(first.id, INCIDENT_NAME, "Reset me", "Volunteer");
    add_media_assertion(first.id, INCIDENT_NAME, "LOCATION", "Bridge", "A", "Report");
    external = upload_image(outside.name, "outside.png", "B", IMAGE);
    shared = upload_image(INCIDENT_NAME, "shared.png", "C", IMAGE);
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    shared_node = [m for m in [incident ->:Contains:->] if jid(m) == shared.id][0];
    outside +>:Contains():+> shared_node;
    reset_demo();
    assert len(get_dashboard().media_records) == 3;
    remaining = list_incident_media(outside.name);
    assert sorted([r.id for r in remaining]) == sorted([external.id, shared.id]);
    assert [r for r in remaining if r.id == shared.id][0].sha256 == shared.sha256;
}

test "deleting an unreferenced upload refreshes copies and cannot delete seeded claim evidence" {
    reset_demo();
    first = upload_image(INCIDENT_NAME, "first.png", "A", IMAGE);
    second = upload_image(INCIDENT_NAME, "second.png", "B", IMAGE);
    add_media_comment(first.id, INCIDENT_NAME, "Disposable demo comment", "Tester");
    assert delete_media(first.id, INCIDENT_NAME);
    records = list_incident_media(INCIDENT_NAME);
    assert first.id not in [r.id for r in records];
    assert [r for r in records if r.id == second.id][0].duplicate_ids == [];
    seed_id = [r.id for r in records if not r.sha256][0];
    rejected = False;
    try { delete_media(seed_id, INCIDENT_NAME); }
    except ValueError { rejected = True; }
    assert rejected;
}

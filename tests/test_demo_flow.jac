"""Judge demo regression, offline: graph/projection agreement across two resets.

Complements test_trace's individual actions with replay citation rebinding and
whole-flow repeatability. Only runtime-produced snapshots are inspected; recorded
model answers keep their REPLAYED labels. No live provider is invoked.
"""
import json;
import from unittest.mock { patch }
import from services.trace {
    DashboardSnapshot, reset_demo, get_dashboard, add_hospital_update, run_watch
}

# Ignore generated node IDs and ingestion/activity times, but compare report
# content, original recording times/usage, subscriptions and graph topology counts.
def demo_signature(snap: DashboardSnapshot) -> dict {
    return {
        "incident": [snap.incident_name, snap.incident_description, snap.incident_start],
        "people": sorted([(p.name, p.age, p.latest_status, p.has_conflict,
            [(c.claim_type, c.value, c.timestamp, c.source_name, c.source_reference,
              c.original_content, c.extraction_method) for c in p.claims],
            [(s.subscriber_name, s.subscriber_contact, s.alert_count) for s in p.subscriptions])
            for p in snap.people]),
        "organizations": sorted([(o.name, o.organization_type) for o in snap.organizations]),
        "media": sorted([(m.description, m.url, m.captured_at, m.location_name,
            m.earliest_known_copy, sorted(m.depicts),
            [(s.signal_type, s.value, s.confidence) for s in m.signals]) for m in snap.media]),
        "locations": sorted([(l.name, l.latitude, l.longitude, len(l.media_ids),
            [(e.person_name, e.source_name, e.claim_type, e.reported_at, e.source_reference)
             for e in l.evidence]) for l in snap.locations]),
        "runs": sorted([(r.status, r.mode, r.model, r.run_at, r.message, r.trace,
            r.usage_source, r.total_tokens, [c.source_name for c in r.citations])
            for r in snap.investigations]),
        "node_kinds": sorted([n.kind for n in snap.graph.nodes]),
        "edge_kinds": sorted([(e.kind, e.status, e.derived) for e in snap.graph.edges]),
        "alerts": len(snap.alerts), "hospital": snap.hospital_update_added,
        "duplicates": len(snap.duplicates)
    };
}

def assert_replay_links(snap: DashboardSnapshot) -> None {
    claims = {c.id: c for p in snap.people for c in p.claims};
    owners = {c.id: p.id for p in snap.people for c in p.claims};
    assert len(snap.investigations) == 2;
    with open("demo/recorded_investigations.json") as handle {
        recordings = json.load(handle)["runs"];
    }
    expected = {r["result"]["citations"][0]["source_name"]: r["result"] for r in recordings};
    assert len(expected) == 2;
    assert sorted([n.id for n in snap.graph.nodes if n.kind == "Investigation"]) == sorted([r.id for r in snap.investigations]);
    for run in snap.investigations {
        assert run.mode == "REPLAYED";
        assert run.usage_source == "provider" and run.total_tokens > 0;
        assert run.run_at and run.model and run.trace;
        assert run.claim_id in claims;
        recording = expected[claims[run.claim_id].source_name];
        assert (run.status, run.model, run.run_at, run.message, run.trace,
            run.total_tokens) == (recording["status"], recording["model"],
            recording["run_at"], recording["message"], recording["trace"],
            recording["usage"]["total_tokens"]);
        assert run.person_id == owners[run.claim_id];
        assert run.citations[0].claim_id == run.claim_id;
        assert len([e for e in snap.graph.edges if e.kind == "HasInvestigation"
            and e.from_id == snap.incident_id and e.to_id == run.id and not e.derived]) == 1;
        for cited in run.citations {
            assert cited.claim_id in claims;
            assert cited.source_name == claims[cited.claim_id].source_name;
            assert len([e for e in snap.graph.edges if e.kind == "InvestigationCitation"
                and e.from_id == run.id and e.to_id == cited.claim_id and e.derived]) == 1;
        }
    }
    node_ids = [n.id for n in snap.graph.nodes];
    assert len(node_ids) == len(set(node_ids));
    for edge in snap.graph.edges {
        assert edge.from_id in node_ids and edge.to_id in node_ids;
    }
    for place in snap.locations {
        for evidence in place.evidence {
            assert evidence.claim_id in claims;
            assert evidence.person_id == owners[evidence.claim_id];
        }
    }
}

test "judge demo replays, alerts once, and resets reproducibly twice without network" {
    with patch("socket.socket.connect", side_effect=AssertionError("Demo smoke must stay offline")) as network {
        assert reset_demo();
        initial = get_dashboard();
        baseline = demo_signature(initial);
        assert len(initial.people) == 2 and len(initial.alerts) == 0;
        assert len([c for p in initial.people for c in p.claims]) == 2;
        assert not initial.hospital_update_added;
        assert_replay_links(initial);
        for cycle in range(2) {
            before = get_dashboard();
            maya = [p for p in before.people if p.name == "Maya Gurung"][0];
            assert maya.latest_status == "MISSING" and not maya.has_conflict;
            police = maya.claims[0];
            assert police.source_name == "Nepal Police Demo";
            assert police.source_reference == "POLICE-DEMO-001";
            assert add_hospital_update() == 1;
            updated = get_dashboard();
            safe = [p for p in updated.people if p.id == maya.id][0];
            assert len(updated.people) == 2 and updated.hospital_update_added;
            assert safe.latest_status == "FOUND_SAFE" and not safe.has_conflict;
            assert [c.claim_type for c in safe.claims] == ["MISSING", "FOUND_SAFE"];
            retained = safe.claims[0];
            assert (retained.id, retained.source_id, retained.organization_id,
                retained.original_content, retained.ingested_at, retained.source_reference,
                retained.value, retained.timestamp, retained.extraction_method,
                retained.supporting_media) == (police.id, police.source_id, police.organization_id,
                police.original_content, police.ingested_at, police.source_reference,
                police.value, police.timestamp, police.extraction_method, police.supporting_media);
            hospital = safe.claims[1];
            assert hospital.source_name == "Central Hospital Demo";
            assert len(updated.alerts) == 1 and updated.alerts[0].claim_id == hospital.id;
            assert safe.subscriptions[0].alert_count == 1;
            assert_replay_links(updated);
            assert [r.id for r in updated.investigations] == [r.id for r in before.investigations];
            assert run_watch() == 0 and add_hospital_update() == 0;
            assert demo_signature(get_dashboard()) == demo_signature(updated);
            old_claim_ids = [c.id for p in updated.people for c in p.claims];
            old_run_ids = [r.id for r in updated.investigations];
            assert reset_demo();
            restored = get_dashboard();
            assert demo_signature(restored) == baseline;
            assert restored.incident_id != updated.incident_id;
            assert_replay_links(restored);
            assert not any(c.id in old_claim_ids for p in restored.people for c in p.claims);
            assert not any(r.id in old_run_ids for r in restored.investigations);
        }
        network.assert_not_called();
    }
}

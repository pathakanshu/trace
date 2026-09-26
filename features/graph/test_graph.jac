"""Graph projection tests. Run: jac test features/graph/test_graph.jac

Runs the scripted hospital update, then checks that the projection exposes
Source -Asserts-> Claim -About-> Person -HasSubscription-> Subscription
-Receives-> Alert, and the stored Claim -Triggered-> Alert link.
"""

import from services.trace { reset_demo, add_hospital_update }
import from demo.seed { INCIDENT_NAME }
import from graph.nodes { Incident }
import from features.graph.services { build_graph_snapshot, GraphSnapshot, GraphNodeView }

def _snapshot() -> GraphSnapshot {
    found = [root -->[?:Incident, name == INCIDENT_NAME]];
    return build_graph_snapshot(found[0] if found else None);
}

def _has_edge(snap: GraphSnapshot, kind: str, from_id: str, to_id: str) -> bool {
    for e in snap.edges {
        if e.kind == kind and e.from_id == from_id and e.to_id == to_id {
            return True;
        }
    }
    return False;
}

def _field(n: GraphNodeView, name: str) -> str {
    for f in n.fields {
        if f.name == name { return f.value; }
    }
    return "";
}

test "hospital FOUND_SAFE claim links source, subject and alert" {
    reset_demo();
    add_hospital_update();
    snap = _snapshot();
    assert snap.incident_id != "";

    claims = [n for n in snap.nodes if n.kind == "Claim" and _field(n, "claim_type") == "FOUND_SAFE"];
    assert len(claims) == 1, "expected one FOUND_SAFE claim";
    claim = claims[0];

    sources = [n for n in snap.nodes if n.kind == "Source" and n.label == "Central Hospital Demo"];
    assert len(sources) == 1;
    assert _has_edge(snap, "Asserts", sources[0].id, claim.id);

    maya = [n for n in snap.nodes if n.kind == "Person" and n.label == "Maya Gurung"][0];
    assert _has_edge(snap, "About", claim.id, maya.id);

    subs = [e for e in snap.edges if e.kind == "HasSubscription" and e.from_id == maya.id];
    assert len(subs) == 1;
    alerts = [e for e in snap.edges if e.kind == "Receives" and e.from_id == subs[0].to_id];
    assert len(alerts) == 1;
    assert _has_edge(snap, "Triggered", claim.id, alerts[0].to_id);

    # Every stored relationship is marked stored; candidates are marked derived.
    for e in snap.edges {
        if e.kind == "DuplicateCandidate" {
            assert e.derived and e.status == "candidate";
        } elif e.kind != "Touched" {
            assert not e.derived;
        }
    }
    # Seed media signals are labelled simulated.
    signals = [n for n in snap.nodes if n.kind == "Signal"];
    assert len(signals) > 0;
    assert all(["simulated" in s.badges for s in signals]);
}

test "police MISSING claim is kept alongside the hospital claim" {
    reset_demo();
    add_hospital_update();
    snap = _snapshot();
    types = sorted([_field(n, "claim_type") for n in snap.nodes if n.kind == "Claim"]);
    assert "MISSING" in types and "FOUND_SAFE" in types;
    # Only the new claim triggered an alert.
    triggered = [e for e in snap.edges if e.kind == "Triggered"];
    assert len(triggered) == 1;
}

"""Graph projection tests. Run: jac test features/graph/test_graph.jac

Runs the real demo flows (hospital update, structured publishing, an identity
review) and checks that the projection exposes the stored relationships, keeps
derived links marked derived, and separates reported time from ingestion time.
"""

import from services.trace { reset_demo, add_hospital_update }
import from demo.seed { INCIDENT_NAME }
import from demo.reset { clear_incident }
import from graph.nodes { Incident, Person, IdentityDecision, IdentityProposal }
import from graph.edges { Involves, Reviews }
import from walkers.resolve { ResolveWalker }
import from features.organizations.services { publish_report }
import from features.graph.services { build_graph_snapshot, GraphSnapshot, GraphNodeView, GraphField }

def _incident() -> Incident | None {
    found = [root -->[?:Incident, name == INCIDENT_NAME]];
    return found[0] if found else None;
}

# Same inputs get_dashboard() passes: the incident plus ResolveWalker's candidates.
def _snapshot() -> GraphSnapshot {
    incident = _incident();
    if incident is None {
        return build_graph_snapshot(None);
    }
    dups = (incident spawn ResolveWalker(quiet=True)).candidates;
    return build_graph_snapshot(incident, dups);
}

def _has_edge(snap: GraphSnapshot, kind: str, from_id: str, to_id: str) -> bool {
    for e in snap.edges {
        if e.kind == kind and e.from_id == from_id and e.to_id == to_id {
            return True;
        }
    }
    return False;
}

def _value(fields: list[GraphField], name: str) -> str {
    for f in fields {
        if f.name == name { return f.value; }
    }
    return "";
}

def _field(n: GraphNodeView, name: str) -> str {
    return _value(n.fields, name);
}

def _person(snap: GraphSnapshot, name: str) -> GraphNodeView {
    return [n for n in snap.nodes if n.kind == "Person" and n.label == name][0];
}

# Links from a claim to an alert: a stored Triggered edge, or the derived
# ClaimRef read from Alert.claim_id when WatchWalker stored no edge.
def _cause_links(snap: GraphSnapshot, alert_id: str) -> list {
    return [e for e in snap.edges if e.to_id == alert_id and e.kind in ["Triggered", "ClaimRef"]];
}

test "hospital FOUND_SAFE claim links source, subject and alert" {
    reset_demo();
    add_hospital_update();
    snap = _snapshot();
    assert snap.incident_id != "";

    claims = [n for n in snap.nodes if n.kind == "Claim" and _field(n, "claim_type") == "FOUND_SAFE"];
    assert len(claims) == 1, "expected one FOUND_SAFE claim";
    claim = claims[0];
    # Reported time and ingestion time are separate fields.
    assert _field(claim, "reported_at (by the source)") != _field(claim, "ingested_at (stored by Trace)");
    assert _value(claim.provenance, "source_reference") == "HOSPITAL-DEMO-001";

    sources = [n for n in snap.nodes if n.kind == "Source" and n.label == "Central Hospital Demo"];
    assert len(sources) == 1;
    assert _has_edge(snap, "Asserts", sources[0].id, claim.id);

    maya = _person(snap, "Maya Gurung");
    assert _has_edge(snap, "About", claim.id, maya.id);

    subs = [e for e in snap.edges if e.kind == "HasSubscription" and e.from_id == maya.id];
    assert len(subs) == 1;
    alerts = [e for e in snap.edges if e.kind == "Receives" and e.from_id == subs[0].to_id];
    assert len(alerts) == 1;
    links = _cause_links(snap, alerts[0].to_id);
    assert len(links) == 1 and links[0].from_id == claim.id;

    # Candidates come from the People tab's results, not a second matching pass.
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    cands = [e for e in snap.edges if e.kind == "DuplicateCandidate"];
    assert len(cands) == len((incident spawn ResolveWalker(quiet=True)).candidates);
    # Stored edges are never marked derived, and derived links never stored.
    for e in snap.edges {
        if e.kind == "DuplicateCandidate" {
            assert e.derived and e.status == "candidate";
        } elif e.kind in ["Touched", "ClaimRef"] {
            assert e.derived and e.status == "derived";
        } else {
            assert not e.derived;
        }
    }
    # Seeded publishers hang off the incident with their uppercase type.
    orgs = [n for n in snap.nodes if n.kind == "Organization"];
    assert "HOSPITAL" in [_field(o, "organization_type") for o in orgs];
    for o in orgs {
        assert _has_edge(snap, "HasOrganization", snap.incident_id, o.id);
    }
    # Seed media signals are labelled simulated.
    signals = [n for n in snap.nodes if n.kind == "Signal"];
    assert len(signals) > 0;
    assert all(["simulated" in s.badges for s in signals]);
    # Activity is scoped to this incident.
    activity = [n for n in snap.nodes if n.kind == "Activity"];
    assert len(activity) > 0;
    assert all([_value(a.provenance, "incident_id") == snap.incident_id for a in activity]);
}

test "police MISSING claim is kept alongside the hospital claim" {
    reset_demo();
    add_hospital_update();
    snap = _snapshot();
    types = sorted([_field(n, "claim_type") for n in snap.nodes if n.kind == "Claim"]);
    assert "MISSING" in types and "FOUND_SAFE" in types;
    # Only the new claim caused an alert.
    alerts = [n for n in snap.nodes if n.kind == "Alert"];
    assert len(alerts) == 1;
}

test "published report shows Organization -Publishes-> Source -Asserts-> Claim" {
    reset_demo();
    snap = _snapshot();
    org = [n for n in snap.nodes if n.kind == "Organization" and _field(n, "organization_type") == "HOSPITAL"][0];
    maya = _person(snap, "Maya Gurung");
    result = publish_report(
        snap.incident_id, org.id, maya.id, "FOUND_SAFE", "Fictional structured report",
        "2026-09-21T09:15:00Z", "GRAPH-TEST-001", "Original supplied text"
    );
    assert result.error == "", result.error;

    snap = _snapshot();
    claim = [n for n in snap.nodes if n.id == result.claim_id][0];
    assert _field(claim, "reported_at (by the source)") == "2026-09-21T09:15:00+00:00";
    assert _field(claim, "ingested_at (stored by Trace)") != "not recorded";
    assert _value(claim.provenance, "extraction_method") == "structured_form";
    sources = [e.from_id for e in snap.edges if e.kind == "Asserts" and e.to_id == claim.id];
    assert len(sources) == 1;
    assert _has_edge(snap, "Publishes", org.id, sources[0]);
}

test "identity review is a stored node linked to both records and cleared on reset" {
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    people = [incident ->:Involves:->];
    maya = [p for p in people if p.name == "Maya Gurung"][0];
    alias = [p for p in people if p.name == "Maya G."][0];
    # Same shape as the People tab's record_identity_decision.
    ids = sorted([jid(maya), jid(alias)]);
    decision = IdentityDecision(
        pair_key="|".join(ids), person_a_id=jid(maya), person_b_id=jid(alias),
        person_a_name=maya.name, person_b_name=alias.name, decision="CONFIRMED",
        reviewer="Graph test", decided_at="2026-09-21T10:00:00+00:00"
    );
    root ++> decision;
    decision +>:Reviews():+> maya;
    decision +>:Reviews():+> alias;

    snap = _snapshot();
    nodes = [n for n in snap.nodes if n.kind == "IdentityDecision"];
    assert len(nodes) == 1;
    assert "confirmed" in nodes[0].badges;
    reviews = [e for e in snap.edges if e.kind == "Reviews" and e.from_id == nodes[0].id];
    assert sorted([e.to_id for e in reviews]) == ids;
    assert all([e.status == "confirmed" and not e.derived for e in reviews]);

    root ++> IdentityProposal(
        pair_key="|".join(ids), person_a_id=jid(maya), person_b_id=jid(alias),
        incident_name=INCIDENT_NAME, proposed_by="Graph test"
    );

    # Reset must remove the review and proposal too, not keep both people alive.
    clear_incident(INCIDENT_NAME);
    assert len([root -->[?:IdentityDecision]]) == 0;
    assert len([root -->[?:IdentityProposal]]) == 0;
    assert len([root -->[?:Incident, name == INCIDENT_NAME]]) == 0;
}

"""Identity review tests. Run: jac test features/people/test_identity_review.jac"""

import from services.trace { reset_demo, get_dashboard }
import from features.people.services { review_identity, propose_identity }
import from graph.nodes { IdentityDecision, IdentityProposal, Incident, Person, Claim, Source }
import from graph.edges { Involves, About, Asserts }
import from walkers.resolve { latest_status_claim, compare_differences }
import from demo.seed { INCIDENT_NAME }

def maya_pair() -> list[str] {
    d = get_dashboard().duplicates[0];
    return [d.person_a_id, d.person_b_id];
}

def claim_ids() -> list[str] {
    return [c.id for p in get_dashboard().people for c in p.claims];
}

def add_claim(p: Person, src: str, ctype: str, ts: str) -> None {
    s = root ++> Source(name=src, source_type="POLICE");
    c = Claim(claim_type=ctype, timestamp=ts);
    s +>:Asserts():+> c;
    c +>:About():+> p;
}

test "confirm persists, keeps both records and sources" {
    reset_demo();
    ids = maya_pair();
    res = review_identity(INCIDENT_NAME, ids[0], ids[1], "CONFIRMED", "Priya", "checked", ["same first name"], claim_ids());
    assert res.ok and res.changed;
    snap = get_dashboard();
    assert len(snap.people) == 2;
    d = snap.duplicates[0];
    assert d.decision == "CONFIRMED" and d.reviewer == "Priya" and d.decided_at != "";
    assert len(d.evidence_claim_ids) == 2;
    sources = [c.source_name for p in snap.people for c in p.claims];
    assert "Nepal Police Demo" in sources and "Community Report Demo" in sources;
}

test "reversed-id retry does not duplicate" {
    reset_demo();
    ids = maya_pair();
    review_identity(INCIDENT_NAME, ids[0], ids[1], "CONFIRMED", "Priya", "", [], []);
    again = review_identity(INCIDENT_NAME, ids[1], ids[0], "CONFIRMED", "Priya", "", [], []);
    assert again.ok and not again.changed;
    assert len([root -->[?:IdentityDecision]]) == 1;
}

test "changed decision keeps complete earlier review" {
    reset_demo();
    ids = maya_pair();
    cids = claim_ids();
    review_identity(INCIDENT_NAME, ids[0], ids[1], "CONFIRMED", "Priya", "nickname known", ["same age (24)"], cids);
    res = review_identity(INCIDENT_NAME, ids[1], ids[0], "REJECTED", "Ravi", "different families", [], []);
    assert res.ok and res.changed;
    d = get_dashboard().duplicates[0];
    assert d.decision == "REJECTED" and d.reviewer == "Ravi" and d.note == "different families";
    assert len(d.past_reviews) == 1;
    prev = d.past_reviews[0];
    assert prev.decision == "CONFIRMED" and prev.reviewer == "Priya";
    assert prev.note == "nickname known";
    assert prev.basis == ["same age (24)"];
    assert sorted(prev.evidence_claim_ids) == sorted(cids);
    assert len([root -->[?:IdentityDecision]]) == 1;
    assert len(get_dashboard().people) == 2;
    assert len(claim_ids()) == 2;
}

test "invalid ids and input are refused" {
    reset_demo();
    ids = maya_pair();
    assert not review_identity(INCIDENT_NAME, ids[0], ids[1], "MERGE", "Priya", "", [], []).ok;
    assert not review_identity(INCIDENT_NAME, ids[0], ids[1], "CONFIRMED", "  ", "", [], []).ok;
    assert not review_identity(INCIDENT_NAME, ids[0], ids[0], "CONFIRMED", "Priya", "", [], []).ok;
    assert not review_identity(INCIDENT_NAME, ids[0], "nope", "CONFIRMED", "Priya", "", [], []).ok;
    # A claim id is a real node but not a Person.
    assert not review_identity(INCIDENT_NAME, ids[0], claim_ids()[0], "CONFIRMED", "Priya", "", [], []).ok;
    assert not review_identity("No Such Incident", ids[0], ids[1], "CONFIRMED", "Priya", "", [], []).ok;
    assert len([root -->[?:IdentityDecision]]) == 0;
}

test "cross-incident pair is refused" {
    reset_demo();
    ids = maya_pair();
    other = root ++> Incident(name="Other Demo Incident");
    stranger = Person(name="Maya Gurung", age=24);
    other +>:Involves():+> stranger;
    res = review_identity(INCIDENT_NAME, ids[0], jid(stranger), "CONFIRMED", "Priya", "", [], []);
    assert not res.ok;
    res2 = review_identity("Other Demo Incident", ids[0], jid(stranger), "CONFIRMED", "Priya", "", [], []);
    assert not res2.ok;
    assert len([root -->[?:IdentityDecision]]) == 0;
}

test "latest status uses report timestamps, not de-duplicated order" {
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    p = Person(name="Timeline Test", age=30);
    incident +>:Involves():+> p;
    # Inserted out of order on purpose: MISSING -> FOUND_SAFE -> MISSING by time.
    add_claim(p, "Src C", "MISSING", "2026-09-22T10:00:00");
    add_claim(p, "Src A", "MISSING", "2026-09-20T10:00:00");
    add_claim(p, "Src B", "FOUND_SAFE", "2026-09-21T10:00:00");
    latest = latest_status_claim(p);
    assert latest is not None;
    assert latest.claim_type == "MISSING";
    assert latest.timestamp == "2026-09-22T10:00:00";
    q = Person(name="Timeline Other", age=30);
    incident +>:Involves():+> q;
    add_claim(q, "Src D", "MISSING", "2026-09-20T09:00:00");
    diffs = compare_differences(p, q);
    assert not [d for d in diffs if d.startswith("Latest status")];
}

test "agent proposal reaches review with cited claims, and is idempotent" {
    reset_demo();
    ids = maya_pair();
    cids = claim_ids();
    r1 = propose_identity(INCIDENT_NAME, ids[1], ids[0], "Investigation agent (demo)", "Same age, nearby places", cids);
    assert r1.ok and r1.changed;
    r2 = propose_identity(INCIDENT_NAME, ids[0], ids[1], "Investigation agent (demo)", "Same age, nearby places", cids);
    assert r2.ok and not r2.changed;
    assert len([root -->[?:IdentityProposal]]) == 1;
    d = get_dashboard().duplicates[0];
    assert d.proposed_by == "Investigation agent (demo)";
    assert sorted(d.cited_claim_ids) == sorted(cids);
    assert d.decision == "PENDING";
    # Citations must be reports about these two records.
    assert not propose_identity(INCIDENT_NAME, ids[0], ids[1], "agent", "", ["bogus"]).ok;
    assert not propose_identity(INCIDENT_NAME, ids[0], ids[1], "", "", []).ok;
}

test "unknowns never claim a check was not performed" {
    reset_demo();
    d = get_dashboard().duplicates[0];
    assert "No photo, document, or contact comparison result is recorded for this pair" in d.unknowns;
    assert not [u for u in d.unknowns if "performed" in u or "not stated by any source" in u];
}

test "reset clears decisions" {
    reset_demo();
    ids = maya_pair();
    review_identity(INCIDENT_NAME, ids[0], ids[1], "CONFIRMED", "Priya", "", [], []);
    reset_demo();
    assert get_dashboard().duplicates[0].decision == "PENDING";
}

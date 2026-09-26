"""Identity review tests. Run: jac test features/people/test_identity_review.jac"""

import from services.trace { reset_demo, get_dashboard }
import from features.people.services { review_identity }
import from graph.nodes { IdentityDecision }

def maya_pair() -> list[str] {
    d = get_dashboard().duplicates[0];
    return [d.person_a_id, d.person_b_id];
}

test "confirm persists, keeps both records and sources" {
    reset_demo();
    ids = maya_pair();
    res = review_identity(ids[0], ids[1], "CONFIRMED", "Priya Shah (demo reviewer)", "checked", ["same first name"]);
    assert res.ok and res.changed;
    snap = get_dashboard();
    assert len(snap.people) == 2;
    d = snap.duplicates[0];
    assert d.decision == "CONFIRMED";
    assert d.reviewer == "Priya Shah (demo reviewer)";
    assert d.decided_at != "";
    sources = [c.source_name for p in snap.people for c in p.claims];
    assert "Nepal Police Demo" in sources;
    assert "Community Report Demo" in sources;
}

test "repeated confirmation does not duplicate" {
    reset_demo();
    ids = maya_pair();
    review_identity(ids[0], ids[1], "CONFIRMED", "Priya", "", []);
    again = review_identity(ids[1], ids[0], "CONFIRMED", "Priya", "", []);
    assert again.ok and not again.changed;
    assert len([root -->[?:IdentityDecision]]) == 1;
}

test "rejection persists and keeps history" {
    reset_demo();
    ids = maya_pair();
    review_identity(ids[0], ids[1], "CONFIRMED", "Priya", "", []);
    res = review_identity(ids[0], ids[1], "REJECTED", "Ravi", "different families", []);
    assert res.ok and res.changed;
    d = get_dashboard().duplicates[0];
    assert d.decision == "REJECTED";
    assert d.reviewer == "Ravi";
    assert len(d.history) == 1;
    assert len([root -->[?:IdentityDecision]]) == 1;
    assert len(get_dashboard().people) == 2;
}

test "invalid input is refused" {
    reset_demo();
    ids = maya_pair();
    assert not review_identity(ids[0], ids[1], "MERGE", "Priya", "", []).ok;
    assert not review_identity(ids[0], ids[1], "CONFIRMED", "  ", "", []).ok;
    assert not review_identity(ids[0], ids[0], "CONFIRMED", "Priya", "", []).ok;
    assert len([root -->[?:IdentityDecision]]) == 0;
}

test "reset clears decisions" {
    reset_demo();
    ids = maya_pair();
    review_identity(ids[0], ids[1], "CONFIRMED", "Priya", "", []);
    reset_demo();
    assert get_dashboard().duplicates[0].decision == "PENDING";
}

"""Small deterministic tests for the Trace demo. Run: jac test tests/test_trace.jac"""

import from services.trace { reset_demo, add_hospital_update, run_resolve, run_watch, get_dashboard }

test "seeding builds the incident with Maya MISSING" {
    reset_demo();
    snap = get_dashboard();
    assert snap.incident_name == "Bhote Koshi Flood Demo";
    maya = [p for p in snap.people if p.name == "Maya Gurung"][0];
    assert maya.latest_status == "MISSING";
    assert maya.claims[0].source_name == "Nepal Police Demo";
    assert len(snap.alerts) == 0;
}

test "resolve flags Maya G. but never merges" {
    reset_demo();
    found = run_resolve();
    assert len(found) == 1;
    assert len(get_dashboard().people) == 2;
}

test "hospital update keeps both claims and creates one alert" {
    reset_demo();
    created = add_hospital_update();
    assert created == 1;
    snap = get_dashboard();
    maya = [p for p in snap.people if p.name == "Maya Gurung"][0];
    assert maya.has_conflict;
    assert [c.claim_type for c in maya.claims] == ["MISSING", "FOUND_SAFE"];
    assert len(snap.alerts) == 1;
    # Running WatchWalker again must not duplicate the alert.
    assert run_watch() == 0;
}

test "reset clears alerts" {
    reset_demo();
    add_hospital_update();
    reset_demo();
    assert len(get_dashboard().alerts) == 0;
}

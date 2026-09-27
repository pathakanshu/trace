"""Generated exercise corpus: import, isolation from the demo, and capped views.

Each test may start from a fresh graph, so each one imports; a repeat import
only matches existing records and is cheap.
"""
import time;
import from graph.nodes { Incident }
import from demo.corpus { load_exercise_corpus, corpus_incident, CORPUS_INCIDENT_NAME }
import from services.trace {
    reset_demo, get_dashboard, list_incidents, search_people, add_hospital_update
}

def corpus_id() -> str {
    return str(load_exercise_corpus()["incident_id"]);
}

test "import counts every mapped kind and reports the rest" {
    result = load_exercise_corpus();
    imported = result["imported"];
    assert imported["person"] == 1150;
    assert imported["claim"] == 3600;
    assert imported["source"] == 1800;
    assert imported["organization"] == 32;
    assert imported["location"] == 170;
    assert imported["media"] == 200;
    assert imported["subscription"] == 100;
    not_imported = result["not_imported"];
    assert not_imported["vote"] == 360 and not_imported["task"] == 96;
    assert sum([not_imported[k] for k in not_imported if str(k).startswith("subscription")]) == 50;
}

test "a second import creates nothing" {
    first = corpus_id();
    again = load_exercise_corpus();
    assert again["incident_id"] == first;
    assert again["created"] == {};
    assert len([i for i in [root -->[?:Incident, name == CORPUS_INCIDENT_NAME]]]) == 1;
}

test "reset_demo leaves the corpus intact and the demo unchanged" {
    cid = corpus_id();
    before = get_dashboard(cid).totals;
    reset_demo();
    add_hospital_update();
    reset_demo();
    assert get_dashboard(cid).totals == before;
    demo = get_dashboard();
    assert demo.incident_name == "Bhote Koshi Flood Demo" and not demo.is_corpus;
    assert len(demo.people) == 2 and len(demo.alerts) == 0 and len(demo.duplicates) == 1;
    assert add_hospital_update() == 1;
    assert len(get_dashboard().alerts) == 1;
    kinds = sorted([o.kind for o in list_incidents()]);
    assert kinds == ["corpus", "demo"];
}

test "corpus snapshot caps people and counts everything" {
    cid = corpus_id();
    started = time.time();
    snap = get_dashboard(cid);
    print(f"corpus get_dashboard took {time.time() - started:.2f}s");
    assert snap.is_corpus and snap.incident_id == cid;
    assert len(snap.people) == 100 and snap.people_total == 1150;
    assert snap.totals["people"] == 1150 and snap.totals["claims"] == 3600;
    assert snap.totals["sources"] == 1800 and snap.totals["locations"] == 170;
    assert sum(snap.status_counts.values()) == 1150;
    assert snap.duplicates == [];
    assert sum([o.report_count for o in snap.organizations]) == 1400;
    assert snap.not_imported["vote"] == 360;
    maya = snap.people[0];
    assert maya.name == "Maya Gurung" and maya.claims;
    assert maya.claims[0].extraction_method == "exercise_corpus_import";
}

test "place counts cover every located report at four coordinates" {
    snap = get_dashboard(corpus_id());
    assert snap.located_reports == 1356;
    assert snap.located_reports + snap.unlocated_reports == 3600;
    assert sum([p.report_count for p in snap.place_counts]) == 1356;
    assert len({(p.latitude, p.longitude) for p in snap.place_counts}) == 4;
    for p in snap.place_counts { assert p.missing + p.safe + p.other == p.report_count; }
}

test "search finds a corpus person by name" {
    found = search_people(corpus_id(), "maya gurung", 10);
    assert found and found[0].name == "Maya Gurung";
    assert len(search_people(corpus_id(), "", 25)) == 25;
}

test "graph projection is capped with the true totals" {
    graph = get_dashboard(corpus_id()).graph;
    assert len(graph.nodes) <= 450;
    assert graph.total_nodes > 7000;
    assert graph.counts_by_kind["Person"] == 1150;
    demo_graph = get_dashboard().graph;
    assert demo_graph.total_nodes == len(demo_graph.nodes);
}

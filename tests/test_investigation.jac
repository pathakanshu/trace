"""Offline checks: no network, credentials, or paid calls. Fakes are test-only."""
import os;
import json;
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from integrations.jev { evaluate, validate_answers, JEV_MODEL, RESERVATION }
import from investigation.questions { attribution_questions }
import from services.investigation { run_report_check }
import from services.trace { reset_demo, get_dashboard }
import from walkers.ingest { IngestWalker }
import from graph.nodes { Incident }
import from graph.edges { HasInvestigation }
import from demo.seed { INCIDENT_NAME }

def fake_answers(questions: dict, choices: dict) -> dict {
    answers: dict = {};
    for name in questions {
        chosen = choices[name];
        answers[name] = {"type": "choice", "choice": chosen, "confidence": 1.0,
            "probabilities": {key: (1.0 if key == chosen else 0.0) for key in questions[name]["criteria"]}};
    }
    return {"model": JEV_MODEL, "answers": answers, "usage": {"input_tokens": 1000}};
}

def good_transport(body: bytes, key: str) -> dict {
    return fake_answers(json.loads(body)["questions"], {"attribution": "UNCLEAR", "reference": "NONE"});
}

def fail_transport(body: bytes, key: str) -> dict { raise ValueError("Controlled failure"); }

def direct_evaluator(state: dict, questions: dict) -> dict {
    response = fake_answers(questions, {"attribution": "DIRECT", "reference": "NONE"});
    return {"status": "LIVE", "model": JEV_MODEL, "answers": response["answers"], "input_tokens": 1000};
}

def relay_evaluator(state: dict, questions: dict) -> dict {
    choices: dict = {"support": "SUPPORTS"};
    if "attribution" in questions {
        choices = {"attribution": "RELAY", "reference": state["candidate_sources"][0]["id"]};
    }
    response = fake_answers(questions, choices);
    return {"status": "LIVE", "model": JEV_MODEL, "answers": response["answers"], "input_tokens": 1000};
}

test "guard disables calls and validates allowance before transport" {
    settings = patch.dict(os.environ, {"TRACE_JEV_ENABLED": "0"});
    settings.start();
    try {
        assert evaluate({}, attribution_questions([]), fail_transport)["status"] == "UNAVAILABLE";
    } finally { settings.stop(); }
    settings = patch.dict(os.environ, {"TRACE_JEV_ENABLED": "1", "TYPESAFE_API_KEY": "test-only", "TRACE_JEV_BUDGET_USD": "10"});
    settings.start();
    try {
        assert evaluate({}, attribution_questions([]), fail_transport)["status"] == "UNAVAILABLE";
    } finally { settings.stop(); }
}

test "persistent spending guard reconciles success reserves failure and blocks exhaustion" {
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/ledger.json";
        settings = patch.dict(os.environ, {"TRACE_JEV_ENABLED": "1", "TYPESAFE_API_KEY": "test-only", "TRACE_JEV_BUDGET_USD": "0.003"});
        settings.start();
        try {
            assert evaluate({}, attribution_questions([]), good_transport, path)["status"] == "LIVE";
            assert evaluate({}, attribution_questions([]), fail_transport, path)["status"] == "FAILED";
            assert evaluate({}, attribution_questions([]), good_transport, path)["status"] == "BUDGET_LIMIT";
            with open(path) as fh { ledger = json.load(fh); }
            assert ledger["attempts"] == 2;
            assert ledger["reserved_usd"] >= RESERVATION;
        } finally { settings.stop(); }
    }
}

test "corrupt ledger cannot reset the allowance" {
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/ledger.json";
        with open(path, "w") as fh { fh.write(""); }
        settings = patch.dict(os.environ, {"TRACE_JEV_ENABLED": "1", "TYPESAFE_API_KEY": "test-only", "TRACE_JEV_BUDGET_USD": "1"});
        settings.start();
        try {
            assert evaluate({}, attribution_questions([]), good_transport, path)["status"] == "UNAVAILABLE";
        } finally { settings.stop(); }
    }
}

test "malformed or unrecognized model choices are rejected" {
    questions = attribution_questions([]);
    response = fake_answers(questions, {"attribution": "UNCLEAR", "reference": "NONE"});
    response["answers"]["attribution"]["choice"] = "MERGE_PEOPLE";
    rejected = False;
    try { validate_answers(response, questions); } except ValueError { rejected = True; }
    assert rejected;
}

test "a repeated investigation uses saved evidence and reset clears it" {
    reset_demo();
    snap = get_dashboard();
    first = run_report_check(snap.incident_id, snap.people[0].id, direct_evaluator);
    assert first["status"] == "COMPLETED" and not first["cached"];
    again = run_report_check(snap.incident_id, snap.people[0].id, None);
    assert again["cached"] and again["run_id"] == first["run_id"];
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    assert len([incident ->:HasInvestigation:->]) == 1;
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    assert len([incident ->:HasInvestigation:->]) == 0;
}

test "relay decision retrieves named source and performs second check without mutations" {
    reset_demo();
    snap = get_dashboard();
    person = snap.people[0];
    relay = root spawn IngestWalker(incident_name=INCIDENT_NAME, selected_person_id=person.id,
        person_name=person.name, source_name="Exercise relay", claim_type="MISSING",
        original_content="According to Nepal Police Demo, Maya Gurung is missing.", source_reference="RELAY-TEST");
    result = run_report_check(snap.incident_id, person.id, relay_evaluator, relay.created_claim_id);
    assert result["status"] == "NEEDS_REVIEW";
    assert len(result["observations"]) == 2 and len(result["citations"]) == 2;
    assert result["citations"][1]["source_name"] == "Nepal Police Demo";
    assert len(get_dashboard().people) == 2 and len(get_dashboard().alerts) == 0;
    assert get_dashboard().people[0].latest_status == "MISSING";
    assert run_report_check(snap.incident_id, "other-person", relay_evaluator)["status"] == "FAILED";
}

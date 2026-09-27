"""Offline checks for report investigation. MockLLM and injected fakes only:
no network, no real key, no paid calls. The ledger lives in a temp folder.
"""
import os;
import sys;
import json;
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.byllm.lib { MockLLM, MockRawResponse }
import from services.trace { reset_demo, get_dashboard }
import from walkers.ingest { IngestWalker }
import from graph.nodes { Incident, ActivityEntry }
import from graph.edges { HasInvestigation }
import from demo.seed { INCIDENT_NAME }

glob LIVE_ENV: dict = {"TRACE_LIVE_PASSPHRASE": "test-pass", "NVIDIA_NIM_API_KEY": "test-only"};

def mock_replies(replies: list[str]) -> MockLLM {
    return MockLLM(
        model_name="mockllm",
        config={"outputs": [MockRawResponse(content=reply) for reply in replies]}
    );
}

# `jac test` evicts project modules from sys.modules each time it collects
# another file, and byLLM resolves annotations through sys.modules, so the
# model module is imported when a test runs. `by llm(...)` captures the
# Model object at import, so tests route that object to a MockLLM instead of
# rebinding the glob; the real call settings stay in the path under test.
def with_model(mock: MockLLM, env: dict, action: any) -> any {
    import from integrations.nemotron { llm }
    swap = patch.object(llm, "_mock_delegate", mock);
    settings = patch.dict(os.environ, env, clear=False);
    swap.start();
    settings.start();
    try {
        return action();
    } finally {
        settings.stop();
        swap.stop();
    }
}

def calls_made(mock: MockLLM, prepared: int) -> int {
    return prepared - len(mock.config["outputs"]);
}

def read_ledger(path: str) -> dict {
    with open(path) as handle {
        return json.load(handle);
    }
}

# Recorded runs would answer the seeded reports from cache, so tests of the
# live path point the loader at a missing file. reset_demo reaches the loader
# through module globals; patching that exact copy survives module eviction.
def reset_with_recordings(path: str) -> None {
    seed_globals: dict = getattr(reset_demo, "__globals__")["seed_demo"].__globals__;
    loader_globals: dict = getattr(seed_globals["load_recorded_investigations"], "__globals__");
    swap = patch.dict(loader_globals, {"RECORDED_PATH": path});
    swap.start();
    try {
        reset_demo();
    } finally {
        swap.stop();
    }
}

glob NO_RECORDINGS: str = "/nonexistent/recorded_investigations.json";

def incident_runs -> int {
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    return len([incident ->:HasInvestigation:->]);
}

test "no passphrase, wrong passphrase or no key means no call" {
    import from integrations.nemotron { evaluate_attribution }
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/ledger.json";
        mock = mock_replies(['{"attribution": "DIRECT", "referenced_source": "NONE"}']);
        def right_pass -> str {
            return evaluate_attribution("I saw her at the bridge.", [], "test-pass", path)["status"];
        }
        def wrong_pass -> str {
            return evaluate_attribution("I saw her at the bridge.", [], "wrong", path)["status"];
        }
        without_pass = {"TRACE_LIVE_PASSPHRASE": "", "NVIDIA_NIM_API_KEY": "test-only"};
        assert with_model(mock, without_pass, right_pass) == "UNAVAILABLE";
        assert with_model(mock, LIVE_ENV, wrong_pass) == "UNAVAILABLE";
        without_key = {"TRACE_LIVE_PASSPHRASE": "test-pass", "NVIDIA_NIM_API_KEY": ""};
        assert with_model(mock, without_key, right_pass) == "UNAVAILABLE";
        assert calls_made(mock, 1) == 0;
        assert not os.path.exists(path);
    }
}

test "ledger reserves before the call, keeps failures and blocks at the cap" {
    import from integrations.nemotron { evaluate_attribution }
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/ledger.json";
        mock = mock_replies(['{"attribution": "DIRECT", "referenced_source": "NONE"}',
            '{"attribution": "MAYBE", "referenced_source": "NONE"}',
            '{"attribution": "DIRECT", "referenced_source": "NONE"}']);
        env = {**LIVE_ENV, "TRACE_MODEL_REQUEST_CAP": "2"};
        def attempt -> dict {
            return evaluate_attribution("I saw her at the bridge.", [], "test-pass", path);
        }
        first = with_model(mock, env, attempt);
        assert first["status"] == "LIVE" and first["attribution"] == "DIRECT";
        assert first["usage_source"] == "estimate" and first["usage"]["total_tokens"] > 0;
        assert with_model(mock, env, attempt)["status"] == "FAILED";
        assert with_model(mock, env, attempt)["status"] == "BUDGET_LIMIT";
        assert calls_made(mock, 3) == 2;
        ledger = read_ledger(path);
        assert ledger["requests"] == 2;
        assert ledger["estimated_tokens"] > 0;
    }
}

test "an empty or corrupt ledger refuses without calling" {
    import from integrations.nemotron { evaluate_attribution }
    for content in ["", "{not json", '{"requests": -1, "prompt_tokens": 0, "completion_tokens": 0, "estimated_tokens": 0}'] {
        with TemporaryDirectory() as folder {
            path: str = str(folder) + "/ledger.json";
            with open(path, "w") as handle { handle.write(content); }
            mock = mock_replies(['{"attribution": "DIRECT", "referenced_source": "NONE"}']);
            result = with_model(mock, LIVE_ENV, lambda -> dict {
                return evaluate_attribution("I saw her at the bridge.", [], "test-pass", path);
            });
            assert result["status"] == "UNAVAILABLE";
            assert calls_made(mock, 1) == 0;
            with open(path) as handle { assert handle.read() == content; }
        }
    }
}

test "request cap comes from the environment and stays within 1 to 1000" {
    import from integrations.nemotron { request_cap }
    for (raw, expected) in [("5", 5), ("0", 1), ("5000", 1000), ("lots", 200)] {
        settings = patch.dict(os.environ, {"TRACE_MODEL_REQUEST_CAP": raw});
        settings.start();
        try { assert request_cap() == expected; } finally { settings.stop(); }
    }
}

test "out-of-menu or wrong-type output fails and nothing is saved" {
    import from services.investigation { run_report_check }
    import from integrations.nemotron { evaluate_attribution }
    for reply in ['{"attribution": "DIRECT", "referenced_source": "Somebody Else"}',
        '{"attribution": "MERGE_PEOPLE", "referenced_source": "NONE"}',
        '{"label": "YES"}'] {
        reset_with_recordings(NO_RECORDINGS);
        snap = get_dashboard();
        with TemporaryDirectory() as folder {
            path: str = str(folder) + "/ledger.json";
            def attribute(excerpt: str, names: list[str], passphrase: str) -> dict {
                return evaluate_attribution(excerpt, names, passphrase, path);
            }
            mock = mock_replies([reply]);
            result = with_model(mock, LIVE_ENV, lambda -> dict {
                return run_report_check(snap.incident_id, snap.people[0].id, passphrase="test-pass", attribute=attribute);
            });
            assert result["status"] == "FAILED";
            assert calls_made(mock, 1) == 1;
            assert read_ledger(path)["requests"] == 1;
        }
        assert incident_runs() == 0;
    }
}

test "a direct report completes, is cached on repeat and cleared by reset" {
    import from services.investigation { run_report_check }
    import from integrations.nemotron { evaluate_attribution, NEMOTRON_MODEL }
    reset_with_recordings(NO_RECORDINGS);
    snap = get_dashboard();
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/ledger.json";
        def attribute(excerpt: str, names: list[str], passphrase: str) -> dict {
            return evaluate_attribution(excerpt, names, passphrase, path);
        }
        mock = mock_replies(['{"attribution": "DIRECT", "referenced_source": "NONE"}']);
        def check -> dict {
            return run_report_check(snap.incident_id, snap.people[0].id, passphrase="test-pass", attribute=attribute);
        }
        first = with_model(mock, LIVE_ENV, check);
        assert first["status"] == "COMPLETED" and first["mode"] == "LIVE";
        assert first["model"] == NEMOTRON_MODEL and first["prompt_version"] == "report-lineage-v2";
        assert first["usage_source"] == "estimate" and first["run_at"];
        # The repeat needs no passphrase: saved results are shown without a call.
        again = run_report_check(snap.incident_id, snap.people[0].id);
        assert again["mode"] == "CACHED" and again["run_id"] == first["run_id"];
        assert again["run_at"] == first["run_at"] and again["model"] == first["model"];
        assert calls_made(mock, 1) == 1 and read_ledger(path)["requests"] == 1;
    }
    assert incident_runs() == 1;
    reset_with_recordings(NO_RECORDINGS);
    assert incident_runs() == 0;
}

test "a relay retrieves the named source with exactly two calls and changes no records" {
    import from services.investigation { run_report_check }
    import from integrations.nemotron { evaluate_attribution, evaluate_support }
    reset_demo();
    snap = get_dashboard();
    person = snap.people[0];
    relay = root spawn IngestWalker(incident_name=INCIDENT_NAME, selected_person_id=person.id,
        person_name=person.name, source_name="Exercise relay", claim_type="MISSING",
        original_content="According to Nepal Police Demo, Maya Gurung is missing.", source_reference="RELAY-TEST");
    before = get_dashboard();
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/ledger.json";
        def attribute(excerpt: str, names: list[str], passphrase: str) -> dict {
            assert names == ["Nepal Police Demo"];
            return evaluate_attribution(excerpt, names, passphrase, path);
        }
        def compare(excerpt: str, referenced: str, passphrase: str) -> dict {
            return evaluate_support(excerpt, referenced, passphrase, path);
        }
        mock = mock_replies(['{"attribution": "RELAY", "referenced_source": "Nepal Police Demo"}',
            '{"support": "SUPPORTS"}']);
        result = with_model(mock, LIVE_ENV, lambda -> dict {
            return run_report_check(snap.incident_id, person.id, claim_id=relay.created_claim_id,
                passphrase="test-pass", attribute=attribute, compare=compare);
        });
        assert result["status"] == "NEEDS_REVIEW";
        assert calls_made(mock, 2) == 2 and read_ledger(path)["requests"] == 2;
    }
    assert len(result["observations"]) == 2 and len(result["citations"]) == 2;
    assert result["citations"][1]["source_name"] == "Nepal Police Demo";
    assert result["observations"][1]["support"] == "SUPPORTS";
    after = get_dashboard();
    assert len(after.people) == len(before.people) and len(after.alerts) == len(before.alerts);
    assert [len(p.claims) for p in after.people] == [len(p.claims) for p in before.people];
    assert after.people[0].latest_status == before.people[0].latest_status;
}

test "the content fingerprint is identical across two resets of the same seed" {
    import from services.investigation { run_report_check }
    def direct(excerpt: str, names: list[str], passphrase: str) -> dict {
        return {"status": "LIVE", "attribution": "DIRECT", "referenced_source": "NONE",
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}, "usage_source": "provider"};
    }
    prints: list[str] = [];
    ids: list[str] = [];
    for _ in range(2) {
        reset_with_recordings(NO_RECORDINGS);
        snap = get_dashboard();
        result = run_report_check(snap.incident_id, snap.people[0].id, attribute=direct);
        assert result["mode"] == "LIVE";
        prints.append(result["fingerprint"]);
        ids.append(snap.people[0].id);
        assert result["usage_source"] == "provider";
    }
    assert prints[0] == prints[1];
    assert ids[0] != ids[1];
}

test "reasoning-off switch rides only on requests for the Nemotron model" {
    import from integrations.nemotron { with_reasoning_off, NEMOTRON_MODEL }
    ours = with_reasoning_off({"model": NEMOTRON_MODEL, "extra_body": {"seed": 1}});
    assert ours["extra_body"] == {"seed": 1, "chat_template_kwargs": {"enable_thinking": False}};
    other = {"model": "nvidia_nim/other-model"};
    assert with_reasoning_off(other) == other;
}

test "provider usage from a litellm response is recorded for the calling thread" {
    import from integrations.nemotron { remember_usage, CALL_STATE }
    import from types { SimpleNamespace }
    CALL_STATE.usage = None;
    remember_usage(SimpleNamespace(usage=SimpleNamespace(prompt_tokens=98, completion_tokens=8, total_tokens=106)));
    assert CALL_STATE.usage == {"prompt_tokens": 98, "completion_tokens": 8, "total_tokens": 106};
    CALL_STATE.usage = None;
    remember_usage(SimpleNamespace());
    assert CALL_STATE.usage is None;
}

test "a missing litellm is reported instead of raised" {
    import from integrations.nemotron { install_request_defaults }
    assert install_request_defaults();
    hide = patch.dict(sys.modules, {"litellm": None});
    hide.start();
    try {
        assert not install_request_defaults();
    } finally {
        hide.stop();
    }
}

test "a call that overruns the wall-clock limit fails and stays counted" {
    import time;
    import from integrations.nemotron { guarded_call }
    nemotron = sys.modules["integrations.nemotron"];
    def slow -> str {
        time.sleep(1.0);
        return "late";
    }
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/ledger.json";
        limit = patch.object(nemotron, "CALL_TIMEOUT_SECONDS", 0.2);
        limit.start();
        try {
            started = time.time();
            result = guarded_call(slow, 100, path);
            assert time.time() - started < 0.9;
        } finally {
            limit.stop();
        }
        assert result["status"] == "FAILED" and "20 seconds" in result["message"];
        assert read_ledger(path)["requests"] == 1;
    }
}

def seeded_fixture -> dict {
    with open("demo/recorded_investigations.json") as handle {
        return json.load(handle);
    }
}

def replayed_runs -> list {
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    return [incident ->:HasInvestigation:->];
}

test "reset replays both recorded runs with the same fingerprints every time" {
    import from integrations.nemotron { NEMOTRON_MODEL }
    expected = sorted([r["fingerprint"] for r in seeded_fixture()["runs"]]);
    for _ in range(2) {
        reset_demo();
        runs = replayed_runs();
        assert len(runs) == 2;
        assert sorted([r.fingerprint for r in runs]) == expected;
        results = [json.loads(str(r.result_json)) for r in runs];
        assert all([r.mode == "REPLAYED" for r in runs]);
        assert all([res["mode"] == "REPLAYED" and res["model"] == NEMOTRON_MODEL for res in results]);
        assert sorted([res["status"] for res in results]) == ["COMPLETED", "NEEDS_REVIEW"];
    }
}

test "a recording whose fingerprint no longer matches is skipped with an activity entry" {
    fixture = seeded_fixture();
    fixture["runs"][0]["fingerprint"] = "0" * 64;
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/recorded.json";
        with open(path, "w") as handle { json.dump(fixture, handle); }
        reset_with_recordings(path);
    }
    runs = replayed_runs();
    assert len(runs) == 1 and runs[0].fingerprint == fixture["runs"][1]["fingerprint"];
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    skipped = [a for a in [root -->[?:ActivityEntry]]
        if a.incident_id == jid(incident) and a.message.startswith("Skipped recorded investigation")];
    assert len(skipped) == 1;
}

test "investigating a replayed report returns the saved run without a call" {
    import from services.investigation { run_report_check, collect_reports }
    import from integrations.nemotron { evaluate_attribution, evaluate_support }
    reset_demo();
    incident = [root -->[?:Incident, name == INCIDENT_NAME]][0];
    replayed_ids = sorted([jid(r) for r in replayed_runs()]);
    with TemporaryDirectory() as folder {
        path: str = str(folder) + "/ledger.json";
        def attribute(excerpt: str, names: list[str], passphrase: str) -> dict {
            return evaluate_attribution(excerpt, names, passphrase, path);
        }
        def compare(excerpt: str, referenced: str, passphrase: str) -> dict {
            return evaluate_support(excerpt, referenced, passphrase, path);
        }
        mock = mock_replies(['{"attribution": "DIRECT", "referenced_source": "NONE"}']);
        seen_runs: list[str] = [];
        for report in collect_reports(incident) {
            result = with_model(mock, LIVE_ENV, lambda -> dict {
                return run_report_check(jid(incident), report["person_id"], claim_id=report["claim_id"],
                    passphrase="test-pass", attribute=attribute, compare=compare);
            });
            assert result["mode"] == "CACHED" and result["cached"];
            assert result["citations"][0]["claim_id"] == report["claim_id"];
            seen_runs.append(result["run_id"]);
        }
        assert sorted(seen_runs) == replayed_ids;
        assert calls_made(mock, 1) == 0 and not os.path.exists(path);
    }
    assert len(replayed_runs()) == 2;
}

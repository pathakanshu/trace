"""Recorded Nemotron runs for the seeded reports, replayed on every reset.

demo/recorded_investigations.json holds real results from live runs. Reset
re-creates them as InvestigationRun nodes with mode REPLAYED, so the demo
shows the model's answers with no key, passphrase or network. A recording is
loaded only when the freshly seeded report still has the same content
fingerprint (text, sources, times, model id, prompt version); an edited seed
or a new prompt version skips it with an activity entry instead of showing a
stale answer.
"""
import os;
import json;
import from graph.nodes { Incident, InvestigationRun }
import from graph.edges { HasInvestigation }
import from graph.activity { now_iso, log_activity }
import from services.investigation { collect_reports, named_sources, report_content, content_fingerprint }

glob RECORDED_PATH: str = "demo/recorded_investigations.json";

def same_report(a: dict, b: dict) -> bool {
    return report_content(a) == report_content(b);
}

"""Point a recorded result at the freshly seeded graph.

Node ids change on every reset, so each citation is swapped for the current
record with the same content. Model labels, trace, usage and run time are
kept as recorded. Returns None when a cited report no longer exists.
"""
def rebind_result(result: dict, records: list[dict]) -> any {
    rebound: dict = json.loads(json.dumps(result));
    new_claim_ids: dict = {};
    citations: list[dict] = [];
    recorded_citations: list[dict] = list(result.get("citations") or []);
    for cited in recorded_citations {
        current = [r for r in records if same_report(r, cited)];
        if len(current) != 1 { return None; }
        new_claim_ids[cited["claim_id"]] = current[0]["claim_id"];
        citations.append(current[0]);
    }
    if not citations { return None; }
    rebound["citations"] = citations;
    rebound["person_id"] = citations[0]["person_id"];
    observations: list[dict] = list(rebound.get("observations") or []);
    for observation in observations {
        observation["claim_id"] = new_claim_ids.get(observation.get("claim_id"), "");
    }
    rebound["mode"] = "REPLAYED";
    rebound["cached"] = False;
    return rebound;
}

"""The fingerprint the live check would compute for this report right now."""
def current_fingerprint(selected: dict, records: list[dict]) -> str {
    by_source = named_sources(selected, records);
    referenced = [r for r in records if r["source_id"] in by_source];
    return content_fingerprint(selected, referenced);
}

def read_recordings -> list[dict] {
    try {
        with open(RECORDED_PATH) as handle {
            data: dict = dict(json.load(handle));
        }
        return list(data.get("runs") or []);
    } except Exception {
        return [];
    }
}

"""Create a REPLAYED InvestigationRun for each recording that still matches.

Called at the end of seed_demo(). Never calls the model. Returns how many
runs were loaded.
"""
def load_recorded_investigations(incident: Incident) -> int {
    incident_id = jid(incident);
    recordings = read_recordings();
    if not recordings {
        log_activity("Investigation", "No recorded investigations found; seeded reports have no replayed result.", incident_id);
        return 0;
    }
    records = collect_reports(incident);
    loaded = 0;
    for entry in recordings {
        result: dict = dict(entry.get("result") or {});
        label = str(entry.get("label", "recorded run"));
        fingerprint = str(entry.get("fingerprint", ""));
        rebound = rebind_result(result, records);
        if rebound is None or current_fingerprint(rebound["citations"][0], records) != fingerprint {
            log_activity("Investigation", "Skipped recorded investigation (" + label + "): the seeded report or prompt version changed since it was recorded.", incident_id);
            continue;
        }
        run = InvestigationRun(person_id=str(rebound["person_id"]), fingerprint=fingerprint,
            result_json="", created_at=now_iso(), mode="REPLAYED");
        incident +>:HasInvestigation():+> run;
        rebound["run_id"] = jid(run);
        run.result_json = json.dumps(rebound);
        loaded += 1;
    }
    return loaded;
}

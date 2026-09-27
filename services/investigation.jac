"""A selected report -> attribution -> cited-source check, at most two model calls.
No automatic investigation on refresh; no whole-incident model scan.
The model returns labels; Jac chooses the next action and records the result.
"""
import json;
import hashlib;
import from graph.nodes { Incident, InvestigationRun }
import from graph.edges { Involves, About, Asserts, HasInvestigation }
import from graph.activity { now_iso, log_activity }
import from integrations.nemotron { evaluate_attribution, evaluate_support, NEMOTRON_MODEL, PROMPT_VERSION }

"""Investigate one source report. The passphrase is checked on the server and
is only needed when no saved result exists and a live call would be made."""
def:pub investigate_report(incident_id: str, person_id: str, claim_id: str, passphrase: str) -> dict {
    return run_report_check(incident_id, person_id, claim_id=claim_id, passphrase=passphrase);
}

"""The fields that identify what a report says, without graph ids.

Node ids change on every reset, so a fingerprint over content lets a recorded
run match freshly seeded evidence. ingested_at is left out for the same reason.
"""
def report_content(record: dict) -> dict {
    return {"person_name": record["person_name"], "source_name": record["source_name"],
        "assertion": record["assertion"], "excerpt": record["excerpt"],
        "reported_at": record["reported_at"], "reference": record["reference"]};
}

def content_fingerprint(selected_report: dict, referenced: list[dict]) -> str {
    others = sorted([report_content(r) for r in referenced], key=lambda (r: dict) -> str { return json.dumps(r, sort_keys=True); });
    packet = [report_content(selected_report), others, NEMOTRON_MODEL, PROMPT_VERSION];
    return hashlib.sha256(json.dumps(packet, sort_keys=True).encode()).hexdigest();
}

def total_usage(observations: list[dict]) -> dict {
    usage = {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0};
    for observation in observations {
        for field in usage {
            usage[field] += int(observation.get("usage", {}).get(field, 0));
        }
    }
    return usage;
}

"""Every claim in the incident with exactly one source, as a report record.

Recorded runs are matched against the same records, so replay and live
investigation agree on what a report and its fingerprint are.
"""
def collect_reports(incident: Incident) -> list[dict] {
    incident_id = jid(incident);
    records: list[dict] = [];
    for person in [incident ->:Involves:->] {
        for claim in [person <-:About:<-] {
            if claim.incident_id and claim.incident_id != incident_id { continue; }
            sources = [claim <-:Asserts:<-];
            if len(sources) != 1 { continue; }
            records.append({"claim_id": jid(claim), "person_id": jid(person),
                "person_name": person.name, "source_id": jid(sources[0]), "source_name": sources[0].name,
                "reported_at": claim.timestamp, "ingested_at": claim.ingested_at,
                "assertion": claim.claim_type, "excerpt": claim.original_content or claim.notes,
                "reference": claim.source_reference});
        }
    }
    return records;
}

"""Other sources named in the selected report's text, keyed by source id."""
def named_sources(selected_report: dict, records: list[dict]) -> dict {
    # Only explicitly named source names enter the menu. Never guess a source URL.
    by_source: dict = {};
    for record in records {
        name = record["source_name"];
        if record["source_id"] != selected_report["source_id"] and len(name) >= 4 and name.lower() in selected_report["excerpt"].lower() {
            by_source[record["source_id"]] = {"id": record["source_id"], "name": name};
        }
    }
    return by_source;
}

# attribute and compare are private test seams with the signatures of
# evaluate_attribution and evaluate_support. RPC accepts IDs and the passphrase only.
def run_report_check(incident_id: str, person_id: str, claim_id: str = "", passphrase: str = "",
    attribute: any = None, compare: any = None) -> dict {
    attribute = attribute or evaluate_attribution;
    compare = compare or evaluate_support;
    incidents = [i for i in [root -->[?:Incident]] if jid(i) == incident_id];
    if not incidents { return {"status": "FAILED", "message": "Incident changed; refresh before investigating."}; }
    incident = incidents[0];
    people = [p for p in [incident ->:Involves:->] if jid(p) == person_id];
    if not people { return {"status": "FAILED", "message": "Select a person in this incident."}; }
    records = collect_reports(incident);
    person_reports = [r for r in records if r["person_id"] == person_id and (not claim_id or r["claim_id"] == claim_id)];
    person_reports.sort(key=lambda (r: dict) -> tuple { return (r["ingested_at"], r["claim_id"]); });
    if not person_reports { return {"status": "PARTIAL", "message": "No attributed report available for this person."}; }
    if len(person_reports) > 1 {
        return {"status": "NEEDS_REVIEW", "message": "Select a specific source report to investigate."};
    }
    selected_report: dict[str, any] = person_reports[-1];
    if not selected_report["excerpt"] or len(selected_report["excerpt"]) > 3000 {
        return {"status": "PARTIAL", "message": "Original report text is missing or too long for this check; inspect the complete source."};
    }
    by_source = named_sources(selected_report, records);
    source_ids = sorted(by_source.keys());
    if len(source_ids) > 8 {
        return {"status": "PARTIAL", "message": "Too many possible source references; choose a report for manual review."};
    }
    candidate_names = sorted(set([by_source[sid]["name"] for sid in source_ids]));
    referenced = [r for r in records if r["source_id"] in source_ids];
    fingerprint = content_fingerprint(selected_report, referenced);
    for saved in [incident ->:HasInvestigation:->] {
        if saved.fingerprint == fingerprint {
            # A saved answer is shown again with its original model and run time.
            result = json.loads(saved.result_json);
            result["mode"] = "CACHED";
            result["cached"] = True;
            result["run_id"] = jid(saved);
            return result;
        }
    }
    first = attribute(selected_report["excerpt"], candidate_names, passphrase);
    if first.get("status") != "LIVE" { return first; }
    trace: list[str] = ["Read the selected report from " + str(selected_report["source_name"]) + "."];
    citations: list[dict] = [selected_report];
    observations: list[dict] = [{"kind": "ATTRIBUTION", "claim_id": selected_report["claim_id"],
        "attribution": first["attribution"], "referenced_source": first["referenced_source"],
        "usage": first.get("usage", {}), "usage_source": first.get("usage_source", "estimate")}];
    attribution = first["attribution"];
    trace.append("Nemotron labeled the report's attribution " + attribution + " (advisory).");
    message = "Attribution checked. This does not establish whether the report is true or independently corroborated.";
    status = "COMPLETED";
    if attribution == "UNCLEAR" {
        status = "NEEDS_REVIEW";
        message = "Attribution remains uncertain. Review the cited report.";
    } elif attribution == "RELAY" {
        # Multiple records from one named publisher cannot identify a particular publication.
        matching = [r for r in referenced if r["source_name"] == first["referenced_source"]];
        if len(matching) != 1 {
            status = "NEEDS_REVIEW";
            message = "The report appears to relay another source, but a unique source report could not be identified.";
        } else {
            target = matching[0];
            if not target["excerpt"] or len(target["excerpt"]) > 3000 {
                status = "PARTIAL";
                message = "Referenced source text is missing or too long; inspect it manually.";
            } else {
                citations.append(target);
                trace.append("Jac retrieved the named source report: " + str(target["source_name"]) + ". Person identities remain separate.");
                second = compare(selected_report["excerpt"], target["excerpt"], passphrase);
                if second.get("status") != "LIVE" {
                    status = "PARTIAL";
                    message = str(second.get("message", "Follow-up unavailable."));
                    trace.append("The comparison did not produce an accepted model result.");
                } else {
                    observations.append({"kind": "SOURCE_COMPARISON", "claim_id": target["claim_id"],
                        "support": second["support"], "usage": second.get("usage", {}),
                        "usage_source": second.get("usage_source", "estimate")});
                    trace.append("Nemotron's cited-source comparison: " + second["support"] + " (advisory).");
                    status = "NEEDS_REVIEW";
                    message = "Review the proposed source relationship. Repeated reporting does not establish independent confirmation or matching identity.";
                }
            }
        }
    }
    sources_of_usage = [o["usage_source"] for o in observations];
    result = {"status": status, "message": message, "mode": "LIVE", "cached": False,
        "person_id": person_id, "model": NEMOTRON_MODEL, "prompt_version": PROMPT_VERSION,
        "run_at": now_iso(), "usage": total_usage(observations),
        "usage_source": "provider" if all([s == "provider" for s in sources_of_usage]) else "estimate",
        "fingerprint": fingerprint, "trace": trace, "citations": citations, "observations": observations,
        "scope": "Selected report only; no media verification or identity decision."};
    # Retryable outcomes are not saved; completed and review results are.
    if status != "PARTIAL" {
        run = InvestigationRun(person_id=person_id, fingerprint=fingerprint,
            result_json=json.dumps(result), created_at=result["run_at"], mode="LIVE");
        incident +>:HasInvestigation():+> run;
        result["run_id"] = jid(run);
    }
    log_activity("Investigation", "Report attribution check: " + status + ". " + str(selected_report["source_name"]), incident_id);
    return result;
}

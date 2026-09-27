"""A selected report -> attribution -> cited-source check, at most two Jev calls.
No automatic investigation on refresh; no whole-incident model scan.
"""
import json;
import hashlib;
import from graph.nodes { Incident, InvestigationRun }
import from graph.edges { Involves, About, Asserts, HasInvestigation }
import from graph.activity { now_iso, log_activity }
import from integrations.jev { evaluate, JEV_MODEL }
import from investigation.questions { attribution_questions, comparison_questions, PROMPT_VERSION }

def:pub investigate_report(incident_id: str, person_id: str, claim_id: str) -> dict {
    return run_report_check(incident_id, person_id, claim_id=claim_id);
}

# The callable is a private test seam. RPC accepts IDs only.
def run_report_check(incident_id: str, person_id: str, evaluator: any = None, claim_id: str = "") -> dict {
    incidents = [i for i in [root -->[?:Incident]] if jid(i) == incident_id];
    if not incidents { return {"status": "FAILED", "message": "Incident changed; refresh before investigating."}; }
    incident = incidents[0];
    people = [p for p in [incident ->:Involves:->] if jid(p) == person_id];
    if not people { return {"status": "FAILED", "message": "Select a person in this incident."}; }
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
    # Only explicitly named source names enter the menu. Never guess a source URL.
    by_source: dict = {};
    for record in records {
        name = record["source_name"];
        if record["source_id"] != selected_report["source_id"] and len(name) >= 4 and name.lower() in selected_report["excerpt"].lower() {
            by_source[record["source_id"]] = {"id": record["source_id"], "name": name};
        }
    }
    source_ids = sorted(by_source.keys());
    if len(source_ids) > 8 {
        return {"status": "PARTIAL", "message": "Too many possible source references; choose a report for manual review."};
    }
    candidates = [by_source[sid] for sid in source_ids];
    referenced = [r for r in records if r["source_id"] in source_ids];
    fingerprint = hashlib.sha256(json.dumps([incident_id, person_id, selected_report, referenced, PROMPT_VERSION, JEV_MODEL], sort_keys=True).encode()).hexdigest();
    for saved in [incident ->:HasInvestigation:->] {
        if saved.fingerprint == fingerprint {
            result = json.loads(saved.result_json);
            result["cached"] = True;
            result["run_id"] = jid(saved);
            return result;
        }
    }
    packet = {"report": selected_report, "candidate_sources": candidates};
    questions = attribution_questions(candidates);
    first = evaluator(packet, questions) if evaluator else evaluate(packet, questions);
    if first.get("status") != "LIVE" { return first; }
    trace: list[str] = ["Read the selected report from " + str(selected_report["source_name"]) + "."];
    citations: list[dict] = [selected_report];
    observations: list[dict] = [{"kind": "ATTRIBUTION", "claim_id": selected_report["claim_id"], "provider_result": first}];
    attribution = first["answers"]["attribution"];
    reference = first["answers"]["reference"];
    trace.append("Jev classified the report's attribution as " + str(attribution["choice"]) + " (advisory).");
    message = "Attribution checked. This does not establish whether the report is true or independently corroborated.";
    status = "COMPLETED";
    if attribution["confidence"] < 0.8 or attribution["choice"] == "UNCLEAR" {
        status = "NEEDS_REVIEW";
        message = "Attribution remains uncertain. Review the cited report.";
    } elif attribution["choice"] == "RELAY" {
        matching = [r for r in referenced if r["source_id"] == reference["choice"]];
        # Multiple records from one named publisher cannot identify a particular publication.
        same_name = [r for r in referenced if matching and r["source_name"] == matching[0]["source_name"]];
        if reference["confidence"] < 0.8 or len(matching) != 1 or len(same_name) != 1 {
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
                second_packet = {"report": selected_report, "referenced_report": target};
                second_questions = comparison_questions();
                second = evaluator(second_packet, second_questions) if evaluator else evaluate(second_packet, second_questions);
                observations.append({"kind": "SOURCE_COMPARISON", "claim_id": target["claim_id"], "provider_result": second});
                if second.get("status") != "LIVE" {
                    status = "PARTIAL";
                    message = str(second.get("message", "Follow-up unavailable."));
                    trace.append("Follow-up did not produce an accepted model result.");
                } else {
                    support = second["answers"]["support"];
                    trace.append("Jev's cited-source comparison: " + str(support["choice"]) + " (advisory).");
                    status = "NEEDS_REVIEW";
                    message = "Review the proposed source relationship. Repeated reporting does not establish independent confirmation or matching identity.";
                }
            }
        }
    }
    result = {"status": status, "message": message, "cached": False, "person_id": person_id,
        "model": JEV_MODEL, "prompt_version": PROMPT_VERSION, "created_at": now_iso(),
        "trace": trace, "citations": citations, "observations": observations,
        "scope": "Selected report only; no media verification or identity decision."};
    # Failures are retryable; persist completed/review results, not unavailable follow-ups.
    if status != "PARTIAL" {
        run = InvestigationRun(person_id=person_id, fingerprint=fingerprint,
            result_json=json.dumps(result), created_at=result["created_at"]);
        incident +>:HasInvestigation():+> run;
        result["run_id"] = jid(run);
    }
    log_activity("Investigation", "Report attribution check: " + status + ". " + str(selected_report["source_name"]), incident_id);
    return result;
}

"""Demo institutional publishing: structured input only, no verified accounts."""
import from graph.nodes { Incident }
import from graph.edges { Involves, HasOrganization }
import from walkers.ingest { IngestWalker }
import from walkers.watch { WatchWalker }
import from demo.names { INCIDENT_NAME }
import from services.access { require_write }

obj PublishResult {
    has claim_id: str, duplicate: bool, alerts_created: int, error: str = "";
}

# Jac 0.34 RPC may turn raised exceptions into a null response. Return known
# validation failures explicitly so the form can show actionable feedback.
def:pub publish_report(incident_id: str, organization_id: str, person_id: str,
    claim_type: str, summary: str, reported_at: str, source_reference: str,
    original_content: str, passphrase: str = "") -> PublishResult {
    try {
        require_write(passphrase);
        return _publish_report(incident_id, organization_id, person_id, claim_type,
            summary, reported_at, source_reference, original_content);
    } except ValueError as exc {
        return PublishResult(claim_id="", duplicate=False, alerts_created=0, error=str(exc));
    }
}

def _publish_report(incident_id: str, organization_id: str, person_id: str,
    claim_type: str, summary: str, reported_at: str, source_reference: str,
    original_content: str) -> PublishResult {
    incidents = [i for i in [root -->[?:Incident]]
        if jid(i) == incident_id and i.name == INCIDENT_NAME];
    if not incidents { raise ValueError("Demo incident changed. Refresh before publishing."); }
    incident = incidents[0];
    people = [p for p in [incident ->:Involves:->] if jid(p) == person_id];
    orgs = [o for o in [incident ->:HasOrganization:->] if jid(o) == organization_id];
    if not people { raise ValueError("Select a person from this incident."); }
    if not orgs { raise ValueError("Select a demo organization from this incident."); }
    if not source_reference.strip() { raise ValueError("A report reference is required to prevent duplicate submissions."); }
    if not summary.strip() or not original_content.strip() {
        raise ValueError("Enter a summary and the original report text.");
    }
    ingested = root spawn IngestWalker(
        incident_name=incident.name, selected_person_id=person_id,
        person_name=people[0].name, person_age=people[0].age,
        organization_id=organization_id, source_name=orgs[0].name,
        source_type=orgs[0].organization_type, claim_type=claim_type,
        claim_value=summary.strip(), timestamp=reported_at,
        source_reference=source_reference, original_content=original_content,
        extraction_method="structured_form"
    );
    watcher = root spawn WatchWalker(incident_id=incident_id);
    return PublishResult(claim_id=ingested.created_claim_id,
        duplicate=ingested.duplicate, alerts_created=watcher.alerts_created);
}

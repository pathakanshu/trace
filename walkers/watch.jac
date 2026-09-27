"""Traverse incident → person → subscription after ingestion.
Alerts describe new evidence, never a truth verdict. Sequential retries are safe.
"""
import from graph.nodes { Incident, Person, Claim, Alert }
import from graph.edges { Involves, Asserts, About, HasSubscription, Receives }
import from graph.activity { log_activity, now_iso, plain_status }

glob STATUS_CLAIMS: list[str] = ["MISSING", "FOUND_SAFE", "INJURED", "DECEASED"];

# Conservative deterministic chronology: only a strictly newer, dated report
# supersedes an earlier report for display. Equal/unknown times need review.
def status_relation(previous: Claim, incoming: Claim) -> str {
    if not previous.timestamp or not incoming.timestamp { return "needs_review"; }
    if incoming.timestamp > previous.timestamp { return "update"; }
    if incoming.timestamp < previous.timestamp { return "historical"; }
    return "needs_review";
}

walker WatchWalker {
    has alerts_created: int = 0, incident_id: str = "", current_incident_id: str = "";
    can start with Root entry {
        visit [i for i in [root -->[?:Incident]] if not self.incident_id or jid(i) == self.incident_id];
    }
    can to_people with Incident entry {
        self.current_incident_id = jid(here);
        visit [here ->:Involves:->];
    }
    can check_person with Person entry {
        claims = [c for c in [here <-:About:<-]
            if not c.incident_id or c.incident_id == self.current_incident_id];
        # Stable report-time order also handles several claims ingested before one run.
        claims.sort(key=lambda (c: Claim) -> str { return c.timestamp; });
        known = [c for c in claims if c.seen_by_watch and c.claim_type in STATUS_CLAIMS];
        new_claims = [c for c in claims if not c.seen_by_watch];
        for claim in new_claims {
            if claim.claim_type in STATUS_CLAIMS {
                different = [c for c in known if c.claim_type != claim.claim_type];
                # Compare with the latest prior status, not every historical status.
                known.sort(key=lambda (c: Claim) -> str { return c.timestamp; });
                previous = known[-1] if known else None;
                relation = status_relation(previous, claim) if previous else "first";
                if previous and (previous.claim_type != claim.claim_type or (relation == "needs_review" and different)) {
                    sources = [claim <-:Asserts:<-];
                    source_name = sources[0].name if sources else "Unknown source";
                    kind = "Newer report" if relation == "update" else ("Earlier report received" if relation == "historical" else "Reports need review");
                    reported_time = claim.timestamp or "unknown";
                    message = f"{kind} for {here.name}: {source_name} says {plain_status(claim.claim_type)}. Reported time: {reported_time}. Source history is retained.";
                    for sub in [here ->:HasSubscription:->] {
                        existing = [a for a in [sub ->:Receives:->] if a.claim_id == jid(claim)];
                        if not existing {
                            sub +>:Receives():+> Alert(message=message, created_at=now_iso(),
                                severity="high" if relation == "needs_review" else "info", claim_id=jid(claim));
                            self.alerts_created += 1;
                        }
                    }
                    log_activity("WatchWalker", message, self.current_incident_id);
                }
                known.append(claim);
            }
            # Mark after successful processing so a failed operation can be retried.
            claim.seen_by_watch = True;
        }
    }
}

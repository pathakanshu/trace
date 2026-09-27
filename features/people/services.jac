"""People server adapter (Gabriel). Registered in main.jac by the integration owner.

review_identity: a human confirms or rejects that two Person records in an
incident may be the same person. Validated server-side; stored as one
IdentityDecision per pair. Neither record nor any claim is changed.

propose_identity: the interface for the investigation agent. It puts a pair
and cited claim ids in front of a human reviewer. It never decides anything.
"""

import from walkers.resolve {
    IdentityDecisionResult, record_identity_decision, propose_identity_pair
}

def:pub review_identity(
    incident_name: str,
    person_a_id: str,
    person_b_id: str,
    decision: str,
    reviewer: str,
    note: str,
    basis: list[str],
    evidence_claim_ids: list[str]
) -> IdentityDecisionResult {
    return record_identity_decision(
        incident_name, person_a_id, person_b_id, decision, reviewer, note, basis, evidence_claim_ids
    );
}

def:pub propose_identity(
    incident_name: str,
    person_a_id: str,
    person_b_id: str,
    proposed_by: str,
    rationale: str,
    cited_claim_ids: list[str]
) -> IdentityDecisionResult {
    return propose_identity_pair(
        incident_name, person_a_id, person_b_id, proposed_by, rationale, cited_claim_ids
    );
}

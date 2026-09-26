"""People server adapter (Gabriel). Registered in main.jac by the integration owner.

review_identity: a human confirms or rejects that two Person records may be the
same person. The decision is stored as one IdentityDecision per pair; neither
record nor any claim is merged, edited, or deleted.
"""

import from walkers.resolve {
    IdentityDecisionResult, record_identity_decision
}

def:pub review_identity(
    person_a_id: str,
    person_b_id: str,
    decision: str,
    reviewer: str,
    note: str,
    basis: list[str]
) -> IdentityDecisionResult {
    return record_identity_decision(person_a_id, person_b_id, decision, reviewer, note, basis);
}

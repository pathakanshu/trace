"""Trace graph nodes.

JAC 101: a f"node" is a piece of data that lives IN the graph. Nodes are
persisted automatically once they are reachable from f"root" (the graph's
starting point), so there is no database layer to write.

Every node gets a stable id from f"jid(node)", so we do not store our own id
fields. Timestamps are plain ISO strings ("2026-09-20T08:00:00") to keep
things readable and JSON-friendly.

Rule of thumb for Trace: a Person has NO status field. Status lives in
Claim nodes, because different sources can say different things.
"""

# A disaster or emergency. Everything else hangs off an Incident.
node Incident {
    has name: str,
        description: str = "",
        start_time: str = "",
        region: str = "";
}

# A person referenced during an incident. No "status" here on purpose.
node Person {
    has name: str,
        age: int = 0,
        notes: str = "";
}

# A statement made by a source, e.g. MISSING, FOUND_SAFE, INJURED, SEEN_AT_LOCATION.
node Claim {
    has claim_type: str,
        value: str = "",
        timestamp: str = "",
        notes: str = "",
        # Set to True once WatchWalker has looked at this claim, so running
        # WatchWalker twice never sends the same alert twice.
        seen_by_watch: bool = False,
        incident_id: str = "",
        ingested_at: str = "",
        original_content: str = "",
        source_reference: str = "",
        extraction_method: str = "",
        ingestion_key: str = "",
        payload_hash: str = "";
}

# Demo institutions are selectable publishers, not authenticated identities.
node Organization {
    has name: str, organization_type: str = "", is_demo: bool = True;
}

# Who made a claim: police, hospital, NGO, community report, registry...
node Source {
    has name: str,
        source_type: str = "",
        url: str = "";
}

# An image or video related to the incident.
node Media {
    has media_type: str,
        url: str = "",
        captured_at: str = "",
        description: str = "",
        # "earliest known copy" - NOT "original". We never overclaim provenance.
        earliest_known_copy: bool = False,
        # Demo stand-ins for real media analysis. Later: fill these from real
        # EXIF parsing / perceptual hashing (Python libs via Jac interop).
        exif_gps_present: bool = False,
        content_hash: str = "",
        community_location: str = "",
        # Aidana: "seed" or "upload". content_hash holds the real SHA-256 for uploads.
        origin: str = "seed",
        uploaded_by: str = "",
        uploaded_at: str = "";
}

# A place on the map.
node Location {
    has name: str,
        latitude: float = 0.0,
        longitude: float = 0.0;
}

# ONE piece of evidence about a media item. Never a single "truth score".
# confidence is a word (HIGH / MEDIUM / LOW / UNKNOWN / NONE) so it stays honest.
node VerificationSignal {
    has signal_type: str,
        value: str = "",
        confidence: str = "UNKNOWN",
        explanation: str = "",
        # How the signal was produced. "simulated" until a real check runs.
        method: str = "simulated";
}

# Someone following a person (fictional contact for the demo).
node Subscription {
    has subscriber_name: str,
        subscriber_contact: str = "";
}

# A generated update delivered to a subscription.
node Alert {
    has message: str,
        created_at: str = "",
        severity: str = "info",
        claim_id: str = "";
}

# One complete earlier review of a pair (kept verbatim in the decision).
obj IdentityReviewEntry {
    has decision: str,
        reviewer: str,
        decided_at: str,
        note: str = "",
        basis: list[str] = [],
        evidence_claim_ids: list[str] = [];
}

# A human review of whether two Person records refer to the same person.
# PROPOSED by Gabriel (People) - schema owner: Miguel.
# It never merges or edits the Person nodes; it only records a decision that
# points at BOTH original records (edge Reviews: IdentityDecision --> Person).
# One node per pair (pair_key = the two Person jids sorted and joined by "|"),
# so repeating the same decision cannot create a duplicate association.
# A changed decision keeps the earlier one in f"history".
node IdentityDecision {
    has pair_key: str,
        person_a_id: str,
        person_b_id: str,
        person_a_name: str = "",
        person_b_name: str = "",
        incident_name: str = "",
        decision: str = "PENDING",          # CONFIRMED | REJECTED
        reviewer: str = "",
        decided_at: str = "",
        note: str = "",
        # Rule reasons shown to the reviewer at decision time.
        basis: list[str] = [],
        # Claim jids the reviewer had in front of them (both records' claims
        # plus any claims an agent cited). Only ids that resolved to Claims.
        evidence_claim_ids: list[str] = [],
        # Every earlier decision on this pair, complete, oldest first.
        # (Legacy string form "REJECTED by X at T" is no longer written.)
        history: list[str] = [],
        past_reviews: list[IdentityReviewEntry] = [];
}

# A pair proposed by an agent (or ResolveWalker) for human review.
# PROPOSED by Gabriel (People) - schema owner: Miguel; producer: investigation agent.
# One node per pair; re-proposing updates the rationale/citations in place.
# It is a suggestion only: it creates no association and no decision.
node IdentityProposal {
    has pair_key: str,
        person_a_id: str,
        person_b_id: str,
        incident_name: str = "",
        proposed_by: str = "",
        rationale: str = "",
        cited_claim_ids: list[str] = [],
        proposed_at: str = "";
}

# One line in the "Agent activity" feed: which walker did what, and when.
# Attached straight to root so the UI can list them in order.
node ActivityEntry {
    has walker_name: str,
        message: str,
        created_at: str = "",
        incident_id: str = "",
        # jids of the records this step touched (Graph tab draws derived links).
        target_ids: list[str] = [];
}

# A small cited report investigation. Structured step history lives in result_json.
# Model observations never become source Claim nodes or change Person identity.
node InvestigationRun {
    has person_id: str, fingerprint: str, result_json: str,
        created_at: str = "";
}

# Metadata and attributed contributions attached to a canonical Media record.
node MediaMetadata {
    has media_id: str = "", filename: str = "", display_name: str = "",
        source_reference: str = "", sha256: str = "", data_url: str = "",
        duplicate_ids: list[str] = [];
}

node MediaComment {
    has body: str = "", author: str = "", created_at: str = "";
}

node MediaAssertion {
    has assertion_type: str = "", value: str = "", source: str = "",
        asserted_at: str = "", provenance: str = "", status: str = "reported";
}

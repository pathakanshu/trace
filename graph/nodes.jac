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
        seen_by_watch: bool = False;
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
        community_location: str = "";
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
        explanation: str = "";
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
        severity: str = "info";
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
        decision: str = "PENDING",          # CONFIRMED | REJECTED
        reviewer: str = "",
        decided_at: str = "",
        note: str = "",
        # Rule reasons shown to the reviewer at decision time.
        basis: list[str] = [],
        # Earlier decisions on this pair: "REJECTED by X at T" strings.
        history: list[str] = [];
}

# One line in the "Agent activity" feed: which walker did what, and when.
# Attached straight to root so the UI can list them in order.
node ActivityEntry {
    has walker_name: str,
        message: str,
        created_at: str = "";
}

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
        severity: str = "info",
        claim_id: str = "";
}

# One line in the "Agent activity" feed: which walker did what, and when.
# Attached straight to root so the UI can list them in order.
node ActivityEntry {
    has walker_name: str,
        message: str,
        created_at: str = "",
        incident_id: str = "";
}

# A small cited report investigation. Structured step history lives in result_json.
# Model observations never become source Claim nodes or change Person identity.
node InvestigationRun {
    has person_id: str, fingerprint: str, result_json: str,
        created_at: str = "";
}
